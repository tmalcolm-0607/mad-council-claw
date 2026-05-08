<#
.SYNOPSIS
    Generate agent eval comparison report from blob storage history.

.DESCRIPTION
    Downloads eval results from Azure Blob Storage and generates a markdown
    comparison report with trend analysis, deltas, and verdicts.

    Computes regression/improvement/stable verdicts based on:
    - assertion_pass_rate: Any decrease = REGRESSED
    - total_tokens: >15% increase = REGRESSED, >10% decrease = IMPROVED
    - total_duration: >20% increase = REGRESSED, >10% decrease = IMPROVED

.PARAMETER Environment
    Target environment storage account: tonym, npe (default: tonym).

.PARAMETER RunId
    Specific run ID to analyze (default: latest).

.PARAMETER BaselineRunId
    Run ID to use as baseline for comparison (default: oldest in history).

.PARAMETER HistoryCount
    Number of historical runs to include in trend table (default: 10).

.PARAMETER Branch
    Branch name to analyze (default: main).

.PARAMETER OutputPath
    Path for generated markdown report (default: .mad/tests/results/report-{RunId}.md).

.EXAMPLE
    .\Generate-EvalReport.ps1
    .\Generate-EvalReport.ps1 -RunId eval-20260214-123456-abc1234
    .\Generate-EvalReport.ps1 -Branch feature/agent-teams -HistoryCount 20
    .\Generate-EvalReport.ps1 -Environment npe -BaselineRunId eval-20260201-000000-baseline

.NOTES
    Storage account naming: stlenscmseval{environment}wus3
    Container name: eval-results
    Requires: Azure CLI with authenticated session (az login)
#>

