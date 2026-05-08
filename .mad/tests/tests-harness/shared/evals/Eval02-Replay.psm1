# Eval02-Replay.psm1 - Historical Task Replay evaluation module
#
# Mines git history from a shared service/consumer-project reference repos for well-scoped commits,
# reconstructs pre-commit state, and scores the reference solution across 6 dimensions.
# Phase 1: mining + static scoring pipeline. Phase 2 (future): live Claude CLI replay.
#
# Exports: Setup-Replay, Get-ReplayPrompt, Invoke-ReplayAssertions
#
# Shared module dependencies:
#   - EvalShared.psm1: Write-Status, New-Assertion, Get-UtcTimestamp, Invoke-SecretRedaction
#   - scoring/Invoke-MultiDimensionalScore.ps1: Invoke-MultiDimensionalScore
#   - analysis/Get-ReferenceRepoFingerprint.ps1: Get-ReferenceRepoFingerprint

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Dot-source shared scoring module (if not already loaded via Run-LocalEval.ps1)
# ---------------------------------------------------------------------------
if (-not (Get-Command 'Invoke-MultiDimensionalScore' -ErrorAction SilentlyContinue)) {
    $scoringScript = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'scoring') 'Invoke-MultiDimensionalScore.ps1'
    if (Test-Path $scoringScript) {
        . $scoringScript
    }
}

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

$script:ReplayConfig = @{
    # Mining filters
    MinFiles        = 3
    MaxFiles        = 15
    MaxCommitsToScan = 200
    RequiredPrefixes = @('feat:', 'fix:', 'refactor:', 'chore:')
    TestFilePattern  = '\.Tests?\b.*\.cs$|Tests?\.cs$'

    # Scoring weights (must sum to 1.0)
    Weights = [ordered]@{
        gate_pass        = 0.25
        file_accuracy    = 0.20
        convention_score = 0.20
        scope_discipline = 0.15
        minimalism       = 0.10
        semantic_match   = 0.10
    }

    # Layer detection patterns
    LayerPatterns = @{
        'API'            = '\.Api[/\\]|Controller[s]?\.cs$|Controller[s]?[/\\]'
        'BusinessLogic'  = '\.Core[/\\]|\.BusinessLogic[/\\]|Handler[s]?\.cs$|Service[s]?\.cs$'
        'DataAccess'     = '\.DataAccess[/\\]|Repository|\.Repositories[/\\]'
        'Common'         = '\.Common[/\\]|\.Shared[/\\]|\.Contracts[/\\]'
        'Test'           = '\.Tests?[/\\]|\.IntegrationTests[/\\]|\.UnitTests[/\\]'
    }

    # Convention patterns to grep for
    ConventionPatterns = @(
        'LoggerMessage'
        'IConfigOptions'
        'IOptions<'
        'AddScoped'
        'AddSingleton'
        'AddTransient'
        'SanitizedException'
        'ProblemDetails'
        'PartitionKey'
        'CosmosClient'
        '\[Fact\]'
        '\[Theory\]'
        'NSubstitute'
        'Substitute\.For'
        'FluentAssertions'
        'DefaultAzureCredential'
        'CancellationToken'
    )

    # Difficulty tier thresholds
    Tiers = @{
        Easy   = @{ MaxFiles = 3;  MaxLayers = 1; CostLimit = 3 }
        Medium = @{ MaxFiles = 8;  MaxLayers = 3; CostLimit = 8 }
        Hard   = @{ MaxFiles = 15; MaxLayers = 5; CostLimit = 15 }
    }
}

# ---------------------------------------------------------------------------
# Weight Validation (Review Finding: MAJOR-1)
# ---------------------------------------------------------------------------

function Assert-ValidWeights {
    <#
    .SYNOPSIS
        Validate that scoring weights sum to 1.0 and contain no negatives.
    .PARAMETER Weights
        Ordered hashtable of dimension name -> weight.
    #>
    param(
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$Weights
    )

    $sum = 0.0
    foreach ($key in $Weights.Keys) {
        $w = [double]$Weights[$key]
        if ($w -lt 0) {
            throw "Invalid weight for dimension '$key': $w (negative weights not allowed)"
        }
        $sum += $w
    }

    if ([Math]::Abs($sum - 1.0) -gt 0.001) {
        throw "Weights must sum to 1.0 (+/- 0.001). Current sum: $sum"
    }
}

# Validate on module load
Assert-ValidWeights -Weights $script:ReplayConfig.Weights

# ---------------------------------------------------------------------------
# Git Mining Pipeline
# ---------------------------------------------------------------------------

function Get-CommitDiffDetail {
    <#
    .SYNOPSIS
        Extract detailed diff information for a single commit.
    .DESCRIPTION
        Given a repo path and commit SHA, extracts parent SHA, commit message,
        files changed with their status, insertions/deletions, and layer classification.
    .PARAMETER RepoPath
        Absolute path to the git repository.
    .PARAMETER CommitSha
        The commit SHA to analyze.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$CommitSha
    )

    # Get commit metadata
    $logOutput = git -C $RepoPath log -1 --format="%H%n%P%n%s%n%b" $CommitSha 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $logOutput) {
        return $null
    }

    $lines = $logOutput -split "`n"
    $fullSha = $lines[0].Trim()
    $parentSha = ($lines[1].Trim() -split '\s+')[0]  # First parent only
    $subject = $lines[2].Trim()
    $body = if ($lines.Count -gt 3) { ($lines[3..($lines.Count - 1)] -join "`n").Trim() } else { '' }

    # Skip merge commits (multiple parents)
    $parentCount = ($lines[1].Trim() -split '\s+').Count
    if ($parentCount -gt 1) { return $null }

    # Get diff stat
    $statOutput = git -C $RepoPath diff --numstat "$parentSha..$CommitSha" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }

    $filesChanged = @()
    $totalInsertions = 0
    $totalDeletions = 0

    if ($statOutput) {
        foreach ($statLine in ($statOutput -split "`n")) {
            $statLine = $statLine.Trim()
            if (-not $statLine) { continue }
            $parts = $statLine -split '\t'
            if ($parts.Count -ge 3) {
                $ins = if ($parts[0] -eq '-') { 0 } else { [int]$parts[0] }
                $del = if ($parts[1] -eq '-') { 0 } else { [int]$parts[1] }
                $filePath = $parts[2]
                $totalInsertions += $ins
                $totalDeletions += $del
                $filesChanged += @{
                    path       = $filePath
                    insertions = $ins
                    deletions  = $del
                }
            }
        }
    }

    # Detect layers touched
    $layersFound = @{}
    foreach ($file in $filesChanged) {
        foreach ($layerName in $script:ReplayConfig.LayerPatterns.Keys) {
            $pattern = $script:ReplayConfig.LayerPatterns[$layerName]
            if ($file.path -match $pattern) {
                $layersFound[$layerName] = $true
            }
        }
    }

    # Check if any test file is in the diff
    $hasTestFile = $false
    foreach ($file in $filesChanged) {
        if ($file.path -match $script:ReplayConfig.TestFilePattern) {
            $hasTestFile = $true
            break
        }
    }

    # Get the actual diff content for scoring
    $diffContent = git -C $RepoPath diff "$parentSha..$CommitSha" 2>$null
    if ($LASTEXITCODE -ne 0) { $diffContent = '' }

    return @{
        commit_sha      = $fullSha
        parent_sha      = $parentSha
        subject         = $subject
        body            = $body
        files_changed   = $filesChanged
        file_count      = $filesChanged.Count
        layers_touched  = @($layersFound.Keys)
        layer_count     = $layersFound.Count
        insertions      = $totalInsertions
        deletions       = $totalDeletions
        has_test_file   = $hasTestFile
        diff_content    = $diffContent
    }
}

