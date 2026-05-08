# LENS-DCS — On-Demand ACI E2E Runbook (NPE4)

**Audience:** any agent (or human) needing to run end-to-end behavioral validation against a deployed LENS-DCS ring without queueing a release.

**What this runbook does:** spins up a transient Azure Container Instance in `rg-lensdcs-{env}-westcentralus`, attaches the pre-provisioned UAMI `id-lensdcs-npe-inttest`, runs an inline pwsh script that exercises the deployed API surface, captures logs, tears down. Total time: 1-3 min per test. Cost: trivial (single ACI, ~30-180s runtime).

---

## Prerequisites

Confirm before running:

| Item | Verify with | Expected |
|---|---|---|
| `az` CLI logged in to LENS-DCS-NPE | `az account show --subscription c750c7f5-7730-4c7c-99aa-47dc6b50c914` | `state: Enabled` |
| PIM elevation active | `az role assignment list --assignee tonym@microsoft.com --scope /subscriptions/c750c7f5-7730-4c7c-99aa-47dc6b50c914 --include-inherited` returns Container Instances Contributor + Network Contributor | Returns roles |
| UAMI `id-lensdcs-npe-inttest` exists | `az identity show --name id-lensdcs-npe-inttest --resource-group rg-lensdcs-npe-westus3 --subscription c750c7f5-7730-4c7c-99aa-47dc6b50c914` | Returns identity object |
| The target region(s) have current build deployed | `az webapp config appsettings list --name app-lensdcs-npe4-{region} --resource-group rg-lensdcs-npe4-{region} --subscription c750c7f5-7730-4c7c-99aa-47dc6b50c914 --query "[?name=='BuildVersion'].value" -o tsv` | Returns desired BuildVersion |
| pwsh installed locally (for encoding) | `pwsh -NoProfile -Command "$PSVersionTable.PSVersion"` | 7.x |

---

## RBAC the inttest UAMI must already have

These are pre-deployed by Ev2; if they're missing, the tests will fail with HTTP 401/403:

| Scope | Role |
|---|---|
| Cosmos custom role on `cosmos-lensdcs-{env}` (database `DataCollectorDb`, container `Tasks`) | "App ReadWrite" (custom role with `Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*`) |
| App Service `app-lensdcs-{env}-{region}` | Website Contributor (for IP allow-rule mutation) |
| Service Bus namespace `sb-app-lensdcs-{env}-{region}` | Azure Service Bus Data Sender |
| App service principal `api://e7793396-4a29-44d0-a076-f35ba907c2fb` | DataCollector.Access app role (for MISE auth) |
| Subscription `c750c7f5-7730-4c7c-99aa-47dc6b50c914` | Network Contributor (or NSP-specific role allowing `Microsoft.Network/networkSecurityPerimeters/profiles/accessRules/write`) — needed only when the test sends Service Bus messages from outside the SB NSP allow-list |

---

## What this validates (and what it doesn't)

### ✅ Proven covered

