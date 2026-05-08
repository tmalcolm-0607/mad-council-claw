<#
.SYNOPSIS
Generic coverage verifier - asserts that every source identifier appears in
one or more target artifacts. Replaces three per-skill verifiers
(Verify-PhaseCoverage, Verify-TaskCoverage, Verify-TestCoverage) with a
single parameterized engine.

.DESCRIPTION
Generalization of Verify-SourceCoverage.ps1. The original engine was 70%
generic - the only LENS-CMS-specific knob was a hardcoded FR-ID regex.
This script lifts that knob into a parameter and adds:

  - Multiple target paths (any number of files cross-referenced at once)
  - Configurable target-reference regex (when source IDs and target refs
    use different formats; default = same as SourceIdRegex)
  - Strict vs Lenient mode (Strict flags orphan target refs; Lenient
    tolerates them - useful when targets legitimately reference items
    outside the source set, e.g. test cases pulling from contracts)
  - Per-target coverage matrix in the JSON output
  - Markdown matrix block ready to paste into target artifacts

Use cases (single script, three regexes):

  /mad-plan        SourceIdRegex='FR-[A-Z][A-Z0-9-]*-\d+', target=plan.md
  /mad-tasks       SourceIdRegex='FR-[A-Z][A-Z0-9-]*-\d+', target=tasks.md
  /mad-testplan    SourceIdRegex='FR-[A-Z][A-Z0-9-]*-\d+', target=test-plan.md
  /mad-tasks       SourceIdRegex='T\d{3,}',                target=tasks.md (self-reference)
  /testplan        SourceIdRegex='TC-[A-Z0-9-]+',          target=test-plan.md

.PARAMETER SourcePath
Path to the file containing source identifiers (e.g. spec.md, the
authoritative requirements artifact).

.PARAMETER TargetPaths
One or more paths to target artifacts that should reference the source
identifiers (e.g. plan.md, tasks.md, test-plan.md).

.PARAMETER SourceIdRegex
Regex pattern that matches identifiers in the source file. Examples:
  'FR-[A-Z][A-Z0-9-]*-\d+'    - functional requirement IDs
  'T\d{3,}'                   - task IDs (T001, T015, T100)
  'TC-[A-Z0-9-]+'             - test case IDs
  'NFR-[A-Z][A-Z0-9-]*-\d+'   - non-functional requirement IDs

.PARAMETER TargetReferenceRegex
Regex pattern that matches references in the target files. Defaults to
SourceIdRegex (same shape on both sides). Override when source uses one
shape and targets use another (rare).

.PARAMETER OutputJson
Path to write JSON output. Defaults to .mad/scratch/coverage-{ts}.json.

