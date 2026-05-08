# Invoke-MultiDimensionalScore.ps1 - Multi-dimensional scoring for eval results
#
# Computes a composite score from multiple weighted dimensions using either
# weighted average or geometric mean aggregation.

$ErrorActionPreference = 'Stop'

function Invoke-MultiDimensionalScore {
    <#
    .SYNOPSIS
        Compute a composite score from multiple weighted dimensions.
    .DESCRIPTION
        Given an array of dimension objects (each with name, score, weight),
        computes a composite score using the specified aggregation method.
        Supports weighted_average and geometric_mean methods.
    .PARAMETER Dimensions
        Array of hashtables, each with: name (string), score (double 0-1), weight (double).
        Example: @(@{name='accuracy'; score=0.85; weight=0.3}, @{name='completeness'; score=0.9; weight=0.7})
    .PARAMETER Method
        Aggregation method: 'weighted_average' (default) or 'geometric_mean'.
    .EXAMPLE
        $dims = @(
            @{name='accuracy'; score=0.85; weight=0.3},
            @{name='completeness'; score=0.9; weight=0.7}
        )
        Invoke-MultiDimensionalScore -Dimensions $dims
    #>
    param(
        [Parameter(Mandatory)][array]$Dimensions,
        [ValidateSet('weighted_average', 'geometric_mean')]
        [string]$Method = 'weighted_average'
    )

    if ($Dimensions.Count -eq 0) {
        return @{
            dimensions = @()
            composite  = 0.0
            method     = $Method
        }
    }

    $composite = 0.0

    switch ($Method) {
        'weighted_average' {
            $totalWeight = 0.0
            $weightedSum = 0.0
            foreach ($dim in $Dimensions) {
                $w = [double]$dim.weight
                $s = [double]$dim.score
                $weightedSum += $w * $s
                $totalWeight += $w
            }
            if ($totalWeight -gt 0) {
                $composite = [Math]::Round($weightedSum / $totalWeight, 4)
            }
        }
        'geometric_mean' {
            # Geometric mean of weighted scores: (prod(score_i ^ weight_i)) ^ (1/sum(weights))
            $totalWeight = 0.0
            $logSum = 0.0
            $hasZero = $false
            foreach ($dim in $Dimensions) {
                $w = [double]$dim.weight
                $s = [double]$dim.score
                $totalWeight += $w
                if ($s -le 0) {
                    $hasZero = $true
                    break
                }
                $logSum += $w * [Math]::Log($s)
            }
            if ($hasZero) {
                $composite = 0.0
            } elseif ($totalWeight -gt 0) {
                $composite = [Math]::Round([Math]::Exp($logSum / $totalWeight), 4)
            }
        }
    }

    return @{
        dimensions = $Dimensions
        composite  = $composite
        method     = $Method
    }
}
