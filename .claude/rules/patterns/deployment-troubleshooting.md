---
paths:
  - "**/deploy/**"
  - "**/*.ps1"
  - "**/*.bicep"
---

# Deployment Troubleshooting

Symptom-Cause-Solution catalog for Azure deployment and operational issues (Azure-style deployment pipelines).

## 1. Azure Deployment Pipeline Failures

### Issue: New ARM parameter breaks unrelated resource definitions

**Symptom:** Deployment fails with "deployment template validation failed" on a resource you did not modify.

**Causes:**
1. Multiple deployment-pipeline resource definitions share one ARM template. Adding a required parameter forces ALL parameter files referencing it to include the new parameter.
2. `ServiceModel.json` was not checked to identify all consumers of the shared template.

**Solution:**
1. Check `ServiceModel.json` to find every resource definition referencing the modified template.
2. Add the new parameter (`__PLACEHOLDER__` value) to every parameter file, add a matching scope binding, and add the config key in every environment config.

**Expected result:** All resource definitions deploy without validation errors.

---

### Issue: Scope binding chain incomplete

**Symptom:** Deployment fails with a parameter value literally set to `__PLACEHOLDER__` or an unresolved scope binding.

**Causes:**
1. The chain `Parameters -> ScopeBindings -> Config` has a break at any link: parameter file has `__PLACEHOLDER__` but no scope binding maps it, or the config key is missing from one or more environment configs.

**Solution:**
Verify all three links: parameter file has `__PLACEHOLDER__`, scope binding maps param name to config key, and every environment config (dev, test, ppe, prod) contains the key.

**Expected result:** The pipeline resolves all placeholders to real values before ARM deployment.

---

### Issue: Ev2 ValidationFailed - "Configuration 'X' cannot be found"

**Symptom:** Ev2 release pipeline reports `inProgress` for an extended period (often >60min) with a frozen `lastChangedDate`. ARM activity completes the early infrastructure phase (private endpoints, RBAC, DNS) but then stalls before AppService deployment phase. App Service slots remain on the prior build version. Eventually surfaces (or is found by reading the Ev2 portal directly) as:

```
ValidationFailed: Configuration 'loggingLevelDefault' cannot be found.
Configuration 'loggingLevelAspNetCore' cannot be found.
...
```

**Causes:**
1. Env-specific config file (`Microsoft.M365.LENS.CMS.<env>.json`) is missing one or more keys that the ARM scope binding chain references.
2. Default config (`Microsoft.M365.LENS.CMS.json`) DOES have the keys, but Ev2 ScopeBindings resolve against the env-specific config first and require an explicit override even when the value would match the default.
3. Config drift: keys were added to most env configs but a subset was missed (typically the lower-traffic envs like personal dev rings, ppe, prd).

**Diagnosis:**
1. Pull the Ev2 validation results via the ADO pipeline timeline endpoint or browser. CLI `az pipelines runs show` only returns top-level state and won't surface this error.
2. `grep -L "<missing-key>" sources/dev/CMS/src/Ev2/ServiceGroupRoot/Configuration/*.json` to find which env configs are missing the key.
3. Compare against the env configs that DO have the key for the right pattern + values.

**Solution:**
1. Add the missing keys to the env-specific config file. Use NPE-equivalent values for dev/test rings (e.g. `Debug` + `true`); use default-config values for ppe/prd (typically `Information` + `false`).
2. Cross-check that ALL env configs (including production rings and personal dev rings) contain all keys referenced by the ARM scope bindings. A spot fix to one env leaves the others vulnerable to the same failure on their next deploy.
3. Cancel the stuck rollout (browser or REST) — it will not recover automatically. Queue a new build + new release run.

**Expected result:** Ev2 ScopeBindings resolution succeeds, AppService deployment phase begins, slots update to the new build version.

**Anti-pattern:** Observing `inProgress` + frozen `lastChangedDate` and concluding "stuck — needs browser triage" without first reading the Ev2 validation results. The error message names the missing key and tells you exactly which file to fix; the diagnostic is one `grep` away.

### Issue: Release pipeline deploys to wrong environment

**Symptom:** Release pipeline deploys to the default environment instead of the intended one.

**Causes:**
1. Environment parameter not passed -- defaults to a shared test env.
2. Pipeline picks latest successful build from the upstream pipeline with no branch filter.

**Solution:**
Always pass the environment explicitly: `powershell.exe -NoProfile -File scripts/Deploy.ps1 -Environment <env>`

**Expected result:** Deployment targets the specified environment. Verify via a status script / portal.

---

## 2. ACI E2E Testing Failures

### Issue: IMDS token acquisition fails on container start

**Symptom:** ACI logs show HTTP 400 or connection refused from IMDS (`169.254.169.254`).

**Causes:**
1. IMDS takes 10-30s to become available after container start. Script lacks retry logic.

