<#
.SYNOPSIS
    Walk a feature-ledger workspace, run the per-feature tests, and emit a status report.

.DESCRIPTION
    Discovers feature-ledger files (specs/<N>-<workspace>/features/F-NNN-<slug>.md),
    parses YAML frontmatter, builds a dependency graph, then for each feature in
    topological order dispatches its referenced test files to the correct runner
    (pnpm vitest run --project <p> for unit/node/browser/integration; pnpm
    playwright test for e2e). Computes red/green/locked status, detects drift
    against the ledger, writes a Markdown + JSON status report to .mad/reports/
    and to <FeaturesDir>/../status/feature-status-latest.json.

    The script is the authoritative red->green->locked oracle for the
    specs/15-nested-quilt/ workspace pattern. The ledger files are advisory;
    the script runs the tests.

    Implements Wave 1B of plan
    C:\Users\tonym\.claude\plans\c-users-tonym-repos-mad-clean-specs-15-nested-quilt.md.

.PARAMETER FeaturesDir
    Path to the features/ directory inside a spec workspace
    (e.g. specs/15-nested-quilt/features). Required.

.PARAMETER TestsDir
    Path to the tests/ directory. Default: parent($FeaturesDir)/tests.

.PARAMETER FeatureFilter
    Optional list of F-IDs (e.g. F-001, F-007). Empty = all.

.PARAMETER StatusFilter
    red | green | locked | all. Default: all. Filters by ledger status.

.PARAMETER ExpectRed
    If set, treat ledger=red + run=green as a DRIFT-EARLY-GREEN regression
    (exits 4 if any feature drifts that way).

.PARAMETER ReportDir
    Where to write the status report. Default: .mad/reports.

.PARAMETER VitestConfig
    Path to vitest.config.ts. Default: vitest.config.ts (resolved relative to cwd).

.PARAMETER PlaywrightConfig
    Path to playwright.config.ts. Default: playwright.config.ts.

.PARAMETER UpdateLedger
    If set, drift triggers /feature-lock --transition <new> --feature F-NNN.
    NOTE: /feature-lock skill not yet implemented; currently logs a warning
    per-feature describing what would be invoked. See TODO comment near the
    Invoke-FeatureLockTransition helper.

.PARAMETER DryRun
    Parse + validate dependency graph only. No runners invoked. Useful for
    schema validation in CI without a Node toolchain.

.EXAMPLE
    pwsh -NoProfile -File .mad/scripts/Run-FeatureEval.ps1 `
        -FeaturesDir specs/15-nested-quilt/features

.EXAMPLE
    pwsh -NoProfile -File .mad/scripts/Run-FeatureEval.ps1 `
        -FeaturesDir specs/15-nested-quilt/features `
        -FeatureFilter F-001,F-002 -DryRun

.EXAMPLE
    pwsh -NoProfile -File .mad/scripts/Run-FeatureEval.ps1 `
        -FeaturesDir specs/15-nested-quilt/features -ExpectRed

.NOTES
    Exit codes:
      0 = clean, no RED at runtime
      1 = script-level error (missing FeaturesDir, malformed frontmatter,
          no F-NNN files when not -DryRun)
      2 = at least one feature RED at runtime (CI build-break signal)
      3 = dependency-graph cycle
      4 = -ExpectRed AND at least one DRIFT-EARLY-GREEN regression

    PowerShell convention sources:
      - .claude/rules/patterns/powershell-conventions.md (no $args, no global
        Set-StrictMode, $LASTEXITCODE for native commands)
      - .mad/scripts/Generate-FeatureMap.ps1 (glob-walk + status-table pattern)
      - .mad/scripts/Run-LocalEval.ps1 (vitest shell-out pattern)

    YAML parser limitations (minimal in-script implementation, no module
    dependency):
      - Supports string keys with string/number/list/object values
      - Lists with `- item` syntax (1 level)
      - Nested objects with 2-space indent (1 level deep, e.g. provenance.surfaces,
        test-files.<project>, status-history)
      - Block scalars with `|` are captured as multi-line strings
      - Does NOT support: anchors, aliases, flow style, multi-document streams,
        explicit type tags, complex map keys
      - Frontmatter is the substring between leading `---\n` and the next
        `\n---\n` boundary
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $FeaturesDir,

    [string] $TestsDir = '',

    [string[]] $FeatureFilter = @(),

    [ValidateSet('red', 'green', 'locked', 'all')]
    [string] $StatusFilter = 'all',

    [switch] $ExpectRed,

    [string] $ReportDir = '.mad/reports',

    [string] $VitestConfig = 'vitest.config.ts',

    [string] $PlaywrightConfig = 'playwright.config.ts',

    [switch] $UpdateLedger,

    [switch] $DryRun
)

