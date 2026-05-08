<#
.SYNOPSIS
    LENS-CMS API smoke test - full CRUD cycle.

.DESCRIPTION
    Tests all Case API endpoints against a deployed LENS-CMS instance.
    Supports multiple authentication modes:
      - ManagedIdentity: Uses App Service MI (run from Kudu SSH or Azure resource)
      - Token: Uses a pre-acquired Bearer token (for local testing)

.PARAMETER BaseUrl
    App Service URL (default: https://app-cms-npe-tonym.azurewebsites.net)

.PARAMETER AuthMode
    Authentication mode: ManagedIdentity or Token (default: Token)

.PARAMETER Token
    Pre-acquired Bearer token (required for Token mode). Pass via $env:CMS_TEST_TOKEN.

.PARAMETER Verbose
    Show full request/response details.

.EXAMPLE
    # From Kudu SSH (PowerShell):
    .\Test-CmsApi.ps1 -AuthMode ManagedIdentity

    # From local machine with pre-acquired token:
    $token = az account get-access-token --resource "api://6c5a00ce-8062-49d8-b568-b9bd0363340b" --query accessToken -o tsv
    .\Test-CmsApi.ps1 -Token $token

    # Using environment variable:
    $env:CMS_TEST_TOKEN = "<token>"
    .\Test-CmsApi.ps1
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = "https://app-cms-npe-tonym.azurewebsites.net",
    [ValidateSet("ManagedIdentity", "Token")]
    [string]$AuthMode = "Token",
    [string]$Token = $env:CMS_TEST_TOKEN,
    [string]$Resource = "api://6c5a00ce-8062-49d8-b568-b9bd0363340b"
)

$ErrorActionPreference = "Stop"
$pass = 0
$fail = 0
$results = @()

function Write-TestResult($Name, $Success, $Detail) {
    $status = if ($Success) { "PASS" } else { "FAIL" }
    $color = if ($Success) { "Green" } else { "Red" }
    Write-Host "$status : $Name - $Detail" -ForegroundColor $color
    $script:results += [PSCustomObject]@{ Test = $Name; Status = $status; Detail = $Detail }
    if ($Success) { $script:pass++ } else { $script:fail++ }
}

function Get-ResponseDetail($Exception) {
    $statusCode = $null
    $body = ""
    try {
        $response = $Exception.Exception.Response
        $statusCode = [int]$response.StatusCode
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        $body = $reader.ReadToEnd()
        $reader.Close()
    } catch { }
    return @{ StatusCode = $statusCode; Body = $body }
}

Write-Host "=== LENS-CMS API Smoke Test ===" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl"
Write-Host "Auth Mode: $AuthMode"
Write-Host ""

