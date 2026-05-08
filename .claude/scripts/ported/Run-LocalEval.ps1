<#
.SYNOPSIS
    Run agent evaluations locally using the Claude Code CLI.

.DESCRIPTION
    Executes agent evaluation scenarios (investigate-and-implement, review-and-fix,
    coverage-loop) in isolated temp directories using the user's existing Claude Code
    CLI authentication (OAuth - no API key needed).

    Each scenario sets up a small .NET project with a deliberate flaw, invokes
    Claude CLI to fix it, then runs build/test/scenario-specific assertions.

    Output conforms to the eval-result-schema.json format.

.PARAMETER Scenario
    Comma-separated scenario names, or a meta-scenario name.
    Meta-scenarios: "smoke" (7 original scenarios), "enterprise" (discriminating scenarios),
    "all" (everything). Individual names are also accepted.
    Default: enterprise (runs only the discriminating enterprise scenarios).

.PARAMETER CommitSha
    Git commit SHA to record. Default: current HEAD.

.PARAMETER OutputDir
    Directory for result JSON files. Default: .mad/tests/results

.PARAMETER EvalRunId
    Unique run identifier. Default: auto-generated as eval-{yyyyMMddHHmmss}-{shortsha}

.PARAMETER MaxTurns
    Maximum Claude CLI turns per scenario. Default: 40

.PARAMETER TimeoutMinutes
    Per-scenario timeout in minutes. Default: 10

.PARAMETER SkipCleanup
    Keep temp directories for debugging.

.PARAMETER Upload
    Also upload results to blob storage via Store-EvalResults.ps1.

.PARAMETER Parallel
    Run scenarios concurrently using background jobs. Each scenario re-invokes
    this script as a separate process. Results are collected and merged.

.PARAMETER MaxParallel
    Maximum number of concurrent scenarios when -Parallel is used. Default: 4

.PARAMETER DryRun
    Show resolved configuration and execution plan without running any scenarios.

.EXAMPLE
    .\Run-LocalEval.ps1
    .\Run-LocalEval.ps1 -Scenario investigate-and-implement -SkipCleanup
    .\Run-LocalEval.ps1 -Scenario "investigate-and-implement,coverage-loop" -MaxTurns 20
    .\Run-LocalEval.ps1 -Upload
    .\Run-LocalEval.ps1 -Scenario all -Parallel -MaxParallel 4
    .\Run-LocalEval.ps1 -Scenario all -DryRun
    .\Run-LocalEval.ps1 -Scenario all -Parallel -DryRun
    .\Run-LocalEval.ps1 -Scenario all -Parallel -IncludeBaseline

.NOTES
    Requires: Claude Code CLI (claude) on PATH, .NET SDK 8.0+
    Auth: Uses existing OAuth session - no ANTHROPIC_API_KEY needed.
#>

[CmdletBinding()]
param(
    [string]$Scenario,
    [string]$CommitSha,
    [string]$OutputDir,
    [string]$EvalRunId,
    [string]$ProjectRoot,          # Project root dir. Temp dirs created inside so Claude finds .claude/ config
    [int]$MaxTurns = 50,
    [int]$TimeoutMinutes = 10,
    [int]$Timeout = 600,           # Wall-clock timeout in seconds per scenario (overrides TimeoutMinutes if explicitly set)
    [decimal]$CostLimit = 3.0,     # Max cost in USD per scenario; circuit breaker fires if exceeded
    [int]$MaxResults = 50,
    [switch]$IncludeBaseline,      # Also run a no-config baseline for comparison (or reuse today's)
    [switch]$Judge,
    [switch]$SkipCleanup,
    [switch]$Upload,
    [switch]$DebugMode,            # Enable debug diagnostic reports
    [switch]$Headless,             # Run eval modules in headless mode (sets EVAL_HEADLESS=1 env var)
    [switch]$Parallel,             # Run scenarios in parallel using background jobs
    [int]$MaxParallel = 4,         # Max concurrent scenarios when -Parallel is used
    [switch]$DryRun,               # Show what would run without executing
    [switch]$NoBundleDashboard    # Skip dashboard bundling (used by parallel sub-runs)
)

# ---------------------------------------------------------------------------
# Auto-detect ProjectRoot from script location if not specified
# ---------------------------------------------------------------------------
if (-not $ProjectRoot -and -not $PSBoundParameters.ContainsKey('ProjectRoot')) {
    # Walk up from script dir (.claude/scripts/) to find the repo root containing .claude/
    # Skip auto-detection if -ProjectRoot was explicitly passed (even as empty string),
    # which baseline sub-invocations do to ensure no config contamination.
    $candidate = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    if (Test-Path (Join-Path $candidate ".claude")) {
        $ProjectRoot = $candidate
        Write-Host "[*] Auto-detected ProjectRoot: $ProjectRoot" -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# Import shared modules (additive - does not replace inline functions)
# ---------------------------------------------------------------------------
$SharedRoot = Join-Path $PSScriptRoot "..\tests\shared"
if (Test-Path (Join-Path $SharedRoot "EvalShared.psm1")) {
    Import-Module (Join-Path $SharedRoot "EvalShared.psm1") -Force -DisableNameChecking
}
# Import scoring modules
$ScoringDir = Join-Path $SharedRoot "scoring"
if (Test-Path $ScoringDir) {
    Get-ChildItem -Path $ScoringDir -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
}
# Import analysis modules
$AnalysisDir = Join-Path $SharedRoot "analysis"
if (Test-Path $AnalysisDir) {
    Get-ChildItem -Path $AnalysisDir -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
}
# Import scaffold modules
$ScaffoldDir = Join-Path $SharedRoot "scaffolds"
if (Test-Path $ScaffoldDir) {
    Get-ChildItem -Path $ScaffoldDir -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
}
# Import per-eval modules
$EvalModulesDir = Join-Path $SharedRoot "evals"
if (Test-Path $EvalModulesDir) {
    Get-ChildItem -Path $EvalModulesDir -Filter "Eval*.psm1" -ErrorAction SilentlyContinue | ForEach-Object {
        Import-Module $_.FullName -Force -DisableNameChecking
    }
}

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

function Get-EpochSeconds {
    return [int][double]::Parse(
        (Get-Date -Date (Get-Date).ToUniversalTime() -UFormat '%s')
    )
}

function Get-CostRegression {
    param(
        [Parameter(Mandatory)][hashtable]$CurrentResult,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$PreviousResults
    )
    $regression = $false
    # Take last 10 previous runs (array is assumed newest-last; take tail)
    $window = $PreviousResults
    if ($window.Count -gt 10) { $window = $window[($window.Count - 10)..($window.Count - 1)] }

    if ($window.Count -eq 0) { return @{ cost_regression = $false } }

    # Check total cost
    $prevTotals = @($window | ForEach-Object {
        $tc = $_.summary.total_cost_usd
        if ($tc -and [double]$tc -gt 0) { [double]$tc }
    })
    if ($prevTotals.Count -gt 0) {
        $avgTotal = ($prevTotals | Measure-Object -Average).Average
        $curTotal = [double]$CurrentResult.summary.total_cost_usd
        if ($avgTotal -gt 0 -and $curTotal -gt (2 * $avgTotal)) { $regression = $true }
    }

    # Check per-scenario cost
    foreach ($scenario in $CurrentResult.scenarios) {
        $sName = $scenario.name
        $sCost = [double]$scenario.cost_usd
        $prevCosts = @($window | ForEach-Object {
            $match = $_.scenarios | Where-Object { $_.name -eq $sName }
            if ($match -and $match.cost_usd -and [double]$match.cost_usd -gt 0) { [double]$match.cost_usd }
        })
        if ($prevCosts.Count -gt 0) {
            $avgCost = ($prevCosts | Measure-Object -Average).Average
            if ($avgCost -gt 0 -and $sCost -gt (2 * $avgCost)) { $regression = $true }
        }
    }

    return @{ cost_regression = $regression }
}

function Build-ScenarioMetrics {
    param(
        [int]$AssertionsPassed = 0,
        [int]$AssertionsTotal = 0,
        $CostUsd = [double]0,
        $NumTurns = $null,
        [int]$DurationSeconds = 0,
        [bool]$BuildPassed = $false,
        [bool]$TestsPassed = $false
    )

    $passRate = if ($AssertionsTotal -gt 0) {
        [Math]::Round($AssertionsPassed / $AssertionsTotal, 4)
    } else { 0.0 }

    return [ordered]@{
        assertion_pass_rate  = $passRate
        discrimination_delta = $null
        total_cost_usd       = $CostUsd
        num_turns            = $NumTurns
        duration_seconds     = $DurationSeconds
        build_gate           = $BuildPassed
        test_gate            = $TestsPassed
    }
}

function Format-MetricsComparison {
    param(
        [Parameter(Mandatory)][hashtable]$BaselineMetrics,
        [Parameter(Mandatory)][hashtable]$TreatmentMetrics
    )

    $metricDefs = @(
        @{ Name = "Assertion Pass Rate"; Key = "assertion_pass_rate"; IsNumeric = $true }
        @{ Name = "Total Cost (USD)";    Key = "total_cost_usd";     IsNumeric = $true }
        @{ Name = "Num Turns";           Key = "num_turns";          IsNumeric = $true }
        @{ Name = "Duration (sec)";      Key = "duration_seconds";   IsNumeric = $true }
        @{ Name = "Build Gate";          Key = "build_gate";         IsNumeric = $false }
        @{ Name = "Test Gate";           Key = "test_gate";          IsNumeric = $false }
    )

    $rows = @()
    foreach ($def in $metricDefs) {
        $bVal = $BaselineMetrics[$def.Key]
        $tVal = $TreatmentMetrics[$def.Key]

        $bDisplay = if ($null -eq $bVal) { "N/A" } else { $bVal }
        $tDisplay = if ($null -eq $tVal) { "N/A" } else { $tVal }

        $delta = "N/A"
        if ($def.IsNumeric -and $null -ne $bVal -and $null -ne $tVal) {
            $delta = [Math]::Round([double]$tVal - [double]$bVal, 4)
        }

        $rows += [PSCustomObject]@{
            Metric    = $def.Name
            Baseline  = $bDisplay
            Treatment = $tDisplay
            Delta     = $delta
        }
    }

    # Discrimination delta = treatment assertion_pass_rate - baseline assertion_pass_rate
    $bPass = $BaselineMetrics["assertion_pass_rate"]
    $tPass = $TreatmentMetrics["assertion_pass_rate"]
    $discriminationDelta = if ($null -ne $bPass -and $null -ne $tPass) {
        [Math]::Round([double]$tPass - [double]$bPass, 4)
    } else { $null }

    return @{
        Rows                = $rows
        DiscriminationDelta = $discriminationDelta
    }
}

function Get-DirectoryHash {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Filter = '*'
    )
    # Compute SHA-256 hash over sorted file contents in directory
    if (-not (Test-Path $Path)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $allBytes = [System.IO.MemoryStream]::new()
    $files = Get-ChildItem -Path $Path -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue | Sort-Object FullName
    foreach ($f in $files) {
        $relPath = $f.FullName.Replace($Path, '').TrimStart('\', '/')
        $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($relPath)
        $allBytes.Write($pathBytes, 0, $pathBytes.Length)
        $contentBytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $allBytes.Write($contentBytes, 0, $contentBytes.Length)
    }
    $allBytes.Position = 0
    $hashBytes = $sha.ComputeHash($allBytes)
    $allBytes.Dispose()
    $sha.Dispose()
    return [BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
}

function Get-WorkspaceChecksum {
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )
    # Hash all .cs files in workspace to detect scaffold drift
    return Get-DirectoryHash -Path $WorkDir -Filter '*.cs'
}

function Invoke-SecretRedaction {
    param(
        [string]$Content
    )
    if (-not $Content) { return "" }

    # Patterns that match key=value or key: value style secrets
    # Each replacement preserves the key and replaces only the value with [REDACTED]
    $patterns = @(
        @{ Pattern = '(?i)(password\s*[=:]\s*).+';           Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(key\s*[=:]\s*).+';                Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(token\s*[=:]\s*).+';              Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(secret\s*[=:]\s*).+';             Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(connection\s*string\s*[=:]\s*).+'; Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(?i)(AccountKey=)[^;]+';               Replacement = '${1}[REDACTED]' }
        @{ Pattern = '(Bearer\s+)\S+';                       Replacement = '${1}[REDACTED]' }
    )

    $result = $Content
    foreach ($p in $patterns) {
        $result = [regex]::Replace($result, $p.Pattern, $p.Replacement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    }
    return $result
}

function Build-DebugReport {
    param(
        [string]$ScenarioName,
        [string]$EvalRunId,
        [string]$Status,
        [array]$AssertionResults,
        [string]$WorkDir
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    $passedCount = @($AssertionResults | Where-Object { $_.passed -eq $true }).Count
    $failedCount = @($AssertionResults | Where-Object { $_.passed -eq $false }).Count
    $totalCount = $AssertionResults.Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Debug Report: $ScenarioName")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Field | Value |")
    [void]$sb.AppendLine("|-------|-------|")
    [void]$sb.AppendLine("| Scenario | $ScenarioName |")
    [void]$sb.AppendLine("| Run ID | $EvalRunId |")
    [void]$sb.AppendLine("| Timestamp | $timestamp |")
    [void]$sb.AppendLine("| Status | $Status |")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- Total: $totalCount")
    [void]$sb.AppendLine("- Passed: $passedCount")
    [void]$sb.AppendLine("- Failed: $failedCount")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Per-Assertion Breakdown")
    [void]$sb.AppendLine("")

    foreach ($a in $AssertionResults) {
        $statusIcon = if ($a.passed) { "PASS" } else { "FAIL" }
        [void]$sb.AppendLine("### [$statusIcon] $($a.name)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("- **Status**: $statusIcon")
        if ($a.expected) { [void]$sb.AppendLine("- **Expected**: $($a.expected)") }
        if ($a.actual)   { [void]$sb.AppendLine("- **Actual**: $($a.actual)") }
        if ($a.message)  { [void]$sb.AppendLine("- **Message**: $($a.message)") }

        # File excerpt: if the assertion message or actual value references a file path, show first 20 lines
        $refPath = $null
        $candidates = @($a.message, $a.actual, $a.expected) | Where-Object { $_ }
        foreach ($candidate in $candidates) {
            # Look for file paths (absolute or relative to WorkDir)
            $pathMatch = [regex]::Match($candidate, '(?:[A-Za-z]:\\|/)[\w\\/.\-]+\.\w+')
            if ($pathMatch.Success) {
                $testPath = $pathMatch.Value
                if (Test-Path $testPath) {
                    $refPath = $testPath
                    break
                }
                # Try relative to WorkDir
                if ($WorkDir) {
                    $relPath = Join-Path $WorkDir $testPath
                    if (Test-Path $relPath) {
                        $refPath = $relPath
                        break
                    }
                }
            }
        }
        if ($refPath) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("**File excerpt** (``$refPath``):")
            [void]$sb.AppendLine('```')
            $lines = Get-Content $refPath -TotalCount 20 -ErrorAction SilentlyContinue
            if ($lines) {
                foreach ($line in $lines) { [void]$sb.AppendLine($line) }
            }
            [void]$sb.AppendLine('```')
        }
        [void]$sb.AppendLine("")
    }

    return $sb.ToString()
}

function Resolve-ScenarioList {
    param([string]$Scenario)

    $SmokeScenarios = @("investigate-and-implement", "review-and-fix", "coverage-loop",
                        "rule-adherence", "negative-constraints", "refactor-extract-service",
                        "cross-project-dependency")
    $EnterpriseScenarios = @("enterprise-cosmos-entity", "trap-antipattern-resistance",
                             "arch-drift", "mutation-detection")
    $ReplayScenarios = @("replay")
    $StressScenarios = @("context-stress")
    $ProcessScenarios = @("workflow-fidelity")
    $StaticScenarios = @("cross-repo-consistency")
    $AllScenarios = $EnterpriseScenarios + $SmokeScenarios + $ReplayScenarios + $StressScenarios + $ProcessScenarios + $StaticScenarios

    if ($Scenario -eq "smoke") {
        return $SmokeScenarios
    } elseif ($Scenario -eq "enterprise") {
        return $EnterpriseScenarios
    } elseif ($Scenario -eq "all") {
        return $AllScenarios
    } elseif ($Scenario) {
        $list = $Scenario -split ',' | ForEach-Object { $_.Trim() }
        foreach ($s in $list) {
            if ($s -notin $AllScenarios) {
                throw "Unknown scenario: $s. Valid: $($AllScenarios -join ', '), or meta-scenarios: smoke, enterprise, all"
            }
        }
        return $list
    } else {
        # Default: run only the discriminating enterprise scenarios
        return $EnterpriseScenarios
    }
}

# ---------------------------------------------------------------------------
# Phase 1: Resolve parameters
# ---------------------------------------------------------------------------

$ScriptRoot = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot "..\.." )).Path

if (-not $CommitSha) {
    $CommitSha = (git -C $RepoRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $CommitSha) {
        Write-Status "Failed to determine git HEAD. Specify -CommitSha explicitly." -Type Error
        exit 1
    }
}
$ShortSha = $CommitSha.Substring(0, 7)

$GitBranch = (git -C $RepoRoot branch --show-current 2>$null)
if (-not $GitBranch) { $GitBranch = "detached" }

if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot ".mad\tests\results"
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

if (-not $EvalRunId) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    $EvalRunId = "eval-$ts-$ShortSha"
}

# Reconcile Timeout (seconds) with legacy TimeoutMinutes
# If user explicitly passed -TimeoutMinutes, use that (converted to seconds)
# Otherwise use -Timeout (seconds, default 600)
$wasBound = $PSBoundParameters.ContainsKey('TimeoutMinutes')
if ($wasBound) {
    $TimeoutSeconds = $TimeoutMinutes * 60
} else {
    $TimeoutSeconds = $Timeout
    $TimeoutMinutes = [Math]::Ceiling($Timeout / 60)
}

try {
    $ScenarioList = Resolve-ScenarioList -Scenario $Scenario
} catch {
    Write-Status $_.Exception.Message -Type Error
    exit 1
}

# ---------------------------------------------------------------------------
# Phase 2: Verify claude CLI
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Run Local Agent Eval" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Status "Run ID:    $EvalRunId" -Type Info
Write-Status "Commit:    $ShortSha ($GitBranch)" -Type Info
Write-Status "Scenarios: $($ScenarioList -join ', ')" -Type Info
Write-Status "Max turns: $MaxTurns | Timeout: ${TimeoutSeconds}s | Cost limit: `$$CostLimit" -Type Info
if ($DebugMode) { Write-Status "Debug mode: ENABLED" -Type Warning }
Write-Status "Output:    $OutputDir" -Type Info
Write-Host ""

try {
    # Temporarily unset CLAUDECODE to allow nested CLI invocation from within Claude Code sessions
    $savedClaudeCode = $env:CLAUDECODE
    $env:CLAUDECODE = $null
    try {
        $claudeVersion = & claude --version 2>&1
        if ($LASTEXITCODE -ne 0) { throw "claude --version exited with $LASTEXITCODE" }
        Write-Status "Claude CLI: $claudeVersion" -Type Success
    } finally {
        $env:CLAUDECODE = $savedClaudeCode
    }
} catch {
    Write-Status "Claude CLI not found on PATH. Install with: npm install -g @anthropic-ai/claude-code" -Type Error
    exit 1
}

try {
    $dotnetVersion = & dotnet --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "dotnet --version exited with $LASTEXITCODE" }
    Write-Status ".NET SDK:   $dotnetVersion" -Type Success
} catch {
    Write-Status ".NET SDK not found on PATH. Install from https://dotnet.microsoft.com" -Type Error
    exit 1
}

Write-Host ""

# ---------------------------------------------------------------------------
# DryRun: print resolved config and exit
# ---------------------------------------------------------------------------
if ($DryRun) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  DRY RUN - No scenarios will execute" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Status "Run ID:       $EvalRunId" -Type Info
    Write-Status "Commit:       $ShortSha ($GitBranch)" -Type Info
    Write-Status "Scenarios:    $($ScenarioList.Count) total" -Type Info
    Write-Status "Parallel:     $(if ($Parallel) { "YES (max $MaxParallel concurrent)" } else { "NO (sequential)" })" -Type Info
    Write-Status "Timeout:      ${TimeoutSeconds}s per scenario" -Type Info
    Write-Status "Cost limit:   `$$CostLimit per scenario" -Type Info
    Write-Status "Max turns:    $MaxTurns" -Type Info
    Write-Status "Output:       $OutputDir" -Type Info
    Write-Status "Baseline:     $(if ($IncludeBaseline) { 'YES' } else { 'NO' })" -Type Info
    Write-Host ""

    if ($Parallel) {
        # Show batching plan
        $batches = [System.Collections.ArrayList]::new()
        for ($i = 0; $i -lt $ScenarioList.Count; $i += $MaxParallel) {
            $end = [Math]::Min($i + $MaxParallel, $ScenarioList.Count)
            [void]$batches.Add($ScenarioList[$i..($end - 1)])
        }
        Write-Host "  Parallel execution plan:" -ForegroundColor White
        for ($b = 0; $b -lt $batches.Count; $b++) {
            $batchItems = $batches[$b]
            Write-Host "    Batch $($b + 1): $($batchItems -join ', ')" -ForegroundColor Cyan
        }
        Write-Host ""
        $seqEstimate = $ScenarioList.Count * $TimeoutSeconds
        $parEstimate = $batches.Count * $TimeoutSeconds
        Write-Host "  Estimated wall-clock (worst case):" -ForegroundColor White
        Write-Host "    Sequential: $([Math]::Round($seqEstimate / 60, 1)) min" -ForegroundColor DarkGray
        Write-Host "    Parallel:   $([Math]::Round($parEstimate / 60, 1)) min ($([Math]::Round($seqEstimate / [Math]::Max($parEstimate,1), 1))x speedup)" -ForegroundColor Green
    } else {
        Write-Host "  Execution order:" -ForegroundColor White
        for ($i = 0; $i -lt $ScenarioList.Count; $i++) {
            Write-Host "    $($i + 1). $($ScenarioList[$i])" -ForegroundColor Cyan
        }
    }

    if ($IncludeBaseline) {
        $configDependentScenarios = @('rule-adherence', 'negative-constraints')
        $baselineScenarios = @($ScenarioList | Where-Object { $_ -notin $configDependentScenarios })
        Write-Host ""
        Write-Host "  Baseline scenarios ($($baselineScenarios.Count)):" -ForegroundColor White
        foreach ($bs in $baselineScenarios) {
            Write-Host "    - $bs" -ForegroundColor DarkGray
        }
        if ($baselineScenarios.Count -lt $ScenarioList.Count) {
            $excluded = @($ScenarioList | Where-Object { $_ -in $configDependentScenarios })
            Write-Host "  Excluded from baseline: $($excluded -join ', ')" -ForegroundColor DarkYellow
        }
    }

    Write-Host ""
    exit 0
}

# ---------------------------------------------------------------------------
# Project setup helpers
# ---------------------------------------------------------------------------

function Setup-InvestigateAndImplement {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        & dotnet new classlib -n EvalProject --no-restore 2>&1 | Out-Null
        & dotnet new xunit -n EvalProject.Tests --no-restore 2>&1 | Out-Null
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null
        & dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj 2>&1 | Out-Null

        # Remove default files
        Remove-Item -Path "EvalProject/Class1.cs" -ErrorAction SilentlyContinue
        Remove-Item -Path "EvalProject.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Create Calculator.cs with deliberate bug
        $calculatorCs = @'
using System.Linq;

public class Calculator
{
    public int Add(int a, int b) => a + b;
    public int Subtract(int a, int b) => a - b;
    public int Multiply(int a, int b) => a * b;
    public int Divide(int a, int b) => a / b;
    public double Average(int[] numbers) => numbers.Sum() / numbers.Length;
}
'@
        Set-Content -Path "EvalProject/Calculator.cs" -Value $calculatorCs -Encoding UTF8

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-ReviewAndFix {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        & dotnet new webapi -n EvalProject --no-restore --no-https 2>&1 | Out-Null
        & dotnet new xunit -n EvalProject.Tests --no-restore 2>&1 | Out-Null
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null
        & dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj 2>&1 | Out-Null
        & dotnet add EvalProject/EvalProject.csproj package Dapper --no-restore 2>&1 | Out-Null

        # Create Models directory
        New-Item -ItemType Directory -Path "EvalProject/Models" -Force | Out-Null

        $userCs = @'
namespace EvalProject.Models;

public class User
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
}

public class CreateUserRequest
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
}
'@
        Set-Content -Path "EvalProject/Models/User.cs" -Value $userCs -Encoding UTF8

        # Create Controllers directory
        New-Item -ItemType Directory -Path "EvalProject/Controllers" -Force | Out-Null

        $controllerCs = @'
using System.Data;
using Dapper;
using EvalProject.Models;
using Microsoft.AspNetCore.Mvc;

