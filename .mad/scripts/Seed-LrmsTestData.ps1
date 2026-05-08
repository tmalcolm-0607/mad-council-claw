<#
.SYNOPSIS
    Seed comprehensive test data for LRMS UX testing via CMS API.

.DESCRIPTION
    Creates 12 diverse cases with notes, events, and communications.
    Designed to populate the tonym environment for LRMS end-to-end testing.

    When -UseAci is specified, runs the seed logic inside an ACI container with
    Managed Identity (MI) for authentication, bypassing the MISE v2 restriction
    that rejects delegated user tokens.

.PARAMETER BaseUrl
    CMS API base URL (default: tonym environment).

.PARAMETER Token
    Pre-acquired Bearer token. If not provided, acquires one via az CLI.
    Ignored when -UseAci is specified.

.PARAMETER Resource
    OAuth2 resource URI for token acquisition. Used by both local and ACI modes.

.PARAMETER UseAci
    Run seed logic inside an ACI container with Managed Identity for
    service-to-service auth (required when CMS rejects delegated user tokens).

.PARAMETER Environment
    Target environment for ACI mode: tonym, npe. Controls which RG/VNet/MI to use.
    Default: tonym.

.PARAMETER SkipCleanup
    Leave the ACI container after seeding completes (for log inspection).
    Only applies when -UseAci is specified.

.PARAMETER CleanFirst
    If set, deletes existing cases before seeding (not implemented - Cosmos has no bulk delete API).

.EXAMPLE
    .\Seed-LrmsTestData.ps1
    .\Seed-LrmsTestData.ps1 -BaseUrl "https://app-cms-npe-westus3.azurewebsites.net"
    .\Seed-LrmsTestData.ps1 -UseAci -Environment tonym
    .\Seed-LrmsTestData.ps1 -UseAci -Environment npe -SkipCleanup
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = "https://app-cms-tonym-westus3.azurewebsites.net",
    [string]$Token,
    [string]$Resource = "api://6c5a00ce-8062-49d8-b568-b9bd0363340b",

    [switch]$UseAci,

    [ValidateSet("tonym", "npe")]
    [string]$Environment = "tonym",

    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

# ============================================================
# ACI Mode: Deploy seed logic to a VNet-injected ACI container
# with Managed Identity for service-to-service auth
# ============================================================
if ($UseAci) {
    $SubscriptionId = 'd27c8315-7947-43ea-88ed-1f1c34860559'
    $ResourceGroup = "rg-lenscms-$Environment"
    $Region = 'westus3'
    $ContainerName = "aci-cms-seed-$Environment"
    $MiName = "id-cms-$Environment-$Region"
    $VnetName = "vnet-cms-$Environment-$Region"
    $SubnetName = 'snet-aci'
    $Image = 'mcr.microsoft.com/azure-cli:latest'
    $MaxPollSeconds = 600
    $PollIntervalSeconds = 15
    $CmsBaseUrl = "https://app-cms-$Environment-${Region}.azurewebsites.net"

    Write-Host ''
    Write-Host '=== LRMS Test Data Seeder (ACI Mode) ===' -ForegroundColor Cyan
    Write-Host "Environment:    $Environment"
    Write-Host "Container:      $ContainerName"
    Write-Host "Resource Group: $ResourceGroup"
    Write-Host "CMS Base URL:   $CmsBaseUrl"
    Write-Host ''

    # --- Step 1: Resolve managed identity ---
    Write-Host '--- Step 1: Resolve managed identity ---' -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    $mi = az identity show `
        --name $MiName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --query "{id: id, clientId: clientId}" `
        --output json 2>&1 | ConvertFrom-Json
    $ErrorActionPreference = 'Stop'

    if (-not $mi.id) {
        Write-Host "ERROR: Could not find managed identity '$MiName' in '$ResourceGroup'" -ForegroundColor Red
        exit 1
    }
    Write-Host "MI Resource ID: $($mi.id)" -ForegroundColor Green
    Write-Host "MI Client ID:   $($mi.clientId)" -ForegroundColor Green

    # --- Step 2: Resolve ACI subnet ---
    Write-Host ''
    Write-Host '--- Step 2: Resolve ACI subnet ---' -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    $subnetId = az network vnet subnet show `
        --name $SubnetName `
        --vnet-name $VnetName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --query "id" -o tsv 2>&1
    $ErrorActionPreference = 'Stop'

    if (-not $subnetId -or $subnetId -like '*ERROR*') {
        Write-Host "ERROR: Could not find subnet '$SubnetName' in VNet '$VnetName'" -ForegroundColor Red
        exit 1
    }
    Write-Host "Subnet ID: $subnetId" -ForegroundColor Green

    # --- Step 3: Delete existing container (if any) ---
    Write-Host ''
    Write-Host '--- Step 3: Delete existing container (if any) ---' -ForegroundColor Yellow
    $existing = $null
    $ErrorActionPreference = 'Continue'
    try { $existing = az container show --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --query "name" -o tsv 2>$null } catch { }
    $ErrorActionPreference = 'Stop'
    if ($existing) {
        $ErrorActionPreference = 'Continue'
        az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
        Write-Host 'Deleted existing container.' -ForegroundColor DarkYellow
    } else {
        Write-Host 'No existing container found.' -ForegroundColor DarkYellow
    }

    # --- Step 4: Build and encode seed bash script ---
    Write-Host ''
    Write-Host '--- Step 4: Build and encode seed bash script ---' -ForegroundColor Yellow

    # Build the self-contained bash script that runs inside ACI
    # It acquires an MI token via IMDS and POSTs case creation requests via curl
    $seedBash = @'
#!/bin/bash
set -euo pipefail

CMS_BASE_URL="$1"
MI_CLIENT_ID="$2"
RESOURCE="$3"

echo "=== LRMS Test Data Seeder (ACI) ==="
echo "CMS Base URL: $CMS_BASE_URL"
echo "MI Client ID: $MI_CLIENT_ID"
echo "Resource:     $RESOURCE"
echo ""

# --- Acquire MI token via IMDS ---
echo "--- Acquiring MI token via IMDS ---"
TOKEN_RESPONSE=$(curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=${RESOURCE}&client_id=${MI_CLIENT_ID}")

TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || true)
if [ -z "$TOKEN" ]; then
    # Fallback: try with grep/sed if python3 not available
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"$//')
fi

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to acquire MI token"
    echo "IMDS response: $TOKEN_RESPONSE"
    exit 1
fi
echo "Token acquired (${#TOKEN} chars)"
echo ""

# --- Helper: POST to CMS API ---
CREATED=0
FAILED=0

post_case() {
    local BODY="$1"
    local TITLE="$2"
    local IDEMPOTENCY_KEY
    IDEMPOTENCY_KEY=$(cat /proc/sys/kernel/random/uuid)

    echo -n "  Creating case: ${TITLE}..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "${CMS_BASE_URL}/api/v1/cases" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
        -d "$BODY")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    RESP_BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        CASE_ID=$(echo "$RESP_BODY" | grep -o '"caseId":"[^"]*"' | head -1 | sed 's/"caseId":"//;s/"$//')
        ETAG=$(echo "$RESP_BODY" | grep -o '"etag":"[^"]*"' | head -1 | sed 's/"etag":"//;s/"$//')
        if [ -z "$ETAG" ]; then
            ETAG=$(echo "$RESP_BODY" | grep -o '"eTag":"[^"]*"' | head -1 | sed 's/"eTag":"//;s/"$//')
        fi
        echo " OK -> ${CASE_ID}"
        CREATED=$((CREATED + 1))

        # Return caseId and etag for downstream use
        echo "RESULT:${CASE_ID}:${ETAG}"
    else
        echo " FAILED (HTTP ${HTTP_CODE})"
        echo "  ${RESP_BODY}"
        FAILED=$((FAILED + 1))
        echo "RESULT:FAILED:"
    fi
}

