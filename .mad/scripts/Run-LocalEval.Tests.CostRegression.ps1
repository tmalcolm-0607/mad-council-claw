# Pester tests for cost regression detection in Run-LocalEval.ps1
# Run: Invoke-Pester -Path .\Run-LocalEval.Tests.CostRegression.ps1
#
# Compatible with Pester 3.x (no BeforeAll at top level)
# Tests the Get-CostRegression helper function.

$scriptPath = Join-Path $PSScriptRoot "Run-LocalEval.ps1"
$scriptContent = Get-Content $scriptPath -Raw

# Extract Get-CostRegression function using brace counting
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

$funcDef = Extract-FunctionDef -Source $scriptContent -Name 'Get-CostRegression'
if ($funcDef) {
    Invoke-Expression $funcDef
} else {
    throw "Could not extract Get-CostRegression from Run-LocalEval.ps1"
}

Describe "Get-CostRegression" {

    Context "No previous runs (first run)" {
        It "Returns no regression when there are no previous results" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "investigate-and-implement"; cost_usd = 1.50 }
                )
                summary = [ordered]@{ total_cost_usd = 1.50 }
            }
            $result = Get-CostRegression -CurrentResult $current -PreviousResults @()
            $result.cost_regression | Should Be $false
        }
    }

    Context "Single previous run, no regression" {
        It "Returns no regression when cost is within 2x average" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 1.50 }
                )
                summary = [ordered]@{ total_cost_usd = 1.50 }
            }
            $previous = @(
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.00 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 1.00 }
                }
            )
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $false
        }
    }

    Context "Scenario cost regression detected" {
        It "Returns regression when scenario cost exceeds 2x average" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 5.00 }
                )
                summary = [ordered]@{ total_cost_usd = 5.00 }
            }
            $previous = @(
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.00 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 1.00 }
                },
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.20 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 1.20 }
                }
            )
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $true
        }
    }

    Context "Total cost regression detected" {
        It "Returns regression when total cost exceeds 2x average" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 3.00 }
                    [ordered]@{ name = "scenario-b"; cost_usd = 3.00 }
                )
                summary = [ordered]@{ total_cost_usd = 6.00 }
            }
            $previous = @(
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.00 }
                        [PSCustomObject]@{ name = "scenario-b"; cost_usd = 1.00 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 2.00 }
                }
            )
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $true
        }
    }

    Context "Previous results missing cost data" {
        It "Skips runs that lack cost_usd and computes average from the rest" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 1.50 }
                )
                summary = [ordered]@{ total_cost_usd = 1.50 }
            }
            $previous = @(
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.00 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 1.00 }
                },
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a" }
                    )
                    summary = [PSCustomObject]@{}
                }
            )
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $false
        }
    }

    Context "Rolling window capped at 10" {
        It "Uses only the last 10 previous runs" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 2.50 }
                )
                summary = [ordered]@{ total_cost_usd = 2.50 }
            }
            # 12 previous runs: first 2 have very low cost (0.10), last 10 have 2.00
            # Rolling window of last 10 => average = 2.00, 2x = 4.00 => 2.50 < 4.00 => no regression
            $previous = @()
            for ($i = 0; $i -lt 2; $i++) {
                $previous += [PSCustomObject]@{
                    scenarios = @([PSCustomObject]@{ name = "scenario-a"; cost_usd = 0.10 })
                    summary = [PSCustomObject]@{ total_cost_usd = 0.10 }
                }
            }
            for ($i = 0; $i -lt 10; $i++) {
                $previous += [PSCustomObject]@{
                    scenarios = @([PSCustomObject]@{ name = "scenario-a"; cost_usd = 2.00 })
                    summary = [PSCustomObject]@{ total_cost_usd = 2.00 }
                }
            }
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $false
        }
    }

    Context "Exactly at 2x threshold" {
        It "Does not flag regression when cost equals exactly 2x (strictly greater than)" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 2.00 }
                )
                summary = [ordered]@{ total_cost_usd = 2.00 }
            }
            $previous = @(
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.00 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 1.00 }
                }
            )
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $false
        }
    }

    Context "Multiple scenarios, only one regressed" {
        It "Flags regression if any single scenario exceeds 2x" {
            $current = [ordered]@{
                scenarios = @(
                    [ordered]@{ name = "scenario-a"; cost_usd = 1.00 }
                    [ordered]@{ name = "scenario-b"; cost_usd = 5.00 }
                )
                summary = [ordered]@{ total_cost_usd = 6.00 }
            }
            $previous = @(
                [PSCustomObject]@{
                    scenarios = @(
                        [PSCustomObject]@{ name = "scenario-a"; cost_usd = 1.00 }
                        [PSCustomObject]@{ name = "scenario-b"; cost_usd = 1.00 }
                    )
                    summary = [PSCustomObject]@{ total_cost_usd = 2.00 }
                }
            )
            $result = Get-CostRegression -CurrentResult $current -PreviousResults $previous
            $result.cost_regression | Should Be $true
        }
    }
}