namespace EvalProject.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IDbConnection _db;

    public UsersController(IDbConnection db)
    {
        _db = db;
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string name)
    {
        // Vulnerable: string concatenation in SQL
        var sql = $"SELECT * FROM Users WHERE Name = '{name}'";
        var users = await _db.QueryAsync<User>(sql);
        return Ok(users);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        // Missing input validation
        var user = new User { Name = request.Name, Email = request.Email };
        await _db.ExecuteAsync("INSERT INTO Users (Name, Email) VALUES (@Name, @Email)", user);
        return Created($"/api/users/{user.Id}", user);
    }
}
'@
        Set-Content -Path "EvalProject/Controllers/UsersController.cs" -Value $controllerCs -Encoding UTF8

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-CoverageLoop {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        & dotnet new classlib -n EvalProject --no-restore 2>&1 | Out-Null
        & dotnet new xunit -n EvalProject.Tests --no-restore 2>&1 | Out-Null
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null
        & dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj package NSubstitute --no-restore 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj package coverlet.collector --no-restore 2>&1 | Out-Null
        & dotnet add EvalProject/EvalProject.csproj package Microsoft.Extensions.Logging.Abstractions --no-restore 2>&1 | Out-Null

        # Remove default files
        Remove-Item -Path "EvalProject/Class1.cs" -ErrorAction SilentlyContinue
        Remove-Item -Path "EvalProject.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Create interfaces
        $repoInterface = @'
using System.Threading.Tasks;

public interface IOrderRepository
{
    Task<Order?> GetAsync(string id);
    Task SaveAsync(Order order);
}
'@
        Set-Content -Path "EvalProject/IOrderRepository.cs" -Value $repoInterface -Encoding UTF8

        # Create domain models
        $orderCs = @'
using System.Collections.Generic;

public class Order
{
    public string Id { get; set; } = string.Empty;
    public List<OrderItem> Items { get; set; } = new();
    public decimal Total { get; set; }
    public OrderStatus Status { get; set; }
}

public class OrderItem
{
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public int Quantity { get; set; }
}

public class CreateOrderRequest
{
    public List<OrderItem> Items { get; set; } = new();
}

public enum OrderStatus
{
    Created,
    Processing,
    Shipped,
    Cancelled
}
'@
        Set-Content -Path "EvalProject/Order.cs" -Value $orderCs -Encoding UTF8

        # Create custom exceptions
        $exceptionsCs = @'
using System;

public class ValidationException : Exception
{
    public ValidationException(string message) : base(message) { }
}

public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
}
'@
        Set-Content -Path "EvalProject/Exceptions.cs" -Value $exceptionsCs -Encoding UTF8

        # Create OrderService with multiple branches
        $serviceCs = @'
using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

public class OrderService
{
    private readonly IOrderRepository _repo;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repo, ILogger<OrderService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public async Task<Order> CreateOrder(CreateOrderRequest request)
    {
        if (request == null) throw new ArgumentNullException(nameof(request));

        if (request.Items.Count == 0)
        {
            _logger.LogWarning("Empty order attempted");
            throw new ValidationException("Order must have at least one item");
        }

        var total = request.Items.Sum(i => i.Price * i.Quantity);

        if (total > 10000)
        {
            _logger.LogInformation("High-value order: {Total}", total);
        }

        var order = new Order
        {
            Id = Guid.NewGuid().ToString(),
            Items = request.Items,
            Total = total,
            Status = OrderStatus.Created
        };

        await _repo.SaveAsync(order);
        return order;
    }

    public async Task<Order> CancelOrder(string orderId)
    {
        var order = await _repo.GetAsync(orderId);
        if (order == null) throw new NotFoundException($"Order {orderId} not found");

        if (order.Status == OrderStatus.Shipped)
            throw new InvalidOperationException("Cannot cancel shipped order");

        order.Status = OrderStatus.Cancelled;
        await _repo.SaveAsync(order);
        return order;
    }
}
'@
        Set-Content -Path "EvalProject/OrderService.cs" -Value $serviceCs -Encoding UTF8

        # Create partial test (happy path only)
        $testCs = @'
using System.Collections.Generic;
using System.Threading.Tasks;
using NSubstitute;
using Microsoft.Extensions.Logging;
using Xunit;

public class OrderServiceTests
{
    private readonly IOrderRepository _repo = Substitute.For<IOrderRepository>();
    private readonly ILogger<OrderService> _logger = Substitute.For<ILogger<OrderService>>();

    [Fact]
    public async Task CreateOrder_WithValidRequest_ReturnsOrder()
    {
        var service = new OrderService(_repo, _logger);
        var request = new CreateOrderRequest
        {
            Items = new List<OrderItem>
            {
                new() { Name = "Widget", Price = 9.99m, Quantity = 2 }
            }
        };

        var result = await service.CreateOrder(request);

        Assert.NotNull(result);
        Assert.Equal(OrderStatus.Created, result.Status);
        Assert.Equal(19.98m, result.Total);
        await _repo.Received(1).SaveAsync(Arg.Any<Order>());
    }
}
'@
        Set-Content -Path "EvalProject.Tests/OrderServiceTests.cs" -Value $testCs -Encoding UTF8

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-RuleAdherence {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        & dotnet new classlib -n EvalProject --no-restore 2>&1 | Out-Null
        & dotnet new xunit -n EvalProject.Tests --no-restore 2>&1 | Out-Null
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null
        & dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj 2>&1 | Out-Null
        & dotnet add EvalProject/EvalProject.csproj package Microsoft.Extensions.Logging.Abstractions --no-restore 2>&1 | Out-Null
        & dotnet add EvalProject/EvalProject.csproj package Microsoft.Extensions.Http --no-restore 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj package NSubstitute --no-restore 2>&1 | Out-Null

        # Remove default files
        Remove-Item -Path "EvalProject/Class1.cs" -ErrorAction SilentlyContinue
        Remove-Item -Path "EvalProject.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Create .claude/ rules directory with coding rules
        New-Item -ItemType Directory -Path ".claude/rules" -Force | Out-Null

        $claudeMd = @'
# Project Rules

## Coding Standards (ENFORCED)

1. **Logging**: Always use `ILogger<T>` for logging. NEVER use `Console.WriteLine` or `Console.Write`.
2. **Async pattern**: All I/O methods MUST be async. Use `async Task<T>` return types.
3. **Dependency injection**: Every service class MUST have a corresponding interface (e.g., `IWeatherService` for `WeatherService`). Register via constructor injection.
4. **Naming**: Public methods use PascalCase. Async methods should use the `Async` suffix.
5. **No static helpers**: Do not create static utility/helper classes. Use instance methods with DI.
'@
        Set-Content -Path "CLAUDE.md" -Value $claudeMd -Encoding UTF8

        # Create an existing service as a pattern example
        $existingService = @'
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace EvalProject;

public interface IGreetingService
{
    Task<string> GetGreetingAsync(string name);
}

public class GreetingService : IGreetingService
{
    private readonly ILogger<GreetingService> _logger;

    public GreetingService(ILogger<GreetingService> logger)
    {
        _logger = logger;
    }

    public async Task<string> GetGreetingAsync(string name)
    {
        _logger.LogInformation("Generating greeting for {Name}", name);
        await Task.CompletedTask;
        return $"Hello, {name}!";
    }
}
'@
        Set-Content -Path "EvalProject/GreetingService.cs" -Value $existingService -Encoding UTF8

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-NegativeConstraints {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        & dotnet new classlib -n EvalProject --no-restore 2>&1 | Out-Null
        & dotnet new xunit -n EvalProject.Tests --no-restore 2>&1 | Out-Null
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null
        & dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj package NSubstitute --no-restore 2>&1 | Out-Null

        # Remove default files
        Remove-Item -Path "EvalProject/Class1.cs" -ErrorAction SilentlyContinue
        Remove-Item -Path "EvalProject.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Create CLAUDE.md with explicit negative constraints
        $claudeMd = @'
# Project Constraints (STRICTLY ENFORCED)

## DO NOT Rules

1. **DO NOT** add XML documentation comments (`///`). Use code that is self-documenting.
2. **DO NOT** create any class with "Helper" or "Utility" in the name. Use focused, single-purpose classes.
3. **DO NOT** add try/catch blocks in service code. Let exceptions propagate to the caller. The middleware handles all exception mapping.
4. **DO NOT** modify existing files. Only create NEW files. Existing code is frozen and owned by another team.

## DO Rules

1. Create a separate validator class (e.g., `UserValidator`) for input validation logic.
2. Validators should throw `ArgumentException` for invalid input.
3. All new code goes in the `EvalProject` project.
'@
        Set-Content -Path "CLAUDE.md" -Value $claudeMd -Encoding UTF8

        # Create UserService.cs (the frozen file that must NOT be modified)
        $userServiceCs = @'
namespace EvalProject;

public class User
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int Age { get; set; }
}

public class UserService
{
    public User CreateUser(string name, string email, int age)
    {
        return new User { Name = name, Email = email, Age = age };
    }

    public User UpdateUser(User existing, string newName, string newEmail)
    {
        existing.Name = newName;
        existing.Email = newEmail;
        return existing;
    }
}
'@
        Set-Content -Path "EvalProject/UserService.cs" -Value $userServiceCs -Encoding UTF8

        # Save a copy to verify it was not modified
        New-Item -ItemType Directory -Path ".eval-baseline" -Force | Out-Null
        Copy-Item "EvalProject/UserService.cs" ".eval-baseline/UserService.cs"

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-RefactorExtractService {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        & dotnet new webapi -n EvalProject --no-restore --no-https 2>&1 | Out-Null
        & dotnet new xunit -n EvalProject.Tests --no-restore 2>&1 | Out-Null
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null
        & dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj 2>&1 | Out-Null

        # Remove default test file
        Remove-Item -Path "EvalProject.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Create ProductController with inline pricing logic
        New-Item -ItemType Directory -Path "EvalProject/Controllers" -Force | Out-Null

        $controllerCs = @'
using Microsoft.AspNetCore.Mvc;

namespace EvalProject.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductController : ControllerBase
{
    [HttpGet("{id}/price")]
    public IActionResult GetPrice(int id, [FromQuery] int quantity = 1)
    {
        // Inline pricing logic that should be extracted
        decimal basePrice = 29.99m;
        decimal discount = 0m;
        if (quantity >= 100) discount = 0.20m;
        else if (quantity >= 50) discount = 0.15m;
        else if (quantity >= 10) discount = 0.10m;

        decimal finalPrice = basePrice * quantity * (1 - discount);
        return Ok(new { id, quantity, basePrice, discount, finalPrice });
    }
}
'@
        Set-Content -Path "EvalProject/Controllers/ProductController.cs" -Value $controllerCs -Encoding UTF8

        # Create tests for the pricing logic
        $testCs = @'
using EvalProject.Controllers;
using Microsoft.AspNetCore.Mvc;
using Xunit;

public class ProductControllerTests
{
    [Fact]
    public void GetPrice_SingleItem_NoDiscount()
    {
        var controller = new ProductController();
        var result = controller.GetPrice(1, 1) as OkObjectResult;
        Assert.NotNull(result);
    }

    [Theory]
    [InlineData(1, 29.99)]
    [InlineData(10, 269.91)]
    [InlineData(50, 1274.575)]
    [InlineData(100, 2399.20)]
    public void GetPrice_VariousQuantities_CorrectDiscount(int qty, decimal expected)
    {
        var controller = new ProductController();
        var result = controller.GetPrice(1, qty) as OkObjectResult;
        Assert.NotNull(result);
    }
}
'@
        Set-Content -Path "EvalProject.Tests/ProductControllerTests.cs" -Value $testCs -Encoding UTF8

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-CrossProjectDependency {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        # Create solution
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null

        # Create class library project
        & dotnet new classlib -n NotificationLib --no-restore 2>&1 | Out-Null
        Remove-Item -Path "NotificationLib/Class1.cs" -ErrorAction SilentlyContinue

        # Create INotificationService interface
        $interfaceCs = @'
using System.Threading.Tasks;

namespace NotificationLib;

public interface INotificationService
{
    Task<bool> SendAsync(string recipient, string message);
}
'@
        Set-Content -Path "NotificationLib/INotificationService.cs" -Value $interfaceCs -Encoding UTF8

        # Create EmailNotificationService implementation
        $emailServiceCs = @'
using System.Threading.Tasks;

namespace NotificationLib;

public class EmailNotificationService : INotificationService
{
    public Task<bool> SendAsync(string recipient, string message)
    {
        // Simulate email sending
        if (string.IsNullOrWhiteSpace(recipient)) return Task.FromResult(false);
        return Task.FromResult(true);
    }
}
'@
        Set-Content -Path "NotificationLib/EmailNotificationService.cs" -Value $emailServiceCs -Encoding UTF8

        # Create web API project
        & dotnet new webapi -n NotificationApi --no-restore --no-https 2>&1 | Out-Null

        # Add project reference from API to library
        & dotnet add NotificationApi/NotificationApi.csproj reference NotificationLib/NotificationLib.csproj 2>&1 | Out-Null

        # Overwrite Program.cs with DI registration and health endpoint
        $programCs = @'
using NotificationLib;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddScoped<INotificationService, EmailNotificationService>();

var app = builder.Build();

app.MapControllers();
app.MapGet("/health", () => "ok");

app.Run();
'@
        Set-Content -Path "NotificationApi/Program.cs" -Value $programCs -Encoding UTF8

        # Create test project
        & dotnet new xunit -n NotificationApi.Tests --no-restore 2>&1 | Out-Null
        Remove-Item -Path "NotificationApi.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Add project references to test project
        & dotnet add NotificationApi.Tests/NotificationApi.Tests.csproj reference NotificationLib/NotificationLib.csproj 2>&1 | Out-Null
        & dotnet add NotificationApi.Tests/NotificationApi.Tests.csproj reference NotificationApi/NotificationApi.csproj 2>&1 | Out-Null

        # Create existing tests for the email service
        $testCs = @'
using NotificationLib;
using Xunit;

namespace NotificationApi.Tests;

public class EmailNotificationServiceTests
{
    [Fact]
    public async Task SendAsync_ValidRecipient_ReturnsTrue()
    {
        var svc = new EmailNotificationService();
        var result = await svc.SendAsync("user@example.com", "Hello");
        Assert.True(result);
    }

    [Fact]
    public async Task SendAsync_EmptyRecipient_ReturnsFalse()
    {
        var svc = new EmailNotificationService();
        var result = await svc.SendAsync("", "Hello");
        Assert.False(result);
    }
}
'@
        Set-Content -Path "NotificationApi.Tests/EmailNotificationServiceTests.cs" -Value $testCs -Encoding UTF8

        # Add all projects to solution
        & dotnet sln add NotificationLib/NotificationLib.csproj NotificationApi/NotificationApi.csproj NotificationApi.Tests/NotificationApi.Tests.csproj 2>&1 | Out-Null

        & dotnet restore 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Setup-EnterpriseCosmosEntity {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        # Create solution
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null

        # Create projects
        & dotnet new classlib -n Common --no-restore 2>&1 | Out-Null
        Remove-Item -Path "Common/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n DataAccess --no-restore 2>&1 | Out-Null
        Remove-Item -Path "DataAccess/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n BusinessLogic --no-restore 2>&1 | Out-Null
        Remove-Item -Path "BusinessLogic/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n DependencyInjection --no-restore 2>&1 | Out-Null
        Remove-Item -Path "DependencyInjection/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new web -n API --no-restore 2>&1 | Out-Null

        # Add projects to solution
        & dotnet sln add Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj DependencyInjection/DependencyInjection.csproj API/API.csproj 2>&1 | Out-Null

        # Add project references
        & dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null
        & dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj 2>&1 | Out-Null

        # Add NuGet packages
        & dotnet add Common/Common.csproj package System.Runtime.Serialization.Primitives 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Newtonsoft.Json 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.DataAnnotations 2>&1 | Out-Null

        # Restore all packages
        & dotnet restore 2>&1 | Out-Null

        # --- Common/Models/CosmosEntity.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Models" | Out-Null
        $cosmosEntityCs = @'
using System.Text.Json.Serialization;

namespace Common.Models;

public interface IPartitioned
{
    string GetPartitionKey();
}

public abstract class CosmosEntity : IPartitioned
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("modifiedAt")]
    public DateTimeOffset ModifiedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("isDeleted")]
    public bool IsDeleted { get; set; }

    public abstract string GetPartitionKey();
}
'@
        Set-Content -Path "Common/Models/CosmosEntity.cs" -Value $cosmosEntityCs -Encoding UTF8

        # --- Common/Models/CaseEntity.cs ---
        $caseEntityCs = @'
using System.Text.Json.Serialization;

namespace Common.Models;

public class CaseEntity : CosmosEntity
{
    [JsonPropertyName("caseNumber")]
    public string CaseNumber { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public CaseStatus Status { get; set; } = CaseStatus.Open;

    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    public override string GetPartitionKey() => CaseNumber;
}
'@
        Set-Content -Path "Common/Models/CaseEntity.cs" -Value $caseEntityCs -Encoding UTF8

        # --- Common/Models/CaseStatus.cs ---
        $caseStatusCs = @'
using System.Runtime.Serialization;
using System.Text.Json.Serialization;

namespace Common.Models;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CaseStatus
{
    [EnumMember(Value = "Open")]
    Open,

    [EnumMember(Value = "Active")]
    Active,

    [EnumMember(Value = "Closed")]
    Closed
}
'@
        Set-Content -Path "Common/Models/CaseStatus.cs" -Value $caseStatusCs -Encoding UTF8

        # --- Common/Constants/DocumentTypes.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Constants" | Out-Null
        $docTypesCs = @'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
'@
        Set-Content -Path "Common/Constants/DocumentTypes.cs" -Value $docTypesCs -Encoding UTF8

        # --- Common/Constants/LogEventIds.cs ---
        $logEventIdsCs = @'
namespace Common.Constants;

public static class LogEventIds
{
    // API layer: 1000-1999
    public const int CaseEndpointCalled = 1000;
    public const int CaseEndpointCompleted = 1001;

    // DataAccess layer: 3000-3999
    public const int CosmosQueryExecuted = 3000;
    public const int CosmosItemCreated = 3001;

    // BusinessLogic layer: 4000-4999
    public const int CaseHandlerProcessing = 4000;
    public const int CaseHandlerCompleted = 4001;

    // Common layer: 5000-5999
    public const int ConfigurationLoaded = 5000;
}
'@
        Set-Content -Path "Common/Constants/LogEventIds.cs" -Value $logEventIdsCs -Encoding UTF8

        # --- Common/Configuration/IConfigOptions.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Configuration" | Out-Null
        $configOptionsCs = @'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
'@
        Set-Content -Path "Common/Configuration/IConfigOptions.cs" -Value $configOptionsCs -Encoding UTF8

        # --- Common/Configuration/CosmosOptions.cs ---
        $cosmosOptionsCs = @'
using System.ComponentModel.DataAnnotations;

namespace Common.Configuration;

public class CosmosOptions : IConfigOptions
{
    public static string ConfigSectionKey => "Cosmos";

    [Required]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    public string ContainerId { get; set; } = "cms";
}
'@
        Set-Content -Path "Common/Configuration/CosmosOptions.cs" -Value $cosmosOptionsCs -Encoding UTF8

        # --- Common/Interfaces/ICaseRepository.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Interfaces" | Out-Null
        $caseRepoIfaceCs = @'
using Common.Models;
using Common.Pagination;

namespace Common.Interfaces;

public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);
    Task<CaseEntity> UpdateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
'@
        Set-Content -Path "Common/Interfaces/ICaseRepository.cs" -Value $caseRepoIfaceCs -Encoding UTF8

        # --- Common/Pagination/PagedResult.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Pagination" | Out-Null
        $pagedResultCs = @'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
'@
        Set-Content -Path "Common/Pagination/PagedResult.cs" -Value $pagedResultCs -Encoding UTF8

        # --- DataAccess/Repositories/CaseRepository.cs ---
        New-Item -ItemType Directory -Force -Path "DataAccess/Repositories" | Out-Null
        $caseRepoCs = @'
using Common.Constants;
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories;

public class CaseRepository : ICaseRepository
{
    private readonly Container _container;
    private readonly ILogger<CaseRepository> _logger;

    public CaseRepository(Container container, ILogger<CaseRepository> logger)
    {
        _container = container;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.Id = DocumentTypes.CreateId(DocumentTypes.Case);
        entity.Type = DocumentTypes.Case;
        entity.PartitionKey = entity.GetPartitionKey();
        var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _container.ReadItemAsync<CaseEntity>(id, new PartitionKey(partitionKey), cancellationToken: cancellationToken);
            return response.Resource.IsDeleted ? null : response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", DocumentTypes.Case);

        var options = new QueryRequestOptions { MaxItemCount = pageSize, PartitionKey = new PartitionKey(caseNumber) };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, continuationToken, options);

        var items = new List<CaseEntity>();
        string? nextToken = null;
        if (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
            nextToken = response.ContinuationToken;
        }

        return new PagedResult<CaseEntity> { Items = items, ContinuationToken = nextToken };
    }

    public async Task<CaseEntity> UpdateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.ModifiedAt = DateTimeOffset.UtcNow;
        var response = await _container.ReplaceItemAsync(entity, entity.Id, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        var entity = await GetByIdAsync(id, partitionKey, cancellationToken);
        if (entity != null)
        {
            entity.IsDeleted = true;
            await UpdateAsync(entity, cancellationToken);
        }
    }
}
'@
        Set-Content -Path "DataAccess/Repositories/CaseRepository.cs" -Value $caseRepoCs -Encoding UTF8

        # --- BusinessLogic/Interfaces/ICaseHandler.cs ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Interfaces" | Out-Null
        $caseHandlerIfaceCs = @'
using Common.Models;
using Common.Pagination;

namespace BusinessLogic.Interfaces;

public interface ICaseHandler
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);
    Task SoftDeleteCaseAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
'@
        Set-Content -Path "BusinessLogic/Interfaces/ICaseHandler.cs" -Value $caseHandlerIfaceCs -Encoding UTF8

        # --- BusinessLogic/Handlers/CaseHandler.cs ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Handlers" | Out-Null
        $caseHandlerCs = @'
using BusinessLogic.Interfaces;
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Handlers;

public class CaseHandler : ICaseHandler
{
    private readonly ICaseRepository _repository;
    private readonly ILogger<CaseHandler> _logger;

    public CaseHandler(ICaseRepository repository, ILogger<CaseHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        LogMessages.CreatingCase(_logger, entity.CaseNumber);
        var result = await _repository.CreateAsync(entity, cancellationToken);
        LogMessages.CaseCreated(_logger, result.Id);
        return result;
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }

    public async Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
    }

    public async Task SoftDeleteCaseAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        LogMessages.DeletingCase(_logger, id);
        await _repository.SoftDeleteAsync(id, partitionKey, cancellationToken);
    }
}
'@
        Set-Content -Path "BusinessLogic/Handlers/CaseHandler.cs" -Value $caseHandlerCs -Encoding UTF8

        # --- BusinessLogic/LogMessages.cs ---
        $logMessagesCs = @'
using Microsoft.Extensions.Logging;

namespace BusinessLogic;

public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Creating case {CaseNumber}")]
    public static partial void CreatingCase(ILogger logger, string caseNumber);

    [LoggerMessage(Level = LogLevel.Information, Message = "Case created with ID {CaseId}")]
    public static partial void CaseCreated(ILogger logger, string caseId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Deleting case {CaseId}")]
    public static partial void DeletingCase(ILogger logger, string caseId);
}
'@
        Set-Content -Path "BusinessLogic/LogMessages.cs" -Value $logMessagesCs -Encoding UTF8

        # --- DependencyInjection/ServiceCollectionExtensions.cs ---
        $diExtensionsCs = @'
using Azure.Identity;
using BusinessLogic.Handlers;
using BusinessLogic.Interfaces;
using Common.Configuration;
using Common.Interfaces;
using DataAccess.Repositories;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCmsServices(this IServiceCollection services, IConfiguration configuration)
    {
        AddConfiguration(services, configuration);
        AddDataAccess(services);
        AddBusinessLogic(services);
        return services;
    }

    private static void AddConfiguration(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosOptions>()
            .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }

    private static void AddDataAccess(IServiceCollection services)
    {
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
            var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential());
            return client.GetContainer(options.DatabaseId, options.ContainerId);
        });

        services.AddScoped<ICaseRepository, CaseRepository>();
    }

    private static void AddBusinessLogic(IServiceCollection services)
    {
        services.AddScoped<ICaseHandler, CaseHandler>();
    }
}
'@
        Set-Content -Path "DependencyInjection/ServiceCollectionExtensions.cs" -Value $diExtensionsCs -Encoding UTF8

        # --- API/Controllers/CasesController.cs ---
        New-Item -ItemType Directory -Force -Path "API/Controllers" | Out-Null
        $casesControllerCs = @'
