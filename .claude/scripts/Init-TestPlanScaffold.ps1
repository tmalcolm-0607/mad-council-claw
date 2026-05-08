<#
.SYNOPSIS
Initialize a canonical MAD test-plan.md scaffold with frontmatter + invariant
section headers. Replaces the slow LLM-driven boilerplate emission step in
/testplan body.

.DESCRIPTION
Writes a single test-plan markdown file at the requested path. Maps the
-Template parameter to one of five canonical test-plan templates (A/B/C/D/E):
  - ApiBehavioral      (Template A)
  - FrontendPlaywright (Template B)
  - SpecDerived        (Template C)
  - CrossProject       (Template D)
  - Behavioral         (Template E)

The skill body then fills in scenarios, coverage matrix rows, NFR targets,
and pass/fail history - it does NOT have to write the boilerplate.

Per Wave 1 Lane alpha of the workflow improvement plan: stub-emit invariant
template sections so the canonical skill body can focus on judgment, not
boilerplate.

.PARAMETER TargetPath
Full path to the test-plan output file. Parent directory created if missing.
Example: .mad/test-plans/cms/cms-create-case.md

.PARAMETER PlanId
Stable plan identifier used in pass/fail history correlation.
Example: TP-CMS-CREATE-CASE-001

.PARAMETER Project
Owning project name. Example: cms, lrms, dcs.

.PARAMETER Template
One of: ApiBehavioral | FrontendPlaywright | SpecDerived | CrossProject | Behavioral.
Maps to Templates A/B/C/D/E respectively.

.PARAMETER WorkItemId
Optional work-item ID. If omitted, attempts to read .claude/work-items/ACTIVE
and falls back to "(none)".

.PARAMETER SkillStateFileId
Optional. The session_id from .mad/scratch/mad-pipeline-active.json. If omitted,
the script attempts to read it; if absent, falls back to "(no-session)".

.PARAMETER SkillSemver
Optional. Version string to stamp into generated-by-version. Default: read from
.claude/skills/testplan/SKILL.md frontmatter "version:" field; if absent, "1.0.0".

.PARAMETER Force
Overwrite existing file if present. Default: refuse with exit code 2.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Init-TestPlanScaffold.ps1 `
  -TargetPath .mad/test-plans/cms/cms-create-case.md `
  -PlanId TP-CMS-CREATE-CASE-001 `
  -Project cms `
  -Template ApiBehavioral

.NOTES
This script is INVARIANT emission only - it never tries to enumerate scenarios,
NFR targets, or pass/fail history rows (those are skill-body output).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$TargetPath,
  [Parameter(Mandatory = $true)] [string]$PlanId,
  [Parameter(Mandatory = $true)] [string]$Project,
  [Parameter(Mandatory = $true)]
  [ValidateSet("ApiBehavioral", "FrontendPlaywright", "SpecDerived", "CrossProject", "Behavioral")]
  [string]$Template,
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
# Template letter mapping
# ============================================================
$TemplateMap = @{
  "ApiBehavioral"      = @{ Letter = "A"; Description = "API behavioral test plan (HTTP-level scenarios, contracts, error envelopes)" }
  "FrontendPlaywright" = @{ Letter = "B"; Description = "Frontend Playwright test plan (E2E user journeys, page objects, visual checks)" }
  "SpecDerived"        = @{ Letter = "C"; Description = "Spec-derived test plan (FR x level coverage matrix from spec.md)" }
  "CrossProject"       = @{ Letter = "D"; Description = "Cross-project test plan (integration across multiple service boundaries)" }
  "Behavioral"         = @{ Letter = "E"; Description = "Generic behavioral test plan (state machines, invariant checks, contract compliance)" }
}

$TemplateLetter = $TemplateMap[$Template].Letter
$TemplateDescription = $TemplateMap[$Template].Description

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
  $SkillMd = Join-Path $KitRoot ".claude/skills/testplan/SKILL.md"
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
# Resolve target file + check overwrite policy
# ============================================================
$ParentDir = Split-Path -Parent $TargetPath
if (-not [string]::IsNullOrWhiteSpace($ParentDir) -and -not (Test-Path $ParentDir)) {
  New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
}

if ((Test-Path $TargetPath) -and (-not $Force)) {
  [Console]::Error.WriteLine("Test plan already exists at $TargetPath. Use -Force to overwrite.")
  exit 2
}

$Today = (Get-Date).ToString("yyyy-MM-dd")
$FileName = [System.IO.Path]::GetFileNameWithoutExtension($TargetPath)