# Hybrid error handling per powershell-conventions.md: 'Stop' for cmdlets,
# explicit $LASTEXITCODE checks for native commands. We do NOT set
# Set-StrictMode because frontmatter has optional fields (e.g., features may
# omit `browser:` lists).
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# Required frontmatter keys (per plan: artifact-class, generated-by,
# generated-by-version, skill-state-file-id, feature-id, status, test-files,
# fr-coverage, depends-on, status-history, provenance).
# ------------------------------------------------------------------
$script:RequiredKeys = @(
    'artifact-class',
    'generated-by',
    'generated-by-version',
    'skill-state-file-id',
    'feature-id',
    'status',
    'test-files',
    'fr-coverage',
    'depends-on',
    'status-history',
    'provenance'
)

$script:ValidProjects = @('unit', 'node', 'browser', 'integration', 'e2e')

# ------------------------------------------------------------------
# Minimal YAML parser. See script header for limitations.
# ------------------------------------------------------------------
function Get-FrontmatterText {
    param([string]$FileContent)

    # Strip BOM if present.
    if ($FileContent.Length -gt 0 -and [int]$FileContent[0] -eq 0xFEFF) {
        $FileContent = $FileContent.Substring(1)
    }

    # Normalize line endings to \n for parsing.
    $normalized = $FileContent -replace "`r`n", "`n"

    if (-not $normalized.StartsWith("---`n")) {
        return $null
    }

    $rest = $normalized.Substring(4)
    $endIdx = $rest.IndexOf("`n---")
    if ($endIdx -lt 0) {
        return $null
    }

    return $rest.Substring(0, $endIdx)
}

function ConvertFrom-MinimalYaml {
    <#
    Minimal YAML parser tuned for the feature-ledger frontmatter shape.
    Produces an ordered hashtable. See script header for documented limitations.
    #>
    param([string]$Yaml)

    $result = [ordered]@{}
    if (-not $Yaml) { return $result }

    $lines = $Yaml -split "`n"
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        # Skip empties/comments at top level.
        if ($line -match '^\s*$' -or $line -match '^\s*#') {
            $i++; continue
        }

        # Top-level key (no leading whitespace) is the only level we descend
        # into; nested children are processed by helpers below.
        if ($line -notmatch '^([A-Za-z][\w\-]*)\s*:\s*(.*)$') {
            $i++; continue
        }

        $key = $Matches[1]
        $valueRaw = $Matches[2].TrimEnd()

        # Block scalar `|` -> capture indented continuation lines.
        if ($valueRaw -eq '|' -or $valueRaw -eq '|-' -or $valueRaw -eq '|+') {
            $i++
            $blockLines = @()
            while ($i -lt $lines.Count) {
                $next = $lines[$i]
                if ($next -match '^( {2,}|\t)' -or $next -match '^\s*$') {
                    if ($next -match '^( {2,})(.*)$') {
                        $blockLines += $Matches[2]
                    }
                    elseif ($next -match '^\s*$') {
                        $blockLines += ''
                    }
                    $i++
                }
                else { break }
            }
            $result[$key] = ($blockLines -join "`n").TrimEnd()
            continue
        }

        # Inline scalar.
        if ($valueRaw -ne '' -and $valueRaw -notmatch '^\[') {
            $result[$key] = ConvertFrom-YamlScalar $valueRaw
            $i++; continue
        }

        # Inline flow-list `[a, b, c]` -> simple split.
        if ($valueRaw -match '^\[(.*)\]$') {
            $items = $Matches[1].Split(',') | ForEach-Object { ConvertFrom-YamlScalar ($_.Trim()) } | Where-Object { $_ -ne '' }
            $result[$key] = @($items)
            $i++; continue
        }

        # Empty value -> child block follows. Determine child shape by peeking.
        $i++
        $childLines = @()
        while ($i -lt $lines.Count) {
            $next = $lines[$i]
            # Stop when we hit a non-blank line at column 0 (next top-level key).
            if ($next -match '^\S') { break }
            if ($next -match '^\s*$') { $i++; continue }
            $childLines += $next
            $i++
        }

        if ($childLines.Count -eq 0) {
            $result[$key] = @()
            continue
        }

        # If first non-blank child line begins with `-`, it's a list.
        $firstChild = $childLines[0]
        if ($firstChild -match '^\s*-\s') {
            $result[$key] = ConvertFrom-YamlListBlock $childLines
        }
        else {
            $result[$key] = ConvertFrom-YamlMapBlock $childLines
        }
    }

    return $result
}

