# Deployment Scripts

ALWAYS use wrapper scripts instead of inline commands. Scripts authenticate once per session.

## Script Reference (example)

This table shows the canonical script surface for a consumer project. Names use `Deploy.ps1` / `Deploy-Status.ps1` etc. as generic stand-ins for an Azure-style deployment orchestrator — adapt for your own pipeline.

| Operation | Script |
|-----------|--------|
| Queue build + download | `Ado-Build.ps1 -Branch "users/<alias>/<branch>"` |
| Register + deploy | `Deploy.ps1 -Environment <env>` |
| Check rollout status | `Deploy-Status.ps1 -Environment <env> -RolloutId <id> -Watch` |
| Restart failed actions | `Deploy-RestartFailed.ps1 -Environment <env> -RolloutId <id>` |
| Assign app roles | `Assign-AppRoles.ps1 -Environment <env>` |
| E2E tests (ACI) | `Test-E2E-ACI.ps1 -Environment <env>` |
| **On-demand ACI E2E (LENS-DCS)** | **`Run-AciE2E.ps1 -Environment <npe\|npe2\|...\|npe6> [-ScriptKind Integration\|Security] [-DryRun]`** — see below |
| E2E smoke (local) | `Test-Api.ps1 -BaseUrl <url>` |
| E2E tests (Kudu SSH) | `Test-Api.sh` (run from App Service Kudu SSH console) |
| E2E behavioral tests (ACI shell) | `Test-Api-ACI.sh` (run from ACI container, VNet-injected) |
| Collect PR data | `Ado-PR-Collect.ps1 -PrId <id>` |
| PR comments/votes | `Ado-PR-Comment.ps1 -PrId <id> -Action comment -Content "..."` |
| Batch post review | `Post-ReviewFindings.ps1 -PrId <id> -FindingsFile <path> [-Vote <V>]` |
| Create/manage PRs | `Ado-PR-Manage.ps1 -Action create -SourceBranch "..." -Title "..."` |
| Quality gates | `Run-DotnetGates.ps1` |
| Pre-flight checks | `Check-Preflight.ps1 -ProjectRoot <path>` |
| **Diagnose stuck/failed deploy (LENS-DCS)** | **`Diagnose-LensDcsDeploy.ps1 -Environment <env> -ReleaseRunId <id>`** — canonical multi-source diagnostic; computes single verdict from ARM activity log + deploymentScripts state + ACI container logs + BuildVersion comparison. Exit 0/1/2/3/4 maps to DEPLOY_SUCCEEDED / STILL_RUNNING / STAGING_DEPLOYED_NO_SWAP / ROLLOUT_FAILED / UNKNOWN. See `rules/deployment-failure-diagnosis.md` |
| Provision secondary service | `Provision-OtherInfra.ps1 -Environment <env>` |
| Deploy secondary service | `Deploy-Other.ps1 -Environment <env>` |
| ADO work items | `Ado-WorkItem.ps1 -Action create -Title "..."` |
| Diff coverage | `Measure-DiffCoverage.ps1` |
| Seed test data | `Seed-TestData.ps1 -Environment <env>` |
| Update reference repos | `Update-ReferenceRepos.ps1` |
| Deploy eval container | `Deploy-EvalContainer.ps1 -Environment <env> -CommitSha <sha>` |
| Local eval | `Run-LocalEval.ps1 -Scenario <name>` |
| Store eval results | `Store-EvalResults.ps1 -ResultFile <path>` |
| Generate eval report | `Generate-EvalReport.ps1 -Environment <env>` |
| Eval history sweep | `Run-EvalHistory.ps1 -AutoDiscover -CompareConfigs` |
| Feature/task maps | `Generate-FeatureMap.ps1` / `Generate-TaskMap.ps1` / `Query-Maps.ps1` |

All scripts in `.claude/scripts/`. Run with: `powershell.exe -NoProfile -File .claude/scripts/<script>`

## Key Rules

