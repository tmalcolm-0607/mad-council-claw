#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Track-SkillMetrics.ps1 - Aggregate skill-timing.jsonl into per-skill
    performance tables.

.DESCRIPTION
    Reads .mad/scratch/skill-timing.jsonl (one JSON line per skill
    completion, written by record-skill-completion.js) and emits a
    grouped report with min/median/p90/max duration per skill.

    Use:
      .\Track-SkillMetrics.ps1                  # full history
      .\Track-SkillMetrics.ps1 -Skill mad-plan   # filter to one skill
      .\Track-SkillMetrics.ps1 -SinceHours 24    # last 24h only
      .\Track-SkillMetrics.ps1 -SlowOnly         # only invocations > 10min

.PARAMETER Skill
    Filter to one skill name (e.g. "mad-plan").

.PARAMETER SinceHours
    Only include invocations within the last N hours.

.PARAMETER SlowOnly
    Only include invocations exceeding 10 minutes (the slow-run threshold).

.PARAMETER OutputFile
    Optional path to also write the report.
#>

[CmdletBinding()]
param(
    [string]$Skill,
    [int]$SinceHours = 0,
    [switch]$SlowOnly,
    [string]$OutputFile,
    [string]$RepoRoot
)

if (-not $RepoRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }
    $RepoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
}

$ErrorActionPreference = 'Continue'
$skillTimingLog = Join-Path $RepoRoot '.mad/scratch/skill-timing.jsonl'
$taskTimingLog  = Join-Path $RepoRoot '.mad/scratch/task-timing.jsonl'

if (-not (Test-Path $skillTimingLog) -and -not (Test-Path $taskTimingLog)) {
    Write-Output 'No timing logs found.'
    Write-Output '  Skill log:  .mad/scratch/skill-timing.jsonl  (populated by record-skill-completion.js on Skill tool use)'
    Write-Output '  Task log:   .mad/scratch/task-timing.jsonl   (populated by record-task-completion.js on Task tool use)'
    exit 0
}

$entries = @()
foreach ($line in (Get-Content -Path $skillTimingLog -ErrorAction SilentlyContinue)) {
    if (-not $line.Trim()) { continue }
    try {
        $entry = $line | ConvertFrom-Json -ErrorAction Stop
        if ($entry) {
            # Annotate as skill entry
            $entry | Add-Member -MemberType NoteProperty -Name 'kind' -Value 'skill' -Force
            $entries += $entry
        }
    } catch {
        Write-Warning "Skipping malformed line in skill log: $line"
    }
}

# Task entries: completion timestamps only (PostToolUse:Task can't see start time without a paired PreToolUse:Task hook).
# We surface these in the Recent invocations list and the per-skill summary uses kind='skill' only.
$taskEntries = @()
foreach ($line in (Get-Content -Path $taskTimingLog -ErrorAction SilentlyContinue)) {
    if (-not $line.Trim()) { continue }
    try {
        $entry = $line | ConvertFrom-Json -ErrorAction Stop
        if ($entry) {
            $entry | Add-Member -MemberType NoteProperty -Name 'kind' -Value 'task' -Force
            # Synthesize a 'skill' field for unified rendering: subagent_type
            if (-not $entry.skill) {
                $skillSyn = if ($entry.subagent_type) { 'task:' + $entry.subagent_type } else { 'task:unknown' }
                $entry | Add-Member -MemberType NoteProperty -Name 'skill' -Value $skillSyn -Force
            }
            # Synthesize duration_ms = 0 since we don't have started_at_ms (advisory: start-time pairing is future work)
            if (-not $entry.duration_ms) {
                $entry | Add-Member -MemberType NoteProperty -Name 'duration_ms' -Value 0 -Force
            }
            $taskEntries += $entry
        }
    } catch {
        Write-Warning "Skipping malformed line in task log: $line"
    }
}

if ($entries.Count -eq 0 -and $taskEntries.Count -eq 0) {
    Write-Output 'No timing entries found.'
    exit 0
}

# Apply filters
if ($Skill) {
    $entries = $entries | Where-Object { $_.skill -eq $Skill }
}
if ($SinceHours -gt 0) {
    $cutoffMs = ([DateTimeOffset](Get-Date).AddHours(-$SinceHours)).ToUnixTimeMilliseconds()
    $entries = $entries | Where-Object { $_.started_at_ms -ge $cutoffMs }
}
if ($SlowOnly) {
    $entries = $entries | Where-Object { $_.duration_ms -gt 600000 }
}

if ($entries.Count -eq 0) {
    Write-Output 'No entries match the filters.'
    exit 0
}

# Group by skill, compute stats
$lines = @()
$lines += '# Skill timing metrics'
$lines += ''
$lines += "Generated: $((Get-Date).ToString('o'))"
$lines += "Total invocations in scope: $($entries.Count)"
if ($Skill) { $lines += "Filter: skill = $Skill" }
if ($SinceHours -gt 0) { $lines += "Filter: since last $SinceHours hour(s)" }
if ($SlowOnly) { $lines += 'Filter: slow-only (> 10 min)' }
$lines += ''

$grouped = $entries | Group-Object -Property skill | Sort-Object Name

$lines += '## Per-skill summary'
$lines += ''
$lines += '| Skill | Invocations | Min | Median | p90 | Max | Total | Success rate | Avg in-tokens | Avg out-tokens | Avg cache-read |'
$lines += '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|'