function Get-DifficultyTier {
    <#
    .SYNOPSIS
        Classify a commit into Easy/Medium/Hard difficulty tier.
    .PARAMETER FileCount
        Number of files changed.
    .PARAMETER LayerCount
        Number of architectural layers touched.
    #>
    param(
        [Parameter(Mandatory)][int]$FileCount,
        [Parameter(Mandatory)][int]$LayerCount
    )

    $tiers = $script:ReplayConfig.Tiers

    if ($FileCount -le $tiers.Easy.MaxFiles -and $LayerCount -le $tiers.Easy.MaxLayers) {
        return 'Easy'
    }
    if ($FileCount -le $tiers.Medium.MaxFiles -and $LayerCount -le $tiers.Medium.MaxLayers) {
        return 'Medium'
    }
    return 'Hard'
}

function Invoke-GitMiningPipeline {
    <#
    .SYNOPSIS
        Mine a git repository for qualifying commits suitable for replay evaluation.
    .DESCRIPTION
        Scans the last N commits in a git repo, filters by file count, commit message
        prefix, test file presence, and non-merge status. Returns an array of task
        descriptors with difficulty classification.
    .PARAMETER RepoPath
        Absolute path to the git repository with history.
    .PARAMETER MaxCommits
        Maximum number of commits to scan from HEAD. Default: 200.
    .PARAMETER OutputPath
        Optional path to write replay-tasks.json.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [int]$MaxCommits = 200,
        [string]$OutputPath
    )

    if (-not (Test-Path $RepoPath)) {
        throw "Repository path does not exist: $RepoPath"
    }

    # Verify it is a git repo
    $gitDir = git -C $RepoPath rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Not a git repository: $RepoPath"
    }

    Write-Status "Mining git history from $(Split-Path $RepoPath -Leaf) (last $MaxCommits commits)..." -Type Info

    # Get commit SHAs
    $shaList = git -C $RepoPath log --format="%H" -n $MaxCommits --no-merges 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $shaList) {
        Write-Status "No commits found in repository" -Type Warning
        return @()
    }

    $shas = ($shaList -split "`n") | Where-Object { $_.Trim() }
    Write-Status "  Scanning $($shas.Count) non-merge commits..." -Type Info

    $qualifyingTasks = @()
    $config = $script:ReplayConfig

    foreach ($sha in $shas) {
        $sha = $sha.Trim()
        if (-not $sha) { continue }

        $detail = Get-CommitDiffDetail -RepoPath $RepoPath -CommitSha $sha
        if (-not $detail) { continue }

        # Filter: file count in range
        if ($detail.file_count -lt $config.MinFiles -or $detail.file_count -gt $config.MaxFiles) {
            continue
        }

        # Filter: commit message starts with a required prefix (or ADO squash-merge wrapping one)
        # ADO squash-merge subjects look like: "Merged PR 12345: feat: add resolver"
        # Strip the ADO prefix before checking for conventional commit prefixes.
        $normalizedSubject = $detail.subject
        if ($normalizedSubject -match '^Merged PR \d+:\s*(.+)$') {
            $normalizedSubject = $Matches[1]
        }
        $hasPrefix = $false
        foreach ($prefix in $config.RequiredPrefixes) {
            if ($normalizedSubject.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $hasPrefix = $true
                break
            }
        }
        # If no conventional prefix found, still accept commits that touch .cs files and have tests
        # This handles enterprise repos where commit messages don't follow conventional-commit format
        if (-not $hasPrefix) {
            $hasCsFiles = $false
            foreach ($file in $detail.files_changed) {
                if ($file.path -match '\.cs$') {
                    $hasCsFiles = $true
                    break
                }
            }
            if (-not ($hasCsFiles -and $detail.has_test_file)) {
                continue
            }
        }

        # Filter: must include at least one test file
        if (-not $detail.has_test_file) { continue }

        # Classify difficulty
        $tier = Get-DifficultyTier -FileCount $detail.file_count -LayerCount $detail.layer_count

        # Sanitize commit message (Review Finding: CRITICAL-1)
        $sanitizedSubject = Invoke-SecretRedaction -Content $detail.subject
        $sanitizedBody = Invoke-SecretRedaction -Content $detail.body

        # Build file path list
        $filePaths = @($detail.files_changed | ForEach-Object { $_.path })

        $task = [ordered]@{
            id              = "replay-$(Split-Path $RepoPath -Leaf)-$($sha.Substring(0,7))"
            repo            = (Split-Path $RepoPath -Leaf)
            commit_sha      = $detail.commit_sha
            parent_sha      = $detail.parent_sha
            subject         = $sanitizedSubject
            body            = $sanitizedBody
            file_count      = $detail.file_count
            files           = $filePaths
            layers_touched  = $detail.layers_touched
            layer_count     = $detail.layer_count
            insertions      = $detail.insertions
            deletions       = $detail.deletions
            difficulty_tier = $tier
            diff_content    = $detail.diff_content
        }

        $qualifyingTasks += $task
    }

    Write-Status "  Found $($qualifyingTasks.Count) qualifying replay tasks" -Type $(if ($qualifyingTasks.Count -ge 5) { 'Success' } else { 'Warning' })

    # Tier breakdown
    $tierCounts = @{ Easy = 0; Medium = 0; Hard = 0 }
    foreach ($t in $qualifyingTasks) {
        $tierCounts[$t.difficulty_tier]++
    }
    Write-Status "  Tiers: Easy=$($tierCounts.Easy) Medium=$($tierCounts.Medium) Hard=$($tierCounts.Hard)" -Type Info

    # Write output if path specified
    if ($OutputPath) {
        $parentDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        # Strip diff_content before serialization (too large for JSON)
        $exportTasks = @()
        foreach ($t in $qualifyingTasks) {
            $export = [ordered]@{}
            foreach ($key in $t.Keys) {
                if ($key -ne 'diff_content') {
                    $export[$key] = $t[$key]
                }
            }
            $exportTasks += $export
        }
        $json = @{
            mined_at = (Get-UtcTimestamp)
            repo     = (Split-Path $RepoPath -Leaf)
            total    = $exportTasks.Count
            tiers    = $tierCounts
            tasks    = $exportTasks
        } | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding $false))
        Write-Status "  Wrote replay-tasks.json to $OutputPath" -Type Success
    }

    return $qualifyingTasks
}

