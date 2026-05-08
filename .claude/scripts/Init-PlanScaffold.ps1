<#
.SYNOPSIS
Initialize a canonical MAD plan.md scaffold with frontmatter + invariant section
headers. Replaces the slow LLM-driven boilerplate emission step in /mad-plan body.

.DESCRIPTION
Writes:
  - <TargetDir>/plan.md  with canonical frontmatter + section skeleton

The skill body then fills in the variant content (architectural decisions,
phase plans, FR-to-evidence mapping, gates) - it does NOT have to write
the boilerplate.

Per Wave 1 Lane alpha of the workflow improvement plan: stub-emit invariant
template sections so the canonical skill body can focus on judgment, not
boilerplate.

.PARAMETER TargetDir
Path to the feature directory (e.g. specs/15-collab-engine/). Created if it
does not exist.

.PARAMETER FeatureName
Human-readable feature name, used in the plan.md title block.

.PARAMETER WorkItemId
Optional work-item ID. If omitted, attempts to read .claude/work-items/ACTIVE
and falls back to "(none)".

.PARAMETER PriorPlanPath
Optional path to a prior plan.md (canonical-rerun mode). When set, the scaffold
adds canonical-rerun frontmatter keys.

.PARAMETER SkillStateFileId
Optional. The session_id from .mad/scratch/mad-pipeline-active.json. If omitted,
the script attempts to read it; if absent, falls back to "(no-session)".

.PARAMETER SkillSemver
Optional. Version string to stamp into generated-by-version. Default: read from
.claude/skills/mad-plan/SKILL.md frontmatter "version:" field; if absent, "1.0.0".

.PARAMETER Force
Overwrite existing plan.md if present. Default: refuse with exit code 2.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Init-PlanScaffold.ps1 `
  -TargetDir specs/15-collab-engine `
  -FeatureName "Collab Engine v1"

.NOTES
This script is INVARIANT emission only - it never tries to enumerate phases,
gates, or rollback strategies (those are skill-body output).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$TargetDir,
  [Parameter(Mandatory = $true)] [string]$FeatureName,
  [string]$WorkItemId = "",
  [string]$PriorPlanPath = "",
  [string]$SkillStateFileId = "",
  [string]$SkillSemver = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

# Resolve script root (kit root = parent of .claude/scripts/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitRoot   = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# ============================================================
# WorkItemId fallback: read .claude/work-items/ACTIVE if not provided
# ============================================================
if ([string]::IsNullOrWhiteSpace($WorkItemId)) {
  $ActivePath = Join-Path $KitRoot ".claude/work-items/ACTIVE"
  if (Test-Path $ActivePath) {
    $activeContent = (Get-Content -Path $ActivePath -Raw -ErrorAction SilentlyContinue)
    if ($activeContent) {
      $WorkItemId = $activeContent.Trim()
    }
  }
  if ([string]::IsNullOrWhiteSpace($WorkItemId)) {
    $WorkItemId = "(none)"
  }
}

# ============================================================
# SkillStateFileId fallback: read .mad/scratch/mad-pipeline-active.json
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
      # Ignore parse errors; fall through to fallback
    }
  }
  if ([string]::IsNullOrWhiteSpace($SkillStateFileId)) {
    $SkillStateFileId = "(no-session)"
  }
}

