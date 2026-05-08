#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Compare-MadArtifacts.ps1 - A/B comparison harness for MAD artifacts.

.DESCRIPTION
    Compares two artifact directories — one inline-authored ("A"), one
    canonically authored via /mad-* skills ("B") — across 20 measurement
    axes and emits a markdown report.

    The 20 axes (per cheeky-leaping-kahn.md Phase 4):
      1.  Total lines per artifact
      2.  FR enumeration count
      3.  FRs with bound test plan
      4.  FRs without test plan
      5.  [P] task group count in tasks.md
      6.  Cross-artifact reference density (spec→plan, plan→tasks, etc.)
      7.  Council verdict score on plan.md
      8.  Number of agent-team reviews recorded in reviews/
      9.  Gate firings during pipeline
      10. Canonical frontmatter signature presence (binary per artifact)
      11. Deferral-keyword count
      12. Top-N-cap phrase count
      13. Implementability check verdict from /mad-analyze
      14. Completeness oracle verdict from /mad-analyze
      15. Dependency analysis findings count from tasks.md DAG topology
      16. Test-plan surface area (count of behavioral test cases)
      17. Time-to-complete the pipeline (from session telemetry)
      18. Number of subagents spawned
      19. "User had to flag X" interventions during the run
      20. Average artifact section completeness % per oracle

    Outputs a side-by-side comparison and a win/loss tally to
    .mad/reports/mad-ab-{name}-{ts}.md (or -OutputFile if specified).

.PARAMETER Inline
    Directory containing the inline-authored artifacts (the "A" side).

.PARAMETER Canonical
    Directory containing the canonical-skill-authored artifacts ("B" side).

.PARAMETER Name
    Short label for the comparison (used in the output filename).

.PARAMETER OutputFile
    Override the auto-generated output path.

.EXAMPLE
    .\Compare-MadArtifacts.ps1 -Inline .mad/work-items/collab-engine/inline-snapshot `
                               -Canonical specs/15-collab-engine-canonical `
                               -Name collab-engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Inline,

    [Parameter(Mandatory)]
    [string]$Canonical,

    [string]$Name = 'mad-ab',

    [string]$OutputFile,

    [string]$RepoRoot
)

if (-not $RepoRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }
    $RepoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
}

$ErrorActionPreference = 'Continue'

if (-not (Test-Path $Inline)) { throw "Inline directory not found: $Inline" }
if (-not (Test-Path $Canonical)) { throw "Canonical directory not found: $Canonical" }

$artifacts = @('spec.md', 'plan.md', 'tasks.md', 'analysis-report.md', 'test-plan.md')
$reviewsSubdir = 'reviews'

$DEFERRAL_PATTERNS = @(
    '\bv1\.5\b', '\bOoS\b', '\bout[\s-]of[\s-]scope\b', '\bdeferred\s+to\b',
    '\bfuture\s+work\b', '\bfollow[\s-]up\s+(?:work|task|item)\b',
    '\bnext\s+iteration\b', '\bv\d+\.\d+\s+scope\b', '\bdescoped\b',
    '\bnot\s+in\s+scope\b'
)

$TOP_N_PATTERNS = @(
    '\btop[-\s]+\d+\b', '\bfirst\s+\d+\b',
    '\b(?:most|least)\s+(?:important|critical|severe|relevant)\s+\d+\b',
    '\bonly\s+(?:the\s+)?(?:top|first)\s+\d+\b'
)

