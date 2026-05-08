<#
.SYNOPSIS
    Generic throttle-aware batch loop with artifact persistence.

.DESCRIPTION
    Drives a callable operation across a list of inputs, persisting per-input
    artifacts to disk and adapting the inter-call delay based on observed throttle
    signals. Resumes from a manifest if the previous run was interrupted.

    Backoff schedule (default):
        - Initial delay: 0 seconds (fire-and-go)
        - On throttle signal: bump to 600s (10 min)
        - On second consecutive throttle: bump to 1800s (30 min)
        - On third+ consecutive throttle: cap at 3600s (60 min)
        - On a successful response: reset toward initial delay (decay)

    The Operation parameter is a script block that receives ($Input, $OutDir) and
    returns one of:
        - "OK"          : normal completion, write artifact
        - "THROTTLED"   : back off
        - "ERROR:<msg>" : record error, continue without backing off

.PARAMETER InputFile
    Path to a text file with one input per line (alias, query, PR ID, etc.).

.PARAMETER OutputDir
    Directory where per-input artifacts are written. Created if missing.

.PARAMETER Operation
    A scriptblock or path to a .ps1 to invoke per input. Receives ($Input, $OutDir).

.PARAMETER ManifestPath
    Optional manifest path (default <OutputDir>/manifest.json). Tracks per-input
    state for resume.

.PARAMETER InitialDelaySeconds
    Default 0.

.PARAMETER ThrottleDelaySeconds
    Default 600 (10 min). First-strike throttle delay.

.PARAMETER MaxDelaySeconds
    Default 3600 (60 min). Upper cap on backoff.

.PARAMETER DryRun
    Print the plan without executing.

.EXAMPLE
    # Generic example: process a list of peer aliases through a WorkIQ query operation
    $op = {
        param($peer, $outDir)
        # ... call WorkIQ via wrapper, save response to $outDir\$peer.json ...
        return "OK"
    }
    .\loop-with-backoff.ps1 -InputFile peers.txt -OutputDir .mad/scratch/peer-evidence -Operation $op
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputFile,

    [Parameter(Mandatory)]
    [string]$OutputDir,

    [Parameter(Mandatory)]
    $Operation,

    [string]$ManifestPath,
    [int]$InitialDelaySeconds = 0,
    [int]$ThrottleDelaySeconds = 600,
    [int]$MaxDelaySeconds = 3600,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputFile)) { Write-Error "Input file not found: $InputFile"; exit 2 }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
if (-not $ManifestPath) { $ManifestPath = Join-Path $OutputDir "manifest.json" }

# --- Load or initialize manifest ---
$manifest = if (Test-Path $ManifestPath) {
    Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -AsHashtable
} else {
    @{ created = (Get-Date -Format "o"); entries = @{} }
}
if (-not $manifest.entries) { $manifest.entries = @{} }

# --- Resolve operation ---
if ($Operation -is [string] -and (Test-Path $Operation)) {
    $opScript = $Operation
    $opIsFile = $true
} elseif ($Operation -is [scriptblock]) {
    $opIsFile = $false
} else {
    Write-Error "Operation must be a scriptblock or a path to a .ps1 file."
    exit 2
}

# --- Read inputs ---
$inputs = Get-Content -Path $InputFile | Where-Object { $_ -and -not $_.StartsWith("#") }
$totalInputs = $inputs.Count
$skipped = 0
$processed = 0
$errored = 0
$consecutiveThrottles = 0
$currentDelay = $InitialDelaySeconds

Write-Host ""
Write-Host "=== loop-with-backoff ===" -ForegroundColor Cyan
Write-Host ("Inputs:        {0}" -f $totalInputs)
Write-Host ("Output dir:    {0}" -f $OutputDir)
Write-Host ("Manifest:      {0}" -f $ManifestPath)
Write-Host ("Initial delay: {0}s" -f $InitialDelaySeconds)
Write-Host ("Throttle delay base: {0}s" -f $ThrottleDelaySeconds)
Write-Host ("Max delay:     {0}s" -f $MaxDelaySeconds)
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN, exiting." -ForegroundColor Yellow
    exit 0
}

# --- Main loop ---
foreach ($entry in $inputs) {
    $key = $entry.Trim()
    if (-not $key) { continue }
    if ($manifest.entries.ContainsKey($key) -and $manifest.entries[$key].status -eq "completed") {
        $skipped++
        Write-Host ("[skip] {0} (already completed)" -f $key) -ForegroundColor DarkGray
        continue
    }

    if ($currentDelay -gt 0) {
        Write-Host ("[wait] sleeping {0}s before next call..." -f $currentDelay) -ForegroundColor DarkYellow
        Start-Sleep -Seconds $currentDelay
    }

    Write-Host ("[run]  {0}" -f $key) -ForegroundColor Cyan
    $result = $null
    try {
        if ($opIsFile) {
            $result = & $opScript $key $OutputDir
        } else {
            $result = & $Operation $key $OutputDir
        }
    } catch {
        $result = "ERROR:$($_.Exception.Message)"
    }

    $manifest.entries[$key] = @{
        status     = "unknown"
        last_seen  = (Get-Date -Format "o")
        last_result = $result
    }

    switch -Wildcard ($result) {
        "OK" {
            $processed++
            $consecutiveThrottles = 0
            $currentDelay = [Math]::Max($InitialDelaySeconds, [int]($currentDelay / 2))
            $manifest.entries[$key].status = "completed"
            Write-Host ("[ok]   {0}" -f $key) -ForegroundColor Green
        }
        "THROTTLED" {
            $consecutiveThrottles++
            $currentDelay = switch ($consecutiveThrottles) {
                1 { $ThrottleDelaySeconds }
                2 { [Math]::Min($MaxDelaySeconds, $ThrottleDelaySeconds * 3) }
                default { $MaxDelaySeconds }
            }
            $manifest.entries[$key].status = "throttled"
            Write-Host ("[throttle] {0}: backing off to {1}s" -f $key, $currentDelay) -ForegroundColor Yellow
        }
        "ERROR:*" {
            $errored++
            $consecutiveThrottles = 0
            $manifest.entries[$key].status = "error"
            Write-Host ("[error] {0}: {1}" -f $key, $result) -ForegroundColor Red
        }
        default {
            $manifest.entries[$key].status = "unknown"
            Write-Host ("[?]    {0}: result {1}" -f $key, $result) -ForegroundColor DarkYellow
        }
    }

    # Persist manifest after every entry so a crash leaves usable state
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $ManifestPath -Encoding UTF8
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ("  Total:     {0}" -f $totalInputs)
Write-Host ("  Skipped:   {0} (already done)" -f $skipped)
Write-Host ("  Processed: {0}" -f $processed)
Write-Host ("  Errored:   {0}" -f $errored)
Write-Host ("  Throttles: {0}" -f $consecutiveThrottles)
Write-Host ""

if ($errored -gt 0) { exit 1 }
exit 0
