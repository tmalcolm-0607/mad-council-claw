<#
.SYNOPSIS
    One-shot Cosmos data migration that renames embedded DataCategory fields
    `publishId` -> `publishJobId` and `deliveryId` -> `deliveryJobId` on every
    DFT document in the target environment's Cosmos database.

    Runs the migration inside an ACI container in the same VNet as the Cosmos
    account, using the CMS API user-assigned managed identity (already granted
    Cosmos data RBAC at db scope `dbs/CMS`).

.DESCRIPTION
    Wrapper structure mirrors Test-E2E-ACI.ps1 (image, network, identity,
    base64 of inner script, polling for completion, log capture, teardown).

    Default mode is DRY-RUN. Pass -Apply to actually mutate documents.

    Idempotency: re-running after success is a no-op. The migration only
    rewrites a doc when at least one DataCategory still has `publishId` or
    `deliveryId`.

    Concurrency: every PUT carries `If-Match: <_etag>`. On 412 the doc is
    refetched once and re-applied; second 412 logs a skip.

    Guid normalization: legacy values stored in 32-char "N" format
    (e.g. "85927287c5b14c57804fa596c087a9ca") are reformatted to standard
    "D" format with dashes ("85927287-c5b1-4c57-804f-a596c087a9ca").
    Values already in D format are passed through unchanged.

.PARAMETER Environment
    Target environment. Defaults to tonym (the only NPE deploy this migration
    is currently authorized for).

.PARAMETER Apply
    Actually mutate Cosmos documents. Without this switch the migration runs
    in dry-run mode and only logs what WOULD change.

.PARAMETER CaseIdFilter
    Optional. Restrict scan to a single caseId for targeted testing.

.PARAMETER SkipCleanup
    Leave the ACI container after the migration completes (for log inspection).

.PARAMETER WhatIf
    Show what would be executed without creating any Azure resources.

.EXAMPLE
    # Default: dry-run against tonym, full container
    .\Migrate-DataCategoryJobIds-ACI.ps1

.EXAMPLE
    # Targeted dry-run for a single case
    .\Migrate-DataCategoryJobIds-ACI.ps1 -CaseIdFilter "1234ABCD"

.EXAMPLE
    # Apply for real (after dry-run review)
    .\Migrate-DataCategoryJobIds-ACI.ps1 -Apply
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet("tonym", "npe", "kcaver", "lpilat", "v-raidasilva", "v-tuliog", "v-matheusc")]
    [string]$Environment = "tonym",

    [switch]$Apply,

    [string]$CaseIdFilter,

    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

# --- Constants (mirror Test-E2E-ACI.ps1) ---
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"
$ResourceGroup = "rg-lenscms-$Environment-westus3"
$Region = "westus3"
$ContainerName = "aci-cms-migrate-jobids-$Environment"
$MiName = "id-lenscmsapi-$Environment-$Region"
$VnetName = "vnet-lenscms-$Environment-$Region"
$SubnetName = $null  # Resolved dynamically in Step 2
$Image = "mcr.microsoft.com/azure-cli:latest"
$MaxPollSeconds = 1800   # 30 min ceiling for full-container scan
$PollIntervalSeconds = 15

$Mode = if ($Apply) { "apply" } else { "dry-run" }
$ModeColor = if ($Apply) { "Red" } else { "Yellow" }

Write-Host ""
Write-Host "=== Cosmos DataCategory JobId Migration via ACI ===" -ForegroundColor Cyan
Write-Host "Environment:  $Environment"
Write-Host "Container:    $ContainerName"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Mode:           $Mode" -ForegroundColor $ModeColor
if ($CaseIdFilter) { Write-Host "CaseId filter:  $CaseIdFilter" -ForegroundColor DarkYellow }
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
Write-Host "Cosmos:         $CosmosEndpoint" -ForegroundColor Green

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

# --- Step 4: Build + base64-encode inner migration script ---
# Bash + python3 inside the azure-cli image. Pattern matches Test-CmsApi-ACI.sh
# migrate-publish-to-delivery suite (scan -> plan -> apply with If-Match).
Write-Host ""
Write-Host "--- Step 4: Build + encode inner migration script ---" -ForegroundColor Yellow

