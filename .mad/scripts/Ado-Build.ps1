<#
.SYNOPSIS
    Queue an ADO build, wait for completion, and download artifacts.
    Authenticates via az CLI (uses cached token from 'az login').

.PARAMETER Branch
    Git branch to build (default: current branch in LENS-CMS submodule)

.PARAMETER SkipDownload
    Don't download artifacts after build completes

.PARAMETER PipelineId
    ADO pipeline ID (default: 52320 = LENS-CMS Unofficial Build)

.EXAMPLE
    .\Ado-Build.ps1
    .\Ado-Build.ps1 -Branch "users/tonym/004-case-api-auth"
    .\Ado-Build.ps1 -SkipDownload
#>
[CmdletBinding()]
param(
    [string]$Branch,
    [switch]$SkipDownload,
    [int]$PipelineId = 52320,
    [string]$Organization = "https://dev.azure.com/o365exchange",
    [string]$Project = "O365 Core"
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

$ArtifactPath = "C:\source\CCGHCP\src\LENS-CMS\build-artifacts"

# --- Detect branch ---
if (-not $Branch) {
    $Branch = git -C "C:\source\CCGHCP\src\LENS-CMS" branch --show-current
    Write-Host "Detected branch: $Branch" -ForegroundColor Cyan
}

# --- Queue build ---
Write-Host "=== Queuing Build ===" -ForegroundColor Cyan
Write-Host "Pipeline: $PipelineId"
Write-Host "Branch:   $Branch"
Write-Host ""

$buildJson = az pipelines run --id $PipelineId --branch $Branch `
    --organization $Organization --project $Project --output json
$build = $buildJson | ConvertFrom-Json
$buildId = $build.id
Write-Host "Build queued: ID=$buildId" -ForegroundColor Green

# --- Wait for completion ---
Write-Host ""
Write-Host "--- Waiting for build ---" -ForegroundColor Yellow
$maxIter = 30  # 30 * 30s = 15 min
$i = 0
do {
    Start-Sleep -Seconds 30
    $i++
    $statusJson = az pipelines build show --id $buildId `
        --organization $Organization --project $Project --output json
    $status = $statusJson | ConvertFrom-Json
    $elapsed = [math]::Round($i * 0.5, 1)
    $bn = $status.buildNumber
    Write-Host "[$elapsed min] $bn - Status: $($status.status) Result: $($status.result)" -ForegroundColor $(
        if ($status.result -eq "succeeded") { "Green" }
        elseif ($status.result -eq "failed") { "Red" }
        else { "DarkYellow" }
    )
} while ($status.status -ne "completed" -and $i -lt $maxIter)

if ($status.result -ne "succeeded") {
    Write-Host "`n=== BUILD FAILED ===" -ForegroundColor Red
    Write-Host "Build ID: $buildId"
    exit 1
}

$buildNumber = $status.buildNumber
Write-Host "`n=== BUILD SUCCEEDED: $buildNumber ===" -ForegroundColor Green

# --- Download artifacts ---
if (-not $SkipDownload) {
    Write-Host ""
    Write-Host "--- Downloading artifacts ---" -ForegroundColor Yellow
    az pipelines runs artifact download --run-id $buildId `
        --artifact-name drop --path $ArtifactPath `
        --organization $Organization --project $Project
    Write-Host "Artifacts downloaded to: $ArtifactPath" -ForegroundColor Green

    $buildver = Get-Content (Join-Path $ArtifactPath "target\publish\CMS\ev2\ServiceGroupRoot\buildver.txt") -Raw
    Write-Host "Build version: $($buildver.Trim())" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next: Deploy with:" -ForegroundColor Cyan
Write-Host "  .\Ev2-Deploy.ps1 -Environment tonym"