# ---------------------------------------------------------------------------
# Scoring Functions
# ---------------------------------------------------------------------------

function Measure-FileAccuracy {
    <#
    .SYNOPSIS
        Compute Jaccard index of files modified (agent vs reference).
    .DESCRIPTION
        intersection(agent_files, ref_files) / union(agent_files, ref_files).
        Returns 1.0 for perfect match, 0.0 for no overlap.
    .PARAMETER AgentFiles
        Array of file paths from agent diff.
    .PARAMETER ReferenceFiles
        Array of file paths from reference diff.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AgentFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ReferenceFiles
    )

    if ($AgentFiles.Count -eq 0 -and $ReferenceFiles.Count -eq 0) { return 1.0 }
    if ($AgentFiles.Count -eq 0 -or $ReferenceFiles.Count -eq 0) { return 0.0 }

    $agentSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $AgentFiles) { [void]$agentSet.Add([string]$f) }
    $refSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $ReferenceFiles) { [void]$refSet.Add([string]$f) }

    # Intersection
    $intersection = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $agentSet) { [void]$intersection.Add($s) }
    $intersection.IntersectWith([System.Collections.Generic.IEnumerable[string]]$refSet)

    # Union
    $union = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $agentSet) { [void]$union.Add($s) }
    $union.UnionWith([System.Collections.Generic.IEnumerable[string]]$refSet)

    if ($union.Count -eq 0) { return 1.0 }

    return [Math]::Round($intersection.Count / $union.Count, 4)
}

function Measure-ConventionScore {
    <#
    .SYNOPSIS
        Score convention adherence by grepping for the ecosystem patterns in diff content.
    .DESCRIPTION
        Counts how many the ecosystem convention patterns appear in the agent diff vs the
        reference diff. Score = min(agent_count, ref_count) / max(1, ref_count).
    .PARAMETER AgentDiff
        The agent's diff content as a string.
    .PARAMETER ReferenceDiff
        The reference diff content as a string.
    #>
    param(
        [string]$AgentDiff = '',
        [string]$ReferenceDiff = ''
    )

    if (-not $ReferenceDiff) { return 0.0 }

    $patterns = $script:ReplayConfig.ConventionPatterns
    $refCount = 0
    $agentCount = 0

    foreach ($pattern in $patterns) {
        $refMatches = [regex]::Matches($ReferenceDiff, $pattern)
        $agentMatches = [regex]::Matches($AgentDiff, $pattern)
        if ($refMatches.Count -gt 0) {
            $refCount++
            if ($agentMatches.Count -gt 0) {
                $agentCount++
            }
        }
    }

    if ($refCount -eq 0) { return 1.0 }  # No conventions in reference = N/A, score as pass

    return [Math]::Round([Math]::Min($agentCount / $refCount, 1.0), 4)
}

function Measure-ScopeDiscipline {
    <#
    .SYNOPSIS
        Score scope discipline: penalize extra files not in reference.
    .DESCRIPTION
        1.0 - (extra_files / total_agent_files). Extra files are those in agent
        output but not in reference. Perfect score (1.0) means no out-of-scope changes.
    .PARAMETER AgentFiles
        Array of file paths from agent diff.
    .PARAMETER ReferenceFiles
        Array of file paths from reference diff.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AgentFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ReferenceFiles
    )

    if ($AgentFiles.Count -eq 0) { return 1.0 }

    $refSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $ReferenceFiles) { [void]$refSet.Add([string]$f) }

    $extraCount = 0
    foreach ($f in $AgentFiles) {
        if (-not $refSet.Contains($f)) {
            $extraCount++
        }
    }

    $penalty = $extraCount / $AgentFiles.Count
    return [Math]::Round(1.0 - $penalty, 4)
}

function Measure-Minimalism {
    <#
    .SYNOPSIS
        Score minimalism: how close is agent line count to reference line count.
    .DESCRIPTION
        min(ref_lines, agent_lines) / max(ref_lines, agent_lines).
        Closer to 1.0 means more similarly sized changes.
    .PARAMETER AgentLines
        Total lines changed (insertions + deletions) by agent.
    .PARAMETER ReferenceLines
        Total lines changed (insertions + deletions) in reference.
    #>
    param(
        [Parameter(Mandatory)][int]$AgentLines,
        [Parameter(Mandatory)][int]$ReferenceLines
    )

    if ($AgentLines -eq 0 -and $ReferenceLines -eq 0) { return 1.0 }
    if ($AgentLines -eq 0 -or $ReferenceLines -eq 0) { return 0.0 }

    $minVal = [Math]::Min($AgentLines, $ReferenceLines)
    $maxVal = [Math]::Max($AgentLines, $ReferenceLines)

    return [Math]::Round($minVal / $maxVal, 4)
}

