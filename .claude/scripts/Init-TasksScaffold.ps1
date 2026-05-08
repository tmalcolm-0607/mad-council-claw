<#
.SYNOPSIS
Initialize a canonical MAD tasks.md scaffold with frontmatter + invariant section
headers. Replaces the slow LLM-driven boilerplate emission step in /mad-tasks body.

.DESCRIPTION
Writes:
  - <TargetDir>/tasks.md  with canonical frontmatter + tier-selected template body

The skill body then fills in the variant content (per-task rows, wave plan,
coverage matrices) - it does NOT have to write the boilerplate.

The Tier parameter selects the source template body:
  - Minimal:  .mad/templates/task-format-minimal.md  (60% token reduction)
  - Standard: .mad/templates/task-format-standard.md (default; balanced)
  - Full:     .mad/templates/task-format-full.md     (complex interactive flows)

Per Wave 1 Lane alpha of the workflow improvement plan: stub-emit invariant
template sections so the canonical skill body can focus on judgment, not
boilerplate.

.PARAMETER TargetDir
Path to the feature directory (e.g. specs/15-collab-engine/). Created if it
does not exist.

.PARAMETER FeatureName
Human-readable feature name, used in the tasks.md title block.

.PARAMETER Tier
One of: Minimal | Standard | Full. Default: Standard. Selects which template
body is loaded from .mad/templates/task-format-{tier}.md.

.PARAMETER WorkItemId
Optional work-item ID. If omitted, attempts to read .claude/work-items/ACTIVE
and falls back to "(none)".

.PARAMETER SkillStateFileId
Optional. The session_id from .mad/scratch/mad-pipeline-active.json. If omitted,
the script attempts to read it; if absent, falls back to "(no-session)".

.PARAMETER SkillSemver
Optional. Version string to stamp into generated-by-version. Default: read from
.claude/skills/mad-tasks/SKILL.md frontmatter "version:" field; if absent, "1.0.0".