**Solution:**
Retry with backoff: 4 attempts, 5/10/15s waits. A standard `Test-E2E-ACI.ps1` wrapper handles this automatically.

**Expected result:** Token acquired within 30 seconds of container start.

---

### Issue: Cosmos queries return HTTP 400 in ACI tests

**Symptom:** Cross-partition queries against the Cosmos REST API return `400 Bad Request` when executed from an ACI container via the gateway.

**Causes:**
1. Cross-partition queries are not supported via the Cosmos gateway REST API.
2. The database name is case-sensitive -- e.g. `MyDb` (exact case) is correct; `mydb` will fail with a 404.
3. The endpoint URL includes `:443` which must be stripped when requesting IMDS tokens (the resource URI must not contain a port).

**Solution:**
1. Use partition-key-scoped queries instead of cross-partition queries.
2. Verify database name has the exact expected casing.
3. Strip `:443` from the Cosmos endpoint before passing it as the IMDS resource.

**Expected result:** Queries return HTTP 200 with expected documents.

---

### Issue: Cosmos config keys not recognized in ACI

**Symptom:** App in ACI fails to connect to Cosmos. Config values are null.

**Causes:**
1. Incorrect env var names. Options class binds to section `Cosmos`, requiring `Cosmos__AccountEndpoint` and `Cosmos__DatabaseId`.

**Solution:**
Set env vars exactly: `Cosmos__AccountEndpoint=https://<account>.documents.azure.com` and `Cosmos__DatabaseId=<db-name>`.

**Expected result:** Application binds configuration and connects to Cosmos on startup.

---

### Issue: ACI container creation fails on Windows

**Symptom:** `az container create` fails with truncated JSON or identity env var errors from Git Bash.

**Causes:**
1. Inline JSON exceeds Windows 8191-char limit. YAML `--file` flag mishandles managed identity config.

**Solution:**
Use `az rest --method PUT` with a JSON body file. A standard `Test-E2E-ACI.ps1` wrapper handles this automatically.

**Expected result:** Container created with managed identity correctly configured.

---

### Issue: MI RBAC permissions insufficient for verification tests

**Symptom:** ACI can write to Cosmos but verification queries (account metadata, App Insights) return 403.

**Causes:**
1. Only `Cosmos DB Built-in Data Contributor` assigned. Verification also needs `Cosmos DB Account Reader Role` and `Monitoring Reader`.
2. RBAC propagation takes 3-10 minutes after role assignment.

**Solution:**
Assign all three roles. Wait 5+ minutes before running verification. For App Insights, use `https://api.applicationinsights.io` as the IMDS token resource.

**Expected result:** All verification queries succeed after RBAC propagation.

---

## 3. VNet / Networking Issues

### Issue: ACI gets HTTP 403 from App Service

**Symptom:** ACI receives HTTP 403 from the target App Service. No application logs -- request never reaches app code.

**Causes:**
1. ACI deployed to the wrong VNet. Two may exist with similar names; only one has private endpoints + DNS zone links.
2. Only the current VNet resolves `privatelink.azurewebsites.net`.

**Solution:**
Always use the current VNet (the one with DNS zone links). Verify DNS zone links exist. Confirm `Test-E2E-ACI.ps1` references the correct VNet.

**Expected result:** ACI resolves the private endpoint and receives HTTP 200.

---

## 4. Token and Authentication Issues

### Issue: MSYS path mangling breaks ADO API calls

**Symptom:** PR inline comments land on wrong file or API returns 400. File path shows `C:/Program Files/Git/sources/dev/...` instead of `/sources/dev/...`.

**Causes:**
1. Git Bash on Windows auto-converts Unix-style paths starting with `/` to Windows paths.

**Solution:**
Prefix the command with `MSYS_NO_PATHCONV=1`:
```bash
MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -File scripts/Ado-PR-Comment.ps1 \
  -PrId 1234567 -Action comment -FilePath "/sources/dev/file.cs" -Content "Fix this"
```

**Expected result:** File path sent to ADO API unmodified.

---

### Issue: Token acquisition functions mix diagnostics into stdout

**Symptom:** `jq` fails parsing token JSON -- stdout contains diagnostic messages mixed with the response.

**Causes:**
1. Shell functions send progress/diagnostic messages to stdout instead of stderr.

**Solution:**
Redirect all diagnostic output to stderr (`>&2`). Only JSON goes to stdout.

**Expected result:** `jq` parses the token cleanly.

---

## Quick Reference

| Symptom | Jump To |
|---------|---------|
| ARM validation error on untouched resource | Shared ARM templates |
| `__PLACEHOLDER__` in deployed config | Scope binding chain |
| Deployed to wrong environment | Release pipeline |
| IMDS 400 on container start | IMDS token acquisition |
| Cosmos 400 on query | Cross-partition queries |
| Cosmos config null | Config key naming |
| ACI 403 from App Service | Wrong VNet |
| Mangled file paths in PR comments | MSYS path mangling |
