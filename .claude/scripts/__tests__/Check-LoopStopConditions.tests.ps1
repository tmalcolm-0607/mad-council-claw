<#
.SYNOPSIS
    Self-contained tests for the council-verdict artifact gate (Step 6) added
    to Check-LoopStopConditions.ps1 per d6-council-verdict-iter3a-2026-05-02.md.

.DESCRIPTION
    No Pester dependency. Each test:
      1. Builds a temp-dir fixture (progress.json + reports dir + specs dir)
      2. Invokes Check-LoopStopConditions.ps1 with explicit -*Path overrides
      3. Asserts on the captured stdout + exit code

    Tests cover Step 6 only — the existing Steps 1-5 are exercised by the
    end-to-end smoke run against the live state, not by these unit tests.

    Run from repo root:
      pwsh -NoProfile -File .claude/scripts/__tests__/Check-LoopStopConditions.tests.ps1

.NOTES
    Single-quoted strings for literal patterns (per powershell-conventions.md).
    No `$args`; named parameters only.
    No Set-StrictMode (mirrors script under test).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# Resolve script under test relative to this test file.
$thisDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $thisDir
$scriptUnderTest = Join-Path $scriptDir 'Check-LoopStopConditions.ps1'

if (-not (Test-Path $scriptUnderTest)) {
    Write-Host "FATAL: Script under test not found at $scriptUnderTest" -ForegroundColor Red
    exit 2
}

$testResults = @()
$passCount = 0
$failCount = 0

function New-FixtureRoot {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("loopstop-test-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp 'reports')   -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp 'specs')     -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp 'work-item') -Force | Out-Null
    return $tmp
}

function Write-FixtureProgress {
    param(
        [string]$FixtureRoot,
        [hashtable]$P2     = @{ status = 'completed'; completed_utc = '2026-05-02T12:00:00Z' },
        [hashtable]$Extras = @{}
    )
    $progress = @{
        '$schema_note' = 'test fixture'
        loop_id        = 'test-loop'
        phase_pointer  = 'complete'
        phases         = @{
            P0_docs_refresh           = @{ status = 'completed'; completed_utc = '2026-05-01T22:00:00Z' }
            P1_scaffold               = @{ status = 'completed'; completed_utc = '2026-05-02T06:30:00Z' }
            P2_structural_decomposition = $P2
            P3_exception_boundary     = @{ status = 'pending' }
            P4_handler_extraction     = @{ status = 'pending' }
            P5_best_practices_gaps    = @{ status = 'pending' }
            P6_cleanup                = @{ status = 'pending' }
        }
        artifact_grades_median = @{
            P1_scaffold = @{ accuracy = 5; completeness = 4; skill_alignment = 4; DX = 4; confidence = 4 }
        }
    }
    foreach ($k in $Extras.Keys) { $progress[$k] = $Extras[$k] }
    $progressPath = Join-Path $FixtureRoot 'work-item/progress.json'
    ($progress | ConvertTo-Json -Depth 10) | Set-Content -Path $progressPath -Encoding UTF8
    return $progressPath
}

function Write-ValidVerdict {
    param([string]$ReportsDir, [string]$Phase, [string]$Date = '2026-05-02')
    $body = @"
# Council verdict — $Phase

**Date:** $Date

## Reviewer summary

| Role | Verdict | Confidence |
|---|---|---|
| Architect | FIX | 82 |
| Skeptic | FIX | 85 |
| Advocate | ACCEPT | 80 |

Median confidence: 82

Decision: FIX

Some additional padding text to push the file past the 500-byte validity-oracle
threshold so the M4 size check passes. The gate enforces a minimum body size to
prevent stub-file bypass attacks where an agent under context pressure creates
an empty filename to satisfy the gate. Padding padding padding padding padding.
"@
    $path = Join-Path $ReportsDir "council-verdict-$Phase-$Date.md"
    Set-Content -Path $path -Value $body -Encoding UTF8
    return $path
}

function Invoke-ScriptUnderTest {
    param(
        [string]$ProgressJson,
        [string]$ReportsDir,
        [string]$SpecsRoot,
        [string]$EnforceFromPhase = 'P2'
    )
    # The script under test uses Write-Host (information stream, stream 6).
    # We must redirect 6>&1 to capture it via the success stream. *>&1 also
    # works (all streams). Without 6>&1, Out-String captures nothing.
    $output = & $scriptUnderTest `
        -ProgressJson $ProgressJson `
        -ReportsDir $ReportsDir `
        -SpecsRoot $SpecsRoot `
        -EnforceCouncilVerdictsFromPhase $EnforceFromPhase *>&1 | Out-String
    return [pscustomobject]@{
        Output   = $output
        ExitCode = $LASTEXITCODE
    }
}

function Assert-Test {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passCount++
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Yellow }
        $script:failCount++
    }
}

