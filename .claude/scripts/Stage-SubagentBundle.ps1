<#
.SYNOPSIS
Stage a canonical context bundle for subagent fan-out. Replaces conversational
LLM emission of "here's the context" preambles in /mad-plan, /mad-tasks,
/testplan, and any skill that fans out to >=2 parallel subagents.

.DESCRIPTION
Per CLAUDE.md "Speed pathologies" #2 (cold-read amplification):

  Each subagent reads the world from cold. If 3 subagents each read SKILL.md
  (700 lines) + CLAUDE.md (300 lines) + memory rules + source spec, that's
  redundant I/O. Pre-stage a single context bundle in .mad/scratch/ and pass
  the path; subagents read once.

This script is the canonical bundle emitter. It writes a Markdown bundle file
that future subagents can read with a SINGLE Read call. Replaces ~5-10 minutes
of conversational preamble across 3 parallel lanes with <500ms of script work.

The emitted bundle shape:

  # <SkillName> context bundle - <RunId>

  ## Source artifacts          (paths the subagents will edit)
  ## Prior canonical artifacts (paths whose content is the source-of-truth precedent)
  ## Pipeline state            (path to mad-pipeline-active.json + resolved session_id)
  ## Memory rules              (paths only - subagents Read on demand)
  ## Lane charters             (one block per lane the orchestrator will spawn)
  ## Subagent prompt boilerplate footer

.PARAMETER SkillName
Mandatory. The MAD skill that owns the fan-out (e.g. mad-plan, mad-tasks,
testplan). Stamped into the bundle header.

.PARAMETER RunId
Optional. Run identifier; defaults to a random GUID-style token. Stamped into
the bundle header and used in the default output path.

.PARAMETER SourceArtifacts
Mandatory. One or more paths to source artifacts (e.g. spec.md, plan.md). Each
must exist - missing source artifacts exit 2.

.PARAMETER PriorArtifacts
Optional. Paths to prior canonical artifacts (e.g. an iter-N inline-snapshot
spec.md). Existence is verified but missing entries are listed under
"(missing)" rather than aborting - prior artifacts are advisory.

.PARAMETER LaneCharters
Optional. Hashtable mapping {laneId -> charterText}. Each entry is rendered as
a "## Lane <id>" block in the bundle. Subagents read their lane charter as
their primary instruction.

.PARAMETER AntipatternMemoryRules
Optional. Paths to memory-rule files (e.g.
.claude/rules/no-top-n-capping.md). Listed in the bundle so subagents know
which rules apply to their fan-out without cold-reading the rule files.

.PARAMETER OutputPath
Optional. Bundle output path; defaults to
.mad/scratch/<SkillName>-context-<RunId>.md.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Stage-SubagentBundle.ps1 `
  -SkillName "mad-plan" `
  -SourceArtifacts @("specs/15-collab-engine-canonical-e/spec.md") `
  -OutputPath ".mad/scratch/test-bundle-smoke.md"

.NOTES
Wave 1 Lane gamma deliverable. Used by /mad-plan Step X (parallel domain-review
fan-out), /mad-tasks Step Y (parallel task-grouping fan-out), /testplan Step Z
(parallel test-suite fan-out). Each skill body invokes this script once, then
hands the resulting path to its parallel Task subagent spawns.

Exit codes:
  0  success
  1  invalid params
  2  source artifact missing
  3  setup error (output dir creation failed, write failed, etc.)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$SkillName,
  [string]$RunId = "",
  [Parameter(Mandatory = $true)] [string[]]$SourceArtifacts,
  [string[]]$PriorArtifacts = @(),
  [hashtable]$LaneCharters = $null,
  [string[]]$AntipatternMemoryRules = @(),
  [string]$OutputPath = ""
)

# Hybrid error handling per .claude/rules/patterns/powershell-conventions.md:
# 'Stop' for cmdlets, $LASTEXITCODE for native commands. No native commands in
# this script, so 'Stop' is safe throughout.
$ErrorActionPreference = 'Stop'

# ---- Param validation ------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($SkillName)) {
  Write-Error "SkillName is required and must be non-empty."
  exit 1
}

if (-not ($SkillName -match '^[a-z][a-z0-9-]*$')) {
  # Permissive: warn but don't reject - some tooling may use prefixed names.
  Write-Warning "SkillName '$SkillName' does not match canonical kebab-case pattern."
}

if ($SourceArtifacts.Count -eq 0) {
  Write-Error "SourceArtifacts must contain at least one path."
  exit 1
}

# Generate RunId if not provided. GUID-style for collision resistance.
if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = [guid]::NewGuid().ToString('N').Substring(0, 12)
}

# Default output path: .mad/scratch/<SkillName>-context-<RunId>.md
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $scratchDir = '.mad/scratch'
  if (-not (Test-Path $scratchDir)) {
    try {
      New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
    } catch {
      Write-Error "Failed to create $scratchDir`: $_"
      exit 3
    }
  }
  $OutputPath = Join-Path $scratchDir "$SkillName-context-$RunId.md"
}