function ConvertFrom-YamlScalar {
    param([string]$Raw)

    if ($null -eq $Raw) { return '' }
    $v = $Raw.Trim()
    if ($v -eq '') { return '' }

    # Strip surrounding quotes.
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        return $v.Substring(1, $v.Length - 2)
    }

    # Strip trailing inline comment ` # ...`.
    $hashIdx = $v.IndexOf(' #')
    if ($hashIdx -gt 0) {
        $v = $v.Substring(0, $hashIdx).TrimEnd()
    }

    return $v
}

function ConvertFrom-YamlListBlock {
    <#
    Converts a list block (each entry begins with `- `). Entries may be:
      - simple scalars: `- F-001`
      - inline maps:    `- status: red`  (continuation lines at deeper indent)
    Returns array of either strings or [ordered]@{} maps.
    #>
    param([string[]]$Lines)

    $items = @()
    $current = $null

    foreach ($ln in $Lines) {
        if ($ln -match '^(\s*)-\s+(.*)$') {
            # Flush previous map (if any).
            if ($null -ne $current) { $items += , $current; $current = $null }

            $rest = $Matches[2].TrimEnd()

            # Inline map first key: `- status: red`
            if ($rest -match '^([A-Za-z][\w\-]*)\s*:\s*(.*)$') {
                $current = [ordered]@{}
                $current[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2]
            }
            else {
                # Pure scalar list item.
                $items += , (ConvertFrom-YamlScalar $rest)
                $current = $null
            }
        }
        elseif ($ln -match '^(\s*)([A-Za-z][\w\-]*)\s*:\s*(.*)$' -and $null -ne $current) {
            # Continuation key for current map item.
            $current[$Matches[2]] = ConvertFrom-YamlScalar $Matches[3]
        }
    }

    if ($null -ne $current) { $items += , $current }

    return , $items
}

function ConvertFrom-YamlMapBlock {
    <#
    Nested map under a parent key. Children at indent >= 2.
    Supports nested lists for one further level (e.g. provenance.surfaces).
    #>
    param([string[]]$Lines)

    $map = [ordered]@{}
    $i = 0
    while ($i -lt $Lines.Count) {
        $ln = $Lines[$i]
        if ($ln -match '^\s*$') { $i++; continue }
        if ($ln -notmatch '^(\s+)([A-Za-z][\w\-]*)\s*:\s*(.*)$') {
            $i++; continue
        }

        $childIndent = $Matches[1].Length
        $childKey = $Matches[2]
        $childRaw = $Matches[3].TrimEnd()

        if ($childRaw -ne '' -and $childRaw -notmatch '^\[') {
            $map[$childKey] = ConvertFrom-YamlScalar $childRaw
            $i++; continue
        }

        if ($childRaw -match '^\[(.*)\]$') {
            $items = $Matches[1].Split(',') | ForEach-Object { ConvertFrom-YamlScalar ($_.Trim()) } | Where-Object { $_ -ne '' }
            $map[$childKey] = @($items)
            $i++; continue
        }

        # Empty value -> nested list/map deeper than $childIndent.
        $i++
        $grandLines = @()
        while ($i -lt $Lines.Count) {
            $g = $Lines[$i]
            if ($g -match '^\s*$') { $grandLines += ''; $i++; continue }
            if ($g -match '^(\s*)') {
                $gIndent = $Matches[1].Length
                if ($gIndent -le $childIndent) { break }
            }
            # Strip the parent indent so child parser sees indent >= 2 from its own root.
            if ($g.Length -gt $childIndent) {
                $grandLines += $g.Substring($childIndent)
            }
            $i++
        }

        if ($grandLines.Count -eq 0) {
            $map[$childKey] = @()
            continue
        }

        # Find first non-blank to detect list vs map.
        $firstGrand = ($grandLines | Where-Object { $_ -match '\S' } | Select-Object -First 1)
        if ($firstGrand -match '^\s*-\s') {
            $map[$childKey] = ConvertFrom-YamlListBlock $grandLines
        }
        else {
            $map[$childKey] = ConvertFrom-YamlMapBlock $grandLines
        }
    }

    return $map
}

