<#
.SYNOPSIS
    End-to-end verification of the deployed CaseValidationHandler JobId-classifier
    on tonym (NPE). Creates a synthetic Case + DFT in Cosmos with three known
    GUIDs (DcsJobId / PublishJobId / DeliveryJobId), calls /api/v1/cases/validate
    four times, and asserts the returned deliveryChannel matches the expected
    classifier outcome (Collection / LEPortal / Delivery / fallback).

.DESCRIPTION
    Runs inside an ACI container in the same VNet as the CMS API + Cosmos so
    the workstation never needs public access to either resource. Authenticates
    via the CMS UAMI (`id-lenscmsapi-tonym-westus3`, client_id 68bb8d79-...),
    which is on the API's ValidApplicationIds + AllowlistedCallers list AND
    has Cosmos data RBAC at the database level.

    Wrapper structure mirrors Test-E2E-ACI.ps1 (subnet resolve, base64 inner,
    az rest PUT, polling, log capture, cleanup). Auth pattern mirrors
    Migrate-DataCategoryJobIds-ACI.ps1 (`az login --identity --client-id`
    + `az account get-access-token --resource ...`).

    The synthetic Case + DFT are deleted in a `try/finally` block at the end
    of the inner script regardless of pass/fail. Every run uses fresh data
    (caseId carries timestamp + uuid suffix), so reruns never collide.

.PARAMETER Environment
    Target environment. Defaults to tonym (the only NPE deploy this verifier
    is currently authorized for).

.PARAMETER SkipCleanup
    Leave the ACI container after verification (for log inspection).

.PARAMETER WhatIf
    Show what would be executed without creating any Azure resources.

.EXAMPLE
    .\Verify-JobIdClassifier-ACI.ps1
    .\Verify-JobIdClassifier-ACI.ps1 -SkipCleanup
    .\Verify-JobIdClassifier-ACI.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet("tonym", "npe", "kcaver", "lpilat", "v-raidasilva", "v-tuliog", "v-matheusc")]
    [string]$Environment = "tonym",

    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

# --- Constants (mirror Test-E2E-ACI.ps1 + Migrate-DataCategoryJobIds-ACI.ps1) ---
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"
$ResourceGroup = "rg-lenscms-$Environment-westus3"
$Region = "westus3"
$ContainerName = "aci-cms-verify-jobid-$Environment"
$MiName = "id-lenscmsapi-$Environment-$Region"
$VnetName = "vnet-lenscms-$Environment-$Region"
$SubnetName = $null  # Resolved dynamically in Step 2
$Image = "mcr.microsoft.com/azure-cli:latest"
$MaxPollSeconds = 300   # 5 min cap
$PollIntervalSeconds = 10

# CMS API audience: api://7f9733d9-66e1-4fa9-a177-bdd4a5bce24f (the deployed CMS resource).
# The same value the API enforces via MISE on the validate endpoint.
$CmsApiAudience = "api://7f9733d9-66e1-4fa9-a177-bdd4a5bce24f"

# NPE tenant — UAMI tokens issued by AAD carry this `tid` claim, and the
# synthetic Case must carry the same TenantId so CaseRepository.GetByIdAsync
# returns the entity (it filters by tenantId post-read).
$NpeTenantId = "b1a4f7cb-a159-44a6-ac48-6674e85c4ddc"

Write-Host ""
Write-Host "=== JobId Classifier Verification via ACI ===" -ForegroundColor Cyan
Write-Host "Environment:    $Environment"
Write-Host "Container:      $ContainerName"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "API audience:   $CmsApiAudience"
Write-Host ""

# --- Step 1: Resolve identity ---
Write-Host "--- Step 1: Resolve managed identity ---" -ForegroundColor Yellow
$mi = az identity show `
    --name $MiName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "{id: id, clientId: clientId}" `
    --output json 2>&1 | ConvertFrom-Json

if (-not $mi.id) {
    Write-Error "Could not find managed identity '$MiName' in '$ResourceGroup'"
}
Write-Host "MI Resource ID: $($mi.id)" -ForegroundColor Green
Write-Host "MI Client ID:   $($mi.clientId)" -ForegroundColor Green

$CosmosEndpoint = "https://cosmos-lenscms-$Environment-$Region.documents.azure.com:443"
$ApiBaseUrl = "https://app-lenscmsapi-$Environment-$Region.azurewebsites.net"
Write-Host "Cosmos:         $CosmosEndpoint" -ForegroundColor Green
Write-Host "API base URL:   $ApiBaseUrl" -ForegroundColor Green

