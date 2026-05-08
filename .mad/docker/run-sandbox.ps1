#Requires -Version 7

<#
.SYNOPSIS
  Build + run the MAD.Council sandbox container, collect report, teardown.

.DESCRIPTION
  Wraps `docker build` + `docker run --rm` with correct bind-mounts for Windows.
  Report JSON lands in MAD/docker/reports/smoke-<timestamp>.json.

  With --rm on `docker run`, the container self-deletes after exit. No manual
  teardown required. Image stays cached for fast subsequent runs.

  Modeled on:
  - plugins/test-sentinel/skills/fleet-generation/ — checkpoint state pattern
  - plugins/test-sentinel/skills/coverage-pipeline/ — idempotent re-run + SHA256 backup

.PARAMETER Cleanup
  Remove the mad-sandbox image + build cache after the run. Use when you want a
  fully-clean workstation (e.g., end-of-day, before switching branches).

.PARAMETER SkipBuild
  Skip the docker build step. Use when iterating on the smoke suite script and
  the image hasn't changed.

.PARAMETER SkipCategory
  Comma-separated categories to skip (matches coverage-pipeline step-skip pattern):
  schema, crosslink, scriptparse, frontmatter, stubfiring.

.EXAMPLE
  pwsh MAD/docker/run-sandbox.ps1
  # Build + run + report

.EXAMPLE
  pwsh MAD/docker/run-sandbox.ps1 -SkipBuild
  # Re-run against cached image

.EXAMPLE
  pwsh MAD/docker/run-sandbox.ps1 -Cleanup
  # Full cleanup after run

.NOTES
  Requires Docker Desktop on Windows / Docker Engine on Linux/macOS.
  Tested on Windows 11 + Docker Desktop with WSL2 backend.
#>

[CmdletBinding()]
param(
    [switch] $Cleanup,
    [switch] $SkipBuild,
    [string] $SkipCategory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dockerDir = Split-Path -Parent $PSCommandPath
$madRoot   = Split-Path -Parent $dockerDir
$reportDir = Join-Path $dockerDir 'reports'

# Ensure report dir exists (host side)
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir | Out-Null
}

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$sessionId  = [guid]::NewGuid().ToString('N').Substring(0, 8)
$reportFile = "smoke-$timestamp-$sessionId.json"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " MAD.Council sandbox — run $sessionId" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Docker dir : $dockerDir"
Write-Host "  MAD root   : $madRoot"
Write-Host "  Report dir : $reportDir"
Write-Host "  Session    : $sessionId"
Write-Host ""

# 1. Verify Docker is available
try {
    $null = & docker version --format '{{.Server.Version}}' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker command returned $LASTEXITCODE" }
} catch {
    Write-Error "Docker is not available. Install Docker Desktop (Windows) or Docker Engine (Linux/macOS)."
    exit 2
}

# 2. Build (unless skipped)
if (-not $SkipBuild) {
    Write-Host "-> Building image..." -ForegroundColor Yellow
    & docker build -t mad-sandbox:latest -f (Join-Path $dockerDir 'Dockerfile') $dockerDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "docker build failed (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
} else {
    Write-Host "-> Skipping build (SkipBuild)"
}

# 3. Run the sandbox
Write-Host "-> Running sandbox..." -ForegroundColor Yellow

$sandboxArgs = @(
    'run'
    '--rm'
    '--name', "mad-sandbox-$sessionId"
    '--read-only'                                       # container FS read-only
    '--tmpfs', '/tmp:size=64m'                          # small tmpfs for ephemeral workspace
    '-v', "${madRoot}:/mad:ro"                          # source tree, RO
    '-v', "${reportDir}:/mad-report"                    # reports, RW
    '-e', "SANDBOX_SESSION_ID=$sessionId"
    '-e', "SANDBOX_SKIP_CATEGORY=$SkipCategory"
    'mad-sandbox:latest'
    '-ReportPath', "/mad-report/$reportFile"
    '-MadRoot', '/mad'
)

& docker @sandboxArgs
$runExit = $LASTEXITCODE

# 4. Report summary
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
$reportPath = Join-Path $reportDir $reportFile
if (Test-Path $reportPath) {
    try {
        $report = Get-Content $reportPath -Raw | ConvertFrom-Json
        $s = $report.summary
        Write-Host " Results: $($s.pass) pass / $($s.fail) fail / $($s.warn) warn / $($s.skip) skip" -ForegroundColor $( if ($s.fail -gt 0) { 'Red' } else { 'Green' } )
        Write-Host " Report : $reportPath"
    } catch {
        Write-Warning "Report file exists but could not parse: $($_.Exception.Message)"
    }
} else {
    Write-Warning "No report file produced at $reportPath — container may have crashed."
}

# 5. Optional cleanup
if ($Cleanup) {
    Write-Host "-> Cleanup: removing image + build cache..." -ForegroundColor Yellow
    & docker image rm mad-sandbox:latest 2>&1 | Out-Null
    & docker builder prune -f 2>&1 | Out-Null
    Write-Host "   Image + cache removed."
}

Write-Host "==========================================================" -ForegroundColor Cyan

exit $runExit