# --- Acquire Token ---
if ($AuthMode -eq "ManagedIdentity") {
    Write-Host "--- Acquiring MI token ---"
    $tokenUrl = "$env:IDENTITY_ENDPOINT?resource=$Resource&api-version=2019-08-01"
    $miHeaders = @{ "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER }
    try {
        $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Headers $miHeaders -Method GET
        $Token = $tokenResponse.access_token
        Write-TestResult "TokenAcquisition" $true "MI token acquired ($($Token.Length) chars)"
    } catch {
        Write-TestResult "TokenAcquisition" $false "Failed: $($_.Exception.Message)"
        Write-Host "Are you running inside an App Service with managed identity?" -ForegroundColor Yellow
        exit 1
    }
} elseif ([string]::IsNullOrEmpty($Token)) {
    Write-Host "ERROR: No token provided. Use -Token parameter or set `$env:CMS_TEST_TOKEN" -ForegroundColor Red
    Write-Host ""
    Write-Host "To get a token (requires client credentials flow with idtyp=app):" -ForegroundColor Yellow
    Write-Host "  Use managed identity from an Azure resource, or"
    Write-Host "  Use -AuthMode ManagedIdentity from Kudu SSH" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "Using pre-acquired token ($($Token.Length) chars)"
}

$authHeaders = @{
    "Authorization" = "Bearer $Token"
    "Content-Type"  = "application/json"
}

# --- Test 1: Health (no auth) ---
Write-Host ""
Write-Host "--- Test 1: Health ---"
try {
    $health = Invoke-WebRequest -Uri "$BaseUrl/api/health" -Method GET -UseBasicParsing
    Write-TestResult "Health" $true "HTTP $($health.StatusCode)"
} catch {
    $detail = Get-ResponseDetail $_
    Write-TestResult "Health" $false "HTTP $($detail.StatusCode) - $($_.Exception.Message)"
}

# --- Test 2: List Cases ---
Write-Host "--- Test 2: List Cases ---"
try {
    $list = Invoke-WebRequest -Uri "$BaseUrl/api/v1/cases?pageSize=5" -Headers $authHeaders -Method GET -UseBasicParsing
    $listData = $list.Content | ConvertFrom-Json
    $itemCount = if ($listData.items) { $listData.items.Count } else { 0 }
    Write-TestResult "ListCases" $true "HTTP $($list.StatusCode) - $itemCount items"
    if ($VerbosePreference -eq "Continue") { Write-Verbose ($list.Content | ConvertFrom-Json | ConvertTo-Json -Depth 3) }
} catch {
    $detail = Get-ResponseDetail $_
    Write-TestResult "ListCases" $false "HTTP $($detail.StatusCode) - $($detail.Body)"
}

# --- Test 3: Create Case ---
Write-Host "--- Test 3: Create Case ---"
$createBody = @{
    requestType  = "LegalEnforcement"
    title        = "Smoke Test Case $(Get-Date -Format 'HH:mm:ss')"
    jurisdiction = "US"
    description  = "Automated smoke test"
} | ConvertTo-Json

$caseId = $null
$etag = $null
try {
    $create = Invoke-WebRequest -Uri "$BaseUrl/api/v1/cases" -Headers $authHeaders -Method POST -Body $createBody -UseBasicParsing
    $createData = $create.Content | ConvertFrom-Json
    $caseId = $createData.caseId
    $etag = $create.Headers["ETag"]
    Write-TestResult "CreateCase" $true "HTTP $($create.StatusCode) caseId=$caseId"
    if ($VerbosePreference -eq "Continue") { Write-Verbose ($createData | ConvertTo-Json -Depth 3) }
} catch {
    $detail = Get-ResponseDetail $_
    Write-TestResult "CreateCase" $false "HTTP $($detail.StatusCode) - $($detail.Body)"
}

if ($caseId) {
    # --- Test 4: Get Case ---
    Write-Host "--- Test 4: Get Case ---"
    $getEtag = $null
    try {
        $get = Invoke-WebRequest -Uri "$BaseUrl/api/v1/cases/$caseId" -Headers $authHeaders -Method GET -UseBasicParsing
        $getEtag = $get.Headers["ETag"]
        Write-TestResult "GetCase" $true "HTTP $($get.StatusCode) ETag=$getEtag"
        if ($VerbosePreference -eq "Continue") { Write-Verbose ($get.Content | ConvertFrom-Json | ConvertTo-Json -Depth 3) }
    } catch {
        $detail = Get-ResponseDetail $_
        Write-TestResult "GetCase" $false "HTTP $($detail.StatusCode) - $($detail.Body)"
    }

    # --- Test 5: Patch Case ---
    Write-Host "--- Test 5: Patch Case ---"
    $patchBody = '[{"op":"replace","path":"/title","value":"Updated Smoke Test"}]'
    $patchHeaders = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json-patch+json"
    }
    $patchEtag = if ($getEtag) { $getEtag } else { $etag }
    if ($patchEtag) { $patchHeaders["If-Match"] = $patchEtag }

    try {
        $patch = Invoke-WebRequest -Uri "$BaseUrl/api/v1/cases/$caseId" -Headers $patchHeaders -Method PATCH -Body $patchBody -UseBasicParsing
        Write-TestResult "PatchCase" $true "HTTP $($patch.StatusCode)"
    } catch {
        $detail = Get-ResponseDetail $_
        Write-TestResult "PatchCase" $false "HTTP $($detail.StatusCode) - $($detail.Body)"
    }

}

# --- Summary ---
Write-Host ""
Write-Host "=== Results: $pass passed, $fail failed ===" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host ""
if ($caseId) {
    Write-Host "Test case ID: $caseId (in Cosmos, can be manually deleted)" -ForegroundColor Yellow
}

exit $fail