# --- Step 2: Resolve subnet ---
Write-Host ""
Write-Host "--- Step 2: Resolve ACI subnet ---" -ForegroundColor Yellow
$allSubnets = az network vnet subnet list `
    --vnet-name $VnetName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "[].name" -o tsv 2>&1

$SubnetName = ($allSubnets -split "`n" | Where-Object { $_ -match "aci" } | Select-Object -First 1).Trim()
if (-not $SubnetName) {
    Write-Error "Could not find an ACI subnet in VNet '$VnetName'. Available: $allSubnets"
}

$subnetId = az network vnet subnet show `
    --name $SubnetName `
    --vnet-name $VnetName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "id" -o tsv 2>&1

if (-not $subnetId -or $subnetId -like "*ERROR*") {
    Write-Error "Could not find subnet '$SubnetName' in VNet '$VnetName'"
}
Write-Host "Subnet:    $SubnetName" -ForegroundColor Green

# --- Step 3: Delete existing container (if any) ---
Write-Host ""
Write-Host "--- Step 3: Delete existing container (if any) ---" -ForegroundColor Yellow
$existing = $null
try { $existing = az container show --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --query "name" -o tsv 2>$null } catch { }
if ($existing) {
    if ($PSCmdlet.ShouldProcess($ContainerName, "Delete existing ACI container")) {
        az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
        Write-Host "Deleted existing container." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "No existing container found." -ForegroundColor DarkYellow
}

# --- Step 4: Build + base64-encode inner verification script ---
Write-Host ""
Write-Host "--- Step 4: Build + encode inner verification script ---" -ForegroundColor Yellow

$innerScript = @'
#!/bin/bash
# Inner verification script:
#  1. Login via UAMI; acquire two tokens (Cosmos + CMS API audience).
#  2. Synthesize a Case doc + DFT doc in Cosmos with three known GUIDs:
#       DcsJobId, PublishJobId, DeliveryJobId
#     The DFT has Scenario=LegalDemand (so handler computes lawfulRequestType
#     and returns IsValid=true), and a single DataCategory with
#     deliveryChannel=LEPortal (the fallback we expect when no jobId matches).
#  3. POST /api/v1/cases/validate four times — once per matched leg, plus a
#     random unrelated GUID for the fallback case.
#  4. Assert response.deliveryChannel matches expectations per call.
#  5. Cleanup: delete the synthetic DFT and Case doc (try/finally semantics).
#  6. exit 0 if all assertions pass, 1 otherwise.

set -uo pipefail
# NOT set -e: we want to do cleanup and assertion accounting on individual failures.

CLIENT_ID="${CLIENT_ID:?CLIENT_ID is required}"
COSMOS_ENDPOINT="${COSMOS_ENDPOINT:?COSMOS_ENDPOINT is required}"
API_BASE_URL="${API_BASE_URL:?API_BASE_URL is required}"
CMS_API_RESOURCE="${CMS_API_RESOURCE:?CMS_API_RESOURCE is required}"
NPE_TENANT_ID="${NPE_TENANT_ID:?NPE_TENANT_ID is required}"
COSMOS_DB="${COSMOS_DB:-CMS}"
CASES_CONTAINER="${CASES_CONTAINER:-Cases}"
DFTS_CONTAINER="${DFTS_CONTAINER:-Dfts}"

echo "========================================="
echo "=== JobId Classifier Verification ==="
echo "========================================="
echo "Cosmos endpoint:  $COSMOS_ENDPOINT"
echo "API base URL:     $API_BASE_URL"
echo "API audience:     $CMS_API_RESOURCE"
echo "NPE tenant:       $NPE_TENANT_ID"
echo ""

# --- Login + token acquisition ---
echo "--- Login via UAMI (client_id=$CLIENT_ID) ---"
az login --identity --client-id "$CLIENT_ID" --output none 2>&1 || {
  echo "FATAL: az login --identity failed"
  exit 1
}

# acquire_token_for: get access token for a specific resource via az CLI (proven pattern from
# Test-CmsApi-ACI.sh). Tries the caller-supplied resource first; falls back to bare-GUID form
# if the passed value is the api://<guid> URI form. Returns token on stdout, "" on failure.
# CRITICAL: stdout-only capture (2>/dev/null on success path) so error text never becomes the token.
acquire_token_for() {
  local res="$1"
  local out tok
  if out=$(az account get-access-token --resource "$res" --query accessToken -o tsv 2>/dev/null); then
    tok="$out"
    if [ -n "$tok" ] && [ "$tok" != "None" ]; then
      printf '%s' "$tok"
      return 0
    fi
  fi
  # Fallback: strip api:// prefix and retry with bare GUID
  local bare="${res#api://}"
  if [ "$bare" != "$res" ]; then
    if out=$(az account get-access-token --resource "$bare" --query accessToken -o tsv 2>/dev/null); then
      tok="$out"
      if [ -n "$tok" ] && [ "$tok" != "None" ]; then
        echo "  Token acquired via bare-GUID fallback (res=$bare)" >&2
        printf '%s' "$tok"
        return 0
      fi
    fi
  fi
  return 1
}

# get_token_with_retry: 4 attempts with 5/10/15/20s backoff (UAMI identity may not be ready immediately)
get_token_with_retry() {
  local resource="$1"
  for attempt in 1 2 3 4; do
    if tok=$(acquire_token_for "$resource"); then
      if [ -n "$tok" ]; then
        printf '%s' "$tok"
        return 0
      fi
    fi
    if [ "$attempt" -lt 4 ]; then
      local wait=$((attempt * 5))
      echo "  Token attempt $attempt/4 failed, waiting ${wait}s..." >&2
      sleep $wait
    fi
  done
  return 1
}

COSMOS_RESOURCE="${COSMOS_ENDPOINT%:443}"
echo "--- Acquire Cosmos token (resource=$COSMOS_RESOURCE) ---"
COSMOS_TOKEN=$(get_token_with_retry "$COSMOS_RESOURCE") || {
  echo "FATAL: failed to acquire Cosmos token after 4 attempts"
  exit 1
}
echo "  Cosmos token acquired (${#COSMOS_TOKEN} chars)"

echo "--- Acquire CMS API token (resource=$CMS_API_RESOURCE) ---"
API_TOKEN=$(get_token_with_retry "$CMS_API_RESOURCE") || {
  echo "FATAL: failed to acquire CMS API token after 4 attempts"
  exit 1
}
echo "  API token acquired (${#API_TOKEN} chars)"
# Sanity-check: if the captured "token" contains spaces or newlines, it's not a JWT
if [ "${#API_TOKEN}" -gt 100 ] && printf '%s' "$API_TOKEN" | grep -q $'[\n ]'; then
  echo "FATAL: captured token contains whitespace/newlines (not a JWT)"
  echo "  First 100 chars: $(printf '%s' "$API_TOKEN" | head -c 100)"
  exit 1
fi
echo ""

# --- Generate synthetic IDs ---
# CaseId format: LNS-{epochSeconds(10 digits)}-{8-char-A-Z0-9 suffix}.
# LensTaskId / job GUIDs are full UUIDv4. The DFT document id is dft:{lensTaskId-N-form}
# and the case document id is case:{caseId} per CaseRepository / DftRepository conventions.

EPOCH_NOW=$(date -u +%s)
RAND_SUFFIX=$(python3 -c "import random,string;print(''.join(random.choices(string.ascii_uppercase+string.digits,k=8)))")
CASE_ID="LNS-${EPOCH_NOW}-${RAND_SUFFIX}"
LENS_TASK_GUID=$(python3 -c "import uuid;print(str(uuid.uuid4()))")
LENS_TASK_N=$(python3 -c "import uuid;print(uuid.UUID('$LENS_TASK_GUID').hex)")
DCS_JOB_ID=$(python3 -c "import uuid;print(str(uuid.uuid4()))")
PUBLISH_JOB_ID=$(python3 -c "import uuid;print(str(uuid.uuid4()))")
DELIVERY_JOB_ID=$(python3 -c "import uuid;print(str(uuid.uuid4()))")
RANDOM_JOB_ID=$(python3 -c "import uuid;print(str(uuid.uuid4()))")
DC_KEY=$(python3 -c "import uuid;print(uuid.uuid4().hex)")
CASE_DOC_ID="case:${CASE_ID}"
DFT_DOC_ID="dft:${LENS_TASK_N}"

echo "--- Synthetic identifiers ---"
echo "  CaseId          : $CASE_ID"
echo "  LensTaskId (D)  : $LENS_TASK_GUID"
echo "  LensTaskId (N)  : $LENS_TASK_N"
echo "  DcsJobId        : $DCS_JOB_ID"
echo "  PublishJobId    : $PUBLISH_JOB_ID"
echo "  DeliveryJobId   : $DELIVERY_JOB_ID"
echo "  Random (no-match): $RANDOM_JOB_ID"
echo "  Case doc id     : $CASE_DOC_ID"
echo "  DFT doc id      : $DFT_DOC_ID"
echo ""

# --- Build the synthetic Case doc ---
CASE_DOC_FILE=/tmp/verify-case.json
python3 - <<PYCASE > "$CASE_DOC_FILE"
import json, datetime
now = datetime.datetime.utcnow().isoformat() + "Z"
doc = {
    "id": "$CASE_DOC_ID",
    "type": "case",
    "caseId": "$CASE_ID",
    "tenantId": "$NPE_TENANT_ID",
    "title": "Verify-JobIdClassifier synthetic case",
    "status": "Draft",
    "requestType": "SubpoenaSummons",
    "priority": "Standard",
    "workflowStage": "Intake",
    "workflowState": "WaitingOnTriage",
    "createdAt": now,
    "modifiedAt": now,
    "createdBy": "verify-jobid-classifier",
    "modifiedBy": "verify-jobid-classifier"
}
print(json.dumps(doc))
PYCASE

# --- Build the synthetic DFT doc ---
# Schema sourced from sources/dev/CMS/src/Common/Models/DataFulfillmentTask.cs
# and DataCategoryRecord.cs at commit 15054701 (the deployed change). Cosmos
# camelCase serializer policy: enums are written camelCase but read
# case-insensitively, so PascalCase enum names (e.g. "LegalDemand", "LEPortal")
# round-trip cleanly.
#
# Required for IsValid=true:
#   - dft.Scenario MUST be LegalDemand|LegalIntercept|LegalPreservation
#     (else lawfulRequestType is null -> handler returns IsValid=false).
#
# DataCategory.deliveryChannel = LEPortal -> firstCategory.DeliveryChannel
# is what the fallback path returns when no jobId matches.

DFT_DOC_FILE=/tmp/verify-dft.json
python3 - <<PYDFT > "$DFT_DOC_FILE"
import json, datetime
now = datetime.datetime.utcnow().isoformat() + "Z"
doc = {
    "id": "$DFT_DOC_ID",
    "type": "dft",
    "caseId": "$CASE_ID",
    "lensTaskId": "$LENS_TASK_N",
    "dftCreatedBy": "API",
    "scenario": "LegalDemand",
    "dftStatus": "Created",
    "fulfillmentStatus": "NotStarted",
    "targetIdentifier": {
        "targetIdentifierValue": "verify@example.com",
        "consumerStorageLocation": "US"
    },
    "dataCategories": {
        "$DC_KEY": {
            "dataCategoryId": "$DC_KEY",
            "lensTaskId": "$LENS_TASK_N",
            "categoryType": "Content",
            "dataExists": True,
            "service": "Exchange",
            "resolvedIdentifier": "verify@example.com",
            "region": "Us",
            "dcsJobId": "$DCS_JOB_ID",
            "collectionState": "NotStarted",
            "publishJobId": "$PUBLISH_JOB_ID",
            "publishState": "NotStarted",
            "deliveryChannel": "LEPortal",
            "deliveryJobId": "$DELIVERY_JOB_ID",
            "deliveryState": "NotStarted"
        }
    },
    "createdAt": now,
    "modifiedAt": now,
    "createdBy": "verify-jobid-classifier",
    "modifiedBy": "verify-jobid-classifier"
}
print(json.dumps(doc))
PYDFT

# --- Helpers: cosmos PUT/DELETE; api POST ---
cosmos_put_doc() {
  # $1 container, $2 partition-key (caseId), $3 file-path
  local container="$1"
  local pk="$2"
  local file="$3"
  local cdate
  cdate=$(TZ=GMT date "+%a, %d %b %Y %H:%M:%S GMT")
  local resp=/tmp/cosmos-put-resp.json
  local status
  status=$(curl -sS -o "$resp" -w "%{http_code}" \
      -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
      -H "x-ms-date: $cdate" \
      -H "x-ms-version: 2018-12-31" \
      -H "x-ms-documentdb-partitionkey: [\"$pk\"]" \
      -H "Content-Type: application/json" \
      -X POST "${COSMOS_ENDPOINT}/dbs/${COSMOS_DB}/colls/${container}/docs" \
      --data-binary "@$file" 2>&1)
  echo "$status"
  if [ "$status" != "201" ] && [ "$status" != "200" ]; then
    echo "  Cosmos PUT body: $(head -c 800 "$resp")" >&2
  fi
}

cosmos_delete_doc() {
  # $1 container, $2 partition-key (caseId), $3 doc-id
  local container="$1"
  local pk="$2"
  local doc_id="$3"
  local cdate
  cdate=$(TZ=GMT date "+%a, %d %b %Y %H:%M:%S GMT")
  local resp=/tmp/cosmos-del-resp.txt
  local status
  status=$(curl -sS -o "$resp" -w "%{http_code}" \
      -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
      -H "x-ms-date: $cdate" \
      -H "x-ms-version: 2018-12-31" \
      -H "x-ms-documentdb-partitionkey: [\"$pk\"]" \
      -X DELETE "${COSMOS_ENDPOINT}/dbs/${COSMOS_DB}/colls/${container}/docs/${doc_id}" 2>&1)
  echo "$status"
}

api_validate_call() {
  # $1 jobId GUID. Echoes "<http_status>|<deliveryChannel-or-NULL>|<isValid>"
  local job_id="$1"
  local body
  body=$(python3 -c "
import json, sys
print(json.dumps({'caseId':'$CASE_ID','lensTaskId':'$LENS_TASK_GUID','jobId':'$job_id'}))
")
  local resp=/tmp/api-resp.json
  local status curl_err
  status=$(curl -sS -o "$resp" -w "%{http_code}" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST "${API_BASE_URL}/api/v1/cases/validate" \
      -d "$body" 2>/tmp/curl-stderr)
  curl_err=$?
  echo "  >>> curl exit=$curl_err  http=$status" >&2
  echo "  >>> body[0:500]: $(head -c 500 "$resp" 2>/dev/null | tr '\n' ' ')" >&2
  if [ -s /tmp/curl-stderr ]; then echo "  >>> stderr[0:300]: $(head -c 300 /tmp/curl-stderr | tr '\n' ' ')" >&2; fi
  local channel
  local is_valid
  channel=$(python3 -c "
import json, sys
try:
    d = json.load(open('$resp'))
    print(d.get('deliveryChannel') or 'NULL')
except Exception as e:
    print('PARSE_ERROR')" 2>/dev/null || echo "PARSE_ERROR")
  is_valid=$(python3 -c "
import json
try:
    d = json.load(open('$resp'))
    print(str(d.get('isValid')).lower())
except Exception:
    print('parse_error')" 2>/dev/null || echo "parse_error")
  echo "${status}|${channel}|${is_valid}"
}

# --- Insert synthetic docs ---
INSERTED_CASE=0
INSERTED_DFT=0

cleanup() {
  echo ""
  echo "--- Cleanup: deleting synthetic docs (always runs) ---"
  if [ "$INSERTED_DFT" = "1" ]; then
    DEL_DFT_STATUS=$(cosmos_delete_doc "$DFTS_CONTAINER" "$CASE_ID" "$DFT_DOC_ID")
    echo "  DELETE Dfts/$DFT_DOC_ID -> HTTP $DEL_DFT_STATUS"
  fi
  if [ "$INSERTED_CASE" = "1" ]; then
    DEL_CASE_STATUS=$(cosmos_delete_doc "$CASES_CONTAINER" "$CASE_ID" "$CASE_DOC_ID")
    echo "  DELETE Cases/$CASE_DOC_ID -> HTTP $DEL_CASE_STATUS"
  fi
}
trap cleanup EXIT

echo ""
echo "--- Diagnostic probes from ACI -> App Service ---"
for probe_path in "/api/health" "/api/v1/cases/validate"; do
  echo "  Probe: GET ${API_BASE_URL}${probe_path}"
  curl -sS -o /tmp/probe-body -w "    GET http=%{http_code} size=%{size_download} bytes\n" \
       --max-time 10 "${API_BASE_URL}${probe_path}" 2>/tmp/probe-stderr
  echo "    body[0:200]: $(head -c 200 /tmp/probe-body 2>/dev/null | tr '\n' ' ')"
  if [ -s /tmp/probe-stderr ]; then echo "    stderr: $(head -c 200 /tmp/probe-stderr | tr '\n' ' ')"; fi
done
echo "  Probe: POST /api/v1/cases/validate (no body, no auth)"
curl -sS -o /tmp/probe-body -w "    POST http=%{http_code} size=%{size_download} bytes\n" \
     --max-time 10 -X POST "${API_BASE_URL}/api/v1/cases/validate" 2>/tmp/probe-stderr
echo "    body[0:200]: $(head -c 200 /tmp/probe-body 2>/dev/null | tr '\n' ' ')"
echo "  Probe: POST /api/v1/cases/validate (empty json, no auth)"
curl -sS -o /tmp/probe-body -w "    POST http=%{http_code} size=%{size_download} bytes\n" \
     --max-time 10 -H "Content-Type: application/json" -X POST "${API_BASE_URL}/api/v1/cases/validate" -d '{}' 2>/tmp/probe-stderr
echo "    body[0:200]: $(head -c 200 /tmp/probe-body 2>/dev/null | tr '\n' ' ')"
echo "  Probe: POST /api/v1/cases/validate (junk Bearer token, valid json)"
curl -sS -o /tmp/probe-body -w "    POST http=%{http_code} size=%{size_download} bytes\n" \
     --max-time 10 -H "Authorization: Bearer JUNK.TOKEN.HERE" -H "Content-Type: application/json" \
     -X POST "${API_BASE_URL}/api/v1/cases/validate" -d '{"caseId":"LNS-X","lensTaskId":"00000000-0000-0000-0000-000000000000","jobId":"00000000-0000-0000-0000-000000000000"}' 2>/tmp/probe-stderr
echo "    body[0:200]: $(head -c 200 /tmp/probe-body 2>/dev/null | tr '\n' ' ')"
echo "  Probe: POST /api/v1/cases/validate (REAL Bearer token, valid json) -- this is the failing case"
curl -sS -o /tmp/probe-body -D /tmp/probe-headers -w "    POST http=%{http_code} size=%{size_download} bytes\n" \
     --max-time 10 -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
     -X POST "${API_BASE_URL}/api/v1/cases/validate" -d '{"caseId":"LNS-X","lensTaskId":"00000000-0000-0000-0000-000000000000","jobId":"00000000-0000-0000-0000-000000000000"}' 2>/tmp/probe-stderr
echo "    body[0:500]: $(head -c 500 /tmp/probe-body 2>/dev/null | tr '\n' ' ')"
echo "    response headers:"
sed 's/^/      /' /tmp/probe-headers 2>/dev/null | head -25
echo ""
echo "  Probe: token diagnostics"
echo "    API_TOKEN length: $(printf '%s' "$API_TOKEN" | wc -c) chars"
echo "    API_TOKEN newlines: $(printf '%s' "$API_TOKEN" | grep -c $'\n')"
echo "    API_TOKEN starts: $(printf '%s' "$API_TOKEN" | head -c 30)..."
echo "    Decoded payload first 400 chars:"
printf '%s' "$API_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | head -c 400 | tr '\n' ' ' || echo "    (decode failed)"
echo ""
echo "  Probe: GET /api/health WITH real Bearer token (does the token break a working endpoint?)"
curl -sS -o /tmp/probe-body -w "    GET http=%{http_code} size=%{size_download} bytes\n" \
     --max-time 10 -H "Authorization: Bearer $API_TOKEN" "${API_BASE_URL}/api/health" 2>/tmp/probe-stderr
echo "    body[0:200]: $(head -c 200 /tmp/probe-body 2>/dev/null | tr '\n' ' ')"
echo ""

echo "--- Step 1: Insert synthetic Case doc ---"
CASE_PUT_STATUS=$(cosmos_put_doc "$CASES_CONTAINER" "$CASE_ID" "$CASE_DOC_FILE")
if [ "$CASE_PUT_STATUS" = "201" ] || [ "$CASE_PUT_STATUS" = "200" ]; then
  INSERTED_CASE=1
  echo "  Case insert OK (HTTP $CASE_PUT_STATUS)"
else
  echo "  FATAL: Case insert failed (HTTP $CASE_PUT_STATUS)"
  exit 1
fi

echo "--- Step 2: Insert synthetic DFT doc ---"
DFT_PUT_STATUS=$(cosmos_put_doc "$DFTS_CONTAINER" "$CASE_ID" "$DFT_DOC_FILE")
if [ "$DFT_PUT_STATUS" = "201" ] || [ "$DFT_PUT_STATUS" = "200" ]; then
  INSERTED_DFT=1
  echo "  DFT insert OK (HTTP $DFT_PUT_STATUS)"
else
  echo "  FATAL: DFT insert failed (HTTP $DFT_PUT_STATUS)"
  exit 1
fi

echo ""

# --- Step 3: Validate calls + assertions ---
PASS=0
FAIL=0
RESULTS=()

run_assert() {
  # $1 label, $2 jobId, $3 expected-deliveryChannel
  local label="$1"
  local job_id="$2"
  local expected="$3"
  local out
  out=$(api_validate_call "$job_id")
  IFS='|' read -r http_status got_channel got_valid <<< "$out"
  echo "--- Validate call: $label (jobId=$job_id) ---"
  echo "  HTTP $http_status, isValid=$got_valid, deliveryChannel='$got_channel' (expected '$expected')"
  if [ "$http_status" != "200" ]; then
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL: $label  (HTTP $http_status, isValid=$got_valid, channel='$got_channel')")
    return
  fi
  if [ "$got_valid" != "true" ]; then
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL: $label  (isValid=$got_valid, channel='$got_channel')")
    return
  fi
  if [ "$got_channel" = "$expected" ]; then
    PASS=$((PASS+1))
    RESULTS+=("PASS: $label  -> '$got_channel'")
  else
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL: $label  (got '$got_channel', expected '$expected')")
  fi
}

run_assert "jobId=DcsJobId      " "$DCS_JOB_ID"      "Collection"
run_assert "jobId=PublishJobId  " "$PUBLISH_JOB_ID"  "LEPortal"
run_assert "jobId=DeliveryJobId " "$DELIVERY_JOB_ID" "Delivery"
run_assert "jobId=Random        " "$RANDOM_JOB_ID"   "LEPortal"   # fallback to firstCategory.DeliveryChannel

echo ""
echo "========================================="
echo "=== Verification Results ==="
echo "========================================="
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
echo ""
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

# trap cleanup runs on exit either way.
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
'@

# Base64 encode for safe transport via env vars (matches Test-E2E-ACI / Migrate scripts).
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($innerScript))
$ChunkSize = 30000
$chunks = @()
for ($i = 0; $i -lt $b64.Length; $i += $ChunkSize) {
    $len = [Math]::Min($ChunkSize, $b64.Length - $i)
    $chunks += $b64.Substring($i, $len)
}
Write-Host "Inner script encoded: $($b64.Length) chars in $($chunks.Count) chunk(s)" -ForegroundColor Green

# --- Step 5: Create ACI container ---
Write-Host ""
Write-Host "--- Step 5: Create ACI container ---" -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess($ContainerName, "Create ACI container running JobId classifier verification")) {
    $envVars = [System.Collections.ArrayList]::new()
    [void]$envVars.Add(@{ name = "CLIENT_ID";        value = $mi.clientId })
    [void]$envVars.Add(@{ name = "COSMOS_ENDPOINT";  value = $CosmosEndpoint })
    [void]$envVars.Add(@{ name = "API_BASE_URL";     value = $ApiBaseUrl })
    [void]$envVars.Add(@{ name = "CMS_API_RESOURCE"; value = $CmsApiAudience })
    [void]$envVars.Add(@{ name = "NPE_TENANT_ID";    value = $NpeTenantId })
    [void]$envVars.Add(@{ name = "COSMOS_DB";        value = "CMS" })
    [void]$envVars.Add(@{ name = "CASES_CONTAINER";  value = "Cases" })
    [void]$envVars.Add(@{ name = "DFTS_CONTAINER";   value = "Dfts" })
    [void]$envVars.Add(@{ name = "TEST_SCRIPT_CHUNKS"; value = [string]$chunks.Count })
    for ($k = 0; $k -lt $chunks.Count; $k++) {
        $idx = $k + 1
        [void]$envVars.Add(@{ name = "TEST_SCRIPT_B64_$idx"; value = $chunks[$k] })
    }

    $aciBody = @{
        location = $Region
        identity = @{
            type = "UserAssigned"
            userAssignedIdentities = @{
                $mi.id = @{}
            }
        }
        properties = @{
            subnetIds = @(
                @{ id = $subnetId }
            )
            restartPolicy = "Never"
            osType = "Linux"
            containers = @(
                @{
                    name = $ContainerName
                    properties = @{
                        image = $Image
                        resources = @{
                            requests = @{
                                cpu = 1
                                memoryInGb = 1
                            }
                        }
                        environmentVariables = @($envVars)
                        command = @("bash", "-c", 'n="$TEST_SCRIPT_CHUNKS"; for i in $(seq 1 "$n"); do v="TEST_SCRIPT_B64_$i"; printf "%s" "${!v}"; done | base64 -d | tr -d "\r" | bash')
                    }
                }
            )
        }
    }

    $jsonPath = "$env:TEMP\aci-cms-verify-jobid-$Environment.json"
    $aciBody | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8

    $aciUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerInstance/containerGroups/${ContainerName}?api-version=2023-05-01"
    az rest --method PUT --url $aciUrl --body "@$jsonPath" --output none 2>&1

    Remove-Item $jsonPath -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create ACI container"
    }
    Write-Host "Container created." -ForegroundColor Green
} else {
    Write-Host "WHATIF: Would create container '$ContainerName' with:" -ForegroundColor DarkYellow
    Write-Host "  Image:    $Image" -ForegroundColor DarkYellow
    Write-Host "  Subnet:   $subnetId" -ForegroundColor DarkYellow
    Write-Host "  Identity: $($mi.id)" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "=== DRY RUN COMPLETE ===" -ForegroundColor Cyan
    exit 0
}

# --- Step 6: Poll for completion ---
Write-Host ""
Write-Host "--- Step 6: Waiting for verification to complete ---" -ForegroundColor Yellow
$elapsed = 0
$state = "Running"

while ($state -eq "Running" -or $state -eq "Waiting" -or $state -eq "Pending") {
    Start-Sleep -Seconds $PollIntervalSeconds
    $elapsed += $PollIntervalSeconds

    $state = az container show `
        --name $ContainerName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --query "instanceView.state" -o tsv 2>&1

    $mins = [math]::Floor($elapsed / 60)
    $secs = $elapsed % 60
    $color = if ($state -eq "Succeeded") { "Green" } elseif ($state -eq "Failed") { "Red" } else { "DarkYellow" }
    Write-Host "  [${mins}m ${secs}s] State: $state" -ForegroundColor $color

    if ($elapsed -ge $MaxPollSeconds) {
        Write-Host "  Timed out after ${MaxPollSeconds}s" -ForegroundColor Red
        break
    }
}

# --- Step 6b: Read container exit code ---
$containerExitCode = $null
if ($state -eq "Succeeded" -or $state -eq "Failed" -or $state -eq "Terminated") {
    try {
        $exitCodeRaw = az container show `
            --name $ContainerName `
            --resource-group $ResourceGroup `
            --subscription $SubscriptionId `
            --query "containers[0].instanceView.currentState.exitCode" -o tsv 2>&1
        if ($exitCodeRaw -match '^\d+$') { $containerExitCode = [int]$exitCodeRaw }
    } catch { }
    $ecColor = if ($containerExitCode -eq 0) { "Green" } else { "Red" }
    Write-Host "  Container exit code: $containerExitCode" -ForegroundColor $ecColor
}

# --- Step 7: Capture logs (always, before cleanup) ---
Write-Host ""
Write-Host "--- Step 7: Verification output ---" -ForegroundColor Yellow
$logs = az container logs `
    --name $ContainerName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId 2>&1

$logTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path (Join-Path $PSScriptRoot "..") "scratch"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "verify-jobid-classifier-$Environment-$logTimestamp.log"
$logs | Out-File -FilePath $logFile -Encoding utf8
Write-Host "Logs saved to: $logFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host $logs

# --- Step 8: Cleanup ACI container ---
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "--- Step 8: Cleanup ACI container ---" -ForegroundColor Yellow
    az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
    Write-Host "Container deleted." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "--- Skipping cleanup (use -SkipCleanup to retain container) ---" -ForegroundColor DarkYellow
}

# --- Result ---
Write-Host ""
if ($null -eq $containerExitCode) {
    Write-Host "=== VERIFICATION INCONCLUSIVE (state: $state) ===" -ForegroundColor Yellow
    exit 2
} elseif ($containerExitCode -eq 0) {
    Write-Host "=== VERIFICATION PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== VERIFICATION FAILED (exit code: $containerExitCode) ===" -ForegroundColor Red
    Write-Host "Review log at: $logFile"
    exit 1
}