$innerScript = @'
#!/bin/bash
# Inner migration script: rename DataCategory.publishId -> publishJobId
# and DataCategory.deliveryId -> deliveryJobId on every DFT in $COSMOS_DB.Dfts.
#
# Runs inside an ACI container with a UAMI attached. Acquires a bearer token
# for the Cosmos DB resource via the IMDS-backed `az login --identity`, then
# uses the Cosmos REST API with `Authorization: type=aad&ver=1.0&sig=<token>`.
#
# DRY-RUN by default. Set MODE=apply (passed via env var) to perform PUTs.
#
# Idempotent: a doc is rewritten only when at least one category still carries
# the legacy publishId/deliveryId field. Re-run after success is a no-op.
#
# Concurrency: every PUT carries If-Match: <_etag>. On 412 the doc is refetched
# and re-applied once; second 412 logs the doc as a conflict and continues.

set -uo pipefail
# NOTE: NOT set -e: we want to handle per-doc failures and continue scanning.

MODE="${MODE:-dry-run}"
COSMOS_ENDPOINT="${COSMOS_ENDPOINT:?COSMOS_ENDPOINT is required}"
COSMOS_DB="${COSMOS_DB:-CMS}"
COSMOS_CONTAINER="${COSMOS_CONTAINER:-Dfts}"
CLIENT_ID="${CLIENT_ID:?CLIENT_ID is required}"
CASE_ID_FILTER="${CASE_ID_FILTER:-}"

echo "========================================="
echo "=== DataCategory JobId Migration ==="
echo "========================================="
echo "Mode:            $MODE"
echo "Cosmos endpoint: $COSMOS_ENDPOINT"
echo "Database:        $COSMOS_DB"
echo "Container:       $COSMOS_CONTAINER"
[ -n "$CASE_ID_FILTER" ] && echo "CaseId filter:   $CASE_ID_FILTER"
echo ""

# --- Login + token acquisition ---
echo "--- Login via UAMI (client_id=$CLIENT_ID) ---"
az login --identity --client-id "$CLIENT_ID" --output none 2>&1 || {
  echo "FATAL: az login --identity failed"
  exit 1
}

# Strip :443 from endpoint when requesting token (some tenants reject the port form).
COSMOS_RESOURCE="${COSMOS_ENDPOINT%:443}"
echo "--- Acquire Cosmos token (resource=$COSMOS_RESOURCE) ---"
COSMOS_TOKEN=$(az account get-access-token --resource "$COSMOS_RESOURCE" --query accessToken -o tsv 2>&1)
if [ -z "$COSMOS_TOKEN" ] || [ "$COSMOS_TOKEN" = "None" ]; then
  echo "FATAL: failed to acquire Cosmos token"
  echo "  Output: $COSMOS_TOKEN"
  exit 1
fi
echo "  Token acquired (${#COSMOS_TOKEN} chars)"
echo ""

# --- Step 1: Cross-partition scan, paginated ---
echo "--- Step 1: Scan $COSMOS_CONTAINER container (cross-partition, paginated) ---"
if [ -n "$CASE_ID_FILTER" ]; then
  QUERY_JSON="{\"query\":\"SELECT * FROM c WHERE c.type = \\\"dft\\\" AND c.caseId = @caseId\",\"parameters\":[{\"name\":\"@caseId\",\"value\":\"$CASE_ID_FILTER\"}]}"
else
  QUERY_JSON='{"query":"SELECT * FROM c WHERE c.type = \"dft\""}'
fi

CONT=""
PAGE=0
ACCUM_FILE=/tmp/migrate-accum-docs.json
echo '{"Documents": []}' > "$ACCUM_FILE"