# ============================================================
# SkillSemver default: read from skill frontmatter or fallback to 1.0.0
# ============================================================
if ([string]::IsNullOrWhiteSpace($SkillSemver)) {
  $SkillMd = Join-Path $KitRoot ".claude/skills/mad-plan/SKILL.md"
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

$PlanPath = Join-Path $TargetDir "plan.md"

if ((Test-Path $PlanPath) -and (-not $Force)) {
  [Console]::Error.WriteLine("plan.md already exists at $PlanPath. Use -Force to overwrite.")
  exit 2
}

$Today = (Get-Date).ToString("yyyy-MM-dd")

# ============================================================
# Frontmatter (canonical-rerun aware)
# ============================================================
$Frontmatter = "---`r`n"
$Frontmatter += "generated-by: /mad-plan`r`n"
$Frontmatter += "generated-by-version: $SkillSemver`r`n"
$Frontmatter += "skill-state-file-id: $SkillStateFileId`r`n"
if (-not [string]::IsNullOrWhiteSpace($PriorPlanPath)) {
  $Frontmatter += "canonical-rerun: true`r`n"
  $Frontmatter += "source-snapshot: $PriorPlanPath`r`n"
}
$Frontmatter += "---`r`n"

# ============================================================
# plan.md scaffold
# ============================================================
$PlanBody = @"
$Frontmatter
# Plan: $FeatureName

**Feature Branch**: ``$([System.IO.Path]::GetFileName($TargetDir))``
**Created**: $Today
**Status**: Draft
**Work Item**: ``$WorkItemId``
**Spec**: ``$([System.IO.Path]::GetFileName($TargetDir))/spec.md``
**Test plan**: ``$([System.IO.Path]::GetFileName($TargetDir))/test-plan.md``

## Summary

[REPLACE: 2-3 sentences on the implementation approach. Cite the highest-impact
architectural decisions only - alternatives belong in research.md, not plan.md.]

## Technical Context

<!-- Skill body fills in concrete technical details. Replace placeholders. -->

**Language/Version**: [REPLACE: e.g. C# / .NET 8, TypeScript 5.x, Python 3.11]
**Primary Dependencies**: [REPLACE: top 3-5 frameworks/libraries]
**Storage**: [REPLACE: e.g. Cosmos DB SQL API, PostgreSQL, blob storage, N/A]
**Testing**: [REPLACE: e.g. xUnit + FluentAssertions, Vitest, pytest]
**Target Platform**: [REPLACE: e.g. Linux containers, Windows server, browser]
**Project Type**: [REPLACE: single | web | mobile - determines source structure]
**Performance Goals**: [REPLACE: domain-specific or NEEDS CLARIFICATION]
**Constraints**: [REPLACE: e.g. <200ms p95, <100MB memory, offline-capable]
**Scale/Scope**: [REPLACE: e.g. 10k users, 1M LOC, 50 screens]

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

<!-- Skill body fills the constitution-gate table here. -->

## Pattern Compliance

<!-- Skill body populates this table from the spec's Applicable Patterns section.
     Each row: pattern file + check + status (PASS / WARN / REJECT) -->

### Validated Patterns

| Pattern | Check | Status |
|---------|-------|--------|
| [REPLACE: pattern file path] | [REPLACE: pattern-specific validation] | [REPLACE: PASS / WARN / REJECT] |

### Pattern-Specific Requirements

<!-- Skill body extracts key requirements from each applicable pattern file. -->

- **[REPLACE: Pattern Name]**: [REPLACE: Key constraint from pattern file]

_If no patterns applicable: "No technology-specific patterns detected for this feature."_

## Architectural Decisions

<!-- Skill body fills the decision table here. Format:
     | Decision | Why | ADR |
     |----------|-----|-----|
     | Use Foo for X | Cited tradeoff | docs/adr/0042-foo.md |
-->

| Decision | Why | ADR |
|----------|-----|-----|
| [REPLACE: decision title] | [REPLACE: tradeoff cited] | [REPLACE: ADR path or N/A] |

## Verification Spec

**MANDATORY per Phase 0.5.** All 5 sub-sections below are required before any
phase runs. Missing sub-sections block /mad-implement.

### Feature Intent

[REPLACE: 1-2 sentences stating what the feature is supposed to accomplish from
the user/system perspective. Avoid implementation language; describe the
observable outcome.]

### Change Type

[REPLACE: One of: new-capability | bug-fix | refactor | perf | security | infra.
Drives which structural signals matter.]

### Expected Impact

[REPLACE: Concrete metric / observable that should move when this ships.
Examples: "p95 latency drops from 240ms to <150ms", "validation rejection count
rises by ~5/day", "no behavior change - refactor only".]

### Structural Signals

How each FR will be verified - concrete, observable evidence:

| FR | How verified | Evidence captured |
|----|--------------|-------------------|
| [REPLACE: FR-1] | [REPLACE: e.g. ``curl POST /api/v1/foo`` returns 201 + Location header] | [REPLACE: response body excerpt + status code] |

If an FR has no verification path, that's an Implementability gap - escalate to
/mad-spec for revision before continuing.

### Not a Failure

Outcomes that look like failures but are intentional / acceptable:

- [REPLACE: e.g. "Coverage drops on new error paths until follow-up tests land" -> flag, don't revert]
- [REPLACE: e.g. "Existing benchmark regresses by <2%" -> within noise budget; not a regression]
- [REPLACE: e.g. "Some callers see HTTP 400 where they used to see 200" -> that IS the feature (input validation)]

Document these explicitly so feature-verifier doesn't trigger a premature revert.

## Project Structure

### Documentation (this feature)

``````text
$([System.IO.Path]::GetFileName($TargetDir))/
+-- plan.md              # This file (/mad-plan command output)
+-- spec.md              # /mad-spec command output
+-- test-plan.md         # /testplan command output
+-- research.md          # Phase 0 output (/mad-plan command, optional)
+-- data-model.md        # Phase 1 output (/mad-plan command, optional)
+-- quickstart.md        # Phase 1 output (/mad-plan command, optional)
+-- contracts/           # Phase 1 output (/mad-plan command, optional)
+-- tasks.md             # /mad-tasks command output
+-- analysis-report.md   # /mad-analyze command output
``````

### Source Code (repository root)

<!-- Skill body fills the actual source-tree layout here. -->

``````text
[REPLACE: actual project layout - e.g.
src/
+-- API/
+-- BusinessLogic/
+-- DataAccess/
+-- Common/
tests/
+-- API.Tests/
+-- BusinessLogic.Tests/
]
``````

**Structure Decision**: [REPLACE: 1-2 sentences on selected structure with
references to actual directories captured above.]

## Phases

<!-- Skill body fills phase plans here. Each phase:
     ### Phase N: <name>
     **Goal**: <single sentence>
     **Inputs**: <files/data this phase reads>
     **Outputs**: <files/data this phase writes>
     **Gate**: <test selector or behavioral probe that must pass>
     - [ ] T1: <atomic task>
-->

### Phase 0: Research (optional)

**Goal**: [REPLACE: research questions resolved before design]
**Outputs**: [REPLACE: research.md with findings]
**Gate**: [REPLACE: all NEEDS CLARIFICATION markers resolved]

### Phase 1: Design

**Goal**: [REPLACE: data model + contracts + quickstart]
**Outputs**: [REPLACE: data-model.md, contracts/*, quickstart.md]
**Gate**: [REPLACE: contracts compile / lint clean]

<!-- Skill body adds Phase 2, Phase 3, etc. as needed. -->

## Quality Gates

After EACH phase, run gates with ACTUAL OUTPUT as proof. See project CLAUDE.md
"Commands" section for exact gate commands.

- [ ] Build clean (exit 0, no errors)
- [ ] Unit tests pass (0 failures)
- [ ] Integration tests pass (where applicable)
- [ ] Coverage >= threshold (typically 80%, 100% diff coverage required)
- [ ] Lint/format clean
- [ ] Bicep lint on changed .bicep files
- [ ] Pre-flight checks pass (.claude/scripts/Check-Preflight.ps1)
- [ ] Verify against ADO coverage report, not just local Measure-DiffCoverage

## Open Questions

<!-- Skill body lists open questions blocking phase advancement. Each:
     - [ ] Q1: <question> (resolve before phase N)
-->

- [ ] [REPLACE: Q1 - question requiring resolution] (resolve before phase [REPLACE: N])

## Rollback Plan

[REPLACE: How to revert if a phase ships and breaks prod. Cite specific
commits / migrations / feature flags / deployment rings. The rollback should
be executable without consulting external docs.]

**Rollback steps**:
1. [REPLACE: step 1 - e.g. revert PR <id>]
2. [REPLACE: step 2 - e.g. roll back migration via <command>]
3. [REPLACE: step 3 - e.g. flip feature flag <name> to off]

**Rollback verification**: [REPLACE: how to confirm the rollback succeeded -
e.g. health endpoint returns 200, error rate drops below 0.1%]
"@

Set-Content -Path $PlanPath -Value $PlanBody -Encoding UTF8 -NoNewline

# ============================================================
# Result JSON to stdout (for skill body to parse if needed)
# ============================================================
$result = [ordered]@{
  plan_path           = $PlanPath
  generated_by        = "/mad-plan"
  generated_version   = $SkillSemver
  skill_state_file_id = $SkillStateFileId
  feature_name        = $FeatureName
  work_item_id        = $WorkItemId
  prior_plan_path     = $PriorPlanPath
  canonical_rerun     = (-not [string]::IsNullOrWhiteSpace($PriorPlanPath))
  created_date        = $Today
}
$result | ConvertTo-Json -Compress

exit 0
