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
feature-id: F-053
short-slug: skills-toggle-per-session
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:src/features/skills/
    - cp:electron/skills.ts
    - kit:rules/skill-standards.md
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
  LOCKED if GREEN AND reviews/F-053-skills-toggle-per-session-review.md exists with verdict: ACCEPT.
depends-on: [F-051, F-052, F-001]
out-of-scope-notes: |
  Format/loader is F-051; bundled installation is F-052; custom-load is F-054.
  Per-session enabled/disabled state persistence across launches is partially F-067 (settings shape) but this feature owns the per-session-id scoped toggle write.
  Allowlist (org policy) overrides per-session toggle — F-055.
  Disabling a skill mid-run does NOT terminate in-flight invocations; only blocks future invocations in the same run.
confidence: high
---

# F-053 — Skills toggle per session

## Behavior contract

Every registered skill can be enabled or disabled in a per-session scope. The engine exposes IPC `skills.setEnabled({ session_id, name, enabled })` and `skills.listForSession({ session_id })` returning `[{ name, enabled, source }]`. The toggle state lives at `<state-dir>/sessions/<session_id>/skill-toggles.json` (atomic write per `concurrency-safety.md` §2). On registration, a skill defaults to `enabled: true` unless the allowlist (F-055) or a stored toggle says otherwise. Disabled skills are excluded from the skill-selection set passed to the model invocation; an attempt to invoke a disabled-by-toggle skill fails with `SKILL_DISABLED_FOR_SESSION` and is logged.

## Acceptance scenarios

1. **Given** a session with skill `processing-pdfs` enabled, **When** the user calls `skills.setEnabled({ session_id, name: "processing-pdfs", enabled: false })`, **Then** the next call to `skills.listForSession` returns `enabled: false` for that name AND `<state-dir>/sessions/<session_id>/skill-toggles.json` records the change atomically.
2. **Given** a session with skill `loop` toggled to `enabled: false`, **When** the model selection layer queries the skill-set for that session, **Then** `loop` is excluded from the returned set.
3. **Given** a model invocation has already started using `processing-pdfs`, **When** the user toggles it to `enabled: false` mid-run, **Then** the in-flight invocation completes normally AND the next invocation in the same run is rejected with `SKILL_DISABLED_FOR_SESSION`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/skills/toggle-set-enabled.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/skills/toggle-excludes-from-selection.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/skills/toggle-mid-run-semantics.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-051 (SKILL.md registry — toggle keys by `name`), F-052 (bundled skills are common subjects of toggle), F-001 (engine kernel exposes IPC)
- **Soft:** F-067 (settings persistence — shape of toggle state file), F-055 (allowlist overrides toggle when org policy denies)
- **Independent:** F-061..F-066 (automations), F-058..F-060 (perms — toggle is orthogonal to permission tier)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "toggle" is item 3 of the M7 catalog list |
| cp:src/features/skills/ | UI panel pattern for per-session enable/disable toggles |
| cp:electron/skills.ts | Skill registry the toggle reads/writes against |
| kit:rules/skill-standards.md | The skill is the unit toggle operates on |

## Implementation notes

(empty — populated when implementation begins)