# ============================================================
# Frontmatter
# ============================================================
$Frontmatter = @"
---
generated-by: /testplan
generated-by-version: $SkillSemver
skill-state-file-id: $SkillStateFileId
plan-id: $PlanId
project: $Project
template: $TemplateLetter
template-name: $Template
---
"@

# ============================================================
# Sentinel comment - deferral inheritance from source
# ============================================================
$Sentinel = "<!-- TESTPLAN GENERATED FROM SPEC - DEFERRALS INHERIT FROM SOURCE PER no-silent-deferrals.md ASYMMETRY -->"

# ============================================================
# Template body skeletons (one per A/B/C/D/E)
# ============================================================
$TemplateBody = ""

switch ($Template) {
  "ApiBehavioral" {
    $TemplateBody = @"
## Template A - API Behavioral

[REPLACE: 1-2 sentences describing the API surface under test - endpoints,
HTTP methods, auth tier.]

### Coverage Matrix (FR x Level)

| FR | Unit | Integration | E2E | NFR |
|----|------|-------------|-----|-----|
| [REPLACE: FR-001] | [REPLACE: UT-1] | [REPLACE: IT-1] | [REPLACE: E2E-1 or n/a] | [REPLACE: NFR-1 or n/a] |

### Scenarios

#### UT-1 - [REPLACE: scenario title]

**Level**: unit
**Endpoint/Handler**: [REPLACE: e.g. CaseHandler.Post]
**Given**: [REPLACE: preconditions / fixture state]
**When**: [REPLACE: action under test]
**Then**: [REPLACE: expected observable outcome]
**Acceptance**: [REPLACE: assertion shape - e.g. Result<T>.Success with id field]

#### IT-1 - [REPLACE: scenario title]

**Level**: integration
**Endpoint**: [REPLACE: HTTP method + route, e.g. POST /api/v1/cases]
**Given**: [REPLACE: API up + Cosmos emulator + valid auth]
**When**: [REPLACE: curl invocation or HttpClient call]
**Then**: [REPLACE: status code + body shape + persistence side effect]
**Acceptance**: [REPLACE: HTTP status + RFC 7807 problem shape on errors + Cosmos read]

<!-- Skill body adds remaining UT-N, IT-N, E2E-N rows here. -->

### Error Envelope Coverage (RFC 7807)

| Status | Scenario | Type URI | Title |
|--------|----------|----------|-------|
| [REPLACE: 400] | [REPLACE: missing required field] | [REPLACE: validation-error] | [REPLACE: "Validation failed"] |
| [REPLACE: 404] | [REPLACE: not found] | [REPLACE: not-found] | [REPLACE: "Resource not found"] |
| [REPLACE: 409] | [REPLACE: optimistic concurrency / duplicate] | [REPLACE: conflict] | [REPLACE: "Conflict"] |
| [REPLACE: 412] | [REPLACE: ETag mismatch] | [REPLACE: precondition-failed] | [REPLACE: "Precondition failed"] |
"@
  }

  "FrontendPlaywright" {
    $TemplateBody = @"
## Template B - Frontend Playwright (E2E)

[REPLACE: 1-2 sentences describing the user journeys under test.]

### Critical User Journeys

| Journey | Priority | Test File | Page Object |
|---------|----------|-----------|-------------|
| [REPLACE: e.g. "User logs in"] | [REPLACE: P0] | [REPLACE: e.g. e2e/auth/login.spec.ts] | [REPLACE: e.g. AuthPage] |

### Coverage Matrix

| User Story | Journey | E2E Test File | Priority | Status |
|------------|---------|---------------|----------|--------|
| [REPLACE: US-001] | [REPLACE: journey name] | [REPLACE: spec file path] | [REPLACE: P0/P1/P2] | [REPLACE: Passing/Skipped/Quarantined] |

### Scenarios

#### E2E-1 - [REPLACE: journey title]

**Priority**: [REPLACE: P0 (smoke) | P1 (critical path) | P2 (regression)]
**Page object**: [REPLACE: e.g. e2e/pages/login-page.ts]
**Given**: [REPLACE: clean browser context, seed data state]
**When**: [REPLACE: user actions - clicks, form fills, navigation]
**Then**: [REPLACE: visible UI state, URL change, persisted side effect]
**Acceptance**: [REPLACE: getByRole / getByLabel assertions, no hard timeouts]

<!-- Skill body adds remaining E2E-N rows here. -->

### Visual / Accessibility Checks

- [ ] [REPLACE: visual regression snapshot for primary view]
- [ ] [REPLACE: WCAG 2.1 AA compliance check]
- [ ] [REPLACE: axe-core or eslint-plugin-jsx-a11y pass]

### Flakiness Prevention

- [ ] All locators use semantic selectors (getByRole, getByLabel, getByText)
- [ ] No page.waitForTimeout() / hard sleeps
- [ ] Each test runs in its own browser context (test isolation)
- [ ] Tests run 5 times locally before commit
"@
  }

  "SpecDerived" {
    $TemplateBody = @"
## Template C - Spec-Derived

[REPLACE: 1-2 sentences. This template derives the test matrix directly from
spec.md FRs and edge cases - one scenario per FR x level dimension.]

### Source

**Spec**: [REPLACE: path to source spec.md]
**FR count**: [REPLACE: total FRs in spec]
**Edge case count**: [REPLACE: total edge cases in spec]

### Coverage Matrix (FR x Level)

| FR | Unit | Integration | E2E | NFR |
|----|------|-------------|-----|-----|
| [REPLACE: FR-001] | [REPLACE: UT-1] | [REPLACE: IT-1] | [REPLACE: E2E-1] | [REPLACE: NFR-1 or n/a] |

### Edge-Case Coverage

| Edge Case (from spec.md) | Test ID | Notes |
|--------------------------|---------|-------|
| [REPLACE: edge case description] | [REPLACE: UT-N / IT-N] | [REPLACE: notes] |

### Scenarios

#### UT-1 - [REPLACE: maps to FR-001]

**Spec FR**: [REPLACE: FR-001 with its Logical Proof citation]
**Level**: unit
**Given**: [REPLACE: precondition]
**When**: [REPLACE: action]
**Then**: [REPLACE: expected outcome - cite the FR's Logical Proof]
**Acceptance**: [REPLACE: assertion]

<!-- Skill body adds one scenario block per spec FR x level cell. -->

### Spec Coverage Verification

- [ ] Every spec FR maps to >=1 scenario
- [ ] Every spec edge case maps to >=1 scenario
- [ ] No "no findings" silently dropped (state explicitly when level n/a for an FR)
"@
  }

  "CrossProject" {
    $TemplateBody = @"
## Template D - Cross-Project Integration

[REPLACE: 1-2 sentences describing the cross-service flow under test.]

### Service Surfaces Involved

| Service | Role | Endpoint(s) | Auth |
|---------|------|-------------|------|
| [REPLACE: service A name] | [REPLACE: producer / consumer / mediator] | [REPLACE: HTTP routes] | [REPLACE: managed identity / S2S / JWT] |

### Cross-Project Flow Diagram

``````
[REPLACE: ASCII diagram of the call sequence across services - e.g.
Client -> Service A (POST /api/v1/cases)
       -> Service B (event: case.created)
       -> Service C (notification dispatched)
]
``````

### Coverage Matrix

| Flow | Producer Test | Consumer Test | Contract Test | E2E |
|------|---------------|---------------|---------------|-----|
| [REPLACE: flow name] | [REPLACE: test ID] | [REPLACE: test ID] | [REPLACE: test ID] | [REPLACE: test ID or n/a] |

### Scenarios

#### CP-1 - [REPLACE: cross-project scenario title]

**Level**: integration (multi-service)
**Producer**: [REPLACE: service producing the contract / event]
**Consumer**: [REPLACE: service consuming]
**Given**: [REPLACE: both services up, valid auth, seed data]
**When**: [REPLACE: caller initiates flow]
**Then**: [REPLACE: producer's response + consumer's observable side effect]
**Acceptance**: [REPLACE: contract assertion + consumer state assertion]

<!-- Skill body adds remaining CP-N rows here. -->

### Contract Compatibility

- [ ] Producer schema version is back-compatible with consumer
- [ ] Consumer handles new producer-side optional fields gracefully
- [ ] Consumer returns deterministic error for malformed/missing required fields
"@
  }

  "Behavioral" {
    $TemplateBody = @"
## Template E - Behavioral (Generic)

[REPLACE: 1-2 sentences. This template covers state machines, invariant checks,
and contract compliance for any subsystem.]

### State Machine (if applicable)

``````
[REPLACE: state diagram - e.g.
States: Created -> Active -> Concluded -> Archived
Valid transitions: 3
Invalid transitions: 9 (all other combinations explicitly tested as rejected)
]
``````

### Coverage Matrix

| Behavior | Unit | Integration | Contract | NFR |
|----------|------|-------------|----------|-----|
| [REPLACE: behavior name] | [REPLACE: UT-1] | [REPLACE: IT-1] | [REPLACE: CT-1 or n/a] | [REPLACE: NFR-1 or n/a] |

### Scenarios

#### UT-1 - Valid Transition: [REPLACE: From -> To]

**Level**: unit (state machine)
**Given**: [REPLACE: entity in From state]
**When**: [REPLACE: triggering event]
**Then**: [REPLACE: entity transitions to To state]
**Acceptance**: [REPLACE: state assertion + persisted side effect]

#### UT-2 - Invalid Transition Rejected: [REPLACE: From -> To]

**Level**: unit (state machine)
**Given**: [REPLACE: entity in From state]
**When**: [REPLACE: invalid triggering event]
**Then**: [REPLACE: rejection - exception thrown / 4xx returned]
**Acceptance**: [REPLACE: assertion shape - exception type or RFC 7807 problem]

<!-- Skill body adds remaining valid + invalid transition rows here. -->

### Invariant Checks

- [ ] [REPLACE: invariant 1 - e.g. "Aggregate never holds two active children"]
- [ ] [REPLACE: invariant 2 - e.g. "Sum of child weights = parent weight"]
- [ ] [REPLACE: invariant 3 - e.g. "ETag advances on every mutation"]
"@
  }
}

# ============================================================
# Common closing sections (apply to all templates)
# ============================================================
$Closing = @"

## Non-functional Targets

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| [REPLACE: NFR-1] | [REPLACE: e.g. p95 latency] | [REPLACE: e.g. <200ms] | [REPLACE: e.g. k6 100 reqs/s for 60s] |

## Anti-hallucination

- Empty cells per FR (or per state, per journey) stated explicitly (gap signal)
- Every scenario maps back to a spec FR / user story / state-machine row, or is
  explicitly marked as cross-cutting / infrastructure
- "Top N" capping is forbidden - enumerate exhaustively per no-top-n-capping.md

## Verification Spec

Test plans are themselves verification material. The 5 sub-sections below mirror
the canonical plan-gate format.

### Feature Intent

[REPLACE: 1-2 sentences restating the source spec's user-visible outcome that
this test plan covers.]

### Change Type

[REPLACE: One of: new-capability | bug-fix | refactor | perf | security | infra.
Inherit from the source spec.]

### Expected Impact

[REPLACE: Concrete metric / observable that should move once tests pass and
implementation lands. Identical to the source spec's Expected Impact.]

### Structural Signals

The Coverage Matrix above IS the structural-signal map. Each cell's scenario row
shows how the FR / journey / state will be observed.

### Not a Failure

- Skipped tests (SkippableFact / test.fixme) for missing infra (Cosmos emulator,
  unimplemented backend) -> not a failure; flagged for ADO-only execution
- Coverage drop on new error paths until follow-up tests land -> flag, don't revert
- Pre-existing failures in other test projects -> tracked separately, not dismissed

## Pass/Fail History

<!-- Skill body and CI append rows here on each test-plan execution. -->

| Date | Run ID | Pass | Fail | Skip | Quarantined | Notes |
|------|--------|------|------|------|-------------|-------|
| [REPLACE: YYYY-MM-DD] | [REPLACE: build/run id] | [REPLACE: count] | [REPLACE: count] | [REPLACE: count] | [REPLACE: count] | [REPLACE: notes] |

## Known Issues

<!-- Skill body lists known flakes / quarantined / deferred-with-rationale. -->

| Issue | Severity | Tracked At | Status |
|-------|----------|------------|--------|
| [REPLACE: issue title] | [REPLACE: BLOCKING/SHOULD-FIX/CONSIDER] | [REPLACE: bug spec id / WI id] | [REPLACE: open / mitigated / closed] |

## References

- Source spec: [REPLACE: path to spec.md]
- Source plan: [REPLACE: path to plan.md, if applicable]
- Test framework: [REPLACE: e.g. xUnit + FluentAssertions, Vitest, Playwright]
"@

# ============================================================
# Compose final test-plan body
# ============================================================
$Header = @"
$Frontmatter

$Sentinel

# Test Plan: $FileName

**Plan ID**: ``$PlanId``
**Project**: ``$Project``
**Template**: ``$TemplateLetter`` ($Template)
**Description**: $TemplateDescription
**Created**: $Today
**Status**: Draft
**Work Item**: ``$WorkItemId``

"@

$FullBody = $Header + $TemplateBody + $Closing

Set-Content -Path $TargetPath -Value $FullBody -Encoding UTF8 -NoNewline

# ============================================================
# Result JSON to stdout
# ============================================================
$result = [ordered]@{
  test_plan_path      = $TargetPath
  generated_by        = "/testplan"
  generated_version   = $SkillSemver
  skill_state_file_id = $SkillStateFileId
  plan_id             = $PlanId
  project             = $Project
  template_name       = $Template
  template_letter     = $TemplateLetter
  work_item_id        = $WorkItemId
  created_date        = $Today
}
$result | ConvertTo-Json -Compress

exit 0