[CmdletBinding()]
param(
    [ValidateSet("tonym", "npe")]
    [string]$Environment = "tonym",

    [string]$RunId,
    [string]$BaselineRunId,
    [int]$HistoryCount = 10,
    [string]$Branch = "main",
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

# --- Constants ---
$StorageAccountPrefix = "stlenscmseval"
$StorageAccountSuffix = "wus3"
$ContainerName = "eval-results"

# --- Helpers ---
function Write-Status {
    param([string]$Message, [ValidateSet("Info","Success","Warning","Error")][string]$Type = "Info")
    $colors = @{ Info="Cyan"; Success="Green"; Warning="Yellow"; Error="Red" }
    $prefix = @{ Info="[*]"; Success="[+]"; Warning="[!]"; Error="[-]" }
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Get-SanitizedBranch {
    param([string]$BranchName)
    return $BranchName -replace '/', '-'
}

function Format-Number {
    param([double]$Value, [string]$Format = "N0")
    return $Value.ToString($Format)
}

function Format-Percentage {
    param([double]$Value)
    return "{0:N1}%" -f ($Value * 100)
}

function Get-DeltaString {
    param([double]$Current, [double]$Baseline, [string]$Format = "N0", [bool]$IsPercentage = $false)

    if ($Baseline -eq 0) { return "N/A" }

    $delta = $Current - $Baseline
    $pctChange = ($delta / $Baseline)

    $sign = if ($delta -gt 0) { "+" } else { "" }

    if ($IsPercentage) {
        $deltaStr = "{0}{1:N1} pp" -f $sign, ($delta * 100)  # pp = percentage points
    } else {
        $deltaStr = "{0}{1}" -f $sign, (Format-Number -Value $delta -Format $Format)
    }

    $pctStr = "{0}{1:N1}%" -f $sign, ($pctChange * 100)

    return "$deltaStr ($pctStr)"
}

function Get-Verdict {
    param([double]$Current, [double]$Baseline, [string]$Metric)

    if ($Baseline -eq 0) { return "STABLE" }

    $pctChange = ($Current - $Baseline) / $Baseline

    switch ($Metric) {
        "assertion_pass_rate" {
            if ($Current -lt $Baseline) { return "REGRESSED" }
            elseif ($Current -gt $Baseline) { return "IMPROVED" }
            else { return "STABLE" }
        }
        "total_tokens" {
            if ($pctChange -gt 0.15) { return "REGRESSED" }
            elseif ($pctChange -lt -0.10) { return "IMPROVED" }
            else { return "STABLE" }
        }
        "total_duration" {
            if ($pctChange -gt 0.20) { return "REGRESSED" }
            elseif ($pctChange -lt -0.10) { return "IMPROVED" }
            else { return "STABLE" }
        }
        default { return "STABLE" }
    }
}

function Get-VerdictEmoji {
    param([string]$Verdict)
    switch ($Verdict) {
        "IMPROVED"  { return "[PASS]" }
        "REGRESSED" { return "[FAIL]" }
        "MIXED"     { return "[WARN]" }
        default     { return "[--]" }  # STABLE
    }
}

function Get-OverallVerdict {
    param([array]$Verdicts)

    $hasRegressed = $Verdicts -contains "REGRESSED"
    $hasImproved = $Verdicts -contains "IMPROVED"

    if ($hasRegressed -and $hasImproved) { return "MIXED" }
    if ($hasRegressed) { return "REGRESSED" }
    if ($hasImproved) { return "IMPROVED" }
    return "STABLE"
}

function Get-AssertionStatusEmoji {
    param([string]$Status)
    switch ($Status) {
        "PASS"  { return "[PASS]" }
        "FAIL"  { return "[FAIL]" }
        default { return "[?]" }
    }
}

# --- Main ---

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Generate Eval Report" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$sanitizedBranch = Get-SanitizedBranch -BranchName $Branch
$storageAccount = "$StorageAccountPrefix$Environment$StorageAccountSuffix"

Write-Status "Environment: $Environment" -Type Info
Write-Status "Branch: $Branch (sanitized: $sanitizedBranch)" -Type Info
Write-Status "Storage Account: $storageAccount" -Type Info
Write-Host ""

# Create temp directory for downloads
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "eval-report-$(Get-Date -Format 'HHmmss')"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

# Determine current run
if (-not $RunId) {
    Write-Status "Downloading latest.json to determine current run..." -Type Info
    $latestPath = Join-Path $tempDir "latest.json"

    az storage blob download `
        --account-name $storageAccount `
        --container-name $ContainerName `
        --auth-mode login `
        --name "$sanitizedBranch/latest.json" `
        --file $latestPath `
        2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to download latest.json. No eval results exist yet?" -Type Error
        Write-Status "Run Store-EvalResults.ps1 first to upload eval results" -Type Info
        Remove-Item $tempDir -Recurse -Force
        exit 1
    }

    $latestJson = Get-Content $latestPath -Raw | ConvertFrom-Json
    $RunId = $latestJson.run_id
    Write-Status "Latest run: $RunId" -Type Success
}

# List and download history
Write-Status "Listing historical runs for branch: $sanitizedBranch" -Type Info

# Build query filter (must avoid PowerShell parsing braces as scriptblock)
$latestFileName = "$sanitizedBranch/latest.json"
$blobListJson = & {
    az storage blob list `
        --account-name $storageAccount `
        --container-name $ContainerName `
        --auth-mode login `
        --prefix "$sanitizedBranch/" `
        --output json
} 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Status "Failed to list blobs" -Type Error
    Remove-Item $tempDir -Recurse -Force
    exit 1
}

$allBlobs = $blobListJson | ConvertFrom-Json
# Filter out latest.json manually
$blobs = $allBlobs | Where-Object { $_.name -ne "$sanitizedBranch/latest.json" } |
    Sort-Object -Property @{Expression={$_.properties.lastModified}; Descending=$true}

if ($blobs.Count -eq 0) {
    Write-Status "No historical runs found for branch: $Branch" -Type Warning
    Remove-Item $tempDir -Recurse -Force
    exit 1
}

Write-Status "Found $($blobs.Count) historical run(s)" -Type Success

# Download runs
$runs = @()
$downloadCount = [Math]::Min($HistoryCount, $blobs.Count)

Write-Status "Downloading last $downloadCount run(s)..." -Type Info

for ($i = 0; $i -lt $downloadCount; $i++) {
    $blobName = $blobs[$i].name
    $fileName = [System.IO.Path]::GetFileName($blobName)
    $localPath = Join-Path $tempDir $fileName

    az storage blob download `
        --account-name $storageAccount `
        --container-name $ContainerName `
        --auth-mode login `
        --name $blobName `
        --file $localPath `
        2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $runJson = Get-Content $localPath -Raw | ConvertFrom-Json
        $runs += $runJson
        Write-Status "  Downloaded: $fileName" -Type Info
    }
}

Write-Host ""
Write-Status "Downloaded $($runs.Count) run(s)" -Type Success

# Identify current, baseline, and previous
$currentRun = $runs | Where-Object { $_.run_id -eq $RunId }
if (-not $currentRun) {
    Write-Status "Run ID $RunId not found in history" -Type Error
    Remove-Item $tempDir -Recurse -Force
    exit 1
}

if ($BaselineRunId) {
    $baselineRun = $runs | Where-Object { $_.run_id -eq $BaselineRunId }
    if (-not $baselineRun) {
        Write-Status "Baseline run ID $BaselineRunId not found in history" -Type Error
        Remove-Item $tempDir -Recurse -Force
        exit 1
    }
} else {
    $baselineRun = $runs | Select-Object -Last 1  # Oldest
}

$previousRun = $runs | Select-Object -Skip 1 -First 1  # Second most recent

Write-Status "Current: $($currentRun.run_id)" -Type Info
Write-Status "Baseline: $($baselineRun.run_id)" -Type Info
if ($previousRun) {
    Write-Status "Previous: $($previousRun.run_id)" -Type Info
}
Write-Host ""

# Compute metrics
$currentPassRate = $currentRun.summary.assertion_pass_rate
$baselinePassRate = $baselineRun.summary.assertion_pass_rate

$currentTokens = $currentRun.summary.total_tokens
$baselineTokens = $baselineRun.summary.total_tokens

$currentDuration = $currentRun.summary.total_duration_seconds
$baselineDuration = $baselineRun.summary.total_duration_seconds

# Compute verdicts
$verdicts = @(
    (Get-Verdict -Current $currentPassRate -Baseline $baselinePassRate -Metric "assertion_pass_rate"),
    (Get-Verdict -Current $currentTokens -Baseline $baselineTokens -Metric "total_tokens"),
    (Get-Verdict -Current $currentDuration -Baseline $baselineDuration -Metric "total_duration")
)

$overallVerdict = Get-OverallVerdict -Verdicts $verdicts

# Determine output path
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path $tempDir -Parent) "report-$RunId.md"
}

# Generate report
Write-Status "Generating report..." -Type Info

# Pre-compute all dynamic values for the summary table
$fmtCurrentPassRate = Format-Percentage $currentPassRate
$fmtBaselinePassRate = Format-Percentage $baselinePassRate
$deltaPassRate = Get-DeltaString -Current $currentPassRate -Baseline $baselinePassRate -IsPercentage $true
$emojiPassRate = Get-VerdictEmoji $verdicts[0]
$verdictPassRate = $verdicts[0]

$fmtCurrentTokens = Format-Number $currentTokens
$fmtBaselineTokens = Format-Number $baselineTokens
$deltaTokens = Get-DeltaString -Current $currentTokens -Baseline $baselineTokens
$emojiTokens = Get-VerdictEmoji $verdicts[1]
$verdictTokens = $verdicts[1]

$deltaDuration = Get-DeltaString -Current $currentDuration -Baseline $baselineDuration -Format "N0"
$emojiDuration = Get-VerdictEmoji $verdicts[2]
$verdictDuration = $verdicts[2]

$emojiOverall = Get-VerdictEmoji $overallVerdict

$runIdStr = $currentRun.run_id
$commitStr = $currentRun.git_commit_sha.Substring(0,7)
$branchStr = $currentRun.git_branch
$timestampStr = $currentRun.timestamp_utc

$report = "# Agent Eval Report" + "`n"
$report += "`n"
$report += "**Run**: ``$runIdStr`` | **Commit**: ``$commitStr`` | **Branch**: ``$branchStr`` | **Date**: ``$timestampStr``" + "`n"
$report += "`n"
$report += "## Summary" + "`n"
$report += "`n"
$report += "| Metric | Current | Baseline | Delta | Verdict |" + "`n"
$report += "|--------|---------|----------|-------|---------|" + "`n"
$report += "| Pass Rate | $fmtCurrentPassRate | $fmtBaselinePassRate | $deltaPassRate | $emojiPassRate $verdictPassRate |" + "`n"
$report += "| Total Tokens | $fmtCurrentTokens | $fmtBaselineTokens | $deltaTokens | $emojiTokens $verdictTokens |" + "`n"
$report += "| Duration | $($currentDuration)s | $($baselineDuration)s | $deltaDuration | $emojiDuration $verdictDuration |" + "`n"
$report += "`n"
$report += "**Overall**: $emojiOverall **$overallVerdict**" + "`n"
$report += "`n"
$report += "## Per-Scenario Results" + "`n"
$report += "`n"

# Add per-scenario details
foreach ($scenario in $currentRun.scenarios) {
    $statusEmoji = Get-AssertionStatusEmoji -Status $scenario.status
    $fmtScenarioTokens = Format-Number $scenario.tokens.total_tokens

    $scenarioAssertionsPassed = @($scenario.assertions | Where-Object { $_.passed }).Count
    $scenarioAssertionsTotal = $scenario.assertions.Count

    $report += "`n"
    $report += "### $($scenario.name)" + "`n"
    $report += "- **Status**: $statusEmoji $($scenario.status)" + "`n"
    $report += "- **Duration**: $($scenario.timing.duration_seconds)s | **Tokens**: $fmtScenarioTokens" + "`n"
    $report += "- **Assertions**: $scenarioAssertionsPassed/$scenarioAssertionsTotal passed" + "`n"
    $report += "`n"

    if ($scenario.assertions) {
        foreach ($assertion in $scenario.assertions) {
            $assertStatus = if ($assertion.passed) { "PASS" } else { "FAIL" }
            $assertEmoji = Get-AssertionStatusEmoji -Status $assertStatus
            $assertName = $assertion.name
            $backtick = [char]96
            $report += "  - $assertEmoji $backtick$assertName$backtick"

            if (-not $assertion.passed -and $assertion.expected) {
                $report += " (expected: $($assertion.expected), actual: $($assertion.actual))"
            }

            $report += "`n"
        }
    }
}

# Trend table
$report += "`n"
$report += "## Trend (last $($runs.Count) runs)" + "`n"
$report += "`n"
$report += "| Run | Date | Pass Rate | Tokens | Duration | Verdict |" + "`n"
$report += "|-----|------|-----------|--------|----------|---------|" + "`n"
$report += "`n"

foreach ($run in $runs) {
    $runPassRate = $run.summary.assertion_pass_rate
    $runBaselinePassRate = $baselineRun.summary.assertion_pass_rate

    $runVerdicts = @(
        (Get-Verdict -Current $runPassRate -Baseline $runBaselinePassRate -Metric "assertion_pass_rate"),
        (Get-Verdict -Current $run.summary.total_tokens -Baseline $baselineRun.summary.total_tokens -Metric "total_tokens"),
        (Get-Verdict -Current $run.summary.total_duration_seconds -Baseline $baselineRun.summary.total_duration_seconds -Metric "total_duration")
    )

    $runVerdict = Get-OverallVerdict -Verdicts $runVerdicts

    $dateStr = if ($run.timestamp_utc -match '(\d{4}-\d{2}-\d{2})') { $matches[1] } else { "N/A" }

    $fmtRunPassRate = Format-Percentage $runPassRate
    $fmtRunTokens = Format-Number $run.summary.total_tokens
    $runDuration = $run.summary.total_duration_seconds
    $runRunId = $run.run_id
    $backtick = [char]96
    $report += "| $backtick$runRunId$backtick | $dateStr | $fmtRunPassRate | $fmtRunTokens | $($runDuration)s | $runVerdict |" + "`n"
}

# Regressions section
$report += "`n"
$report += "## Regressions" + "`n"
$report += "`n"

$hasRegressions = $false
if ($verdicts[0] -eq "REGRESSED") {
    $report += "- **Pass Rate**: Decreased from $(Format-Percentage $baselinePassRate) to $(Format-Percentage $currentPassRate)" + "`n"
    $hasRegressions = $true
}
if ($verdicts[1] -eq "REGRESSED") {
    $fmtBlTokens = Format-Number $baselineTokens
    $fmtCrTokens = Format-Number $currentTokens
    $report += "- **Total Tokens**: Increased by >15% ($fmtBlTokens --> $fmtCrTokens)" + "`n"
    $hasRegressions = $true
}
if ($verdicts[2] -eq "REGRESSED") {
    $report += "- **Duration**: Increased by >20% ($($baselineDuration)s --> $($currentDuration)s)" + "`n"
    $hasRegressions = $true
}

if (-not $hasRegressions) {
    $report += "None detected" + "`n"
}

# Improvements section
$report += "`n"
$report += "## Improvements" + "`n"
$report += "`n"

$hasImprovements = $false
if ($verdicts[0] -eq "IMPROVED") {
    $report += "- **Pass Rate**: Increased from $(Format-Percentage $baselinePassRate) to $(Format-Percentage $currentPassRate)" + "`n"
    $hasImprovements = $true
}
if ($verdicts[1] -eq "IMPROVED") {
    $fmtBlTokens = Format-Number $baselineTokens
    $fmtCrTokens = Format-Number $currentTokens
    $report += "- **Total Tokens**: Decreased by >10% ($fmtBlTokens --> $fmtCrTokens)" + "`n"
    $hasImprovements = $true
}
if ($verdicts[2] -eq "IMPROVED") {
    $report += "- **Duration**: Decreased by >10% ($($baselineDuration)s --> $($currentDuration)s)" + "`n"
    $hasImprovements = $true
}

if (-not $hasImprovements) {
    $report += "None detected" + "`n"
}

# Write report
Set-Content -Path $OutputPath -Value $report

# Cleanup
Remove-Item $tempDir -Recurse -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Report Generated" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Status "Report saved to: $OutputPath" -Type Success
Write-Host ""
$verdictType = if ($overallVerdict -eq "REGRESSED") { "Error" } elseif ($overallVerdict -eq "IMPROVED") { "Success" } else { "Info" }
Write-Status "Overall Verdict: $emojiOverall $overallVerdict" -Type $verdictType
Write-Host ""
