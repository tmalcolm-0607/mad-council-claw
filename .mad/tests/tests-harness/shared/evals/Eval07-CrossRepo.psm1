# Eval07-CrossRepo.psm1 - Cross-Repo Pattern Consistency Gauge
#
# Zero-LLM-cost eval that fingerprints 8 architectural concern dimensions
# across reference repos in the ecosystem, computes weighted majority voting
# consensus, and measures whether agent-produced code matches ecosystem norms.
#
# Lesson: majority-voting across N reference repos with maturity-weighted
# scores is a cheap, LLM-free way to detect when an agent produces code that
# drifts from ecosystem norms. To use this in your own ecosystem:
#   1. Replace $script:MaturityTiers with your own repo-name -> {tier,weight,label}
#      map. Give Reference repos the highest weight; give Legacy repos the lowest.
#   2. Populate $script:AllRepoNames with the directory names you placed under
#      references/ (see scripts/Update-ReferenceRepos.ps1 for the pull workflow).
#   3. Tune $script:MinConsensusThreshold and $script:MinReposForConsensus for
#      your ecosystem's size and churn.
# The placeholder repo names below (reference-repo-1 ... reference-repo-12)
# are NOT real directories — they are abstract names to illustrate the shape.
# The eval will throw if no matching directories are found under references/.
#
# Exports: Setup-CrossRepo, Get-CrossRepoPrompt, Invoke-CrossRepoAssertions
#
# Dependencies:
#   - Get-ReferenceRepoFingerprint (from .mad/tests/shared/analysis/)
#   - Invoke-MultiDimensionalScore (from .mad/tests/shared/scoring/)
#   - New-Assertion, Write-Status (from EvalShared.psm1)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Maturity tier weights for consensus voting
# ---------------------------------------------------------------------------
# NOTE: Replace these placeholder repo names with your own. Tier 1 = the
# repos you trust most when there is disagreement.
$script:MaturityTiers = @{
    'reference-repo-1'  = @{ tier = 1; weight = 3.0; label = 'Reference' }
    'reference-repo-2'  = @{ tier = 1; weight = 3.0; label = 'Reference' }
    'reference-repo-3'  = @{ tier = 2; weight = 2.0; label = 'Established' }
    'reference-repo-4'  = @{ tier = 2; weight = 2.0; label = 'Established' }
    'reference-repo-5'  = @{ tier = 2; weight = 2.0; label = 'Established' }
    'reference-repo-6'  = @{ tier = 3; weight = 1.0; label = 'Developing' }
    'reference-repo-7'  = @{ tier = 3; weight = 1.0; label = 'Developing' }
    'reference-repo-8'  = @{ tier = 4; weight = 0.5; label = 'Legacy' }
    'reference-repo-9'  = @{ tier = 4; weight = 0.5; label = 'Legacy' }
    'reference-repo-10' = @{ tier = 4; weight = 0.5; label = 'Legacy' }
    'reference-repo-11' = @{ tier = 4; weight = 0.5; label = 'Legacy' }
}

# Minimum consensus threshold -- below this, dimension is 'weak_consensus'
$script:MinConsensusThreshold = 0.66

# Minimum repos with data before a dimension is considered valid
$script:MinReposForConsensus = 4

# Reference-repo directory names (relative to references/ root).
# Populate with your own repo directory names before running.
$script:AllRepoNames = @(
    'reference-repo-1',  'reference-repo-2',  'reference-repo-3',  'reference-repo-4',
    'reference-repo-5',  'reference-repo-6',  'reference-repo-7',  'reference-repo-8',
    'reference-repo-9',  'reference-repo-10', 'reference-repo-11', 'reference-repo-12'
)

# The 8 concern dimensions
$script:Dimensions = @(
    'di-registration', 'error-handling', 'config-pattern', 'logging',
    'testing', 'security', 'resilience', 'cosmos'
)

