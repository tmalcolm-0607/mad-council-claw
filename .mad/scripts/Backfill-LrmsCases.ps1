<#
.SYNOPSIS
    Backfill existing LRMS cases with meaningful metadata (title, country, priority, assigneeName).

.DESCRIPTION
    Fetches all cases from the LRMS BFF API, identifies cases missing metadata fields
    (title, country, priority, assigneeName), and PATCHes them with enriched data.
    Uses ETag-based optimistic concurrency (If-Match header) as required by the API.

.PARAMETER Environment
    Target environment name (default: tonym). Used to construct the BFF base URL.

.PARAMETER BaseUrl
    Override the BFF base URL directly. Takes precedence over -Environment.

.PARAMETER DryRun
    List what would be patched without making any changes.

.PARAMETER MaxCases
    Maximum number of cases to patch (0 = all, default: 0).

.PARAMETER Token
    Pre-acquired Bearer token. If not provided, acquires one via az CLI.

.PARAMETER Resource
    Azure AD resource URI for token acquisition.

.PARAMETER ThrottleSeconds
    Delay in seconds between PATCH requests (default: 2).

.EXAMPLE
    # Dry run - see what would be patched
    .\Backfill-LrmsCases.ps1 -DryRun

    # Patch all cases in tonym environment
    .\Backfill-LrmsCases.ps1

    # Patch up to 10 cases
    .\Backfill-LrmsCases.ps1 -MaxCases 10

    # Use a different environment
    .\Backfill-LrmsCases.ps1 -Environment npe

    # Override base URL directly
    .\Backfill-LrmsCases.ps1 -BaseUrl "https://webapi-lrms-npe-westus3.azurewebsites.net"
#>
[CmdletBinding()]
param(
    [string]$Environment = "tonym",
    [string]$BaseUrl,
    [switch]$DryRun,
    [int]$MaxCases = 0,
    [string]$Token,
    [string]$Resource = "api://6c5a00ce-8062-49d8-b568-b9bd0363340b",
    [int]$ThrottleSeconds = 2
)

$ErrorActionPreference = "Stop"

# --- Compute base URL ---
if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = "https://webapi-lrms-$Environment-westus3.azurewebsites.net"
}

# --- Rotation data ---
$countries = @("US", "GB", "CA", "AU", "DE")
$priorities = @("High", "Medium", "Low")
$assignees = @("Alice Johnson", "Bob Smith", "Carol Davis", "David Lee", "Eva Martinez")

# --- Token acquisition ---
if ([string]::IsNullOrEmpty($Token)) {
    Write-Host "Acquiring token via az CLI..." -ForegroundColor Cyan
    $Token = az account get-access-token --resource $Resource --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($Token)) {
        Write-Host "ERROR: Failed to acquire token. Run 'az login' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "Token acquired ($($Token.Length) chars)"
}

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type"  = "application/json"
}

# --- Helper: Invoke BFF API ---
function Invoke-BffApi {
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
        $errorBody = ""
        try {
            $resp = $_.Exception.Response
            $statusCode = [int]$resp.StatusCode
            $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            $reader.Close()
        } catch { }
        return @{ StatusCode = $statusCode; Data = $null; Success = $false; Error = $errorBody }
    }
}

# --- Helper: Generate title from requestType and caseId ---
function Get-GeneratedTitle {
    param([string]$RequestType, [string]$CaseId)

    $labelMap = @{
        "InternationalRequest" = "International Request"
        "EmergencyRequest"     = "Emergency Request"
        "CourtOrder"           = "Court Order"
        "SearchWarrant"        = "Search Warrant"
        "SubpoenaSummons"      = "Subpoena Summons"
        "PreservationRequest"  = "Preservation Request"
        "ConsentRequest"       = "Consent Request"
    }

    $label = $labelMap[$RequestType]
    if ([string]::IsNullOrEmpty($label)) {
        $label = $RequestType
    }
    return "$label - Case $CaseId"
}