function Format-Duration {
    param([int64]$ms)
    if ($ms -lt 1000) { return "${ms}ms" }
    $sec = [Math]::Round($ms / 1000, 1)
    if ($sec -lt 60) { return "${sec}s" }
    $min = [Math]::Round($ms / 60000, 1)
    return "${min}m"
}

function Get-Percentile {
    param([double[]]$Values, [double]$Pct)
    $sorted = $Values | Sort-Object
    $n = $sorted.Count
    if ($n -eq 0) { return 0 }
    if ($n -eq 1) { return $sorted[0] }
    $idx = [Math]::Min($n - 1, [Math]::Ceiling(($Pct / 100.0) * $n) - 1)
    if ($idx -lt 0) { $idx = 0 }
    return $sorted[$idx]
}

foreach ($g in $grouped) {
    $durations = @($g.Group | ForEach-Object { [double]$_.duration_ms })
    $count = $durations.Count
    $min = ($durations | Measure-Object -Minimum).Minimum
    $max = ($durations | Measure-Object -Maximum).Maximum
    $sum = ($durations | Measure-Object -Sum).Sum
    $median = Get-Percentile -Values $durations -Pct 50
    $p90 = Get-Percentile -Values $durations -Pct 90

    # Success rate (success + success-no-marker + success-empty-response counted as success;
    # failure / failure-likely counted as failure; unknown excluded from denominator)
    $outcomes = @($g.Group | ForEach-Object { $_.outcome })
    $known = @($outcomes | Where-Object { $_ -and $_ -ne 'unknown' })
    $successes = @($known | Where-Object { $_ -like 'success*' }).Count
    $successRate = if ($known.Count -gt 0) { '{0:N0}%' -f (100.0 * $successes / $known.Count) } else { 'n/a' }

    # Token averages (skip nulls)
    $inputs = @($g.Group | Where-Object { $_.tokens -and $_.tokens.input } | ForEach-Object { [double]$_.tokens.input })
    $outputs = @($g.Group | Where-Object { $_.tokens -and $_.tokens.output } | ForEach-Object { [double]$_.tokens.output })
    $cacheReads = @($g.Group | Where-Object { $_.tokens -and $_.tokens.cache_read } | ForEach-Object { [double]$_.tokens.cache_read })

    $avgIn = if ($inputs.Count -gt 0) { '{0:N0}' -f (($inputs | Measure-Object -Average).Average) } else { 'n/a' }
    $avgOut = if ($outputs.Count -gt 0) { '{0:N0}' -f (($outputs | Measure-Object -Average).Average) } else { 'n/a' }
    $avgCache = if ($cacheReads.Count -gt 0) { '{0:N0}' -f (($cacheReads | Measure-Object -Average).Average) } else { 'n/a' }

    $lines += "| $($g.Name) | $count | $(Format-Duration $min) | $(Format-Duration $median) | $(Format-Duration $p90) | $(Format-Duration $max) | $(Format-Duration $sum) | $successRate | $avgIn | $avgOut | $avgCache |"
}

$lines += ''
$lines += '## Slow-run flag list (> 10 min)'
$lines += ''
$slowOnes = $entries | Where-Object { $_.duration_ms -gt 600000 } | Sort-Object -Property duration_ms -Descending
if ($slowOnes.Count -eq 0) {
    $lines += '_No invocations exceeded the slow-run threshold._'
} else {
    $lines += '| Skill | Duration | Completed | Session |'
    $lines += '|---|---:|---|---|'
    foreach ($e in $slowOnes) {
        $sid = if ($e.session_id) { $e.session_id.Substring(0, 8) + '...' } else { 'n/a' }
        $lines += "| $($e.skill) | $(Format-Duration $e.duration_ms) | $($e.completed_at_iso) | $sid |"
    }
}

$lines += ''
$lines += '## Recent invocations (last 20 — Skills + Tasks merged)'
$lines += ''
$lines += '| When | Kind | Skill / Subagent | Duration | Session |'
$lines += '|---|---|---|---:|---|'

# Merge skill + task entries for the recent view; per-skill summary above remains skill-only
$mergedRecent = @()
foreach ($e in $entries) { $mergedRecent += $e }
foreach ($e in $taskEntries) { $mergedRecent += $e }

$recent = $mergedRecent | Sort-Object -Property completed_at_ms -Descending | Select-Object -First 20
foreach ($e in $recent) {
    $sid = if ($e.session_id) { $e.session_id.Substring(0, 8) + '...' } else { 'n/a' }
    $kind = if ($e.kind) { $e.kind } else { 'skill' }
    $dur = if ($e.duration_ms -and $e.duration_ms -gt 0) { Format-Duration $e.duration_ms } else { '-' }
    $lines += "| $($e.completed_at_iso) | $kind | $($e.skill) | $dur | $sid |"
}

if ($taskEntries.Count -gt 0) {
    $lines += ''
    $lines += "_Task entries show completion timestamp only; per-Task duration_ms requires a paired PreToolUse:Task hook (future tooling). Skill entries have full duration via record-skill-completion.js._"
}

$report = $lines -join "`n"
$report | Write-Output

if ($OutputFile) {
    $report | Set-Content -Path $OutputFile -Encoding UTF8
    Write-Output ''
    Write-Output "Report written: $OutputFile"
}

# Exit non-zero if any slow runs exist (so CI can flag)
if ($slowOnes.Count -gt 0) { exit 2 }
exit 0
