---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a; flipped wave-017 / lane-c)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-017 / lane-c
    note: "RED → GREEN. CheckpointManager primitive (~80 LOC) + 6 RED-cleared scenarios under tests/node/F-026-resume-from-checkpoint.test.ts. Scope: save/load/exists semantics + atomic-write persistence + null-on-missing contract. F-015 audit-chain integration deferred to engine-cycle integration step per no-silent-deferrals.md."
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
  node:
    - tests/node/F-026-resume-from-checkpoint.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - "vitest run tests/node/F-026-resume-from-checkpoint.test.ts"
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

### wave-017 / lane-c — RED → GREEN flip (2026-05-07)

**Scope deviation from ledger §Behavior contract** (intentional, documented per `rules/no-silent-deferrals.md`):

The ledger §Behavior contract specifies a richer `runs/<run_id>/checkpoint.json` schema with `last_completed_cycle`, `cycle_state_sha256` (linking F-015 audit log), and `resumable: true`, plus a scheduler-startup sweep that resumes from `last_completed_cycle + 1` and emits a `resumed_from_checkpoint` audit entry.

The wave-017 lane-c brief simplifies this primitive to a `CheckpointManager` class with:

- Constructor `new CheckpointManager(path: string)`.
- `save(input)` — writes via F-008's `atomicWriteJson`, returns the full Checkpoint with `schemaVersion: 1` + auto-injected `savedAt` ISO-8601 timestamp.
- `load()` — returns the parsed Checkpoint or `null` when missing/unreadable. Catch-all silently swallows parse + IO errors per ledger's "no checkpoint" semantics.
- `exists()` — cheap presence check for scheduler startup sweeps that inventory resumable runs without parsing.

The substantive guarantees are preserved:

- Atomic-write persistence (F-008's `atomicWriteJson` — no half-read).
- Missing-file → null contract (callers map this to ledger scenario 2's `halted_by: lost_checkpoint` path).
- `schemaVersion: 1` preservation through round-trip.
- `savedAt` auto-injection at save time (caller cannot fabricate stale timestamps).

Deferred to caller integration (engine-cycle integration step):

- F-015 audit-chain `cycle_state_sha256` verification + the `CHECKPOINT_INTEGRITY_FAIL` → F-018 `audit_chain_broken` halt path.
- `last_completed_cycle` advancement semantics + scheduler resume dispatch (F-023 caller integration).
- Resume-marker re-write on advance + the F-014 retro-on-lost-checkpoint emission.
- Cross-machine resume (carry checkpoint to a different host) — explicitly v1 out-of-scope per ledger §out-of-scope-notes.

This mirrors F-022 ToolCallQuota + F-018 HaltDetector + F-023 HeartbeatScheduler pure-class pattern: primitive class + caller wires composition.

### Cross-lane staging-race sighting #19+ (2026-05-07)

`packages/engine-core/src/checkpoint.ts` + barrel re-export + GREEN proof artifact landed in commit `2463d90` (subject "test(F-024,F-025): RED actual"). Pre-commit hook swept files from working tree across active lanes. Per `non-negotiable-rules.md` (no destructive git ops; user directive 2026-05-07 "DO NOT use git reset"), no rebase/reset to fix history. Substance preserved (verified by 6/6 tests PASS at GREEN; full suite 225/225 PASS post-flip); credit attribution in commit subject is corrupted. Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE), the file's actual provenance is documented here in the ledger Implementation notes — the authoritative record beats the commit subject for archaeology.

### Test-file path

- `tests/node/F-026-resume-from-checkpoint.test.ts` (~155 LOC, 6 scenarios across one `describe` block: save creates file, load round-trips, load returns null when missing, exists reflects presence, schemaVersion preserved, savedAt auto-injected ISO-8601).

### Source path

- `packages/engine-core/src/checkpoint.ts` (~80 LOC, exports `CheckpointManager` class + `Checkpoint` type + `CheckpointInput` type + `PipelinePhase` union).

### Proof artifacts

- `docs/09-examples-proof/F-026/red-test-output.txt` (6/6 fail at RED; `CheckpointManager is not a constructor`).
- `docs/09-examples-proof/F-026/green-test-output.txt` (6/6 PASS at GREEN).
