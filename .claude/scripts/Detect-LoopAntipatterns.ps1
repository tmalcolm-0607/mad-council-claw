#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Detect-LoopAntipatterns.ps1 - Aggregate the five antipattern flag files and
    exit non-zero if any contain unacknowledged entries.

.DESCRIPTION
    Reads:
      .mad/scratch/deferral-flags.json
      .mad/scratch/canonical-marker-flags.json
      .mad/scratch/top-n-cap-flags.json
      .mad/scratch/missing-testplan-flags.json    (computed if absent)
      .mad/scratch/missing-autofire-flags.json

    Counts unacknowledged entries (entries lacking acknowledged: true and
    acknowledged_by_user: true).

    Writes a structured report to stdout (or -OutputFile) and to
    .mad/scratch/loop-antipattern-summary.json.

    Exit codes:
      0 - all flag files empty or fully acknowledged (loop may proceed)
      1 - at least one antipattern category has live violations

    Used by:
      /loop wrapper before each iter "complete" decision
      Check-LoopStopConditions.ps1 (chained)
      validate-artifact-completeness.js hook (reads same files)

.PARAMETER RepoRoot
    Repo root path (default: parent of script's parent dir).

.PARAMETER OutputFile
    Optional path to also write the JSON summary.

.PARAMETER Quiet
    Suppress per-category stdout listing; only print the summary line.

.EXAMPLE
    powershell.exe -NoProfile -File .claude/scripts/Detect-LoopAntipatterns.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputFile,
    [switch]$Quiet
)

if (-not $RepoRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }
    $RepoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
}

$ErrorActionPreference = 'Continue'

$scratchDir = Join-Path $RepoRoot '.mad/scratch'
if (-not (Test-Path $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}

$flagFiles = @(
    @{ Name = 'deferrals';         File = 'deferral-flags.json' }
    @{ Name = 'canonical-markers'; File = 'canonical-marker-flags.json' }
    @{ Name = 'top-n-caps';        File = 'top-n-cap-flags.json' }
    @{ Name = 'missing-autofires'; File = 'missing-autofire-flags.json' }
)

$summary = @{
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    repo_root = $RepoRoot
    categories = @()
    total_unacknowledged = 0
    overall_pass = $true
}

foreach ($ff in $flagFiles) {
    $path = Join-Path $scratchDir $ff.File
    $entries = @()
    if (Test-Path $path) {
        try {
            $raw = Get-Content -Path $path -Raw -ErrorAction Stop
            if ($raw -and $raw.Trim()) {
                $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
                if ($parsed -is [System.Array]) {
                    $entries = $parsed
                } elseif ($parsed) {
                    $entries = @($parsed)
                }
            }
        } catch {
            Write-Warning "[$($ff.Name)] flag file unreadable ($path): $_"
        }
    }

    $live = @($entries | Where-Object {
        -not ($_.acknowledged -eq $true) -and -not ($_.acknowledged_by_user -eq $true)
    })

    $cat = @{
        name = $ff.Name
        flag_file = $ff.File
        total_entries = $entries.Count
        unacknowledged = $live.Count
        sample = if ($live.Count -gt 0) { $live[0] } else { $null }
    }
    $summary.categories += $cat
    $summary.total_unacknowledged += $live.Count

    if (-not $Quiet) {
        if ($live.Count -gt 0) {
            Write-Host "[FAIL] $($ff.Name): $($live.Count) unacknowledged of $($entries.Count) entries (file: .mad/scratch/$($ff.File))"
        } else {
            Write-Host "[PASS] $($ff.Name): clean"
        }
    }
}

# Computed: orphan specs (spec.md without sibling test-plan.md) modified in last 24h
$specsRoot = Join-Path $RepoRoot 'specs'
$orphanSpecs = @()
if (Test-Path $specsRoot) {
    $cutoff = (Get-Date).AddHours(-24)
    Get-ChildItem -Path $specsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $specPath = Join-Path $_.FullName 'spec.md'
        $tpPath = Join-Path $_.FullName 'test-plan.md'
        if (Test-Path $specPath) {
            $mtime = (Get-Item $specPath).LastWriteTime
            if ($mtime -ge $cutoff -and -not (Test-Path $tpPath)) {
                $orphanSpecs += @{
                    spec_dir = $_.Name
                    spec_path = $specPath
                    last_modified = $mtime.ToString('o')
                }
            }
        }
    }
}

$cat = @{
    name = 'missing-test-plans'
    flag_file = 'computed-from-disk'
    total_entries = $orphanSpecs.Count
    unacknowledged = $orphanSpecs.Count
    orphan_specs = $orphanSpecs
}
$summary.categories += $cat
$summary.total_unacknowledged += $orphanSpecs.Count

if (-not $Quiet) {
    if ($orphanSpecs.Count -gt 0) {
        Write-Host "[FAIL] missing-test-plans: $($orphanSpecs.Count) recently-modified spec(s) without sibling test-plan.md"
        $orphanSpecs | ForEach-Object { Write-Host "  - $($_.spec_dir)" }
    } else {
        Write-Host "[PASS] missing-test-plans: clean"
    }
}

$summary.overall_pass = ($summary.total_unacknowledged -eq 0)

$summaryPath = Join-Path $scratchDir 'loop-antipattern-summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8

if ($OutputFile) {
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
}

Write-Host ""
if ($summary.overall_pass) {
    Write-Host "[OVERALL PASS] All antipattern categories clean. ($($summary.total_unacknowledged) live violations)"
    exit 0
} else {
    Write-Host "[OVERALL FAIL] $($summary.total_unacknowledged) live violation(s) across $(($summary.categories | Where-Object { $_.unacknowledged -gt 0 }).Count) categor(ies)."
    Write-Host "Summary: $summaryPath"
    exit 1
}
