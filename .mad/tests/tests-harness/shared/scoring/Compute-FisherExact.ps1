# Compute-FisherExact.ps1 - Exact binomial test for small-sample significance
#
# For eval scenarios with fewer than 25 observations, McNemar's chi-squared
# approximation is unreliable. This script uses an exact binomial CDF to test
# whether the observed success rate differs significantly from a hypothesized
# probability.
#
# Review finding: "Use Fisher's exact test not McNemar for n<25."

$ErrorActionPreference = 'Stop'

function Compute-FisherExact {
    <#
    .SYNOPSIS
        Exact binomial test for small samples.
    .DESCRIPTION
        Computes a two-sided exact binomial test. Under H0, the number of
        successes follows Binomial(Trials, HypothesizedProbability). The p-value
        is P(X >= Successes) for a one-sided test of "treatment is better than
        chance," then doubled for two-sided. Uses direct binomial CDF summation.

        Appropriate when the number of trials is small (n < 25) where
        chi-squared approximations (McNemar) break down.
    .PARAMETER Successes
        Number of observed successes (e.g., assertions that passed under treatment
        but failed under baseline -- discordant pairs favoring treatment).
    .PARAMETER Trials
        Total number of trials (e.g., total discordant pairs).
    .PARAMETER HypothesizedProbability
        Null hypothesis probability. Default 0.5 (no difference between
        baseline and treatment for discordant pairs).
    .PARAMETER Alpha
        Significance level. Default 0.05.
    .EXAMPLE
        Compute-FisherExact -Successes 6 -Trials 7 -HypothesizedProbability 0.5
        # Returns @{p_value=0.125; significant=$false; test='fisher_exact'; ...}
    .EXAMPLE
        Compute-FisherExact -Successes 7 -Trials 7
        # Returns @{p_value=0.015625; significant=$true; test='fisher_exact'; ...}
    #>
    param(
        [Parameter(Mandatory)][int]$Successes,
        [Parameter(Mandatory)][int]$Trials,
        [double]$HypothesizedProbability = 0.5,
        [double]$Alpha = 0.05
    )

    # Validate inputs
    if ($Trials -lt 0) {
        throw "Trials must be non-negative. Got: $Trials"
    }
    if ($Successes -lt 0 -or $Successes -gt $Trials) {
        throw "Successes must be between 0 and Trials. Got: Successes=$Successes, Trials=$Trials"
    }
    if ($HypothesizedProbability -le 0 -or $HypothesizedProbability -ge 1) {
        throw "HypothesizedProbability must be in (0, 1). Got: $HypothesizedProbability"
    }

    # Edge case: no trials
    if ($Trials -eq 0) {
        return @{
            p_value                  = 1.0
            significant              = $false
            test                     = 'fisher_exact'
            successes                = $Successes
            trials                   = $Trials
            hypothesized_probability = $HypothesizedProbability
            alpha                    = $Alpha
            note                     = 'No trials; test not applicable.'
        }
    }

    # Compute binomial PMF: P(X = k) = C(n,k) * p^k * (1-p)^(n-k)
    # Use log-space to avoid overflow with factorials
    $p = $HypothesizedProbability
    $q = 1.0 - $p
    $n = $Trials

    # Log-binomial-coefficient using Stirling-free log-gamma
    # ln(C(n,k)) = ln(n!) - ln(k!) - ln((n-k)!)
    function Get-LogBinomPMF {
        param([int]$k, [int]$total, [double]$prob)
        $logCoeff = (Get-LogFactorial $total) - (Get-LogFactorial $k) - (Get-LogFactorial ($total - $k))
        $logPMF = $logCoeff + $k * [Math]::Log($prob) + ($total - $k) * [Math]::Log(1.0 - $prob)
        return $logPMF
    }

    # Pre-compute log factorials for 0..n
    $script:logFactCache = @(0.0) # ln(0!) = 0
    for ($i = 1; $i -le $n; $i++) {
        $script:logFactCache += $script:logFactCache[$i - 1] + [Math]::Log($i)
    }

    function Get-LogFactorial {
        param([int]$x)
        if ($x -le 0) { return 0.0 }
        return $script:logFactCache[$x]
    }

    # Compute the PMF for the observed value
    $observedLogPMF = Get-LogBinomPMF -k $Successes -total $n -prob $p
    $observedPMF = [Math]::Exp($observedLogPMF)

    # Two-sided p-value: sum of all PMFs <= observed PMF (exact method)
    # This is the standard "minimum likelihood" two-sided exact test
    $pValue = 0.0
    for ($k = 0; $k -le $n; $k++) {
        $logPMF = Get-LogBinomPMF -k $k -total $n -prob $p
        $pmf = [Math]::Exp($logPMF)
        if ($pmf -le ($observedPMF + 1e-12)) {
            # Include values as extreme or more extreme than observed
            $pValue += $pmf
        }
    }

    # Clamp to [0, 1] for floating-point safety
    $pValue = [Math]::Min(1.0, [Math]::Max(0.0, $pValue))
    $pValue = [Math]::Round($pValue, 6)

    $significant = $pValue -lt $Alpha

    return @{
        p_value                  = $pValue
        significant              = $significant
        test                     = 'fisher_exact'
        successes                = $Successes
        trials                   = $Trials
        hypothesized_probability = $HypothesizedProbability
        alpha                    = $Alpha
    }
}
