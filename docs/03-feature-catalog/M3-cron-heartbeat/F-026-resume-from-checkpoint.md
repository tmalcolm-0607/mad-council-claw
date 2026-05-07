---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-026
short-slug: resume-from-checkpoint
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - ce:FR-CORE-002
    - kit:rules/resume-protocol.md
    - kit:resume-handoff-skill
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
  LOCKED if GREEN AND reviews/F-026-resume-from-checkpoint-review.md exists with verdict: ACCEPT.
depends-on: [F-023, F-001, F-008, F-015]
out-of-scope-notes: |
  Cryptographic checkpoint signing (verifying a checkpoint wasn't tampered between
  write and resume) is v1.5. v1 trusts filesystem integrity inherited from OS.
  Cross-machine resume (carry checkpoint to a different host) is out of scope for v1.
confidence: high
---

# F-026 — Resume from checkpoint

## Behavior contract

A cron-spawned run that is interrupted (process kill, host reboot, OS update) MUST be resumable from its last persisted cycle checkpoint. At cycle boundaries, the engine writes `runs/<run_id>/checkpoint.json` atomically (per `concurrency-safety.md` §2) with `last_completed_cycle`, `cycle_state_sha256` (linking to the audit-log entry per F-015), and `resumable: true`. On scheduler startup, any run in `runs/` with `lifecycle: active` AND `resumable: true` AND no live process owning it is a resume candidate. The scheduler MUST resume from `last_completed_cycle + 1` — NOT replay prior cycles, NOT skip forward — and append a `resumed_from_checkpoint` audit entry citing the checkpoint sha256.

## Acceptance scenarios

1. **Given** a run with `max_cycles=10` that was killed at cycle 4 with checkpoint written, **When** the scheduler restarts and resumes, **Then** cycle 5 fires next + the audit log shows entry `resumed_from_checkpoint` referencing `cycle_state_sha256` matching cycle 4's audit entry.
2. **Given** a run killed before its first cycle's checkpoint was written (i.e., no `checkpoint.json`), **When** the scheduler starts up, **Then** the run is marked `halted_by: lost_checkpoint` and transitions through `closing` (firing the retro per F-014) — NOT silently restarted from cycle 0.
3. **Given** a checkpoint whose `cycle_state_sha256` does NOT match the audit-log entry it claims to point to, **When** resume is attempted, **Then** resume rejects with `CHECKPOINT_INTEGRITY_FAIL`, the run halts via F-018 trigger `audit_chain_broken`, and the operator is notified.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cron/resume-from-cycle-N.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/cron/resume-no-checkpoint-halt.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/cron/checkpoint-integrity-fail.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-023 (scheduler that detects + dispatches resume), F-001 (cycle lifecycle), F-008 (checkpoint.json path), F-015 (hash-chained audit log for cycle_state_sha256 verification)
- **Soft:** F-018 (failure-pattern halt for `audit_chain_broken` trigger), F-014 (retro for halted resume), F-020 (kill-switch interaction during resume)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Cron resume after interruption |
| ce:FR-CORE-002 | Run lifecycle includes resume path through `active` |
| kit:rules/resume-protocol.md | Resume discipline (read state, verify, continue from last checkpoint) |
| kit:resume-handoff-skill | Resume-from-handoff pattern adapted to cron runs |

## Implementation notes

(empty — populated when implementation begins)