using BusinessLogic.Interfaces;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseHandler _handler;

    public CasesController(ICaseHandler handler)
    {
        _handler = handler;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _handler.CreateCaseAsync(entity, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _handler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("by-case/{caseNumber}")]
    public async Task<ActionResult> GetByCaseNumber(string caseNumber, [FromQuery] int pageSize = 25, [FromQuery] string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var result = await _handler.GetCasesByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        await _handler.SoftDeleteCaseAsync(id, partitionKey, cancellationToken);
        return NoContent();
    }
}
'@
        Set-Content -Path "API/Controllers/CasesController.cs" -Value $casesControllerCs -Encoding UTF8

        # --- API/Program.cs ---
        $programCs = @'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("runtimesettings.json", optional: true);

builder.Services.AddControllers();
builder.Services.AddCmsServices(builder.Configuration);

var app = builder.Build();

app.MapControllers();

app.Run();
'@
        Set-Content -Path "API/Program.cs" -Value $programCs -Encoding UTF8

        # --- API/appsettings.json ---
        $appSettingsJson = @'
{
  "Cosmos": {
    "AccountEndpoint": "https://localhost:8081",
    "DatabaseId": "CMS",
    "ContainerId": "cms"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
'@
        Set-Content -Path "API/appsettings.json" -Value $appSettingsJson -Encoding UTF8

        # --- API/runtimesettings.json ---
        $runtimeSettingsJson = @'
{
  "Cosmos": {
    "AccountEndpoint": "https://cosmos-override.example.com:443"
  }
}
'@
        Set-Content -Path "API/runtimesettings.json" -Value $runtimeSettingsJson -Encoding UTF8

        # Create test project for behavioral verification
        & dotnet new xunit -n EvalSolution.Tests --no-restore 2>&1 | Out-Null
        & dotnet sln add EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalSolution.Tests/EvalSolution.Tests.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet restore EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        Remove-Item -Path "EvalSolution.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

    } finally {
        Pop-Location
    }
}

function Setup-TrapAntipatternResistance {
    param([string]$WorkDir)

    Push-Location $WorkDir
    try {
        # Create solution
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null

        # Create projects
        & dotnet new classlib -n Common --no-restore 2>&1 | Out-Null
        Remove-Item -Path "Common/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n DataAccess --no-restore 2>&1 | Out-Null
        Remove-Item -Path "DataAccess/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n BusinessLogic --no-restore 2>&1 | Out-Null
        Remove-Item -Path "BusinessLogic/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n DependencyInjection --no-restore 2>&1 | Out-Null
        Remove-Item -Path "DependencyInjection/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new web -n API --no-restore 2>&1 | Out-Null

        # Add projects to solution
        & dotnet sln add Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj DependencyInjection/DependencyInjection.csproj API/API.csproj 2>&1 | Out-Null

        # Add project references
        & dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null
        & dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj 2>&1 | Out-Null

        # Add NuGet packages
        & dotnet add Common/Common.csproj package System.Runtime.Serialization.Primitives 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Newtonsoft.Json 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.DataAnnotations 2>&1 | Out-Null

        # Restore all packages
        & dotnet restore 2>&1 | Out-Null

        # ---------------------------------------------------------------
        # Common layer (CORRECT patterns for agent to follow)
        # ---------------------------------------------------------------

        # --- Common/Models/CosmosEntity.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Models" | Out-Null
        $cosmosEntityCs = @'
using System.Text.Json.Serialization;

namespace Common.Models;

public interface IPartitioned
{
    string GetPartitionKey();
}

public abstract class CosmosEntity : IPartitioned
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("modifiedAt")]
    public DateTimeOffset ModifiedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("isDeleted")]
    public bool IsDeleted { get; set; }

    public abstract string GetPartitionKey();
}
'@
        Set-Content -Path "Common/Models/CosmosEntity.cs" -Value $cosmosEntityCs -Encoding UTF8

        # --- Common/Models/CaseEntity.cs ---
        $caseEntityCs = @'
using System.Text.Json.Serialization;

namespace Common.Models;

public class CaseEntity : CosmosEntity
{
    [JsonPropertyName("caseNumber")]
    public string CaseNumber { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public CaseStatus Status { get; set; } = CaseStatus.Open;

    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    public override string GetPartitionKey() => CaseNumber;
}
'@
        Set-Content -Path "Common/Models/CaseEntity.cs" -Value $caseEntityCs -Encoding UTF8

        # --- Common/Models/CaseStatus.cs ---
        $caseStatusCs = @'
using System.Runtime.Serialization;
using System.Text.Json.Serialization;

namespace Common.Models;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CaseStatus
{
    [EnumMember(Value = "Open")]
    Open,

    [EnumMember(Value = "Active")]
    Active,

    [EnumMember(Value = "Closed")]
    Closed
}
'@
        Set-Content -Path "Common/Models/CaseStatus.cs" -Value $caseStatusCs -Encoding UTF8

        # --- Common/Constants/DocumentTypes.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Constants" | Out-Null
        $docTypesCs = @'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
'@
        Set-Content -Path "Common/Constants/DocumentTypes.cs" -Value $docTypesCs -Encoding UTF8

        # --- Common/Constants/LogEventIds.cs ---
        $logEventIdsCs = @'
namespace Common.Constants;

public static class LogEventIds
{
    // API layer: 1000-1999
    public const int CaseEndpointCalled = 1000;
    public const int CaseEndpointCompleted = 1001;

    // DataAccess layer: 3000-3999
    public const int CosmosQueryExecuted = 3000;
    public const int CosmosItemCreated = 3001;

    // BusinessLogic layer: 4000-4999
    public const int CaseHandlerProcessing = 4000;
    public const int CaseHandlerCompleted = 4001;

    // Common layer: 5000-5999
    public const int ConfigurationLoaded = 5000;
}
'@
        Set-Content -Path "Common/Constants/LogEventIds.cs" -Value $logEventIdsCs -Encoding UTF8

        # --- Common/Configuration/IConfigOptions.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Configuration" | Out-Null
        $configOptionsCs = @'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
'@
        Set-Content -Path "Common/Configuration/IConfigOptions.cs" -Value $configOptionsCs -Encoding UTF8

        # --- Common/Configuration/CosmosOptions.cs ---
        $cosmosOptionsCs = @'
using System.ComponentModel.DataAnnotations;

namespace Common.Configuration;

public class CosmosOptions : IConfigOptions
{
    public static string ConfigSectionKey => "Cosmos";

    [Required]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    public string ContainerId { get; set; } = "cms";
}
'@
        Set-Content -Path "Common/Configuration/CosmosOptions.cs" -Value $cosmosOptionsCs -Encoding UTF8

        # --- Common/Interfaces/ directory exists but has NO ICaseRepository ---
        # ANTIPATTERN #2/#7: ICaseRepository is only in DataAccess (should be here in Common/Interfaces)
        New-Item -ItemType Directory -Force -Path "Common/Interfaces" | Out-Null

        # --- Common/Pagination/PagedResult.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Pagination" | Out-Null
        $pagedResultCs = @'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
'@
        Set-Content -Path "Common/Pagination/PagedResult.cs" -Value $pagedResultCs -Encoding UTF8

        # ---------------------------------------------------------------
        # DataAccess layer (contains ANTIPATTERNS #2, #3, #4, #7)
        # ---------------------------------------------------------------

        # --- ANTIPATTERN #2 + #7: ICaseRepository interface ALSO in DataAccess (should only be in Common) ---
        New-Item -ItemType Directory -Force -Path "DataAccess/Repositories" | Out-Null
        $daCaseRepoIfaceCs = @'
using Common.Models;

namespace DataAccess.Repositories;

// ANTIPATTERN: Interface collocated with implementation (should only be in Common/Interfaces)
public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<List<CaseEntity>> GetByCaseNumberAsync(string caseNumber, CancellationToken cancellationToken = default);
}
'@
        Set-Content -Path "DataAccess/Repositories/ICaseRepository.cs" -Value $daCaseRepoIfaceCs -Encoding UTF8

        # --- ANTIPATTERN #3 + #4: CaseRepository with List return and magic string ---
        $caseRepoCs = @'
using Common.Models;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories;

public class CaseRepository : ICaseRepository
{
    private readonly Container _container;
    private readonly ILogger<CaseRepository> _logger;

    public CaseRepository(Container container, ILogger<CaseRepository> logger)
    {
        _container = container;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.Id = Guid.NewGuid().ToString("N");
        entity.Type = "case";
        entity.PartitionKey = entity.GetPartitionKey();
        var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _container.ReadItemAsync<CaseEntity>(id, new PartitionKey(partitionKey), cancellationToken: cancellationToken);
            return response.Resource.IsDeleted ? null : response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    // ANTIPATTERN #3: Returns Task<List<>> instead of PagedResult<>
    // ANTIPATTERN #4: Uses magic string "case" instead of DocumentTypes.Case
    public async Task<List<CaseEntity>> GetByCaseNumberAsync(string caseNumber, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", "case");

        var options = new QueryRequestOptions { PartitionKey = new PartitionKey(caseNumber) };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, requestOptions: options);

        var items = new List<CaseEntity>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
        }
        return items;
    }
}
'@
        Set-Content -Path "DataAccess/Repositories/CaseRepository.cs" -Value $caseRepoCs -Encoding UTF8

        # ---------------------------------------------------------------
        # BusinessLogic layer (contains ANTIPATTERNS #1, #5)
        # ---------------------------------------------------------------

        # --- ANTIPATTERN #1: Named "Service" instead of "Handler" ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Interfaces" | Out-Null
        $caseServiceIfaceCs = @'
using Common.Models;

namespace BusinessLogic.Interfaces;

// ANTIPATTERN #1: Should be ICaseHandler, not ICaseService
public interface ICaseService
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
'@
        Set-Content -Path "BusinessLogic/Interfaces/ICaseService.cs" -Value $caseServiceIfaceCs -Encoding UTF8

        # --- ANTIPATTERN #1 + #5: CaseService with interpolated logging ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Services" | Out-Null
        $caseServiceCs = @'
using BusinessLogic.Interfaces;
using Common.Models;
using DataAccess.Repositories;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services;

// ANTIPATTERN #1: Should be CaseHandler in Handlers/, not CaseService in Services/
public class CaseService : ICaseService
{
    private readonly ICaseRepository _repository;
    private readonly ILogger<CaseService> _logger;

    public CaseService(ICaseRepository repository, ILogger<CaseService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        // ANTIPATTERN #5: Uses string interpolation instead of LoggerMessage source generator
        _logger.LogInformation($"Creating case {entity.CaseNumber}");
        var result = await _repository.CreateAsync(entity, cancellationToken);
        _logger.LogInformation($"Created case {result.Id}");
        return result;
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation($"Getting case {id}");
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }
}
'@
        Set-Content -Path "BusinessLogic/Services/CaseService.cs" -Value $caseServiceCs -Encoding UTF8

        # --- LogMessages.cs with CORRECT [LoggerMessage] examples for other operations ---
        $logMessagesCs = @'
using Microsoft.Extensions.Logging;

namespace BusinessLogic;

public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Creating note for case {CaseNumber}")]
    public static partial void CreatingNote(ILogger logger, string caseNumber);

    [LoggerMessage(Level = LogLevel.Information, Message = "Note created with ID {NoteId}")]
    public static partial void NoteCreated(ILogger logger, string noteId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Deleting note {NoteId}")]
    public static partial void DeletingNote(ILogger logger, string noteId);
}
'@
        Set-Content -Path "BusinessLogic/LogMessages.cs" -Value $logMessagesCs -Encoding UTF8

        # ---------------------------------------------------------------
        # DependencyInjection layer
        # ---------------------------------------------------------------
        $diExtensionsCs = @'
using Azure.Identity;
using BusinessLogic.Interfaces;
using BusinessLogic.Services;
using Common.Configuration;
using DataAccess.Repositories;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCmsServices(this IServiceCollection services, IConfiguration configuration)
    {
        AddConfiguration(services, configuration);
        AddDataAccess(services);
        AddBusinessLogic(services);
        return services;
    }

    private static void AddConfiguration(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosOptions>()
            .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }

    private static void AddDataAccess(IServiceCollection services)
    {
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
            var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential());
            return client.GetContainer(options.DatabaseId, options.ContainerId);
        });

        services.AddScoped<ICaseRepository, CaseRepository>();
    }

    private static void AddBusinessLogic(IServiceCollection services)
    {
        services.AddScoped<ICaseService, CaseService>();
    }
}
'@
        Set-Content -Path "DependencyInjection/ServiceCollectionExtensions.cs" -Value $diExtensionsCs -Encoding UTF8

        # ---------------------------------------------------------------
        # API layer (contains ANTIPATTERN #6)
        # ---------------------------------------------------------------

        # --- ANTIPATTERN #6: Controller with try-catch block ---
        New-Item -ItemType Directory -Force -Path "API/Controllers" | Out-Null
        $casesControllerCs = @'
