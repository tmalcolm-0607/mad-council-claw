<#
.SYNOPSIS
    Run agent evaluations across historical milestone commits.

.DESCRIPTION
    Orchestrates eval sweeps across multiple git commits. Each commit gets a worktree,
    then Run-LocalEval.ps1 is invoked with that worktree's .claude/ config.

    Optionally compare CCGHCP config vs LENS-CMS config side-by-side for each commit.

    Results are enriched with commit metadata (message, date) and saved to .mad/tests/results/.

.PARAMETER Commits
    Explicit list of commit SHAs to evaluate. Mutually exclusive with -AutoDiscover.

.PARAMETER AutoDiscover
    Auto-discover milestone commits from git log of .claude/ directory.

.PARAMETER MaxCommits
    Maximum commits when auto-discovering. Default: 10

.PARAMETER Scenario
    Comma-separated scenario names. Default: all scenarios.
    Valid values: investigate-and-implement, review-and-fix, coverage-loop

.PARAMETER CompareConfigs
    Also run each commit with LENS-CMS config for comparison.

.PARAMETER LensCmsRoot
    Path to LENS-CMS worktree for config comparison. Default: .mad/scratch/lens-cms-eval

.PARAMETER MaxTurns
    Maximum Claude CLI turns per scenario. Default: 25 (lower than Run-LocalEval default
    of 40 to reduce cost for multi-commit sweeps).

.PARAMETER TimeoutMinutes
    Per-scenario timeout in minutes. Default: 10

.PARAMETER SkipCleanup
    Keep worktrees for debugging.

.EXAMPLE
    .\Run-EvalHistory.ps1 -AutoDiscover -MaxCommits 5
    .\Run-EvalHistory.ps1 -Commits "abc1234","def5678" -Scenario investigate-and-implement
    .\Run-EvalHistory.ps1 -AutoDiscover -CompareConfigs -LensCmsRoot C:\repos\lens-cms

.NOTES
    Requires: Claude Code CLI, .NET SDK 8.0+, Run-LocalEval.ps1
    Creates detached worktrees at .mad/scratch/eval-history/{short-sha}
#>

[CmdletBinding()]
param(
    [string[]]$Commits,
    [switch]$AutoDiscover,
    [int]$MaxCommits = 10,
    [string]$Scenario,
    [switch]$CompareConfigs,
    [string]$LensCmsRoot,
    [int]$MaxTurns = 25,
    [int]$TimeoutMinutes = 10,
    [switch]$SkipCleanup
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    $colors = @{ Info = "Cyan"; Success = "Green"; Warning = "Yellow"; Error = "Red" }
    $prefix = @{ Info = "[*]"; Success = "[+]"; Warning = "[!]"; Error = "[-]" }
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Get-UtcTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Format-Duration {
    param([int]$Seconds)
    $m = [Math]::Floor($Seconds / 60)
    $s = $Seconds % 60
    return "${m}m ${s}s"
}

# ---------------------------------------------------------------------------
# Phase 1: Resolve parameters and discover milestones
# ---------------------------------------------------------------------------

$ScriptRoot = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..\.." )).Path

# Validate input
if (-not $Commits -and -not $AutoDiscover) {
    Write-Status "Must specify either -Commits or -AutoDiscover" -Type Error
    exit 1
}

if ($Commits -and $AutoDiscover) {
    Write-Status "Cannot specify both -Commits and -AutoDiscover" -Type Error
    exit 1
}

# Determine output directory
$OutputDir = Join-Path $RepoRoot ".mad\tests\results"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Default LENS-CMS root
if (-not $LensCmsRoot) {
    $LensCmsRoot = Join-Path $RepoRoot ".mad\scratch\lens-cms-eval"
}

# Validate LENS-CMS root if comparison requested
if ($CompareConfigs -and -not (Test-Path $LensCmsRoot)) {
    Write-Status "LENS-CMS root not found: $LensCmsRoot" -Type Warning
    Write-Status "Disabling config comparison" -Type Warning
    $CompareConfigs = $false
}

# Discover or parse commits
$MilestoneCommits = [System.Collections.ArrayList]::new()

if ($AutoDiscover) {
    Write-Status "Auto-discovering milestone commits from git log..." -Type Info
    $ErrorActionPreference = 'Continue'
    $logOutput = git -C $RepoRoot log --format="%H %aI %s" -- .claude/ 2>$null
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or -not $logOutput) {
        Write-Status "Failed to read git log for .claude/ directory" -Type Error
        exit 1
    }

    $lines = $logOutput -split "`n" | Where-Object { $_.Trim() } | Select-Object -First $MaxCommits
    foreach ($line in $lines) {
        if ($line -match '^([a-f0-9]{40})\s+(\S+)\s+(.+)$') {
            [void]$MilestoneCommits.Add([PSCustomObject]@{
                sha     = $Matches[1]
                date    = $Matches[2]
                message = $Matches[3].Trim()
            })
        }
    }

    # Sort oldest-first for chronological sweep
    [array]::Reverse($MilestoneCommits)
    Write-Status "Discovered $($MilestoneCommits.Count) commits" -Type Success
} else {
    Write-Status "Parsing explicit commit list..." -Type Info
    foreach ($commitSha in $Commits) {
        $ErrorActionPreference = 'Continue'
        $logLine = git -C $RepoRoot log --format="%H %aI %s" -1 $commitSha 2>$null
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0 -or -not $logLine) {
            Write-Status "Failed to resolve commit: $commitSha" -Type Warning
            continue
        }

        if ($logLine -match '^([a-f0-9]{40})\s+(\S+)\s+(.+)$') {
            [void]$MilestoneCommits.Add([PSCustomObject]@{
                sha     = $Matches[1]
                date    = $Matches[2]
                message = $Matches[3].Trim()
            })
        }
    }
    Write-Status "Resolved $($MilestoneCommits.Count) commits" -Type Success
}

