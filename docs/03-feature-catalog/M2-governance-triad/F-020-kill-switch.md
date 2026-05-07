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
feature-id: F-020
short-slug: kill-switch
milestone: M2
provenance:
  surfaces:
    - ce:FR-KILL-001
    - kit:rules/non-negotiable-rules.md (manual halt)
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
  LOCKED if GREEN AND reviews/F-020-kill-switch-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-014]
out-of-scope-notes: |
  Manual operator verdict (override at `verdicts/manual-<ts>.json` per FR-OVERRIDE-001)
  is a related-but-distinct surface tracked separately in M11 (F-088..F-092). This
  feature is the read-time-propagating JSON kill switch only.
confidence: high
---

# F-020 — Read-time-propagating kill switch

## Behavior contract

A single file `userData/mad-council-claw/kill-switch.json` declares the engine's halt state. Schema: `{halted: boolean, reason?: string, set_at_utc?: string, set_by?: string}`. Every engine cycle reads this file at the START of the cycle (read-time propagation, not snapshot-at-boot). If `halted: true`, the engine skips the cycle's work and transitions immediately to `closing` with `halted_by: "kill_switch"` and `trigger_evidence_sha256` linking to a fresh audit entry that captures the kill-switch state at the instant of read.

## Acceptance scenarios

1. **Given** a running engine and `kill-switch.json` set to `{halted: false}`, **When** an external process writes `{halted: true, reason: "ops review"}` mid-run, **Then** the engine's NEXT cycle observes the halt and transitions to `closing` within that cycle.
2. **Given** `kill-switch.json` set to `{halted: true}` BEFORE engine boot, **When** the engine boots, **Then** it transitions through `open → closing` without ever entering `active`, and the retro records `halted_by: "kill_switch_at_boot"`.
3. **Given** the kill-switch file is missing entirely, **When** the engine reads, **Then** the engine treats this as `{halted: false}` (default open) and continues; missing file is NOT an error.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/kill-switch/mid-run-halt.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/kill-switch/halt-at-boot.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/kill-switch/missing-file-defaults.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (cycle hook for read-time check), F-008 (storage path for kill-switch.json), F-014 (retro consumes trigger evidence)
- **Soft:** F-015 (audit log records every read result), F-018 (halt mechanism shared)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-KILL-001 | Read-time-propagating kill-switch JSON |
| kit:rules/non-negotiable-rules.md | "MUST NOT skip user-requested halt" discipline |

## Implementation notes

(empty — populated when implementation begins)