# ------------------------------------------------------------------
# Feature-ledger discovery + validation.
# ------------------------------------------------------------------
function Read-FeatureLedger {
    <#
    Parse one F-NNN-<slug>.md. Returns [ordered]@{} with keys:
      file, frontmatter, slug, parseError (if any).
    Hard-fails (exit 1) if a required key is missing.
    #>
    param([string]$Path)

    $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
    $fm = Get-FrontmatterText $raw
    if ($null -eq $fm) {
        Write-Error "Malformed feature ledger (no YAML frontmatter): $Path"
        exit 1
    }

    $parsed = ConvertFrom-MinimalYaml $fm

    $missing = @()
    foreach ($k in $script:RequiredKeys) {
        if (-not $parsed.Contains($k)) { $missing += $k }
    }
    if ($missing.Count -gt 0) {
        Write-Error ("Feature ledger missing required keys: {0}`nFile: {1}" -f ($missing -join ', '), $Path)
        exit 1
    }

    if ($parsed['artifact-class'] -ne 'feature-ledger') {
        Write-Error "Feature ledger has wrong artifact-class '$($parsed['artifact-class'])': $Path"
        exit 1
    }

    # Slug = filename minus F-NNN- prefix and .md suffix.
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $slug = $base -replace '^F-\d+-', ''

    return [ordered]@{
        file = $Path
        frontmatter = $parsed
        slug = $slug
        feature_id = [string]$parsed['feature-id']
    }
}

function Get-DependsOnList {
    param($Frontmatter)

    $deps = $Frontmatter['depends-on']
    if ($null -eq $deps) { return @() }

    # Could be array of strings, array of maps, or a single string.
    $out = @()
    foreach ($d in @($deps)) {
        if ($d -is [string]) { $out += $d }
        elseif ($d -is [System.Collections.IDictionary]) {
            # If it's a map (unusual), pull a `feature` or `id` key if present.
            foreach ($cand in @('feature', 'id', 'feature-id')) {
                if ($d.Contains($cand)) { $out += [string]$d[$cand]; break }
            }
        }
    }
    return @($out | Where-Object { $_ -ne '' })
}

function Get-TestFilesByProject {
    <#
    Returns [ordered]@{ unit=[]; node=[]; browser=[]; integration=[]; e2e=[] }.
    #>
    param($Frontmatter)

    $tf = $Frontmatter['test-files']
    $out = [ordered]@{}
    foreach ($p in $script:ValidProjects) { $out[$p] = @() }
    if ($null -eq $tf) { return $out }
    if (-not ($tf -is [System.Collections.IDictionary])) { return $out }

    foreach ($p in $script:ValidProjects) {
        if ($tf.Contains($p)) {
            $list = $tf[$p]
            if ($null -eq $list) { continue }
            $out[$p] = @($list | Where-Object { $_ -is [string] -and $_ -ne '' })
        }
    }
    return $out
}

# ------------------------------------------------------------------
# Topological sort (Kahn).
# ------------------------------------------------------------------
function Get-TopologicalOrder {
    <#
    Input: hashtable id -> @(deps).
    Output:
      [ordered]@{ order=@(); cycle=@() } where cycle is nonempty if a cycle exists.
    #>
    param([hashtable]$Graph)

    $indeg = @{}
    foreach ($k in $Graph.Keys) { $indeg[$k] = 0 }
    foreach ($k in $Graph.Keys) {
        foreach ($dep in $Graph[$k]) {
            if ($indeg.ContainsKey($dep)) { $indeg[$dep] = $indeg[$dep] + 0 }
            # Note: graph stores depends-on; "k depends on dep" -> dep must come first
            # so edge is dep -> k. Indegree on k from each dep.
            $indeg[$k] = $indeg[$k] + 1
        }
    }

    # Re-derive correctly: indeg(k) = count of deps of k that are in the graph.
    $indeg = @{}
    foreach ($k in $Graph.Keys) {
        $count = 0
        foreach ($dep in $Graph[$k]) {
            if ($Graph.ContainsKey($dep)) { $count++ }
        }
        $indeg[$k] = $count
    }

    $queue = New-Object System.Collections.Queue
    foreach ($k in ($Graph.Keys | Sort-Object)) {
        if ($indeg[$k] -eq 0) { [void]$queue.Enqueue($k) }
    }

    $order = @()
    while ($queue.Count -gt 0) {
        $n = $queue.Dequeue()
        $order += $n
        # For every k that depends on n, decrement indeg.
        foreach ($k in ($Graph.Keys | Sort-Object)) {
            if ($Graph[$k] -contains $n) {
                $indeg[$k]--
                if ($indeg[$k] -eq 0) { [void]$queue.Enqueue($k) }
            }
        }
    }

    if ($order.Count -lt $Graph.Keys.Count) {
        # Cycle exists. Identify nodes still with indeg > 0.
        $cycleNodes = @($Graph.Keys | Where-Object { $indeg[$_] -gt 0 } | Sort-Object)
        return [ordered]@{ order = $order; cycle = $cycleNodes }
    }

    return [ordered]@{ order = $order; cycle = @() }
}