if ($MilestoneCommits.Count -eq 0) {
    Write-Status "No commits to process" -Type Error
    exit 1
}

# ---------------------------------------------------------------------------
# Phase 2: Display banner
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Historical Eval Sweep" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$configModes = $(if ($CompareConfigs) { "CCGHCP + LENS-CMS" } else { "CCGHCP only" })
$scenarioCount = $(if ($Scenario) { ($Scenario -split ',').Count } else { 3 })
$configMultiplier = $(if ($CompareConfigs) { 2 } else { 1 })
$totalRuns = $MilestoneCommits.Count * $scenarioCount * $configMultiplier

Write-Status "Commits:       $($MilestoneCommits.Count)" -Type Info
Write-Status "Config modes:  $configModes" -Type Info
$scenarioLabel = $(if ($Scenario) { $Scenario } else { 'all' })
Write-Status "Scenarios:     $scenarioLabel" -Type Info
Write-Status "Estimated runs: $totalRuns" -Type Info
Write-Status "Max turns:     $MaxTurns | Timeout: ${TimeoutMinutes}m" -Type Info
Write-Status "Output:        $OutputDir" -Type Info
Write-Host ""

# ---------------------------------------------------------------------------
# Phase 3: For each commit, create worktree and run eval
# ---------------------------------------------------------------------------

$results = [System.Collections.ArrayList]::new()
$worktreePaths = [System.Collections.ArrayList]::new()
$runLocalEvalScript = Join-Path $ScriptRoot "Run-LocalEval.ps1"

if (-not (Test-Path $runLocalEvalScript)) {
    Write-Status "Run-LocalEval.ps1 not found at $runLocalEvalScript" -Type Error
    exit 1
}