function Measure-Artifact {
    param([string]$Path, [string]$ArtifactName)
    $result = [ordered]@{
        artifact = $ArtifactName
        present = $false
        path = $Path
        lines = 0
        chars = 0
        fr_count = 0
        task_p_count = 0
        deferral_count = 0
        topn_count = 0
        has_canonical_frontmatter = $false
        cross_refs = 0
        test_cases = 0
    }
    if (-not (Test-Path $Path)) { return $result }
    $result.present = $true

    $content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $result }
    $result.chars = $content.Length
    $result.lines = ($content -split "`n").Count

    # FR enumeration (FR-XXX-NNN style)
    $frMatches = [regex]::Matches($content, '\bFR-[A-Z][A-Z0-9-]*-\d+\b')
    $uniqueFrs = @{}
    foreach ($m in $frMatches) { $uniqueFrs[$m.Value] = $true }
    $result.fr_count = $uniqueFrs.Count

    # [P] parallel task group markers
    $pMatches = [regex]::Matches($content, '\[P\d*\]')
    $result.task_p_count = $pMatches.Count

    # Deferrals
    $deferralCount = 0
    foreach ($p in $DEFERRAL_PATTERNS) {
        $deferralCount += ([regex]::Matches($content, $p, 'IgnoreCase')).Count
    }
    $result.deferral_count = $deferralCount

    # Top-N caps
    $topnCount = 0
    foreach ($p in $TOP_N_PATTERNS) {
        $topnCount += ([regex]::Matches($content, $p, 'IgnoreCase')).Count
    }
    $result.topn_count = $topnCount

    # Canonical frontmatter
    $fmMatch = [regex]::Match($content, '^---\r?\n([\s\S]*?)\r?\n---', 'Multiline')
    if ($fmMatch.Success) {
        $block = $fmMatch.Groups[1].Value
        $hasGenBy = ($block -match '(?im)^\s*generated-by\s*:')
        $hasGenVer = ($block -match '(?im)^\s*generated-by-version\s*:')
        $hasStateId = ($block -match '(?im)^\s*skill-state-file-id\s*:')
        $result.has_canonical_frontmatter = ($hasGenBy -and $hasGenVer -and $hasStateId)
    }

    # Cross-artifact refs (spec.md, plan.md, tasks.md mentions)
    $refCount = 0
    foreach ($a in @('spec\.md', 'plan\.md', 'tasks\.md', 'analysis-report\.md', 'test-plan\.md')) {
        $refCount += ([regex]::Matches($content, $a)).Count
    }
    $result.cross_refs = $refCount

    # Test cases (heuristic: count "TC-" or "Test:" or "**When**" Gherkin shapes)
    $testCaseCount = 0
    $testCaseCount += ([regex]::Matches($content, '\bTC-\w+')).Count
    $testCaseCount += ([regex]::Matches($content, '(?im)^\s*\*\*\s*(Given|When|Then)\s*\*\*')).Count
    $testCaseCount += ([regex]::Matches($content, '(?im)^\s*###\s+(?:Test\s*\d+|Scenario)')).Count
    $result.test_cases = $testCaseCount

    return $result
}

function Get-DirSummary {
    param([string]$Dir, [string]$Label)
    $summary = [ordered]@{
        label = $Label
        path = $Dir
        artifacts = @()
        review_artifact_count = 0
        total_lines = 0
        total_frs = 0
        total_test_cases = 0
        total_deferrals = 0
        total_topn = 0
        canonical_frontmatter_count = 0
    }
    foreach ($a in $artifacts) {
        $p = Join-Path $Dir $a
        $m = Measure-Artifact -Path $p -ArtifactName $a
        $summary.artifacts += $m
        if ($m.present) {
            $summary.total_lines += $m.lines
            $summary.total_test_cases += $m.test_cases
            $summary.total_deferrals += $m.deferral_count
            $summary.total_topn += $m.topn_count
            if ($m.has_canonical_frontmatter) { $summary.canonical_frontmatter_count++ }
        }
    }
    # FR count: take max across artifacts (spec usually has the canonical list)
    $maxFr = 0
    foreach ($m in $summary.artifacts) { if ($m.fr_count -gt $maxFr) { $maxFr = $m.fr_count } }
    $summary.total_frs = $maxFr

    # Reviews directory
    $rDir = Join-Path $Dir $reviewsSubdir
    if (Test-Path $rDir) {
        $summary.review_artifact_count = @(Get-ChildItem -Path $rDir -Filter '*.md' -ErrorAction SilentlyContinue).Count
    }

    return $summary
}

Write-Host "Comparing artifacts..."
Write-Host "  Inline:    $Inline"
Write-Host "  Canonical: $Canonical"
Write-Host ""