# --- Helper: Check if a case needs backfill ---
function Test-NeedsBackfill {
    param([PSObject]$Case)

    $missing = @()
    if ([string]::IsNullOrEmpty($Case.title)) { $missing += "title" }
    if ([string]::IsNullOrEmpty($Case.country)) { $missing += "country" }
    if ([string]::IsNullOrEmpty($Case.priority)) { $missing += "priority" }
    if ([string]::IsNullOrEmpty($Case.assigneeName)) { $missing += "assigneeName" }
    return $missing
}

# === Main Execution ===
Write-Host ""
Write-Host "=== LRMS Case Backfill ===" -ForegroundColor Cyan
Write-Host "Target:   $BaseUrl"
Write-Host "DryRun:   $DryRun"
Write-Host "MaxCases: $(if ($MaxCases -eq 0) { 'all' } else { $MaxCases })"
Write-Host ""

# --- Fetch all cases (handle pagination) ---
Write-Host "--- Fetching cases ---" -ForegroundColor Yellow
$allCases = @()
$continuationToken = $null
$pageNum = 0

do {
    $pageNum++
    $path = "/api/v2/cases?pageSize=200"
    if ($continuationToken) {
        $encodedToken = [System.Uri]::EscapeDataString($continuationToken)
        $path += "&continuationToken=$encodedToken"
    }

    Write-Host "  Fetching page $pageNum..." -NoNewline
    $listResult = Invoke-BffApi -Method GET -Path $path

    if (-not $listResult.Success) {
        Write-Host " FAILED (HTTP $($listResult.StatusCode))" -ForegroundColor Red
        if ($listResult.Error) { Write-Host "  $($listResult.Error)" -ForegroundColor DarkRed }
        Write-Host ""
        Write-Host "ERROR: Failed to list cases. Aborting." -ForegroundColor Red
        exit 1
    }

    $pageData = $listResult.Data
    $pageItems = @()
    if ($pageData.items) {
        $pageItems = @($pageData.items)
    } elseif ($pageData -is [System.Collections.IEnumerable] -and -not ($pageData -is [string])) {
        # In case the response is a flat array
        $pageItems = @($pageData)
    }

    $allCases += $pageItems
    Write-Host " got $($pageItems.Count) cases (total: $($allCases.Count))" -ForegroundColor Green

    $continuationToken = $pageData.continuationToken
} while ($continuationToken)

Write-Host "Total cases fetched: $($allCases.Count)"
Write-Host ""

if ($allCases.Count -eq 0) {
    Write-Host "No cases found. Nothing to do." -ForegroundColor Yellow
    exit 0
}

# --- Identify cases needing backfill ---
Write-Host "--- Analyzing cases ---" -ForegroundColor Yellow
$candidateCases = @()

foreach ($case in $allCases) {
    $caseId = $case.caseId
    if ([string]::IsNullOrEmpty($caseId)) { continue }

    $missingFields = Test-NeedsBackfill -Case $case
    if ($missingFields.Count -gt 0) {
        $candidateCases += @{
            CaseId        = $caseId
            RequestType   = $case.requestType
            MissingFields = $missingFields
            Case          = $case
        }
    }
}

Write-Host "Cases needing backfill: $($candidateCases.Count) / $($allCases.Count)"

if ($candidateCases.Count -eq 0) {
    Write-Host "All cases already have metadata. Nothing to do." -ForegroundColor Green
    exit 0
}

# Apply MaxCases limit
$targetCases = $candidateCases
if ($MaxCases -gt 0 -and $candidateCases.Count -gt $MaxCases) {
    $targetCases = $candidateCases[0..($MaxCases - 1)]
    Write-Host "Limiting to first $MaxCases cases."
}

Write-Host ""

# --- Patch cases ---
$modeLabel = if ($DryRun) { "DRY RUN" } else { "PATCHING" }
Write-Host "--- $modeLabel ---" -ForegroundColor Yellow

$patchedCount = 0
$skippedCount = 0
$failedCount = 0
$failedCases = @()

