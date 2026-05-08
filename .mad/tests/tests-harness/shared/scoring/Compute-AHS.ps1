# Compute-AHS.ps1 - Architecture Health Score
#
# Computes a weighted pass rate for architecture rules, considering
# severity levels. Critical rules have higher weight than advisory ones.

$ErrorActionPreference = 'Stop'

function Compute-AHS {
    <#
    .SYNOPSIS
        Compute Architecture Health Score as a weighted pass rate.
    .DESCRIPTION
        Given the total and passing rule counts, plus optional severity weights,
        computes both a simple pass rate and a severity-weighted score.
        Critical rules carry more weight than informational ones.
    .PARAMETER TotalRules
        Total number of architecture rules evaluated.
    .PARAMETER PassingRules
        Number of rules that passed.
    .PARAMETER SeverityWeights
        Optional array of per-rule severity weights.
        Each item: @{rule='no-circular-deps'; severity='critical'; weight=3; passed=$true}
        If not provided, all rules have equal weight.
    .EXAMPLE
        Compute-AHS -TotalRules 10 -PassingRules 8
        # Returns: @{ score = 0.8; passing = 8; total = 10; weighted_score = 0.8 }
    .EXAMPLE
        $weights = @(
            @{rule='no-circular-deps'; severity='critical'; weight=3; passed=$true},
            @{rule='naming-conventions'; severity='advisory'; weight=1; passed=$false}
        )
        Compute-AHS -TotalRules 2 -PassingRules 1 -SeverityWeights $weights
    #>
    param(
        [Parameter(Mandatory)][int]$TotalRules,
        [Parameter(Mandatory)][int]$PassingRules,
        [array]$SeverityWeights
    )

    # Simple pass rate
    $score = if ($TotalRules -gt 0) {
        [Math]::Round($PassingRules / $TotalRules, 4)
    } else { 0.0 }

    # Weighted score using severity weights
    $weightedScore = $score  # Default to simple score if no weights provided
    if ($SeverityWeights -and $SeverityWeights.Count -gt 0) {
        $totalWeight = 0.0
        $passedWeight = 0.0
        foreach ($sw in $SeverityWeights) {
            $w = [double]$sw.weight
            $totalWeight += $w
            if ($sw.passed -eq $true) {
                $passedWeight += $w
            }
        }
        if ($totalWeight -gt 0) {
            $weightedScore = [Math]::Round($passedWeight / $totalWeight, 4)
        }
    }

    return @{
        score          = $score
        passing        = $PassingRules
        total          = $TotalRules
        weighted_score = $weightedScore
    }
}