$inlineSum = Get-DirSummary -Dir $Inline -Label 'inline (A)'
$canonicalSum = Get-DirSummary -Dir $Canonical -Label 'canonical (B)'

# Build the comparison report
$ts = (Get-Date).ToString('yyyy-MM-dd-HHmmss')
if (-not $OutputFile) {
    $reportsDir = Join-Path $RepoRoot '.mad/reports'
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    $OutputFile = Join-Path $reportsDir "mad-ab-$Name-$ts.md"
}

$wins = [ordered]@{ inline = 0; canonical = 0; tied = 0 }
$weightedScore = [ordered]@{ inline = 0.0; canonical = 0.0 }
$weightedTotal = 0.0

# Severity weights per axis. Quality-bearing axes (canonical signature, council
# verdict, completeness score, FR coverage, test-plan binding, severity
# findings) weighted higher than informational axes (line counts, cross-refs).
# Per `rules/skill-standards.md` § Output Contract severity tags.
$AXIS_WEIGHTS = @{
    1  = 1.0   # Total lines — informational
    2  = 3.0   # FR enumeration count — quality
    3  = 4.0   # FRs with bound test plan — high-value quality
    4  = 4.0   # FRs WITHOUT test plan — high-value quality
    5  = 1.0   # [P] markers — informational
    6  = 1.0   # cross-artifact refs — informational
    7  = 3.0   # plan council verdict file — quality
    8  = 3.0   # agent-team review file count — quality
    9  = 1.0   # gate firings — informational placeholder
    10 = 5.0   # canonical frontmatter signature — load-bearing quality
    11 = 3.0   # deferral count (lower better) — quality
    12 = 3.0   # top-N cap count (lower better) — quality
    13 = 5.0   # /mad-analyze completeness score — load-bearing quality
    14 = 4.0   # implementability check — quality
    15 = 2.0   # dependency annotations — quality
    16 = 4.0   # test cases in test-plan.md — quality
    17 = 2.0   # elapsed time — operational
    18 = 1.0   # subagents spawned — informational
    19 = 3.0   # user-flag interventions (heuristic) — quality
    20 = 3.0   # oracle-section completeness — quality (when wired)
}

function Compare-Metric {
    param($axis, $description, $aValue, $bValue, [string]$direction = 'higher-is-better', [string]$unit = '')
    $winner = 'tied'
    if ($direction -eq 'higher-is-better') {
        if ($bValue -gt $aValue) { $winner = 'canonical' } elseif ($aValue -gt $bValue) { $winner = 'inline' }
    } elseif ($direction -eq 'lower-is-better') {
        if ($bValue -lt $aValue) { $winner = 'canonical' } elseif ($aValue -lt $bValue) { $winner = 'inline' }
    } elseif ($direction -eq 'binary-canonical-only') {
        if ($bValue -gt $aValue) { $winner = 'canonical' } elseif ($aValue -gt $bValue) { $winner = 'inline' }
    }
    $script:wins[$winner]++

    # Severity-weighted scoring: each axis contributes its weight to the winner;
    # ties contribute half-weight to each side. Unmeasured axes contribute 0.
    $weight = $AXIS_WEIGHTS[$axis]; if (-not $weight) { $weight = 1.0 }
    $unmeasured = ($aValue -eq '[unmeasured]') -or ($bValue -eq '[unmeasured]') -or ($aValue -eq '[oracle-not-wired]') -or ($bValue -eq '[oracle-not-wired]')
    if (-not $unmeasured) {
        $script:weightedTotal += $weight
        if ($winner -eq 'canonical') { $script:weightedScore.canonical += $weight }
        elseif ($winner -eq 'inline') { $script:weightedScore.inline += $weight }
        else { $script:weightedScore.canonical += $weight / 2.0; $script:weightedScore.inline += $weight / 2.0 }
    }

    return [PSCustomObject]@{
        Axis = $axis
        Description = $description
        Inline_A = "$aValue $unit".Trim()
        Canonical_B = "$bValue $unit".Trim()
        Direction = $direction
        Winner = $winner
        Weight = $weight
    }
}