# ------------------------------------------------------------------
# Tooling probe.
# ------------------------------------------------------------------
function Test-ToolOnPath {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

# ------------------------------------------------------------------
# Test runners.
# ------------------------------------------------------------------
function Invoke-VitestProject {
    <#
    Returns [ordered]@{ exit=N; runtime_ms=M; stdout='...'; missing_files=@() }.
    Skips the whole runner if pnpm is missing -> exit 127, missing tag.
    Treats missing test files as RED contributors but does NOT count them as
    runner exits (returns missing_files list separately).
    #>
    param(
        [string]$Project,
        [string[]]$TestFiles,
        [string]$WorkspaceRoot
    )

    $absoluteTests = @()
    $missing = @()
    foreach ($rel in $TestFiles) {
        $abs = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $WorkspaceRoot $rel }
        if (Test-Path $abs) { $absoluteTests += $abs } else { $missing += $rel }
    }

    if ($absoluteTests.Count -eq 0) {
        return [ordered]@{ exit = 0; runtime_ms = 0; stdout = '(no existing files; missing-files contributes RED)'; missing_files = $missing }
    }

    if (-not (Test-ToolOnPath 'pnpm')) {
        return [ordered]@{ exit = 127; runtime_ms = 0; stdout = 'TOOLING_MISSING: pnpm not found on PATH'; missing_files = $missing }
    }

    $argsList = @('vitest', 'run', '--project', $Project) + $absoluteTests
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # Toggle to 'Continue' so native command stderr does not throw.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & pnpm @argsList 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prev

    $sw.Stop()
    return [ordered]@{
        exit = $exitCode
        runtime_ms = [int]$sw.ElapsedMilliseconds
        stdout = ($output -join "`n")
        missing_files = $missing
    }
}

function Invoke-PlaywrightSuite {
    param(
        [string[]]$TestFiles,
        [string]$WorkspaceRoot
    )

    $absoluteTests = @()
    $missing = @()
    foreach ($rel in $TestFiles) {
        $abs = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $WorkspaceRoot $rel }
        if (Test-Path $abs) { $absoluteTests += $abs } else { $missing += $rel }
    }

    if ($absoluteTests.Count -eq 0) {
        return [ordered]@{ exit = 0; runtime_ms = 0; stdout = '(no existing files)'; missing_files = $missing }
    }

    if (-not (Test-ToolOnPath 'pnpm')) {
        return [ordered]@{ exit = 127; runtime_ms = 0; stdout = 'TOOLING_MISSING: pnpm not found on PATH'; missing_files = $missing }
    }

    $argsList = @('playwright', 'test', '--reporter=json') + $absoluteTests
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & pnpm @argsList 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prev

    $sw.Stop()
    return [ordered]@{
        exit = $exitCode
        runtime_ms = [int]$sw.ElapsedMilliseconds
        stdout = ($output -join "`n")
        missing_files = $missing
    }
}

