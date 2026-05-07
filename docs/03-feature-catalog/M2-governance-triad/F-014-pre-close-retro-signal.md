---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-014
short-slug: pre-close-retro-signal
milestone: M2
provenance:
  surfaces:
    - ce:FR-CORE-004
    - ce:FR-CORE-005
    - kit:council-retro-skill
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
  LOCKED if GREEN AND reviews/F-014-pre-close-retro-signal-review.md exists with verdict: ACCEPT.
depends-on: [F-001]
out-of-scope-notes: |
  ALAS-compatible learning-hub posting is tracked under M11 (F-088..F-092 soul/introspect/replay).
  This feature emits the local retro signal at run wind-down; downstream consumption
  is owned by later milestones.
confidence: high
---

# F-014 — Pre-close retro signal

## Behavior contract

Every run lifecycle MUST pass through `closing` before reaching `closed` (per F-001). During `closing` the engine emits a mandatory retro signal: a structured artifact at `runs/<run_id>/retro.json` capturing 5-axis 1-5 scores (accuracy / completeness / tsg_alignment / dx / confidence) plus what-worked + what-was-hard prose. For halted runs (`halted_by_*` outcomes), the retro additionally carries `trigger_evidence_sha256` linking to the audit entry that triggered the halt. Skipping the retro emit fails the close transition with `RETRO_MISSING`.

## Acceptance scenarios

1. **Given** a run that completes naturally (cycle cap reached or explicit terminate), **When** `closing` fires, **Then** `runs/<run_id>/retro.json` exists with all 5 axes scored and `outcome: "completed"`.
2. **Given** a run halted by kill-switch (per F-020), **When** `closing` fires, **Then** the retro carries `outcome: "halted_by_kill_switch"` and `trigger_evidence_sha256` matching the kill-switch audit entry.
3. **Given** a buggy implementation that omits the retro emit, **When** the engine attempts to transition to `closed`, **Then** the transition rejects with `RETRO_MISSING` and the run stays in `closing` until retro lands.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/governance/retro-natural-close.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/governance/retro-halted-trigger.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/governance/retro-missing-rejection.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (lifecycle), F-008 (storage layout for retro.json)
- **Soft:** F-015 (retro entry is also written to audit log), F-018 (halt outcomes feed trigger_evidence_sha256)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-CORE-004 | Mandatory pre-close retro signal (ALAS Step 9 anchor) |
| ce:FR-CORE-005 | Carve-out retro for halted_by_* with trigger_evidence_sha256 |
| kit:council-retro-skill | 5-axis scoring rubric + blameless framing |

## Implementation notes

(empty — populated when implementation begins)