.PARAMETER Force
Overwrite existing tasks.md if present. Default: refuse with exit code 2.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Init-TasksScaffold.ps1 `
  -TargetDir specs/15-collab-engine `
  -FeatureName "Collab Engine v1" `
  -Tier Standard

.NOTES
This script is INVARIANT emission only - it never tries to enumerate tasks,
waves, or coverage rows (those are skill-body output).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$TargetDir,
  [Parameter(Mandatory = $true)] [string]$FeatureName,
  [ValidateSet("Minimal", "Standard", "Full")] [string]$Tier = "Standard",
  [string]$WorkItemId = "",
  [string]$SkillStateFileId = "",
  [string]$SkillSemver = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

# Resolve script root (kit root = parent of .claude/scripts/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitRoot   = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# ============================================================
# WorkItemId fallback
# ============================================================
if ([string]::IsNullOrWhiteSpace($WorkItemId)) {
  $ActivePath = Join-Path $KitRoot ".claude/work-items/ACTIVE"
  if (Test-Path $ActivePath) {
    $activeContent = (Get-Content -Path $ActivePath -Raw -ErrorAction SilentlyContinue)
    if ($activeContent) { $WorkItemId = $activeContent.Trim() }
  }
  if ([string]::IsNullOrWhiteSpace($WorkItemId)) { $WorkItemId = "(none)" }
}

# ============================================================
# SkillStateFileId fallback
# ============================================================
if ([string]::IsNullOrWhiteSpace($SkillStateFileId)) {
  $ActiveStateFile = Join-Path $KitRoot ".mad/scratch/mad-pipeline-active.json"
  if (Test-Path $ActiveStateFile) {
    try {
      $stateRaw = Get-Content -Path $ActiveStateFile -Raw -ErrorAction SilentlyContinue
      if ($stateRaw) {
        $stateData = $stateRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($stateData -and $stateData.session_id) {
          $SkillStateFileId = $stateData.session_id
        }
      }
    } catch {
      # Ignore parse errors
    }
  }
  if ([string]::IsNullOrWhiteSpace($SkillStateFileId)) { $SkillStateFileId = "(no-session)" }
}

# ============================================================
# SkillSemver default
# ============================================================
if ([string]::IsNullOrWhiteSpace($SkillSemver)) {
  $SkillMd = Join-Path $KitRoot ".claude/skills/mad-tasks/SKILL.md"
  if (Test-Path $SkillMd) {
    $head = Get-Content -Path $SkillMd -TotalCount 30
    $verLine = $head | Where-Object { $_ -match '^version:\s*(.+)$' } | Select-Object -First 1
    if ($verLine -and $verLine -match '^version:\s*(.+)$') {
      $SkillSemver = $matches[1].Trim()
    }
  }
  if ([string]::IsNullOrWhiteSpace($SkillSemver)) { $SkillSemver = "1.0.0" }
}

# ============================================================
# Resolve target dir + check overwrite policy
# ============================================================
if (-not (Test-Path $TargetDir)) {
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$TasksPath = Join-Path $TargetDir "tasks.md"

if ((Test-Path $TasksPath) -and (-not $Force)) {
  [Console]::Error.WriteLine("tasks.md already exists at $TasksPath. Use -Force to overwrite.")
  exit 2
}

$Today = (Get-Date).ToString("yyyy-MM-dd")

# ============================================================
# Tier-selected template body
# ============================================================
$TierLower = $Tier.ToLower()
$TemplatePath = Join-Path $KitRoot ".mad/templates/task-format-$TierLower.md"

if (-not (Test-Path $TemplatePath)) {
  [Console]::Error.WriteLine("Template file not found: $TemplatePath (Tier=$Tier)")
  exit 3
}

# Read the template body. Strip its YAML frontmatter (description: ...)
# because we replace it with our canonical frontmatter.
$rawTemplate = Get-Content -Path $TemplatePath -Raw -ErrorAction Stop

# Strip leading YAML frontmatter block (---\n...\n---\n)
$strippedTemplate = $rawTemplate -replace '(?s)\A---\r?\n.*?\r?\n---\r?\n', ''

# Replace the template's [FEATURE NAME] placeholder with the actual feature name
$strippedTemplate = $strippedTemplate -replace '\[FEATURE NAME\]', $FeatureName

# ============================================================
# Frontmatter + canonical intro additions
# ============================================================
$Frontmatter = @"
---
generated-by: /mad-tasks
generated-by-version: $SkillSemver
skill-state-file-id: $SkillStateFileId
tier: $Tier
---
"@

# ============================================================
# Field-semantics block - clarifies Dependencies vs Connections
# ============================================================
$FieldSemanticsBlock = @"
## Field Semantics

| Field | Meaning | Example |
|-------|---------|---------|
| **Dependencies** | Build-time prerequisites. Task X cannot start until task Y completes. | T015 depends on T012 (model must exist before service uses it) |
| **Connections** | Informational runtime callers/consumers. Task X is invoked by task Y at runtime; does NOT block execution order. | T020 (handler) is connected to T030 (controller) at runtime |
| **[P]** | Parallel-eligible. No file conflict, no dependency on another [P] task in the same wave. | T012 [P] and T013 [P] write different files |
| **[USX]** | User story marker - traces task to spec.md user story. | [US1], [US2] |

## Layer-Dependency-Direction

Dependencies flow DOWN only (no upward references):

``````
API (Controllers, Middleware, DTOs)
  v references
BusinessLogic (Services, Interfaces, Validators, Handlers)
  v references
DataAccess (Repositories, EF Contexts, Cosmos clients)
  v references
Common (Extensions, Constants, Helpers) - LEAF
``````

Tasks MUST respect this layering. A DataAccess task may NOT depend on a
BusinessLogic task. A Common task may NOT depend on anything.

## Wave Plan

<!-- Skill body fills the wave plan here. Each row:
     | Wave | Tasks | Parallel? | Files Touched | Dependencies |
     |------|-------|-----------|---------------|--------------|
     | W1   | T001, T002 | Yes | a.cs, b.cs | (none)
     | W2   | T010 | No | c.cs | T001, T002
-->

| Wave | Tasks | Parallel? | Files Touched | Dependencies |
|------|-------|-----------|---------------|--------------|
| [REPLACE: W1] | [REPLACE: T001, T002] | [REPLACE: Yes/No] | [REPLACE: file paths] | [REPLACE: (none) or task IDs] |

## FR-to-Task Coverage Matrix

<!-- Skill body fills this matrix from spec.md FRs. Every FR MUST map to >=1 task.
     Format:
     | FR | Tasks | Coverage Status |
     |----|-------|-----------------|
     | FR-001 | T012, T015 | covered |
     | FR-002 | (none) | GAP - escalate |
-->

| FR | Tasks | Coverage Status |
|----|-------|-----------------|
| [REPLACE: FR-001] | [REPLACE: task IDs] | [REPLACE: covered / partial / GAP] |

## Edge-Case-to-Task Coverage Matrix

<!-- Skill body fills this matrix from spec.md edge cases. Each row:
     | Edge Case | Task(s) | Notes |
     |-----------|---------|-------|
     | "Empty input" | T020 | validation handler |
     | "Concurrent writes" | T025 | optimistic concurrency via ETag |
-->

| Edge Case | Task(s) | Notes |
|-----------|---------|-------|
| [REPLACE: edge case from spec.md] | [REPLACE: task IDs] | [REPLACE: notes] |

"@

# ============================================================
# Self-Review template
# ============================================================
$SelfReviewBlock = @"

## Self-Review

Before reporting tasks.md complete, verify each item below:

- [ ] Frontmatter present (generated-by, generated-by-version, skill-state-file-id)
- [ ] All FRs from spec.md appear in FR-to-Task Coverage Matrix
- [ ] No FR has Coverage Status: GAP (escalate to /mad-spec if so)
- [ ] All edge cases from spec.md appear in Edge-Case-to-Task Coverage Matrix
- [ ] Wave Plan respects Layer-Dependency-Direction (no upward refs)
- [ ] [P] markers verified - parallel tasks DO NOT touch the same file
- [ ] Each task has a concrete, deterministic Success Criteria
- [ ] File paths are exact (no "update some files")
- [ ] Tier matches feature complexity (Minimal / Standard / Full)
- [ ] Quality gates included with proof-paste-required output

If any item fails, edit only the affected section. Do NOT re-author tasks.md.
"@

# ============================================================
# Compose final tasks.md body
# ============================================================
$Header = @"
$Frontmatter

# Tasks: $FeatureName

**Created**: $Today
**Status**: Draft
**Work Item**: ``$WorkItemId``
**Spec**: ``$([System.IO.Path]::GetFileName($TargetDir))/spec.md``
**Plan**: ``$([System.IO.Path]::GetFileName($TargetDir))/plan.md``
**Tier**: ``$Tier``

"@

$TasksBody = $Header + $FieldSemanticsBlock + "`r`n" + $strippedTemplate + $SelfReviewBlock

Set-Content -Path $TasksPath -Value $TasksBody -Encoding UTF8 -NoNewline

# ============================================================
# Result JSON to stdout
# ============================================================
$result = [ordered]@{
  tasks_path          = $TasksPath
  generated_by        = "/mad-tasks"
  generated_version   = $SkillSemver
  skill_state_file_id = $SkillStateFileId
  feature_name        = $FeatureName
  work_item_id        = $WorkItemId
  tier                = $Tier
  template_source     = $TemplatePath
  created_date        = $Today
}
$result | ConvertTo-Json -Compress

exit 0