foreach ($commit in $MilestoneCommits) {
    $shortSha = $commit.sha.Substring(0, 7)
    $worktreePath = Join-Path $RepoRoot ".mad\scratch\eval-history\$shortSha"

    Write-Host ""
    Write-Host "========================================" -ForegroundColor White
    Write-Status "Processing commit $shortSha" -Type Info
    Write-Status "  Date:    $($commit.date)" -Type Info
    Write-Status "  Message: $($commit.message)" -Type Info
    Write-Host "========================================" -ForegroundColor White
    Write-Host ""

    # Remove existing worktree if present
    if (Test-Path $worktreePath) {
        Write-Status "  Removing existing worktree..." -Type Info
        $ErrorActionPreference = 'Continue'
        git -C $RepoRoot worktree remove $worktreePath --force 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
    }

    # Create worktree (detached HEAD at that commit)
    Write-Status "  Creating worktree at $worktreePath..." -Type Info
    $ErrorActionPreference = 'Continue'
    git -C $RepoRoot worktree add --detach $worktreePath $commit.sha 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        Write-Status "  Failed to create worktree for $shortSha -- skipping" -Type Warning
        continue
    }
    [void]$worktreePaths.Add($worktreePath)

    # Run CCGHCP config eval
    $runId = "eval-hist-$shortSha-ccghcp"
    Write-Status "  Running eval with CCGHCP config..." -Type Info

    $evalArgs = @(
        "-NoProfile", "-File", $runLocalEvalScript,
        "-ProjectRoot", $worktreePath,
        "-CommitSha", $commit.sha,
        "-EvalRunId", $runId,
        "-MaxTurns", $MaxTurns,
        "-TimeoutMinutes", $TimeoutMinutes,
        "-OutputDir", $OutputDir
    )
    if ($Scenario) { $evalArgs += @("-Scenario", $Scenario) }
    if ($SkipCleanup) { $evalArgs += "-SkipCleanup" }

    & powershell.exe @evalArgs
    $evalExitCode = $LASTEXITCODE

    # Enrich result JSON with commit metadata
    $resultFile = Join-Path $OutputDir "$runId.json"
    if (Test-Path $resultFile) {
        try {
            $json = Get-Content $resultFile -Raw | ConvertFrom-Json
            $json | Add-Member -NotePropertyName "git_commit_message" -NotePropertyValue $commit.message -Force
            $json | Add-Member -NotePropertyName "git_commit_date" -NotePropertyValue $commit.date -Force
            $json | ConvertTo-Json -Depth 10 | Set-Content $resultFile -Encoding UTF8
            [void]$results.Add($json)
            Write-Status "  CCGHCP result saved: $resultFile" -Type Success
        } catch {
            Write-Status "  Failed to enrich result JSON: $($_.Exception.Message)" -Type Warning
        }
    } else {
        Write-Status "  No result file found for $runId" -Type Warning
    }

    # Run LENS-CMS config eval (if -CompareConfigs)
    if ($CompareConfigs -and (Test-Path $LensCmsRoot)) {
        $lensRunId = "eval-hist-$shortSha-lenscms"
        Write-Status "  Running eval with LENS-CMS config..." -Type Info

        $lensArgs = @(
            "-NoProfile", "-File", $runLocalEvalScript,
            "-ProjectRoot", $LensCmsRoot,
            "-CommitSha", $commit.sha,
            "-EvalRunId", $lensRunId,
            "-MaxTurns", $MaxTurns,
            "-TimeoutMinutes", $TimeoutMinutes,
            "-OutputDir", $OutputDir
        )
        if ($Scenario) { $lensArgs += @("-Scenario", $Scenario) }
        if ($SkipCleanup) { $lensArgs += "-SkipCleanup" }

        & powershell.exe @lensArgs

        $lensResultFile = Join-Path $OutputDir "$lensRunId.json"
        if (Test-Path $lensResultFile) {
            try {
                $lensJson = Get-Content $lensResultFile -Raw | ConvertFrom-Json
                $lensJson | Add-Member -NotePropertyName "git_commit_message" -NotePropertyValue $commit.message -Force
                $lensJson | Add-Member -NotePropertyName "git_commit_date" -NotePropertyValue $commit.date -Force
                $lensJson | ConvertTo-Json -Depth 10 | Set-Content $lensResultFile -Encoding UTF8
                [void]$results.Add($lensJson)
                Write-Status "  LENS-CMS result saved: $lensResultFile" -Type Success
            } catch {
                Write-Status "  Failed to enrich LENS-CMS result JSON: $($_.Exception.Message)" -Type Warning
            }
        } else {
            Write-Status "  No result file found for $lensRunId" -Type Warning
        }
    }
}

