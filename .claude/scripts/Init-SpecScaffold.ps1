<#
.SYNOPSIS
Initialize a canonical MAD spec.md scaffold with frontmatter + invariant section
headers. Replaces the slow LLM-driven boilerplate emission step in /mad-spec body.

.DESCRIPTION
Writes:
  - <TargetDir>/spec.md           with canonical frontmatter + section skeleton
  - <TargetDir>/checklists/       directory created
  - <TargetDir>/checklists/requirements.md  with quality-checklist scaffold

The skill body then fills in the variant content (User Stories, FRs, Edge Cases,
Success Criteria) - it does NOT have to write the boilerplate.

Per the workflow improvement plan at C:/Users/tonym/.claude/plans/i-shouldn-t-have-
to-dynamic-lighthouse.md fix #5: stub-emit invariant template sections.

.PARAMETER TargetDir
Path to the spec output directory (e.g. specs/15-collab-engine-canonical-e/).
Created if it does not exist.

.PARAMETER FeatureName
Human-readable feature name, used in the spec.md title block (e.g.
"Collab Engine v1").

.PARAMETER WorkItemId
Optional work-item ID to stamp into the title block (e.g.
"WI-20260502-1639-collab-engine"). If omitted, "(none)" is written.

.PARAMETER InputDescription
Optional user-description string to quote in the Input section.

.PARAMETER SkillStateFileId
Required. The session_id from .mad/scratch/mad-pipeline-active.json. Stamped
into the canonical-marker frontmatter so enforce-skill-canonical-marker.js
sees the artifact as canonical.

