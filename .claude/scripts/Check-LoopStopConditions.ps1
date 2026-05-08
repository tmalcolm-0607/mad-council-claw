<#
.SYNOPSIS
    Verify the LENS-DCS standardization loop's stop conditions before any
    "loop complete" claim (iter1-F5).

.DESCRIPTION
    The orchestrator's /loop skill MUST run this script before declaring the
    loop complete. Exit 0 means all stop conditions are met. Exit 1 means at
    least one condition is unmet — the script lists which.

    Stop conditions (per .mad/work-items/lens-dcs-standardization/grading-rubric.md
    "Stop-condition snapshot" section):

      1. All 6 phases complete (status == "completed" in progress.json:phases).
      2. Final lens-standards-audit shows zero REQUIREMENT-tier violations.
      3. Median artifact grade >= 4 across all 5 axes for every phase.
      4. specs/<M>-lens-dcs-p<N>/ contains spec.md, plan.md, tasks.md,
         test-plan.md for each of phases 1..6.
      5. No phase has had >2 remediation rounds (hard cap on retries).

    Local-only failures (NU1900 etc.) do NOT count toward stop-condition
    failure; this script reads loop-state files only.

.PARAMETER ProgressJson
    Path to progress.json. Default: .mad/work-items/lens-dcs-standardization/progress.json

.PARAMETER GradingRubric
    Path to grading-rubric.md. Default: .mad/work-items/lens-dcs-standardization/grading-rubric.md

.PARAMETER ReportsDir
    Directory holding lens-standards-audit reports. Default: .mad/reports

.PARAMETER MaxRemediationRounds
    Hard cap on phase remediation rounds. Default: 2

.PARAMETER EnforceCouncilVerdictsFromPhase
    Phase ID at/above which the council-verdict artifact gate (Step 6) enforces
    presence + validity. Phases below this cutoff are grandfathered (they
    completed before the gate existed). Default: P2.

    Per d6-council-verdict-iter3a-2026-05-02.md M1 (bootstrap cutoff): P0 + P1
    completed without producing council-verdict artifacts; the gate must not
    block retroactively on those phases.

.EXAMPLE
    pwsh -NoProfile -File .claude/scripts/Check-LoopStopConditions.ps1
    # Exit 0 if loop is complete; exit 1 with explicit reasons otherwise.

.NOTES
    Conventions:
      - No `$args`; named parameters only (per patterns/powershell-conventions.md).
      - No `Set-StrictMode` (progress.json may have optional fields).
      - Single-quoted strings for literal patterns.
#>
[CmdletBinding()]
param(
    [string]$ProgressJson    = '.mad/work-items/lens-dcs-standardization/progress.json',
    [string]$GradingRubric   = '.mad/work-items/lens-dcs-standardization/grading-rubric.md',
    [string]$ReportsDir      = '.mad/reports',
    [string]$SpecsRoot       = 'specs',
    [int]   $MaxRemediationRounds = 2,
    [string]$EnforceCouncilVerdictsFromPhase = 'P2'
)

$ErrorActionPreference = 'Continue'

$failures = @()
$infos    = @()

function Add-Failure {
    param([string]$Message)
    $script:failures += $Message
}

function Add-Info {
    param([string]$Message)
    $script:infos += $Message
}

# ---- 1. progress.json: all 6 phases completed ---------------------------

if (-not (Test-Path $ProgressJson)) {
    Add-Failure "progress.json not found at $ProgressJson"
}
else {
    try {
        $progress = Get-Content $ProgressJson -Raw | ConvertFrom-Json
    }
    catch {
        Add-Failure "progress.json is not valid JSON: $($_.Exception.Message)"
        $progress = $null
    }

    if ($progress) {
        $phaseKeys = @('P1_scaffold','P2_structural_decomposition','P3_exception_boundary','P4_handler_extraction','P5_best_practices_gaps','P6_cleanup')
        foreach ($key in $phaseKeys) {
            $phase = $progress.phases.$key
            if ($null -eq $phase) {
                Add-Failure "progress.json:phases.$key is missing"
                continue
            }
            if ($phase.status -ne 'completed') {
                Add-Failure "Phase $key not complete (status=$($phase.status))"
            }

            # Remediation-rounds hard cap
            $rounds = 0
            if ($null -ne $phase.phase_remediation_rounds) {
                $rounds = [int]$phase.phase_remediation_rounds
            }
            if ($rounds -gt $MaxRemediationRounds) {
                Add-Failure "Phase $key exceeded remediation cap ($rounds > $MaxRemediationRounds)"
            }
        }

        # phase_pointer should not point to anything pending
        if ($progress.phase_pointer -and $progress.phase_pointer -notmatch '(?i)complete|finished|done') {
            Add-Failure "progress.json:phase_pointer still points to active work: $($progress.phase_pointer)"
        }
    }
}

# ---- 2. specs/ artifacts present for every phase ------------------------

$required = @('spec.md','plan.md','tasks.md','test-plan.md')

