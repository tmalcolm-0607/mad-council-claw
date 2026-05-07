---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-052
short-slug: skills-bundled-installation
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:bundled-skills/
    - cp:scripts/install-skills.mjs
    - cp:scripts/initialize-bundled-skills.mjs
    - cp:first-party-skills/
    - kit:rules/canonical-skill-only.md
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-052-skills-bundled-installation-review.md exists with verdict: ACCEPT.
depends-on: [F-051, F-008, F-104]
out-of-scope-notes: |
  SKILL.md format itself is F-051.
  Per-session toggle of installed bundled skills is F-053.
  Custom-loading from arbitrary user paths is F-054.
  Allowlist enforcement at install time is F-055.
  Version pinning by sha256 of bundled skill files is F-056.
  Marketplace browse/install UI is M18 (F-119..F-121).
confidence: high
---

# F-052 — Skills bundled installation

## Behavior contract

The engine ships a fixed set of bundled skills in `<install-root>/bundled-skills/<name>/SKILL.md` (per the clawpilot pattern of 8 bundled skills: ai-investigator, docx, excalidraw, expense-report, loop, pptx, web-artifacts-builder, xlsx — concrete bundle list TBD per consumer build). On first launch, an idempotent initializer script copies missing bundled skills into `<state-dir>/skills/bundled/<name>/`, preserving the SKILL.md + any reference files; existing bundle entries with matching sha256 are left untouched. First-party-overrides under `<install-root>/first-party-skills/<name>/SKILL.md` take precedence over the matching bundled entry at registration time. The initializer logs every install/skip with `{name, action: "installed" | "skipped" | "overridden", sha256}`.

## Acceptance scenarios

1. **Given** a fresh install + empty `<state-dir>/skills/bundled/`, **When** the engine starts, **Then** all bundled skills are copied into `<state-dir>/skills/bundled/<name>/` and registered; the install log records `action: "installed"` for each.
2. **Given** an existing install where `<state-dir>/skills/bundled/loop/SKILL.md` matches the install-root sha256, **When** the engine starts, **Then** the file is left in place and the install log records `action: "skipped"` for that skill.
3. **Given** a first-party override at `<install-root>/first-party-skills/ai-investigator/SKILL.md`, **When** the engine registers skills, **Then** the active `ai-investigator` registration points to the first-party override path and the bundled copy is recorded as `action: "overridden"`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/skills/bundled-fresh-install.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/skills/bundled-idempotent-skip.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/skills/first-party-override.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-051 (SKILL.md format the installer copies), F-008 (storage layout defines `<state-dir>/skills/bundled/` path), F-104 (electron-builder packages bundled-skills/ alongside the binary)
- **Soft:** F-053 (toggle reads bundled list to populate UI), F-056 (sha256 used for the idempotent skip)
- **Independent:** F-058..F-066 (perms + automations)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "bundled" is item 2 of the M7 catalog list |
| cp:bundled-skills/ | Reference set of 8 bundled skills (concrete bundle list to be re-decided for the engine) |
| cp:scripts/install-skills.mjs | Reference installer pattern (`pnpm install:skills`) |
| cp:scripts/initialize-bundled-skills.mjs | First-launch initialization pattern |
| cp:first-party-skills/ | Override-precedence pattern (5 of 8 bundled have first-party overrides in clawpilot) |
| kit:rules/canonical-skill-only.md | Skill bodies are the canonical authors of the artifacts they produce |

## Implementation notes

(empty — populated when implementation begins)