using BusinessLogic.Interfaces;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseService _service;

    public CasesController(ICaseService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        // ANTIPATTERN #6: try-catch in controller (should delegate to exception middleware)
        try
        {
            var result = await _service.CreateCaseAsync(entity, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _service.GetCaseByIdAsync(id, partitionKey, cancellationToken);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
'@
        Set-Content -Path "API/Controllers/CasesController.cs" -Value $casesControllerCs -Encoding UTF8

        # --- API/Program.cs ---
        $programCs = @'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("runtimesettings.json", optional: true);

builder.Services.AddControllers();
builder.Services.AddCmsServices(builder.Configuration);

var app = builder.Build();

app.MapControllers();

app.Run();
'@
        Set-Content -Path "API/Program.cs" -Value $programCs -Encoding UTF8

        # --- API/appsettings.json ---
        $appSettingsJson = @'
{
  "Cosmos": {
    "AccountEndpoint": "https://localhost:8081",
    "DatabaseId": "CMS",
    "ContainerId": "cms"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
'@
        Set-Content -Path "API/appsettings.json" -Value $appSettingsJson -Encoding UTF8

        # --- API/runtimesettings.json ---
        $runtimeSettingsJson = @'
{
  "Cosmos": {
    "AccountEndpoint": "https://cosmos-override.example.com:443"
  }
}
'@
        Set-Content -Path "API/runtimesettings.json" -Value $runtimeSettingsJson -Encoding UTF8

        # Create test project for behavioral verification
        & dotnet new xunit -n EvalSolution.Tests --no-restore 2>&1 | Out-Null
        & dotnet sln add EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalSolution.Tests/EvalSolution.Tests.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet restore EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        Remove-Item -Path "EvalSolution.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

    } finally {
        Pop-Location
    }
}

function Setup-MutationDetection {
    param([string]$WorkDir)

    # Load the Eval05-Mutation module for scaffold generation and mutation injection
    $modulePath = Join-Path $ScriptRoot "..\tests\shared\evals\Eval05-Mutation.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        throw "Eval05-Mutation.psm1 not found at $modulePath"
    }

    # Setup-Mutation creates the scaffold, selects mutations, injects them, and saves manifest
    Setup-Mutation -WorkDir $WorkDir -MutationCount 3
}

# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

function Get-ScenarioPrompt {
    param(
        [string]$ScenarioName,
        [string]$WorkDir
    )

    switch ($ScenarioName) {
        "investigate-and-implement" {
            return "Fix the bug in Calculator.Average - it uses integer division instead of floating-point division, causing incorrect results for non-evenly-divisible inputs. Also add a guard for empty arrays. Write tests for the fix. The project is at $WorkDir. Work directly in the project files. Do not use git."
        }
        "review-and-fix" {
            return "Review and fix the security issues in $WorkDir/EvalProject/Controllers/UsersController.cs. The Search method uses string interpolation in SQL which is a SQL injection vulnerability - fix it to use parameterized queries. The Create method is missing input validation - add basic null/empty checks. Write tests if appropriate. Work directly in the project files. Do not use git."
        }
        "coverage-loop" {
            return "Close the coverage gap for OrderService.cs in $WorkDir. The existing tests only cover CreateOrder happy path. Add tests for: null request, empty items, high-value order (over 10000), CancelOrder happy path, CancelOrder with non-existent order, and CancelOrder with shipped order. Target: all branches covered. Work directly in the project files. Do not use git."
        }
        "rule-adherence" {
            return Get-RuleAdherenceScorecardPrompt -WorkDir $WorkDir
        }
        "negative-constraints" {
            return "Add input validation for UserService in the project at $WorkDir. Read the CLAUDE.md file carefully -- it contains strict DO NOT constraints you MUST follow. Create a UserValidator class that validates name (non-empty, max 100 chars), email (contains @), and age (1-150). The validator should throw ArgumentException for invalid input. Write unit tests for the validator. IMPORTANT: Do NOT modify any existing files -- only create new files. Work directly in the project files. Do not use git."
        }
        "refactor-extract-service" {
            return "Extract the pricing logic from ProductController into a new PricingService with an IPricingService interface. Register PricingService in DI. ProductController should depend on IPricingService via constructor injection. All existing tests must still pass. The project is at $WorkDir. Work directly in the project files. Do not use git."
        }
        "cross-project-dependency" {
            return "Add an ISmsNotificationService interface to the NotificationLib class library with a SendSmsAsync(string phoneNumber, string message) method. Create an SmsNotificationService implementation. Register it in the API's DI container. Add a POST /api/notifications/sms endpoint that accepts {phoneNumber, message} and calls the service. Write unit tests for both the new service and the new endpoint. All existing tests must continue to pass. The project is at $WorkDir. Work directly in the project files. Do not use git."
        }
        "enterprise-cosmos-entity" {
            return "Add a new 'Attachment' entity to this project. Attachments belong to a case and store file metadata (fileName, contentType, sizeBytes, uploadedBy, uploadedAt). Requirements: Each attachment has a unique ID and belongs to a case (partition key is caseId). Support CRUD operations: create, get by ID, list by case (with pagination), soft delete. Add the AttachmentEntity model, AttachmentRepository with interface, AttachmentHandler, AttachmentsController endpoint, DI registration, and logging. Follow the existing patterns in the codebase exactly. The project is at $WorkDir. Work directly in the project files. Do not use git."
        }
        "trap-antipattern-resistance" {
            return @"
Add a new 'Attachment' entity to this project. Attachments belong to a case and store file metadata (fileName, contentType, sizeBytes, uploadedBy, uploadedAt). Requirements:
- Each attachment has a unique ID and belongs to a case (partition key is caseId)
- Support CRUD operations: create, get by ID, list by case (with pagination), soft delete
- Add the AttachmentEntity model, AttachmentRepository with interface, AttachmentHandler, AttachmentsController endpoint, DI registration, and logging
- Follow the existing patterns in the codebase exactly
The project is at $WorkDir. Work directly in the project files. Do not use git.
"@
        }
        "replay" {
            return Get-ReplayPrompt -WorkDir $WorkDir
        }
        "context-stress" {
            if (Get-Command -Name 'Get-ContextStressPrompt' -ErrorAction SilentlyContinue) {
                return Get-ContextStressPrompt -WorkDir $WorkDir
            }
            $eval03Module = Join-Path $PSScriptRoot "..\tests\shared\evals\Eval03-ContextStress.psm1"
            if (Test-Path $eval03Module) {
                Import-Module $eval03Module -Force -DisableNameChecking
                return Get-ContextStressPrompt -WorkDir $WorkDir
            }
            throw "Eval03-ContextStress.psm1 not found"
        }
        "arch-drift" {
            return Get-ArchDriftPrompt -WorkDir $WorkDir
        }
        "mutation-detection" {
            return @"
Review this consumer-project service codebase for bugs, security issues, performance problems, and convention violations. The project is a 5-layer .NET service (Common, DataAccess, BusinessLogic, DependencyInjection, API) that manages legal cases using Azure Cosmos DB.

For each issue found:
1. Identify the file and line
2. Describe the root cause
3. Fix the issue directly in the code

Focus on: Cosmos DB usage patterns, architecture layering, security best practices, performance antipatterns, and .NET naming/coding conventions.

The project is at $WorkDir. Work directly in the project files. Do not use git. After fixing issues, ensure the project still builds.
"@
        }
        "workflow-fidelity" {
            return Get-WorkflowPrompt -WorkDir $WorkDir
        }
        "cross-repo-consistency" {
            return Get-CrossRepoPrompt -WorkDir $WorkDir
        }
        default {
            throw "Unknown scenario: $ScenarioName"
        }
    }
}

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

function New-Assertion {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Expected = "",
        [string]$Actual = "",
        [string]$Message = ""
    )
    $obj = [ordered]@{ name = $Name; passed = $Passed }
    if ($Expected) { $obj["expected"] = $Expected }
    if ($Actual) { $obj["actual"] = $Actual }
    if ($Message) { $obj["message"] = $Message }
    return $obj
}

function Run-StandardAssertions {
    param(
        [string]$ScenarioName,
        [string]$WorkDir,
        [string]$StderrLog
    )

    $assertions = [System.Collections.ArrayList]::new()
    $buildPassed = $false
    $testsPassed = $false
    $filesCreated = @()

    # Assertion 1: build_passes
    Write-Status "  Assertion: build_passes" -Type Info
    Push-Location $WorkDir
    try {
        $buildOutput = & dotnet build --nologo -v q 2>&1 | ForEach-Object { $_.ToString() }
        $buildExit = $LASTEXITCODE
    } catch {
        $buildOutput = @("dotnet build threw: $($_.Exception.Message)")
        $buildExit = 1
    }
    Pop-Location

    if ($buildExit -eq 0) {
        [void]$assertions.Add((New-Assertion -Name "build_passes" -Passed $true -Expected "exit 0" -Actual "exit 0"))
        $buildPassed = $true
    } else {
        $firstError = ($buildOutput | Select-String "error " | Select-Object -First 1) -as [string]
        if (-not $firstError) { $firstError = "dotnet build failed" }
        $errMsg = if ($firstError.Length -gt 200) { $firstError.Substring(0, 200) } else { $firstError }
        [void]$assertions.Add((New-Assertion -Name "build_passes" -Passed $false -Expected "exit 0" -Actual "exit $buildExit" -Message $errMsg))
    }

    # Assertion 2: test_file_exists
    Write-Status "  Assertion: test_file_exists" -Type Info
    $testFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include "*Test*.cs", "*Tests*.cs" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
    if ($testFiles.Count -gt 0) {
        [void]$assertions.Add((New-Assertion -Name "test_file_exists" -Passed $true -Expected "*.Test*.cs" -Actual $testFiles[0].Name))
    } else {
        [void]$assertions.Add((New-Assertion -Name "test_file_exists" -Passed $false -Expected "*.Test*.cs" -Actual "none found"))
    }

    # Assertion 3: tests_pass
    Write-Status "  Assertion: tests_pass" -Type Info
    if ($testFiles.Count -gt 0 -and $buildPassed) {
        Push-Location $WorkDir
        try {
            $testOutput = & dotnet test --nologo -v q 2>&1 | ForEach-Object { $_.ToString() }
            $testExit = $LASTEXITCODE
        } catch {
            $testOutput = @("dotnet test threw: $($_.Exception.Message)")
            $testExit = 1
        }
        Pop-Location

        $testOutputStr = $testOutput -join "`n"
        if ($testOutputStr -match 'Passed!' -or $testOutputStr -match 'Passed:\s*[1-9]') {
            [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $true -Expected "0 failures" -Actual "all passed"))
            $testsPassed = $true
        } elseif ($testOutputStr -match 'Failed') {
            $failMatch = [regex]::Match($testOutputStr, 'Failed:\s*(\d+)')
            $failCount = if ($failMatch.Success) { $failMatch.Groups[1].Value } else { "unknown" }
            [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "0 failures" -Actual "$failCount failures"))
        } else {
            [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "0 failures" -Actual "no tests ran" -Message "Test runner produced no pass/fail output"))
        }
    } elseif ($testFiles.Count -eq 0) {
        [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "tests exist" -Actual "no test files"))
    } else {
        [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "build + tests" -Actual "build failed" -Message "Cannot run tests because build failed"))
    }

    # Assertion 4: no_errors in Claude stderr
    Write-Status "  Assertion: no_errors" -Type Info
    if (Test-Path $StderrLog) {
        $stderrContent = Get-Content $StderrLog -Raw -ErrorAction SilentlyContinue
        if ($stderrContent) {
            $errorLines = @(($stderrContent -split "`n") | Where-Object { $_ -match '\bERROR\b' })
            $errorCount = $errorLines.Count
            if ($errorCount -eq 0) {
                [void]$assertions.Add((New-Assertion -Name "no_errors" -Passed $true -Expected "0 ERROR lines" -Actual "0"))
            } else {
                $firstErr = [string]$errorLines[0]
                if ($firstErr.Length -gt 200) { $firstErr = $firstErr.Substring(0, 200) }
                [void]$assertions.Add((New-Assertion -Name "no_errors" -Passed $false -Expected "0 ERROR lines" -Actual "$errorCount errors" -Message $firstErr))
            }
        } else {
            [void]$assertions.Add((New-Assertion -Name "no_errors" -Passed $true -Expected "no stderr" -Actual "empty"))
        }
    } else {
        [void]$assertions.Add((New-Assertion -Name "no_errors" -Passed $true -Expected "no stderr log" -Actual "file missing"))
    }

    # Assertion 5: no_build_warnings
    Write-Status "  Assertion: no_build_warnings" -Type Info
    if ($buildPassed) {
        $buildOutputStr = $buildOutput -join "`n"
        $warningLines = @($buildOutput | Where-Object { $_ -match 'warning [A-Z]{2}\d{4}:' })
        $summaryMatch = [regex]::Match($buildOutputStr, '(\d+)\s+Warning\(s\)')
        $warningCount = if ($summaryMatch.Success) {
            [int]$summaryMatch.Groups[1].Value
        } else {
            $warningLines.Count
        }
        if ($warningCount -eq 0) {
            [void]$assertions.Add((New-Assertion -Name "no_build_warnings" -Passed $true -Expected "0 warnings" -Actual "0"))
        } else {
            $firstWarnings = ($warningLines | Select-Object -First 3 | ForEach-Object {
                if ($_.Length -gt 150) { $_.Substring(0, 150) } else { $_ }
            }) -join "; "
            [void]$assertions.Add((New-Assertion -Name "no_build_warnings" -Passed $false -Expected "0 warnings" -Actual "$warningCount build warnings detected" -Message $firstWarnings))
        }
    } else {
        [void]$assertions.Add((New-Assertion -Name "no_build_warnings" -Passed $false -Expected "0 warnings" -Actual "build failed" -Message "Cannot check warnings because build failed"))
    }

    # Assertion 6: no_debug_artifacts
    Write-Status "  Assertion: no_debug_artifacts" -Type Info
    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
    $debugMatches = [System.Collections.ArrayList]::new()
    foreach ($csFile in $csFiles) {
        $isTestFile = $csFile.Name -match 'Test'
        $lines = Get-Content $csFile.FullName -ErrorAction SilentlyContinue
        if (-not $lines) { continue }
        $relPath = $csFile.FullName.Replace($WorkDir, "").TrimStart('\', '/')
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            # TODO / HACK / FIXME
            if ($line -match '//\s*(TODO|HACK|FIXME)') {
                [void]$debugMatches.Add("${relPath}:${lineNum} $($Matches[0].Trim())")
            }
            # throw new NotImplementedException
            if ($line -match 'throw\s+new\s+NotImplementedException') {
                [void]$debugMatches.Add("${relPath}:${lineNum} NotImplementedException")
            }
            # Console.Write (except in test files)
            if (-not $isTestFile -and $line -match 'Console\.Write') {
                [void]$debugMatches.Add("${relPath}:${lineNum} Console.Write")
            }
            # #if DEBUG
            if ($line -match '^\s*#if\s+DEBUG') {
                [void]$debugMatches.Add("${relPath}:${lineNum} #if DEBUG")
            }
            # 3+ consecutive comment lines (commented-out code)
            if ($i + 2 -lt $lines.Count) {
                if ($line -match '^\s*//' -and $lines[$i+1] -match '^\s*//' -and $lines[$i+2] -match '^\s*//') {
                    # Only flag once per block
                    if ($i -eq 0 -or $lines[$i-1] -notmatch '^\s*//') {
                        [void]$debugMatches.Add("${relPath}:${lineNum} commented-out code block")
                    }
                }
            }
        }
    }
    if ($debugMatches.Count -eq 0) {
        [void]$assertions.Add((New-Assertion -Name "no_debug_artifacts" -Passed $true -Expected "0 debug artifacts" -Actual "0"))
    } else {
        $firstThree = ($debugMatches | Select-Object -First 3) -join "; "
        [void]$assertions.Add((New-Assertion -Name "no_debug_artifacts" -Passed $false -Expected "0 debug artifacts" -Actual "$($debugMatches.Count) matches found" -Message $firstThree))
    }

    # Assertion 7: no_unused_usings
    Write-Status "  Assertion: no_unused_usings" -Type Info
    if ($buildPassed) {
        Push-Location $WorkDir
        try {
            $formatOutput = & dotnet format analyzers --diagnostics IDE0005 --severity info --verify-no-changes 2>&1 | ForEach-Object { $_.ToString() }
            $formatExit = $LASTEXITCODE
        } catch {
            $formatOutput = @("dotnet format threw: $($_.Exception.Message)")
            $formatExit = -1
        }
        Pop-Location
        if ($null -eq $formatExit) { $formatExit = -1 }
        if ($formatExit -eq 0) {
            [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $true -Expected "0 unused usings" -Actual "0"))
        } elseif ($formatExit -eq -1 -or ($formatOutput -join "`n") -match 'error|could not|is not recognized') {
            [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $true -Expected "dotnet format available" -Actual "SKIPPED" -Message "dotnet format not available or failed unexpectedly"))
        } else {
            $formatMsg = ($formatOutput | Select-String "IDE0005" | Select-Object -First 3 | ForEach-Object { $_.ToString().Trim() }) -join "; "
            if (-not $formatMsg) { $formatMsg = "unused using directives detected" }
            [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $false -Expected "0 unused usings" -Actual "unused usings detected" -Message $formatMsg))
        }
    } else {
        [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $false -Expected "0 unused usings" -Actual "build failed" -Message "Cannot check unused usings because build failed"))
    }

    # Assertion 8: minimal_changes (scenario-aware file count threshold)
    Write-Status "  Assertion: minimal_changes" -Type Info
    $maxCsFilesThreshold = @{
        "investigate-and-implement" = 4
        "review-and-fix"           = 5
        "coverage-loop"            = 6
        "rule-adherence"           = 30
        "negative-constraints"     = 5
        "refactor-extract-service" = 7
        "cross-project-dependency" = 12
        "enterprise-cosmos-entity" = 30
        "trap-antipattern-resistance" = 30
        "replay"                     = 50
        "arch-drift"                 = 30
        "mutation-detection"         = 20
        "workflow-fidelity"          = 10
        "cross-repo-consistency"     = 0
    }
    $threshold = if ($maxCsFilesThreshold.ContainsKey($ScenarioName)) { $maxCsFilesThreshold[$ScenarioName] } else { 10 }
    $allCsFiles = @(Get-ChildItem -Path $WorkDir -Filter "*.cs" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
    $csFileCount = $allCsFiles.Count
    if ($csFileCount -le $threshold) {
        [void]$assertions.Add((New-Assertion -Name "minimal_changes" -Passed $true -Expected "max $threshold .cs files" -Actual "$csFileCount files"))
    } else {
        $extraFiles = ($allCsFiles | Select-Object -Skip $threshold | ForEach-Object {
            $_.FullName.Replace($WorkDir, "").TrimStart('\', '/')
        }) -join "; "
        [void]$assertions.Add((New-Assertion -Name "minimal_changes" -Passed $false -Expected "max $threshold .cs files" -Actual "Created $csFileCount .cs files, expected max $threshold" -Message $extraFiles))
    }

    # Assertion 9: test_quality_assertions
    Write-Status "  Assertion: test_quality_assertions" -Type Info
    $testCsFilesForQuality = @(Get-ChildItem -Path $WorkDir -Recurse -Include "*Test*.cs", "*Tests*.cs" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
    if ($testCsFilesForQuality.Count -gt 0) {
        $strongAssertionTypes = [System.Collections.Generic.HashSet[string]]::new()
        $degenerateTests = [System.Collections.ArrayList]::new()
        foreach ($tf in $testCsFilesForQuality) {
            $testContent = Get-Content $tf.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $testContent) { continue }
            # Collect strong assertion types (excluding Assert.NotNull as sole type)
            if ($testContent -match 'Assert\.Equal|Assert\.StrictEqual') { [void]$strongAssertionTypes.Add("Assert.Equal") }
            if ($testContent -match 'Assert\.Throws|Assert\.ThrowsAsync') { [void]$strongAssertionTypes.Add("Assert.Throws") }
            if ($testContent -match 'Assert\.Contains|Assert\.DoesNotContain') { [void]$strongAssertionTypes.Add("Assert.Contains") }
            if ($testContent -match 'Assert\.Empty|Assert\.NotEmpty') { [void]$strongAssertionTypes.Add("Assert.Empty") }
            if ($testContent -match 'Assert\.InRange') { [void]$strongAssertionTypes.Add("Assert.InRange") }
            if ($testContent -match '\.Should\(') { [void]$strongAssertionTypes.Add("FluentAssertions") }
            # Assert.True/False with non-trivial argument
            $trueMatches = [regex]::Matches($testContent, 'Assert\.True\(([^)]+)\)')
            foreach ($m in $trueMatches) {
                $arg = $m.Groups[1].Value.Trim()
                if ($arg -ne "true") { [void]$strongAssertionTypes.Add("Assert.True") }
            }
            $falseMatches = [regex]::Matches($testContent, 'Assert\.False\(([^)]+)\)')
            foreach ($m in $falseMatches) {
                $arg = $m.Groups[1].Value.Trim()
                if ($arg -ne "false") { [void]$strongAssertionTypes.Add("Assert.False") }
            }
            # Check for degenerate test methods: body contains ONLY Assert.True(true) or Assert.NotNull(result)
            $methodBodies = [regex]::Matches($testContent, '(?s)\[(Fact|Theory|Test|TestMethod)\][^\{]*\{(.*?)\n\s*\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            foreach ($mb in $methodBodies) {
                $body = $mb.Groups[2].Value.Trim()
                # Strip variable declarations/assignments to isolate assertion-only bodies
                $bodyLines = ($body -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne '{' -and $_ -ne '}' })
                $assertionOnlyLines = @($bodyLines | Where-Object { $_ -match 'Assert\.' -or $_ -match '\.Should\(' })
                if ($assertionOnlyLines.Count -eq $bodyLines.Count -and $assertionOnlyLines.Count -gt 0) {
                    $allDegenerate = $true
                    foreach ($al in $assertionOnlyLines) {
                        if ($al -notmatch 'Assert\.True\(\s*true\s*\)' -and $al -notmatch 'Assert\.NotNull\s*\(') {
                            $allDegenerate = $false
                            break
                        }
                    }
                    if ($allDegenerate) {
                        $relFile = $tf.FullName.Replace($WorkDir, "").TrimStart('\', '/')
                        [void]$degenerateTests.Add($relFile)
                    }
                }
            }
        }
        $distinctCount = $strongAssertionTypes.Count
        $typesList = ($strongAssertionTypes | Sort-Object) -join ", "
        if ($distinctCount -ge 2) {
            $msg = "$distinctCount types: $typesList"
            if ($degenerateTests.Count -gt 0) {
                $msg += "; WARNING: degenerate tests in: $(($degenerateTests | Select-Object -First 3) -join ', ')"
            }
            [void]$assertions.Add((New-Assertion -Name "test_quality_assertions" -Passed $true -Expected ">= 2 distinct strong assertion types" -Actual $msg))
        } else {
            $msg = "Only $distinctCount distinct assertion types found: $typesList"
            if ($degenerateTests.Count -gt 0) {
                $msg += "; degenerate tests in: $(($degenerateTests | Select-Object -First 3) -join ', ')"
            }
            [void]$assertions.Add((New-Assertion -Name "test_quality_assertions" -Passed $false -Expected ">= 2 distinct strong assertion types" -Actual $msg))
        }
    } else {
        [void]$assertions.Add((New-Assertion -Name "test_quality_assertions" -Passed $false -Expected ">= 2 distinct strong assertion types" -Actual "no test files found"))
    }

    # Collect files created/modified (all .cs files, excluding build artifacts)
    $filesCreated = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } |
        ForEach-Object { $_.FullName.Replace($WorkDir, "").TrimStart('\', '/') }
    if (-not $filesCreated) { $filesCreated = @() }

    return @{
        Assertions   = $assertions
        BuildPassed  = $buildPassed
        TestsPassed  = $testsPassed
        FilesCreated = @($filesCreated)
    }
}

function Run-ScenarioAssertions {
    param(
        [string]$ScenarioName,
        [string]$WorkDir
    )

    $assertions = [System.Collections.ArrayList]::new()

    switch ($ScenarioName) {
        "investigate-and-implement" {
            # Check floating-point division fix
            Write-Status "  Assertion: float_division_fix" -Type Info
            $calcFile = Join-Path $WorkDir "EvalProject/Calculator.cs"
            if (Test-Path $calcFile) {
                $calcContent = Get-Content $calcFile -Raw
                if ($calcContent -match '(double|1\.0|\(float\)|\.0)') {
                    [void]$assertions.Add((New-Assertion -Name "float_division_fix" -Passed $true -Expected "floating-point cast" -Actual "found"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "float_division_fix" -Passed $false -Expected "floating-point cast" -Actual "not found" -Message "Average method should use floating-point division"))
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "float_division_fix" -Passed $false -Expected "Calculator.cs exists" -Actual "file not found"))
            }

            # Check empty array guard
            Write-Status "  Assertion: empty_array_guard" -Type Info
            if (Test-Path $calcFile) {
                $calcContent = Get-Content $calcFile -Raw
                if ($calcContent -match '(Length\s*==\s*0|\.Any\(\)|IsNullOrEmpty|throw.*Argument|\.Length\s*<\s*1|[Cc]ount\s*==\s*0|is\s*(null\s*or)?\s*\{?\s*Length\s*:\s*0)') {
                    [void]$assertions.Add((New-Assertion -Name "empty_array_guard" -Passed $true -Expected "empty array check" -Actual "found"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "empty_array_guard" -Passed $false -Expected "empty array check" -Actual "not found"))
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "empty_array_guard" -Passed $false -Expected "Calculator.cs exists" -Actual "file not found"))
            }
        }

        "review-and-fix" {
            # Check SQL injection fixed
            Write-Status "  Assertion: sql_injection_fixed" -Type Info
            $controllerFile = Join-Path $WorkDir "EvalProject/Controllers/UsersController.cs"
            if (Test-Path $controllerFile) {
                $controllerContent = Get-Content $controllerFile -Raw
                if ($controllerContent -match '\$".*SELECT.*\{') {
                    [void]$assertions.Add((New-Assertion -Name "sql_injection_fixed" -Passed $false -Expected "no string interpolation in SQL" -Actual "still present"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "sql_injection_fixed" -Passed $true -Expected "no string interpolation in SQL" -Actual "fixed"))
                }
            } else {
                # File may have been moved or refactored - search for it
                $anyController = Get-ChildItem -Path $WorkDir -Recurse -Filter "UsersController.cs" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($anyController) {
                    $controllerContent = Get-Content $anyController.FullName -Raw
                    if ($controllerContent -match '\$".*SELECT.*\{') {
                        [void]$assertions.Add((New-Assertion -Name "sql_injection_fixed" -Passed $false -Expected "no string interpolation in SQL" -Actual "still present"))
                    } else {
                        [void]$assertions.Add((New-Assertion -Name "sql_injection_fixed" -Passed $true -Expected "no string interpolation in SQL" -Actual "fixed"))
                    }
                } else {
                    [void]$assertions.Add((New-Assertion -Name "sql_injection_fixed" -Passed $false -Expected "UsersController.cs exists" -Actual "file not found"))
                }
            }

            # Check parameterized query
            Write-Status "  Assertion: parameterized_query" -Type Info
            $searchFile = if (Test-Path $controllerFile) { $controllerFile } else {
                $found = Get-ChildItem -Path $WorkDir -Recurse -Filter "UsersController.cs" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $found.FullName } else { $null }
            }
            if ($searchFile -and (Test-Path $searchFile)) {
                $content = Get-Content $searchFile -Raw
                if ($content -match '@[Nn]ame|new\s*\{.*[Nn]ame') {
                    [void]$assertions.Add((New-Assertion -Name "parameterized_query" -Passed $true -Expected "parameterized query" -Actual "found"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "parameterized_query" -Passed $false -Expected "parameterized query" -Actual "not found"))
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "parameterized_query" -Passed $false -Expected "UsersController.cs exists" -Actual "file not found"))
            }
        }

        "coverage-loop" {
            # Check test method count
            Write-Status "  Assertion: sufficient_test_methods" -Type Info
            $testDir = Join-Path $WorkDir "EvalProject.Tests"
            $testCount = 0
            if (Test-Path $testDir) {
                $testCsFiles = Get-ChildItem -Path $testDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $testCsFiles) {
                    $content = Get-Content $f.FullName -Raw
                    $testCount += ([regex]::Matches($content, '\[(Fact|Theory|Test|TestMethod)\]')).Count
                }
            }
            if ($testCount -ge 5) {
                [void]$assertions.Add((New-Assertion -Name "sufficient_test_methods" -Passed $true -Expected ">= 5 test methods" -Actual "$testCount methods"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "sufficient_test_methods" -Passed $false -Expected ">= 5 test methods" -Actual "$testCount methods"))
            }

            # Check exception tests present
            Write-Status "  Assertion: exception_tests_present" -Type Info
            $exceptionPatterns = 0
            if (Test-Path $testDir) {
                $testCsFiles = Get-ChildItem -Path $testDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $testCsFiles) {
                    $content = Get-Content $f.FullName -Raw
                    $exceptionPatterns += ([regex]::Matches($content, 'ArgumentNullException|ValidationException|InvalidOperationException|NotFoundException')).Count
                }
            }
            if ($exceptionPatterns -ge 3) {
                [void]$assertions.Add((New-Assertion -Name "exception_tests_present" -Passed $true -Expected ">= 3 exception types" -Actual "$exceptionPatterns found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "exception_tests_present" -Passed $false -Expected ">= 3 exception types" -Actual "$exceptionPatterns found"))
            }
        }

        "rule-adherence" {
            # Delegate to Eval01-RuleAdherence module (18 assertions)
            $moduleAssertions = Invoke-RuleAdherenceScorecardAssertions -WorkDir $WorkDir
            foreach ($a in $moduleAssertions) {
                [void]$assertions.Add($a)
            }
        }

        "negative-constraints" {
            # Check: no XML doc comments in new files
            Write-Status "  Assertion: no_xml_docs" -Type Info
            $newCsFiles = Get-ChildItem -Path (Join-Path $WorkDir "EvalProject") -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' -and $_.Name -ne "UserService.cs" }
            $xmlDocFound = $false
            $xmlDocFile = ""
            foreach ($f in $newCsFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match '///\s*<') {
                    $xmlDocFound = $true
                    $xmlDocFile = $f.Name
                    break
                }
            }
            if (-not $xmlDocFound) {
                [void]$assertions.Add((New-Assertion -Name "no_xml_docs" -Passed $true -Expected "no /// comments" -Actual "none found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "no_xml_docs" -Passed $false -Expected "no /// comments" -Actual "found in $xmlDocFile" -Message "CLAUDE.md forbids XML documentation comments"))
            }

            # Check: no Helper or Utility classes
            Write-Status "  Assertion: no_helper_utility_classes" -Type Info
            $helperFiles = Get-ChildItem -Path (Join-Path $WorkDir "EvalProject") -Recurse -Include "*Helper*.cs", "*Utility*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
            if ($helperFiles.Count -eq 0) {
                [void]$assertions.Add((New-Assertion -Name "no_helper_utility_classes" -Passed $true -Expected "no Helper/Utility files" -Actual "none found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "no_helper_utility_classes" -Passed $false -Expected "no Helper/Utility files" -Actual "$($helperFiles[0].Name)" -Message "CLAUDE.md forbids Helper/Utility classes"))
            }

            # Check: no try/catch in new service files (test files exempt)
            Write-Status "  Assertion: no_try_catch_blocks" -Type Info
            $serviceCsFiles = Get-ChildItem -Path (Join-Path $WorkDir "EvalProject") -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' -and $_.Name -ne "UserService.cs" }
            $tryCatchFound = $false
            $tryCatchFile = ""
            foreach ($f in $serviceCsFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match '\btry\s*\{') {
                    $tryCatchFound = $true
                    $tryCatchFile = $f.Name
                    break
                }
            }
            if (-not $tryCatchFound) {
                [void]$assertions.Add((New-Assertion -Name "no_try_catch_blocks" -Passed $true -Expected "no try/catch" -Actual "none found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "no_try_catch_blocks" -Passed $false -Expected "no try/catch" -Actual "found in $tryCatchFile" -Message "CLAUDE.md forbids try/catch in service code"))
            }

            # Check: existing UserService.cs was not modified
            Write-Status "  Assertion: existing_files_unchanged" -Type Info
            $baselinePath = Join-Path $WorkDir ".eval-baseline/UserService.cs"
            $currentPath = Join-Path $WorkDir "EvalProject/UserService.cs"
            if ((Test-Path $baselinePath) -and (Test-Path $currentPath)) {
                $baselineContent = Get-Content $baselinePath -Raw
                $currentContent = Get-Content $currentPath -Raw
                if ($baselineContent -eq $currentContent) {
                    [void]$assertions.Add((New-Assertion -Name "existing_files_unchanged" -Passed $true -Expected "UserService.cs unchanged" -Actual "content match"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "existing_files_unchanged" -Passed $false -Expected "UserService.cs unchanged" -Actual "file was modified" -Message "CLAUDE.md forbids modifying existing files"))
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "existing_files_unchanged" -Passed $false -Expected "both files exist" -Actual "missing" -Message "Baseline or current UserService.cs not found"))
            }

            # Check: validation was actually added (a validator file exists)
            Write-Status "  Assertion: validation_added" -Type Info
            $validatorFiles = Get-ChildItem -Path (Join-Path $WorkDir "EvalProject") -Recurse -Include "*Validat*.cs", "*validat*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
            if ($validatorFiles.Count -gt 0) {
                [void]$assertions.Add((New-Assertion -Name "validation_added" -Passed $true -Expected "validator class" -Actual $validatorFiles[0].Name))
            } else {
                # Also check if validation logic exists in any new file
                $anyValidation = $false
                foreach ($f in $newCsFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'ArgumentException|throw.*new.*Argument') { $anyValidation = $true; break }
                }
                if ($anyValidation) {
                    [void]$assertions.Add((New-Assertion -Name "validation_added" -Passed $true -Expected "validation logic" -Actual "found in new files"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "validation_added" -Passed $false -Expected "validator class" -Actual "not found" -Message "No validation code was created"))
                }
            }
        }

        "refactor-extract-service" {
            # Check: IPricingService interface file exists
            Write-Status "  Assertion: interface_exists" -Type Info
            $interfaceFile = Get-ChildItem -Path $WorkDir -Recurse -Filter "IPricingService.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } | Select-Object -First 1
            if ($interfaceFile) {
                [void]$assertions.Add((New-Assertion -Name "interface_exists" -Passed $true -Expected "IPricingService.cs" -Actual $interfaceFile.Name))
            } else {
                # Also check if the interface is defined inside another file
                $anyInterface = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } |
                    Where-Object { (Get-Content $_.FullName -Raw) -match 'interface\s+IPricingService' } | Select-Object -First 1
                if ($anyInterface) {
                    [void]$assertions.Add((New-Assertion -Name "interface_exists" -Passed $true -Expected "IPricingService interface" -Actual "defined in $($anyInterface.Name)"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "interface_exists" -Passed $false -Expected "IPricingService.cs" -Actual "not found"))
                }
            }

            # Check: PricingService implementation file exists
            Write-Status "  Assertion: implementation_exists" -Type Info
            $implFile = Get-ChildItem -Path $WorkDir -Recurse -Filter "PricingService.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } | Select-Object -First 1
            if ($implFile) {
                [void]$assertions.Add((New-Assertion -Name "implementation_exists" -Passed $true -Expected "PricingService.cs" -Actual $implFile.Name))
            } else {
                # Check if PricingService class is defined in another file
                $anyImpl = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } |
                    Where-Object { (Get-Content $_.FullName -Raw) -match 'class\s+PricingService' } | Select-Object -First 1
                if ($anyImpl) {
                    [void]$assertions.Add((New-Assertion -Name "implementation_exists" -Passed $true -Expected "PricingService class" -Actual "defined in $($anyImpl.Name)"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "implementation_exists" -Passed $false -Expected "PricingService.cs" -Actual "not found"))
                }
            }

            # Check: ProductController uses IPricingService
            Write-Status "  Assertion: controller_uses_interface" -Type Info
            $controllerFile = Get-ChildItem -Path $WorkDir -Recurse -Filter "ProductController.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } | Select-Object -First 1
            if ($controllerFile) {
                $controllerContent = Get-Content $controllerFile.FullName -Raw
                if ($controllerContent -match 'IPricingService') {
                    [void]$assertions.Add((New-Assertion -Name "controller_uses_interface" -Passed $true -Expected "IPricingService in ProductController" -Actual "found"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "controller_uses_interface" -Passed $false -Expected "IPricingService in ProductController" -Actual "not found" -Message "ProductController should depend on IPricingService via constructor injection"))
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "controller_uses_interface" -Passed $false -Expected "ProductController.cs exists" -Actual "file not found"))
            }

            # Check: no inline pricing logic in ProductController
            Write-Status "  Assertion: no_inline_pricing" -Type Info
            if ($controllerFile) {
                $controllerContent = Get-Content $controllerFile.FullName -Raw
                if ($controllerContent -match '0\.20m|0\.15m|0\.10m|quantity\s*>=\s*100|quantity\s*>=\s*50|quantity\s*>=\s*10') {
                    [void]$assertions.Add((New-Assertion -Name "no_inline_pricing" -Passed $false -Expected "no discount logic in controller" -Actual "inline pricing logic still present" -Message "Pricing logic should be extracted to PricingService"))
                } else {
                    [void]$assertions.Add((New-Assertion -Name "no_inline_pricing" -Passed $true -Expected "no discount logic in controller" -Actual "extracted"))
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "no_inline_pricing" -Passed $false -Expected "ProductController.cs exists" -Actual "file not found"))
            }

            # Check: DI registration exists
            Write-Status "  Assertion: di_registration" -Type Info
            $diFound = $false
            $csFiles = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
            foreach ($f in $csFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match 'Add(Scoped|Transient|Singleton)<IPricingService') {
                    $diFound = $true
                    break
                }
            }
            if ($diFound) {
                [void]$assertions.Add((New-Assertion -Name "di_registration" -Passed $true -Expected "AddScoped/Transient/Singleton<IPricingService>" -Actual "found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "di_registration" -Passed $false -Expected "AddScoped/Transient/Singleton<IPricingService>" -Actual "not found" -Message "IPricingService must be registered in DI container"))
            }
        }

        "cross-project-dependency" {
            # Check: ISmsNotificationService interface exists in NotificationLib
            Write-Status "  Assertion: sms_interface_exists" -Type Info
            $smsIfaceFound = $false
            $libDir = Join-Path $WorkDir "NotificationLib"
            if (Test-Path $libDir) {
                $libCsFiles = Get-ChildItem -Path $libDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $libCsFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'interface\s+ISmsNotificationService') {
                        $smsIfaceFound = $true
                        break
                    }
                }
            }
            if ($smsIfaceFound) {
                [void]$assertions.Add((New-Assertion -Name "sms_interface_exists" -Passed $true -Expected "ISmsNotificationService in NotificationLib" -Actual "found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "sms_interface_exists" -Passed $false -Expected "ISmsNotificationService in NotificationLib" -Actual "not found"))
            }

            # Check: SmsNotificationService implementation exists in NotificationLib
            Write-Status "  Assertion: sms_implementation_exists" -Type Info
            $smsImplFound = $false
            if (Test-Path $libDir) {
                $libCsFiles = Get-ChildItem -Path $libDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $libCsFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'class\s+SmsNotificationService') {
                        $smsImplFound = $true
                        break
                    }
                }
            }
            if ($smsImplFound) {
                [void]$assertions.Add((New-Assertion -Name "sms_implementation_exists" -Passed $true -Expected "SmsNotificationService in NotificationLib" -Actual "found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "sms_implementation_exists" -Passed $false -Expected "SmsNotificationService in NotificationLib" -Actual "not found"))
            }

            # Check: ISmsNotificationService registered in DI
            Write-Status "  Assertion: sms_di_registered" -Type Info
            $smsDiFound = $false
            $csFiles = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
            foreach ($f in $csFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match 'Add(Scoped|Transient|Singleton)<ISmsNotificationService') {
                    $smsDiFound = $true
                    break
                }
            }
            if ($smsDiFound) {
                [void]$assertions.Add((New-Assertion -Name "sms_di_registered" -Passed $true -Expected "ISmsNotificationService in DI" -Actual "found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "sms_di_registered" -Passed $false -Expected "ISmsNotificationService in DI" -Actual "not found" -Message "ISmsNotificationService must be registered in DI container"))
            }

            # Check: SMS endpoint exists (route for notifications/sms)
            Write-Status "  Assertion: sms_endpoint_exists" -Type Info
            $smsEndpointFound = $false
            foreach ($f in $csFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match 'notifications/sms|notifications\\sms|NotificationsSms|"sms"' -or
                    ($content -match 'HttpPost' -and $content -match 'ISmsNotificationService|SmsNotificationService')) {
                    $smsEndpointFound = $true
                    break
                }
            }
            if ($smsEndpointFound) {
                [void]$assertions.Add((New-Assertion -Name "sms_endpoint_exists" -Passed $true -Expected "POST /api/notifications/sms endpoint" -Actual "found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "sms_endpoint_exists" -Passed $false -Expected "POST /api/notifications/sms endpoint" -Actual "not found"))
            }

            # Check: Tests reference SmsNotificationService or ISmsNotificationService
            Write-Status "  Assertion: sms_tests_exist" -Type Info
            $smsTestsFound = $false
            $testDir = Join-Path $WorkDir "NotificationApi.Tests"
            if (Test-Path $testDir) {
                $testCsFiles = Get-ChildItem -Path $testDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $testCsFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'SmsNotificationService|ISmsNotificationService') {
                        $smsTestsFound = $true
                        break
                    }
                }
            }
            if ($smsTestsFound) {
                [void]$assertions.Add((New-Assertion -Name "sms_tests_exist" -Passed $true -Expected "tests for SMS service" -Actual "found"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "sms_tests_exist" -Passed $false -Expected "tests for SMS service" -Actual "not found"))
            }
        }

        "enterprise-cosmos-entity" {
            # Helper: get all .cs files excluding bin/obj
            $allCsFiles = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }

            # A1: handler_not_service
            Write-Status "  Assertion: handler_not_service" -Type Info
            $handlerFound = $false
            $serviceFound = $false
            $blHandlersDir = Join-Path $WorkDir "BusinessLogic/Handlers"
            if (Test-Path $blHandlersDir) {
                $handlerFiles = Get-ChildItem -Path $blHandlersDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $handlerFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'class\s+AttachmentHandler') { $handlerFound = $true }
                }
            }
            foreach ($f in $allCsFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match 'class\s+AttachmentService') { $serviceFound = $true; break }
            }
            $a1Passed = $handlerFound -and (-not $serviceFound)
            $a1Actual = if ($handlerFound -and -not $serviceFound) { "AttachmentHandler found, no AttachmentService" } elseif (-not $handlerFound) { "AttachmentHandler not found in BusinessLogic/Handlers" } else { "AttachmentService found (should be Handler)" }
            [void]$assertions.Add((New-Assertion -Name "handler_not_service" -Passed $a1Passed -Expected "AttachmentHandler in BusinessLogic/Handlers, no AttachmentService" -Actual $a1Actual))

            # A2: interface_in_common
            Write-Status "  Assertion: interface_in_common" -Type Info
            $ifaceInCommon = $false
            $ifaceInDataAccess = $false
            $commonIfacesDir = Join-Path $WorkDir "Common/Interfaces"
            if (Test-Path $commonIfacesDir) {
                $commonFiles = Get-ChildItem -Path $commonIfacesDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $commonFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'interface\s+IAttachmentRepository') { $ifaceInCommon = $true; break }
                }
            }
            $daDir = Join-Path $WorkDir "DataAccess"
            if (Test-Path $daDir) {
                $daFiles = Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $daFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'interface\s+IAttachmentRepository') { $ifaceInDataAccess = $true; break }
                }
            }
            $a2Passed = $ifaceInCommon -and (-not $ifaceInDataAccess)
            $a2Actual = if ($ifaceInCommon -and -not $ifaceInDataAccess) { "IAttachmentRepository in Common/Interfaces" } elseif (-not $ifaceInCommon) { "IAttachmentRepository not found in Common/Interfaces" } else { "IAttachmentRepository defined in DataAccess (wrong location)" }
            [void]$assertions.Add((New-Assertion -Name "interface_in_common" -Passed $a2Passed -Expected "IAttachmentRepository in Common/Interfaces, not in DataAccess" -Actual $a2Actual))

            # A3: cosmos_entity_inheritance
            Write-Status "  Assertion: cosmos_entity_inheritance" -Type Info
            $cosmosInherit = $false
            $modelsDir = Join-Path $WorkDir "Common/Models"
            if (Test-Path $modelsDir) {
                $modelFiles = Get-ChildItem -Path $modelsDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $modelFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'class\s+AttachmentEntity\s*:\s*CosmosEntity') { $cosmosInherit = $true; break }
                }
            }
            $a3Actual = if ($cosmosInherit) { "AttachmentEntity : CosmosEntity found" } else { "AttachmentEntity not inheriting CosmosEntity in Common/Models" }
            [void]$assertions.Add((New-Assertion -Name "cosmos_entity_inheritance" -Passed $cosmosInherit -Expected "class AttachmentEntity : CosmosEntity in Common/Models" -Actual $a3Actual))

            # A4: paged_result_return
            Write-Status "  Assertion: paged_result_return" -Type Info
            $pagedFound = $false
            $listFound = $false
            if (Test-Path $daDir) {
                $daFiles = Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $daFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'PagedResult<Attachment') { $pagedFound = $true }
                    $codeLines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match 'Task<List<Attachment' -or $codeOnly -match 'Task<IEnumerable<Attachment') { $listFound = $true }
                }
            }
            $a4Passed = $pagedFound -and (-not $listFound)
            $a4Actual = if ($pagedFound -and -not $listFound) { "PagedResult used, no raw List/IEnumerable returns" } elseif (-not $pagedFound) { "PagedResult<Attachment not found in DataAccess" } else { "Raw List/IEnumerable return found instead of PagedResult" }
            [void]$assertions.Add((New-Assertion -Name "paged_result_return" -Passed $a4Passed -Expected "PagedResult<Attachment in DataAccess, no Task<List<Attachment" -Actual $a4Actual))

            # A5: document_type_constant
            Write-Status "  Assertion: document_type_constant" -Type Info
            $docTypeUsed = $false
            $magicString = $false
            if (Test-Path $daDir) {
                $daFiles = Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $daFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'DocumentTypes\.Attachment') { $docTypeUsed = $true }
                    $codeLines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match '"attachment"') { $magicString = $true }
                }
            }
            $a5Passed = $docTypeUsed -and (-not $magicString)
            $a5Actual = if ($docTypeUsed -and -not $magicString) { "DocumentTypes.Attachment used, no magic strings" } elseif (-not $docTypeUsed) { "DocumentTypes.Attachment not found in DataAccess" } else { "Magic string 'attachment' found in DataAccess" }
            [void]$assertions.Add((New-Assertion -Name "document_type_constant" -Passed $a5Passed -Expected "DocumentTypes.Attachment in DataAccess, no magic string" -Actual $a5Actual))

            # A6: logger_message_generator
            Write-Status "  Assertion: logger_message_generator" -Type Info
            $loggerMsgAttr = $false
            $stringInterp = $false
            $blDir = Join-Path $WorkDir "BusinessLogic"
            if (Test-Path $blDir) {
                $blFiles = Get-ChildItem -Path $blDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                # Check LogMessages files first for [LoggerMessage] with attachment references
                $logMsgFiles = Get-ChildItem -Path $blDir -Recurse -Include "*LogMessages*.cs", "*LogMessage*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $logMsgFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match '\[LoggerMessage' -and $content -imatch '[Aa]ttach') { $loggerMsgAttr = $true; break }
                }
                # Also check any .cs file in BusinessLogic for [LoggerMessage] mentioning attachment
                if (-not $loggerMsgAttr) {
                    foreach ($f in $blFiles) {
                        $content = Get-Content $f.FullName -Raw
                        if ($content -match '\[LoggerMessage' -and $content -imatch '[Aa]ttach') { $loggerMsgAttr = $true; break }
                    }
                }
                # Check for string interpolation logging (anti-pattern)
                foreach ($f in $blFiles) {
                    $content = Get-Content $f.FullName -Raw
                    $codeLines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match 'Log(Information|Warning|Error)\(\$"') { $stringInterp = $true; break }
                }
            }
            $a6Passed = $loggerMsgAttr -and (-not $stringInterp)
            $a6Actual = if ($loggerMsgAttr -and -not $stringInterp) { "[LoggerMessage] used, no string interpolation logging" } elseif (-not $loggerMsgAttr) { "[LoggerMessage] for attachment not found in BusinessLogic" } else { "String interpolation logging found in BusinessLogic" }
            [void]$assertions.Add((New-Assertion -Name "logger_message_generator" -Passed $a6Passed -Expected "[LoggerMessage] for attachment ops, no interpolated logging" -Actual $a6Actual))

            # A7: no_controller_trycatch
            Write-Status "  Assertion: no_controller_trycatch" -Type Info
            $tryCatchFound = $false
            $controllerDir = Join-Path $WorkDir "API/Controllers"
            if (Test-Path $controllerDir) {
                $controllerFiles = Get-ChildItem -Path $controllerDir -Recurse -Include "*Attachment*Controller*.cs", "*Attachments*Controller*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $controllerFiles) {
                    $content = Get-Content $f.FullName -Raw
                    $codeLines = $content -split "`n" | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match 'catch\s*\(') { $tryCatchFound = $true; break }
                }
            }
            $a7Passed = -not $tryCatchFound
            $a7Actual = if (-not $tryCatchFound) { "No try-catch in AttachmentsController" } else { "try-catch found in AttachmentsController (should delegate to middleware)" }
            [void]$assertions.Add((New-Assertion -Name "no_controller_trycatch" -Passed $a7Passed -Expected "No catch blocks in AttachmentsController" -Actual $a7Actual))

            # A8: namespace_matches_path
            Write-Status "  Assertion: namespace_matches_path" -Type Info
            $nsMatchCount = 0
            $nsMismatchCount = 0
            $nsMismatches = @()
            foreach ($f in $allCsFiles) {
                # Only check files Claude added (attachment-related)
                $relativePath = $f.FullName.Replace($WorkDir, '').TrimStart('\', '/')
                if ($relativePath -imatch 'Attachment|attachment') {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'namespace\s+([\w.]+)') {
                        $ns = $Matches[1]
                        # Extract expected namespace from path: Common/Models/AttachmentEntity.cs -> Common.Models
                        $pathParts = $relativePath -replace '[\\/]', '.'
                        $expectedNs = ($pathParts -replace '\.[^.]+$', '') # Remove filename
                        if ($ns -eq $expectedNs) {
                            $nsMatchCount++
                        } else {
                            $nsMismatchCount++
                            $nsMismatches += "$relativePath (got: $ns, expected: $expectedNs)"
                        }
                    }
                }
            }
            $a8Passed = $nsMismatchCount -eq 0 -and $nsMatchCount -gt 0
            $a8Actual = if ($a8Passed) { "$nsMatchCount files with correct namespaces" } elseif ($nsMatchCount -eq 0) { "No attachment .cs files found" } else { "$nsMismatchCount mismatches: $($nsMismatches -join '; ')" }
            [void]$assertions.Add((New-Assertion -Name "namespace_matches_path" -Passed $a8Passed -Expected "All new .cs file namespaces match folder paths" -Actual $a8Actual))
        }

        "trap-antipattern-resistance" {
            # Helper: get all .cs files excluding bin/obj
            $allCsFiles = Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }

            # A1: handler_not_service - Agent should name it AttachmentHandler, not AttachmentService
            Write-Status "  Assertion: handler_not_service" -Type Info
            $handlerFound = $false
            $serviceFound = $false
            foreach ($f in $allCsFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match 'class\s+AttachmentHandler') { $handlerFound = $true }
                if ($content -match 'class\s+AttachmentService') { $serviceFound = $true }
            }
            $a1Passed = $handlerFound -and (-not $serviceFound)
            $a1Actual = if ($handlerFound -and -not $serviceFound) { "AttachmentHandler found, no AttachmentService" } elseif (-not $handlerFound -and -not $serviceFound) { "Neither AttachmentHandler nor AttachmentService found" } elseif (-not $handlerFound) { "AttachmentService found but no AttachmentHandler (copied antipattern)" } else { "Both AttachmentHandler and AttachmentService found" }
            [void]$assertions.Add((New-Assertion -Name "handler_not_service" -Passed $a1Passed -Expected "class AttachmentHandler, no class AttachmentService" -Actual $a1Actual))

            # A2: interface_in_common - IAttachmentRepository should be in Common/Interfaces, NOT in DataAccess
            Write-Status "  Assertion: interface_in_common" -Type Info
            $ifaceInCommon = $false
            $ifaceInDataAccess = $false
            $commonIfacesDir = Join-Path $WorkDir "Common/Interfaces"
            if (Test-Path $commonIfacesDir) {
                $commonFiles = Get-ChildItem -Path $commonIfacesDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $commonFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'interface\s+IAttachmentRepository') { $ifaceInCommon = $true; break }
                }
            }
            $daDir = Join-Path $WorkDir "DataAccess"
            if (Test-Path $daDir) {
                $daFiles = Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $daFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'interface\s+IAttachmentRepository') { $ifaceInDataAccess = $true; break }
                }
            }
            $a2Passed = $ifaceInCommon -and (-not $ifaceInDataAccess)
            $a2Actual = if ($ifaceInCommon -and -not $ifaceInDataAccess) { "IAttachmentRepository in Common/Interfaces only" } elseif (-not $ifaceInCommon -and $ifaceInDataAccess) { "IAttachmentRepository in DataAccess (copied antipattern)" } elseif (-not $ifaceInCommon) { "IAttachmentRepository not found in Common/Interfaces" } else { "IAttachmentRepository in both Common and DataAccess" }
            [void]$assertions.Add((New-Assertion -Name "interface_in_common" -Passed $a2Passed -Expected "IAttachmentRepository in Common/Interfaces, not in DataAccess" -Actual $a2Actual))

            # A3: paged_result_return - Should use PagedResult<>, not Task<List<>> or Task<IEnumerable<>>
            Write-Status "  Assertion: paged_result_return" -Type Info
            $pagedFound = $false
            $listFound = $false
            $daDir = Join-Path $WorkDir "DataAccess"
            if (Test-Path $daDir) {
                $daFiles = Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $daFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'PagedResult<Attachment') { $pagedFound = $true }
                    $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match 'Task<List<Attachment' -or $codeOnly -match 'Task<IEnumerable<Attachment') { $listFound = $true }
                }
            }
            $a3Passed = $pagedFound -and (-not $listFound)
            $a3Actual = if ($pagedFound -and -not $listFound) { "PagedResult used, no raw List/IEnumerable returns" } elseif (-not $pagedFound) { "PagedResult<Attachment not found in DataAccess" } else { "Raw List/IEnumerable return found (copied antipattern)" }
            [void]$assertions.Add((New-Assertion -Name "paged_result_return" -Passed $a3Passed -Expected "PagedResult<Attachment in DataAccess, no Task<List<Attachment" -Actual $a3Actual))

            # A4: document_type_constant - Should use DocumentTypes.Attachment, not magic string "attachment"
            Write-Status "  Assertion: document_type_constant" -Type Info
            $docTypeUsed = $false
            $magicString = $false
            if (Test-Path $daDir) {
                $daFiles = Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $daFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match 'DocumentTypes\.Attachment') { $docTypeUsed = $true }
                    $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match '"attachment"') { $magicString = $true }
                }
            }
            $a4Passed = $docTypeUsed -and (-not $magicString)
            $a4Actual = if ($docTypeUsed -and -not $magicString) { "DocumentTypes.Attachment used, no magic strings" } elseif (-not $docTypeUsed) { "DocumentTypes.Attachment not found in DataAccess" } else { "Magic string 'attachment' found in DataAccess (copied antipattern)" }
            [void]$assertions.Add((New-Assertion -Name "document_type_constant" -Passed $a4Passed -Expected "DocumentTypes.Attachment in DataAccess, no magic string" -Actual $a4Actual))

            # A5: logger_message_generator - Should use [LoggerMessage] source gen, not string interpolation
            Write-Status "  Assertion: logger_message_generator" -Type Info
            $loggerMsgAttr = $false
            $stringInterp = $false
            $blDir = Join-Path $WorkDir "BusinessLogic"
            if (Test-Path $blDir) {
                $blFiles = Get-ChildItem -Path $blDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                # Check LogMessages files first for [LoggerMessage] with attachment references
                $logMsgFiles = Get-ChildItem -Path $blDir -Recurse -Include "*LogMessages*.cs", "*LogMessage*.cs" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }
                foreach ($f in $logMsgFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -match '\[LoggerMessage' -and $content -imatch '[Aa]ttach') { $loggerMsgAttr = $true; break }
                }
                # Also check any .cs file in BusinessLogic for [LoggerMessage] mentioning attachment
                if (-not $loggerMsgAttr) {
                    foreach ($f in $blFiles) {
                        $content = Get-Content $f.FullName -Raw
                        if ($content -match '\[LoggerMessage' -and $content -imatch '[Aa]ttach') { $loggerMsgAttr = $true; break }
                    }
                }
                # Check for string interpolation logging (anti-pattern) in new attachment code
                foreach ($f in $blFiles) {
                    $content = Get-Content $f.FullName -Raw
                    if ($content -imatch '[Aa]ttach') {
                        $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
                        $codeOnly = $codeLines -join "`n"
                        if ($codeOnly -match 'Log(Information|Warning|Error)\(\$"') { $stringInterp = $true; break }
                    }
                }
            }
            $a5Passed = $loggerMsgAttr -and (-not $stringInterp)
            $a5Actual = if ($loggerMsgAttr -and -not $stringInterp) { "[LoggerMessage] used for attachment ops, no string interpolation" } elseif (-not $loggerMsgAttr) { "[LoggerMessage] for attachment ops not found in BusinessLogic" } else { "String interpolation logging found for attachment ops (copied antipattern)" }
            [void]$assertions.Add((New-Assertion -Name "logger_message_generator" -Passed $a5Passed -Expected "[LoggerMessage] for attachment ops, no interpolated logging" -Actual $a5Actual))

            # A6: no_controller_trycatch - No try-catch in AttachmentsController
            Write-Status "  Assertion: no_controller_trycatch" -Type Info
            $tryCatchFound = $false
            $controllerDir = Join-Path $WorkDir "API/Controllers"
            if (Test-Path $controllerDir) {
                $controllerFiles = Get-ChildItem -Path $controllerDir -Recurse -Include "*Attachment*Controller*.cs", "*Attachments*Controller*.cs" -File -ErrorAction SilentlyContinue
                foreach ($f in $controllerFiles) {
                    $content = Get-Content $f.FullName -Raw
                    $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
                    $codeOnly = $codeLines -join "`n"
                    if ($codeOnly -match 'catch\s*\(') { $tryCatchFound = $true; break }
                }
            }
            $a6Passed = -not $tryCatchFound
            $a6Actual = if (-not $tryCatchFound) { "No try-catch in AttachmentsController" } else { "try-catch found in AttachmentsController (copied antipattern)" }
            [void]$assertions.Add((New-Assertion -Name "no_controller_trycatch" -Passed $a6Passed -Expected "No catch blocks in AttachmentsController" -Actual $a6Actual))

            # A7: interface_not_collocated - IAttachmentRepository not in same dir as AttachmentRepository
            Write-Status "  Assertion: interface_not_collocated" -Type Info
            $ifaceDir = $null
            $implDir = $null
            foreach ($f in $allCsFiles) {
                $content = Get-Content $f.FullName -Raw
                if ($content -match 'interface\s+IAttachmentRepository') { $ifaceDir = $f.DirectoryName }
                if ($content -match 'class\s+AttachmentRepository') { $implDir = $f.DirectoryName }
            }
            $a7Passed = $false
            $a7Actual = "Neither IAttachmentRepository nor AttachmentRepository found"
            if ($ifaceDir -and $implDir) {
                if ($ifaceDir -ne $implDir) {
                    $a7Passed = $true
                    $a7Actual = "Interface and implementation in different directories"
                } else {
                    $a7Actual = "Interface collocated with implementation in same directory (copied antipattern)"
                }
            } elseif ($ifaceDir -and -not $implDir) {
                $a7Actual = "IAttachmentRepository found but no AttachmentRepository implementation"
            } elseif (-not $ifaceDir -and $implDir) {
                $a7Actual = "AttachmentRepository found but no IAttachmentRepository interface"
            }
            [void]$assertions.Add((New-Assertion -Name "interface_not_collocated" -Passed $a7Passed -Expected "IAttachmentRepository not in same directory as AttachmentRepository" -Actual $a7Actual))
        }

        "replay" {
            # Delegate to Eval02-Replay module
            $replayAssertions = Invoke-ReplayAssertions -WorkDir $WorkDir
            foreach ($a in $replayAssertions) {
                [void]$assertions.Add($a)
            }
        }

        "context-stress" {
            # Delegate to Eval03-ContextStress module
            if (Get-Command -Name 'Invoke-ContextStressAssertions' -ErrorAction SilentlyContinue) {
                $stressAssertions = Invoke-ContextStressAssertions -WorkDir $WorkDir
                foreach ($a in $stressAssertions) {
                    [void]$assertions.Add($a)
                }
            } else {
                $eval03Module = Join-Path $PSScriptRoot "..\tests\shared\evals\Eval03-ContextStress.psm1"
                if (Test-Path $eval03Module) {
                    Import-Module $eval03Module -Force -DisableNameChecking
                    $stressAssertions = Invoke-ContextStressAssertions -WorkDir $WorkDir
                    foreach ($a in $stressAssertions) {
                        [void]$assertions.Add($a)
                    }
                } else {
                    [void]$assertions.Add((New-Assertion -Name "context_stress_module" -Passed $false `
                        -Expected "Eval03-ContextStress.psm1" -Actual "not found" `
                        -Message "Module not found at $eval03Module"))
                }
            }
        }

        "arch-drift" {
            $archAssertions = Invoke-ArchDriftAssertions -WorkDir $WorkDir
            foreach ($a in $archAssertions) { [void]$assertions.Add($a) }
        }

        "mutation-detection" {
            # Delegate to Eval05-Mutation module assertions
            Write-Status "  Loading Eval05-Mutation module for assertions..." -Type Info
            $modulePath = Join-Path $ScriptRoot "..\tests\shared\evals\Eval05-Mutation.psm1"
            if (Test-Path $modulePath) {
                Import-Module $modulePath -Force -ErrorAction Stop

                # Read agent output for keyword-based diagnosis scoring
                $agentOutput = ''
                $claudeOutputPath = Join-Path (Split-Path $WorkDir -Parent) "claude-output-mutation-detection.txt"
                if (Test-Path $claudeOutputPath) {
                    $agentOutput = Get-Content -Path $claudeOutputPath -Raw -ErrorAction SilentlyContinue
                }

                $mutationAssertions = Invoke-MutationAssertions -WorkDir $WorkDir -AgentOutput $agentOutput
                foreach ($ma in $mutationAssertions) {
                    [void]$assertions.Add($ma)
                }
            } else {
                [void]$assertions.Add((New-Assertion -Name "mutation_module_load" -Passed $false -Expected "Eval05-Mutation.psm1 exists" -Actual "Not found at $modulePath"))
            }
        }

        "workflow-fidelity" {
            # Delegate to Eval06-Workflow module for transcript-based compliance checking
            $wfAssertions = Invoke-WorkflowAssertions -WorkDir $WorkDir
            foreach ($a in $wfAssertions) { [void]$assertions.Add($a) }
        }

        "cross-repo-consistency" {
            # Delegate to Eval07-CrossRepo module
            Write-Status "  Running cross-repo consistency assertions..." -Type Info
            $crossRepoAssertions = Invoke-CrossRepoAssertions -WorkDir $WorkDir
            foreach ($a in $crossRepoAssertions) {
                [void]$assertions.Add($a)
            }
        }
    }

    return $assertions
}

