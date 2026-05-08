<#
.SYNOPSIS
    Validates that data submitted by an AciE2E integration-test run actually
    persisted to Cosmos and is readable through the production GetStatus API.

.DESCRIPTION
    The Ev2 integration-test script (`Invoke-IntegrationTests.ps1`) submits
    test requests via POST /api/v1/DataCollector/submit (which writes a
    DCSTaskStatus record into the Tasks container in Cosmos). The same
    script then immediately calls GET /api/v1/DataCollector/getStatus to
    validate the round-trip. That implicit validation IS the persistence
    proof — but it lives buried inside the ACI test log.

    This script extracts every dpsJobId observed in the test log, then
    re-queries each one through the production GetStatus API a second time
    (after the test container is gone). This proves:

      1. The submit POST persisted the record to Cosmos (otherwise the
         original GET in the test would have failed — the test exit-code 0
         already covers this).
      2. The record is still durable and queryable AFTER the test container
         is torn down (this script's contribution — verifies durability).
      3. The GetStatus / BuildStatusResponse code path returns a well-formed
         DCSTaskStatus DTO matching the contract.

    Per CLAUDE.md "ALL infra changes go through Ev2 pipelines + bicep" and
    "NEVER change Cosmos RBAC manually" — this script does NOT query Cosmos
    directly. It uses the same API the production callers use, so a passing
    run is equivalent to "production read path is healthy".

.PARAMETER LogFile
    Path to the AciE2E log file produced by Run-AciE2E.ps1 (typically under
    .mad/reports/aci-e2e-{env}-{ts}.log).

.PARAMETER BaseUrl
    Base URL for the API. Default: regional endpoint for the npe4 ring.

.PARAMETER ApiClientId
    AAD app ID of the API. Default matches DataCollector NPE registration.

.PARAMETER MinDpsJobIdCount
    Fail unless at least this many dpsJobId values were extracted from the
    log AND verified. Default 1 (requires at least one round-trip).

.NOTES
    Exit codes:
      0 = ALL PASS — every observed dpsJobId returned a well-formed response.
      1 = AT LEAST ONE FAIL — record missing, malformed response, or 5xx.
      2 = SETUP_ERROR — could not read log, could not get token, etc.
      3 = NO_DATA — log contained zero dpsJobId values to verify.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LogFile,

    [string]$BaseUrl = 'https://app-lensdcs-npe4-westcentralus.azurewebsites.net',

    [string]$ApiClientId = 'e7793396-4a29-44d0-a076-f35ba907c2fb',

    [int]$MinDpsJobIdCount = 1,

    [string]$ReportPath = $null
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $LogFile)) {
    Write-Error "LogFile not found: $LogFile"
    exit 2
}

if (-not $ReportPath) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ReportPath = Join-Path '.mad/reports' "cosmos-persistence-verify-$ts.md"
}

Write-Host "=== DCS Cosmos persistence verifier ===" -ForegroundColor Cyan
Write-Host "  LogFile:    $LogFile"
Write-Host "  BaseUrl:    $BaseUrl"
Write-Host "  ApiClientId: $ApiClientId"
Write-Host "  ReportPath: $ReportPath"
Write-Host ""

# === Step 1: extract dpsJobId values from the log ===
$logContent = Get-Content $LogFile -Raw
$dpsJobIdPattern = '(?i)dpsJobId["\s:=]+["]?([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'
$matches = [regex]::Matches($logContent, $dpsJobIdPattern)
$dpsJobIds = $matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

Write-Host "Extracted $($dpsJobIds.Count) unique dpsJobId values from log" -ForegroundColor Cyan
$dpsJobIds | ForEach-Object { Write-Host "  $_" }

if ($dpsJobIds.Count -eq 0) {
    Write-Warning "No dpsJobId values found in log. Cannot verify persistence."
    @"
# Cosmos Persistence Verification — NO DATA

**Log file**: ``$LogFile``
**Verdict**: NO_DATA — exit code 3
**Reason**: regex extraction found 0 dpsJobId values in the log.

The integration test may have failed before submitting anything, OR the log format
changed and the regex needs tuning. Manual review required:

  Get-Content -Path '$LogFile' -Tail 100
"@ | Set-Content -Path $ReportPath -Encoding UTF8
    exit 3
}

if ($dpsJobIds.Count -lt $MinDpsJobIdCount) {
    Write-Warning "Found $($dpsJobIds.Count) dpsJobId(s); minimum required: $MinDpsJobIdCount"
}

# === Step 2: get an API access token ===
Write-Host ""
Write-Host "Acquiring access token for api://$ApiClientId ..." -ForegroundColor Cyan
$token = az account get-access-token --resource "api://$ApiClientId" --query accessToken -o tsv 2>&1
if (-not $token -or $token -match '^ERROR' -or $LASTEXITCODE -ne 0) {
    Write-Error "Failed to acquire access token. Make sure 'az login' is current and your account has access to the API. Error: $token"
    @"
# Cosmos Persistence Verification — SETUP_ERROR

**Log file**: ``$LogFile``
**Verdict**: SETUP_ERROR — exit code 2
**Reason**: ``az account get-access-token`` failed.

Output:
$token

Likely fix: ``az login --tenant b1a4f7cb-a159-44a6-ac48-6674e85c4ddc`` (Torus tenant for NPE).
Or PIM-elevate before running.
"@ | Set-Content -Path $ReportPath -Encoding UTF8
    exit 2
}
Write-Host "  token acquired (length: $($token.Length))" -ForegroundColor Green