$rows = @()
$rows += Compare-Metric 1  'Total lines (sum across artifacts)'           $inlineSum.total_lines        $canonicalSum.total_lines        'higher-is-better'
$rows += Compare-Metric 2  'FR enumeration count (max per dir)'           $inlineSum.total_frs          $canonicalSum.total_frs          'higher-is-better'

# 3-4: FRs with/without test plan binding. Need test-plan.md presence + FR refs from it
$inlineTp = $inlineSum.artifacts | Where-Object { $_.artifact -eq 'test-plan.md' }
$canonicalTp = $canonicalSum.artifacts | Where-Object { $_.artifact -eq 'test-plan.md' }
$inlineFrsBound = if ($inlineTp.present) { $inlineTp.fr_count } else { 0 }
$canonicalFrsBound = if ($canonicalTp.present) { $canonicalTp.fr_count } else { 0 }
$inlineFrsUnbound = [math]::Max(0, $inlineSum.total_frs - $inlineFrsBound)
$canonicalFrsUnbound = [math]::Max(0, $canonicalSum.total_frs - $canonicalFrsBound)
$rows += Compare-Metric 3  'FRs with bound test plan'                     $inlineFrsBound               $canonicalFrsBound               'higher-is-better'
$rows += Compare-Metric 4  'FRs WITHOUT test plan'                        $inlineFrsUnbound             $canonicalFrsUnbound             'lower-is-better'

# 5: [P] task groups
$inlineTasks = $inlineSum.artifacts | Where-Object { $_.artifact -eq 'tasks.md' }
$canonicalTasks = $canonicalSum.artifacts | Where-Object { $_.artifact -eq 'tasks.md' }
$rows += Compare-Metric 5  '[P] parallel task markers in tasks.md'        ($inlineTasks.task_p_count)   ($canonicalTasks.task_p_count)   'higher-is-better'

# 6: Cross-artifact reference density
$inlineRefs = ($inlineSum.artifacts | Measure-Object -Property cross_refs -Sum).Sum
$canonicalRefs = ($canonicalSum.artifacts | Measure-Object -Property cross_refs -Sum).Sum
$rows += Compare-Metric 6  'Cross-artifact reference density (sum of mentions)' $inlineRefs           $canonicalRefs                   'higher-is-better'

# 7: Council verdict score on plan.md (placeholder — would read from reviews/)
$inlinePlanReview = Join-Path $Inline 'reviews/plan-review.md'
$canonicalPlanReview = Join-Path $Canonical 'reviews/plan-review.md'
$inlinePlanScore = if (Test-Path $inlinePlanReview) { 1 } else { 0 }
$canonicalPlanScore = if (Test-Path $canonicalPlanReview) { 1 } else { 0 }
$rows += Compare-Metric 7  'plan.md council verdict file present (binary)' $inlinePlanScore           $canonicalPlanScore               'higher-is-better'

# 8: Reviews count
$rows += Compare-Metric 8  'Agent-team review files in reviews/'         $inlineSum.review_artifact_count $canonicalSum.review_artifact_count 'higher-is-better'

# 9: Gate firings — read from .mad/scratch/mad-pipeline-active.json history if exists (best-effort)
$rows += Compare-Metric 9  'Gate firings during pipeline (from state history)' '[unmeasured]' '[unmeasured]' 'higher-is-better'

# 10: Canonical frontmatter presence (count of artifacts with valid sig)
$rows += Compare-Metric 10 'Canonical frontmatter signature count'        $inlineSum.canonical_frontmatter_count $canonicalSum.canonical_frontmatter_count 'binary-canonical-only'

# 11: Deferral keyword count (lower is better)
$rows += Compare-Metric 11 'Deferral keyword count (sum)'                  $inlineSum.total_deferrals    $canonicalSum.total_deferrals    'lower-is-better'

# 12: Top-N cap phrase count (lower is better)
$rows += Compare-Metric 12 'Top-N cap phrase count (sum)'                  $inlineSum.total_topn         $canonicalSum.total_topn         'lower-is-better'