1. Never call Azure-deployment-pipeline / az / pipelines commands inline - use wrapper scripts
2. Never poll in a loop - use `-Watch` flag on status scripts
3. Never use `gh` CLI for ADO repos - use `Ado-PR-Manage.ps1`
4. Never run separate `dotnet build/test/format` - use `Run-DotnetGates.ps1`
5. Pass parameters to scripts, don't hardcode values
6. Run scripts with `powershell.exe -NoProfile -File` for credential caching
7. Never use `az container exec` for non-interactive work - use `Test-E2E-ACI.ps1` which handles base64 encoding and polling
8. Never run inline `az container create/show/logs/delete` - use `Test-E2E-ACI.ps1` which handles the full lifecycle
9. Never run inline `az repos pr show/diff` + `az devops invoke` - use `Ado-PR-Collect.ps1` which saves all data to files
10. Never post PR comments with inline `az devops invoke --http-method POST` - use `Ado-PR-Comment.ps1`
11. Never run `az pipelines` in repeated calls - use `Ado-Build.ps1` which queues and waits internally
12. **When a deploy looks stuck or didn't take effect, run `Diagnose-LensDcsDeploy.ps1 -Environment <env> -ReleaseRunId <id>` FIRST.** Pipeline "succeeded" status is NOT proof the ARM resources updated. The script combines ARM + deploymentScripts + ACI logs + BuildVersion into a single verdict; using ad-hoc `az` queries instead has cost hours across multiple sessions (iter12 + iter13). See `rules/deployment-failure-diagnosis.md`.
13. **For on-demand E2E against LENS-DCS NPE rings, use `Run-AciE2E.ps1` — never re-run a release just to re-test.** `Run-AciE2E.ps1` runs the unmodified Ev2 `Invoke-IntegrationTests.ps1` (or `Invoke-SecurityTests.ps1`) inside a transient ACI under the pre-provisioned UAMI, captures full logs to `.mad/reports/aci-e2e-{env}-{ts}.log`, and tears the container down — total wall-clock ~10-15 min vs ~45 min to re-queue an Ev2 rollout.

## Run-AciE2E.ps1 (on-demand ACI E2E for LENS-DCS)

Spins up a transient Azure Container Instance under `id-lensdcs-npe-inttest` (pre-provisioned UAMI in `rg-lensdcs-npe-westus3`), runs the unmodified Ev2 integration-test PowerShell script inside it, polls until terminal state, captures full logs to `.mad/reports/`, and tears the container down. Always use `-DryRun` first to preview the resolved env vars + planned `az container create` invocation.

### Why ACI (not the dev machine)

- Private VNet reachability (matches the Ev2 `deploymentScripts` topology)
- The UAMI already has the right RBAC: Website Contributor + SB sender/receiver + app role on the API SP
- The Ev2 scripts use `Get-AzAccessToken`, `Get-AzWebApp`, `Add-AzWebAppAccessRestrictionRule`, `Invoke-AzRestMethod` — the Az PowerShell modules are in the container image, not on a typical dev box

### What it does NOT exercise

To stay quick + safe, on-demand mode sets `SKIP_DUAL_SB_FLOW=true` on `Invoke-IntegrationTests.ps1`. The script targets the secondary app service directly via Test 1 (Regional Submit) and skips:

- Traffic Manager submit
- Dual-Service-Bus status update flow (and the SB NSP IP allow-list dance)

That flow is a release-validation concern; on-demand mode is for "did my recent deploy break something" smoke. If you need the full TM+SB exercise, queue a real Ev2 release.

**Why an explicit kill switch (PR 5159603 fix-forward).** The prior version of this doc claimed `Run-AciE2E.ps1` "forces the secondary-stage branch which skips Test 2", but the script actually set `SKIP_VERSION_CHECK=true` which per `Invoke-IntegrationTests.ps1` selection logic FORCES `runFullFlow=true` (Test 2 runs). The doc-vs-code divergence was caught when an on-demand npe6 validation 401'd 30/30 retries on Test 2's SB SEND because the fresh ACI's egress IP hadn't propagated through NSP yet. The new `SKIP_DUAL_SB_FLOW` env var is an explicit kill switch that hard-overrides `runFullFlow=$false` regardless of `SKIP_VERSION_CHECK` or `IsPrimaryStage`, making the doc claim load-bearing.

### Common invocations

```powershell
# Preview without launching anything
pwsh -NoProfile -File .claude/scripts/Run-AciE2E.ps1 -Environment npe4 -DryRun

# Real run, integration tests against npe4
pwsh -NoProfile -File .claude/scripts/Run-AciE2E.ps1 -Environment npe4

# Security tests instead
pwsh -NoProfile -File .claude/scripts/Run-AciE2E.ps1 -Environment npe4 -ScriptKind Security
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | PASS (container Succeeded; tests passed) |
| 1 | FAIL (container Failed/Terminated; tests failed) |
| 2 | SETUP_ERROR (config missing, az not authenticated, RG missing) |
| 3 | TIMEOUT (no terminal state in `-TimeoutSeconds`, default 1800s) |
