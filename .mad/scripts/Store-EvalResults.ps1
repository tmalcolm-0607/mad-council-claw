<#
.SYNOPSIS
    Upload agent eval result JSON to Azure Blob Storage.

.DESCRIPTION
    Stores eval results in blob storage for historical tracking and trend analysis.
    Creates two blobs per run:
    - {branch}/{YYYY}/{MM}/{run_id}.json - Permanent record
    - {branch}/latest.json - Quick access (overwrite)

.PARAMETER ResultFile
    Path to eval result JSON file (required).

.PARAMETER Environment
    Target environment storage account: tonym, npe (default: tonym).

.PARAMETER Branch
    Override branch name (default: read from JSON git_branch field).

.EXAMPLE
    .\Store-EvalResults.ps1 -ResultFile .mad/tests/results/eval-20260214-123456.json
    .\Store-EvalResults.ps1 -ResultFile results.json -Environment npe -Branch feature/agent-teams

.NOTES
    Storage account naming: stlenscmseval{environment}wus3
    Container name: eval-results
    Requires: Azure CLI with authenticated session (az login)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResultFile,

    [ValidateSet("tonym", "npe")]
    [string]$Environment = "tonym",

    [string]$Branch
)

$ErrorActionPreference = "Stop"

# --- Constants ---
$StorageAccountPrefix = "stlenscmseval"
$StorageAccountSuffix = "wus3"
$ContainerName = "eval-results"

# --- Helpers ---
function Write-Status {
    param([string]$Message, [ValidateSet("Info","Success","Warning","Error")][string]$Type = "Info")
    $colors = @{ Info="Cyan"; Success="Green"; Warning="Yellow"; Error="Red" }
    $prefix = @{ Info="[*]"; Success="[+]"; Warning="[!]"; Error="[-]" }
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Get-SanitizedBranch {
    param([string]$BranchName)
    # Replace / with - for blob path compatibility
    return $BranchName -replace '/', '-'
}

# --- Main ---

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Store Eval Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate result file exists
if (-not (Test-Path $ResultFile)) {
    Write-Status "Result file not found: $ResultFile" -Type Error
    exit 1
}

Write-Status "Reading result file: $ResultFile" -Type Info

# Load and validate JSON
try {
    $resultJson = Get-Content $ResultFile -Raw | ConvertFrom-Json
} catch {
    Write-Status "Failed to parse JSON: $($_.Exception.Message)" -Type Error
    exit 1
}

# Extract metadata
$runId = $resultJson.run_id
if (-not $runId) {
    Write-Status "Missing required field: run_id" -Type Error
    exit 1
}

if (-not $Branch) {
    $Branch = $resultJson.git_branch
    if (-not $Branch) {
        Write-Status "Missing git_branch in JSON and no -Branch parameter provided" -Type Error
        exit 1
    }
}

$sanitizedBranch = Get-SanitizedBranch -BranchName $Branch
$storageAccount = "$StorageAccountPrefix$Environment$StorageAccountSuffix"

Write-Status "Run ID: $runId" -Type Info
Write-Status "Branch: $Branch (sanitized: $sanitizedBranch)" -Type Info
Write-Status "Environment: $Environment" -Type Info
Write-Status "Storage Account: $storageAccount" -Type Info
Write-Host ""

# Determine blob paths
$timestamp = $resultJson.timestamp_utc
if ($timestamp -match '^(\d{4})-(\d{2})') {
    $year = $matches[1]
    $month = $matches[2]
} else {
    # Fallback: parse from run_id (format: eval-YYYYMMDD-HHMMSS-sha)
    if ($runId -match 'eval-(\d{4})(\d{2})') {
        $year = $matches[1]
        $month = $matches[2]
    } else {
        Write-Status "Could not extract year/month from timestamp or run_id" -Type Error
        exit 1
    }
}

$permanentBlobPath = "$sanitizedBranch/$year/$month/$runId.json"
$latestBlobPath = "$sanitizedBranch/latest.json"

Write-Status "Uploading to blob storage..." -Type Info
Write-Status "  Permanent: $permanentBlobPath" -Type Info
Write-Status "  Latest:    $latestBlobPath" -Type Info
Write-Host ""

# Upload permanent record
Write-Status "Uploading permanent record..." -Type Info
az storage blob upload `
    --account-name $storageAccount `
    --container-name $ContainerName `
    --auth-mode login `
    --file $ResultFile `
    --name $permanentBlobPath `
    --overwrite 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Status "Failed to upload permanent record" -Type Error
    exit 1
}
Write-Status "Permanent record uploaded" -Type Success

# Upload latest
Write-Status "Uploading latest.json..." -Type Info
az storage blob upload `
    --account-name $storageAccount `
    --container-name $ContainerName `
    --auth-mode login `
    --file $ResultFile `
    --name $latestBlobPath `
    --overwrite 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Status "Failed to upload latest.json" -Type Error
    exit 1
}
Write-Status "Latest.json uploaded" -Type Success

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Upload Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Generate blob URLs
$permanentUrl = "https://$storageAccount.blob.core.windows.net/$ContainerName/$permanentBlobPath"
$latestUrl = "https://$storageAccount.blob.core.windows.net/$ContainerName/$latestBlobPath"

Write-Status "Blob URLs:" -Type Success
Write-Host "  Permanent: $permanentUrl" -ForegroundColor White
Write-Host "  Latest:    $latestUrl" -ForegroundColor White
Write-Host ""