.PARAMETER SkillSemver
Optional. Version string to stamp into generated-by-version. Default: read from
.claude/skills/mad-spec/SKILL.md frontmatter "version:" field; if absent, "1.0.0".

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Init-SpecScaffold.ps1 `
  -TargetDir specs/15-collab-engine-canonical-e `
  -FeatureName "Collab Engine v1" `
  -WorkItemId "WI-20260502-1639-collab-engine" `
  -InputDescription "Collab engine v1: Lobster-grounded multi-agent ..." `
  -SkillStateFileId "249a59a7-276c-40ae-8664-4d35ffd03b7c"

.NOTES
This script is INVARIANT emission only - it never tries to enumerate FRs, user
stories, or edge cases (those are skill-body output).
#>

param(
  [Parameter(Mandatory = $true)] [string]$TargetDir,
  [Parameter(Mandatory = $true)] [string]$FeatureName,
  [Parameter(Mandatory = $true)] [string]$SkillStateFileId,
  [string]$WorkItemId = "(none)",
  [string]$InputDescription = "",
  [string]$SkillSemver = ""
)

$ErrorActionPreference = "Stop"

# Resolve script root (kit root = parent of .claude/scripts/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitRoot   = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Default SkillSemver: read from mad-spec/SKILL.md frontmatter "version:" if
# present; otherwise 1.0.0.
if ([string]::IsNullOrWhiteSpace($SkillSemver)) {
  $SkillMd = Join-Path $KitRoot ".claude/skills/mad-spec/SKILL.md"
  if (Test-Path $SkillMd) {
    $head = Get-Content -Path $SkillMd -TotalCount 20
    $verLine = $head | Where-Object { $_ -match "^version:\s*(.+)$" } | Select-Object -First 1
    if ($verLine -and $verLine -match "^version:\s*(.+)$") {
      $SkillSemver = $matches[1].Trim()
    }
  }
  if ([string]::IsNullOrWhiteSpace($SkillSemver)) { $SkillSemver = "1.0.0" }
}

# Resolve target dir relative to current working directory (caller controls $PWD)
if (-not (Test-Path $TargetDir)) {
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}
$ChecklistDir = Join-Path $TargetDir "checklists"
if (-not (Test-Path $ChecklistDir)) {
  New-Item -ItemType Directory -Path $ChecklistDir -Force | Out-Null
}

$SpecPath      = Join-Path $TargetDir "spec.md"
$ChecklistPath = Join-Path $ChecklistDir "requirements.md"
$Today         = (Get-Date).ToString("yyyy-MM-dd")

# Escape input-description for safe inclusion in frontmatter quote
$InputEscaped = $InputDescription -replace '"', '\"'
if ([string]::IsNullOrWhiteSpace($InputEscaped)) { $InputEscaped = "(no input description provided)" }

# ============================================================
# spec.md scaffold
# ============================================================
$SpecBody = @"
---
generated-by: /mad-spec
generated-by-version: $SkillSemver
skill-state-file-id: $SkillStateFileId
---

# Feature Specification: $FeatureName

**Feature Branch**: ``$([System.IO.Path]::GetFileName($TargetDir))``
**Created**: $Today
**Status**: Draft
**Work Item**: ``$WorkItemId``
**Input**: User description: "$InputEscaped"

## User Scenarios & Testing _(mandatory)_

<!-- Skill body fills user stories here. Each user story:
     ### User Story N - <Title> (Priority: PN)
     - Why this priority
     - Independent Test
     - Access / Data / Integration / Presentation
     - Acceptance Scenarios (3+ items each)
-->

## Edge Cases

<!-- Skill body fills edge case bullets here. Bullet format:
     - **<one-line scenario>**: <expected behavior>
-->

## Applicable Patterns _(auto-populated)_

<!-- Skill body fills the pattern table here. Format:
     | Pattern File | Applies To | Key Constraints |
     |---|---|---|
     | ... | ... | ... |
-->

## Requirements _(mandatory)_

### Functional Requirements

<!-- Skill body fills FRs here. Each FR:
     **FR-<DOMAIN>-NNN**: <Short Title>
     - **Semantic**: <what success means>
     - **Logical Proof**: <CI-verifiable test spec>
-->

## Key Entities _(if data involved)_

<!-- Skill body lists entities here. Each entry:
     - **<EntityName>**: <one-line description>
-->

## Success Criteria

<!-- Skill body lists measurable, technology-agnostic outcomes here. Each:
     - **SC-N**: <criterion that can be verified without implementation details>
-->

## Assumptions

<!-- Skill body records reasonable defaults here. Each:
     - <assumption + rationale>
-->

## Deployment & Integration Considerations

<!-- Skill body documents operational/infra needs here in technology-agnostic terms. -->

## Self-Review

<!-- Skill body completes the self-review per the SKILL.md output requirements:
     1. Completeness
     2. Source Coverage
     3. Quality
     4. Clarification (<= 3 [NEEDS CLARIFICATION] markers)
     5. Next Action
-->
"@

Set-Content -Path $SpecPath -Value $SpecBody -Encoding UTF8 -NoNewline

# ============================================================
# checklists/requirements.md scaffold
# ============================================================
$ChecklistBody = @"
# Spec Quality Checklist

**Spec**: ``$([System.IO.Path]::GetFileName($TargetDir))/spec.md``
**Generated**: $Today
**Iteration**: 1

Each item is judged PASS / FAIL by the skill body Step 7. On FAIL, edit only
the affected spec section per the ``remediation`` column. Do NOT re-author the
entire spec.

If a second pass would be needed (any FAIL after the first targeted edit), log
a Context Gap entry and proceed - do NOT loop blindly.

| # | Item | Status | Remediation on FAIL |
|---|---|---|---|
| 1 | Every FR has BOTH Semantic + Logical Proof bullets | | Edit the failing FR; add the missing bullet |
| 2 | Logical Proofs name a specific file/endpoint/command/test artifact (not "verify behavior") | | Edit the failing FR's Logical Proof to name a concrete artifact |
| 3 | <= 3 [NEEDS CLARIFICATION] markers total | | Make informed-default guesses for the lowest-priority markers; document in Assumptions |
| 4 | Each user story has 3+ Acceptance Scenarios | | Add scenarios to the failing user story |
| 5 | Each user story has at least 3 concrete nouns (file/endpoint/component/command) | | Add concrete nouns to the failing user story |
| 6 | Success Criteria are measurable + technology-agnostic | | Rewrite the failing criterion to be measurable and technology-agnostic |
| 7 | No implementation leak (tech stack, framework, code structure) in spec body | | Remove the leaking detail; move to /mad-plan if it must persist |
| 8 | Applicable Patterns table populated (or note "no patterns detected") | | Populate the table or add the note |
| 9 | Source Coverage report shows all source workflows covered | | Add the missing FR/user story; cite source line |
| 10 | Implementability gates (Vision/Newspaper/3-Nouns/Squeeze) pass for all FRs | | Edit the failing FRs per Step 7.1 directives |

## Iteration log

<!-- Step 7 may run only ONE iteration in the new shape. If a second iteration
     would be needed, append a Context Gap entry below instead of looping. -->
"@

Set-Content -Path $ChecklistPath -Value $ChecklistBody -Encoding UTF8 -NoNewline

# ============================================================
# Result JSON to stdout (for skill body to parse if needed)
# ============================================================
$result = @{
  spec_path           = $SpecPath
  checklist_path      = $ChecklistPath
  generated_by        = "/mad-spec"
  generated_version   = $SkillSemver
  skill_state_file_id = $SkillStateFileId
  feature_name        = $FeatureName
  work_item_id        = $WorkItemId
  created_date        = $Today
}
$result | ConvertTo-Json -Compress

exit 0