| Component | How |
|---|---|
| **`/api/v1/DataCollector/submit`** (POST) | Submits a synthetic `IntegrationTest` request; expects HTTP 200 + `processingStatus: InProgress` + `errorCode: null` |
| **`/api/v1/DataCollector/getStatus`** (GET) | Polls until `InProgress` is returned post-submit (proves Cosmos read path works) |
| **Cosmos write path** (in handler) | Implicit via GetStatus returning the persisted state |
| **MISE auth chain** (api://CLIENT_ID token → API accepts) | Implicit — submit only succeeds if MISE auth passes |
| **App Service IP allow-list mutation** | Add rule → call → remove rule cycle |
| **Service Bus Send** (POST to namespace REST API) | After NSP allow-list mutation, posts a status update message; expects HTTP 201 |
| **NSP IP-allow mutation** | GET current rules → PUT with appended IP → cleanup |
| **ACI lifecycle** | Create with UAMI → run → fetch logs → delete |

### ❌ NOT covered (gaps)

| Gap | Why | How to close |
|---|---|---|
| **CMS authorize / resolveIdentifier** | These endpoints are only hit when `/api/v1/Target/{authorize\|resolveIdentifier}` is called; the IntegrationTest only hits `/submit`. | Extend script with explicit calls to `Target/authorize` (passing a CDT token) and `Target/resolveIdentifier` (passing an opaque identifier). Requires a CDT-token-acquisition step inside the ACI. |
| **Partner downstream HTTP (Exchange/Teams/Class/ODSP)** | Submit uses `requestedService=99 (IntegrationTest)` which is a sentinel that bypasses partner dispatch. By design — keeps the test from burning partner quota. | Add a *second* submit branch that uses real `requestedService` values + `dataCategory` to trigger partner dispatch. WARNING: this hits live partner infra. Consider gating behind a flag. |
| **SB consumer → Cosmos status transition (full round-trip)** | The chained script (Submit → Poll → SB Send → Verify status changed) fails silently when the encoded pwsh script exceeds ~20KB. The `-EncodedCommand` mechanism on the `mcr.microsoft.com/azure-powershell:latest` image has a size cliff that's not documented. | Three options: (a) split into two ACI runs (submit, then SB+verify); (b) mount the script via Azure File share instead of `-EncodedCommand`; (c) use a slim base image (`mcr.microsoft.com/cbl-mariner/base/core:2.0`) and install only `pwsh-lts` to bypass the wrapper that may be hitting the size limit. |
| **GetStatus polling cycle (post-SB)** | Same root cause — the `Test 4` arm only runs in the chained script which fails. | Same fix as above. |
| **Status update via Service Bus end-to-end** (consumer-side processing verified) | Send proven; consumer execution proven only by Ev2 release-time inttest, not by on-demand script. | Manual: query Cosmos directly via UAMI for the dpsJobId 30s after SB send; assert `ProcessingStatus = Completed`. |
| **Geneva traces / `cms.*` tags surfacing** | Test asserts API behavior, not telemetry emission. | Add a `dgrep-query` step after the test runs (separate process, doesn't fit in ACI). |

---

## Method 1: Single-component test (proven, reliable)

Use this when you want to validate ONE thing — submit, getstatus, or service-bus send — without size constraints.

### Step 1 — write the inner script

Save to `.mad/scratch/aci-{name}.ps1` (where `{name}` is `submit`, `getstatus`, or `sbsend`). Use the proven examples:

- **Submit-only** (~5KB encoded, always works): see `.mad/scratch/aci-e2e-encoded.txt` (already encoded; source equivalent at `.mad/scratch/aci-e2e-submit.ps1`).
- **NSP-add + SB-Send-only** (~9KB encoded, always works): see `.mad/scratch/aci-sbtest.ps1`.

### Step 2 — encode the script (UTF-16LE base64)

```powershell
$src = Get-Content -Raw '.mad/scratch/aci-{name}.ps1'
$bytes = [System.Text.Encoding]::Unicode.GetBytes($src)
[System.IO.File]::WriteAllText('.mad/scratch/aci-{name}.txt', [Convert]::ToBase64String($bytes))
```

### Step 3 — build the ACI ARM body

Save as `.mad/scratch/aci-{name}.json`. Replace `{ENCODED}` with the contents of `aci-{name}.txt`.

```json
{
  "location": "westcentralus",
  "identity": {
    "type": "UserAssigned",
    "userAssignedIdentities": {
      "/subscriptions/c750c7f5-7730-4c7c-99aa-47dc6b50c914/resourceGroups/rg-lensdcs-npe-westus3/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-lensdcs-npe-inttest": {}
    }
  },
  "properties": {
    "osType": "Linux",
    "restartPolicy": "Never",
    "containers": [{
      "name": "main",
      "properties": {
        "image": "mcr.microsoft.com/azure-powershell:latest",
        "command": ["pwsh", "-NoProfile", "-NonInteractive", "-EncodedCommand", "{ENCODED}"],
        "environmentVariables": [
          {"name": "AZURE_SUBSCRIPTION_ID", "value": "c750c7f5-7730-4c7c-99aa-47dc6b50c914"},
          {"name": "UAMI_CLIENT_ID", "value": "017685bf-da44-4908-adec-4fe374285599"},
          {"name": "BASE_URL", "value": "https://app-lensdcs-npe4-westcentralus.azurewebsites.net"},
          {"name": "API_CLIENT_ID", "value": "e7793396-4a29-44d0-a076-f35ba907c2fb"},
          {"name": "TARGET_APP_NAME", "value": "app-lensdcs-npe4-westcentralus"},
          {"name": "TARGET_RESOURCE_GROUP", "value": "rg-lensdcs-npe4-westcentralus"},
          {"name": "SB_NAMESPACE", "value": "sb-app-lensdcs-npe4-westcentralus"},
          {"name": "SB_QUEUE", "value": "tasks"},
          {"name": "SB_NSP_NAME", "value": "nsp-sb-lensdcs-npe4-westcentralus"},
          {"name": "SB_NSP_RG", "value": "rg-lensdcs-npe4-westcentralus"},
          {"name": "SB_NSP_PROFILE", "value": "nsp-sb-profile-lensdcs-npe4-westcentralus"}
        ],
        "resources": { "requests": { "cpu": 1, "memoryInGB": 2 } }
      }
    }]
  }
}
```

For the **PRIMARY** region (`westus3`), substitute:

| key | value |
|---|---|
| `BASE_URL` | `https://app-lensdcs-npe4-westus3.azurewebsites.net` |
| `TARGET_APP_NAME` | `app-lensdcs-npe4-westus3` |
| `TARGET_RESOURCE_GROUP` | `rg-lensdcs-npe4-westus3` |
| `SB_NAMESPACE` | `sb-app-lensdcs-npe4-westus3` |
| `SB_NSP_NAME` | `nsp-sb-lensdcs-npe4-westus3` |
| `SB_NSP_RG` | `rg-lensdcs-npe4-westus3` |
| `SB_NSP_PROFILE` | `nsp-sb-profile-lensdcs-npe4-westus3` |

The ACI itself stays in `rg-lensdcs-npe4-westcentralus` regardless of which region it tests — that RG just hosts the transient container.

### Step 4 — create + run + capture logs

```bash
SUB=c750c7f5-7730-4c7c-99aa-47dc6b50c914
ACI_NAME=aci-{name}-$(date -u +%Y%m%d%H%M%S)

# Create
MSYS_NO_PATHCONV=1 az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB/resourceGroups/rg-lensdcs-npe4-westcentralus/providers/Microsoft.ContainerInstance/containerGroups/$ACI_NAME?api-version=2023-05-01" \
  --body @.mad/scratch/aci-{name}.json \
  --headers "Content-Type=application/json"

# Wait (Submit-only ~30s, SB-send ~60s, full chain ~3min)
sleep 90

# Logs (CLIXML — extract <ToString> tags for clean output)
MSYS_NO_PATHCONV=1 az container logs --container-name main --name $ACI_NAME \
  --resource-group rg-lensdcs-npe4-westcentralus --subscription $SUB \
  | tr -cd '\11\12\15\40-\176' \
  | grep -E "RESULT|status=|PASS|FAIL|Connected|Public IP|POST|HTTP"

# State (read exit code)
MSYS_NO_PATHCONV=1 az container show --name $ACI_NAME \
  --resource-group rg-lensdcs-npe4-westcentralus --subscription $SUB \
  --query "containers[0].instanceView.currentState" -o json

# Cleanup
MSYS_NO_PATHCONV=1 az container delete --name $ACI_NAME \
  --resource-group rg-lensdcs-npe4-westcentralus --subscription $SUB --yes --no-wait

# Cleanup any stray IP rules (App Service)
for rule in $(MSYS_NO_PATHCONV=1 az webapp config access-restriction show \
  --name "$TARGET_APP_NAME" --resource-group "$TARGET_RG" --subscription $SUB \
  --query "ipSecurityRestrictions[?starts_with(name,'AciE2E')].name" -o tsv); do
  MSYS_NO_PATHCONV=1 az webapp config access-restriction remove \
    --name "$TARGET_APP_NAME" --resource-group "$TARGET_RG" --subscription $SUB \
    --rule-name "$rule"
done
```

Container logs come back in **CLIXML format** — strip non-printable bytes with `tr -cd '\11\12\15\40-\176'` and grep for the markers your script emits.

### Expected output

```
Connected on attempt 1
API token acquired
Public IP: 20.168.191.36
Added IP allow rule
POST https://app-lensdcs-npe4-westcentralus.azurewebsites.net/api/v1/DataCollector/submit
Response: dpsJobId=8aa9ee84-... processingStatus=InProgress errorCode=
=== RESULT: PASS ===
```

Container exit code 0 = pass. Exit 1 = inner test failed. Exit 137 (or empty logs) = process killed by ACI for resource limits.

---

## Method 2: Multi-phase test (chained, large script — currently fails silently)

The full chained test (Submit → Poll → SB Send → Verify status transition) is at `.mad/scratch/aci-final-e2e.ps1` (~10KB source / ~20KB encoded). It silently exits 1 with no logs on the standard `mcr.microsoft.com/azure-powershell:latest` image.

**Workaround:** decompose into 2 ACI runs:

1. ACI #1 — Submit (Method 1, returns dpsJobId)
2. ACI #2 — SB Send + Poll-for-Completed against that dpsJobId (Method 1, with the dpsJobId passed as an env var)

OR: use script-mounting via Azure File share (more complex setup, doesn't hit the size cliff).

---

## Three known size-cliff workarounds (pick one when chaining tests)

| Workaround | Pros | Cons |
|---|---|---|
| **A. Two-ACI sequence** | Simple; uses already-proven inner scripts | Two API calls; orchestration logic moves to the caller |
| **B. Azure File share script mount** | Single ACI; arbitrary script size | Storage account dependency; more infra to manage |
| **C. Slim base image with pwsh installed** | Proven scaling beyond 20KB | Image build + push (~5 min); custom registry |

Workaround **A** is the recommended starting point — it's a 30-line shell wrapper around two existing proven inner scripts.

---

## Recreating the **full** "submit → SB → verify" E2E in 2 ACI runs

```bash
# ACI #1 — submit, capture dpsJobId
ACI1_NAME=aci-submit-$(date -u +%H%M%S)
# ... (Method 1 steps with submit-only inner script) ...
DPS_JOB_ID=$(az container logs ... | grep -oP 'dpsJobId=\K[a-f0-9-]+' | head -1)

# ACI #2 — SB send + poll for state transition
ACI2_NAME=aci-verify-$(date -u +%H%M%S)
# Build the ARM body with DPS_JOB_ID as an env var
# Inner script: Connect → NSP-add → SB-send → poll GetStatus until Completed
# (The inner script source is at .mad/scratch/aci-verify.ps1 — write this from
#  the Method 1 SB-Send template + a polling loop that reads $env:DPS_JOB_ID)
```

---

## Cleanup checklist (always run)

After every test (especially on failure):

```bash
# 1. Delete the ACI
MSYS_NO_PATHCONV=1 az container delete --name $ACI_NAME \
  --resource-group rg-lensdcs-npe4-westcentralus \
  --subscription c750c7f5-7730-4c7c-99aa-47dc6b50c914 --yes

# 2. Remove leftover App Service IP rules
for app_pair in "westus3:rg-lensdcs-npe4-westus3:app-lensdcs-npe4-westus3" \
                "westcentralus:rg-lensdcs-npe4-westcentralus:app-lensdcs-npe4-westcentralus"; do
  IFS=":" read -r region rg app <<< "$app_pair"
  for rule in $(MSYS_NO_PATHCONV=1 az webapp config access-restriction show \
    --name $app --resource-group $rg \
    --subscription c750c7f5-7730-4c7c-99aa-47dc6b50c914 \
    --query "ipSecurityRestrictions[?starts_with(name,'AciE2E')].name" -o tsv); do
    MSYS_NO_PATHCONV=1 az webapp config access-restriction remove \
      --name $app --resource-group $rg \
      --subscription c750c7f5-7730-4c7c-99aa-47dc6b50c914 --rule-name "$rule"
  done
done

# 3. Verify NSP allow-list has no test IPs left
# (If your test crashed before cleanup, manually inspect:)
TOKEN=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)
for region_pair in "westus3:nsp-sb-lensdcs-npe4-westus3:nsp-sb-profile-lensdcs-npe4-westus3" \
                   "westcentralus:nsp-sb-lensdcs-npe4-westcentralus:nsp-sb-profile-lensdcs-npe4-westcentralus"; do
  IFS=":" read -r region nsp profile <<< "$region_pair"
  curl -sH "Authorization: Bearer $TOKEN" \
    "https://management.azure.com/subscriptions/c750c7f5-7730-4c7c-99aa-47dc6b50c914/resourceGroups/rg-lensdcs-npe4-$region/providers/Microsoft.Network/networkSecurityPerimeters/$nsp/profiles/$profile/accessRules/AllowIps?api-version=2023-08-01-preview" \
    | jq '.properties.addressPrefixes'
done
```

If you see leftover ACI public IPs (Azure VM range, e.g. `20.168.x.x`, `172.208.x.x`) that aren't supposed to be there, remove them by issuing a PUT with the cleaned address list.

---

## Troubleshooting

| Symptom | Most likely cause | Fix |
|---|---|---|
| Exit 1, empty logs (CLIXML returns 0 bytes via `--output tsv`) | Encoded script ≥ ~20KB tripping a pwsh image limit | Use Method 2 (Workaround A) — split into 2 ACI runs |
| `ParserError: Variable reference is not valid. ':' was not followed by...` | PowerShell drive-qualified variable (`$var:`) ambiguity | Use `${var}:` instead in interpolated strings |
| `AuthorizationFailed ... Microsoft.ContainerInstance/containerGroups/write` | PIM elevation expired | Re-activate PIM; retry |
| `HTTP 401` from `/api/v1/...` | Test ran before App Service IP rule propagated | Increase `Start-Sleep` after `Add-AzWebAppAccessRestrictionRule` (15s minimum, 30s recommended) |
| `HTTP 401` from Service Bus REST | NSP IP-allow rule not propagated | Increase sleep after NSP PUT to 30-45s; verify NSP profile name + RG match |
| `processingStatus: Failed errorCode: COM007` from /submit | Cosmos config drift (deployed code uses old `Cosmos:DatabaseId` keys with no fallback) | Verify deployed BuildVersion includes commits `0a1f8dd` and `4939242` |
| `processingStatus: Failed errorCode: COM006` from /submit | UAMI doesn't have Cosmos data-plane role on `cosmos-lensdcs-{env}/dbs/DataCollectorDb/colls/Tasks` | Verify RBAC; wait 5-15 min for propagation if just assigned |

---

## Reference: env-var resolution shortcut

For any environment (`npe`, `npe2`...`npe6`), substitute `{env}` in the env vars above. Names follow the kit convention:

| Resource | Pattern |
|---|---|
| Subscription | `c750c7f5-7730-4c7c-99aa-47dc6b50c914` (LENS-DCS-NPE — same for all `npe*`) |
| App Service | `app-lensdcs-{env}-{region}` |
| Resource Group | `rg-lensdcs-{env}-{region}` |
| Service Bus | `sb-app-lensdcs-{env}-{region}` |
| NSP | `nsp-sb-lensdcs-{env}-{region}` |
| NSP Profile | `nsp-sb-profile-lensdcs-{env}-{region}` |
| API Client ID | `e7793396-4a29-44d0-a076-f35ba907c2fb` (constant across NPE rings) |
| UAMI | `id-lensdcs-npe-inttest` (NOTE: same UAMI for all NPE rings — NOT region/env-suffixed) |
| UAMI Resource Group | `rg-lensdcs-npe-westus3` (constant) |
| UAMI Client ID | `017685bf-da44-4908-adec-4fe374285599` (constant) |

---

## Status as of last validation (this session)

| Region | BuildVersion deployed | E2E Tests Passed |
|---|---|---|
| **westcentralus (SECONDARY)** | `2.0.03409.428` (HEAD `a4b9fe6`) | Submit ✅, GetStatus ✅, SB Send ✅, NSP add/remove ✅, App IP add/remove ✅ |
| westus3 (PRIMARY) | `2.0.03409.427` (HEAD `257f344`) | Submit ✅ (earlier), other tests N/A — release 35203607 still mid-flight |

**The chained "submit → SB → verify status transition" full E2E was NOT successfully run end-to-end in one ACI** due to the encoded-script size cliff. Each component was validated individually. Workaround A (two-ACI split) is documented above.