# ------------------------------------------------------------------
# /feature-lock invocation (deferred until skill is implemented).
# ------------------------------------------------------------------
function Invoke-FeatureLockTransition {
    <#
    TODO(Wave 2): replace this warn-only stub with the real /feature-lock
    invocation once .claude/skills/feature-lock/SKILL.md ships. Per the
    Wave 1B contract in the plan, this script must NOT write the F-NNN file
    directly -- the canonical-skill-active enforcement model gates F-NNN
    writes via .claude/hooks/validate-mad-pipeline.js. The right answer
    after the skill is built is to shell out to the orchestrator's Skill
    invocation (via a sentinel file that the user/operator picks up, or a
    direct skill dispatch when this script runs inside an autonomous loop).
    Until then: log loudly and continue.
    #>
    param(
        [string]$FeatureId,
        [string]$NewStatus,
        [string]$Rationale
    )

    $msg = "Would invoke /feature-lock --transition $NewStatus --feature $FeatureId --rationale `"$Rationale`" -- skill not yet implemented; ledger NOT updated."
    Write-Warning $msg
    return $msg
}

# ------------------------------------------------------------------
# Main.
# ------------------------------------------------------------------

# Resolve FeaturesDir.
if (-not (Test-Path -LiteralPath $FeaturesDir)) {
    [Console]::Error.WriteLine("ERROR: FeaturesDir does not exist: $FeaturesDir")
    exit 1
}
$FeaturesDirAbs = (Resolve-Path -LiteralPath $FeaturesDir).Path
$WorkspaceRoot = Split-Path -Parent $FeaturesDirAbs

# Resolve TestsDir default.
if ([string]::IsNullOrWhiteSpace($TestsDir)) {
    $TestsDir = Join-Path $WorkspaceRoot 'tests'
}

# Resolve ReportDir (create if missing).
if (-not (Test-Path -LiteralPath $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}
$ReportDirAbs = (Resolve-Path -LiteralPath $ReportDir).Path

# Reviews directory for LOCKED gate.
$ReviewsDir = Join-Path $WorkspaceRoot 'reviews'
$StatusDir = Join-Path $WorkspaceRoot 'status'

# ------------------------------------------------------------------
# Discover ledger files.
# ------------------------------------------------------------------
$ledgerFiles = @(Get-ChildItem -Path $FeaturesDirAbs -Filter 'F-*.md' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'README.md' } |
    Sort-Object Name)

if ($ledgerFiles.Count -eq 0 -and -not $DryRun) {
    [Console]::Error.WriteLine("ERROR: No F-NNN-*.md feature-ledger files found in: $FeaturesDirAbs")
    exit 1
}

$ledgers = @()
foreach ($f in $ledgerFiles) {
    $ledgers += Read-FeatureLedger -Path $f.FullName
}

# ------------------------------------------------------------------
# Filter.
# ------------------------------------------------------------------
$filtered = $ledgers
if ($FeatureFilter.Count -gt 0) {
    $filterSet = $FeatureFilter | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $filtered = @($filtered | Where-Object { $filterSet -contains $_.feature_id })
}
if ($StatusFilter -ne 'all') {
    $filtered = @($filtered | Where-Object { [string]$_.frontmatter['status'] -eq $StatusFilter })
}

# ------------------------------------------------------------------
# Build dependency graph and topo-sort. Cycle detection on the FILTERED set
# is risky (filtering may break edges) -- run the cycle check on the FULL set.
# ------------------------------------------------------------------
$graph = @{}
foreach ($l in $ledgers) {
    $graph[$l.feature_id] = Get-DependsOnList $l.frontmatter
}

$topo = Get-TopologicalOrder -Graph $graph
if ($topo.cycle.Count -gt 0) {
    [Console]::Error.WriteLine(("ERROR: Dependency-graph cycle detected among: {0}" -f ($topo.cycle -join ' <-> ')))
    exit 3
}

# Apply topo order to the filtered set, preserving discovery order for ties.
$idToLedger = @{}
foreach ($l in $ledgers) { $idToLedger[$l.feature_id] = $l }
$orderedFiltered = @()
foreach ($id in $topo.order) {
    if ($filtered | Where-Object { $_.feature_id -eq $id }) {
        $orderedFiltered += $idToLedger[$id]
    }
}

# ------------------------------------------------------------------
# Execute (or DryRun).
# ------------------------------------------------------------------
$runResults = @()
$toolingMissingNoted = $false

foreach ($l in $orderedFiltered) {
    $fid = $l.feature_id
    $ledgerStatus = [string]$l.frontmatter['status']
    $depsList = Get-DependsOnList $l.frontmatter
    $tfMap = Get-TestFilesByProject $l.frontmatter
    $provenance = $l.frontmatter['provenance']

    $perProject = [ordered]@{}
    $totalRuntime = 0
    $hasNonZero = $false
    $hasMissing = $false
    $toolingMissing = $false

    if ($DryRun) {
        $runStatus = 'DRY-RUN'
    }
    else {
        foreach ($p in $script:ValidProjects) {
            $files = $tfMap[$p]
            if ($files.Count -eq 0) { continue }

            if ($p -eq 'e2e') {
                $r = Invoke-PlaywrightSuite -TestFiles $files -WorkspaceRoot $WorkspaceRoot
            }
            else {
                $r = Invoke-VitestProject -Project $p -TestFiles $files -WorkspaceRoot $WorkspaceRoot
            }

            $perProject[$p] = $r
            $totalRuntime += [int]$r.runtime_ms
            if ($r.missing_files.Count -gt 0) { $hasMissing = $true }
            if ($r.exit -eq 127) {
                $toolingMissing = $true
                $toolingMissingNoted = $true
            }
            elseif ($r.exit -ne 0) {
                $hasNonZero = $true
            }
        }

        if ($toolingMissing -or $hasNonZero -or $hasMissing) {
            $runStatus = 'red'
        }
        else {
            $runStatus = 'green'
        }

        # LOCKED requires green AND review file with verdict: ACCEPT.
        if ($runStatus -eq 'green') {
            $reviewFile = Join-Path $ReviewsDir ("{0}-{1}-review.md" -f $fid, $l.slug)
            if (Test-Path $reviewFile) {
                $reviewContent = Get-Content $reviewFile -Raw -ErrorAction SilentlyContinue
                if ($reviewContent -match '(?im)^\s*verdict\s*:\s*ACCEPT\s*$') {
                    $runStatus = 'locked'
                }
            }
        }
    }

    $drift = '-'
    if (-not $DryRun -and $runStatus -ne $ledgerStatus) {
        if ($ledgerStatus -eq 'red' -and $runStatus -eq 'green') {
            $drift = 'DRIFT-EARLY-GREEN'
        }
        elseif ($ledgerStatus -eq 'green' -and $runStatus -eq 'red') {
            $drift = 'REGRESSION-GREEN-TO-RED'
        }
        elseif ($ledgerStatus -eq 'locked' -and $runStatus -ne 'locked') {
            $drift = 'REGRESSION-FROM-LOCKED'
        }
        else {
            $drift = "DRIFT:${ledgerStatus}->${runStatus}"
        }
    }

    $provenanceSurfaces = @()
    if ($provenance -is [System.Collections.IDictionary] -and $provenance.Contains('surfaces')) {
        $provenanceSurfaces = @($provenance['surfaces'])
    }

    $runResults += [ordered]@{
        feature_id = $fid
        slug = $l.slug
        ledger_status = $ledgerStatus
        run_status = $runStatus
        drift = $drift
        runtime_ms = $totalRuntime
        depends_on = $depsList
        provenance_surfaces = $provenanceSurfaces
        per_project = $perProject
        tooling_missing = $toolingMissing
        ledger_file = $l.file
    }
}

# ------------------------------------------------------------------
# Aggregate counts and exit-code resolution.
# ------------------------------------------------------------------
$redCount = @($runResults | Where-Object { $_.run_status -eq 'red' }).Count
$greenCount = @($runResults | Where-Object { $_.run_status -eq 'green' }).Count
$lockedCount = @($runResults | Where-Object { $_.run_status -eq 'locked' }).Count
$missingTests = @($runResults | Where-Object {
    $any = $false
    foreach ($p in $_.per_project.Keys) {
        if ($_.per_project[$p].missing_files.Count -gt 0) { $any = $true; break }
    }
    $any
}).Count
$regressions = @($runResults | Where-Object { $_.drift -like 'REGRESSION-*' -or $_.drift -eq 'DRIFT-EARLY-GREEN' }).Count

$earlyGreenDrifts = @($runResults | Where-Object { $_.drift -eq 'DRIFT-EARLY-GREEN' })

# ------------------------------------------------------------------
# Update ledger (warn-only stub).
# ------------------------------------------------------------------
if ($UpdateLedger -and -not $DryRun) {
    foreach ($r in $runResults) {
        if ($r.drift -ne '-' -and $r.drift -notlike 'TOOLING_*') {
            $reason = "auto-detected by Run-FeatureEval.ps1"
            Invoke-FeatureLockTransition -FeatureId $r.feature_id -NewStatus $r.run_status -Rationale $reason | Out-Null
        }
    }
}

# ------------------------------------------------------------------
# Write report.
# ------------------------------------------------------------------
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runAtIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$reportPathMd = Join-Path $ReportDirAbs ("feature-status-{0}.md" -f $ts)
$reportPathLatestJson = Join-Path $ReportDirAbs 'feature-status-latest.json'
$workspaceLatestJson = Join-Path $StatusDir 'feature-status-latest.json'

# Build markdown body.
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('---')
$lines.Add('artifact-class: feature-status-report')
$lines.Add('generated-by: Run-FeatureEval.ps1')
$lines.Add('generated-by-version: 1.0.0')
$lines.Add("features-dir: $FeaturesDirAbs")
$lines.Add("run-at: $runAtIso")
$lines.Add("total-features: $($runResults.Count)")
$lines.Add("red-count: $redCount")
$lines.Add("green-count: $greenCount")
$lines.Add("locked-count: $lockedCount")
$lines.Add("missing-tests: $missingTests")
$lines.Add("regressions: $regressions")
$lines.Add('---')
$lines.Add('')
$lines.Add('# Feature status report')
$lines.Add('')
$lines.Add("Generated: $runAtIso")
$lines.Add("Workspace: $WorkspaceRoot")
$lines.Add('')
$lines.Add('| F-ID | slug | status (ledger) | status (run) | drift | runtime ms | depends-on | provenance |')
$lines.Add('|------|------|------------------|---------------|-------|------------|------------|------------|')

if ($runResults.Count -eq 0) {
    # Header only; no rows.
}
else {
    foreach ($r in $runResults) {
        $depsTxt = if ($r.depends_on.Count -gt 0) { $r.depends_on -join ', ' } else { '-' }
        $provTxt = if ($r.provenance_surfaces.Count -gt 0) { $r.provenance_surfaces -join ', ' } else { '-' }
        $lines.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f `
            $r.feature_id, $r.slug, $r.ledger_status, $r.run_status, $r.drift, $r.runtime_ms, $depsTxt, $provTxt))
    }
}