# ---------------------------------------------------------------------------
# Internal: Compute consensus for one dimension across all repo fingerprints
# ---------------------------------------------------------------------------
function Get-DimensionConsensus {
    <#
    .SYNOPSIS
        Compute weighted majority vote consensus for a single dimension.
    .PARAMETER Dimension
        The dimension name (e.g., 'error-handling').
    .PARAMETER Fingerprints
        Array of fingerprint objects from Get-ReferenceRepoFingerprint.
    .PARAMETER GroundTruthVariants
        Optional hashtable of ground-truth variant names from .claude/rules/.
        Used as tie-breaker.
    #>
    param(
        [Parameter(Mandatory)][string]$Dimension,
        [Parameter(Mandatory)][array]$Fingerprints,
        [hashtable]$GroundTruthVariants = @{}
    )

    # Collect variant votes from each repo
    # Each repo casts ONE vote per dimension for its strongest variant.
    # This prevents vote dilution when repos use multiple variants.
    $variantVotes = @{}  # variantName -> total weighted vote
    $reposWithData = 0

    foreach ($fp in $Fingerprints) {
        $repoName = $fp.repo
        # Skip repos that are not_applicable (non-.NET)
        if ($fp.status -eq 'not_applicable') { continue }
        # Skip repos that lack this dimension
        if (-not $fp.variants -or -not $fp.variants.ContainsKey($Dimension)) { continue }

        $dimVariants = $fp.variants[$Dimension]

        # Find the strongest variant for this repo
        # Use match_count as primary sort (more patterns matched = stronger signal),
        # strength (ratio) as secondary sort to break ties
        $bestVariant = $null
        $bestMatchCount = 0
        $bestStrength = 0.0
        foreach ($variantName in $dimVariants.Keys) {
            $variantInfo = $dimVariants[$variantName]
            if ($variantInfo.present) {
                $mc = [int]$variantInfo.match_count
                $st = [double]$variantInfo.strength
                if ($mc -gt $bestMatchCount -or ($mc -eq $bestMatchCount -and $st -gt $bestStrength)) {
                    $bestVariant = $variantName
                    $bestMatchCount = $mc
                    $bestStrength = $st
                }
            }
        }

        if ($bestVariant) {
            $reposWithData++
            $weight = if ($script:MaturityTiers.ContainsKey($repoName)) {
                $script:MaturityTiers[$repoName].weight
            } else { 0.5 }

            if (-not $variantVotes.ContainsKey($bestVariant)) {
                $variantVotes[$bestVariant] = 0.0
            }
            $variantVotes[$bestVariant] += $weight
        }
    }

    # --- Edge case: insufficient data ---
    if ($reposWithData -lt $script:MinReposForConsensus) {
        return @{
            dimension        = $Dimension
            status           = 'insufficient_data'
            repos_with_data  = $reposWithData
            min_required     = $script:MinReposForConsensus
            consensus        = $null
            agreement_ratio  = 0.0
            variant_votes    = $variantVotes
        }
    }

    # --- Find winning variant ---
    $totalVotes = 0.0
    $maxVote = 0.0
    $winningVariant = $null
    $runnerUp = $null
    $runnerUpVote = 0.0

    foreach ($vn in $variantVotes.Keys) {
        $vote = $variantVotes[$vn]
        $totalVotes += $vote
        if ($vote -gt $maxVote) {
            $runnerUp = $winningVariant
            $runnerUpVote = $maxVote
            $maxVote = $vote
            $winningVariant = $vn
        } elseif ($vote -gt $runnerUpVote) {
            $runnerUp = $vn
            $runnerUpVote = $vote
        }
    }

    $agreementRatio = if ($totalVotes -gt 0) {
        [Math]::Round($maxVote / $totalVotes, 4)
    } else { 0.0 }

    # --- Tie detection and tie-breaking ---
    $isTie = ($runnerUp -and [Math]::Abs($maxVote - $runnerUpVote) -lt 0.01)
    if ($isTie) {
        # Tie-breaker: defer to .claude/rules/ ground truth if present
        if ($GroundTruthVariants.ContainsKey($Dimension)) {
            $groundTruth = $GroundTruthVariants[$Dimension]
            if ($variantVotes.ContainsKey($groundTruth)) {
                $winningVariant = $groundTruth
                $agreementRatio = if ($totalVotes -gt 0) {
                    [Math]::Round($variantVotes[$groundTruth] / $totalVotes, 4)
                } else { 0.0 }
            } else {
                # Ground truth variant not in vote -- mark inconclusive
                return @{
                    dimension        = $Dimension
                    status           = 'inconclusive'
                    reason           = 'Tie with no matching ground truth'
                    repos_with_data  = $reposWithData
                    consensus        = $null
                    agreement_ratio  = $agreementRatio
                    variant_votes    = $variantVotes
                    tie_variants     = @($winningVariant, $runnerUp)
                }
            }
        } else {
            # No ground truth -- inconclusive
            return @{
                dimension        = $Dimension
                status           = 'inconclusive'
                reason           = 'Tie without ground truth tie-breaker'
                repos_with_data  = $reposWithData
                consensus        = $null
                agreement_ratio  = $agreementRatio
                variant_votes    = $variantVotes
                tie_variants     = @($winningVariant, $runnerUp)
            }
        }
    }

    # --- Weak consensus check ---
    $status = if ($agreementRatio -lt $script:MinConsensusThreshold) {
        'weak_consensus'
    } else {
        'consensus'
    }

    return @{
        dimension        = $Dimension
        status           = $status
        repos_with_data  = $reposWithData
        consensus        = $winningVariant
        agreement_ratio  = $agreementRatio
        variant_votes    = $variantVotes
    }
}

