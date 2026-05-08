<#
.SYNOPSIS
    Run all .NET quality gates (build, test, format, coverage) with compact output.
    Replaces 3-4 separate dotnet build/test/format commands with a single summary.

.PARAMETER SolutionPath
    Path to .sln file (auto-discovers LENS-CMS if not specified)

.PARAMETER SkipBuild
    Skip the build gate

.PARAMETER SkipTest
    Skip the test gate

.PARAMETER SkipFormat
    Skip the format gate

.PARAMETER SkipCoverage
    Skip the coverage gate

.PARAMETER CoverageThreshold
    Minimum overall line coverage percentage (default: 90)

.PARAMETER SkipDiffCoverage
    Skip the diff coverage gate (Gate 3b)

.EXAMPLE
    .\Run-DotnetGates.ps1
    .\Run-DotnetGates.ps1 -SolutionPath C:\source\CCGHCP\src\LENS-CMS\src\CMS.sln
    .\Run-DotnetGates.ps1 -SkipCoverage
    .\Run-DotnetGates.ps1 -SkipDiffCoverage
    .\Run-DotnetGates.ps1 -CoverageThreshold 80
#>
[CmdletBinding()]
param(
    [string]$SolutionPath,

    [switch]$SkipBuild,

    [switch]$SkipTest,

    [switch]$SkipFormat,

    [switch]$SkipCoverage,

    [int]$CoverageThreshold = 90, # Overall line coverage (diff coverage is 100%, enforced by ADO + Measure-DiffCoverage.ps1)

    [switch]$SkipDiffCoverage
)

$ErrorActionPreference = "Stop"

# --- Auto-discover solution ---
if (-not $SolutionPath) {
    $candidates = @(
        "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\CMS.sln",
        "C:\source\CCGHCP\src\LENS-CMS\src\CMS.sln",
        "C:\source\LENS-CMS\src\CMS.sln"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $SolutionPath = $c
            break
        }
    }
    if (-not $SolutionPath) {
        # Fall back to detecting a .sln / .csproj at the current working directory
        # (kit-aware behavior added 2026-05-02 per iter15-hook-misfire fix).
        # Skill kits + spec-only repos legitimately have no .sln; emit a clear
        # skip message and exit 0 so the PostToolUse gate runner does not flag
        # a false-positive failure on every doc-only implementer dispatch.
        $cwd = (Get-Location).Path
        $localSln = @(Get-ChildItem -Path $cwd -Filter '*.sln' -File -ErrorAction SilentlyContinue)
        $localCsproj = @(Get-ChildItem -Path $cwd -Filter '*.csproj' -File -ErrorAction SilentlyContinue)
        if ($localSln.Count -gt 0) {
            $SolutionPath = $localSln[0].FullName
        } elseif ($localCsproj.Count -gt 0) {
            # Single .csproj at root -- treat as build target (no .sln required)
            $SolutionPath = $localCsproj[0].FullName
        } else {
            Write-Host "[Run-DotnetGates] Skipping: no .sln or .csproj found at repo root (kit / spec-only repo)." -ForegroundColor DarkYellow
            exit 0
        }
    }
}

$SolutionDir = Split-Path $SolutionPath -Parent
$failedGates = 0
$gateResults = @()

Write-Host ""
Write-Host "=== .NET Quality Gates ===" -ForegroundColor Cyan
Write-Host "Solution: $SolutionPath"
Write-Host "Coverage Threshold: $CoverageThreshold%"
Write-Host ""

# --- Gate 1: Build ---
if (-not $SkipBuild) {
    Write-Host "--- Gate 1: Build ---" -ForegroundColor Yellow
    $ErrorActionPreference = "Continue"
    $buildOutput = dotnet build $SolutionPath --nologo -v q 2>&1 | Out-String
    $ErrorActionPreference = "Stop"

    $warnings = ([regex]::Matches($buildOutput, "warning [A-Z]+\d+")).Count
    $errors = ([regex]::Matches($buildOutput, "error [A-Z]+\d+")).Count

    if ($LASTEXITCODE -eq 0 -and $errors -eq 0) {
        Write-Host "  PASS: Build succeeded ($warnings warnings)" -ForegroundColor Green
        $gateResults += "Build: PASS ($warnings warnings)"
    } else {
        Write-Host "  FAIL: Build failed ($errors errors, $warnings warnings)" -ForegroundColor Red
        $gateResults += "Build: FAIL ($errors errors)"
        $failedGates++
        # Show last 20 lines for context
        $lines = $buildOutput -split "`n"
        $tail = $lines | Select-Object -Last 20
        $tail | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    }
} else {
    Write-Host "--- Gate 1: Build (SKIPPED) ---" -ForegroundColor DarkYellow
    $gateResults += "Build: SKIPPED"
}