while : ; do
  PAGE=$((PAGE + 1))
  CDATE=$(TZ=GMT date "+%a, %d %b %Y %H:%M:%S GMT")
  HEADERS_FILE=/tmp/migrate-resp-headers.txt
  BODY_FILE=/tmp/migrate-resp-body.json
  : > "$HEADERS_FILE"

  CONT_HEADER=()
  if [ -n "$CONT" ]; then
    CONT_HEADER=(-H "x-ms-continuation: $CONT")
  fi

  STATUS=$(curl -sS -o "$BODY_FILE" -D "$HEADERS_FILE" -w "%{http_code}" \
      -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
      -H "x-ms-date: $CDATE" \
      -H "x-ms-version: 2018-12-31" \
      -H "x-ms-documentdb-isquery: True" \
      -H "x-ms-documentdb-query-enablecrosspartition: True" \
      -H "x-ms-max-item-count: 1000" \
      -H "Content-Type: application/query+json" \
      "${CONT_HEADER[@]}" \
      -X POST "${COSMOS_ENDPOINT}/dbs/${COSMOS_DB}/colls/${COSMOS_CONTAINER}/docs" \
      -d "$QUERY_JSON" 2>&1)

  if [ "$STATUS" != "200" ]; then
    echo "  FATAL: Cosmos query failed page=$PAGE HTTP $STATUS"
    echo "  Body: $(head -c 600 "$BODY_FILE")"
    exit 1
  fi

  PAGE_COUNT=$(python3 -c "import json;print(len(json.load(open('$BODY_FILE')).get('Documents',[])))" 2>/dev/null || echo 0)
  echo "  page $PAGE: returned $PAGE_COUNT docs"

  python3 -c "
import json
with open('$ACCUM_FILE') as f: acc = json.load(f)
with open('$BODY_FILE') as f: pg  = json.load(f)
acc['Documents'].extend(pg.get('Documents', []))
with open('$ACCUM_FILE', 'w') as f: json.dump(acc, f)
" 2>&1

  CONT=$(grep -i "^x-ms-continuation:" "$HEADERS_FILE" | sed 's/^[Xx]-[Mm][Ss]-[Cc]ontinuation:[[:space:]]*//' | tr -d '\r\n' || true)
  if [ -z "$CONT" ]; then
    break
  fi
done

TOTAL=$(python3 -c "import json;print(len(json.load(open('$ACCUM_FILE')).get('Documents',[])))" 2>/dev/null || echo 0)
echo "  Total docs accumulated across $PAGE page(s): $TOTAL"
echo ""

# --- Step 2: Plan + (optionally) apply per doc ---
echo "--- Step 2: Per-doc analysis (mode=$MODE) ---"

# A single python invocation does the planning. We capture each doc's intended
# mutated payload to a per-doc file under /tmp/migrate-mutated/<id>.json so the
# bash apply loop can PUT them with If-Match. Dry-run skips the writes but still
# emits the plan.

PLAN_FILE=/tmp/migrate-plan.json
mkdir -p /tmp/migrate-mutated
python3 - "$ACCUM_FILE" "$PLAN_FILE" /tmp/migrate-mutated <<'PYEOF'
import json, os, re, sys, uuid

accum_path, plan_path, mutated_dir = sys.argv[1], sys.argv[2], sys.argv[3]

GUID_N_RE = re.compile(r'^[0-9a-fA-F]{32}$')

def normalize_guid(v):
    """Return Guid in D-format (with dashes). Generate a fresh Guid for
    legacy non-Guid values (e.g. seed strings like 'pub-001') so the
    new Guid? entity field can deserialize them.
    - 32-char hex (N format) -> reformat to D
    - Already-D-format Guid -> pass through (after uuid round-trip for canonicalization)
    - Anything else (None, non-string, non-Guid string) -> generate new Guid"""
    if isinstance(v, str):
        if GUID_N_RE.match(v):
            return str(uuid.UUID(v))
        try:
            return str(uuid.UUID(v))
        except (ValueError, AttributeError):
            return str(uuid.uuid4())
    return str(uuid.uuid4())

with open(accum_path) as f:
    docs = json.load(f).get('Documents', [])

totals = {
    'docs_scanned': len(docs),
    'docs_needing_migration': 0,
    'cats_with_publishId': 0,
    'cats_with_deliveryId': 0,
    'guid_renormalized': 0,
}
plans = []