# ---------------------------------------------------------------------------
# Behavioral correctness verification (hidden test injection)
# ---------------------------------------------------------------------------

function Run-BehavioralVerification {
    param(
        [string]$ScenarioName,
        [string]$WorkDir
    )

    $assertions = [System.Collections.ArrayList]::new()

    # Scenarios that have verification tests
    $verificationTests = @{
        "investigate-and-implement" = @{
            FileName  = "VerifyFix.cs"
            TestDir   = "EvalProject.Tests"
            Filter    = "FullyQualifiedName~VerifyFix"
            Content   = @'
using System;
using Xunit;

public class VerifyFix
{
    [Fact]
    public void Average_ShouldReturnDecimalResult()
    {
        var calc = new Calculator();
        var result = calc.Average(new[] { 2, 3 });
        Assert.Equal(2.5, result, precision: 1);
    }

    [Fact]
    public void Average_EmptyArray_ShouldThrow()
    {
        var calc = new Calculator();
        Assert.ThrowsAny<Exception>(() => calc.Average(Array.Empty<int>()));
    }
}
'@
        }
        "refactor-extract-service" = @{
            FileName  = "VerifyRefactor.cs"
            TestDir   = "EvalProject.Tests"
            Filter    = "FullyQualifiedName~VerifyRefactor"
            Content   = @'
using System;
using System.Linq;
using System.Reflection;
using Xunit;

public class VerifyRefactor
{
    [Theory]
    [InlineData(1, 29.99)]
    [InlineData(10, 269.91)]
    [InlineData(50, 1274.575)]
    [InlineData(100, 2399.20)]
    public void PricingService_MustPreserveBehavior(int qty, decimal expected)
    {
        // Find PricingService type via reflection
        var pricingType = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(a => { try { return a.GetTypes(); } catch { return Array.Empty<Type>(); } })
            .FirstOrDefault(t => t.Name == "PricingService" && !t.IsInterface);

        Assert.NotNull(pricingType);

        var instance = Activator.CreateInstance(pricingType);
        Assert.NotNull(instance);

        // Find a method that calculates price (CalculatePrice, GetPrice, ComputePrice, Calculate)
        var method = pricingType.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(m =>
                m.Name.Contains("Price", StringComparison.OrdinalIgnoreCase) ||
                m.Name.Contains("Calculate", StringComparison.OrdinalIgnoreCase) ||
                m.Name.Contains("Compute", StringComparison.OrdinalIgnoreCase));

        Assert.NotNull(method);

        // Determine parameter types and invoke
        var parameters = method.GetParameters();
        object result;
        if (parameters.Length == 2)
        {
            // Likely (int productId, int quantity) or (decimal basePrice, int quantity)
            var p0Type = parameters[0].ParameterType;
            var p1Type = parameters[1].ParameterType;
            object arg0 = p0Type == typeof(decimal) ? (object)(decimal)29.99m : (object)1;
            object arg1 = p1Type == typeof(decimal) ? (object)(decimal)qty : (object)qty;
            result = method.Invoke(instance, new[] { arg0, arg1 });
        }
        else if (parameters.Length == 1)
        {
            result = method.Invoke(instance, new object[] { qty });
        }
        else
        {
            // Try with productId=1, quantity=qty, basePrice=29.99m as applicable
            var args = new object[parameters.Length];
            for (int i = 0; i < parameters.Length; i++)
            {
                if (parameters[i].ParameterType == typeof(int))
                    args[i] = parameters[i].Name.Contains("qty", StringComparison.OrdinalIgnoreCase) ||
                              parameters[i].Name.Contains("quantity", StringComparison.OrdinalIgnoreCase)
                        ? qty : 1;
                else if (parameters[i].ParameterType == typeof(decimal))
                    args[i] = 29.99m;
                else
                    args[i] = Activator.CreateInstance(parameters[i].ParameterType);
            }
            result = method.Invoke(instance, args);
        }

        Assert.NotNull(result);
        var decimalResult = Convert.ToDecimal(result);
        Assert.Equal(expected, decimalResult);
    }

    [Fact]
    public void ProductController_MustUseDI()
    {
        var controllerType = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(a => { try { return a.GetTypes(); } catch { return Array.Empty<Type>(); } })
            .FirstOrDefault(t => t.Name == "ProductController");

        Assert.NotNull(controllerType);

        var ctorParams = controllerType.GetConstructors()[0].GetParameters();
        Assert.Contains(ctorParams, p => p.ParameterType.Name == "IPricingService");
    }
}
'@
        }
        "enterprise-cosmos-entity" = @{
            FileName  = "VerifyEnterprisePatterns.cs"
            TestDir   = "EvalSolution.Tests"
            Filter    = "FullyQualifiedName~VerifyEnterprisePatterns"
            Content   = @'
using Common.Constants;
using Common.Models;
using Xunit;

public class VerifyEnterprisePatterns
{
    [Fact]
    public void DocumentTypes_HasAttachmentConstant()
    {
        var field = typeof(DocumentTypes).GetField("Attachment");
        Assert.NotNull(field);
        var value = field!.GetValue(null) as string;
        Assert.False(string.IsNullOrEmpty(value), "DocumentTypes.Attachment should not be empty");
    }
}
'@
        }
    }

    # Scenarios that should be skipped
    $skippedScenarios = @("review-and-fix", "coverage-loop", "rule-adherence", "negative-constraints", "cross-project-dependency", "workflow-fidelity", "cross-repo-consistency")

    if ($ScenarioName -in $skippedScenarios) {
        Write-Status "  Assertion: behavioral_correctness (SKIPPED)" -Type Info
        [void]$assertions.Add((New-Assertion -Name "behavioral_correctness" -Passed $true `
            -Expected "verification test" -Actual "SKIPPED" `
            -Message "No verification test for $ScenarioName scenario"))
        return $assertions
    }

    if (-not $verificationTests.ContainsKey($ScenarioName)) {
        Write-Status "  Assertion: behavioral_correctness (SKIPPED)" -Type Info
        [void]$assertions.Add((New-Assertion -Name "behavioral_correctness" -Passed $true `
            -Expected "verification test" -Actual "SKIPPED" `
            -Message "No verification test for $ScenarioName scenario"))
        return $assertions
    }

    $testSpec = $verificationTests[$ScenarioName]
    $testFilePath = Join-Path $WorkDir (Join-Path $testSpec.TestDir $testSpec.FileName)
    $testDirPath = Join-Path $WorkDir $testSpec.TestDir

    Write-Status "  Assertion: behavioral_correctness" -Type Info

    # Guard: test directory must exist
    if (-not (Test-Path $testDirPath)) {
        [void]$assertions.Add((New-Assertion -Name "behavioral_correctness" -Passed $false `
            -Expected "test project exists" -Actual "$($testSpec.TestDir) not found" `
            -Message "Cannot inject verification test -- test project directory missing"))
        return $assertions
    }

    try {
        # Inject the verification test file
        Set-Content -Path $testFilePath -Value $testSpec.Content -Encoding UTF8

        # Run only the verification tests
        Push-Location $WorkDir
        try {
            $testOutput = & dotnet test --nologo -v q --filter $testSpec.Filter 2>&1 | Out-String
            $testExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        if ($testExit -eq 0 -and $testOutput -match 'Passed') {
            [void]$assertions.Add((New-Assertion -Name "behavioral_correctness" -Passed $true `
                -Expected "verification tests pass" -Actual "all passed"))
        } else {
            # Extract failure info
            $failInfo = ($testOutput -split "`n" | Where-Object { $_ -match 'Failed|Error|Assert' } | Select-Object -First 3) -join "; "
            if (-not $failInfo) { $failInfo = "dotnet test exit code $testExit" }
            # Truncate
            if ($failInfo.Length -gt 300) { $failInfo = $failInfo.Substring(0, 300) }
            [void]$assertions.Add((New-Assertion -Name "behavioral_correctness" -Passed $false `
                -Expected "verification tests pass" -Actual "tests failed" `
                -Message $failInfo))
        }
    } catch {
        [void]$assertions.Add((New-Assertion -Name "behavioral_correctness" -Passed $false `
            -Expected "verification tests pass" -Actual "exception" `
            -Message "Verification test injection failed: $($_.Exception.Message)"))
    } finally {
        # Clean up the injected file
        if (Test-Path $testFilePath) {
            Remove-Item $testFilePath -Force -ErrorAction SilentlyContinue
        }
    }

    return $assertions
}

# ---------------------------------------------------------------------------
# Token parsing from Claude JSON output
# ---------------------------------------------------------------------------

function Parse-ClaudeTokens {
    param([string]$OutputFile)

    $tokens = [ordered]@{
        input_tokens          = 0
        output_tokens         = 0
        total_tokens          = 0
        cache_read_tokens     = 0
        cache_creation_tokens = 0
        cost_usd              = [double]0
        num_turns             = 0
        duration_ms           = 0
        duration_api_ms       = 0
        stop_reason           = ""
        session_id            = ""
        model_breakdown       = @{}
    }

    if (-not (Test-Path $OutputFile)) { return $tokens }

    try {
        $content = Get-Content $OutputFile -Raw -ErrorAction Stop
        if (-not $content) { return $tokens }

        # Claude --print --output-format json outputs either:
        #   1. A JSON array: [{...}, {...}, ...]  (Claude Code 2.x)
        #   2. Newline-delimited JSON (NDJSON): {...}\n{...}\n  (older versions)
        # Try JSON array first, then fall back to NDJSON line-by-line parsing.
        $objects = @()
        $trimmed = $content.Trim()
        if ($trimmed.StartsWith('[')) {
            try {
                $objects = $trimmed | ConvertFrom-Json -ErrorAction Stop
            } catch {
                # JSON array parse failed, fall through to NDJSON
            }
        }
        if ($objects.Count -eq 0) {
            # NDJSON fallback: parse each line individually
            foreach ($line in ($content -split "`n" | Where-Object { $_.Trim() })) {
                try {
                    $objects += ($line | ConvertFrom-Json -ErrorAction Stop)
                } catch { }
            }
        }

        foreach ($obj in $objects) {
            try {

                # Check for usage at top level
                if ($obj.usage) {
                    if ($obj.usage.input_tokens) { $tokens.input_tokens += [int]$obj.usage.input_tokens }
                    if ($obj.usage.output_tokens) { $tokens.output_tokens += [int]$obj.usage.output_tokens }
                    if ($obj.usage.cache_read_input_tokens) { $tokens.cache_read_tokens += [int]$obj.usage.cache_read_input_tokens }
                    if ($obj.usage.cache_creation_input_tokens) { $tokens.cache_creation_tokens += [int]$obj.usage.cache_creation_input_tokens }
                }

                # Check result.usage
                if ($obj.result -and $obj.result.usage) {
                    if ($obj.result.usage.input_tokens) { $tokens.input_tokens += [int]$obj.result.usage.input_tokens }
                    if ($obj.result.usage.output_tokens) { $tokens.output_tokens += [int]$obj.result.usage.output_tokens }
                }

                # Extract cost from top-level total_cost_usd or nested
                if ($obj.total_cost_usd) { $tokens.cost_usd += [double]$obj.total_cost_usd }
                elseif ($obj.cost_usd) { $tokens.cost_usd += [double]$obj.cost_usd }
                if ($obj.result -and $obj.result.total_cost_usd) { $tokens.cost_usd += [double]$obj.result.total_cost_usd }

                # Extract num_turns (take the last/highest value found)
                if ($obj.num_turns) {
                    $val = [int]$obj.num_turns
                    if ($val -gt $tokens.num_turns) { $tokens.num_turns = $val }
                }
                if ($obj.result -and $obj.result.num_turns) {
                    $val = [int]$obj.result.num_turns
                    if ($val -gt $tokens.num_turns) { $tokens.num_turns = $val }
                }

                # Extract duration, stop reason, and session ID
                if ($obj.duration_ms) { $tokens.duration_ms = [int]$obj.duration_ms }
                if ($obj.duration_api_ms) { $tokens.duration_api_ms = [int]$obj.duration_api_ms }
                if ($obj.subtype) { $tokens.stop_reason = [string]$obj.subtype }
                if ($obj.session_id) { $tokens.session_id = [string]$obj.session_id }

                # Parse per-model breakdown from modelUsage
                if ($obj.modelUsage) {
                    foreach ($prop in $obj.modelUsage.PSObject.Properties) {
                        $modelName = $prop.Name
                        $modelData = $prop.Value
                        $tokens.model_breakdown[$modelName] = @{
                            input_tokens           = [int]($modelData.inputTokens)
                            output_tokens          = [int]($modelData.outputTokens)
                            cache_read_tokens      = [int]($modelData.cacheReadInputTokens)
                            cache_creation_tokens  = [int]($modelData.cacheCreationInputTokens)
                            cost_usd               = [double]($modelData.costUSD)
                        }
                    }
                }
            } catch {
                # Not valid JSON line - skip
            }
        }

        $tokens.total_tokens = $tokens.input_tokens + $tokens.output_tokens
    } catch {
        # Failed to read - return zeros
    }

    return $tokens
}

# ---------------------------------------------------------------------------
# LLM-as-Judge evaluation
# ---------------------------------------------------------------------------

function Run-LlmJudge {
    param(
        [Parameter(Mandatory)][string]$ScenarioName,
        [Parameter(Mandatory)][string]$WorkDir  # scenario working directory with .cs files
    )

    # 1. Find rubric file
    $rubricPath = Join-Path $ScriptRoot "..\tests\rubrics\$ScenarioName.md"
    if (-not (Test-Path $rubricPath)) {
        Write-Status "  No rubric found for $ScenarioName, skipping judge" -Type Warning
        return $null
    }

    # 2. Collect created .cs files (limit to first 5, max 200 lines each to control cost)
    $csFiles = Get-ChildItem -Path $WorkDir -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' } |
        Select-Object -First 5
    $codeContent = ""
    foreach ($f in $csFiles) {
        $lines = Get-Content $f.FullName -TotalCount 200 -ErrorAction SilentlyContinue
        $codeContent += "--- $($f.Name) ---`n$($lines -join "`n")`n`n"
    }

    if (-not $codeContent) {
        Write-Status "  No .cs files found for judge, skipping" -Type Warning
        return $null
    }

    # 3. Build prompt: rubric + code
    $rubric = Get-Content $rubricPath -Raw
    $prompt = @"
$rubric

## Source Code to Evaluate

$codeContent

## Your Response

Return ONLY a JSON object with the structure specified in the rubric above. No markdown, no explanation outside the JSON.
"@

    # 4. Invoke claude CLI with Haiku
    $promptFile = Join-Path $WorkDir ".judge-prompt.txt"
    Set-Content -Path $promptFile -Value $prompt -Encoding UTF8

    $judgeOutput = ""
    try {
        # Temporarily unset CLAUDECODE to allow nested CLI invocation from within Claude Code sessions
        $savedClaudeCode = $env:CLAUDECODE
        $env:CLAUDECODE = $null
        try {
            $judgeOutput = & claude --print --max-turns 1 --output-format json --model claude-haiku-4-5-20251001 -p (Get-Content $promptFile -Raw) 2>&1
        } finally {
            $env:CLAUDECODE = $savedClaudeCode
        }
    } catch {
        Write-Status "  Judge CLI invocation failed: $($_.Exception.Message)" -Type Warning
        return $null
    }

    # 5. Parse response - extract the JSON result
    # claude --print --output-format json returns NDJSON; find the result line
    $resultJson = $null
    $judgeCost = [double]0
    $judgeInputTokens = 0
    $judgeOutputTokens = 0

    foreach ($line in ($judgeOutput -split "`n")) {
        $line = $line.Trim()
        if (-not $line) { continue }
        try {
            $obj = $line | ConvertFrom-Json -ErrorAction Stop
            if ($obj.result) {
                # The actual text response is in result
                $resultText = $null
                if ($obj.result -is [string]) { $resultText = $obj.result }
                elseif ($obj.result.text) { $resultText = $obj.result.text }
                elseif ($obj.result.content) { $resultText = $obj.result.content }
                if ($resultText) {
                    # Strip markdown code fences if present
                    $resultText = $resultText -replace '(?s)^```json\s*', '' -replace '(?s)\s*```$', ''
                    try { $resultJson = $resultText | ConvertFrom-Json -ErrorAction Stop } catch {}
                }
            }
            # Accumulate cost/tokens
            if ($obj.usage) {
                if ($obj.usage.input_tokens) { $judgeInputTokens += [int]$obj.usage.input_tokens }
                if ($obj.usage.output_tokens) { $judgeOutputTokens += [int]$obj.usage.output_tokens }
            }
            if ($obj.cost_usd) { $judgeCost += [double]$obj.cost_usd }
            elseif ($obj.total_cost_usd) { $judgeCost += [double]$obj.total_cost_usd }
        } catch { }
    }

    # 6. Build return object
    if (-not $resultJson -or $null -eq $resultJson.score) {
        Write-Status "  Judge returned invalid response, skipping" -Type Warning
        return $null
    }

    $criteriaScores = @()
    if ($resultJson.criteria_scores) {
        $criteriaScores = @($resultJson.criteria_scores | ForEach-Object {
            [ordered]@{
                criterion   = [string]$_.criterion
                score       = [int]$_.score
                explanation = [string]($_.explanation)
            }
        })
    }

    $maxScore = 3
    if ($resultJson.max_score) { $maxScore = [int]$resultJson.max_score }

    return [ordered]@{
        model           = "claude-haiku-4-5-20251001"
        score           = [int]$resultJson.score
        max_score       = $maxScore
        rationale       = [string]($resultJson.rationale)
        criteria_scores = $criteriaScores
        cost_usd        = [Math]::Round($judgeCost, 6)
        tokens          = [ordered]@{
            input_tokens  = $judgeInputTokens
            output_tokens = $judgeOutputTokens
        }
    }
}

# ---------------------------------------------------------------------------
# Run a single scenario
# ---------------------------------------------------------------------------

function Run-SingleScenario {
    param(
        [string]$ScenarioName,
        [int]$MaxTurns,
        [int]$TimeoutMinutes,
        [int]$TimeoutSeconds = 600,
        [decimal]$CostLimit = 3.0,
        [switch]$DebugMode
    )

    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor White
    Write-Status "Scenario: $ScenarioName" -Type Info
    Write-Host "----------------------------------------" -ForegroundColor White

    $timestamp = (Get-Date).ToString("yyyyMMddHHmmss")

    # Determine base temp directory
    if ($ProjectRoot) {
        # Create inside project tree so Claude CLI finds .claude/ config
        $baseTempDir = [System.IO.Path]::Combine($ProjectRoot, ".mad", "scratch", "eval-$EvalRunId")
        if (-not (Test-Path $baseTempDir)) {
            New-Item -ItemType Directory -Path $baseTempDir -Force | Out-Null
        }
        $workDir = Join-Path $baseTempDir $ScenarioName
    } else {
        # Baseline runs must use a temp root with no .claude/ ancestor.
        # $env:TEMP is under $env:USERPROFILE which often has ~/.claude/ rules,
        # so we use C:\Temp (or create it) to avoid config drift detection.
        $cleanTemp = 'C:\Temp'
        if (-not (Test-Path $cleanTemp)) { New-Item -ItemType Directory -Path $cleanTemp -Force | Out-Null }
        $workDir = Join-Path $cleanTemp "eval-$ScenarioName-$timestamp"
    }

    $stderrLog = Join-Path $env:TEMP "claude-stderr-$ScenarioName-$timestamp.log"
    $claudeOutput = Join-Path $env:TEMP "claude-output-$ScenarioName-$timestamp.json"

    $startUtc = Get-UtcTimestamp
    $startTicks = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    $status = "passed"
    $errorMessage = $null

    # Setup project
    Write-Status "  Setting up project..." -Type Info
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null

    # Override parent .editorconfig to prevent CHARSET conflicts with scaffold encoding
    # PowerShell 5.1 Set-Content -Encoding UTF8 writes BOM; parent .editorconfig may enforce no-BOM
    Set-Content -Path (Join-Path $workDir ".editorconfig") -Value @"
root = true

[*]
charset = utf-8-bom
"@ -Encoding UTF8

    try {
        switch ($ScenarioName) {
            "investigate-and-implement" { Setup-InvestigateAndImplement -WorkDir $workDir }
            "review-and-fix" { Setup-ReviewAndFix -WorkDir $workDir }
            "coverage-loop" { Setup-CoverageLoop -WorkDir $workDir }
            "rule-adherence" { Setup-RuleAdherenceScorecard -WorkDir $workDir }
            "negative-constraints" { Setup-NegativeConstraints -WorkDir $workDir }
            "refactor-extract-service" { Setup-RefactorExtractService -WorkDir $workDir }
            "cross-project-dependency" { Setup-CrossProjectDependency -WorkDir $workDir }
            "enterprise-cosmos-entity" { Setup-EnterpriseCosmosEntity -WorkDir $workDir }
            "trap-antipattern-resistance" { Setup-TrapAntipatternResistance -WorkDir $workDir }
            "replay" { Setup-Replay -WorkDir $workDir }
            "context-stress" {
                $eval03Module = Join-Path $PSScriptRoot "..\tests\shared\evals\Eval03-ContextStress.psm1"
                if (Test-Path $eval03Module) {
                    Import-Module $eval03Module -Force -DisableNameChecking
                    Setup-ContextStress -WorkDir $workDir
                } else {
                    throw "Eval03-ContextStress.psm1 not found at $eval03Module"
                }
            }
            "arch-drift" { Setup-ArchDrift -WorkDir $workDir }
            "mutation-detection" { Setup-MutationDetection -WorkDir $workDir }
            "workflow-fidelity" { Setup-Workflow -WorkDir $workDir }
            "cross-repo-consistency" { Setup-CrossRepo -WorkDir $workDir }
        }

        # For treatment runs, copy CLAUDE.md into workspace if not already present.
        # This ensures the agent has explicit project instructions, not just ancestor-discovered config.
        # Scenarios like rule-adherence and negative-constraints create their own CLAUDE.md — skip those.
        if ($ProjectRoot -and -not (Test-Path (Join-Path $workDir "CLAUDE.md"))) {
            $srcClaudeMd = Join-Path $ProjectRoot "CLAUDE.md"
            if (Test-Path $srcClaudeMd) {
                Copy-Item $srcClaudeMd (Join-Path $workDir "CLAUDE.md") -Force
                Write-Status "    Copied CLAUDE.md into workspace" -Type Info
            }
        }

        Write-Status "  Project setup complete" -Type Success
    } catch {
        $status = "error"
        $errorMessage = "Project setup failed: $($_.Exception.Message)"
        Write-Status "  $errorMessage" -Type Error
    }

    $tokensData = [ordered]@{
        input_tokens = 0; output_tokens = 0; total_tokens = 0
        cache_read_tokens = 0; cache_creation_tokens = 0
        cost_usd = [double]0; num_turns = 0; model_breakdown = @{}
    }
    $claudeRawOutput = ""
    $assertionResults = [System.Collections.ArrayList]::new()
    $buildPassed = $false
    $testsPassed = $false
    $filesCreated = @()
    $circuitBreakerFired = $false

    # Initialize operational metadata
    $rulesHash = $null
    $workspaceChecksum = $null

    # Define static scenarios early -- used by config drift, pre-flight, and assertion guards
    $StaticScenarios = @("cross-repo-consistency")

    # T005: Config drift detection
    # Claude CLI walks up ancestor directories to find .claude/ config.
    # For treatment runs where workspace is under $ProjectRoot, check both
    # the workspace itself AND ancestor directories up to $ProjectRoot.
    # For baseline runs (no ProjectRoot), ONLY check the workspace itself
    # (no ancestor walk - user's home dir may have .claude/).
    # Static analysis scenarios skip config drift (no Claude CLI invocation).
    if ($status -ne "error" -and $ScenarioName -notin $StaticScenarios) {
        $isBaseline = -not $ProjectRoot
        $claudeDir = $null

        if ($isBaseline) {
            # BASELINE: Only check workspace dir itself (no ancestor walk)
            $candidate = Join-Path $workDir ".claude"
            if (Test-Path $candidate) { $claudeDir = $candidate }

            # Also walk ancestor directories from $workDir to filesystem root.
            # Claude CLI walks up the directory tree to discover .claude/ config,
            # so if $env:TEMP happens to be under a directory with .claude/ or
            # CLAUDE.md, the baseline run would be contaminated by project rules.
            if (-not $claudeDir) {
                $ancestorDir = Split-Path $workDir -Parent
                while ($ancestorDir) {
                    $candidateClaude = Join-Path $ancestorDir ".claude"
                    $candidateClaudeMd = Join-Path $ancestorDir "CLAUDE.md"
                    if (Test-Path $candidateClaude) {
                        $claudeDir = $candidateClaude
                        $errorMessage = "Configuration drift detected: ancestor directory $ancestorDir contains .claude/ rules"
                        break
                    }
                    if (Test-Path $candidateClaudeMd) {
                        $claudeDir = $candidateClaudeMd
                        $errorMessage = "Configuration drift detected: ancestor directory $ancestorDir contains CLAUDE.md"
                        break
                    }
                    $nextParent = Split-Path $ancestorDir -Parent
                    if (-not $nextParent -or $nextParent -eq $ancestorDir) { break }
                    $ancestorDir = $nextParent
                }
            }
        } else {
            # TREATMENT: Walk ancestor directories up to $ProjectRoot
            $searchDir = $workDir
            while ($searchDir) {
                $candidate = Join-Path $searchDir ".claude"
                if (Test-Path $candidate) {
                    $claudeDir = $candidate
                    break
                }
                $parent = Split-Path $searchDir -Parent
                if (-not $parent -or $parent -eq $searchDir) { break }
                if ($searchDir -eq $ProjectRoot) { break }
                $searchDir = $parent
            }
        }

        if ($isBaseline) {
            # BASELINE: .claude/ or CLAUDE.md must NOT exist in workspace or any ancestor
            if ($claudeDir) {
                $status = "error"
                if (-not $errorMessage) {
                    $errorMessage = "Configuration drift detected: baseline workspace contains .claude/ rules"
                }
                Write-Status "  $errorMessage" -Type Error
            }
        } else {
            # TREATMENT: .claude/ MUST exist (in workspace or ancestor)
            if (-not $claudeDir) {
                $status = "error"
                $errorMessage = "Configuration drift detected: treatment workspace missing .claude/ rules"
                Write-Status "  $errorMessage" -Type Error
            } else {
                if ($claudeDir -ne (Join-Path $workDir ".claude")) {
                    Write-Status "  Using .claude/ from ancestor: $claudeDir" -Type Info
                }
                # Compute rules hash for treatment runs
                $rulesDir = Join-Path $claudeDir "rules"
                if (Test-Path $rulesDir) {
                    $rulesHash = Get-DirectoryHash -Path $rulesDir
                    if ($rulesHash) {
                        Write-Status "  Rules hash: $($rulesHash.Substring(0, 12))..." -Type Info
                    }
                }
            }
        }

        # Compute workspace checksum (scaffold .cs files)
        if ($status -ne "error") {
            $workspaceChecksum = Get-WorkspaceChecksum -WorkDir $workDir
            if ($workspaceChecksum) {
                Write-Status "  Workspace checksum: $($workspaceChecksum.Substring(0, 12))..." -Type Info
            }
        }
    }

    # Pre-flight: verify scaffold compiles before invoking agent
    # Skip for static analysis scenarios (no .NET project to build)
    if ($status -ne "error" -and $ScenarioName -notin $StaticScenarios) {
        Write-Status "  Pre-flight: verifying scaffold builds..." -Type Info
        # Determine build directory: use workDir if it contains a .sln/.csproj,
        # otherwise check one level of subdirectories (e.g., context-stress puts project in EvalProject/)
        $buildDir = $workDir
        $topProjects = @(Get-ChildItem -Path $workDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.sln', '.slnx', '.csproj' })
        if ($topProjects.Count -eq 0) {
            $subProjects = @(Get-ChildItem -Path $workDir -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue } |
                Where-Object { $_.Extension -in '.sln', '.slnx', '.csproj' } |
                Select-Object -First 1)
            if ($subProjects.Count -gt 0) {
                $buildDir = Split-Path $subProjects[0].FullName -Parent
                Write-Status "  Build target found in subdirectory: $buildDir" -Type Info
            }
        }
        Push-Location $buildDir
        try {
            $prefBuildOutput = & dotnet build --no-restore 2>&1 | ForEach-Object { $_.ToString() }
            if ($LASTEXITCODE -ne 0) {
                Write-Status "  SCAFFOLD BUILD FAILED - skipping agent invocation" -Type Error
                $status = "error"
                $errorMessage = "scaffold_build_failed"
                $prefBuildStr = ($prefBuildOutput | Out-String)
                $prefBuildMsg = $prefBuildStr.Substring(0, [Math]::Min(500, $prefBuildStr.Length))
                [void]$assertionResults.Add((New-Assertion -Name "scaffold_build" -Passed $false -Expected "scaffold compiles" -Actual "build failed" -Message $prefBuildMsg))
            } else {
                Write-Status "  Scaffold builds successfully" -Type Success
            }
        } catch {
            Write-Status "  Pre-flight build threw: $($_.Exception.Message)" -Type Warning
            # Treat workspace warnings during pre-flight as non-fatal; only exit code matters
        } finally {
            Pop-Location
        }
    } elseif ($ScenarioName -in $StaticScenarios) {
        Write-Status "  Static analysis scenario - skipping scaffold build" -Type Info
    }

    if ($status -ne "error") {
        # Build prompt (even for static scenarios, we capture it for reference)
        $prompt = Get-ScenarioPrompt -ScenarioName $ScenarioName -WorkDir $workDir

        # Skip Claude CLI invocation for static analysis scenarios
        if ($ScenarioName -in $StaticScenarios) {
            Write-Status "  Static analysis scenario - skipping Claude CLI invocation" -Type Info
        } else {
            # Run Claude CLI with timeout
            Write-Status "  Running Claude CLI (timeout: ${TimeoutSeconds}s, max-turns: $MaxTurns, cost-limit: `$$CostLimit)..." -Type Info

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "claude"
        $psi.Arguments = "--print --max-turns $MaxTurns --output-format json --dangerously-skip-permissions -p `"$($prompt -replace '"', '\"')`""
        $psi.WorkingDirectory = $workDir
        $psi.UseShellExecute = $false
        # Clear all Claude env vars to avoid nested session detection
        $claudeVars = @($psi.EnvironmentVariables.Keys | Where-Object { $_ -like "CLAUDE*" })
        foreach ($cv in $claudeVars) { $psi.EnvironmentVariables.Remove($cv) | Out-Null }
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        # Set EVAL_HEADLESS environment variable if -Headless flag is present
        if ($Headless) {
            $psi.EnvironmentVariables["EVAL_HEADLESS"] = "1"
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi

        # Capture output asynchronously to avoid deadlocks
        $stdoutBuilder = New-Object System.Text.StringBuilder
        $stderrBuilder = New-Object System.Text.StringBuilder

        $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
            if ($null -ne $Event.SourceEventArgs.Data) {
                [void]$Event.MessageData.AppendLine($Event.SourceEventArgs.Data)
            }
        } -MessageData $stdoutBuilder

        $stderrEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
            if ($null -ne $Event.SourceEventArgs.Data) {
                [void]$Event.MessageData.AppendLine($Event.SourceEventArgs.Data)
            }
        } -MessageData $stderrBuilder

        try {
            [void]$process.Start()
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()

            $timeoutMs = $TimeoutSeconds * 1000
            $exited = $process.WaitForExit($timeoutMs)

            if (-not $exited) {
                Write-Status "  Scenario timed out after ${TimeoutSeconds}s -- killing process" -Type Warning
                try { $process.Kill() } catch { }
                $status = "timeout"
                $errorMessage = "Timed out after ${TimeoutSeconds} seconds"
            } else {
                # Give events time to flush
                $process.WaitForExit()
                $claudeExit = $process.ExitCode
                if ($claudeExit -ne 0) {
                    Write-Status "  Claude CLI exited with code $claudeExit" -Type Warning
                    # Do not mark as error -- assertions determine pass/fail
                }
            }
        } finally {
            Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
            Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
            Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
            Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
            $process.Dispose()
        }

        # Write captured output to files
        $stdoutStr = $stdoutBuilder.ToString()
        $stderrStr = $stderrBuilder.ToString()

        if ($stdoutStr) {
            Set-Content -Path $claudeOutput -Value $stdoutStr -Encoding UTF8
        }
        if ($stderrStr) {
            Set-Content -Path $stderrLog -Value $stderrStr -Encoding UTF8
        }

        # Parse tokens
        $tokensData = Parse-ClaudeTokens -OutputFile $claudeOutput

        # Truncate raw output to 10KB for storage
        if ($stdoutStr.Length -gt 10240) {
            $claudeRawOutput = $stdoutStr.Substring(0, 10240)
        } else {
            $claudeRawOutput = $stdoutStr
        }

        # T003: Cost circuit breaker
        $scenarioCost = $tokensData.cost_usd
        if ($null -eq $scenarioCost -or $scenarioCost -eq 0) {
            Write-Status "  Cost data unavailable from Claude CLI output -- skipping circuit breaker" -Type Warning
        } elseif ([double]$scenarioCost -gt [double]$CostLimit) {
            Write-Status "  CIRCUIT BREAKER: cost `$$([Math]::Round($scenarioCost, 4)) exceeds limit `$$CostLimit -- skipping assertions" -Type Warning
            $circuitBreakerFired = $true
            $status = "circuit_breaker"
            $errorMessage = "Cost circuit breaker fired: `$$([Math]::Round($scenarioCost, 4)) > `$$CostLimit limit"
        }
        } # End of else block (non-static scenarios)

        # Run assertions (skipped if circuit breaker fired)
        if (-not $circuitBreakerFired) {
        Write-Status "  Running assertions..." -Type Info

        # Skip standard build/test assertions for static analysis scenarios
        if ($ScenarioName -notin $StaticScenarios) {
            $standardResults = Run-StandardAssertions -ScenarioName $ScenarioName -WorkDir $workDir -StderrLog $stderrLog
            foreach ($a in $standardResults.Assertions) { [void]$assertionResults.Add($a) }
            $buildPassed = $standardResults.BuildPassed
            $testsPassed = $standardResults.TestsPassed
            $filesCreated = $standardResults.FilesCreated
        } else {
            # For static scenarios, initialize with defaults (no build/test required)
            $buildPassed = $true
            $testsPassed = $true
            $filesCreated = @()
        }

        try {
            $scenarioAssertions = Run-ScenarioAssertions -ScenarioName $ScenarioName -WorkDir $workDir
            foreach ($a in $scenarioAssertions) { [void]$assertionResults.Add($a) }
        } catch {
            Write-Status "  Scenario assertions crashed: $($_.Exception.Message)" -Type Error
            $errMsg = $_.Exception.Message
            if ($errMsg.Length -gt 300) { $errMsg = $errMsg.Substring(0, 300) }
            [void]$assertionResults.Add((New-Assertion -Name "scenario_assertions_completed" -Passed $false `
                -Expected "scenario assertions run without crash" `
                -Actual "exception thrown" `
                -Message $errMsg))
        }

        # Behavioral correctness verification (hidden test injection) - skip for static scenarios
        if ($ScenarioName -notin $StaticScenarios) {
            $behavioralAssertions = Run-BehavioralVerification -ScenarioName $ScenarioName -WorkDir $workDir
            foreach ($a in $behavioralAssertions) { [void]$assertionResults.Add($a) }

            # Assertion: agent_completed -- verify agent did not hit max turns and ran enough turns
            Write-Status "  Assertion: agent_completed" -Type Info
            $hitMaxTurns = $false
            if ($stdoutStr) {
                foreach ($line in ($stdoutStr -split "`n")) {
                    try {
                        $obj = $line.Trim() | ConvertFrom-Json -ErrorAction Stop
                        if ($obj.type -eq "result" -and $obj.subtype -eq "error_max_turns") {
                            $hitMaxTurns = $true
                            break
                        }
                    } catch { }
                }
            }
            $numTurns = $tokensData.num_turns
            if ($hitMaxTurns) {
                [void]$assertionResults.Add((New-Assertion -Name "agent_completed" -Passed $false `
                    -Expected "no error_max_turns" -Actual "error_max_turns detected" `
                -Message "Agent hit max turns limit without completing"))
            } elseif ($numTurns -lt 3) {
                [void]$assertionResults.Add((New-Assertion -Name "agent_completed" -Passed $false `
                    -Expected "num_turns >= 3" -Actual "num_turns = $numTurns" `
                    -Message "Agent completed too few turns, likely did not engage with the task"))
            } else {
                [void]$assertionResults.Add((New-Assertion -Name "agent_completed" -Passed $true `
                    -Expected "num_turns >= 3, no error_max_turns" -Actual "num_turns = $numTurns"))
            }
        } # End of non-static scenarios block

        # LLM-as-Judge evaluation (optional, gated by -Judge flag)
        if ($Judge) {
            Write-Status "  Running LLM judge..." -Type Info
            $judgeResult = Run-LlmJudge -ScenarioName $ScenarioName -WorkDir $workDir
            if ($judgeResult) {
                $judgeScoreStr = "$($judgeResult.score)/$($judgeResult.max_score)"
                Write-Status "  Judge score: $judgeScoreStr" -Type Info
                # Add judge_score as an assertion for visibility
                [void]$assertionResults.Add((New-Assertion -Name "judge_score" `
                    -Passed ($judgeResult.score -ge 2) `
                    -Expected "score >= 2/3" `
                    -Actual "score = $judgeScoreStr"))
            }
        }
        } # end: if (-not $circuitBreakerFired)
    }

    # Record end time
    $endUtc = Get-UtcTimestamp
    $endTicks = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $durationSeconds = [int]($endTicks - $startTicks)

    # Determine final status from assertions
    if ($status -eq "passed") {
        $failedCount = @($assertionResults | Where-Object { $_.passed -eq $false }).Count
        if ($failedCount -gt 0) {
            $status = "failed"
        }
    }

    # Report per-assertion
    foreach ($a in $assertionResults) {
        $icon = if ($a.passed) { "[PASS]" } else { "[FAIL]" }
        $color = if ($a.passed) { "Green" } else { "Red" }
        Write-Host "    $icon $($a.name)" -ForegroundColor $color
    }
    Write-Status "  Result: $($status.ToUpper()) (${durationSeconds}s)" -Type $(if ($status -eq "passed") { "Success" } elseif ($status -eq "failed") { "Warning" } else { "Error" })

    # T014/T015: Debug diagnostic report (only when -DebugMode is set)
    if ($DebugMode) {
        Write-Status "  Generating debug diagnostic report..." -Type Info
        $debugTimestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
        $debugReportPath = Join-Path $OutputDir "debug-$ScenarioName-$debugTimestamp.md"
        $reportContent = Build-DebugReport -ScenarioName $ScenarioName `
            -EvalRunId $EvalRunId -Status $status `
            -AssertionResults @($assertionResults) -WorkDir $workDir
        # T015: Apply secret redaction before writing to disk
        $reportContent = Invoke-SecretRedaction -Content $reportContent
        Set-Content -Path $debugReportPath -Value $reportContent -Encoding UTF8
        Write-Status "  Debug report: $debugReportPath" -Type Info
    }

    # Cleanup temp files (but not workdir - that is handled later)
    if (-not $SkipCleanup) {
        Remove-Item $stderrLog -ErrorAction SilentlyContinue
        Remove-Item $claudeOutput -ErrorAction SilentlyContinue
    }

    # Compute per-scenario score (assertion pass rate as decimal)
    $scenarioAssertTotal = $assertionResults.Count
    $scenarioAssertPassed = @($assertionResults | Where-Object { $_.passed -eq $true }).Count
    $scenarioScore = if ($scenarioAssertTotal -gt 0) { [Math]::Round($scenarioAssertPassed / $scenarioAssertTotal, 4) } else { 0.0 }

    # Build result object
    $scenarioResult = [ordered]@{
        name           = $ScenarioName
        status         = $status
        score          = $scenarioScore
        timing         = [ordered]@{
            start_utc        = $startUtc
            end_utc          = $endUtc
            duration_seconds = $durationSeconds
        }
        tokens         = $tokensData
        cost_usd       = $tokensData.cost_usd
        assertions     = @($assertionResults)
        quality_checks = [ordered]@{
            build_passed  = $buildPassed
            tests_passed  = $testsPassed
            files_created = @($filesCreated)
        }
        claude_output  = $claudeRawOutput
    }
    $scenarioResult["schema_version"] = "2.0"
    $scenarioResult["operational"] = [ordered]@{
        timeout_ms            = $TimeoutSeconds * 1000
        cost_limit_usd        = $CostLimit
        circuit_breaker_fired = $circuitBreakerFired
        max_turns             = $MaxTurns
        rules_hash            = $rulesHash
        workspace_checksum    = $workspaceChecksum
    }

    # T008: 6 MVP Metrics consolidated object
    $numTurnsVal = if ($tokensData.num_turns -and [int]$tokensData.num_turns -gt 0) { [int]$tokensData.num_turns } else { $null }
    $scenarioResult["metrics"] = Build-ScenarioMetrics `
        -AssertionsPassed $scenarioAssertPassed -AssertionsTotal $scenarioAssertTotal `
        -CostUsd $tokensData.cost_usd -NumTurns $numTurnsVal `
        -DurationSeconds $durationSeconds `
        -BuildPassed $buildPassed -TestsPassed $testsPassed

    if ($errorMessage) {
        $scenarioResult["error_message"] = $errorMessage
    }

    if ($judgeResult) {
        $scenarioResult["llm_judge"] = $judgeResult
    }

    return @{
        Result  = $scenarioResult
        WorkDir = $workDir
    }
}