$lines.Add('')
if ($toolingMissingNoted) {
    $lines.Add('## Tooling notes')
    $lines.Add('')
    $lines.Add('- TOOLING_MISSING: `pnpm` was not found on PATH for at least one feature. Those features were classified RED (tooling missing). Install pnpm and re-run to get a runtime answer.')
    $lines.Add('')
}

# Write Markdown (UTF-8 no BOM per powershell-conventions.md UTF-8 BOM Gotcha).
$mdText = ($lines -join "`n")
[System.IO.File]::WriteAllText($reportPathMd, $mdText, (New-Object System.Text.UTF8Encoding $false))

# Build JSON sibling.
$jsonObj = [ordered]@{
    artifact_class = 'feature-status-report'
    generated_by = 'Run-FeatureEval.ps1'
    generated_by_version = '1.0.0'
    features_dir = $FeaturesDirAbs
    workspace_root = $WorkspaceRoot
    run_at = $runAtIso
    total_features = $runResults.Count
    red_count = $redCount
    green_count = $greenCount
    locked_count = $lockedCount
    missing_tests = $missingTests
    regressions = $regressions
    dry_run = [bool]$DryRun
    expect_red = [bool]$ExpectRed
    update_ledger = [bool]$UpdateLedger
    feature_filter = @($FeatureFilter)
    status_filter = $StatusFilter
    tooling_missing_any = $toolingMissingNoted
    features = @($runResults | ForEach-Object {
        $r = $_
        $proj = [ordered]@{}
        foreach ($k in $r.per_project.Keys) {
            $entry = $r.per_project[$k]
            $proj[$k] = [ordered]@{
                exit = $entry.exit
                runtime_ms = $entry.runtime_ms
                missing_files = @($entry.missing_files)
            }
        }
        [ordered]@{
            feature_id = $r.feature_id
            slug = $r.slug
            ledger_status = $r.ledger_status
            run_status = $r.run_status
            drift = $r.drift
            runtime_ms = $r.runtime_ms
            depends_on = @($r.depends_on)
            provenance_surfaces = @($r.provenance_surfaces)
            tooling_missing = $r.tooling_missing
            ledger_file = $r.ledger_file
            per_project = $proj
        }
    })
}