for doc in docs:
    doc_id  = doc.get('id')
    case_id = doc.get('caseId')
    etag    = doc.get('_etag')
    dcs = doc.get('dataCategories') or {}
    if not isinstance(dcs, dict):
        continue

    changed = False
    cat_summaries = []

    for key, cat in list(dcs.items()):
        if not isinstance(cat, dict):
            continue
        cat_action = []

        # publishId -> publishJobId
        if isinstance(cat.get('publishId'), str) and cat['publishId']:
            raw = cat['publishId']
            new_v = normalize_guid(raw)
            if new_v != raw:
                totals['guid_renormalized'] += 1
            cat['publishJobId'] = new_v
            del cat['publishId']
            totals['cats_with_publishId'] += 1
            cat_action.append(f"publishId={raw!r} -> publishJobId={new_v!r}")
            changed = True

        # deliveryId -> deliveryJobId
        if isinstance(cat.get('deliveryId'), str) and cat['deliveryId']:
            raw = cat['deliveryId']
            new_v = normalize_guid(raw)
            if new_v != raw:
                totals['guid_renormalized'] += 1
            cat['deliveryJobId'] = new_v
            del cat['deliveryId']
            totals['cats_with_deliveryId'] += 1
            cat_action.append(f"deliveryId={raw!r} -> deliveryJobId={new_v!r}")
            changed = True

        if cat_action:
            cat_summaries.append({'key': key, 'actions': cat_action})

    if changed:
        totals['docs_needing_migration'] += 1
        # Write the mutated doc to per-doc file for the bash apply loop.
        # Cosmos REST PUT replaces the doc; we keep all other fields intact.
        out_path = os.path.join(mutated_dir, f"{doc_id}.json")
        with open(out_path, 'w') as f:
            json.dump(doc, f)
        plans.append({
            'id': doc_id,
            'caseId': case_id,
            'etag': etag,
            'cat_summaries': cat_summaries,
            'mutated_path': out_path,
        })

with open(plan_path, 'w') as f:
    json.dump({'totals': totals, 'plans': plans}, f, indent=2)

print(f"  Docs scanned                   : {totals['docs_scanned']}")
print(f"  Docs needing migration         : {totals['docs_needing_migration']}")
print(f"  Categories with publishId      : {totals['cats_with_publishId']}")
print(f"  Categories with deliveryId     : {totals['cats_with_deliveryId']}")
print(f"  Guid values renormalized (N->D): {totals['guid_renormalized']}")
PYEOF

echo ""
echo "--- Step 3: Plan detail ---"
python3 - "$PLAN_FILE" <<'PYEOF'
import json, sys
plan = json.load(open(sys.argv[1]))
for p in plan['plans']:
    print(f"  {p['caseId']} / {p['id']} (etag={p['etag']})")
    for s in p['cat_summaries']:
        for a in s['actions']:
            print(f"    cat[{s['key']}]: {a}")
PYEOF

if [ "$MODE" != "apply" ]; then
  echo ""
  echo "--- DRY-RUN: no Cosmos mutations performed ---"
  echo "Re-run with -Apply (wrapper) / MODE=apply (inner) to execute the planned ops."
  exit 0
fi

echo ""
echo "--- Step 4: Applying Cosmos PUT replaces (mode=apply) ---"
APPLIED=0
SKIPPED=0
CONFLICTS=0
FAILED=0

# Iterate plans via python -> JSON Lines so bash can read line-by-line.
PLAN_LINES=/tmp/migrate-plan.lines
python3 -c "
import json, sys
plan = json.load(open('$PLAN_FILE'))
for p in plan['plans']:
    print(json.dumps(p))
" > "$PLAN_LINES"