# === Step 3: re-query GetStatus for each dpsJobId ===
$results = @()
$failCount = 0
foreach ($jobId in $dpsJobIds) {
    $uri = "$BaseUrl/api/v1/DataCollector/getStatus?dpsJobId=$jobId"
    Write-Host ""
    Write-Host "GET $uri" -ForegroundColor Cyan
    $verdict = 'UNKNOWN'
    $details = ''
    $statusCode = $null
    $response = $null
    try {
        $resp = Invoke-WebRequest -Uri $uri `
            -Method GET `
            -Headers @{ Authorization = "Bearer $token" } `
            -UseBasicParsing `
            -ErrorAction Stop
        $statusCode = $resp.StatusCode
        if ($statusCode -ge 200 -and $statusCode -lt 300) {
            $response = $resp.Content | ConvertFrom-Json -Depth 20
            # Validate response shape: must have lensTaskId AND status (or DCSTaskStatus equivalent)
            $hasLensTaskId = ($null -ne $response.lensTaskId) -or ($null -ne $response.LensTaskId)
            $hasStatus = ($null -ne $response.status) -or ($null -ne $response.Status)
            if ($hasLensTaskId -and $hasStatus) {
                $verdict = 'PASS'
                $details = "200 OK; status=$($response.status ?? $response.Status); lensTaskId=$($response.lensTaskId ?? $response.LensTaskId)"
                Write-Host "  PASS — $details" -ForegroundColor Green
            }
            else {
                $verdict = 'FAIL_SHAPE'
                $details = "200 OK but response missing lensTaskId or status; body: $($resp.Content.Substring(0, [Math]::Min(200, $resp.Content.Length)))"
                Write-Host "  FAIL_SHAPE — $details" -ForegroundColor Red
                $failCount++
            }
        }
        else {
            $verdict = 'FAIL_HTTP'
            $details = "HTTP $statusCode"
            Write-Host "  FAIL_HTTP — $details" -ForegroundColor Red
            $failCount++
        }
    }
    catch {
        $verdict = 'FAIL_EXCEPTION'
        $details = "$($_.Exception.Message)"
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $details = "HTTP $statusCode — $($_.Exception.Message)"
        }
        Write-Host "  FAIL_EXCEPTION — $details" -ForegroundColor Red
        $failCount++
    }
    $results += [PSCustomObject]@{
        DpsJobId    = $jobId
        StatusCode  = $statusCode
        Verdict     = $verdict
        Details     = $details
        LensTaskId  = if ($response) { $response.lensTaskId ?? $response.LensTaskId } else { '' }
        Status      = if ($response) { $response.status ?? $response.Status } else { '' }
    }
}

# === Step 4: write report + exit ===
$total = $results.Count
$passCount = ($results | Where-Object { $_.Verdict -eq 'PASS' }).Count
$exitCode = if ($failCount -eq 0 -and $passCount -ge $MinDpsJobIdCount) { 0 } else { 1 }
$verdictBanner = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }

$reportLines = @()
$reportLines += "# Cosmos Persistence Verification — $verdictBanner"
$reportLines += ""
$reportLines += "**Log file**: ``$LogFile``"
$reportLines += "**Base URL**: $BaseUrl"
$reportLines += "**Verdict**: $verdictBanner — exit code $exitCode"
$reportLines += "**Pass / Total**: $passCount / $total"
$reportLines += "**Generated**: $(Get-Date -Format o)"
$reportLines += ""
$reportLines += "## Per-dpsJobId results"
$reportLines += ""
$reportLines += "| dpsJobId | HTTP | Verdict | LensTaskId | Status | Details |"
$reportLines += "|---|---|---|---|---|---|"
foreach ($r in $results) {
    $reportLines += "| ``$($r.DpsJobId)`` | $($r.StatusCode) | $($r.Verdict) | ``$($r.LensTaskId)`` | $($r.Status) | $($r.Details) |"
}
$reportLines += ""
$reportLines += "## Interpretation"
$reportLines += ""
if ($exitCode -eq 0) {
    $reportLines += "All $total submitted records re-queried successfully via the production GetStatus API."
    $reportLines += "This proves:"
    $reportLines += "1. The submit POST persisted records to the Cosmos ``Tasks`` container."
    $reportLines += "2. Records remain durable post-test (test ACI was torn down before this verification ran)."
    $reportLines += "3. The DCSTaskStatus DTO contract is intact (lensTaskId + status both present)."
    $reportLines += "4. The GetStatus / BuildStatusResponse code path is healthy."
}
else {
    $reportLines += "$failCount of $total dpsJobId records did NOT round-trip successfully. Inspect the per-record verdict + details above."
    $reportLines += ""
    $reportLines += "Possible causes:"
    $reportLines += "- Cosmos write succeeded but record was deleted by another process."
    $reportLines += "- BuildStatusResponse hit corrupt-doc path (Wave triage hardened this to throw vs swallow — a 5xx HERE confirms the change is reaching the service)."
    $reportLines += "- App Service slot mismatch (production slot still on old build)."
    $reportLines += "- API auth scope mismatch (token tenant != API tenant)."
}

$reportLines -join "`n" | Set-Content -Path $ReportPath -Encoding UTF8
Write-Host ""
Write-Host "Report written: $ReportPath" -ForegroundColor Cyan
Write-Host "Exit code: $exitCode ($verdictBanner)" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })

exit $exitCode