# Verify source artifacts exist
$missingSources = @()
foreach ($src in $SourceArtifacts) {
  if (-not (Test-Path $src)) {
    $missingSources += $src
  }
}
if ($missingSources.Count -gt 0) {
  Write-Error "Source artifact(s) missing: $($missingSources -join ', ')"
  exit 2
}

# ---- Pipeline state resolution ---------------------------------------------

$pipelineStatePath = '.mad/scratch/mad-pipeline-active.json'
$sessionId = '(unresolved)'
if (Test-Path $pipelineStatePath) {
  try {
    # NOTE: per powershell-conventions.md, do NOT use Set-StrictMode here -
    # mad-pipeline-active.json may have optional fields.
    $pipelineState = Get-Content $pipelineStatePath -Raw | ConvertFrom-Json
    if ($pipelineState.session_id) {
      $sessionId = $pipelineState.session_id
    }
  } catch {
    Write-Warning "Pipeline state file present but unparseable: $_"
    $sessionId = '(parse-error)'
  }
}

# ---- Build the bundle ------------------------------------------------------

$generatedAt = (Get-Date).ToString('o')
$lines = @()

$lines += "# $SkillName subagent context bundle"
$lines += ""
$lines += "**Run ID**: ``$RunId``"
$lines += "**Generated**: $generatedAt"
$lines += "**Skill**: ``/$SkillName``"
$lines += ""
$lines += "> This bundle is the canonical context for parallel subagent fan-out."
$lines += "> Subagents MUST read this file FIRST (single Read call) and NOT cold-read"
$lines += "> source artifacts before consuming this bundle."
$lines += ""
$lines += "---"
$lines += ""

# Source artifacts table
$lines += "## Source artifacts"
$lines += ""
$lines += "| Path | Purpose |"
$lines += "|------|---------|"
foreach ($src in $SourceArtifacts) {
  # Purpose is heuristic - infer from filename; subagents can override in lane charters.
  $purpose = switch -Wildcard ($src) {
    '*spec.md'             { 'Source feature specification (functional + non-functional requirements).' }
    '*plan.md'             { 'Implementation plan (phases, dependencies, design decisions).' }
    '*tasks.md'            { 'Dependency-ordered task list with [P] parallel markers.' }
    '*test-plan.md'        { 'Test plan (per-FR coverage matrix, suite layout).' }
    '*data-model.md'       { 'Entity / aggregate definitions feeding plan + tasks.' }
    '*analysis-report.md'  { 'Cross-artifact consistency report.' }
    '*contracts/*.md'      { 'Contract definition (errors, schemas, API surface).' }
    '*review*.md'          { 'Review feedback (prior council/domain-reviewer pass).' }
    default                { 'Source artifact (consumer-of-record for this fan-out).' }
  }
  $lines += "| ``$src`` | $purpose |"
}
$lines += ""

