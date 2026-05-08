# Azure Container Instance (ACI) E2E Test Plan

Behavioral end-to-end tests for a consumer-project API, executed from inside an Azure Container Instance (ACI) on the target environment's VNet using a user-assigned Managed Identity. No inbound public access to the API is required — the ACI sits on the same VNet as the App Service and authenticates via IMDS.

This doc uses a Case Management API as a running example. The pattern (in-VNet ACI + IMDS + base64-encoded test script) applies to any private Azure service fronted by an App Service or App Container.

**Example scope:** `/api/health`, `/api/v1/cases` (CRUD + JSON-Patch + ETag concurrency), `/api/v1/cases/{id}/...` sub-resources.

---

## Why run from ACI (vs. local curl)

| Requirement | ACI in-VNet | Local curl |
|---|---|---|
| Reach private App Service behind VNet | Yes (same subnet) | No (blocked by network ACL) |
| Acquire MI token without user interaction | Yes (IMDS) | No (needs az login) |
| Reproducible from CI/CD or any dev box | Yes | No (env-dependent) |
| Isolated per env | Yes (per-env RG) | No |

---

## Components

| File | Role |
|---|---|
| `scripts/Test-E2E-ACI.ps1` | Orchestrator. Resolves MI + subnet, creates ACI, polls, collects logs, cleans up. |
| `scripts/Test-Api-ACI.sh` | Canonical workflow simulation (e.g. 9 assertions). Injected into the ACI as base64. |
| `scripts/Test-Api-FullField-ACI.sh` | Full-field coverage across top-level and sub-resources. |
| `scripts/Test-Api.sh` \| `.ps1` | Kudu-SSH smoke test (runs inside the App Service, not ACI). |

These ship with the consumer project, not this kit.

---

## How it runs

```
Test-E2E-ACI.ps1 -Environment <env> [-Suite full|per-milestone|...] [-SkipCleanup] [-WhatIf]
```

Steps performed by the orchestrator:

1. **Resolve MI** — `az identity show --name id-<service>api-<env>-<region>` → `{id, clientId}`.
2. **Resolve ACI subnet** — enumerates the VNet's subnets and picks the one matching `aci` (subnet naming varies).
3. **Delete existing container** with the same name, if any.
4. **Base64-encode** the bash test script to avoid Windows cmd-line length limits.
5. **Create container** via `az rest PUT .../containerGroups/{name}?api-version=2023-05-01` (YAML path can't inject IMDS env vars). Image: `mcr.microsoft.com/azure-cli:latest`. Env vars: `CLIENT_ID`, `BASE_URL`, `RESOURCE`, `COSMOS_ENDPOINT`, `APPINSIGHTS_APPID`, `SUITE`, `TEST_SCRIPT_B64`. Command: `bash -c 'echo $TEST_SCRIPT_B64 | base64 -d | tr -d "\r" | bash'`.
6. **Poll** `instanceView.state` every 15s until `Succeeded` / `Failed` / `Terminated`. Timeout varies by suite (600s–2400s).
7. **Read exit code** from `containers[0].instanceView.currentState.exitCode` before deletion.
8. **Dump logs** with `az container logs`.
9. **Cleanup** — delete ACI unless `-SkipCleanup`.

Exit codes: `0` = pass, `1` = fail, `2` = inconclusive or skipped-critical.

---

## Authentication (inside the container)

Bash scripts acquire a bearer token from IMDS with 4 retries (5s/10s/15s/20s backoff):

```bash
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=${RESOURCE}&client_id=${CLIENT_ID}"
```

Response:
```json
{"access_token": "eyJ0eXAiOi...", "token_type": "Bearer", "expires_in": "86399", ...}
```

The `access_token` is used as `Authorization: Bearer {token}` for all subsequent API calls.

---

## Example Test Suite A — Workflow simulation (9 tests)

Simulates a middletier workflow: draft → triage → assigned, with ETag concurrency edge cases. Adapt the entities, field names, and transitions to your own API.

### Test 1 — Health (no auth)

**Request**
```
GET {BASE_URL}/api/health
```

**Expected:** `200 OK`

---

### Test 2 — Create entity

**Request**
```
POST {BASE_URL}/api/v1/cases
Authorization: Bearer {token}
Content-Type: application/json
X-Idempotency-Key: {uuid}

{
  "requestType": "SubpoenaSummons",
  "title": "Workflow Test Case",
  "jurisdiction": "US-WA",
  "country": "US",
  "priority": "Standard"
}
```

**Expected response:** `201 Created` + `ETag` header

**Assertions:** status code = 201; `caseId` non-empty; `status == "Draft"` (original state).

---

### Test 3 — Get entity (capture fresh ETag)

**Request**
```
GET {BASE_URL}/api/v1/cases/{caseId}
Authorization: Bearer {token}
```

**Expected:** `200 OK` + `ETag` header (the `ETag` from GET is used for the next PATCH since create→get may emit a different tag).

---

### Test 4 — PATCH status transition

**Request** (JSON-Patch)
```
PATCH {BASE_URL}/api/v1/cases/{caseId}
Authorization: Bearer {token}
Content-Type: application/json
If-Match: {etag}

[{"op":"replace","path":"/status","value":"Open"}]
```

**Expected:** `200 OK`; response body has `status: "Open"`; new `ETag`.

---

### Test 5 — PATCH multiple fields (form save pattern)

**Request**
```
PATCH {BASE_URL}/api/v1/cases/{caseId}
If-Match: {etag}

[
  {"op":"replace","path":"/workflowStage","value":"Triage"},
  {"op":"replace","path":"/referenceNumber","value":"REF-2026-TEST-001"},
  {"op":"replace","path":"/description","value":"..."}
]
```

**Expected:** `200 OK`; `workflowStage: "Triage"`.

> **Cosmos PATCH limit:** Cosmos `PatchItemAsync` supports max 10 operations per request (+ 2 audit fields added server-side). Split larger patch sets into batches — see full-field suite.

---

### Test 6 — PATCH assignment (triage)

Similar PATCH pattern setting assignee and priority fields. Expected: `200 OK`.

---

### Test 7 — PATCH with stale ETag (optimistic concurrency)

**Request**
```
PATCH {BASE_URL}/api/v1/cases/{caseId}
If-Match: "00000000-0000-0000-0000-000000000000"

[{"op":"replace","path":"/title","value":"Should fail"}]
```

**Expected:** `412 Precondition Failed`.

---

### Test 8 — PATCH with missing `If-Match`

**Request** (no `If-Match` header)
```
PATCH {BASE_URL}/api/v1/cases/{caseId}

[{"op":"replace","path":"/title","value":"Should fail"}]
```

**Expected:** `428 Precondition Required`.

---

### Test 9 — Final GET (verify cumulative state)

**Request**
```
GET {BASE_URL}/api/v1/cases/{caseId}
```

**Expected:** `200 OK`; body reflects all successful patches. Logged as human-readable JSON for visual review.

---

## Example Test Suite B — Full-Field Coverage (13 steps)

Richer payloads and sub-resources. Same IMDS auth. Run when validating a schema change, new field, or sub-entity behavior. Exercise:

- Step 1 — Create with all fields populated, including nested arrays
- Step 2 — GET and verify persistence
- Step 3 — PATCH in batches to stay under the Cosmos 10-op limit
- Step 4 — GET and verify patched values
- Steps 5-7 — PATCH sub-resources (nested entity, nested-of-nested entity)
- Step 8 — Create another sub-resource
- Step 9 — PATCH using merge-patch content type (not JSON-Patch)
- Step 10 — List sub-resources and verify persistence
- Step 11 — Create note/comment sub-resource
- Step 12 — GET parent, verify embedded summaries reflect sub-resource state
- Step 13 — List parent entities, verify ours appears

---

## Prerequisites

The target environment must have:

| Resource | Example Naming | Purpose |
|---|---|---|
| Resource group | `rg-<service>-{env}-westus3` | Container + supporting resources |
| User-assigned MI | `id-<service>api-{env}-westus3` | IMDS identity inside ACI |
| VNet | `vnet-<service>-{env}-westus3` | Must include a subnet with `aci` in the name |
| App Service | `app-<service>api-{env}-westus3` | Target (`BASE_URL`) |
| Cosmos | `cosmos-<service>-{env}-westus3` | Verification endpoint |
| App Insights | `appi-<service>-{env}-westus3` | Observability verification |
| RBAC | MI must have an `<Api>.Access` app role on the API App Registration | Bearer token is accepted |

If the MI or subnet name differs, fix it at the source — do not hardcode environment-specific names in the script.

### Caller RBAC required to run

The **user running the script** needs write on the container-instances resource provider for the target RG:

| Action | Scope | Notes |
|---|---|---|
| `Microsoft.ContainerInstance/containerGroups/write` | target RG | Create/update the test container |
| `Microsoft.ContainerInstance/containerGroups/delete` | same | Cleanup |
| `Microsoft.ContainerInstance/containerGroups/containers/logs/action` | same | Collect logs |
| `*/read` (Reader) | same | Resolve MI / subnet / App Insights |

A personal dev env with Contributor works out-of-the-box. Shared environments typically require **PIM activation** on the RG first — otherwise container creation fails with:

```
ERROR: Forbidden ... AuthorizationFailed: The client ... does not have authorization to perform action
'Microsoft.ContainerInstance/containerGroups/write' over scope '.../rg-<service>-<env>-westus3/...'
```

Activate PIM → re-run `az login` or `az account set` to refresh the token, then re-run the script. In CI, the pipeline identity should be assigned Contributor on the RG at deploy time.

---

## Failure triage — common patterns

| Symptom | Cause | Fix |
|---|---|---|
| `FATAL: Could not acquire MI token after 4 attempts` | IMDS timing at container start | Retry is built in; if still failing check MI is assigned to the container group |
| All authenticated requests return `403` | MI missing app role | Run your role-assignment script against the target env |
| Both `/api/health` (anon) and authed routes return `401` | App Service EasyAuth rejecting token, or no `AllowAnonymous` on health | Check `az webapp auth show`; verify issuer/audience and health controller attributes |
| `412` on what should be a valid PATCH | ETag captured from POST, not GET | Test script uses GET ETag by design (see Test 3) |
| ACI stuck in `Waiting`/`Pending` | Subnet delegation or quota issue | Check `az network vnet subnet show` for `Microsoft.ContainerInstance/containerGroups` delegation |
| Exit code `2` (skipped-critical) | Non-critical tests bypassed; review log | Inspect raw logs via `-SkipCleanup` + `az container logs` |

See `rules/patterns/deployment-troubleshooting.md` for the full ACI triage matrix.

---

## When to run

| Trigger | Suite |
|---|---|
| Smoke after a deployment | `-Suite full` against the target env |
| Schema change (new field) | Full-field suite against a dev/test env |
| ETag / concurrency contract change | Workflow suite (Tests 7, 8) |
| CI gate for API PRs | `-Suite full` against a shared test env |

---

## Not covered (out of scope)

- Authorization bypass / negative-path RBAC — covered by middleware unit tests
- High-volume / load — separate load harness, not this plan
- Frontend-to-API integration — covered by UI-level tests in the frontend repo
- Cosmos query correctness at scale — covered by integration tests using Cosmos emulator