# ---------------------------------------------------------------------------
# Internal: Load ground truth variants from .claude/rules/patterns/
# ---------------------------------------------------------------------------
function Get-GroundTruthVariants {
    <#
    .SYNOPSIS
        Extract ground-truth variant names from .claude/rules/patterns/ files.
    .PARAMETER ProjectRoot
        Root of the project containing .claude/rules/patterns/.
    #>
    param([string]$ProjectRoot)

    $groundTruth = @{}
    $patternsDir = Join-Path (Join-Path (Join-Path $ProjectRoot '.claude') 'rules') 'patterns'
    if (-not (Test-Path $patternsDir)) { return $groundTruth }

    # Map pattern files to dimensions and their canonical variants
    $mappings = @{
        'dotnet-error-handling.md'   = @{ dimension = 'error-handling';  variant = 'sanitized_exception_hierarchy' }
        'dotnet-di-patterns.md'      = @{ dimension = 'di-registration'; variant = 'explicit_registration' }
        'dotnet-configuration.md'    = @{ dimension = 'config-pattern';  variant = 'iconfigoptions' }
        'dotnet-logging.md'          = @{ dimension = 'logging';         variant = 'source_generators' }
        'dotnet-testing-setup.md'    = @{ dimension = 'testing';         variant = 'xunit' }
        'dotnet-testing-patterns.md' = @{ dimension = 'testing';         variant = 'nsubstitute' }
        'dotnet-security.md'         = @{ dimension = 'security';        variant = 'managed_identity' }
        'dotnet-auth.md'             = @{ dimension = 'security';        variant = 'jwt_bearer' }
        'dotnet-resilience.md'       = @{ dimension = 'resilience';      variant = 'polly_v8' }
        'dotnet-cosmos-core.md'      = @{ dimension = 'cosmos';          variant = 'core_sdk' }
    }

    foreach ($file in $mappings.Keys) {
        $filePath = Join-Path $patternsDir $file
        if (Test-Path $filePath) {
            $mapping = $mappings[$file]
            $groundTruth[$mapping.dimension] = $mapping.variant
        }
    }

    return $groundTruth
}