# Prior canonical artifacts (optional)
$lines += "## Prior canonical artifacts"
$lines += ""
if ($PriorArtifacts.Count -eq 0) {
  $lines += "_(none - fresh fan-out, no prior canonical artifacts to honour.)_"
} else {
  $lines += "| Path | Status | Relationship |"
  $lines += "|------|--------|--------------|"
  foreach ($prior in $PriorArtifacts) {
    if (Test-Path $prior) {
      $status = 'present'
    } else {
      $status = '(missing)'
    }
    $relationship = switch -Wildcard ($prior) {
      '*inline-snapshot*'  { 'Frozen iter-N source-of-truth precedent.' }
      '*review*verdict*'   { 'Settled council verdict; decisions binding.' }
      '*review*.md'        { 'Prior review pass; resolved threads inform dedup.' }
      default              { 'Prior canonical artifact (precedent).' }
    }
    $lines += "| ``$prior`` | $status | $relationship |"
  }
}
$lines += ""

# Pipeline state path
$lines += "## Pipeline state"
$lines += ""
$lines += "- **Pipeline state file**: ``$pipelineStatePath``"
$lines += "- **Resolved session_id**: ``$sessionId``"
$lines += ""
$lines += "> Subagents that emit canonical artifacts MUST stamp this session_id into"
$lines += "> the ``skill-state-file-id`` frontmatter key per"
$lines += "> ``.claude/rules/canonical-artifact-frontmatter.md``."
$lines += ""

# Memory rule references (paths only)
$lines += "## Antipattern memory rules"
$lines += ""
if ($AntipatternMemoryRules.Count -eq 0) {
  $lines += "_(no rule paths supplied - default kit rules apply.)_"
} else {
  foreach ($rule in $AntipatternMemoryRules) {
    if (Test-Path $rule) {
      $lines += "- ``$rule`` (present)"
    } else {
      $lines += "- ``$rule`` _(missing - subagent must skip)_"
    }
  }
  $lines += ""
  $lines += "> Subagents MUST honour these rules. Read on demand only when a finding"
  $lines += "> requires citation; do NOT cold-read the rule files unless required."
}
$lines += ""

# Lane charters
$lines += "## Lane charters"
$lines += ""
if ($null -eq $LaneCharters -or $LaneCharters.Count -eq 0) {
  $lines += "_(no lane charters supplied - this bundle is for context only, not fan-out.)_"
} else {
  # Sort lane keys for deterministic ordering
  $laneKeys = $LaneCharters.Keys | Sort-Object
  foreach ($laneId in $laneKeys) {
    $charterText = $LaneCharters[$laneId]
    $lines += "### Lane ``$laneId``"
    $lines += ""
    $lines += $charterText
    $lines += ""
  }
}
$lines += ""

# Subagent prompt boilerplate footer
$lines += "---"
$lines += ""
$lines += "## Subagent prompt boilerplate"
$lines += ""
$lines += "> Every subagent spawned with this bundle MUST receive the following"
$lines += "> sentinel in its prompt (per ``.claude/rules/no-top-n-capping.md`` and"
$lines += "> CLAUDE.md > Subagent output completeness):"
$lines += ""
$lines += '> Enumerate exhaustively. No Top-N capping. Every item classified and'
$lines += "> acted upon. State 'no findings' explicitly when a category is empty."
$lines += ""
$lines += "> Read this bundle (``$OutputPath``) FIRST. Do not cold-read any other"
$lines += "> file before this bundle has been consumed."
$lines += ""
$lines += "> If you need to call ``Get-SubagentPromptBoilerplate.ps1``, reference"
$lines += "> ``.claude/scripts/Get-SubagentPromptBoilerplate.ps1`` with -SkillName"
$lines += "> ``$SkillName``, -BundlePath ``$OutputPath``, and your -LaneId."
$lines += ""

# ---- Write bundle ----------------------------------------------------------

try {
  $content = $lines -join "`n"
  # Use [System.IO.File]::WriteAllText to avoid PS 5.1 BOM gotcha per
  # patterns/powershell-conventions.md.
  $absPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
  } else {
    Join-Path (Get-Location).Path $OutputPath
  }
  $absPath = [System.IO.Path]::GetFullPath($absPath)
  $parentDir = [System.IO.Path]::GetDirectoryName($absPath)
  if ($parentDir -and -not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
  }
  [System.IO.File]::WriteAllText(
    $absPath,
    $content,
    (New-Object System.Text.UTF8Encoding $false)
  )
} catch {
  Write-Error "Failed to write bundle: $_"
  exit 3
}

# Emit the path on stdout for downstream callers.
Write-Output $OutputPath

exit 0