patch_assignee() {
    local CASE_ID="$1"
    local ETAG="$2"
    local ASSIGNEE="$3"

    local PATCH_BODY="[{\"op\":\"replace\",\"path\":\"/assignee\",\"value\":\"${ASSIGNEE}\"}]"
    local IDEMPOTENCY_KEY
    IDEMPOTENCY_KEY=$(cat /proc/sys/kernel/random/uuid)

    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH \
        "${CMS_BASE_URL}/api/v1/cases/${CASE_ID}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -H "If-Match: ${ETAG}" \
        -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
        -d "$PATCH_BODY")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        echo "    + Assigned to ${ASSIGNEE}"
    else
        echo "    ! PATCH assignee failed (HTTP ${HTTP_CODE})"
    fi
}

post_sub_entity() {
    local CASE_ID="$1"
    local ENTITY_TYPE="$2"
    local BODY="$3"
    local LABEL="$4"

    local IDEMPOTENCY_KEY
    IDEMPOTENCY_KEY=$(cat /proc/sys/kernel/random/uuid)

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "${CMS_BASE_URL}/api/v1/cases/${CASE_ID}/${ENTITY_TYPE}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
        -d "$BODY")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        echo "    + ${LABEL}"
    else
        echo "    ! ${LABEL} failed (HTTP ${HTTP_CODE})"
    fi
}

# --- Health Check ---
echo "--- Health Check ---"
HC_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${CMS_BASE_URL}/api/health")
if [ "$HC_CODE" -ge 200 ] && [ "$HC_CODE" -lt 300 ]; then
    echo "CMS API is healthy."
else
    echo "Health check returned ${HC_CODE} - continuing anyway."
fi
echo ""

# --- Case Definitions (JSON bodies) ---
echo "--- Creating Cases ---"