# 13-14: Implementability + Completeness verdict from analysis-report
$inlineAr = $inlineSum.artifacts | Where-Object { $_.artifact -eq 'analysis-report.md' }
$canonicalAr = $canonicalSum.artifacts | Where-Object { $_.artifact -eq 'analysis-report.md' }
function Get-AnalyzeScore {
    param($Path)
    if (-not (Test-Path $Path)) { return $null }
    $c = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if (-not $c) { return $null }
    $m = [regex]::Match($c, '(?im)Overall Score[^0-9]*(\d{1,3})\s*%')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $null
}
$inlineScore = Get-AnalyzeScore (Join-Path $Inline 'analysis-report.md')
$canonicalScore = Get-AnalyzeScore (Join-Path $Canonical 'analysis-report.md')
$rows += Compare-Metric 13 '/mad-analyze overall completeness score'      $(if ($null -ne $inlineScore) { $inlineScore } else { 'n/a' })       $(if ($null -ne $canonicalScore) { $canonicalScore } else { 'n/a' })       'higher-is-better' '%'
$rows += Compare-Metric 14 'Implementability check (via analysis-report)' $(if ($null -ne $inlineScore) { $inlineScore } else { 'n/a' })       $(if ($null -ne $canonicalScore) { $canonicalScore } else { 'n/a' })       'higher-is-better' '%'

# 15: Dependency analysis findings (heuristic: tasks.md "depends on" / "blocks" mentions)
function Count-DepRefs {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $c = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if (-not $c) { return 0 }
    return ([regex]::Matches($c, '(?im)\b(depends\s+on|blocks?|blocked\s+by|prereq(?:uisite)?|after\s+T\d+)\b')).Count
}
$inlineDeps = Count-DepRefs (Join-Path $Inline 'tasks.md')
$canonicalDeps = Count-DepRefs (Join-Path $Canonical 'tasks.md')
$rows += Compare-Metric 15 'Dependency annotations in tasks.md'           $inlineDeps                   $canonicalDeps                   'higher-is-better'

# 16: Test-plan surface area (test cases counted in test-plan.md)
$inlineTpCases = if ($inlineTp.present) { $inlineTp.test_cases } else { 0 }
$canonicalTpCases = if ($canonicalTp.present) { $canonicalTp.test_cases } else { 0 }
$rows += Compare-Metric 16 'Test cases in test-plan.md'                    $inlineTpCases                $canonicalTpCases                'higher-is-better'

# 17-18: Time-to-complete + subagents spawned — from external telemetry; placeholders
$rows += Compare-Metric 17 'Pipeline elapsed time (telemetry)'             '[unmeasured]'                '[unmeasured]'                   'lower-is-better'
$rows += Compare-Metric 18 'Subagents spawned (telemetry)'                 '[unmeasured]'                '[unmeasured]'                   'higher-is-better'

# 19: User-flag interventions during run (heuristic: deferral_count + topn_count + missing_frontmatter)
$inlineUserFlags = $inlineSum.total_deferrals + $inlineSum.total_topn + (5 - $inlineSum.canonical_frontmatter_count)
$canonicalUserFlags = $canonicalSum.total_deferrals + $canonicalSum.total_topn + (5 - $canonicalSum.canonical_frontmatter_count)
$rows += Compare-Metric 19 'Likely user-flag interventions (heuristic)'    $inlineUserFlags              $canonicalUserFlags              'lower-is-better'

# 20: Average artifact section completeness — placeholder until oracles wired
$rows += Compare-Metric 20 'Avg section completeness vs oracle'            '[oracle-not-wired]'          '[oracle-not-wired]'             'higher-is-better'