# --- Gate 2: Test ---
if (-not $SkipTest) {
    Write-Host ""
    Write-Host "--- Gate 2: Test ---" -ForegroundColor Yellow

    $testArgs = @("test", $SolutionPath, "--nologo", "--no-build", "-v", "q")
    if (-not $SkipCoverage) {
        $testArgs += @("--collect:`"XPlat Code Coverage`"")
    }

    $ErrorActionPreference = "Continue"
    $testOutput = & dotnet @testArgs 2>&1 | Out-String
    $ErrorActionPreference = "Stop"

    # Extract test counts
    $passMatch = [regex]::Match($testOutput, "Passed!\s+-\s+Failed:\s+(\d+),\s+Passed:\s+(\d+),\s+Skipped:\s+(\d+),\s+Total:\s+(\d+)")
    $failMatch = [regex]::Match($testOutput, "Failed!\s+-\s+Failed:\s+(\d+),\s+Passed:\s+(\d+),\s+Skipped:\s+(\d+),\s+Total:\s+(\d+)")

    if ($passMatch.Success) {
        $failed = [int]$passMatch.Groups[1].Value
        $passed = [int]$passMatch.Groups[2].Value
        $skipped = [int]$passMatch.Groups[3].Value
        $total = [int]$passMatch.Groups[4].Value
        Write-Host "  PASS: $passed passed, $failed failed, $skipped skipped ($total total)" -ForegroundColor Green
        $gateResults += "Test: PASS ($passed passed, $failed failed)"
    } elseif ($failMatch.Success) {
        $failed = [int]$failMatch.Groups[1].Value
        $passed = [int]$failMatch.Groups[2].Value
        $skipped = [int]$failMatch.Groups[3].Value
        $total = [int]$failMatch.Groups[4].Value
        Write-Host "  FAIL: $passed passed, $failed failed, $skipped skipped ($total total)" -ForegroundColor Red
        $gateResults += "Test: FAIL ($passed passed, $failed failed)"
        $failedGates++
        # Show failing test names
        $failLines = $testOutput -split "`n" | Where-Object { $_ -match "Failed\s" } | Select-Object -First 10
        $failLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    } elseif ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: Tests could not run" -ForegroundColor Red
        $gateResults += "Test: FAIL (could not run)"
        $failedGates++
        $lines = $testOutput -split "`n" | Select-Object -Last 10
        $lines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    } else {
        # Fallback: look for individual project results
        $allPassed = [regex]::Matches($testOutput, "Passed:\s+(\d+)")
        $allFailed = [regex]::Matches($testOutput, "Failed:\s+(\d+)")
        $totalPassed = ($allPassed | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Sum).Sum
        $totalFailed = ($allFailed | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Sum).Sum

        if ($totalFailed -gt 0) {
            Write-Host "  FAIL: $totalPassed passed, $totalFailed failed" -ForegroundColor Red
            $gateResults += "Test: FAIL ($totalPassed passed, $totalFailed failed)"
            $failedGates++
        } else {
            Write-Host "  PASS: $totalPassed passed" -ForegroundColor Green
            $gateResults += "Test: PASS ($totalPassed passed)"
        }
    }
} else {
    Write-Host ""
    Write-Host "--- Gate 2: Test (SKIPPED) ---" -ForegroundColor DarkYellow
    $gateResults += "Test: SKIPPED"
}

# --- Gate 3: Coverage ---
if (-not $SkipCoverage -and -not $SkipTest) {
    Write-Host ""
    Write-Host "--- Gate 3: Coverage ---" -ForegroundColor Yellow

    # Find coverage files
    $coverageFiles = Get-ChildItem -Path $SolutionDir -Recurse -Filter "coverage.cobertura.xml" -ErrorAction SilentlyContinue
    if ($coverageFiles.Count -eq 0) {
        Write-Host "  WARN: No coverage files found" -ForegroundColor DarkYellow
        $gateResults += "Coverage: WARN (no data)"
    } else {
        # Use reportgenerator if available, otherwise parse XML
        $latestCoverage = $coverageFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        [xml]$coverageXml = Get-Content $latestCoverage.FullName
        $lineRate = [double]$coverageXml.coverage.'line-rate' * 100
        $branchRate = [double]$coverageXml.coverage.'branch-rate' * 100

        $lineRate = [math]::Round($lineRate, 1)
        $branchRate = [math]::Round($branchRate, 1)

        if ($lineRate -ge $CoverageThreshold) {
            Write-Host "  PASS: Line $lineRate%, Branch $branchRate% (threshold: $CoverageThreshold%)" -ForegroundColor Green
            $gateResults += "Coverage: PASS (line $lineRate%, branch $branchRate%)"
        } else {
            Write-Host "  FAIL: Line $lineRate% < $CoverageThreshold% threshold (branch $branchRate%)" -ForegroundColor Red
            $gateResults += "Coverage: FAIL (line $lineRate% < $CoverageThreshold%)"
            $failedGates++
        }
    }
} elseif ($SkipCoverage) {
    Write-Host ""
    Write-Host "--- Gate 3: Coverage (SKIPPED) ---" -ForegroundColor DarkYellow
    $gateResults += "Coverage: SKIPPED"
}