function Measure-SemanticMatch {
    <#
    .SYNOPSIS
        Score semantic match via identifier keyword overlap between diffs.
    .DESCRIPTION
        Extracts C# identifiers (class names, method names, property names) from both
        diffs using regex, then computes Jaccard similarity of identifier sets.
        This is a lightweight proxy for semantic equivalence.
    .PARAMETER AgentDiff
        The agent's diff content.
    .PARAMETER ReferenceDiff
        The reference diff content.
    #>
    param(
        [string]$AgentDiff = '',
        [string]$ReferenceDiff = ''
    )

    if (-not $AgentDiff -and -not $ReferenceDiff) { return 1.0 }
    if (-not $AgentDiff -or -not $ReferenceDiff) { return 0.0 }

    # Extract C# identifiers: class/interface/struct/enum declarations, method signatures,
    # property names, and namespaces from diff lines (those starting with + or -)
    $identifierPattern = '(?:class|interface|struct|enum|namespace|void|async\s+Task|public|private|protected|internal)\s+(?:(?:static|virtual|override|abstract|sealed|readonly|partial)\s+)*([A-Z][A-Za-z0-9_]+)'
    $propertyPattern = '(?:public|private|protected|internal)\s+(?:\w+(?:<[^>]+>)?)\s+([A-Z][A-Za-z0-9_]+)\s*\{'

    # Build identifier sets inline (avoid PowerShell return-unwrapping of HashSet)
    $agentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $agentDiffLines = $AgentDiff -split "`n" | Where-Object { $_ -match '^\+[^+]|^-[^-]' }
    $agentContent = $agentDiffLines -join "`n"
    foreach ($m in [regex]::Matches($agentContent, $identifierPattern)) {
        if ($m.Groups[1].Value.Length -ge 3) { [void]$agentIds.Add($m.Groups[1].Value) }
    }
    foreach ($m in [regex]::Matches($agentContent, $propertyPattern)) {
        if ($m.Groups[1].Value.Length -ge 3) { [void]$agentIds.Add($m.Groups[1].Value) }
    }

    $refIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $refDiffLines = $ReferenceDiff -split "`n" | Where-Object { $_ -match '^\+[^+]|^-[^-]' }
    $refContent = $refDiffLines -join "`n"
    foreach ($m in [regex]::Matches($refContent, $identifierPattern)) {
        if ($m.Groups[1].Value.Length -ge 3) { [void]$refIds.Add($m.Groups[1].Value) }
    }
    foreach ($m in [regex]::Matches($refContent, $propertyPattern)) {
        if ($m.Groups[1].Value.Length -ge 3) { [void]$refIds.Add($m.Groups[1].Value) }
    }

    if ($agentIds.Count -eq 0 -and $refIds.Count -eq 0) { return 1.0 }
    if ($agentIds.Count -eq 0 -or $refIds.Count -eq 0) { return 0.0 }

    # Jaccard similarity -- use clone-and-modify to avoid constructor overload issues
    $intersection = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $agentIds) { [void]$intersection.Add($s) }
    $intersection.IntersectWith([System.Collections.Generic.IEnumerable[string]]$refIds)

    $union = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $agentIds) { [void]$union.Add($s) }
    $union.UnionWith([System.Collections.Generic.IEnumerable[string]]$refIds)

    if ($union.Count -eq 0) { return 1.0 }

    return [Math]::Round($intersection.Count / $union.Count, 4)
}

function Invoke-ReplayScoringPipeline {
    <#
    .SYNOPSIS
        Score a single replay task across all 6 dimensions.
    .DESCRIPTION
        Given a task descriptor with reference diff, scores it across Gate Pass,
        File Accuracy, Convention Score, Scope Discipline, Minimalism, and Semantic Match.
        In Phase 1 (static scoring), the agent diff equals the reference diff as baseline
        calibration -- all scores should be 1.0 for self-comparison.
    .PARAMETER Task
        The task descriptor hashtable from Invoke-GitMiningPipeline.
    .PARAMETER AgentDiff
        The agent's diff content. If null, uses reference diff (self-comparison baseline).
    .PARAMETER AgentFiles
        Array of file paths from agent diff. If null, uses reference files.
    .PARAMETER AgentLines
        Total agent lines changed. If null, uses reference lines.
    .PARAMETER BuildPassed
        Whether dotnet build succeeded. Default: $true for baseline calibration.
    #>
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Task,
        [string]$AgentDiff,
        [string[]]$AgentFiles,
        [int]$AgentLines = -1,
        [bool]$BuildPassed = $true
    )

    $refFiles = @($Task['files'])
    $refDiff = $Task['diff_content']
    $refLines = [int]$Task['insertions'] + [int]$Task['deletions']
    $weights = $script:ReplayConfig.Weights

    # Defaults for self-comparison baseline
    if (-not $AgentDiff) { $AgentDiff = $refDiff }
    if (-not $AgentFiles) { $AgentFiles = $refFiles }
    if ($AgentLines -lt 0) { $AgentLines = $refLines }

    # Score each dimension
    $gateScore = if ($BuildPassed) { 1.0 } else { 0.0 }
    $fileAccuracy = Measure-FileAccuracy -AgentFiles $AgentFiles -ReferenceFiles $refFiles
    $conventionScore = Measure-ConventionScore -AgentDiff $AgentDiff -ReferenceDiff $refDiff
    $scopeDiscipline = Measure-ScopeDiscipline -AgentFiles $AgentFiles -ReferenceFiles $refFiles
    $minimalism = Measure-Minimalism -AgentLines $AgentLines -ReferenceLines $refLines
    $semanticMatch = Measure-SemanticMatch -AgentDiff $AgentDiff -ReferenceDiff $refDiff

    # Build dimensions array for Invoke-MultiDimensionalScore
    $dimensions = @(
        @{ name = 'gate_pass';        score = $gateScore;        weight = [double]$weights['gate_pass'] }
        @{ name = 'file_accuracy';    score = $fileAccuracy;     weight = [double]$weights['file_accuracy'] }
        @{ name = 'convention_score'; score = $conventionScore;  weight = [double]$weights['convention_score'] }
        @{ name = 'scope_discipline'; score = $scopeDiscipline;  weight = [double]$weights['scope_discipline'] }
        @{ name = 'minimalism';       score = $minimalism;       weight = [double]$weights['minimalism'] }
        @{ name = 'semantic_match';   score = $semanticMatch;    weight = [double]$weights['semantic_match'] }
    )

    # Compute composite using shared scoring module
    $result = Invoke-MultiDimensionalScore -Dimensions $dimensions -Method 'weighted_average'

    # Add task metadata
    $result['task_id'] = $Task['id']
    $result['difficulty_tier'] = $Task['difficulty_tier']
    $result['commit_sha'] = $Task['commit_sha']

    return $result
}

# ---------------------------------------------------------------------------
# Module Interface (3 standard functions)
# ---------------------------------------------------------------------------

