# Pester tests for MVP metrics and CLI comparison table in Run-LocalEval.ps1
# Run: Invoke-Pester -Path .\Run-LocalEval.Tests.Metrics.ps1
#
# Compatible with Pester 3.x (no BeforeAll at top level)
# Tests the Build-ScenarioMetrics and Format-MetricsComparison helper functions.

$scriptPath = Join-Path $PSScriptRoot "Run-LocalEval.ps1"
$scriptContent = Get-Content $scriptPath -Raw

# Extract function using brace counting
function Extract-FunctionDef {
    param([string]$Source, [string]$Name)
    $marker = "function $Name {"
    $start = $Source.IndexOf($marker)
    if ($start -lt 0) {
        $marker = "function $Name`r`n{"
        $start = $Source.IndexOf($marker)
    }
    if ($start -lt 0) { return $null }
    $depth = 0; $inFunc = $false
    for ($i = $start; $i -lt $Source.Length; $i++) {
        if ($Source[$i] -eq '{') { $depth++; $inFunc = $true }
        if ($Source[$i] -eq '}') { $depth-- }
        if ($inFunc -and $depth -eq 0) {
            return $Source.Substring($start, $i + 1 - $start)
        }
    }
    return $null
}

$buildMetricsDef = Extract-FunctionDef -Source $scriptContent -Name 'Build-ScenarioMetrics'
if ($buildMetricsDef) {
    Invoke-Expression $buildMetricsDef
} else {
    throw "Could not extract Build-ScenarioMetrics from Run-LocalEval.ps1"
}

$formatCompDef = Extract-FunctionDef -Source $scriptContent -Name 'Format-MetricsComparison'
if ($formatCompDef) {
    Invoke-Expression $formatCompDef
} else {
    throw "Could not extract Format-MetricsComparison from Run-LocalEval.ps1"
}

# ---------------------------------------------------------------------------
# Build-ScenarioMetrics tests
# ---------------------------------------------------------------------------

Describe "Build-ScenarioMetrics" {

    Context "Basic metric computation" {
        It "Computes all 6 metrics from valid inputs" {
            $metrics = Build-ScenarioMetrics `
                -AssertionsPassed 8 -AssertionsTotal 10 `
                -CostUsd 1.5 -NumTurns 12 `
                -DurationSeconds 120 `
                -BuildPassed $true -TestsPassed $true

            $metrics.assertion_pass_rate | Should Be 0.8
            $metrics.total_cost_usd | Should Be 1.5
            $metrics.num_turns | Should Be 12
            $metrics.duration_seconds | Should Be 120
            $metrics.build_gate | Should Be $true
            $metrics.test_gate | Should Be $true
            $metrics.discrimination_delta | Should Be $null
        }
    }

    Context "Edge cases" {
        It "Returns 0.0 pass rate when no assertions exist" {
            $metrics = Build-ScenarioMetrics `
                -AssertionsPassed 0 -AssertionsTotal 0 `
                -CostUsd 0.5 -NumTurns 5 `
                -DurationSeconds 60 `
                -BuildPassed $false -TestsPassed $false

            $metrics.assertion_pass_rate | Should Be 0.0
        }

        It "Returns perfect pass rate for all-passing assertions" {
            $metrics = Build-ScenarioMetrics `
                -AssertionsPassed 5 -AssertionsTotal 5 `
                -CostUsd 0.5 -NumTurns 5 `
                -DurationSeconds 60 `
                -BuildPassed $true -TestsPassed $true

            $metrics.assertion_pass_rate | Should Be 1.0
        }

        It "Handles null num_turns gracefully" {
            $metrics = Build-ScenarioMetrics `
                -AssertionsPassed 3 -AssertionsTotal 5 `
                -CostUsd 0.5 -NumTurns $null `
                -DurationSeconds 60 `
                -BuildPassed $true -TestsPassed $false

            $metrics.num_turns | Should Be $null
        }

        It "Handles zero cost" {
            $metrics = Build-ScenarioMetrics `
                -AssertionsPassed 3 -AssertionsTotal 5 `
                -CostUsd 0 -NumTurns 5 `
                -DurationSeconds 60 `
                -BuildPassed $false -TestsPassed $false

            $metrics.total_cost_usd | Should Be 0
        }
    }

    Context "Assertion pass rate precision" {
        It "Rounds to 4 decimal places" {
            $metrics = Build-ScenarioMetrics `
                -AssertionsPassed 1 -AssertionsTotal 3 `
                -CostUsd 1.0 -NumTurns 5 `
                -DurationSeconds 60 `
                -BuildPassed $true -TestsPassed $true

            $metrics.assertion_pass_rate | Should Be 0.3333
        }
    }
}

