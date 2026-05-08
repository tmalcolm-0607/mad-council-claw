<#
.SYNOPSIS
Emit the canonical subagent prompt boilerplate header for parallel fan-out
spawns. Replaces conversational LLM emission of "remember: enumerate
exhaustively, no Top-N capping..." preambles in /mad-plan, /mad-tasks,
/testplan, and any skill that fans out to >=2 parallel subagents.

.DESCRIPTION
Emits a canonical prompt header that subagents MUST receive at the top of
their Task spawn prompt. Honours:

  - .claude/rules/no-top-n-capping.md (exhaustive enumeration sentinel)
  - .claude/rules/canonical-skill-only.md (skill-active state)
  - CLAUDE.md > Subagent output completeness (literal sentinel phrase)

The emitted block is copy-pasted into the orchestrator's parallel-Task spawn
brief. ~30 lines total; <100ms to emit.

.PARAMETER SkillName
Mandatory. The MAD skill that owns the fan-out (e.g. mad-plan, mad-tasks,
testplan). Stamped into the boilerplate header.

.PARAMETER LaneId
Optional. Lane identifier (e.g. architecture-review, dependency-correctness).
Stamped into the boilerplate so the subagent knows which lane charter applies.

.PARAMETER BundlePath
Optional. Path to the context bundle the subagent must read FIRST. If
provided, the boilerplate cites the exact path; if omitted, a TODO sentinel is
emitted instead.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Get-SubagentPromptBoilerplate.ps1 `
  -SkillName "mad-plan" `
  -LaneId "architecture-review" `
  -BundlePath ".mad/scratch/mad-plan-context-abc123.md"

.NOTES
Wave 1 Lane gamma deliverable. Used as a building block by skill bodies that
spawn parallel Task subagents - the skill body invokes this script, captures
stdout, and prepends it to the Task prompt body.

Exit codes:
  0  success
  1  invalid params
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$SkillName,
  [string]$LaneId = "(unspecified)",
  [string]$BundlePath = ""
)

$ErrorActionPreference = 'Stop'

# ---- Param validation ------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($SkillName)) {
  Write-Error "SkillName is required and must be non-empty."
  exit 1
}

if ([string]::IsNullOrWhiteSpace($LaneId)) {
  $LaneId = "(unspecified)"
}

# Bundle path - emit explicit TODO sentinel if missing, so a fan-out without
# a bundle is loud rather than silent.
if ([string]::IsNullOrWhiteSpace($BundlePath)) {
  $bundleLine = "_(TODO: bundle path not supplied - call Stage-SubagentBundle.ps1 first)_"
} else {
  $bundleLine = "Read ``$BundlePath`` (your context bundle - do not cold-read other files first)."
}

# ---- Emit boilerplate ------------------------------------------------------

# Use single-quoted here-string for literal text per powershell-conventions.md;
# string-replace placeholders manually so $vars are not interpolated by accident.
$template = @'
## CRITICAL discipline (from CLAUDE.md)

Enumerate exhaustively. No Top-N capping. Every item classified and acted upon. State 'no findings' explicitly when a category is empty.

## Read the bundle FIRST

__BUNDLE_LINE__

Lane: __LANE_ID__
Skill: __SKILL_NAME__

## Output completeness sentinel

When a category produces no findings, state that explicitly. Do not pad. Do not truncate. Do not introduce a "Top N" framing unless the prompt EXPLICITLY requests display-ordering only - and even then, list all items internally.

## Canonical-marker reminder

If your output includes a canonical MAD artifact (spec.md / plan.md / tasks.md / analysis-report.md / test-plan.md), the orchestrator persists it via the matching `/mad-*` skill and the skill body stamps the canonical frontmatter (`generated-by`, `generated-by-version`, `skill-state-file-id`). Do NOT inline-author these artifacts yourself; return findings in your final assistant message and the orchestrator routes them through the canonical skill (per .claude/rules/canonical-skill-only.md).
'@

$out = $template `
  -replace '__BUNDLE_LINE__', $bundleLine `
  -replace '__LANE_ID__',     $LaneId `
  -replace '__SKILL_NAME__',  $SkillName

Write-Output $out

exit 0
