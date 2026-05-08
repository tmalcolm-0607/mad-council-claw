# Compare-BaselineTreatment.ps1 - A/B comparison framework for eval results
#
# Extracted from Run-LocalEval.ps1: Build-ScenarioMetrics, Format-MetricsComparison, Get-CostRegression
# These functions form the baseline/treatment comparison framework used for
# evaluating configuration changes (treatment) against no-config runs (baseline).

$ErrorActionPreference = 'Stop'

function Build-ScenarioMetrics {
    <#
    .SYNOPSIS
        Build a standardized metrics hashtable for a scenario run.
    .DESCRIPTION
        Creates an ordered hashtable containing assertion pass rate, cost, turns,
        duration, and gate results for comparison.
    #>
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
    <#
    .SYNOPSIS
        Format a side-by-side comparison of baseline vs treatment metrics.
    .DESCRIPTION
        Produces a table of metric deltas and computes the discrimination delta
        (difference in assertion pass rates between treatment and baseline).
    #>
    param(
        [Parameter(Mandatory)][hashtable]$BaselineMetrics,
        [Parameter(Mandatory)][hashtable]$TreatmentMetrics
    )

    $metricDefs = @(
        @{ Name = 'Assertion Pass Rate'; Key = 'assertion_pass_rate'; IsNumeric = $true }
        @{ Name = 'Total Cost (USD)';    Key = 'total_cost_usd';     IsNumeric = $true }
        @{ Name = 'Num Turns';           Key = 'num_turns';          IsNumeric = $true }
        @{ Name = 'Duration (sec)';      Key = 'duration_seconds';   IsNumeric = $true }
        @{ Name = 'Build Gate';          Key = 'build_gate';         IsNumeric = $false }
        @{ Name = 'Test Gate';           Key = 'test_gate';          IsNumeric = $false }
    )

    $rows = @()
    foreach ($def in $metricDefs) {
        $bVal = $BaselineMetrics[$def.Key]
        $tVal = $TreatmentMetrics[$def.Key]

        $bDisplay = if ($null -eq $bVal) { 'N/A' } else { $bVal }
        $tDisplay = if ($null -eq $tVal) { 'N/A' } else { $tVal }

        $delta = 'N/A'
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
    $bPass = $BaselineMetrics['assertion_pass_rate']
    $tPass = $TreatmentMetrics['assertion_pass_rate']
    $discriminationDelta = if ($null -ne $bPass -and $null -ne $tPass) {
        [Math]::Round([double]$tPass - [double]$bPass, 4)
    } else { $null }

    return @{
        Rows                = $rows
        DiscriminationDelta = $discriminationDelta
    }
}

function Get-CostRegression {
    <#
    .SYNOPSIS
        Detect cost regressions by comparing current result against a rolling window.
    .DESCRIPTION
        Checks if total cost or per-scenario cost exceeds 2x the rolling average
        of the last 10 previous runs. Returns a hashtable with cost_regression flag.
    #>
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