$jsonText = $jsonObj | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($reportPathLatestJson, $jsonText, (New-Object System.Text.UTF8Encoding $false))

# Copy JSON into the spec workspace's status/ directory.
if (-not (Test-Path -LiteralPath $StatusDir)) {
    New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null
}
[System.IO.File]::WriteAllText($workspaceLatestJson, $jsonText, (New-Object System.Text.UTF8Encoding $false))

# ------------------------------------------------------------------
# Console summary.
# ------------------------------------------------------------------
Write-Host ''
Write-Host "Feature status report written:" -ForegroundColor Green
Write-Host "  Markdown: $reportPathMd"
Write-Host "  JSON:     $reportPathLatestJson"
Write-Host "  Workspace JSON: $workspaceLatestJson"
Write-Host ''
Write-Host ("Totals: total={0} red={1} green={2} locked={3} missing-tests={4} regressions={5}" -f `
    $runResults.Count, $redCount, $greenCount, $lockedCount, $missingTests, $regressions) -ForegroundColor Cyan

if ($toolingMissingNoted) {
    Write-Host "TOOLING_MISSING: pnpm not found on PATH; features dependent on it were classified RED." -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# Exit-code resolution.
# ------------------------------------------------------------------
if ($ExpectRed -and $earlyGreenDrifts.Count -gt 0) {
    Write-Host ("ExpectRed: {0} feature(s) drifted RED->GREEN early; treating as regression." -f $earlyGreenDrifts.Count) -ForegroundColor Yellow
    exit 4
}

if ($DryRun) {
    exit 0
}

if ($redCount -gt 0) {
    Write-Host "At least one feature is RED at runtime." -ForegroundColor Red
    exit 2
}

exit 0
