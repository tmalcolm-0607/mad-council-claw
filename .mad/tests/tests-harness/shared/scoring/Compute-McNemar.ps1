# Compute-McNemar.ps1 - McNemar's test for statistical significance
#
# Used to determine whether a configuration change (treatment) produces
# a statistically significant difference in pass/fail outcomes compared
# to a baseline run.

$ErrorActionPreference = 'Stop'

function Compute-McNemar {
    <#
    .SYNOPSIS
        Compute McNemar's chi-squared statistic for paired pass/fail data.
    .DESCRIPTION
        Given the counts from a 2x2 contingency table of paired binary outcomes
        (baseline pass/fail x treatment pass/fail), computes the McNemar chi-squared
        statistic with continuity correction and an approximate p-value.

        The test determines whether the marginal proportions differ -- i.e., whether
        the treatment produces significantly different pass rates than the baseline.
    .PARAMETER BothPass
        Count of assertions where both baseline and treatment passed.
    .PARAMETER BaseOnly
        Count of assertions where baseline passed but treatment failed (b).
    .PARAMETER TreatOnly
        Count of assertions where treatment passed but baseline failed (c).
    .PARAMETER BothFail
        Count of assertions where both baseline and treatment failed.
    .EXAMPLE
        Compute-McNemar -BothPass 45 -BaseOnly 5 -TreatOnly 15 -BothFail 5
        # Returns chi_squared, p_value_approx, significant
    #>
    param(
        [Parameter(Mandatory)][int]$BothPass,
        [Parameter(Mandatory)][int]$BaseOnly,
        [Parameter(Mandatory)][int]$TreatOnly,
        [Parameter(Mandatory)][int]$BothFail
    )

    $b = $BaseOnly
    $c = $TreatOnly

    # McNemar chi-squared with continuity correction: (|b-c| - 1)^2 / (b+c)
    $denominator = $b + $c
    if ($denominator -eq 0) {
        return @{
            chi_squared   = 0.0
            p_value_approx = 1.0
            significant    = $false
            note           = 'No discordant pairs (b+c=0); test not applicable.'
        }
    }

    $corrected = [Math]::Max(0, [Math]::Abs($b - $c) - 1)
    $numerator = [Math]::Pow($corrected, 2)

    $chiSquared = [Math]::Round($numerator / $denominator, 4)

    # Approximate p-value using chi-squared distribution with 1 df
    # Using the survival function approximation: P(X > x) for chi-sq(1)
    # For chi-sq(1), P(X > x) = 2 * (1 - Phi(sqrt(x))) where Phi is the standard normal CDF
    # Approximation using the complementary error function:
    $z = [Math]::Sqrt($chiSquared)
    # Approximate standard normal survival: P(Z > z) using erfc
    # erfc(x) = 2/sqrt(pi) * integral(exp(-t^2), t=x..inf)
    # P(Z > z) = 0.5 * erfc(z / sqrt(2))
    # For chi-sq(1): p = 2 * P(Z > z) = erfc(z / sqrt(2))
    $pValue = 1.0
    if ($chiSquared -gt 0) {
        # Use a rational approximation for the normal CDF
        $t = 1.0 / (1.0 + 0.2316419 * $z)
        $d = 0.3989422804014327  # 1/sqrt(2*pi)
        $normalPdf = $d * [Math]::Exp(-0.5 * $z * $z)
        $poly = ((((1.330274429 * $t - 1.821255978) * $t + 1.781477937) * $t - 0.356563782) * $t + 0.319381530) * $t
        $normalCdf = 1.0 - $normalPdf * $poly
        $pValue = [Math]::Round(2.0 * (1.0 - $normalCdf), 6)
        if ($pValue -lt 0) { $pValue = 0.0 }
    }

    return @{
        chi_squared    = $chiSquared
        p_value_approx = $pValue
        significant    = ($pValue -lt 0.05)
    }
}