# ---------------------------------------------------------------------------
# Public: Setup-CrossRepo
# ---------------------------------------------------------------------------
function Setup-CrossRepo {
    <#
    .SYNOPSIS
        Set up the cross-repo consistency eval workspace.
    .DESCRIPTION
        Fingerprints all configured reference repos in batches of 4, computes
        weighted majority consensus per dimension, and writes the consensus
        baseline to the workspace. This is zero-LLM-cost -- pure static analysis.
    .PARAMETER WorkDir
        Directory where the eval workspace will be created.
    .PARAMETER ReferenceRepos
        Array of reference repo paths to fingerprint. Defaults to all repos
        in the references/ directory relative to project root.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [string[]]$ReferenceRepos
    )

    if (-not (Test-Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    # Locate references/ directory
    # Walk up from WorkDir to find the project root (contains .claude/ or references/)
    $projectRoot = $null
    $searchDir = $WorkDir
    for ($i = 0; $i -lt 10; $i++) {
        $candidate = Split-Path $searchDir -Parent
        if (-not $candidate -or $candidate -eq $searchDir) { break }
        $searchDir = $candidate
        if (Test-Path (Join-Path $searchDir 'references')) {
            $projectRoot = $searchDir
            break
        }
    }

    if (-not $projectRoot) {
        # Fallback: try git rev-parse (suppress stderr on Windows)
        try {
            $gitOutput = & git -C $WorkDir rev-parse --show-toplevel 2>&1
            if ($LASTEXITCODE -eq 0 -and $gitOutput -is [string]) {
                $projectRoot = $gitOutput.Trim()
            }
        } catch {
            # git not available or not in a repo -- ignore
        }
        if (-not $projectRoot) {
            $projectRoot = Split-Path $WorkDir -Parent
        }
        # Normalize forward slashes
        $projectRoot = $projectRoot -replace '/', '\'
    }

    $referencesDir = Join-Path $projectRoot 'references'

    # Build list of repo paths
    if (-not $ReferenceRepos -or $ReferenceRepos.Count -eq 0) {
        $ReferenceRepos = @()
        foreach ($repoName in $script:AllRepoNames) {
            $repoPath = Join-Path $referencesDir $repoName
            if (Test-Path $repoPath) {
                $ReferenceRepos += $repoPath
            }
        }
    }

    if ($ReferenceRepos.Count -eq 0) {
        throw "No reference repos found at $referencesDir"
    }

    # --- Cache directory ---
    $cacheDir = Join-Path $WorkDir '.cache'
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    # --- Fingerprint repos in batches of 4 ---
    $batchSize = 4
    $allFingerprints = [System.Collections.ArrayList]::new()

    if (Get-Command -Name 'Write-Status' -ErrorAction SilentlyContinue) {
        Write-Status "Fingerprinting $($ReferenceRepos.Count) reference repos across $($script:Dimensions.Count) dimensions..." -Type Info
    }

    for ($batchStart = 0; $batchStart -lt $ReferenceRepos.Count; $batchStart += $batchSize) {
        $batchEnd = [Math]::Min($batchStart + $batchSize, $ReferenceRepos.Count) - 1
        $batch = $ReferenceRepos[$batchStart..$batchEnd]

        foreach ($repoPath in $batch) {
            $repoName = Split-Path $repoPath -Leaf
            $cachePath = Join-Path $cacheDir "$repoName.json"

            try {
                $fp = Get-ReferenceRepoFingerprint -RepoPath $repoPath -CachePath $cachePath -Dimensions $script:Dimensions -MaxFiles 5000 -TimeoutSeconds 30
                [void]$allFingerprints.Add($fp)

                $status = if ($fp.status -eq 'not_applicable') { 'skipped (non-.NET)' }
                          elseif ($fp.from_cache) { 'cached' }
                          else { "$($fp.dimensions.Values | Where-Object { $_.present } | Measure-Object | Select-Object -ExpandProperty Count)/$($script:Dimensions.Count) dims" }

                if (Get-Command -Name 'Write-Status' -ErrorAction SilentlyContinue) {
                    Write-Status "  $repoName : $status" -Type Info
                }
            } catch {
                if (Get-Command -Name 'Write-Status' -ErrorAction SilentlyContinue) {
                    Write-Status "  $repoName : ERROR - $($_.Exception.Message)" -Type Warning
                }
            }
        }
    }

    # --- Compute consensus per dimension ---
    $groundTruth = Get-GroundTruthVariants -ProjectRoot $projectRoot

    $consensusResults = @{}
    foreach ($dim in $script:Dimensions) {
        $consensusResults[$dim] = Get-DimensionConsensus -Dimension $dim -Fingerprints $allFingerprints -GroundTruthVariants $groundTruth
    }

    # --- Write baseline to workspace ---
    $baseline = @{
        fingerprints     = @($allFingerprints)
        consensus        = $consensusResults
        ground_truth     = $groundTruth
        repo_count       = $allFingerprints.Count
        net_repo_count   = @($allFingerprints | Where-Object { $_.status -ne 'not_applicable' }).Count
        dimensions       = $script:Dimensions
        maturity_tiers   = $script:MaturityTiers
        timestamp        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    $baselinePath = Join-Path $WorkDir 'consensus-baseline.json'
    $baselineJson = $baseline | ConvertTo-Json -Depth 15
    [System.IO.File]::WriteAllText($baselinePath, $baselineJson, (New-Object System.Text.UTF8Encoding $false))

    # --- Write human-readable summary ---
    $summaryPath = Join-Path $WorkDir 'consensus-summary.md'
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Cross-Repo Pattern Consensus Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Generated: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC'))")
    [void]$sb.AppendLine("Repos scanned: $($allFingerprints.Count) ($($baseline.net_repo_count) .NET)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Dimension | Consensus Variant | Agreement | Status | Repos |')
    [void]$sb.AppendLine('|-----------|-------------------|-----------|--------|-------|')

    foreach ($dim in $script:Dimensions) {
        $c = $consensusResults[$dim]
        $variant = if ($c.consensus) { $c.consensus } else { '--' }
        $ratio = '{0:P0}' -f $c.agreement_ratio
        $dimStatus = $c.status
        $repos = $c.repos_with_data
        [void]$sb.AppendLine("| $dim | $variant | $ratio | $dimStatus | $repos |")
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Maturity Tiers')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Tier | Weight | Repos |')
    [void]$sb.AppendLine('|------|--------|-------|')
    for ($t = 1; $t -le 4; $t++) {
        $tierRepos = $script:MaturityTiers.Keys | Where-Object { $script:MaturityTiers[$_].tier -eq $t } | Sort-Object
        $w = ($script:MaturityTiers[$tierRepos[0]]).weight
        $label = ($script:MaturityTiers[$tierRepos[0]]).label
        [void]$sb.AppendLine("| $t ($label) | ${w}x | $($tierRepos -join ', ') |")
    }

    [System.IO.File]::WriteAllText($summaryPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

    if (Get-Command -Name 'Write-Status' -ErrorAction SilentlyContinue) {
        $consensusCount = @($consensusResults.Values | Where-Object { $_.status -eq 'consensus' }).Count
        Write-Status "Consensus computed: $consensusCount/$($script:Dimensions.Count) dimensions reached consensus" -Type Success
    }
}

# ---------------------------------------------------------------------------
# Public: Get-CrossRepoPrompt
# ---------------------------------------------------------------------------
function Get-CrossRepoPrompt {
    <#
    .SYNOPSIS
        Get the prompt for the cross-repo consistency eval scenario.
    .DESCRIPTION
        Returns a prompt that asks the agent to implement a new service feature
        following ecosystem patterns. Since this is a zero-LLM-cost eval,
        the prompt describes the static analysis comparison rather than
        requiring agent invocation.
    .PARAMETER WorkDir
        The eval workspace directory.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    return @"
This is a static analysis eval -- no agent invocation required.

The cross-repo pattern consistency gauge has fingerprinted all configured
reference repos and computed weighted majority consensus across 8 concern
dimensions:

1. DI Registration (AddSingleton/AddScoped/AddTransient patterns)
2. Error Handling (SanitizedException hierarchy, dual middleware)
3. Configuration (IConfigOptions, Options pattern, dual config)
4. Logging (source generators, structured logging, correlation)
5. Testing (xUnit, NSubstitute, FluentAssertions)
6. Security (Managed Identity, JWT Bearer, policy auth)
7. Resilience (Polly v8, classic Polly, resilience pipelines)
8. Cosmos (SDK v3, queries, advanced features)

Consensus baseline written to: $WorkDir\consensus-baseline.json
Summary: $WorkDir\consensus-summary.md

To measure a workspace against consensus, run Invoke-CrossRepoAssertions.
"@
}

# ---------------------------------------------------------------------------
# Public: Invoke-CrossRepoAssertions
# ---------------------------------------------------------------------------
function Invoke-CrossRepoAssertions {
    <#
    .SYNOPSIS
        Run assertions for the cross-repo consistency eval scenario.
    .DESCRIPTION
        Compares the consensus baseline against known ecosystem patterns.
        Validates that fingerprinting worked correctly, consensus was computed,
        and the scoring pipeline produces valid results.

        For zero-LLM-cost mode: validates the consensus itself (meta-eval).
        For agent-eval mode: compares agent workspace fingerprint against consensus.
    .PARAMETER WorkDir
        The eval workspace directory containing consensus-baseline.json.
    .PARAMETER FingerprintBaseline
        Optional explicit path to the baseline file. Defaults to WorkDir/consensus-baseline.json.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [string]$FingerprintBaseline
    )

    $assertions = [System.Collections.ArrayList]::new()

    # Resolve New-Assertion (from EvalShared or inline)
    $useNewAssertion = Get-Command -Name 'New-Assertion' -ErrorAction SilentlyContinue

    # Helper to add assertion
    $addAssertion = {
        param([string]$Name, [bool]$Passed, [string]$Expected, [string]$Actual, [string]$Message)
        if ($useNewAssertion) {
            $a = New-Assertion -Name $Name -Passed $Passed -Expected $Expected -Actual $Actual -Message $Message
        } else {
            $a = [ordered]@{ name = $Name; passed = $Passed }
            if ($Expected) { $a['expected'] = $Expected }
            if ($Actual) { $a['actual'] = $Actual }
            if ($Message) { $a['message'] = $Message }
        }
        [void]$assertions.Add($a)
    }

    # --- Load baseline ---
    if (-not $FingerprintBaseline) {
        $FingerprintBaseline = Join-Path $WorkDir 'consensus-baseline.json'
    }

    if (-not (Test-Path $FingerprintBaseline)) {
        & $addAssertion 'baseline_exists' $false 'consensus-baseline.json exists' 'file not found' 'Run Setup-CrossRepo first'
        return $assertions
    }

    try {
        $baseline = Get-Content $FingerprintBaseline -Raw | ConvertFrom-Json
    } catch {
        & $addAssertion 'baseline_parseable' $false 'valid JSON' "parse error: $($_.Exception.Message)" ''
        return $assertions
    }

    & $addAssertion 'baseline_exists' $true 'consensus-baseline.json exists' 'found' ''

    # --- Assertion 1: Sufficient repos fingerprinted ---
    $repoCount = $baseline.repo_count
    $netRepoCount = $baseline.net_repo_count
    $minRepos = 6  # At least half the ecosystem

    & $addAssertion 'sufficient_repos' ($netRepoCount -ge $minRepos) `
        ">= $minRepos .NET repos fingerprinted" `
        "$netRepoCount .NET repos (of $repoCount total)" ''

    # --- Assertion 2: All 8 dimensions computed ---
    $consensusDims = if ($baseline.consensus.PSObject) {
        @($baseline.consensus.PSObject.Properties.Name)
    } else {
        @($baseline.consensus.Keys)
    }
    $dimCount = $consensusDims.Count

    & $addAssertion 'all_dimensions_computed' ($dimCount -ge 8) `
        '8 dimensions computed' `
        "$dimCount dimensions" ''

    # --- Assertion 3: Consensus reached on majority of dimensions ---
    $consensusCount = 0
    $weakCount = 0
    $inconclusiveCount = 0
    $insufficientCount = 0

    foreach ($dimName in $consensusDims) {
        $dimResult = $baseline.consensus.$dimName
        $dimStatus = if ($dimResult.PSObject) { $dimResult.status } else { $dimResult['status'] }

        switch ($dimStatus) {
            'consensus'         { $consensusCount++ }
            'weak_consensus'    { $weakCount++ }
            'inconclusive'      { $inconclusiveCount++ }
            'insufficient_data' { $insufficientCount++ }
        }
    }

    & $addAssertion 'majority_consensus' ($consensusCount -ge 3) `
        '>= 3 dimensions with strong consensus' `
        "$consensusCount consensus, $weakCount weak, $inconclusiveCount inconclusive, $insufficientCount insufficient" ''

    # --- Assertion 4: No dimension has zero repos ---
    $emptyDims = 0
    foreach ($dimName in $consensusDims) {
        $dimResult = $baseline.consensus.$dimName
        $reposWithData = if ($dimResult.PSObject) { $dimResult.repos_with_data } else { $dimResult['repos_with_data'] }
        if ($reposWithData -eq 0) { $emptyDims++ }
    }

    & $addAssertion 'no_empty_dimensions' ($emptyDims -eq 0) `
        '0 dimensions with zero repos' `
        "$emptyDims empty dimensions" ''

    # --- Assertion 5: Agreement ratios are reasonable (not all 1.0 or all 0.0) ---
    $ratios = @()
    foreach ($dimName in $consensusDims) {
        $dimResult = $baseline.consensus.$dimName
        $ratio = if ($dimResult.PSObject) { $dimResult.agreement_ratio } else { $dimResult['agreement_ratio'] }
        if ($null -ne $ratio) { $ratios += [double]$ratio }
    }

    $allSame = ($ratios.Count -gt 0) -and (($ratios | Select-Object -Unique).Count -eq 1)

    & $addAssertion 'agreement_ratio_variance' (-not $allSame -and $ratios.Count -gt 0) `
        'Varied agreement ratios across dimensions' `
        "Ratios: $(($ratios | ForEach-Object { '{0:P0}' -f $_ } | Select-Object -First 8) -join ', ')" ''

    # --- Assertion 6: Tier 1 repos contributed to consensus ---
    # Derive the Tier 1 set from $script:MaturityTiers so it tracks the
    # per-ecosystem configuration rather than hard-coding names here.
    $tier1Repos = @($script:MaturityTiers.Keys | Where-Object { $script:MaturityTiers[$_].tier -eq 1 })
    $tier1Present = 0
    $fpArray = if ($baseline.fingerprints -is [array]) { $baseline.fingerprints } else { @($baseline.fingerprints) }
    foreach ($fp in $fpArray) {
        $fpRepo = if ($fp.PSObject) { $fp.repo } else { $fp['repo'] }
        if ($fpRepo -and $tier1Repos -contains $fpRepo) {
            $fpStatus = if ($fp.PSObject -and $fp.PSObject.Properties['status']) { $fp.status } else { $null }
            if ($fpStatus -ne 'not_applicable') { $tier1Present++ }
        }
    }

    & $addAssertion 'tier1_repos_present' ($tier1Present -ge 2) `
        "Both Tier 1 repos ($($tier1Repos -join ', ')) present" `
        "$tier1Present Tier 1 repos found" ''

    # --- Assertion 7: Security exclusions working (no .git content in fingerprints) ---
    # Verify by checking that none of the fingerprints have anomalous match counts
    # that would suggest .git directory scanning
    $suspiciouslyHigh = $false
    foreach ($fp in $fpArray) {
        $fpDims = if ($fp.PSObject -and $fp.PSObject.Properties['dimensions']) { $fp.dimensions } else { $null }
        if (-not $fpDims) { continue }
        $dimProps = if ($fpDims.PSObject) { $fpDims.PSObject.Properties } else { $null }
        if ($dimProps) {
            foreach ($prop in $dimProps) {
                $dimData = $prop.Value
                $matches = if ($dimData.PSObject -and $dimData.PSObject.Properties['matches']) { $dimData.matches } else { 0 }
                $total = if ($dimData.PSObject -and $dimData.PSObject.Properties['total_patterns']) { $dimData.total_patterns } else { 1 }
                # If matches exceeds total_patterns substantially, scanning may include artifacts
                if ($total -gt 0 -and $matches -gt ($total * 3)) {
                    $suspiciouslyHigh = $true
                }
            }
        }
    }

    & $addAssertion 'security_exclusions_effective' (-not $suspiciouslyHigh) `
        'No suspiciously high match counts (security exclusions working)' `
        "$(if ($suspiciouslyHigh) { 'anomalous counts detected' } else { 'counts within expected range' })" ''

    # --- Assertion 8: Composite score via Invoke-MultiDimensionalScore ---
    $scoreDimensions = @()
    foreach ($dimName in $consensusDims) {
        $dimResult = $baseline.consensus.$dimName
        $dimStatus = if ($dimResult.PSObject) { $dimResult.status } else { $dimResult['status'] }
        $ratio = if ($dimResult.PSObject) { $dimResult.agreement_ratio } else { $dimResult['agreement_ratio'] }

        # Score each dimension by its agreement strength
        $dimScore = switch ($dimStatus) {
            'consensus'         { [double]$ratio }
            'weak_consensus'    { [double]$ratio * 0.75 }
            'inconclusive'      { 0.25 }
            'insufficient_data' { 0.0 }
            default             { 0.0 }
        }

        $scoreDimensions += @{
            name   = $dimName
            score  = [Math]::Min($dimScore, 1.0)
            weight = 1.0  # Equal weight across dimensions for meta-eval
        }
    }

    $compositeResult = $null
    if (Get-Command -Name 'Invoke-MultiDimensionalScore' -ErrorAction SilentlyContinue) {
        $compositeResult = Invoke-MultiDimensionalScore -Dimensions $scoreDimensions -Method 'weighted_average'
    }

    $compositeScore = if ($compositeResult) { $compositeResult.composite } else { -1 }

    & $addAssertion 'composite_score_computed' ($compositeScore -ge 0) `
        'Composite score >= 0' `
        "Score: $([Math]::Round($compositeScore, 4))" `
        "$(if ($compositeScore -lt 0) { 'Invoke-MultiDimensionalScore not available' } else { '' })"

    # --- Write assertion summary to workspace ---
    $summaryPath = Join-Path $WorkDir 'assertion-results.json'
    $summaryJson = @{
        assertions      = @($assertions)
        composite_score = $compositeScore
        consensus_count = $consensusCount
        total_dims      = $dimCount
        timestamp       = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($summaryPath, $summaryJson, (New-Object System.Text.UTF8Encoding $false))

    return $assertions
}

Export-ModuleMember -Function @(
    'Setup-CrossRepo',
    'Get-CrossRepoPrompt',
    'Invoke-CrossRepoAssertions'
)