CASES=(
'{"requestType":"IREQ","title":"International Request - German BKA Investigation","description":"Request from BKA for Microsoft account data related to organized crime investigation.","priority":"Standard","jurisdiction":"DE","country":"DE","leReferenceNumber":"BKA-2026-00142"}'
'{"requestType":"EmergencyLetter","title":"Emergency - Imminent Threat to Life (FBI)","description":"Emergency disclosure request involving imminent threat to life.","priority":"Emergency","jurisdiction":"US-FED","country":"US","leReferenceNumber":"FBI-2026-EM-0087"}'
'{"requestType":"CourtOrder","title":"UK NCA Court Order - Child Safety Investigation","description":"Court order from UK NCA for content and metadata.","priority":"Urgent","jurisdiction":"GB","country":"GB","leReferenceNumber":"NCA-2026-CO-0034"}'
'{"requestType":"SearchWarrant","title":"NYPD Search Warrant - Financial Fraud","description":"State-level search warrant for email communications.","priority":"Standard","jurisdiction":"US-NY","country":"US","leReferenceNumber":"NYPD-2026-SW-1122"}'
'{"requestType":"SubpoenaSummons","title":"RCMP Subpoena - Cybercrime","description":"Canadian RCMP subpoena for subscriber information.","priority":"Standard","jurisdiction":"CA","country":"CA","leReferenceNumber":"RCMP-2026-SP-0219"}'
'{"requestType":"Preservation","title":"France DGSI Preservation - Terrorism","description":"Urgent preservation request from French intelligence.","priority":"Urgent","jurisdiction":"FR","country":"FR","leReferenceNumber":"DGSI-2026-PR-0056"}'
'{"requestType":"InternationalOrder","title":"India CBI Request - Human Trafficking","description":"International request from India CBI for communications data.","priority":"Standard","jurisdiction":"IN","country":"IN","agentFirstName":"Rajesh","agentLastName":"Kumar","agentEmail":"rajesh.kumar@cbi.gov.in","internationalJurisdiction":"IN-MH","leReferenceNumber":"CBI-2025-IR-0891"}'
'{"requestType":"EmergencyLetter","title":"Emergency - AFP Missing Person (Australia)","description":"Emergency disclosure for AFP regarding missing person case.","priority":"Emergency","jurisdiction":"AU","country":"AU","leReferenceNumber":"AFP-2026-EM-0031"}'
'{"requestType":"CourtOrder","title":"Japan NPA Court Order - Cyber Espionage","description":"Court order from Japan NPA for Azure AD and Exchange data.","priority":"Standard","jurisdiction":"JP","country":"JP","leReferenceNumber":"NPA-2025-CO-0467"}'
'{"requestType":"NSL","title":"National Security Letter - Counterintelligence","description":"National Security Letter for subscriber and transactional data.","priority":"Urgent","jurisdiction":"US-FED","country":"US","leReferenceNumber":"FBI-2026-NSL-0178"}'
'{"requestType":"ConsentRelease","title":"USSS Consent Release - Account Compromise","description":"Voluntary consent release for Secret Service investigation.","priority":"Standard","jurisdiction":"US-FED","country":"US","leReferenceNumber":"USSS-2026-VD-0044"}'
'{"requestType":"Preservation","title":"Germany BKA Preservation - Ransomware","description":"Urgent preservation for BKA regarding ransomware attack.","priority":"Urgent","jurisdiction":"DE","country":"DE","leReferenceNumber":"BKA-2026-AP-0023"}'
)

TITLES=(
"International Request - German BKA Investigation"
"Emergency - Imminent Threat to Life (FBI)"
"UK NCA Court Order - Child Safety Investigation"
"NYPD Search Warrant - Financial Fraud"
"RCMP Subpoena - Cybercrime"
"France DGSI Preservation - Terrorism"
"India CBI Request - Human Trafficking"
"Emergency - AFP Missing Person (Australia)"
"Japan NPA Court Order - Cyber Espionage"
"National Security Letter - Counterintelligence"
"USSS Consent Release - Account Compromise"
"Germany BKA Preservation - Ransomware"
)

ASSIGNEES=(
"Sarah Johnson"
"Michael Chen"
"Emily Rodriguez"
"David Kim"
""
"Anna Mueller"
"James Wilson"
""
"Yuki Tanaka"
"Carlos Silva"
"Lisa Park"
"Thomas Weber"
)

# Note templates (JSON)
NOTE_TEMPLATES=(
'{"noteType":"General","content":"Initial case review completed. All required documentation has been received and verified.","isInternal":false}'
'{"noteType":"Triage","content":"Triage assessment: Request scope includes email metadata and account activity logs.","isInternal":true}'
'{"noteType":"Fulfillment","content":"Data extraction initiated. Querying relevant data sources for the identifiers specified.","isInternal":true}'
'{"noteType":"Attorney","content":"Legal review confirms the request meets jurisdictional requirements.","isInternal":true}'
'{"noteType":"Escalation","content":"Escalated to senior analyst due to request complexity.","isInternal":true}'
'{"noteType":"General","content":"Requestor contacted via secure portal to clarify the date range.","isInternal":false}'
)

NOTE_LABELS=("Note (General)" "Note (Triage)" "Note (Fulfillment)" "Note (Attorney)" "Note (Escalation)" "Note (General)")

# Event templates (JSON)
# IMPORTANT: Only "NoteAdded" is in the ExplicitlyCreatableTypes whitelist.
# All other types (StageChange, Assignment, etc.) are system-generated and return 400.
EVENT_TEMPLATES=(
'{"eventType":"NoteAdded","details":{"context":"Initial triage assessment completed"}}'
'{"eventType":"NoteAdded","details":{"context":"Legal review note added to case file"}}'
'{"eventType":"NoteAdded","details":{"context":"Escalation note: senior analyst review required"}}'
'{"eventType":"NoteAdded","details":{"context":"Fulfillment progress update recorded"}}'
'{"eventType":"NoteAdded","details":{"context":"Data collection milestone reached"}}'
'{"eventType":"NoteAdded","details":{"context":"Jurisdiction verification note added"}}'
)

EVENT_LABELS=("Event (NoteAdded)" "Event (NoteAdded)" "Event (NoteAdded)" "Event (NoteAdded)" "Event (NoteAdded)" "Event (NoteAdded)")

# Communication templates (JSON)
COMM_TEMPLATES=(
'{"direction":"Outbound","channel":"Portal","communicationType":"LECorrespondence","subject":"Request Acknowledgment - Case Received","body":"Thank you for your submission."}'
'{"direction":"Inbound","channel":"Portal","communicationType":"LECorrespondence","subject":"Additional Documentation Provided","body":"Please find attached the supplemental court order."}'
'{"direction":"Outbound","channel":"Email","communicationType":"RedirectNotice","subject":"Request Redirect - Jurisdiction Notice","body":"A portion of the data falls under a different jurisdiction."}'
'{"direction":"Outbound","channel":"Portal","communicationType":"UserNotification","subject":"Data Production Ready for Review","body":"The data production for your request is complete."}'
'{"direction":"Outbound","channel":"Portal","communicationType":"RejectionNotice","subject":"Request Returned - Insufficient Legal Process","body":"The submitted request does not meet threshold requirements."}'
)