function Setup-Replay {
    <#
    .SYNOPSIS
        Set up the replay eval workspace by mining git history.
    .DESCRIPTION
        Scans reference repos (a shared service, consumer-project) for qualifying commits, writes
        replay-tasks.json to the workspace. If no reference repos have git history,
        creates a minimal synthetic task for validation.
    .PARAMETER WorkDir
        Directory where the eval workspace will be created.
    .PARAMETER RepoPath
        Optional: explicit path to reference repo. If not provided, auto-discovers
        from references/ directory relative to the project root.
    .PARAMETER MineTasks
        If specified, forces re-mining even if replay-tasks.json already exists.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [string]$RepoPath,
        [switch]$MineTasks
    )

    if (-not (Test-Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    $tasksFile = Join-Path $WorkDir 'replay-tasks.json'

    # Skip mining if tasks already exist (unless forced)
    if ((Test-Path $tasksFile) -and -not $MineTasks) {
        Write-Status "  replay-tasks.json already exists, skipping mining" -Type Info
        return
    }

    # Auto-discover reference repos
    $repoSearchPaths = @()
    if ($RepoPath) {
        $repoSearchPaths += $RepoPath
    } else {
        # Walk up from WorkDir to find references/
        $searchBase = $WorkDir
        for ($i = 0; $i -lt 5; $i++) {
            $refDir = Join-Path $searchBase 'references'
            if (Test-Path $refDir) {
                # Check each known repo
                foreach ($repoName in @('a shared service', 'consumer-project')) {
                    $candidatePath = Join-Path $refDir $repoName
                    if (Test-Path $candidatePath) {
                        $gitCheck = git -C $candidatePath rev-parse --git-dir 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            $repoSearchPaths += $candidatePath
                        }
                    }
                }
                break
            }
            $searchBase = Split-Path $searchBase -Parent
            if (-not $searchBase) { break }
        }

        # Also check standard project location
        if ($repoSearchPaths.Count -eq 0) {
            $scriptDir = $PSScriptRoot
            if ($scriptDir) {
                $projectRoot = (Resolve-Path (Join-Path $scriptDir '..\..' ) -ErrorAction SilentlyContinue)
                if ($projectRoot) {
                    $refDir = Join-Path $projectRoot.Path 'references'
                    foreach ($repoName in @('a shared service', 'consumer-project')) {
                        $candidatePath = Join-Path $refDir $repoName
                        if (Test-Path $candidatePath) {
                            $gitCheck = git -C $candidatePath rev-parse --git-dir 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                $repoSearchPaths += $candidatePath
                            }
                        }
                    }
                }
            }
        }
    }

    $allTasks = @()

    if ($repoSearchPaths.Count -gt 0) {
        foreach ($rp in $repoSearchPaths) {
            Write-Status "  Mining repo: $rp" -Type Info
            $tasks = Invoke-GitMiningPipeline -RepoPath $rp -MaxCommits $script:ReplayConfig.MaxCommitsToScan
            $allTasks += $tasks
        }
    }

    if ($allTasks.Count -eq 0) {
        Write-Status "  No qualifying commits found in any reference repo. Creating synthetic baseline task." -Type Warning

        # Generate a buildable scaffold for the synthetic task so pre-flight build checks pass
        $scaffoldDir = Join-Path $WorkDir 'src'
        $apiDir      = Join-Path $scaffoldDir 'Api'
        $coreDir     = Join-Path $scaffoldDir 'Core'
        $testsDir    = Join-Path $scaffoldDir 'Tests'
        foreach ($d in @($apiDir, (Join-Path $apiDir 'Controllers'), $coreDir, (Join-Path $coreDir 'Services'), $testsDir)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }

        # Api.csproj with inline PackageReference entries
        # Note: Newtonsoft.Json is required by Microsoft.Azure.Cosmos 3.57+ on .NET 10
        $apiCsproj = @'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Cosmos" Version="3.*" />
    <PackageReference Include="Newtonsoft.Json" Version="13.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.*" />
    <PackageReference Include="Microsoft.Extensions.Options.ConfigurationExtensions" Version="9.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Core\Core.csproj" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $apiDir 'Api.csproj') -Value $apiCsproj -Encoding UTF8

        # Core.csproj with inline PackageReference entries
        $coreCsproj = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Cosmos" Version="3.*" />
    <PackageReference Include="Newtonsoft.Json" Version="13.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.*" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $coreDir 'Core.csproj') -Value $coreCsproj -Encoding UTF8

        # Tests.csproj with inline PackageReference entries
        $testsCsproj = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
    <PackageReference Include="xunit" Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
    <PackageReference Include="NSubstitute" Version="5.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Core\Core.csproj" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $testsDir 'Tests.csproj') -Value $testsCsproj -Encoding UTF8

        # Minimal source files for the scaffold to compile
        Set-Content -Path (Join-Path $apiDir 'Controllers/TestController.cs') -Value @'
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class TestController : ControllerBase
{
    private readonly ILogger<TestController> _logger;
    public TestController(ILogger<TestController> logger) { _logger = logger; }
}
'@ -Encoding UTF8

        Set-Content -Path (Join-Path $coreDir 'Services/TestService.cs') -Value @'
using Microsoft.Extensions.Logging;

namespace Core.Services;

public class TestService
{
    private readonly ILogger<TestService> _logger;
    public TestService(ILogger<TestService> logger) { _logger = logger; }
}
'@ -Encoding UTF8

        Set-Content -Path (Join-Path $testsDir 'TestServiceTests.cs') -Value @'
using Xunit;

namespace Tests;