# ---------------------------------------------------------------------------
# Phase 3: Execute scenarios
# ---------------------------------------------------------------------------

$scenarioResults = [System.Collections.ArrayList]::new()
$workDirs = [System.Collections.ArrayList]::new()
$partialJsonPath = Join-Path $OutputDir "$EvalRunId.partial.json"

if ($Parallel -and $ScenarioList.Count -gt 1) {
    # --- Parallel execution via background jobs ---
    Write-Host ""
    Write-Status "Parallel mode: up to $MaxParallel concurrent scenarios" -Type Info
    Write-Host ""

    $scriptPath = $MyInvocation.MyCommand.Path
    $batches = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $ScenarioList.Count; $i += $MaxParallel) {
        $end = [Math]::Min($i + $MaxParallel, $ScenarioList.Count)
        [void]$batches.Add(@($ScenarioList[$i..($end - 1)]))
    }

    $batchNum = 0
    foreach ($batch in $batches) {
        $batchNum++
        Write-Host ""
        Write-Host "--- Batch $batchNum/$($batches.Count): $($batch -join ', ') ---" -ForegroundColor Cyan
        Write-Host ""

        $jobs = @()
        foreach ($scenarioName in $batch) {
            # Each job re-invokes this script for a single scenario, writing to a unique output file.
            # The sub-invocation runs the full Phase 3 sequentially (single scenario) and saves its own JSON.
            $jobRunId = "$EvalRunId-$scenarioName"
            $jobArgs = @(
                '-NoProfile', '-File', $scriptPath,
                '-Scenario', $scenarioName,
                '-CommitSha', $CommitSha,
                '-OutputDir', $OutputDir,
                '-EvalRunId', $jobRunId,
                '-MaxTurns', $MaxTurns,
                '-Timeout', $TimeoutSeconds,
                '-CostLimit', $CostLimit,
                '-MaxResults', '0'    # Don't rotate from sub-runs
            )
            # Always forward ProjectRoot -- even empty string matters for baseline isolation.
            # Empty string suppresses auto-detect in sub-runs (via $PSBoundParameters check).
            $jobArgs += @('-ProjectRoot', $(if ($ProjectRoot) { $ProjectRoot } else { '' }))
            if ($SkipCleanup) { $jobArgs += '-SkipCleanup' }
            if ($DebugMode)   { $jobArgs += '-DebugMode' }
            if ($Headless)    { $jobArgs += '-Headless' }
            $jobArgs += '-NoBundleDashboard'

            Write-Status "  Launching: $scenarioName" -Type Info
            $job = Start-Job -ScriptBlock {
                param($pwshArgs)
                & powershell.exe @pwshArgs 2>&1
            } -ArgumentList (,$jobArgs)

            $jobs += @{ Job = $job; Scenario = $scenarioName; RunId = $jobRunId }
        }

        # Wait for all jobs in this batch with a generous timeout
        $batchTimeout = $TimeoutSeconds + 120  # extra 2 min for setup/teardown overhead
        Write-Status "  Waiting for batch $batchNum (timeout: ${batchTimeout}s)..." -Type Info
        $allJobs = $jobs | ForEach-Object { $_.Job }
        $null = Wait-Job -Job $allJobs -Timeout $batchTimeout

        # Stop any jobs that are still running after the timeout
        foreach ($entry in $jobs) {
            if ($entry.Job.State -eq 'Running') {
                Stop-Job -Job $entry.Job -ErrorAction SilentlyContinue
                Write-Status "  Timed out: $($entry.Scenario)" -Type Warning
            }
        }

        # Collect results from each job
        foreach ($entry in $jobs) {
            $job = $entry.Job
            $scenarioName = $entry.Scenario
            $jobRunId = $entry.RunId
            $jobJsonPath = Join-Path $OutputDir "$jobRunId.json"

            # Show job output (stdout/stderr from the sub-invocation)
            $jobOutput = Receive-Job -Job $job 2>&1
            foreach ($line in $jobOutput) {
                Write-Host "  [$scenarioName] $line"
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

            # Parse the sub-run's result JSON and extract the single scenario
            if (Test-Path $jobJsonPath) {
                try {
                    $jobResult = Get-Content $jobJsonPath -Raw | ConvertFrom-Json
                    foreach ($sr in $jobResult.scenarios) {
                        [void]$scenarioResults.Add($sr)
                    }
                } catch {
                    Write-Status "  Failed to parse results for $scenarioName : $($_.Exception.Message)" -Type Error
                    $crashResult = [ordered]@{
                        name           = $scenarioName
                        status         = "error"
                        score          = 0.0
                        timing         = [ordered]@{ start_utc = Get-UtcTimestamp; end_utc = Get-UtcTimestamp; duration_seconds = 0 }
                        tokens         = [ordered]@{ input_tokens = 0; output_tokens = 0; total_tokens = 0; cache_read_tokens = 0; cache_creation_tokens = 0; cost_usd = [double]0; num_turns = 0; duration_ms = 0; duration_api_ms = 0; stop_reason = ""; session_id = ""; model_breakdown = @{} }
                        cost_usd       = [double]0
                        assertions     = @()
                        quality_checks = [ordered]@{ build_passed = $false; tests_passed = $false; files_created = @() }
                        claude_output  = ""
                        error_message  = "Failed to parse sub-run results: $($_.Exception.Message)"
                        metrics        = Build-ScenarioMetrics -AssertionsPassed 0 -AssertionsTotal 0 -CostUsd 0 -NumTurns $null -DurationSeconds 0 -BuildPassed $false -TestsPassed $false
                    }
                    [void]$scenarioResults.Add($crashResult)
                }
                # Remove the per-scenario JSON (results are merged into the main file)
                Remove-Item $jobJsonPath -Force -ErrorAction SilentlyContinue
            } else {
                Write-Status "  No result file for $scenarioName (job may have timed out)" -Type Error
                $crashResult = [ordered]@{
                    name           = $scenarioName
                    status         = "error"
                    score          = 0.0
                    timing         = [ordered]@{ start_utc = Get-UtcTimestamp; end_utc = Get-UtcTimestamp; duration_seconds = 0 }
                    tokens         = [ordered]@{ input_tokens = 0; output_tokens = 0; total_tokens = 0; cache_read_tokens = 0; cache_creation_tokens = 0; cost_usd = [double]0; num_turns = 0; duration_ms = 0; duration_api_ms = 0; stop_reason = ""; session_id = ""; model_breakdown = @{} }
                    cost_usd       = [double]0
                    assertions     = @()
                    quality_checks = [ordered]@{ build_passed = $false; tests_passed = $false; files_created = @() }
                    claude_output  = ""
                    error_message  = "No result file produced (timeout or crash)"
                    metrics        = Build-ScenarioMetrics -AssertionsPassed 0 -AssertionsTotal 0 -CostUsd 0 -NumTurns $null -DurationSeconds 0 -BuildPassed $false -TestsPassed $false
                }
                [void]$scenarioResults.Add($crashResult)
            }
            # Also remove the dashboard that the sub-run may have auto-bundled
            # (we'll re-bundle at the end with all scenarios)
        }
    }

    # Remove any per-scenario partial files left behind by sub-runs
    Get-ChildItem -Path $OutputDir -Filter "$EvalRunId-*.partial.json" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
} else {
    # --- Sequential execution (original behavior) ---
    foreach ($scenarioName in $ScenarioList) {
        try {
            $outcome = Run-SingleScenario -ScenarioName $scenarioName -MaxTurns $MaxTurns -TimeoutMinutes $TimeoutMinutes -TimeoutSeconds $TimeoutSeconds -CostLimit $CostLimit -DebugMode:$DebugMode
            [void]$scenarioResults.Add($outcome.Result)
            [void]$workDirs.Add($outcome.WorkDir)
        } catch {
            Write-Status "Scenario $scenarioName crashed: $($_.Exception.Message)" -Type Error
            $crashResult = [ordered]@{
                name           = $scenarioName
                status         = "error"
                score          = 0.0
                timing         = [ordered]@{
                    start_utc        = Get-UtcTimestamp
                    end_utc          = Get-UtcTimestamp
                    duration_seconds = 0
                }
                tokens         = [ordered]@{
                    input_tokens = 0; output_tokens = 0; total_tokens = 0
                    cache_read_tokens = 0; cache_creation_tokens = 0
                    cost_usd = [double]0; num_turns = 0
                    duration_ms = 0; duration_api_ms = 0
                    stop_reason = ""; session_id = ""
                    model_breakdown = @{}
                }
                cost_usd       = [double]0
                assertions     = @()
                quality_checks = [ordered]@{
                    build_passed = $false; tests_passed = $false; files_created = @()
                }
                claude_output  = ""
                error_message  = "Scenario crashed: $($_.Exception.Message)"
                metrics        = Build-ScenarioMetrics `
                    -AssertionsPassed 0 -AssertionsTotal 0 `
                    -CostUsd 0 -NumTurns $null `
                    -DurationSeconds 0 `
                    -BuildPassed $false -TestsPassed $false
            }
            [void]$scenarioResults.Add($crashResult)
        }

        # Incremental save: write partial results after each scenario so progress survives crashes
        try {
            $partialResult = [ordered]@{
                run_id         = $EvalRunId
                schema_version = "2.0"
                git_commit_sha = $CommitSha
                git_branch     = $GitBranch
                timestamp_utc  = Get-UtcTimestamp
                trigger        = "manual"
                environment    = "local"
                config_source  = if ($ProjectRoot) { $ProjectRoot } else { "default" }
                partial        = $true
                completed      = $scenarioResults.Count
                total_planned  = $ScenarioList.Count
                scenarios      = @($scenarioResults)
            }
            $partialResult | ConvertTo-Json -Depth 10 | Set-Content -Path $partialJsonPath -Encoding UTF8
        } catch {
            Write-Status "  Warning: incremental save failed: $($_.Exception.Message)" -Type Warning
        }
    }
}

