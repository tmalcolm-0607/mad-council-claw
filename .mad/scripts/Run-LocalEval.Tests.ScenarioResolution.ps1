# Pester tests for scenario resolution logic in Run-LocalEval.ps1
# Run: Invoke-Pester -Path .\Run-LocalEval.Tests.ScenarioResolution.ps1
#
# Compatible with Pester 3.x (no BeforeAll at top level)
# Tests the Resolve-ScenarioList helper function.

$scriptPath = Join-Path $PSScriptRoot "Run-LocalEval.ps1"
$scriptContent = Get-Content $scriptPath -Raw

# Extract Resolve-ScenarioList function using brace counting
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

$funcDef = Extract-FunctionDef -Source $scriptContent -Name 'Resolve-ScenarioList'
if ($funcDef) {
    Invoke-Expression $funcDef
} else {
    throw "Could not extract Resolve-ScenarioList from Run-LocalEval.ps1"
}

Describe "Resolve-ScenarioList" {

    Context "Meta-scenario: smoke" {
        It "Returns all 7 smoke scenarios" {
            $result = @(Resolve-ScenarioList -Scenario "smoke")
            $result.Count | Should Be 7
            ($result -contains "investigate-and-implement") | Should Be $true
            ($result -contains "review-and-fix") | Should Be $true
            ($result -contains "coverage-loop") | Should Be $true
            ($result -contains "rule-adherence") | Should Be $true
            ($result -contains "negative-constraints") | Should Be $true
            ($result -contains "refactor-extract-service") | Should Be $true
            ($result -contains "cross-project-dependency") | Should Be $true
        }

        It "Does not include enterprise scenarios" {
            $result = @(Resolve-ScenarioList -Scenario "smoke")
            ($result -contains "enterprise-cosmos-entity") | Should Be $false
        }
    }

    Context "Meta-scenario: enterprise" {
        It "Returns only enterprise scenarios" {
            $result = @(Resolve-ScenarioList -Scenario "enterprise")
            $result.Count | Should Be 1
            ($result -contains "enterprise-cosmos-entity") | Should Be $true
        }
    }

    Context "Meta-scenario: all" {
        It "Returns enterprise + smoke scenarios" {
            $result = @(Resolve-ScenarioList -Scenario "all")
            $result.Count | Should Be 8
            ($result -contains "enterprise-cosmos-entity") | Should Be $true
            ($result -contains "investigate-and-implement") | Should Be $true
        }
    }

    Context "No scenario specified (default)" {
        It "Returns only enterprise scenarios" {
            $result = @(Resolve-ScenarioList -Scenario $null)
            $result.Count | Should Be 1
            ($result -contains "enterprise-cosmos-entity") | Should Be $true
        }

        It "Returns only enterprise scenarios for empty string" {
            $result = @(Resolve-ScenarioList -Scenario "")
            $result.Count | Should Be 1
            ($result -contains "enterprise-cosmos-entity") | Should Be $true
        }
    }

    Context "Individual scenario name" {
        It "Returns single scenario when valid name given" {
            $result = @(Resolve-ScenarioList -Scenario "coverage-loop")
            $result.Count | Should Be 1
            $result[0] | Should Be "coverage-loop"
        }

        It "Throws for unknown scenario name" {
            { Resolve-ScenarioList -Scenario "nonexistent-scenario" } | Should Throw "Unknown scenario"
        }
    }

    Context "Comma-separated scenarios" {
        It "Returns multiple scenarios from comma-separated input" {
            $result = @(Resolve-ScenarioList -Scenario "rule-adherence,coverage-loop")
            $result.Count | Should Be 2
            ($result -contains "rule-adherence") | Should Be $true
            ($result -contains "coverage-loop") | Should Be $true
        }

        It "Throws if any scenario in comma list is invalid" {
            { Resolve-ScenarioList -Scenario "rule-adherence,bogus" } | Should Throw "Unknown scenario"
        }
    }
}