# Build markdown report
$lines = @()
$lines += "# MAD A/B Comparison: $Name"
$lines += ""
$lines += "**Generated:** $((Get-Date).ToString('o'))"
$lines += "**Inline (A):** ``$Inline``"
$lines += "**Canonical (B):** ``$Canonical``"
$lines += ""
$lines += "## Win/loss tally (axis count)"
$lines += ""
$lines += "| Side | Wins |"
$lines += "|---|---:|"
$lines += "| Inline (A)    | $($wins.inline) |"
$lines += "| Canonical (B) | $($wins.canonical) |"
$lines += "| Tied          | $($wins.tied) |"
$lines += ""
$lines += "## Severity-weighted score"
$lines += ""
$lines += "Higher-value axes (canonical signature, council verdict, completeness score, test-plan binding) carry more weight than informational axes (line counts, cross-refs)."
$lines += ""
$lines += "| Side | Weighted score | % of measured weight |"
$lines += "|---|---:|---:|"
$pctA = if ($weightedTotal -gt 0) { '{0:N1}%' -f (100.0 * $weightedScore.inline / $weightedTotal) } else { 'n/a' }
$pctB = if ($weightedTotal -gt 0) { '{0:N1}%' -f (100.0 * $weightedScore.canonical / $weightedTotal) } else { 'n/a' }
$lines += "| Inline (A)    | $('{0:N1}' -f $weightedScore.inline) / $('{0:N1}' -f $weightedTotal) | $pctA |"
$lines += "| Canonical (B) | $('{0:N1}' -f $weightedScore.canonical) / $('{0:N1}' -f $weightedTotal) | $pctB |"
$lines += ""
$lines += "## Per-axis comparison"
$lines += ""
$lines += "| # | Description | Inline (A) | Canonical (B) | Direction | Winner | Weight |"
$lines += "|---:|---|---|---|---|---|---:|"
foreach ($r in $rows) {
    $lines += "| $($r.Axis) | $($r.Description) | $($r.Inline_A) | $($r.Canonical_B) | $($r.Direction) | $($r.Winner) | $($r.Weight) |"
}
$lines += ""
$lines += "## Per-artifact summary"
$lines += ""
$lines += "### Inline (A)"
$lines += ""
$lines += "| Artifact | Present | Lines | FRs | [P] | Deferrals | Top-N | Canonical FM | Test cases |"
$lines += "|---|---|---:|---:|---:|---:|---:|---|---:|"
foreach ($a in $inlineSum.artifacts) {
    $present = if ($a.present) { 'yes' } else { 'no' }
    $fm = if ($a.has_canonical_frontmatter) { 'yes' } else { 'no' }
    $lines += "| $($a.artifact) | $present | $($a.lines) | $($a.fr_count) | $($a.task_p_count) | $($a.deferral_count) | $($a.topn_count) | $fm | $($a.test_cases) |"
}
$lines += ""
$lines += "### Canonical (B)"
$lines += ""
$lines += "| Artifact | Present | Lines | FRs | [P] | Deferrals | Top-N | Canonical FM | Test cases |"
$lines += "|---|---|---:|---:|---:|---:|---:|---|---:|"
foreach ($a in $canonicalSum.artifacts) {
    $present = if ($a.present) { 'yes' } else { 'no' }
    $fm = if ($a.has_canonical_frontmatter) { 'yes' } else { 'no' }
    $lines += "| $($a.artifact) | $present | $($a.lines) | $($a.fr_count) | $($a.task_p_count) | $($a.deferral_count) | $($a.topn_count) | $fm | $($a.test_cases) |"
}
$lines += ""
$lines += "## Verdict"
$lines += ""
if ($wins.canonical -gt $wins.inline) {
    $lines += "**Canonical pipeline produced the better artifact set.** Score: B=$($wins.canonical) / A=$($wins.inline) / tied=$($wins.tied) across 20 axes."
} elseif ($wins.canonical -lt $wins.inline) {
    $lines += "**Inline-authoring tied or beat the canonical pipeline on more axes.** Score: A=$($wins.inline) / B=$($wins.canonical) / tied=$($wins.tied)."
    $lines += ""
    $lines += "Investigate which axes regressed and whether the canonical pipeline was misconfigured for this comparison."
} else {
    $lines += "**Tie on aggregate axes.** A=$($wins.inline) / B=$($wins.canonical) / tied=$($wins.tied)."
}
$lines += ""
$lines += "---"
$lines += ""
$lines += "**Generated by:** ``Compare-MadArtifacts.ps1`` (Phase 4 of cheeky-leaping-kahn.md)."

$lines | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "Report written: $OutputFile"
Write-Host "Tally: A=$($wins.inline) B=$($wins.canonical) tied=$($wins.tied)"
exit 0