# Remove partial file now that full aggregation will take over
if (Test-Path $partialJsonPath) {
    Remove-Item -Path $partialJsonPath -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Phase 4: Aggregate results
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Aggregating Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalScenarios = $scenarioResults.Count
$passedCount = @($scenarioResults | Where-Object { $_.status -eq "passed" }).Count
$failedCount = @($scenarioResults | Where-Object { $_.status -eq "failed" }).Count
$errorCount = @($scenarioResults | Where-Object { $_.status -eq "error" }).Count
$skippedCount = @($scenarioResults | Where-Object { $_.status -eq "skipped" }).Count

$totalDuration = ($scenarioResults | ForEach-Object { $_.timing.duration_seconds } | Measure-Object -Sum).Sum
if (-not $totalDuration) { $totalDuration = 0 }

$totalTokens = ($scenarioResults | ForEach-Object { $_.tokens.total_tokens } | Measure-Object -Sum).Sum
if (-not $totalTokens) { $totalTokens = 0 }

$totalCostUsd = ($scenarioResults | ForEach-Object { $_.cost_usd } | Measure-Object -Sum).Sum
if (-not $totalCostUsd) { $totalCostUsd = [double]0 }

$totalAssertions = ($scenarioResults | ForEach-Object { $_.assertions.Count } | Measure-Object -Sum).Sum
$passedAssertions = 0
foreach ($sr in $scenarioResults) {
    $passedAssertions += @($sr.assertions | Where-Object { $_.passed -eq $true }).Count
}

$passRate = 0
if ($totalAssertions -gt 0) {
    $passRate = [Math]::Round($passedAssertions / $totalAssertions, 4)
}

# Compute avg_score: average of per-scenario scores
$scorableScenarios = @($scenarioResults | Where-Object { $_.status -ne "skipped" })
$avgScore = 0
if ($scorableScenarios.Count -gt 0) {
    $avgScore = [Math]::Round(($scorableScenarios | ForEach-Object { $_.score } | Measure-Object -Average).Average, 4)
}

# Add commit metadata if CommitSha was explicitly provided
$commitMessage = ""
$commitDate = ""
if ($CommitSha) {
    $commitMessage = (git -C $RepoRoot log --format="%s" -1 $CommitSha 2>$null)
    $commitDate = (git -C $RepoRoot log --format="%aI" -1 $CommitSha 2>$null)
}

$finalResult = [ordered]@{
    run_id             = $EvalRunId
    schema_version     = "2.0"
    git_commit_sha     = $CommitSha
    git_branch         = $GitBranch
    timestamp_utc      = Get-UtcTimestamp
    trigger            = "manual"
    environment        = "local"
    config_source      = if ($ProjectRoot) { $ProjectRoot } else { "default" }
    git_commit_message = $commitMessage
    git_commit_date    = $commitDate
    scenarios          = @($scenarioResults)
    summary        = [ordered]@{
        total_scenarios        = $totalScenarios
        passed                 = $passedCount
        failed                 = $failedCount
        errors                 = $errorCount
        skipped                = $skippedCount
        total_duration_seconds = [int]$totalDuration
        total_tokens           = [int]$totalTokens
        total_cost_usd         = $totalCostUsd
        assertion_pass_rate    = $passRate
        avg_score              = $avgScore
    }
}

# Judge aggregation (if any scenarios were judged)
$judgeScenarios = @($scenarioResults | Where-Object { $_.llm_judge })
if ($judgeScenarios.Count -gt 0) {
    $avgJudge = ($judgeScenarios | ForEach-Object { $_.llm_judge.score / $_.llm_judge.max_score } | Measure-Object -Average).Average
    $totalJudgeCost = ($judgeScenarios | ForEach-Object { $_.llm_judge.cost_usd } | Measure-Object -Sum).Sum
    $finalResult.summary.avg_judge_score = [Math]::Round($avgJudge, 4)
    $finalResult.summary.total_judge_cost_usd = [Math]::Round($totalJudgeCost, 6)
}

# Save JSON
$jsonPath = Join-Path $OutputDir "$EvalRunId.json"
$finalResult | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
Write-Status "Results saved: $jsonPath" -Type Success

# --- Cost regression detection ---
$prevFiles = @(Get-ChildItem -Path $OutputDir -Filter "eval-*.json" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "$EvalRunId.json" } |
    Sort-Object LastWriteTime)