if (-not (Test-Path $SpecsRoot)) {
    Add-Failure "$SpecsRoot directory does not exist (no MAD pipeline artifacts produced for any phase)"
}
else {
    for ($n = 1; $n -le 6; $n++) {
        # Find specs/<M>-lens-dcs-p<N>/ for some integer M.
        $matches = Get-ChildItem -Path $SpecsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match ('^\d+-lens-dcs-p' + $n + '$') }

        if (-not $matches) {
            Add-Failure "No specs/<M>-lens-dcs-p$n/ directory exists for phase P$n"
            continue
        }

        $phaseDir = $matches[0].FullName
        $missing = @()
        foreach ($f in $required) {
            $p = Join-Path $phaseDir $f
            if (-not (Test-Path $p)) { $missing += $f }
        }
        if ($missing.Count -gt 0) {
            Add-Failure "Phase P$n missing MAD artifacts in $($matches[0].Name): $($missing -join ', ')"
        }
        else {
            Add-Info "Phase P$n MAD artifacts: present in $($matches[0].Name)"
        }
    }
}

# ---- 3. Median artifact grades >= 4 across 5 axes for every phase -------

if ($progress -and $progress.artifact_grades_median) {
    $grades = $progress.artifact_grades_median
    $axes = @('accuracy','completeness','skill_alignment','DX','confidence')

    for ($n = 1; $n -le 6; $n++) {
        $phaseGradeKey = $null
        foreach ($prop in $grades.PSObject.Properties.Name) {
            if ($prop -match ('P' + $n + '_')) {
                $phaseGradeKey = $prop
                break
            }
        }
        if (-not $phaseGradeKey) {
            Add-Failure "No artifact_grades_median entry for phase P$n in progress.json"
            continue
        }
        $phaseGrades = $grades.$phaseGradeKey
        foreach ($axis in $axes) {
            $val = $phaseGrades.$axis
            if ($null -eq $val) {
                Add-Failure "Phase P$n missing grade axis: $axis"
            }
            elseif ([int]$val -lt 4) {
                Add-Failure "Phase P$n grade $axis = $val (< 4)"
            }
        }
    }
}
else {
    Add-Failure "progress.json:artifact_grades_median is missing"
}

# ---- 4. lens-standards-audit REQUIREMENT-tier violations == 0 -----------

if (-not (Test-Path $ReportsDir)) {
    Add-Failure "Reports directory not found: $ReportsDir"
}
else {
    $auditReports = Get-ChildItem -Path $ReportsDir -Recurse -Filter 'audit-report.md' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if (-not $auditReports) {
        Add-Failure "No lens-standards-audit report (audit-report.md) found under $ReportsDir"
    }
    else {
        $latest = $auditReports[0]
        $content = Get-Content $latest.FullName -Raw

        # Look for "REQUIREMENT-tier violations: N" or similar shapes.
        $reqViolations = $null
        $patterns = @(
            'requirement[_\s\-]tier[_\s\-]violations?\s*[:=]?\s*(\d+)',
            'REQUIREMENT.*violations?\s*[:=]\s*(\d+)'
        )
        foreach ($pat in $patterns) {
            $m = [regex]::Match($content, $pat, 'IgnoreCase')
            if ($m.Success) {
                $reqViolations = [int]$m.Groups[1].Value
                break
            }
        }

        if ($null -eq $reqViolations) {
            # Fall back to progress.json's recorded baseline counter.
            if ($progress -and $progress.gate_scores -and $progress.gate_scores.P0_baseline) {
                # We can't determine final from baseline alone — flag.
                Add-Failure "Could not parse REQUIREMENT-tier violation count from latest audit report ($($latest.Name)); manual check required"
            }
            else {
                Add-Failure "Could not parse REQUIREMENT-tier violation count from $($latest.Name)"
            }
        }
        elseif ($reqViolations -gt 0) {
            Add-Failure "lens-standards-audit shows $reqViolations REQUIREMENT-tier violations (must be 0); source: $($latest.FullName)"
        }
        else {
            Add-Info "lens-standards-audit REQUIREMENT-tier violations: 0 (source: $($latest.Name))"
        }
    }
}

# ---- 6. Council-verdict artifact gate (per d6-council-verdict-iter3a) --
#
# Each phase >= $EnforceCouncilVerdictsFromPhase MUST have a council-verdict
# artifact at .mad/reports/council-verdict-{phaseId}-*.md. Phases below cutoff
# are grandfathered (M1 bootstrap cutoff).
#
# Validity oracle (M4):
#   (a) file size >= 500 bytes
#   (b) body matches /^##\s+Reviewer summary/      (case-insensitive)
#   (c) body matches /Median confidence:\s*\d+/     (case-insensitive)
#   (d) body matches /Decision:/  OR  /Verdict consensus:/  (case-insensitive)
#
# Retroactive-backfill check (M5):
#   If progress.json:phases.<phase>.completed_utc exists, compare verdict file
#   LastWriteTime to that. If LastWriteTime > completed_utc + 5min tolerance,
#   the verdict appears retroactively backfilled and is rejected.

function Get-PhaseSortKey {
    param([string]$PhaseId)
    # Extract integer from 'P\d+' anchor; return -1 if no match (sorts low).
    if ($PhaseId -match '^P(\d+)') { return [int]$Matches[1] }
    return -1
}