for ($i = 0; $i -lt $targetCases.Count; $i++) {
    $entry = $targetCases[$i]
    $caseId = $entry.CaseId
    $requestType = $entry.RequestType
    $missingFields = $entry.MissingFields

    Write-Host "[$($i+1)/$($targetCases.Count)] Case $caseId (missing: $($missingFields -join ', '))" -NoNewline

    # Build PATCH body with only the missing fields
    $patchBody = @{}

    if ($missingFields -contains "title") {
        $patchBody["title"] = Get-GeneratedTitle -RequestType $requestType -CaseId $caseId
    }
    if ($missingFields -contains "country") {
        $patchBody["country"] = $countries[$i % $countries.Count]
    }
    if ($missingFields -contains "priority") {
        $patchBody["priority"] = $priorities[$i % $priorities.Count]
    }
    if ($missingFields -contains "assigneeName") {
        $patchBody["assigneeName"] = $assignees[$i % $assignees.Count]
    }

    if ($DryRun) {
        Write-Host "" -ForegroundColor White
        foreach ($field in $patchBody.Keys) {
            Write-Host "    [DRY RUN] $field = $($patchBody[$field])" -ForegroundColor DarkCyan
        }
        $patchedCount++
        continue
    }

    # Throttle between PATCHes
    if ($i -gt 0) { Start-Sleep -Seconds $ThrottleSeconds }

    # GET the case to obtain the current ETag
    $getResult = Invoke-BffApi -Method GET -Path "/api/v2/cases/$caseId"
    if (-not $getResult.Success) {
        Write-Host " FAILED (GET HTTP $($getResult.StatusCode))" -ForegroundColor Red
        $failedCount++
        $failedCases += "Case $caseId (GET failed: HTTP $($getResult.StatusCode))"
        continue
    }

    $etag = $getResult.Data.eTag
    if ([string]::IsNullOrEmpty($etag)) {
        $etag = $getResult.Data.etag
    }
    if ([string]::IsNullOrEmpty($etag)) {
        # Try response headers
        $etagHeader = $getResult.Headers["ETag"]
        if ($etagHeader) { $etag = $etagHeader }
    }

    if ([string]::IsNullOrEmpty($etag)) {
        Write-Host " SKIPPED (no ETag)" -ForegroundColor DarkYellow
        $skippedCount++
        continue
    }

    # PATCH the case
    $bodyJson = $patchBody | ConvertTo-Json -Depth 5
    $patchResult = Invoke-BffApi -Method PATCH -Path "/api/v2/cases/$caseId" -Body $bodyJson -ExtraHeaders @{ "If-Match" = $etag }

    if ($patchResult.Success) {
        Write-Host " OK" -ForegroundColor Green
        $patchedCount++
    } else {
        Write-Host " FAILED (PATCH HTTP $($patchResult.StatusCode))" -ForegroundColor Red
        if ($patchResult.Error) {
            Write-Host "    $($patchResult.Error)" -ForegroundColor DarkRed
        }
        $failedCount++
        $failedCases += "Case $caseId (PATCH failed: HTTP $($patchResult.StatusCode))"
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Backfill Summary ===" -ForegroundColor Cyan
Write-Host "Total cases:    $($allCases.Count)"
Write-Host "Candidates:     $($candidateCases.Count)"
Write-Host "Targeted:       $($targetCases.Count)"

$patchedColor = if ($failedCount -eq 0) { "Green" } else { "Yellow" }
if ($DryRun) {
    Write-Host "Would patch:    $patchedCount" -ForegroundColor Cyan
} else {
    Write-Host "Patched:        $patchedCount" -ForegroundColor $patchedColor
}

if ($skippedCount -gt 0) {
    Write-Host "Skipped:        $skippedCount (no ETag)" -ForegroundColor DarkYellow
}

if ($failedCount -gt 0) {
    Write-Host "Failed:         $failedCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failed cases:" -ForegroundColor Red
    foreach ($f in $failedCases) { Write-Host "  $f" -ForegroundColor Red }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