# ---- Test 1: Phase < cutoff is grandfathered (INFO, no FAIL) -----------
Write-Host ''
Write-Host 'Test 1: Phase < cutoff (P1 with cutoff=P2) -- INFO, not FAIL' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $progressPath = Write-FixtureProgress -FixtureRoot $root
    $result = Invoke-ScriptUnderTest `
        -ProgressJson $progressPath `
        -ReportsDir   (Join-Path $root 'reports') `
        -SpecsRoot    (Join-Path $root 'specs') `
        -EnforceFromPhase 'P2'

    # Match against the full captured-output string. -match returns Boolean;
    # using the .NET Contains helps avoid regex meta issues with brackets.
    $hasP1Info = $result.Output.Contains('Council verdict gate not enforced for P1')
    $hasP1Fail = $result.Output.Contains('P1 has no council verdict')
    Assert-Test 'P1 logged as grandfathered (INFO)' $hasP1Info "expected 'Council verdict gate not enforced for P1' in output"
    Assert-Test 'P1 NOT in FAIL list'                (-not $hasP1Fail)
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# ---- Test 2: Phase >= cutoff with no artifact -- FAIL --------------------
Write-Host ''
Write-Host 'Test 2: Phase >= cutoff with no artifact -- FAIL with prefix' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $progressPath = Write-FixtureProgress -FixtureRoot $root
    # No verdict artifact written.
    $result = Invoke-ScriptUnderTest `
        -ProgressJson $progressPath `
        -ReportsDir   (Join-Path $root 'reports') `
        -SpecsRoot    (Join-Path $root 'specs') `
        -EnforceFromPhase 'P2'

    $failLine = $result.Output.Contains('Phase P2 has no council verdict artifact')
    Assert-Test 'P2 missing artifact reported' $failLine "expected 'Phase P2 has no council verdict artifact' in FAIL list"
    Assert-Test 'Exit code != 0'               ($result.ExitCode -ne 0)
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# ---- Test 3: Stub artifact (<500B) -- validity oracle FAIL ---------------
Write-Host ''
Write-Host 'Test 3: Stub artifact <500B -- validity oracle FAIL' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $progressPath = Write-FixtureProgress -FixtureRoot $root
    $stub = Join-Path $root 'reports/council-verdict-P2-2026-05-02.md'
    Set-Content -Path $stub -Value '# Stub' -Encoding UTF8
    $result = Invoke-ScriptUnderTest `
        -ProgressJson $progressPath `
        -ReportsDir   (Join-Path $root 'reports') `
        -SpecsRoot    (Join-Path $root 'specs') `
        -EnforceFromPhase 'P2'

    # The stub-message text is "fails validity oracle: file size NB < 500B threshold"
    $sizeFail = $result.Output.Contains('fails validity oracle: file size') -and $result.Output.Contains('< 500B threshold')
    Assert-Test 'Stub flagged as too small' $sizeFail "expected 'fails validity oracle: file size ... < 500B threshold' in output"
    Assert-Test 'Exit code != 0'            ($result.ExitCode -ne 0)
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# ---- Test 4: Valid artifact -- gate passes -------------------------------
Write-Host ''
Write-Host 'Test 4: Valid artifact present -- gate passes' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    # Set completed_utc to now so retroactive-backfill check (M5) does not fire.
    $nowIso = (Get-Date).ToUniversalTime().ToString('o')
    $progressPath = Write-FixtureProgress -FixtureRoot $root `
        -P2 @{ status = 'completed'; completed_utc = $nowIso }
    $verdictPath = Write-ValidVerdict -ReportsDir (Join-Path $root 'reports') -Phase 'P2' -Date '2026-05-02'

    $result = Invoke-ScriptUnderTest `
        -ProgressJson $progressPath `
        -ReportsDir   (Join-Path $root 'reports') `
        -SpecsRoot    (Join-Path $root 'specs') `
        -EnforceFromPhase 'P2'

    $passLine      = $result.Output.Contains('Council verdict artifact for P2') -and $result.Output.Contains('validity oracle passed')
    $noVerdictFail = -not $result.Output.Contains('fails validity oracle')
    $noBackfill    = -not $result.Output.Contains('retroactively backfilled')
    Assert-Test 'P2 verdict acknowledged as valid' $passLine "expected '[PASS] Council verdict artifact for P2 ... validity oracle passed' in output"
    Assert-Test 'No validity-oracle FAIL for P2'   $noVerdictFail
    Assert-Test 'No retroactive-backfill FAIL'     $noBackfill
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# ---- Test 5: Retroactive backfill (LastWriteTime > completed_utc + 5min) -
Write-Host ''
Write-Host 'Test 5: Retroactive backfill -- FAIL on M5 check' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    # Phase completed at 2026-05-02T00:00:00Z. We will write the verdict NOW
    # (current time, well past +5min tolerance from that completed_utc).
    $progressPath = Write-FixtureProgress -FixtureRoot $root `
        -P2 @{ status = 'completed'; completed_utc = '2026-05-02T00:00:00Z' }
    $verdictPath = Write-ValidVerdict -ReportsDir (Join-Path $root 'reports') -Phase 'P2' -Date '2026-05-02'

    # Force LastWriteTime to NOW (already is, but be explicit).
    (Get-Item $verdictPath).LastWriteTimeUtc = [datetime]::UtcNow

    $result = Invoke-ScriptUnderTest `
        -ProgressJson $progressPath `
        -ReportsDir   (Join-Path $root 'reports') `
        -SpecsRoot    (Join-Path $root 'specs') `
        -EnforceFromPhase 'P2'

    $backfillFail = $result.Output.Contains('retroactively backfilled')
    Assert-Test 'Retroactive backfill detected' $backfillFail
    Assert-Test 'Exit code != 0'                ($result.ExitCode -ne 0)
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# ---- Summary -----------------------------------------------------------
Write-Host ''
Write-Host '=== Test Summary ===' -ForegroundColor Cyan
Write-Host "Passed: $passCount"
Write-Host "Failed: $failCount"
Write-Host ''
if ($failCount -gt 0) { exit 1 } else { exit 0 }