# ---------------------------------------------------------------------------
# Format-MetricsComparison tests
# ---------------------------------------------------------------------------

Describe "Format-MetricsComparison" {

    Context "Basic comparison" {
        It "Returns comparison rows for all 6 metrics" {
            $baseline = [ordered]@{
                assertion_pass_rate = 0.6; total_cost_usd = 1.0
                num_turns = 10; duration_seconds = 100
                build_gate = $false; test_gate = $false
            }
            $treatment = [ordered]@{
                assertion_pass_rate = 0.9; total_cost_usd = 1.5
                num_turns = 15; duration_seconds = 120
                build_gate = $true; test_gate = $true
            }

            $result = Format-MetricsComparison -BaselineMetrics $baseline -TreatmentMetrics $treatment

            $result.Rows.Count | Should Be 6
            $result.DiscriminationDelta | Should Be 0.3
        }

        It "Computes correct delta for assertion pass rate" {
            $baseline = [ordered]@{
                assertion_pass_rate = 0.5; total_cost_usd = 1.0
                num_turns = 10; duration_seconds = 100
                build_gate = $false; test_gate = $false
            }
            $treatment = [ordered]@{
                assertion_pass_rate = 0.8; total_cost_usd = 1.5
                num_turns = 15; duration_seconds = 120
                build_gate = $true; test_gate = $true
            }

            $result = Format-MetricsComparison -BaselineMetrics $baseline -TreatmentMetrics $treatment

            $assertRow = $result.Rows | Where-Object { $_.Metric -eq "Assertion Pass Rate" }
            $assertRow.Delta | Should Be 0.3
        }
    }

    Context "Null handling" {
        It "Shows N/A for null num_turns" {
            $baseline = [ordered]@{
                assertion_pass_rate = 0.6; total_cost_usd = 1.0
                num_turns = $null; duration_seconds = 100
                build_gate = $false; test_gate = $false
            }
            $treatment = [ordered]@{
                assertion_pass_rate = 0.9; total_cost_usd = 1.5
                num_turns = 15; duration_seconds = 120
                build_gate = $true; test_gate = $true
            }

            $result = Format-MetricsComparison -BaselineMetrics $baseline -TreatmentMetrics $treatment

            $turnsRow = $result.Rows | Where-Object { $_.Metric -eq "Num Turns" }
            $turnsRow.Baseline | Should Be "N/A"
            $turnsRow.Delta | Should Be "N/A"
        }
    }

    Context "Negative delta (regression)" {
        It "Shows negative delta when treatment is worse" {
            $baseline = [ordered]@{
                assertion_pass_rate = 0.9; total_cost_usd = 1.0
                num_turns = 10; duration_seconds = 100
                build_gate = $true; test_gate = $true
            }
            $treatment = [ordered]@{
                assertion_pass_rate = 0.5; total_cost_usd = 2.0
                num_turns = 20; duration_seconds = 200
                build_gate = $false; test_gate = $false
            }

            $result = Format-MetricsComparison -BaselineMetrics $baseline -TreatmentMetrics $treatment

            $result.DiscriminationDelta | Should Be -0.4
        }
    }

    Context "Boolean gate deltas" {
        It "Shows delta as N/A for boolean gate metrics" {
            $baseline = [ordered]@{
                assertion_pass_rate = 0.5; total_cost_usd = 1.0
                num_turns = 10; duration_seconds = 100
                build_gate = $false; test_gate = $false
            }
            $treatment = [ordered]@{
                assertion_pass_rate = 0.8; total_cost_usd = 1.5
                num_turns = 15; duration_seconds = 120
                build_gate = $true; test_gate = $true
            }

            $result = Format-MetricsComparison -BaselineMetrics $baseline -TreatmentMetrics $treatment

            $buildRow = $result.Rows | Where-Object { $_.Metric -eq "Build Gate" }
            $buildRow.Delta | Should Be "N/A"

            $testRow = $result.Rows | Where-Object { $_.Metric -eq "Test Gate" }
            $testRow.Delta | Should Be "N/A"
        }
    }
}