# --- Gate 3b: Diff Coverage ---
if (-not $SkipDiffCoverage -and -not $SkipCoverage -and -not $SkipTest) {
    Write-Host ""
    Write-Host "--- Gate 3b: Diff Coverage ---" -ForegroundColor Yellow
    $diffScript = Join-Path $PSScriptRoot "Measure-DiffCoverage.ps1"
    if (Test-Path $diffScript) {
        $ErrorActionPreference = "Continue"
        $diffOutput = & $diffScript -SolutionPath $SolutionPath -Json 2>&1 | Out-String
        $ErrorActionPreference = "Stop"
        try {
            $diffData = $diffOutput | ConvertFrom-Json
            if ($diffData.pass) {
                Write-Host "  PASS: Diff coverage $($diffData.diffCoveragePercent)% ($($diffData.coveredLines)/$($diffData.totalChangedLines) lines)" -ForegroundColor Green
                $gateResults += "Diff Coverage: PASS ($($diffData.diffCoveragePercent)%)"
            } else {
                Write-Host "  FAIL: Diff coverage $($diffData.diffCoveragePercent)% < $($diffData.threshold)% ($($diffData.uncoveredLines) uncovered)" -ForegroundColor Red
                $gateResults += "Diff Coverage: FAIL ($($diffData.diffCoveragePercent)% < $($diffData.threshold)%)"
                $failedGates++
                # Show uncovered files
                if ($diffData.uncoveredDetails) {
                    $diffData.uncoveredDetails | Select-Object -First 10 | ForEach-Object {
                        Write-Host "    $($_.file):$($_.line)" -ForegroundColor DarkYellow
                    }
                }
            }
        } catch {
            Write-Host "  WARN: Could not parse diff coverage output" -ForegroundColor DarkYellow
            $gateResults += "Diff Coverage: WARN (parse error)"
        }
    } else {
        Write-Host "  WARN: Measure-DiffCoverage.ps1 not found" -ForegroundColor DarkYellow
        $gateResults += "Diff Coverage: WARN (script missing)"
    }
} elseif ($SkipDiffCoverage) {
    Write-Host ""
    Write-Host "--- Gate 3b: Diff Coverage (SKIPPED) ---" -ForegroundColor DarkYellow
    $gateResults += "Diff Coverage: SKIPPED"
}

# --- Gate 4: Format ---
if (-not $SkipFormat) {
    Write-Host ""
    Write-Host "--- Gate 4: Format ---" -ForegroundColor Yellow
    $ErrorActionPreference = "Continue"
    $formatOutput = dotnet format $SolutionPath --verify-no-changes --no-restore 2>&1 | Out-String
    $ErrorActionPreference = "Stop"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  PASS: No formatting violations" -ForegroundColor Green
        $gateResults += "Format: PASS"
    } else {
        $violations = ([regex]::Matches($formatOutput, "error\s+\w+:")).Count
        if ($violations -eq 0) { $violations = 1 }  # at least 1 if exit code non-zero
        Write-Host "  FAIL: $violations formatting violations" -ForegroundColor Red
        $gateResults += "Format: FAIL ($violations violations)"
        $failedGates++
        # Show first few violations
        $formatOutput -split "`n" | Where-Object { $_ -match "error\s+\w+:" } | Select-Object -First 5 | ForEach-Object {
            Write-Host "    $($_.Trim())" -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host ""
    Write-Host "--- Gate 4: Format (SKIPPED) ---" -ForegroundColor DarkYellow
    $gateResults += "Format: SKIPPED"
}

# --- Summary ---
Write-Host ""
Write-Host "=== Gate Summary ===" -ForegroundColor Cyan
$gateResults | ForEach-Object {
    $color = if ($_ -match "PASS") { "Green" } elseif ($_ -match "FAIL") { "Red" } elseif ($_ -match "WARN") { "DarkYellow" } else { "DarkYellow" }
    Write-Host "  $_" -ForegroundColor $color
}
Write-Host ""

if ($failedGates -eq 0) {
    Write-Host "=== ALL GATES PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== $failedGates GATE(S) FAILED ===" -ForegroundColor Red
}

exit $failedGates