while IFS= read -r line; do
  [ -z "$line" ] && continue
  DOC_ID=$(echo "$line"   | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")
  CASE_ID=$(echo "$line"  | python3 -c "import json,sys;print(json.load(sys.stdin)['caseId'])")
  ETAG=$(echo "$line"     | python3 -c "import json,sys;print(json.load(sys.stdin)['etag'])")
  MUTATED_PATH=$(echo "$line" | python3 -c "import json,sys;print(json.load(sys.stdin)['mutated_path'])")

  P_DATE=$(TZ=GMT date "+%a, %d %b %Y %H:%M:%S GMT")
  P_RESP_FILE=/tmp/migrate-put-resp.json
  P_HEADERS_FILE=/tmp/migrate-put-headers.txt
  : > "$P_HEADERS_FILE"

  P_STATUS=$(curl -sS -o "$P_RESP_FILE" -D "$P_HEADERS_FILE" -w "%{http_code}" \
      -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
      -H "x-ms-date: $P_DATE" \
      -H "x-ms-version: 2018-12-31" \
      -H "x-ms-documentdb-partitionkey: [\"$CASE_ID\"]" \
      -H "If-Match: $ETAG" \
      -H "Content-Type: application/json" \
      -X PUT "${COSMOS_ENDPOINT}/dbs/${COSMOS_DB}/colls/${COSMOS_CONTAINER}/docs/$DOC_ID" \
      --data-binary "@$MUTATED_PATH" 2>&1)

  if [ "$P_STATUS" = "200" ]; then
    APPLIED=$((APPLIED + 1))
    echo "  [OK]      $CASE_ID / $DOC_ID  (HTTP 200)"
    continue
  fi

  if [ "$P_STATUS" = "401" ]; then
    echo "  [FATAL]   $CASE_ID / $DOC_ID  (HTTP 401 - UAMI auth issue, aborting)"
    echo "  Body: $(head -c 600 "$P_RESP_FILE")"
    exit 1
  fi

  if [ "$P_STATUS" = "412" ]; then
    # Refetch + retry once
    echo "  [412]     $CASE_ID / $DOC_ID  - refetch + retry"
    R_DATE=$(TZ=GMT date "+%a, %d %b %Y %H:%M:%S GMT")
    R_BODY_FILE=/tmp/migrate-refetch-body.json
    R_STATUS=$(curl -sS -o "$R_BODY_FILE" -w "%{http_code}" \
        -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
        -H "x-ms-date: $R_DATE" \
        -H "x-ms-version: 2018-12-31" \
        -H "x-ms-documentdb-partitionkey: [\"$CASE_ID\"]" \
        -X GET "${COSMOS_ENDPOINT}/dbs/${COSMOS_DB}/colls/${COSMOS_CONTAINER}/docs/$DOC_ID" 2>&1)
    if [ "$R_STATUS" != "200" ]; then
      echo "    Refetch failed HTTP $R_STATUS - skip"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    # Re-apply migration to the freshly fetched doc, get its new etag.
    NEW_PATH=/tmp/migrate-mutated/${DOC_ID}.retry.json
    python3 - "$R_BODY_FILE" "$NEW_PATH" <<'PYRETRY'
import json, re, sys, uuid
GUID_N_RE = re.compile(r'^[0-9a-fA-F]{32}$')
def normalize_guid(v):
    if not isinstance(v, str):
        return v
    if GUID_N_RE.match(v):
        return str(uuid.UUID(v))
    return v
src, dst = sys.argv[1], sys.argv[2]
doc = json.load(open(src))
dcs = doc.get('dataCategories') or {}
changed = False
if isinstance(dcs, dict):
    for key, cat in list(dcs.items()):
        if not isinstance(cat, dict):
            continue
        if isinstance(cat.get('publishId'), str) and cat['publishId']:
            cat['publishJobId'] = normalize_guid(cat['publishId'])
            del cat['publishId']
            changed = True
        if isinstance(cat.get('deliveryId'), str) and cat['deliveryId']:
            cat['deliveryJobId'] = normalize_guid(cat['deliveryId'])
            del cat['deliveryId']
            changed = True
print('changed' if changed else 'noop', doc.get('_etag'))
with open(dst, 'w') as f:
    json.dump(doc, f)
PYRETRY

    NEW_ETAG=$(python3 -c "import json;print(json.load(open('$R_BODY_FILE')).get('_etag',''))")
    if [ -z "$NEW_ETAG" ]; then
      echo "    Refetched doc has no _etag - skip"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    R2_DATE=$(TZ=GMT date "+%a, %d %b %Y %H:%M:%S GMT")
    R2_RESP_FILE=/tmp/migrate-put-retry-resp.json
    R2_STATUS=$(curl -sS -o "$R2_RESP_FILE" -w "%{http_code}" \
        -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
        -H "x-ms-date: $R2_DATE" \
        -H "x-ms-version: 2018-12-31" \
        -H "x-ms-documentdb-partitionkey: [\"$CASE_ID\"]" \
        -H "If-Match: $NEW_ETAG" \
        -H "Content-Type: application/json" \
        -X PUT "${COSMOS_ENDPOINT}/dbs/${COSMOS_DB}/colls/${COSMOS_CONTAINER}/docs/$DOC_ID" \
        --data-binary "@$NEW_PATH" 2>&1)

    if [ "$R2_STATUS" = "200" ]; then
      APPLIED=$((APPLIED + 1))
      echo "    [OK retry] HTTP 200"
    elif [ "$R2_STATUS" = "412" ]; then
      CONFLICTS=$((CONFLICTS + 1))
      echo "    [CONFLICT] second 412 - giving up on this doc"
    else
      FAILED=$((FAILED + 1))
      echo "    [FAIL retry] HTTP $R2_STATUS - $(head -c 300 "$R2_RESP_FILE")"
    fi
    continue
  fi

  FAILED=$((FAILED + 1))
  echo "  [FAIL]    $CASE_ID / $DOC_ID  (HTTP $P_STATUS): $(head -c 300 "$P_RESP_FILE")"

done < "$PLAN_LINES"

echo ""
echo "========================================="
echo "=== Migration summary ==="
echo "========================================="
TOTAL_PLANNED=$(python3 -c "import json;print(len(json.load(open('$PLAN_FILE'))['plans']))")
echo "  Docs needing migration  : $TOTAL_PLANNED"
echo "  Docs migrated (applied) : $APPLIED"
echo "  Docs skipped (refetch)  : $SKIPPED"
echo "  Docs conflicted (2x412) : $CONFLICTS"
echo "  Docs failed             : $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
'@

# Base64 encode the inner script for safe transport via env vars.
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

if ($PSCmdlet.ShouldProcess($ContainerName, "Create ACI container running migration ($Mode)")) {
    $envVars = [System.Collections.ArrayList]::new()
    [void]$envVars.Add(@{ name = "CLIENT_ID";       value = $mi.clientId })
    [void]$envVars.Add(@{ name = "COSMOS_ENDPOINT"; value = $CosmosEndpoint })
    [void]$envVars.Add(@{ name = "COSMOS_DB";       value = "CMS" })
    [void]$envVars.Add(@{ name = "COSMOS_CONTAINER"; value = "Dfts" })
    [void]$envVars.Add(@{ name = "MODE";            value = $Mode })
    if ($CaseIdFilter) {
        [void]$envVars.Add(@{ name = "CASE_ID_FILTER"; value = $CaseIdFilter })
    }
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
                                memoryInGb = 2
                            }
                        }
                        environmentVariables = @($envVars)
                        command = @("bash", "-c", 'n="$TEST_SCRIPT_CHUNKS"; for i in $(seq 1 "$n"); do v="TEST_SCRIPT_B64_$i"; printf "%s" "${!v}"; done | base64 -d | tr -d "\r" | bash')
                    }
                }
            )
        }
    }

    $jsonPath = "$env:TEMP\aci-cms-migrate-jobids-$Environment.json"
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
    Write-Host "  Mode:     $Mode" -ForegroundColor DarkYellow
    if ($CaseIdFilter) { Write-Host "  CaseId:   $CaseIdFilter" -ForegroundColor DarkYellow }
    Write-Host ""
    Write-Host "=== DRY RUN COMPLETE (Azure-side; the container itself was not created) ===" -ForegroundColor Cyan
    exit 0
}