.PARAMETER Mode
Strict (default) or Lenient.
  Strict  - emits 'orphan_target_refs' when a target references an ID not
            in the source set. Used for tasks.md / plan.md (every FR
            reference there should trace to spec.md).
  Lenient - skips the orphan check. Used when targets legitimately pull
            references from artifacts other than the named source (e.g.
            test-plan.md may reference contract IDs from contracts/*.md).

.EXAMPLE
# FR coverage from spec.md to plan.md
pwsh -NoProfile -File .claude/scripts/Verify-Coverage.ps1 `
  -SourcePath specs/15-feat/spec.md `
  -TargetPaths specs/15-feat/plan.md `
  -SourceIdRegex 'FR-[A-Z][A-Z0-9-]*-\d+'

.EXAMPLE
# FR coverage to multiple targets at once
pwsh -NoProfile -File .claude/scripts/Verify-Coverage.ps1 `
  -SourcePath specs/15-feat/spec.md `
  -TargetPaths specs/15-feat/plan.md, specs/15-feat/tasks.md, specs/15-feat/test-plan.md `
  -SourceIdRegex 'FR-[A-Z][A-Z0-9-]*-\d+'

.EXAMPLE
# Task ID self-coverage in tasks.md (orphan check disabled)
pwsh -NoProfile -File .claude/scripts/Verify-Coverage.ps1 `
  -SourcePath specs/15-feat/tasks.md `
  -TargetPaths specs/15-feat/tasks.md `
  -SourceIdRegex 'T\d{3,}' `
  -Mode Lenient

.NOTES
Per workflow improvement plan Wave 1 Lane Beta: replace three per-skill
coverage verifiers with one engine. Verify-SourceCoverage.ps1 is now a
thin wrapper that calls this script with the FR regex hardcoded.

Backward compatibility: existing callers of Verify-SourceCoverage.ps1
continue to work; same exit codes, same JSON shape (with extra fields
for the multi-target case).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourcePath,

  [Parameter(Mandatory = $true)]
  [string[]]$TargetPaths,

  [Parameter(Mandatory = $true)]
  [string]$SourceIdRegex,

  [string]$TargetReferenceRegex = "",

  [string]$OutputJson = "",

  [ValidateSet("Strict", "Lenient")]
  [string]$Mode = "Strict"
)

$ErrorActionPreference = "Stop"

# --- 1. Validate inputs ---------------------------------------------------

if (-not (Test-Path $SourcePath)) {
  Write-Error "Source file not found: $SourcePath"
  exit 3
}

$missingTargets = @()
foreach ($t in $TargetPaths) {
  if (-not (Test-Path $t)) {
    $missingTargets += $t
  }
}
if ($missingTargets.Count -gt 0) {
  Write-Error ("Target file(s) not found: " + ($missingTargets -join ', '))
  exit 3
}

# Validate the source regex compiles
try {
  $null = [regex]::new($SourceIdRegex)
} catch {
  Write-Error "SourceIdRegex is not a valid regex: $SourceIdRegex - $_"
  exit 3
}

# Default target regex to source regex
if ([string]::IsNullOrWhiteSpace($TargetReferenceRegex)) {
  $TargetReferenceRegex = $SourceIdRegex
}

try {
  $null = [regex]::new($TargetReferenceRegex)
} catch {
  Write-Error "TargetReferenceRegex is not a valid regex: $TargetReferenceRegex - $_"
  exit 3
}

# Default output path under .mad/scratch/
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
  $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $ScratchDir = ".mad/scratch"
  if (-not (Test-Path $ScratchDir)) {
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
  }
  $OutputJson = Join-Path $ScratchDir "coverage-$ts.json"
}

# --- 2. ID extraction ----------------------------------------------------

function Get-DistinctIds {
  param(
    [string]$Path,
    [string]$Pattern
  )
  $found = Select-String -Path $Path -Pattern $Pattern -AllMatches |
    ForEach-Object { $_.Matches } |
    ForEach-Object { $_.Value }
  if ($null -eq $found) { return @() }
  return ($found | Sort-Object -Unique)
}

$sourceIds = @(Get-DistinctIds -Path $SourcePath -Pattern $SourceIdRegex)

# Per-target reference extraction
$perTarget = @()
$allTargetRefs = @()
foreach ($t in $TargetPaths) {
  $refs = @(Get-DistinctIds -Path $t -Pattern $TargetReferenceRegex)
  $perTarget += [pscustomobject]@{
    path  = $t
    refs  = $refs
    count = $refs.Count
  }
  $allTargetRefs += $refs
}
$allTargetRefs = @($allTargetRefs | Sort-Object -Unique)

# --- 3. Set differences --------------------------------------------------

# Source IDs not present in ANY target = missing
$missingIds = @($sourceIds | Where-Object { $allTargetRefs -notcontains $_ })

# Target refs not present in source = orphan (Strict mode only)
$orphanTargetRefs = @()
if ($Mode -eq "Strict") {
  $orphanTargetRefs = @($allTargetRefs | Where-Object { $sourceIds -notcontains $_ })
}

$coveredIds = @($sourceIds | Where-Object { $allTargetRefs -contains $_ })

# Per-target coverage map: which source IDs each target covers
$perTargetCoverage = @()
foreach ($t in $perTarget) {
  $coversFromSource = @($t.refs | Where-Object { $sourceIds -contains $_ } | Sort-Object -Unique)
  $perTargetCoverage += [pscustomobject]@{
    path             = $t.path
    total_refs       = $t.count
    covers_source    = $coversFromSource
    covers_count     = $coversFromSource.Count
  }
}

# Per-source-ID rows showing which target(s) cover it
$rows = @()
foreach ($id in $sourceIds) {
  $coveredBy = @()
  foreach ($t in $perTarget) {
    if ($t.refs -contains $id) {
      $coveredBy += $t.path
    }
  }
  $rows += [pscustomobject]@{
    source_id   = $id
    covered     = ($coveredBy.Count -gt 0)
    covered_by  = $coveredBy
  }
}

# --- 4. Summary computation ----------------------------------------------

$sourceCount = $sourceIds.Count
$coveredCount = $coveredIds.Count
$missingCount = $missingIds.Count
$coveragePct = if ($sourceCount -eq 0) { 100.0 } else { [math]::Round(($coveredCount / $sourceCount) * 100.0, 2) }
$fullyCovered = ($missingCount -eq 0)

$result = [ordered]@{
  source_path          = $SourcePath
  target_paths         = $TargetPaths
  source_id_regex      = $SourceIdRegex
  target_ref_regex     = $TargetReferenceRegex
  mode                 = $Mode
  source_ids           = $sourceIds
  covered_ids          = $coveredIds
  missing_ids          = $missingIds
  orphan_target_refs   = $orphanTargetRefs
  per_target_coverage  = $perTargetCoverage
  rows                 = $rows
  summary              = [ordered]@{
    source_count   = $sourceCount
    covered_count  = $coveredCount
    missing_count  = $missingCount
    coverage_pct   = $coveragePct
    fully_covered  = $fullyCovered
  }
  generated_at         = (Get-Date).ToString("o")
}

# Write UTF-8 without BOM (PS 5.1 compat - tools like az reject BOM)
$jsonString = ($result | ConvertTo-Json -Depth 8)
$outDir = Split-Path -Parent $OutputJson
if ($outDir -and -not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$absOutput = if ([System.IO.Path]::IsPathRooted($OutputJson)) {
  $OutputJson
} else {
  Join-Path (Get-Location).Path $OutputJson
}
[System.IO.File]::WriteAllText(
  $absOutput,
  $jsonString,
  (New-Object System.Text.UTF8Encoding $false)
)

# --- 5. Markdown matrix block (paste-ready) ------------------------------

$mdLines = @()
$mdLines += '<!-- coverage-matrix:begin -->'
$mdLines += "## Coverage Matrix"
$mdLines += ""
$mdLines += "Source: ``$SourcePath`` (pattern ``$SourceIdRegex``)"
$mdLines += "Mode: $Mode | Coverage: $coveragePct% ($coveredCount / $sourceCount)"
$mdLines += ""
$targetHeader = "| Source ID | " + (($TargetPaths | ForEach-Object { (Split-Path -Leaf $_) }) -join " | ") + " | Status |"
$separator    = "|-----------|" + (($TargetPaths | ForEach-Object { "------" }) -join "|") + "|--------|"
$mdLines += $targetHeader
$mdLines += $separator
foreach ($row in $rows) {
  $cells = @($row.source_id)
  foreach ($t in $TargetPaths) {
    if ($row.covered_by -contains $t) {
      $cells += 'YES'
    } else {
      $cells += '-'
    }
  }
  $cells += $(if ($row.covered) { 'COVERED' } else { 'MISSING' })
  $mdLines += "| " + ($cells -join " | ") + " |"
}
if ($missingIds.Count -gt 0) {
  $mdLines += ""
  $mdLines += "### Missing source IDs (not referenced in any target)"
  foreach ($m in $missingIds) { $mdLines += "- $m" }
}
if ($Mode -eq "Strict" -and $orphanTargetRefs.Count -gt 0) {
  $mdLines += ""
  $mdLines += "### Orphan target references (referenced in target, not in source)"
  foreach ($o in $orphanTargetRefs) { $mdLines += "- $o" }
}
$mdLines += '<!-- coverage-matrix:end -->'

$mdPath = [System.IO.Path]::ChangeExtension($absOutput, '.md')
[System.IO.File]::WriteAllText(
  $mdPath,
  ($mdLines -join "`n"),
  (New-Object System.Text.UTF8Encoding $false)
)

# --- 6. Human-readable summary to stdout ---------------------------------

"source_path     = $SourcePath"
"target_paths    = $($TargetPaths -join ', ')"
"source_id_regex = $SourceIdRegex"
"mode            = $Mode"
"source_count    = $sourceCount"
"covered_count   = $coveredCount"
"missing_count   = $missingCount"
"coverage_pct    = $coveragePct%"
""
"missing source IDs (not in any target):"
if ($missingIds.Count -eq 0) {
  "  (none)"
} else {
  foreach ($m in $missingIds) { "  - $m" }
}
if ($Mode -eq "Strict") {
  ""
  "orphan target refs (in target, not in source):"
  if ($orphanTargetRefs.Count -eq 0) {
    "  (none)"
  } else {
    foreach ($o in $orphanTargetRefs) { "  - $o" }
  }
}
""
"json written to: $OutputJson"
"markdown written to: $mdPath"

# --- 7. Exit codes -------------------------------------------------------

if ($missingCount -gt 0) {
  exit 2
}
exit 0