$prevResults = @($prevFiles | ForEach-Object {
    try { Get-Content $_.FullName -Raw | ConvertFrom-Json } catch { $null }
} | Where-Object { $_ -ne $null })

$regressionCheck = Get-CostRegression -CurrentResult $finalResult -PreviousResults $prevResults
$finalResult.summary.cost_regression = $regressionCheck.cost_regression

if ($regressionCheck.cost_regression) {
    foreach ($scenario in $finalResult.scenarios) {
        $sName = $scenario.name
        $sCost = [double]$scenario.cost_usd
        $prevWindow = $prevResults
        if ($prevWindow.Count -gt 10) { $prevWindow = $prevWindow[($prevWindow.Count - 10)..($prevWindow.Count - 1)] }
        $prevCosts = @($prevWindow | ForEach-Object {
            $m = $_.scenarios | Where-Object { $_.name -eq $sName }
            if ($m -and $m.cost_usd -and [double]$m.cost_usd -gt 0) { [double]$m.cost_usd }
        })
        if ($prevCosts.Count -gt 0) {
            $avg = ($prevCosts | Measure-Object -Average).Average
            if ($avg -gt 0 -and $sCost -gt (2 * $avg)) {
                $ratio = [Math]::Round($sCost / $avg, 1)
                Write-Status "COST REGRESSION: scenario '$sName' cost `$$([Math]::Round($sCost,2)) vs avg `$$([Math]::Round($avg,2)) (${ratio}x)" -Type Warning
            }
        }
    }
} else {
    Write-Status "Cost check: no regression detected" -Type Info
}

# Re-save with cost_regression field
$finalResult | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

# --- Auto-bundle dashboard ---
if (-not $NoBundleDashboard) {
    $bundleScript = Join-Path $ScriptRoot "Open-EvalDashboard.ps1"
    if (Test-Path $bundleScript) {
        Write-Status "Bundling dashboard..." -Type Info
        & powershell.exe -NoProfile -File $bundleScript -NoOpen
        Write-Status "Dashboard bundled: .mad/tests/dashboard/dashboard.html" -Type Success
    }
}

# --- Baseline pass (if requested) ---
if ($IncludeBaseline) {
    $today = (Get-Date).ToString("yyyyMMdd")
    $baselinePattern = "eval-baseline-$today*.json"
    $existingBaseline = Get-ChildItem -Path $OutputDir -Filter $baselinePattern -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.partial.json' } | Select-Object -First 1

    if ($existingBaseline) {
        Write-Status "Baseline for today already exists: $($existingBaseline.Name) -- reusing" -Type Info
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Magenta
        Write-Host "  Running Baseline (no project config)" -ForegroundColor Magenta
        Write-Host "========================================" -ForegroundColor Magenta
        Write-Host ""

        $baselineRunId = "eval-baseline-$today-$ShortSha"
        $baselineScript = $MyInvocation.MyCommand.Path

        # Exclude config-dependent scenarios from baseline runs.
        # 'rule-adherence' and 'negative-constraints' deliberately create their own
        # .claude/rules/ and CLAUDE.md inside the workspace to test config adherence.
        # Running them without project config (baseline mode) is meaningless -- they
        # would always fail or produce noise since they depend on config being present.
        $configDependentScenarios = @('rule-adherence', 'negative-constraints')
        $baselineScenarios = $ScenarioList | Where-Object { $_ -notin $configDependentScenarios }

        if ($baselineScenarios.Count -eq 0) {
            Write-Status "All scenarios are config-dependent -- skipping baseline run" -Type Warning
        } else {
            if ($baselineScenarios.Count -lt $ScenarioList.Count) {
                $excluded = $ScenarioList | Where-Object { $_ -in $configDependentScenarios }
                Write-Status "Excluding config-dependent scenarios from baseline: $($excluded -join ', ')" -Type Info
            }

        # Re-invoke without ProjectRoot to get a bare baseline
        $baselineArgs = @(
            '-NoProfile', '-File', $baselineScript,
            '-Scenario', ($baselineScenarios -join ','),
            '-ProjectRoot', '',
            '-CommitSha', $CommitSha,
            '-OutputDir', $OutputDir,
            '-EvalRunId', $baselineRunId,
            '-MaxTurns', $MaxTurns,
            '-TimeoutMinutes', $TimeoutMinutes,
            '-MaxResults', '0'    # Don't rotate from baseline sub-run
        )
        if ($SkipCleanup) { $baselineArgs += '-SkipCleanup' }
        if ($Parallel)    { $baselineArgs += @('-Parallel', '-MaxParallel', $MaxParallel) }
        if ($DebugMode)   { $baselineArgs += '-DebugMode' }
        if ($Headless)    { $baselineArgs += '-Headless' }
        $baselineArgs += @('-CostLimit', $CostLimit)

        Write-Status "Invoking baseline: $baselineRunId" -Type Info
        & powershell.exe @baselineArgs
        $baselineExit = $LASTEXITCODE

        if ($baselineExit -eq 0) {
            Write-Status "Baseline complete: $baselineRunId" -Type Success
        } else {
            Write-Status "Baseline had failures (exit $baselineExit) -- saved anyway" -Type Warning
        }

        # Tag the baseline result with config_source = "baseline"
        $baselineJsonPath = Join-Path $OutputDir "$baselineRunId.json"
        if (Test-Path $baselineJsonPath) {
            $baselineJson = Get-Content $baselineJsonPath -Raw | ConvertFrom-Json
            $baselineJson.config_source = "baseline"
            $baselineJson | ConvertTo-Json -Depth 10 | Set-Content -Path $baselineJsonPath -Encoding UTF8
        }
        } # end: baseline scenarios available
    }

    # T009: CLI Comparison Table -- baseline vs treatment metrics
    $baselineFile = if ($existingBaseline) { $existingBaseline.FullName } else { Join-Path $OutputDir "$baselineRunId.json" }
    if (Test-Path $baselineFile) {
        $baselineData = Get-Content $baselineFile -Raw | ConvertFrom-Json

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Baseline vs Treatment Comparison" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""

        # Per-scenario comparison
        foreach ($treatmentScenario in $scenarioResults) {
            $sName = $treatmentScenario.name
            $baselineScenario = $baselineData.scenarios | Where-Object { $_.name -eq $sName } | Select-Object -First 1

            if (-not $baselineScenario) {
                Write-Host "  $sName : no matching baseline scenario found" -ForegroundColor DarkGray
                continue
            }

            Write-Host "  Scenario: $sName" -ForegroundColor White

            # Extract metrics from both sides
            $treatmentMetrics = $null
            $baselineMetrics = $null

            # Treatment: use the metrics object we just built
            if ($treatmentScenario.metrics) {
                $treatmentMetrics = $treatmentScenario.metrics
            } else {
                # Fallback: build from raw fields
                $tAssertTotal = $treatmentScenario.assertions.Count
                $tAssertPassed = @($treatmentScenario.assertions | Where-Object { $_.passed -eq $true }).Count
                $tNumTurns = if ($treatmentScenario.tokens.num_turns -and [int]$treatmentScenario.tokens.num_turns -gt 0) { [int]$treatmentScenario.tokens.num_turns } else { $null }
                $treatmentMetrics = Build-ScenarioMetrics `
                    -AssertionsPassed $tAssertPassed -AssertionsTotal $tAssertTotal `
                    -CostUsd ([double]$treatmentScenario.cost_usd) -NumTurns $tNumTurns `
                    -DurationSeconds ([int]$treatmentScenario.timing.duration_seconds) `
                    -BuildPassed ([bool]$treatmentScenario.quality_checks.build_passed) `
                    -TestsPassed ([bool]$treatmentScenario.quality_checks.tests_passed)
            }

            # Baseline: build from parsed JSON
            if ($baselineScenario.metrics) {
                # If baseline already has metrics object, use it
                $baselineMetrics = [ordered]@{
                    assertion_pass_rate = [double]$baselineScenario.metrics.assertion_pass_rate
                    total_cost_usd      = [double]$baselineScenario.metrics.total_cost_usd
                    num_turns           = if ($null -ne $baselineScenario.metrics.num_turns) { [int]$baselineScenario.metrics.num_turns } else { $null }
                    duration_seconds    = [int]$baselineScenario.metrics.duration_seconds
                    build_gate          = [bool]$baselineScenario.metrics.build_gate
                    test_gate           = [bool]$baselineScenario.metrics.test_gate
                }
            } else {
                # Fallback: build from raw fields
                $bAssertTotal = @($baselineScenario.assertions).Count
                $bAssertPassed = @($baselineScenario.assertions | Where-Object { $_.passed -eq $true }).Count
                $bNumTurns = if ($baselineScenario.tokens.num_turns -and [int]$baselineScenario.tokens.num_turns -gt 0) { [int]$baselineScenario.tokens.num_turns } else { $null }
                $baselineMetrics = Build-ScenarioMetrics `
                    -AssertionsPassed $bAssertPassed -AssertionsTotal $bAssertTotal `
                    -CostUsd ([double]$baselineScenario.cost_usd) -NumTurns $bNumTurns `
                    -DurationSeconds ([int]$baselineScenario.timing.duration_seconds) `
                    -BuildPassed ([bool]$baselineScenario.quality_checks.build_passed) `
                    -TestsPassed ([bool]$baselineScenario.quality_checks.tests_passed)
            }

            $comparison = Format-MetricsComparison -BaselineMetrics $baselineMetrics -TreatmentMetrics $treatmentMetrics
            $comparison.Rows | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }

            # Update discrimination_delta in the treatment scenario metrics
            if ($null -ne $comparison.DiscriminationDelta) {
                $treatmentScenario.metrics.discrimination_delta = $comparison.DiscriminationDelta
                $deltaColor = if ($comparison.DiscriminationDelta -gt 0) { "Green" } elseif ($comparison.DiscriminationDelta -lt 0) { "Red" } else { "Yellow" }
                Write-Host "  Discrimination Delta: $([Math]::Round($comparison.DiscriminationDelta, 4)) ($([Math]::Round($comparison.DiscriminationDelta * 100, 1))%)" -ForegroundColor $deltaColor
            }
            Write-Host ""
        }

        # Aggregate discrimination delta
        $aggBaselinePassRate = if ($baselineData.summary.assertion_pass_rate) { [double]$baselineData.summary.assertion_pass_rate } else { 0.0 }
        $aggTreatmentPassRate = $passRate
        $aggDiscDelta = [Math]::Round($aggTreatmentPassRate - $aggBaselinePassRate, 4)
        $aggDeltaColor = if ($aggDiscDelta -gt 0) { "Green" } elseif ($aggDiscDelta -lt 0) { "Red" } else { "Yellow" }
        Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Aggregate Discrimination Delta: $aggDiscDelta ($([Math]::Round($aggDiscDelta * 100, 1))%)" -ForegroundColor $aggDeltaColor
        Write-Host ""

        # Re-save with updated discrimination_delta values
        $finalResult | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    } else {
        Write-Status "Baseline file not found -- skipping comparison table" -Type Warning
    }
}

# --- Rotate old results ---
if ($MaxResults -gt 0) {
    $allResults = @(Get-ChildItem -Path $OutputDir -Filter "eval-*.json" -File | Sort-Object LastWriteTime -Descending)
    if ($allResults.Count -gt $MaxResults) {
        $toRemove = $allResults[$MaxResults..($allResults.Count - 1)]
        foreach ($old in $toRemove) {
            Write-Verbose "Removing old result: $($old.Name)"
            Remove-Item $old.FullName -Force
        }
        Write-Host "  Rotated: removed $($toRemove.Count) old result(s), keeping $MaxResults"
    }
}

# ---------------------------------------------------------------------------
# Phase 5: Summary table
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Table header
$headerFmt = "{0,-30} {1,-10} {2,-12} {3,-10} {4,-8}"
Write-Host ($headerFmt -f "SCENARIO", "SCORE", "DURATION", "TOKENS", "ASSERTS") -ForegroundColor White
Write-Host ("-" * 72) -ForegroundColor DarkGray

foreach ($sr in $scenarioResults) {
    $scorePct = [Math]::Round($sr.score * 100, 0)
    $scoreStr = "$scorePct%"
    $scoreColor = if ($scorePct -eq 100) { "Green" } elseif ($scorePct -ge 80) { "Yellow" } elseif ($scorePct -ge 60) { "DarkYellow" } else { "Red" }
    if ($sr.status -eq "error") { $scoreStr = "ERROR"; $scoreColor = "Red" }
    if ($sr.status -eq "skipped") { $scoreStr = "SKIP"; $scoreColor = "Yellow" }
    $dur = "$($sr.timing.duration_seconds)s"
    $tok = $sr.tokens.total_tokens
    $assertTotal = $sr.assertions.Count
    $assertPass = @($sr.assertions | Where-Object { $_.passed -eq $true }).Count
    $assertStr = "$assertPass/$assertTotal"

    Write-Host ($headerFmt -f $sr.name, $scoreStr, $dur, $tok, $assertStr) -ForegroundColor $scoreColor
}

Write-Host ("-" * 72) -ForegroundColor DarkGray
$avgScorePct = [Math]::Round($avgScore * 100, 1)
Write-Host ($headerFmt -f "TOTAL", "${avgScorePct}% avg", "${totalDuration}s", $totalTokens, "$passedAssertions/$totalAssertions") -ForegroundColor White
Write-Host ""
Write-Host "  Overall score: ${avgScorePct}%" -ForegroundColor $(if ($avgScore -ge 0.8) { "Green" } elseif ($avgScore -ge 0.5) { "Yellow" } else { "Red" })
Write-Host ""

# ---------------------------------------------------------------------------
# Phase 6: Upload (if requested)
# ---------------------------------------------------------------------------

if ($Upload) {
    $storeScript = Join-Path $ScriptRoot "Store-EvalResults.ps1"
    if (Test-Path $storeScript) {
        Write-Status "Uploading results..." -Type Info
        & $storeScript -ResultFile $jsonPath
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Upload failed (exit $LASTEXITCODE)" -Type Warning
        } else {
            Write-Status "Upload complete" -Type Success
        }
    } else {
        Write-Status "Store-EvalResults.ps1 not found at $storeScript -- skipping upload" -Type Warning
    }
}

# ---------------------------------------------------------------------------
# Phase 7: Cleanup
# ---------------------------------------------------------------------------

if (-not $SkipCleanup) {
    Write-Status "Cleaning up temp directories..." -Type Info
    if ($ProjectRoot) {
        # Remove the entire eval run directory
        $baseTempDir = [System.IO.Path]::Combine($ProjectRoot, ".mad", "scratch", "eval-$EvalRunId")
        if (Test-Path $baseTempDir) {
            Remove-Item -Path $baseTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        # Also clean up parallel sub-run directories (eval-$EvalRunId-<scenario>)
        $scratchDir = Join-Path (Join-Path $ProjectRoot ".mad") "scratch"
        Get-ChildItem -Path $scratchDir -Filter "eval-$EvalRunId-*" -Directory -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        # Remove individual scenario directories
        foreach ($wd in $workDirs) {
            if ($wd -and (Test-Path $wd)) {
                Remove-Item -Path $wd -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Status "Cleanup complete" -Type Success
} else {
    Write-Status "Skipping cleanup (-SkipCleanup). Temp dirs:" -Type Info
    if ($ProjectRoot) {
        $baseTempDir = [System.IO.Path]::Combine($ProjectRoot, ".mad", "scratch", "eval-$EvalRunId")
        Write-Host "    $baseTempDir" -ForegroundColor DarkGray
    } else {
        foreach ($wd in $workDirs) {
            Write-Host "    $wd" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""

# Exit code: exit 1 only if any scenario scores below 50% (catastrophic failure)
$catastrophicScenarios = @($scorableScenarios | Where-Object { $_.score -lt 0.5 })
if ($catastrophicScenarios.Count -gt 0) {
    $catastrophicNames = ($catastrophicScenarios | ForEach-Object { "$($_.name) ($([Math]::Round($_.score * 100, 0))%)" }) -join ', '
    Write-Host "  CATASTROPHIC FAILURE: $($catastrophicScenarios.Count) scenario(s) below 50%: $catastrophicNames" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  Overall score: ${avgScorePct}% (all scenarios above 50% threshold)" -ForegroundColor Green
    exit 0
}