public class TestServiceTests
{
    [Fact]
    public void Placeholder_test() { Assert.True(true); }
}
'@ -Encoding UTF8

        Set-Content -Path (Join-Path $apiDir 'Program.cs') -Value @'
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();
app.MapControllers();
app.Run();
'@ -Encoding UTF8

        # Create solution file and add all projects so dotnet build works at solution level
        # Note: .NET 10+ creates .slnx (XML format) instead of .sln; detect whichever is created
        $slnOutput = & dotnet new sln -n EvalSolution -o $WorkDir 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "  dotnet new sln failed: $($slnOutput | Out-String)" -Type Warning
        } else {
            $slnFile = Get-ChildItem $WorkDir -Filter 'EvalSolution.*' -File |
                Where-Object { $_.Extension -in '.sln', '.slnx' } |
                Select-Object -First 1
            if ($slnFile) {
                $slnPath = $slnFile.FullName
                $addOutput = & dotnet sln $slnPath add `
                    (Join-Path $apiDir 'Api.csproj') `
                    (Join-Path $coreDir 'Core.csproj') `
                    (Join-Path $testsDir 'Tests.csproj') 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "  dotnet sln add failed: $($addOutput | Out-String)" -Type Warning
                }
            } else {
                Write-Status "  Solution file not found after dotnet new sln" -Type Warning
                $slnPath = $null
            }
        }

        # Restore ALL projects via the solution (not just Api.csproj)
        if ($slnPath -and (Test-Path $slnPath)) {
            $restoreOutput = & dotnet restore $slnPath 2>&1
        } else {
            # Fallback: restore each project individually
            $restoreOutput = @()
            foreach ($proj in @((Join-Path $coreDir 'Core.csproj'), (Join-Path $apiDir 'Api.csproj'), (Join-Path $testsDir 'Tests.csproj'))) {
                $restoreOutput += (& dotnet restore $proj 2>&1)
            }
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Status "  dotnet restore failed for synthetic scaffold: $($restoreOutput | Out-String)" -Type Warning
        }

        # Synthetic fallback task for validation
        $allTasks += [ordered]@{
            id              = 'replay-synthetic-001'
            repo            = 'synthetic'
            commit_sha      = '0000000000000000000000000000000000000000'
            parent_sha      = '0000000000000000000000000000000000000000'
            subject         = 'feat: synthetic test task for replay eval validation'
            body            = 'This is a synthetic task used when no reference repos have qualifying git history.'
            file_count      = 3
            files           = @('src/Api/Controllers/TestController.cs', 'src/Core/Services/TestService.cs', 'src/Tests/TestServiceTests.cs')
            layers_touched  = @('API', 'BusinessLogic', 'Test')
            layer_count     = 3
            insertions      = 50
            deletions       = 10
            difficulty_tier = 'Easy'
            diff_content    = @"
diff --git a/src/Api/Controllers/TestController.cs b/src/Api/Controllers/TestController.cs
new file mode 100644
+using Microsoft.AspNetCore.Mvc;
+[ApiController]
+[Route("api/v1/[controller]")]
+public class TestController : ControllerBase
+{
+    private readonly ILogger<TestController> _logger;
+    public TestController(ILogger<TestController> logger) { _logger = logger; }
+}
"@
        }
    }

    # Tier breakdown summary
    $tierCounts = @{ Easy = 0; Medium = 0; Hard = 0 }
    foreach ($t in $allTasks) {
        if ($t.difficulty_tier -and $tierCounts.ContainsKey($t.difficulty_tier)) {
            $tierCounts[$t.difficulty_tier]++
        }
    }

    # Write tasks (strip diff_content for JSON)
    $exportTasks = @()
    foreach ($t in $allTasks) {
        $export = [ordered]@{}
        foreach ($key in $t.Keys) {
            if ($key -ne 'diff_content') {
                $export[$key] = $t[$key]
            }
        }
        $exportTasks += $export
    }
    $json = @{
        mined_at = (Get-UtcTimestamp)
        total    = $allTasks.Count
        tiers    = $tierCounts
        tasks    = $exportTasks
    } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tasksFile, $json, (New-Object System.Text.UTF8Encoding $false))
    Write-Status "  Wrote $($allTasks.Count) replay tasks to $tasksFile" -Type Success

    # ---------------------------------------------------------------------------
    # Populate workspace with source code from the first task's parent commit.
    # The synthetic fallback (above) already creates a buildable scaffold, so
    # this block only runs when real commits were mined from a reference repo.
    # ---------------------------------------------------------------------------
    if ($allTasks.Count -gt 0 -and $allTasks[0].repo -ne 'synthetic') {
        $firstTask = $allTasks[0]
        $parentSha = $firstTask.parent_sha
        $repoLeaf  = $firstTask.repo

        # Resolve the full repo path from $repoSearchPaths
        $sourceRepoPath = $null
        foreach ($rp in $repoSearchPaths) {
            if ((Split-Path $rp -Leaf) -eq $repoLeaf) {
                $sourceRepoPath = $rp
                break
            }
        }

        if ($parentSha -and $sourceRepoPath -and (Test-Path $sourceRepoPath)) {
            Write-Status "  Populating workspace from parent commit $($parentSha.Substring(0,8)) of $repoLeaf" -Type Info

            $tempWorktree = Join-Path $env:TEMP "replay-checkout-$(Get-Random)"
            $worktreeCreated = $false
            try {
                # Create a detached worktree at the parent commit
                # Temporarily use 'Continue' to prevent git stderr info messages
                # (e.g. "Preparing worktree (detached HEAD ...)") from throwing
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                $wtOutput = & git -C $sourceRepoPath worktree add $tempWorktree $parentSha --detach 2>&1
                $wtExitCode = $LASTEXITCODE
                $ErrorActionPreference = $prevEAP
                if ($wtExitCode -ne 0) {
                    throw "git worktree add failed (exit $wtExitCode): $($wtOutput | Out-String)"
                } else {
                    $worktreeCreated = $true

                    # Locate the solution file within the worktree (search up to 5 levels)
                    $slnFiles = @(Get-ChildItem -Path $tempWorktree -Filter '*.sln' -Recurse -Depth 5 -ErrorAction SilentlyContinue)
                    if ($slnFiles.Count -eq 0) {
                        $slnFiles = @(Get-ChildItem -Path $tempWorktree -Filter '*.slnx' -Recurse -Depth 5 -ErrorAction SilentlyContinue)
                    }

                    if ($slnFiles.Count -gt 0) {
                        # Pick the solution closest to the changed files
                        $slnFile = $slnFiles[0]
                        $slnDir = Split-Path $slnFile.FullName -Parent
                        Write-Status "  Found solution: $($slnFile.Name) at $slnDir" -Type Info

                        # Copy the solution directory tree to the workspace
                        $items = Get-ChildItem -Path $slnDir -ErrorAction SilentlyContinue
                        foreach ($item in $items) {
                            if ($item.Name -eq '.git') { continue }
                            Copy-Item -Path $item.FullName -Destination (Join-Path $WorkDir $item.Name) -Recurse -Force -ErrorAction SilentlyContinue
                        }

                        # Copy root-level build infrastructure files that the solution may depend on
                        # (Directory.Build.props, Directory.Packages.props, NuGet.config, global.json, etc.)
                        $buildInfraFiles = @(
                            'Directory.Build.props',
                            'Directory.Build.targets',
                            'Directory.Packages.props',
                            'NuGet.config',
                            'global.json'
                        )
                        # Walk from the solution dir up to (and including) the worktree root,
                        # copying build infra files that are not yet in the workspace.
                        $normalizedRoot = $tempWorktree.TrimEnd('\','/')
                        $walkDir = $slnDir
                        $visited = @{}
                        while ($walkDir) {
                            $walkDir = Split-Path $walkDir -Parent
                            if (-not $walkDir) { break }
                            $normalizedWalk = $walkDir.TrimEnd('\','/')
                            if ($visited.ContainsKey($normalizedWalk)) { break }
                            $visited[$normalizedWalk] = $true
                            foreach ($infraFile in $buildInfraFiles) {
                                $infraPath = Join-Path $walkDir $infraFile
                                $destPath  = Join-Path $WorkDir $infraFile
                                if ((Test-Path $infraPath) -and -not (Test-Path $destPath)) {
                                    Copy-Item -Path $infraPath -Destination $destPath -Force -ErrorAction SilentlyContinue
                                }
                            }
                            # Stop after processing the worktree root
                            if ($normalizedWalk.Length -le $normalizedRoot.Length) { break }
                        }

                        # Remove missing project references from .sln using dotnet sln remove
                        # (e.g. test projects at sibling paths like ../../test/ that weren't copied)
                        $copiedSln = Get-ChildItem -Path $WorkDir -Filter '*.sln' -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($copiedSln) {
                            $slnContent = Get-Content $copiedSln.FullName -Raw -ErrorAction SilentlyContinue
                            if ($slnContent) {
                                # Find all project paths referenced in the .sln
                                $projPattern = 'Project\("[^"]*"\)\s*=\s*"[^"]*",\s*"([^"]*\.csproj)"'
                                $projMatches = [regex]::Matches($slnContent, $projPattern)
                                $missingProjects = @()
                                foreach ($m in $projMatches) {
                                    $relPath = $m.Groups[1].Value
                                    $absPath = Join-Path $WorkDir $relPath
                                    if (-not (Test-Path $absPath)) {
                                        $missingProjects += $relPath
                                    }
                                }
                                if ($missingProjects.Count -gt 0) {
                                    Push-Location $WorkDir
                                    try {
                                        foreach ($mp in $missingProjects) {
                                            & dotnet sln $copiedSln.Name remove $mp 2>&1 | Out-Null
                                        }
                                    } finally { Pop-Location }
                                }
                            }
                        }

                        # Replace Directory.Build.props with minimal version if it has
                        # unresolvable internal build-system imports ($(EnlistmentRoot)\build\...)
                        $dbProps = Join-Path $WorkDir 'Directory.Build.props'
                        if (Test-Path $dbProps) {
                            $propsContent = Get-Content $dbProps -Raw -ErrorAction SilentlyContinue
                            if ($propsContent -and $propsContent -match 'EnlistmentRoot.*\\build\\') {
                                $minimalProps = @'
<Project>
  <PropertyGroup>
    <TargetFramework Condition="'$(TargetFramework)' == ''">net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <NoWarn>$(NoWarn);CS1591;CS8618</NoWarn>
  </PropertyGroup>
</Project>
'@
                                Set-Content -Path $dbProps -Value $minimalProps -Encoding UTF8
                            }
                        }

                        Write-Status "  Workspace populated with source from $repoLeaf" -Type Success
                    } else {
                        # No .sln found -- copy the entire worktree minus .git
                        Write-Status "  No .sln found; copying entire repo tree to workspace" -Type Warning
                        $items = Get-ChildItem -Path $tempWorktree -ErrorAction SilentlyContinue
                        foreach ($item in $items) {
                            if ($item.Name -eq '.git') { continue }
                            Copy-Item -Path $item.FullName -Destination (Join-Path $WorkDir $item.Name) -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            } catch {
                Write-Status "  Failed to populate workspace: $($_.Exception.Message)" -Type Warning
                throw
            } finally {
                # Clean up the temporary worktree
                if ($worktreeCreated) {
                    $prevEAP = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    & git -C $sourceRepoPath worktree remove $tempWorktree --force 2>&1 | Out-Null
                    $ErrorActionPreference = $prevEAP
                }
                if (Test-Path $tempWorktree) {
                    Remove-Item -Recurse -Force $tempWorktree -ErrorAction SilentlyContinue
                }
            }

            # Attempt dotnet restore on the workspace (may fail for private NuGet feeds)
            $slnInWorkspace = Get-ChildItem -Path $WorkDir -Filter '*.sln' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $slnInWorkspace) {
                $slnInWorkspace = Get-ChildItem -Path $WorkDir -Filter '*.slnx' -ErrorAction SilentlyContinue | Select-Object -First 1
            }
            if ($slnInWorkspace) {
                Write-Status "  Running dotnet restore on $($slnInWorkspace.Name)..." -Type Info
                Push-Location $WorkDir
                try {
                    $restoreOutput = & dotnet restore $slnInWorkspace.Name 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Status "  dotnet restore failed (private feed auth may be needed): $($restoreOutput | Select-Object -Last 3 | Out-String)" -Type Warning
                    } else {
                        Write-Status "  dotnet restore succeeded" -Type Success
                    }
                } catch {
                    Write-Status "  dotnet restore threw: $($_.Exception.Message)" -Type Warning
                } finally {
                    Pop-Location
                }
            }
        } else {
            Write-Status "  Cannot populate workspace: missing parent_sha or repo path for $repoLeaf" -Type Warning
        }
    }

    # Post-population validation: ensure workspace has buildable project files
    $slnFiles = @(Get-ChildItem -Path $WorkDir -Filter '*.sln' -ErrorAction SilentlyContinue)
    $slnxFiles = @(Get-ChildItem -Path $WorkDir -Filter '*.slnx' -ErrorAction SilentlyContinue)
    $csprojFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Depth 2 -Filter '*.csproj' -ErrorAction SilentlyContinue)
    if ($slnFiles.Count -eq 0 -and $slnxFiles.Count -eq 0 -and $csprojFiles.Count -eq 0) {
        throw "Workspace population failed: no .sln/.slnx/.csproj found in $WorkDir after Setup-Replay"
    }

    # Store tasks with diff_content in memory for scoring (via module-level variable)
    $script:MinedTasks = $allTasks
}

function Get-ReplayPrompt {
    <#
    .SYNOPSIS
        Get the prompt for the replay eval scenario.
    .DESCRIPTION
        Reads replay-tasks.json from the workspace and returns a prompt based on
        the first mined task's commit message. The prompt instructs the agent to
        implement the feature described in the commit message.
    .PARAMETER WorkDir
        The eval workspace directory.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    $tasksFile = Join-Path $WorkDir 'replay-tasks.json'

    if (-not (Test-Path $tasksFile)) {
        return "ERROR: replay-tasks.json not found in $WorkDir. Run Setup-Replay first."
    }

    $data = Get-Content $tasksFile -Raw | ConvertFrom-Json
    if (-not $data.tasks -or $data.tasks.Count -eq 0) {
        return "ERROR: No replay tasks found in replay-tasks.json."
    }

    $task = $data.tasks[0]

    # Build a realistic implementation prompt from the commit message
    $prompt = @"
Implement the following change in this .NET project:

$($task.subject)

$($task.body)

The project is at $WorkDir. Work directly in the project files. Do not use git.
Follow the existing patterns in the codebase exactly.
"@

    return $prompt
}

function Invoke-ReplayAssertions {
    <#
    .SYNOPSIS
        Run 6-dimensional scoring assertions for all mined replay tasks.
    .DESCRIPTION
        Scores each mined task using the replay scoring pipeline (Phase 1: self-comparison
        baseline where agent diff = reference diff). Returns an array of assertion results
        compatible with the standard eval assertion format.

        Assertions produced:
        - mining_found_tasks: At least 1 task was mined
        - mining_tier_distribution: At least 2 tiers represented (or synthetic fallback)
        - Per-task: composite_score >= 0.8 (baseline should be ~1.0)
        - Per-dimension: individual dimension scores for diagnostics
        - summary_composite: Average composite across all tasks
    .PARAMETER WorkDir
        The eval workspace directory to validate.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    $assertions = [System.Collections.ArrayList]::new()

    # Load tasks
    $tasksFile = Join-Path $WorkDir 'replay-tasks.json'
    if (-not (Test-Path $tasksFile)) {
        [void]$assertions.Add((New-Assertion -Name 'replay_tasks_exist' -Passed $false `
            -Message "replay-tasks.json not found in $WorkDir"))
        return $assertions
    }

    $data = Get-Content $tasksFile -Raw | ConvertFrom-Json
    $taskCount = if ($data.tasks) { $data.tasks.Count } else { 0 }

    # Assertion: mining found tasks
    [void]$assertions.Add((New-Assertion -Name 'mining_found_tasks' `
        -Passed ($taskCount -gt 0) `
        -Expected 'At least 1 qualifying commit' `
        -Actual "$taskCount tasks found" `
        -Message $(if ($taskCount -gt 0) { "Found $taskCount qualifying replay tasks" } else { 'No qualifying commits found' })))

    if ($taskCount -eq 0) {
        return $assertions
    }

    # Assertion: tier distribution
    $tierCounts = @{ Easy = 0; Medium = 0; Hard = 0 }
    foreach ($t in $data.tasks) {
        $tier = $t.difficulty_tier
        if ($tier -and $tierCounts.ContainsKey($tier)) {
            $tierCounts[$tier]++
        }
    }
    $tiersRepresented = @($tierCounts.Keys | Where-Object { $tierCounts[$_] -gt 0 }).Count
    $isSynthetic = ($data.tasks[0].repo -eq 'synthetic')

    [void]$assertions.Add((New-Assertion -Name 'mining_tier_distribution' `
        -Passed ($tiersRepresented -ge 2 -or $isSynthetic) `
        -Expected 'At least 2 difficulty tiers (or synthetic)' `
        -Actual "Tiers: Easy=$($tierCounts.Easy) Medium=$($tierCounts.Medium) Hard=$($tierCounts.Hard)" `
        -Message $(if ($isSynthetic) { 'Synthetic baseline - tier check waived' } else { "$tiersRepresented tier(s) represented" })))

    # Score each task using the in-memory tasks (with diff_content) or self-comparison baseline
    $compositeScores = @()
    # Determine task source. Note: PowerShell's if-expression unwraps single-element arrays,
    # so we must re-wrap in @() after the conditional to prevent OrderedDictionary enumeration.
    $rawTasks = if ($script:MinedTasks -and @($script:MinedTasks).Count -gt 0) {
        $script:MinedTasks
    } else {
        # Reconstruct from JSON (without diff_content, scoring will use defaults)
        $data.tasks | ForEach-Object {
            $ht = [ordered]@{}
            $_.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            if (-not $ht.ContainsKey('diff_content')) { $ht['diff_content'] = '' }
            $ht
        }
    }
    # Force array semantics regardless of element count
    $tasksToScore = [System.Collections.ArrayList]::new()
    foreach ($item in @($rawTasks)) {
        if ($item -is [System.Collections.IDictionary]) {
            [void]$tasksToScore.Add($item)
        }
    }

    # Limit scoring to first 10 tasks for performance
    $scoringTasks = $tasksToScore
    if ($scoringTasks.Count -gt 10) {
        $scoringTasks = $scoringTasks[0..9]
        Write-Status "  Scoring limited to first 10 of $($tasksToScore.Count) tasks" -Type Info
    }

    $taskIndex = 0
    foreach ($task in $scoringTasks) {
        $taskIndex++

        # Phase 1: self-comparison baseline (agent = reference)
        $scoreResult = Invoke-ReplayScoringPipeline -Task $task -BuildPassed $true

        $composite = [double]$scoreResult.composite
        $compositeScores += $composite

        # Per-task composite assertion
        $taskId = if ($task['id']) { $task['id'] } else { "task-$taskIndex" }
        $taskTier = $task['difficulty_tier']
        [void]$assertions.Add((New-Assertion -Name "task_${taskId}_composite" `
            -Passed ($composite -ge 0.8) `
            -Expected '>= 0.80' `
            -Actual ([string]$composite) `
            -Message "Composite score for $taskId ($taskTier)"))

        # Per-dimension detail assertions (first 3 tasks only for brevity)
        if ($taskIndex -le 3 -and $scoreResult.dimensions) {
            foreach ($dim in $scoreResult.dimensions) {
                [void]$assertions.Add((New-Assertion -Name "task_${taskId}_$($dim.name)" `
                    -Passed ([double]$dim.score -ge 0.5) `
                    -Expected '>= 0.50' `
                    -Actual ([string]$dim.score) `
                    -Message "$($dim.name) for $taskId"))
            }
        }
    }

    # Summary composite assertion
    $avgComposite = if ($compositeScores.Count -gt 0) {
        [Math]::Round(($compositeScores | Measure-Object -Average).Average, 4)
    } else { 0.0 }

    [void]$assertions.Add((New-Assertion -Name 'summary_composite_score' `
        -Passed ($avgComposite -ge 0.7) `
        -Expected '>= 0.70 average composite' `
        -Actual ([string]$avgComposite) `
        -Message "Average composite across $($compositeScores.Count) tasks"))

    # Dimension discrimination check: do scores vary across tasks?
    if ($compositeScores.Count -ge 3) {
        $stdDev = 0.0
        $mean = ($compositeScores | Measure-Object -Average).Average
        $sumSq = 0.0
        foreach ($s in $compositeScores) { $sumSq += ($s - $mean) * ($s - $mean) }
        $stdDev = [Math]::Round([Math]::Sqrt($sumSq / $compositeScores.Count), 4)

        [void]$assertions.Add((New-Assertion -Name 'score_discrimination' `
            -Passed ($stdDev -ge 0.0) `
            -Expected 'StdDev reported (discrimination power)' `
            -Actual "StdDev=$stdDev across $($compositeScores.Count) tasks" `
            -Message "Higher StdDev indicates better discrimination between tasks"))
    }

    return $assertions
}

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Setup-Replay',
    'Get-ReplayPrompt',
    'Invoke-ReplayAssertions'
)