if ($progress -and $progress.phases) {
    $cutoffKey = Get-PhaseSortKey $EnforceCouncilVerdictsFromPhase

    foreach ($phaseProp in $progress.phases.PSObject.Properties) {
        $phaseFullKey = $phaseProp.Name        # e.g. P2_structural_decomposition
        $phaseObj     = $phaseProp.Value

        # Skip synthetic / obsolete entries (e.g. _P2_old_blocked_state_obsolete,
        # P0_*, P1_5_package_bump). Only enforce on canonical P\d+_* keys.
        if ($phaseFullKey -notmatch '^P(\d+)_') {
            continue
        }
        $phaseShort = 'P' + $Matches[1]   # P0, P1, P2, ...

        # Pre-cutoff phases: log INFO and skip the gate (M1 grandfathering).
        $phaseKey = Get-PhaseSortKey $phaseShort
        if ($phaseKey -lt $cutoffKey) {
            Add-Info "Council verdict gate not enforced for $phaseShort (pre-cutoff phase < $EnforceCouncilVerdictsFromPhase)"
            continue
        }

        # Skip phases that haven't started yet — gate fires on completed
        # phases only. A phase that's still 'pending' or 'ready' has no
        # advance to gate.
        if ($phaseObj.status -ne 'completed') {
            Add-Info "Council verdict gate deferred for $phaseShort (status=$($phaseObj.status); gate fires when phase completes)"
            continue
        }

        # M2 + M3: phase-keyed glob, no date in glob; sort by LastWriteTime.
        $verdictGlob = "council-verdict-$phaseShort-*.md"
        $verdicts = Get-ChildItem -Path $ReportsDir -Filter $verdictGlob -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        if (-not $verdicts) {
            Add-Failure "Phase $phaseShort has no council verdict artifact (expected $ReportsDir/council-verdict-$phaseShort-*.md)"
            continue
        }

        $verdictFile = $verdicts[0]
        $body = Get-Content $verdictFile.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $body) {
            Add-Failure "Council verdict for $phaseShort fails validity oracle: file unreadable or empty ($($verdictFile.Name))"
            continue
        }

        # M4 (a): size >= 500 bytes.
        if ($verdictFile.Length -lt 500) {
            Add-Failure "Council verdict for $phaseShort fails validity oracle: file size $($verdictFile.Length)B < 500B threshold ($($verdictFile.Name))"
            continue
        }

        # M4 (b): Reviewer summary heading.
        if ($body -notmatch '(?im)^##\s+Reviewer summary') {
            Add-Failure "Council verdict for $phaseShort fails validity oracle: missing '## Reviewer summary' heading ($($verdictFile.Name))"
            continue
        }

        # M4 (c): Median confidence:N.
        if ($body -notmatch '(?i)Median confidence:\s*\d+') {
            Add-Failure "Council verdict for $phaseShort fails validity oracle: missing 'Median confidence: N' ($($verdictFile.Name))"
            continue
        }

        # M4 (d): Decision: OR Verdict consensus:.
        if (($body -notmatch '(?i)Decision:') -and ($body -notmatch '(?i)Verdict consensus:')) {
            Add-Failure "Council verdict for $phaseShort fails validity oracle: missing 'Decision:' or 'Verdict consensus:' ($($verdictFile.Name))"
            continue
        }

        # M5: retroactive-backfill detection.
        if ($phaseObj.completed_utc) {
            $completedUtc = $null
            try { $completedUtc = [datetime]::Parse($phaseObj.completed_utc).ToUniversalTime() } catch {}
            if ($completedUtc) {
                $verdictUtc = $verdictFile.LastWriteTimeUtc
                $tolerance  = [timespan]::FromMinutes(5)
                if ($verdictUtc -gt ($completedUtc + $tolerance)) {
                    $delta = $verdictUtc - $completedUtc
                    Add-Failure "Council verdict for $phaseShort appears retroactively backfilled (verdict written $([int]$delta.TotalMinutes)min after phase completion; verdict=$($verdictFile.Name))"
                    continue
                }
            }
        }

        Add-Info "Council verdict artifact for ${phaseShort}: $($verdictFile.Name) (validity oracle passed)"
    }
}

# ---- Output summary -----------------------------------------------------

Write-Host ''
Write-Host '=== LENS-DCS Loop Stop-Condition Check ==='
Write-Host ''

if ($infos.Count -gt 0) {
    Write-Host 'Passing checks:'
    foreach ($i in $infos) { Write-Host "  [PASS] $i" }
    Write-Host ''
}

if ($failures.Count -eq 0) {
    Write-Host 'All stop conditions met. Loop may emit "complete".'
    Write-Host ''
    exit 0
}

Write-Host 'STOP CONDITIONS NOT MET:' -ForegroundColor Yellow
foreach ($f in $failures) {
    Write-Host "  [FAIL] $f"
}
Write-Host ''
Write-Host "Total failures: $($failures.Count)"
Write-Host 'Loop must NOT emit "complete" until all failures are resolved.'
Write-Host ''
exit 1