COMM_LABELS=("Comm (LECorrespondence)" "Comm (LECorrespondence)" "Comm (RedirectNotice)" "Comm (UserNotification)" "Comm (RejectionNotice)")

TOTAL=${#CASES[@]}
CASE_IDS=()

for i in $(seq 0 $((TOTAL - 1))); do
    # Throttle: 2 second delay between cases
    if [ "$i" -gt 0 ]; then sleep 2; fi

    IDX=$((i + 1))
    echo "[$IDX/$TOTAL]"

    OUTPUT=$(post_case "${CASES[$i]}" "${TITLES[$i]}")
    echo "$OUTPUT" | grep -v "^RESULT:"

    RESULT_LINE=$(echo "$OUTPUT" | grep "^RESULT:" || true)
    CASE_ID=$(echo "$RESULT_LINE" | cut -d: -f2)
    ETAG=$(echo "$RESULT_LINE" | cut -d: -f3)

    if [ "$CASE_ID" != "FAILED" ] && [ -n "$CASE_ID" ]; then
        CASE_IDS+=("$CASE_ID")

        # PATCH assignee
        ASSIGNEE="${ASSIGNEES[$((i % ${#ASSIGNEES[@]}))]}"
        if [ -n "$ASSIGNEE" ]; then
            patch_assignee "$CASE_ID" "$ETAG" "$ASSIGNEE"
        fi

        # Add 2-3 notes per case
        NOTE_COUNT=$((2 + (i % 2)))
        for n in $(seq 0 $((NOTE_COUNT - 1))); do
            NOTE_IDX=$(( (i * 3 + n) % ${#NOTE_TEMPLATES[@]} ))
            # Inject caseId into the note body
            NOTE_BODY=$(echo "${NOTE_TEMPLATES[$NOTE_IDX]}" | sed "s/}$/,\"caseId\":\"${CASE_ID}\"}/")
            post_sub_entity "$CASE_ID" "notes" "$NOTE_BODY" "${NOTE_LABELS[$NOTE_IDX]}"
        done

        # Add 1-2 events per case
        EVENT_COUNT=$((1 + (i % 2)))
        for e in $(seq 0 $((EVENT_COUNT - 1))); do
            EVENT_IDX=$(( (i * 2 + e) % ${#EVENT_TEMPLATES[@]} ))
            post_sub_entity "$CASE_ID" "events" "${EVENT_TEMPLATES[$EVENT_IDX]}" "${EVENT_LABELS[$EVENT_IDX]}"
        done

        # Add 1-2 communications per case
        COMM_COUNT=$((1 + ((i + 1) % 2)))
        for c in $(seq 0 $((COMM_COUNT - 1))); do
            COMM_IDX=$(( (i * 2 + c) % ${#COMM_TEMPLATES[@]} ))
            # Inject caseId into the comm body
            COMM_BODY=$(echo "${COMM_TEMPLATES[$COMM_IDX]}" | sed "s/}$/,\"caseId\":\"${CASE_ID}\"}/")
            post_sub_entity "$CASE_ID" "communications" "$COMM_BODY" "${COMM_LABELS[$COMM_IDX]}"
        done

        echo ""
    fi
done

# --- Summary ---
echo ""
echo "=== Seed Summary ==="
echo "Created: ${CREATED} / ${TOTAL} cases"

if [ ${#CASE_IDS[@]} -gt 0 ]; then
    echo ""
    echo "Case IDs:"
    for cid in "${CASE_IDS[@]}"; do
        echo "  $cid"
    done
fi

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "Failed: ${FAILED} cases"
fi

echo ""
echo "Done."

if [ "$FAILED" -gt 0 ]; then exit 1; fi
exit 0
'@

    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($seedBash))
    Write-Host "Encoded seed script ($($b64.Length) chars)" -ForegroundColor Green

    # --- Step 5: Create ACI container ---
    Write-Host ''
    Write-Host '--- Step 5: Create ACI container ---' -ForegroundColor Yellow

    $aciBody = @{
        location = $Region
        identity = @{
            type = 'UserAssigned'
            userAssignedIdentities = @{
                $mi.id = @{}
            }
        }
        properties = @{
            subnetIds = @(
                @{ id = $subnetId }
            )
            restartPolicy = 'Never'
            osType = 'Linux'
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
                        environmentVariables = @(
                            @{ name = 'CMS_BASE_URL'; value = $CmsBaseUrl }
                            @{ name = 'MI_CLIENT_ID'; value = $mi.clientId }
                            @{ name = 'RESOURCE'; value = $Resource }
                            @{ name = 'SEED_SCRIPT_B64'; value = $b64 }
                        )
                        command = @('bash', '-c', 'echo $SEED_SCRIPT_B64 | base64 -d | tr -d "\r" | bash -s "$CMS_BASE_URL" "$MI_CLIENT_ID" "$RESOURCE"')
                    }
                }
            )
        }
    }

    $jsonPath = "$env:TEMP\aci-cms-seed.json"
    $aciBody | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8

    $aciUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerInstance/containerGroups/${ContainerName}?api-version=2023-05-01"

    $ErrorActionPreference = 'Continue'
    az rest --method PUT --url $aciUrl --body "@$jsonPath" --output none 2>&1
    $aciExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    Remove-Item $jsonPath -ErrorAction SilentlyContinue

    if ($aciExitCode -ne 0) {
        Write-Host 'ERROR: Failed to create ACI container' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Container created.' -ForegroundColor Green

    # --- Step 6: Poll for completion ---
    Write-Host ''
    Write-Host '--- Step 6: Waiting for seed to complete ---' -ForegroundColor Yellow
    $elapsed = 0
    $state = 'Running'

    while ($state -eq 'Running' -or $state -eq 'Waiting' -or $state -eq 'Pending') {
        Start-Sleep -Seconds $PollIntervalSeconds
        $elapsed += $PollIntervalSeconds

        $ErrorActionPreference = 'Continue'
        $state = az container show `
            --name $ContainerName `
            --resource-group $ResourceGroup `
            --subscription $SubscriptionId `
            --query "instanceView.state" -o tsv 2>&1
        $ErrorActionPreference = 'Stop'

        $mins = [math]::Floor($elapsed / 60)
        $secs = $elapsed % 60
        $color = if ($state -eq 'Succeeded') { 'Green' } elseif ($state -eq 'Failed') { 'Red' } else { 'DarkYellow' }
        Write-Host "  [${mins}m ${secs}s] State: $state" -ForegroundColor $color

        if ($elapsed -ge $MaxPollSeconds) {
            Write-Host "  Timed out after ${MaxPollSeconds}s" -ForegroundColor Red
            break
        }
    }

    # --- Step 6b: Read container exit code ---
    $containerExitCode = $null
    if ($state -eq 'Succeeded' -or $state -eq 'Failed' -or $state -eq 'Terminated') {
        try {
            $ErrorActionPreference = 'Continue'
            $exitCodeRaw = az container show `
                --name $ContainerName `
                --resource-group $ResourceGroup `
                --subscription $SubscriptionId `
                --query "containers[0].instanceView.currentState.exitCode" -o tsv 2>&1
            $ErrorActionPreference = 'Stop'
            if ($exitCodeRaw -match '^\d+$') { $containerExitCode = [int]$exitCodeRaw }
        } catch { }
        $ecColor = if ($containerExitCode -eq 0) { 'Green' } else { 'Red' }
        Write-Host "  Container exit code: $containerExitCode" -ForegroundColor $ecColor
    }

    # --- Step 7: Get logs ---
    Write-Host ''
    Write-Host '--- Step 7: Seed output ---' -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    $logs = az container logs `
        --name $ContainerName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId 2>&1
    $ErrorActionPreference = 'Stop'

    Write-Host $logs

    # --- Step 8: Cleanup ---
    if (-not $SkipCleanup) {
        Write-Host ''
        Write-Host '--- Step 8: Cleanup ---' -ForegroundColor Yellow
        $ErrorActionPreference = 'Continue'
        az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
        Write-Host 'Container deleted.' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Host '--- Skipping cleanup (-SkipCleanup specified) ---' -ForegroundColor DarkYellow
    }

    # --- Result ---
    Write-Host ''
    if ($null -eq $containerExitCode) {
        Write-Host "=== SEED INCONCLUSIVE (state: $state) ===" -ForegroundColor Yellow
        exit 2
    } elseif ($containerExitCode -eq 0) {
        Write-Host '=== SEED COMPLETED SUCCESSFULLY ===' -ForegroundColor Green
        exit 0
    } else {
        Write-Host "=== SEED FAILED (exit code: $containerExitCode) ===" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# Local Mode: Run seed logic directly with az CLI token
# ============================================================
$created = @()
$failed = @()

# --- Token ---
if ([string]::IsNullOrEmpty($Token)) {
    Write-Host "Acquiring token via az CLI..." -ForegroundColor Cyan
    $ErrorActionPreference = 'Continue'
    $Token = az account get-access-token --resource $Resource --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($Token)) {
        Write-Host "ERROR: Failed to acquire token. Run 'az login' first." -ForegroundColor Red
        exit 1
    }
    $ErrorActionPreference = 'Stop'
    Write-Host "Token acquired ($($Token.Length) chars)"
}

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type"  = "application/json"
}

# --- Helper Functions ---
function Invoke-CmsApi {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body,
        [hashtable]$ExtraHeaders = @{}
    )
    $uri = "$BaseUrl$Path"
    $allHeaders = $headers.Clone()
    foreach ($k in $ExtraHeaders.Keys) { $allHeaders[$k] = $ExtraHeaders[$k] }

    $params = @{
        Uri             = $uri
        Method          = $Method
        Headers         = $allHeaders
        UseBasicParsing = $true
    }
    if ($Body) { $params["Body"] = [System.Text.Encoding]::UTF8.GetBytes($Body) }

    try {
        $response = Invoke-WebRequest @params
        return @{
            StatusCode = $response.StatusCode
            Data       = ($response.Content | ConvertFrom-Json)
            Headers    = $response.Headers
            Success    = $true
        }
    } catch {
        $statusCode = $null
        $body = ""
        try {
            $resp = $_.Exception.Response
            $statusCode = [int]$resp.StatusCode
            $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
            $body = $reader.ReadToEnd()
            $reader.Close()
        } catch { }
        Write-Host "  FAILED: $Method $Path -> HTTP $statusCode" -ForegroundColor Red
        if ($body) { Write-Host "  $body" -ForegroundColor DarkRed }
        return @{ StatusCode = $statusCode; Data = $null; Success = $false; Error = $body }
    }
}

function New-Case {
    param([hashtable]$CaseDef)
    $body = $CaseDef | ConvertTo-Json -Depth 10
    Write-Host "  Creating case: $($CaseDef.title)..." -NoNewline
    $idempotencyKey = [System.Guid]::NewGuid().ToString()
    $result = Invoke-CmsApi -Method POST -Path "/api/v1/cases" -Body $body -ExtraHeaders @{ "X-Idempotency-Key" = $idempotencyKey }
    if ($result.Success) {
        $caseId = $result.Data.caseId
        $etag = $result.Data.etag
        Write-Host " OK -> $caseId" -ForegroundColor Green
        return @{ CaseId = $caseId; ETag = $etag }
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        return $null
    }
}

function Add-Note {
    param([string]$CaseId, [hashtable]$NoteDef)
    $NoteDef["caseId"] = $CaseId
    $body = $NoteDef | ConvertTo-Json -Depth 5
    $result = Invoke-CmsApi -Method POST -Path "/api/v1/cases/$CaseId/notes" -Body $body -ExtraHeaders @{ "X-Idempotency-Key" = [System.Guid]::NewGuid().ToString() }
    if ($result.Success) {
        Write-Host "    + Note ($($NoteDef.noteType))" -ForegroundColor DarkGreen
    }
    return $result
}

function Add-Event {
    param([string]$CaseId, [hashtable]$EventDef)
    # CreateCaseEventRequest only has eventType + details; caseId is in the URL path
    $body = $EventDef | ConvertTo-Json -Depth 5
    $result = Invoke-CmsApi -Method POST -Path "/api/v1/cases/$CaseId/events" -Body $body -ExtraHeaders @{ "X-Idempotency-Key" = [System.Guid]::NewGuid().ToString() }
    if ($result.Success) {
        Write-Host "    + Event ($($EventDef.eventType))" -ForegroundColor DarkGreen
    }
    return $result
}

function Add-Communication {
    param([string]$CaseId, [hashtable]$CommDef)
    $CommDef["caseId"] = $CaseId
    $body = $CommDef | ConvertTo-Json -Depth 10
    $result = Invoke-CmsApi -Method POST -Path "/api/v1/cases/$CaseId/communications" -Body $body -ExtraHeaders @{ "X-Idempotency-Key" = [System.Guid]::NewGuid().ToString() }
    if ($result.Success) {
        Write-Host "    + Comm ($($CommDef.communicationType))" -ForegroundColor DarkGreen
    }
    return $result
}

# --- Case Definitions ---
# 12 diverse cases covering different request types, priorities
# RequestType values: must match Common/Enums/RequestType.cs exactly:
#   IREQ, CourtOrder, SearchWarrant, SubpoenaSummons, Preservation, NSL,
#   LawfulIntercept, EmergencyLetter, ConsentRelease, Other, CivilDemand,
#   InternationalOrder, PRTT, MMOBusinessRecords, TestimonySubpoenaSummons
#   (NotValid and Duplicate are NOT allowed on case creation)
# Fields must match DTOs/Cases/CreateCaseRequest.cs exactly:
#   Required: requestType, title, jurisdiction, priority
#   Optional: description, requestSubType, leReferenceNumber, cpConcern,
#             isPreservationRequest, isWAShieldLaw, dsaCategories,
#             agentFirstName, agentLastName, agentEmail, agentPhone,
#             services, notificationPreferences, internationalJurisdiction,
#             treatyReference, urgencyLevel, dsaAgencyName, dsaAgencyCountry,
#             country (2-letter ISO), natureOfCrimes, originalReceivedDate,
#             additionalCaseInformation
# NOTE: assignee is set via PATCH (JSON Patch RFC 6902) after creation
# NOTE: country is optional (2-letter ISO 3166-1 alpha-2) on CreateCaseRequest
# NOTE: caseDueDate is system-managed and not settable via API (not on CreateCaseRequest or CasePatchModel)
$caseDefs = @(
    @{
        requestType           = "IREQ"
        title                 = "International Request - German BKA Investigation"
        description           = "Request from BKA for Microsoft account data related to organized crime investigation. Multiple identifiers across Outlook, Teams, and Azure AD."
        priority              = "Standard"
        jurisdiction          = "DE"
        country               = "DE"
        leReferenceNumber     = "BKA-2026-00142"
    },
    @{
        requestType           = "EmergencyLetter"
        title                 = "Emergency - Imminent Threat to Life (FBI)"
        description           = "Emergency disclosure request involving imminent threat to life. Requires immediate processing of subscriber and transactional data for identified accounts."
        priority              = "Emergency"
        jurisdiction          = "US-FED"
        country               = "US"
        leReferenceNumber     = "FBI-2026-EM-0087"
    },
    @{
        requestType           = "CourtOrder"
        title                 = "UK NCA Court Order - Child Safety Investigation"
        description           = "Court order from UK National Crime Agency for content and metadata across multiple Microsoft services related to child exploitation material."
        priority              = "Urgent"
        jurisdiction          = "GB"
        country               = "GB"
        leReferenceNumber     = "NCA-2026-CO-0034"
    },
    @{
        requestType           = "SearchWarrant"
        title                 = "NYPD Search Warrant - Financial Fraud"
        description           = "State-level search warrant for email communications and OneDrive documents related to wire fraud investigation."
        priority              = "Standard"
        jurisdiction          = "US-NY"
        country               = "US"
        leReferenceNumber     = "NYPD-2026-SW-1122"
    },
    @{
        requestType           = "SubpoenaSummons"
        title                 = "RCMP Subpoena - Cybercrime"
        description           = "Canadian RCMP subpoena for subscriber information and IP logs related to unauthorized computer access investigation."
        priority              = "Standard"
        jurisdiction          = "CA"
        country               = "CA"
        leReferenceNumber     = "RCMP-2026-SP-0219"
    },
    @{
        requestType           = "Preservation"
        title                 = "France DGSI Preservation - Terrorism"
        description           = "Urgent preservation request from French intelligence for account data pending formal MLAT request. Terrorism-related investigation."
        priority              = "Urgent"
        jurisdiction          = "FR"
        country               = "FR"
        leReferenceNumber     = "DGSI-2026-PR-0056"
    },
    @{
        requestType           = "InternationalOrder"
        title                 = "India CBI Request - Human Trafficking"
        description           = "International request from India CBI for communications data related to cross-border human trafficking ring."
        priority              = "Standard"
        jurisdiction          = "IN"
        country               = "IN"
        agentFirstName        = "Rajesh"
        agentLastName         = "Kumar"
        agentEmail            = "rajesh.kumar@cbi.gov.in"
        internationalJurisdiction = "IN-MH"
        leReferenceNumber     = "CBI-2025-IR-0891"
    },
    @{
        requestType           = "EmergencyLetter"
        title                 = "Emergency - AFP Missing Person (Australia)"
        description           = "Emergency disclosure for Australian Federal Police regarding missing person case with imminent danger. Location data and recent account activity required."
        priority              = "Emergency"
        jurisdiction          = "AU"
        country               = "AU"
        leReferenceNumber     = "AFP-2026-EM-0031"
    },
    @{
        requestType           = "CourtOrder"
        title                 = "Japan NPA Court Order - Cyber Espionage"
        description           = "Court order from Japan National Police Agency for Azure AD and Exchange data related to state-sponsored cyber espionage investigation."
        priority              = "Standard"
        jurisdiction          = "JP"
        country               = "JP"
        leReferenceNumber     = "NPA-2025-CO-0467"
    },
    @{
        requestType           = "NSL"
        title                 = "National Security Letter - Counterintelligence"
        description           = "National Security Letter for subscriber and transactional data related to counterintelligence investigation."
        priority              = "Urgent"
        jurisdiction          = "US-FED"
        country               = "US"
        leReferenceNumber     = "FBI-2026-NSL-0178"
    },
    @{
        requestType           = "ConsentRelease"
        title                 = "USSS Consent Release - Account Compromise"
        description           = "Voluntary consent release for Secret Service investigation of compromised federal employee accounts."
        priority              = "Standard"
        jurisdiction          = "US-FED"
        country               = "US"
        leReferenceNumber     = "USSS-2026-VD-0044"
    },
    @{
        requestType           = "Preservation"
        title                 = "Germany BKA Preservation - Ransomware"
        description           = "Urgent preservation for BKA regarding ransomware attack targeting critical infrastructure. Azure and Exchange data preservation required."
        priority              = "Urgent"
        jurisdiction          = "DE"
        country               = "DE"
        leReferenceNumber     = "BKA-2026-AP-0023"
    }
)

# Assignee names to PATCH after creation (rotate through these)
# PATCH uses JSON Patch (RFC 6902): [{"op":"replace","path":"/assignee","value":"..."}]
# The patchable field is "assignee" (not "assigneeName") per CasePatchModel.cs
$assigneeNames = @(
    "Sarah Johnson",
    "Michael Chen",
    "Emily Rodriguez",
    "David Kim",
    $null,  # unassigned
    "Anna Mueller",
    "James Wilson",
    $null,  # unassigned
    "Yuki Tanaka",
    "Carlos Silva",
    "Lisa Park",
    "Thomas Weber"
)

# --- Note Templates ---
$noteTemplates = @(
    @{
        noteType  = "General"
        content   = "Initial case review completed. All required documentation has been received and verified. Case is ready for triage assessment."
        isInternal = $false
    },
    @{
        noteType  = "Triage"
        content   = "Triage assessment: Request scope includes email metadata and account activity logs for the specified date range. Estimated fulfillment time: 5 business days."
        isInternal = $true
    },
    @{
        noteType  = "Fulfillment"
        content   = "Data extraction initiated. Querying relevant data sources for the identifiers specified in the legal process. Preliminary results available for review."
        isInternal = $true
    },
    @{
        noteType  = "Attorney"
        content   = "Legal review confirms the request meets jurisdictional requirements. Authorization granted to proceed with data production per the scope outlined in the legal instrument."
        isInternal = $true
    },
    @{
        noteType  = "Escalation"
        content   = "Escalated to senior analyst due to request complexity. Multiple data sources and cross-border legal considerations require additional review."
        isInternal = $true
    },
    @{
        noteType  = "General"
        content   = "Requestor contacted via secure portal to clarify the date range for account activity. Awaiting response before proceeding with data collection."
        isInternal = $false
    }
)

# --- Event Templates ---
# CreateCaseEventRequest only accepts: eventType (required), details (optional)
# IMPORTANT: Only "NoteAdded" is in the ExplicitlyCreatableTypes whitelist.
# All other types (StageChange, Assignment, PriorityChange, CaseUpdated,
# StatusUpdate, etc.) are system-generated and the API returns 400 for them.
$eventTemplates = @(
    @{
        eventType = "NoteAdded"
        details   = @{ context = "Initial triage assessment completed" }
    },
    @{
        eventType = "NoteAdded"
        details   = @{ context = "Legal review note added to case file" }
    },
    @{
        eventType = "NoteAdded"
        details   = @{ context = "Escalation note: senior analyst review required" }
    },
    @{
        eventType = "NoteAdded"
        details   = @{ context = "Fulfillment progress update recorded" }
    },
    @{
        eventType = "NoteAdded"
        details   = @{ context = "Data collection milestone reached" }
    },
    @{
        eventType = "NoteAdded"
        details   = @{ context = "Jurisdiction verification note added" }
    }
)

# --- Communication Templates ---
$commTemplates = @(
    @{
        direction         = "Outbound"
        channel           = "Portal"
        communicationType = "LECorrespondence"
        subject           = "Request Acknowledgment - Case Received"
        body              = "Thank you for your submission. Your request has been received and assigned a case identifier. You will receive updates as the case progresses through our review process."
    },
    @{
        direction         = "Inbound"
        channel           = "Portal"
        communicationType = "LECorrespondence"
        subject           = "Additional Documentation Provided"
        body              = "Please find attached the supplemental court order expanding the scope of the original request to include additional account identifiers as specified."
    },
    @{
        direction         = "Outbound"
        channel           = "Email"
        communicationType = "RedirectNotice"
        subject           = "Request Redirect - Jurisdiction Notice"
        body              = "After review, we have determined that a portion of the data requested falls under a different service jurisdiction. The relevant portion has been redirected accordingly."
    },
    @{
        direction         = "Outbound"
        channel           = "Portal"
        communicationType = "UserNotification"
        subject           = "Data Production Ready for Review"
        body              = "The data production for your request is complete and ready for download via the secure portal. Please review and confirm receipt within 30 days."
    },
    @{
        direction         = "Outbound"
        channel           = "Portal"
        communicationType = "RejectionNotice"
        subject           = "Request Returned - Insufficient Legal Process"
        body              = "After legal review, the submitted request does not meet the threshold requirements for the data categories requested. Please consult the legal process guidelines and resubmit."
    }
)

# === Main Execution ===
Write-Host ""
Write-Host "=== LRMS Test Data Seeder ===" -ForegroundColor Cyan
Write-Host "Target: $BaseUrl"
Write-Host "Cases to create: $($caseDefs.Count)"
Write-Host ""

# --- Health Check ---
Write-Host "--- Health Check ---"
$health = Invoke-CmsApi -Method GET -Path "/api/health"
if ($health.Success) {
    Write-Host "CMS API is healthy." -ForegroundColor Green
} else {
    Write-Host "Health check returned $($health.StatusCode) - continuing anyway (auth-protected endpoints may still work)." -ForegroundColor Yellow
}
Write-Host ""

# --- Create Cases ---
Write-Host "--- Creating Cases ---" -ForegroundColor Yellow
$caseResults = @()

for ($i = 0; $i -lt $caseDefs.Count; $i++) {
    # Throttle: 2 second delay between cases to avoid 429
    if ($i -gt 0) { Start-Sleep -Seconds 2 }
    Write-Host "[$($i+1)/$($caseDefs.Count)]" -NoNewline
    $caseResult = New-Case -CaseDef $caseDefs[$i]
    if ($caseResult) {
        $caseResults += $caseResult
        $created += "Case $($caseResult.CaseId)"

        # PATCH to set assignee (JSON Patch RFC 6902 format, field is "assignee" not "assigneeName")
        $assignee = $assigneeNames[$i % $assigneeNames.Count]
        if ($assignee) {
            $patchOps = @(
                @{ op = "replace"; path = "/assignee"; value = $assignee }
            )
            $patchBody = $patchOps | ConvertTo-Json -Depth 5
            $patchResult = Invoke-CmsApi -Method PATCH -Path "/api/v1/cases/$($caseResult.CaseId)" -Body $patchBody -ExtraHeaders @{ "If-Match" = $caseResult.ETag }
            if ($patchResult.Success) {
                Write-Host "    + Assigned to $assignee" -ForegroundColor DarkGreen
                # Update etag for subsequent patches
                if ($patchResult.Data.eTag) { $caseResult.ETag = $patchResult.Data.eTag }
            } else {
                Write-Host "    ! PATCH assignee failed" -ForegroundColor DarkYellow
            }
        }

        # Add 2-3 notes per case (rotate through templates)
        $noteCount = 2 + ($i % 2)  # alternates 2 and 3
        for ($n = 0; $n -lt $noteCount; $n++) {
            $noteIdx = ($i * 3 + $n) % $noteTemplates.Count
            Add-Note -CaseId $caseResult.CaseId -NoteDef $noteTemplates[$noteIdx].Clone()
        }

        # Add 1-2 events per case
        $eventCount = 1 + ($i % 2)
        for ($e = 0; $e -lt $eventCount; $e++) {
            $eventIdx = ($i * 2 + $e) % $eventTemplates.Count
            Add-Event -CaseId $caseResult.CaseId -EventDef $eventTemplates[$eventIdx].Clone()
        }

        # Add 1-2 communications per case
        $commCount = 1 + (($i + 1) % 2)
        for ($c = 0; $c -lt $commCount; $c++) {
            $commIdx = ($i * 2 + $c) % $commTemplates.Count
            Add-Communication -CaseId $caseResult.CaseId -CommDef $commTemplates[$commIdx].Clone()
        }

        Write-Host ""
    } else {
        $failed += "Case #$($i+1) ($($caseDefs[$i].requestType)/$($caseDefs[$i].jurisdiction))"
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Seed Summary ===" -ForegroundColor Cyan
Write-Host "Created: $($caseResults.Count) / $($caseDefs.Count) cases" -ForegroundColor $(if ($caseResults.Count -eq $caseDefs.Count) { "Green" } else { "Yellow" })

if ($caseResults.Count -gt 0) {
    Write-Host ""
    Write-Host "Case IDs:" -ForegroundColor White
    foreach ($cr in $caseResults) {
        Write-Host "  $($cr.CaseId)"
    }
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed:" -ForegroundColor Red
    foreach ($f in $failed) { Write-Host "  $f" -ForegroundColor Red }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
