<#
.SYNOPSIS
    Behavioral E2E smoke test against a deployed LENS-DCS ring.

.DESCRIPTION
    Local-invocation variant of Invoke-IntegrationTests.ps1. Does NOT require an Ev2
    deployment-script container — runs from the developer's machine using `az` CLI for
    AAD token acquisition.

    Flow:
      1. Acquire AAD token (resource = api://<ApiClientId>) via az CLI.
      2. POST a sample DataPipelineRequest to <BaseUrl>/api/v1/DataCollector/submit.
      3. Poll <BaseUrl>/api/v1/DataCollector/getStatus until status terminates or
         transitions to InProgress (the controller's own persisted state).
      4. Send a Service Bus status update message via Az.ServiceBus.
      5. Re-poll status; verify it transitions to the expected new value.

    Returns 0 on success, 1 on failure.

.PARAMETER BaseUrl
    Base URL of the deployed API (e.g. https://api.lensdcs-npe4.com).

.PARAMETER Environment
    Environment name (npe4, ppe, prd, etc). Used for diagnostics and for resolving
    Service Bus / API client config when these aren't supplied directly.

.PARAMETER RequestType
    DPS request type. Default: 'IntegrationTest'.

.PARAMETER ApiClientId
    AAD application (client) ID for the API. If omitted, the script logs that the
    caller is expected to set the API_CLIENT_ID env var.

.PARAMETER ServiceBusNamespace
    Service Bus namespace FQDN component (e.g. sb-app-lensdcs-npe4-westus3).
    Optional — when omitted, step 4 is skipped with a WARN.

.PARAMETER Queue
    Service Bus queue name. Default: 'datacollector-status'.

.PARAMETER MaxAttempts
    Max poll attempts in each polling loop. Default: 30.

.PARAMETER PollSeconds
    Poll interval. Default: 5.

.PARAMETER DryRun
    Print intent without making any HTTP / SB calls.

.EXAMPLE
    pwsh -NoProfile -File Test-E2E-ACI.ps1 `
        -BaseUrl 'https://api.lensdcs-npe4.com' -Environment npe4
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$Environment,

    [string]$RequestType = 'IntegrationTest',

    [string]$ApiClientId = '',

    [string]$ServiceBusNamespace = '',

    [string]$Queue = 'datacollector-status',

    [int]$MaxAttempts = 30,

    [int]$PollSeconds = 5,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[Test-E2E-ACI] $Message" }

# Resolve ApiClientId from env var if not supplied
if (-not $ApiClientId -and $env:API_CLIENT_ID) {
    $ApiClientId = $env:API_CLIENT_ID
    Write-Info "ApiClientId resolved from env API_CLIENT_ID"
}

Write-Info "BaseUrl         : $BaseUrl"
Write-Info "Environment     : $Environment"
Write-Info "RequestType     : $RequestType"
Write-Info "ApiClientId     : $(if ($ApiClientId) { $ApiClientId } else { '(unresolved — set -ApiClientId or API_CLIENT_ID env var)' })"
Write-Info "ServiceBus      : $(if ($ServiceBusNamespace) { $ServiceBusNamespace } else { '(none — step 4 will be skipped)' })"
Write-Info "Queue           : $Queue"
Write-Info "MaxAttempts/Poll: $MaxAttempts / ${PollSeconds}s"

$dpsJobId = [guid]::NewGuid().ToString()
$caseId = "E2E-$($Environment.ToUpper())-$(Get-Date -Format yyyyMMddHHmmss)"

if ($DryRun) {
    Write-Info '[DRY-RUN] Would execute:'
    Write-Info "  1. az account get-access-token --resource api://$ApiClientId"
    Write-Info "  2. POST $BaseUrl/api/v1/DataCollector/submit (dpsJobId=$dpsJobId, caseId=$caseId)"
    Write-Info "  3. Poll $BaseUrl/api/v1/DataCollector/getStatus?dpsJobId=$dpsJobId up to $MaxAttempts times"
    if ($ServiceBusNamespace) {
        Write-Info "  4. POST status update to https://$ServiceBusNamespace.servicebus.windows.net/$Queue/messages"
        Write-Info "  5. Re-poll status; expect transition (e.g. InProgress -> Completed)"
    } else {
        Write-Info "  4. SKIP (no ServiceBusNamespace supplied)"
    }
    exit 0
}

if (-not $ApiClientId) {
    Write-Error 'ApiClientId is required for live invocation. Pass -ApiClientId or set API_CLIENT_ID env var.'
    exit 1
}

# 1. Acquire token
Write-Info 'Acquiring AAD token...'
$ErrorActionPreference = 'Continue'
$tokenJson = az account get-access-token --resource "api://$ApiClientId" -o json 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0) {
    Write-Error "az account get-access-token failed: $tokenJson"
    exit 1
}
$token = (($tokenJson | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) | ConvertFrom-Json).accessToken
$headers = @{ Authorization = "Bearer $token" }

# 2. Submit
$submitUri = "$BaseUrl/api/v1/DataCollector/submit"
$body = @{
    dpsJobId    = $dpsJobId
    caseId      = $caseId
    lensTaskId  = [guid]::NewGuid().ToString()
    isEmergency = $false
    dpsData     = @{
        identifierHash   = 'e2e-aci-test-hash'
        identifierType   = 0
        isEnterprise     = $false
        tenantId         = '00000000-0000-0000-0000-000000000000'
        requestedService = 99
        dataCategory     = 4
        storageRegion    = 0
        demandStartDate  = '2099-01-01T00:00:00Z'
        demandEndDate    = '2099-01-02T00:00:00Z'
        scenarioDetails  = @{
            storageRegion = 'US'
            serviceName   = $RequestType
        }
    }
} | ConvertTo-Json -Depth 5
Write-Info "Submitting to $submitUri (dpsJobId=$dpsJobId)"
$resp = Invoke-RestMethod -Uri $submitUri -Method POST -Headers $headers -ContentType 'application/json' -Body $body
if ("$($resp.processingStatus)" -notin @('InProgress','2')) {
    Write-Error "Submit returned processingStatus='$($resp.processingStatus)' errorCode='$($resp.errorCode)'"
    exit 1
}
Write-Info 'Submit accepted (InProgress).'

# 3. Poll status
$statusUri = "$BaseUrl/api/v1/DataCollector/getStatus?dpsJobId=$dpsJobId"
$initialStatus = $null
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Start-Sleep -Seconds $PollSeconds
    $r = Invoke-RestMethod -Uri $statusUri -Headers $headers
    $initialStatus = "$($r.processingStatus)"
    Write-Info "  poll ${attempt}: processingStatus=$initialStatus"
    if ($initialStatus -in @('InProgress','2','Completed','5','Failed')) { break }
}
if (-not $initialStatus) {
    Write-Error 'getStatus never returned a status before MaxAttempts.'
    exit 1
}

# 4 & 5. Service Bus status update + re-poll (only if SB configured)
if (-not $ServiceBusNamespace) {
    Write-Info 'Skipping Service Bus update (ServiceBusNamespace not supplied).'
    Write-Info 'E2E PASS (submit + initial status only).'
    exit 0
}

Write-Info "Sending Service Bus status update via $ServiceBusNamespace..."
$sbToken = (az account get-access-token --resource 'https://servicebus.azure.net' -o json |
    ConvertFrom-Json).accessToken
$sbUri = "https://$ServiceBusNamespace.servicebus.windows.net/$Queue/messages"
$sbBody = @{
    dpsJobId         = $dpsJobId
    processingStatus = 5
    stateDetails     = @{
        status               = 'Completed'
        statusText           = 'E2E test completed'
        statusTotalSize      = 100
        statusTotalProcessed = 100
    }
} | ConvertTo-Json -Depth 3 -Compress
Invoke-WebRequest -Uri $sbUri -Method POST `
    -Headers @{ Authorization = "Bearer $sbToken" } -ContentType 'application/json' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($sbBody)) -UseBasicParsing | Out-Null
Write-Info 'Service Bus message sent.'

# Re-poll
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Start-Sleep -Seconds $PollSeconds
    $r = Invoke-RestMethod -Uri $statusUri -Headers $headers
    $finalStatus = "$($r.processingStatus)"
    Write-Info "  re-poll ${attempt}: processingStatus=$finalStatus"
    if ($finalStatus -in @('Completed','5','Failed')) { break }
}
if ("$($r.processingStatus)" -notin @('Completed','5')) {
    Write-Error "Expected Completed after SB update, got '$($r.processingStatus)'."
    exit 1
}
Write-Info 'E2E PASS (submit + SB transition to Completed verified).'
exit 0