# --- Step 6: Poll for completion ---
Write-Host ""
Write-Host "--- Step 6: Waiting for migration to complete ---" -ForegroundColor Yellow
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

# --- Step 7: Capture logs ---
Write-Host ""
Write-Host "--- Step 7: Migration output ---" -ForegroundColor Yellow
$logs = az container logs `
    --name $ContainerName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId 2>&1

# Persist logs alongside other migration artifacts.
$logTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path (Join-Path $PSScriptRoot "..") "scratch"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "cosmos-migration-$Environment-$Mode-$logTimestamp.log"
$logs | Out-File -FilePath $logFile -Encoding utf8
Write-Host "Logs saved to: $logFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host $logs

# --- Step 8: Cleanup ---
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "--- Step 8: Cleanup ---" -ForegroundColor Yellow
    az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
    Write-Host "Container deleted." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "--- Skipping cleanup (use -SkipCleanup to retain container) ---" -ForegroundColor DarkYellow
}

# --- Result ---
Write-Host ""
if ($null -eq $containerExitCode) {
    Write-Host "=== MIGRATION INCONCLUSIVE (state: $state) ===" -ForegroundColor Yellow
    exit 2
} elseif ($containerExitCode -eq 0) {
    Write-Host "=== MIGRATION SUCCEEDED (Mode: $Mode) ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== MIGRATION FAILED (Mode: $Mode, exit code: $containerExitCode) ===" -ForegroundColor Red
    Write-Host "Review log at: $logFile"
    exit 1
}