# ---------------------------------------------------------------------------
# Phase 4: Summary table
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($results.Count -eq 0) {
    Write-Status "No results to display" -Type Warning
} else {
    # Table header
    $headerFmt = "{0,-10} {1,-10} {2,-10} {3,-10} {4,-10} {5,-10}"
    Write-Host ($headerFmt -f "COMMIT", "CONFIG", "PASS RATE", "TOKENS", "COST", "DURATION") -ForegroundColor White
    Write-Host ("-" * 72) -ForegroundColor DarkGray

    foreach ($r in $results) {
        $commitShort = $(if ($r.git_commit_sha) { $r.git_commit_sha.Substring(0, 7) } else { "unknown" })
        $configName = $(if ($r.run_id -match 'lenscms') { "LENS-CMS" } else { "CCGHCP" })
        $passRate = $(if ($r.summary.assertion_pass_rate) {
            "$([Math]::Round($r.summary.assertion_pass_rate * 100, 1))%"
        } else { "N/A" })
        $tokens = $(if ($r.summary.total_tokens) {
            "$([Math]::Round($r.summary.total_tokens / 1000.0, 1))K"
        } else { "0" })
        $cost = $(if ($r.summary.total_cost_usd) {
            "`$$([Math]::Round($r.summary.total_cost_usd, 2))"
        } else { "`$0.00" })
        $duration = $(if ($r.summary.total_duration_seconds) {
            Format-Duration -Seconds $r.summary.total_duration_seconds
        } else { "0s" })

        $passRateVal = $(if ($r.summary.assertion_pass_rate) { $r.summary.assertion_pass_rate } else { 0 })
        $color = $(if ($passRateVal -ge 0.8) { "Green" } elseif ($passRateVal -ge 0.5) { "Yellow" } else { "Red" })

        Write-Host ($headerFmt -f $commitShort, $configName, $passRate, $tokens, $cost, $duration) -ForegroundColor $color
    }

    Write-Host ("-" * 72) -ForegroundColor DarkGray

    # Aggregate stats
    $totalTokens = ($results | ForEach-Object { $_.summary.total_tokens } | Measure-Object -Sum).Sum
    $totalCost = ($results | ForEach-Object { $_.summary.total_cost_usd } | Measure-Object -Sum).Sum
    $totalDuration = ($results | ForEach-Object { $_.summary.total_duration_seconds } | Measure-Object -Sum).Sum
    $avgPassRate = $(if ($results.Count -gt 0) {
        ($results | ForEach-Object { $_.summary.assertion_pass_rate } | Measure-Object -Average).Average
    } else { 0 })

    $tokensStr = "$([Math]::Round($totalTokens / 1000.0, 1))K"
    $costStr = "`$$([Math]::Round($totalCost, 2))"
    $durationStr = Format-Duration -Seconds $totalDuration
    $avgPassRateStr = "$([Math]::Round($avgPassRate * 100, 1))%"

    Write-Host ($headerFmt -f "TOTAL", "$($results.Count) runs", $avgPassRateStr, $tokensStr, $costStr, $durationStr) -ForegroundColor White
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Phase 5: Cleanup worktrees
# ---------------------------------------------------------------------------

if (-not $SkipCleanup) {
    Write-Status "Cleaning up worktrees..." -Type Info
    foreach ($wp in $worktreePaths) {
        if (Test-Path $wp) {
            $ErrorActionPreference = 'Continue'
            git -C $RepoRoot worktree remove $wp --force 2>&1 | Out-Null
            $ErrorActionPreference = 'Stop'
        }
    }

    # Clean parent directory if empty
    $historyDir = Join-Path $RepoRoot ".mad\scratch\eval-history"
    if ((Test-Path $historyDir) -and @(Get-ChildItem $historyDir -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $historyDir -Force -ErrorAction SilentlyContinue
    }
    Write-Status "Cleanup complete" -Type Success
} else {
    Write-Status "Skipping cleanup (-SkipCleanup). Worktrees:" -Type Info
    foreach ($wp in $worktreePaths) {
        Write-Host "    $wp" -ForegroundColor DarkGray
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------

# Exit 0 if average pass rate >= 0.5, else exit 1
if ($results.Count -gt 0) {
    $avgPassRate = ($results | ForEach-Object { $_.summary.assertion_pass_rate } | Measure-Object -Average).Average
    if ($avgPassRate -ge 0.5) {
        Write-Host "  HISTORICAL SWEEP PASSED (avg pass rate: $([Math]::Round($avgPassRate * 100, 1))%)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  HISTORICAL SWEEP FAILED (avg pass rate: $([Math]::Round($avgPassRate * 100, 1))%)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  NO RESULTS - CHECK LOGS" -ForegroundColor Red
    exit 1
}
