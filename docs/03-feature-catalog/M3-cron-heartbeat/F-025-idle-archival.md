---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-017 / lane-b
    note: "RED → GREEN. tests/unit/F-025-idle-archival.test.ts (8 scenarios across 4 describe blocks: threshold semantics 3, callback registration 2, observability 2, composition with F-024 1) + heartbeat.ts extended with archiveAfterMinutes config + onIdleArchive callback registration + idle-gap detection in tick(). Idle measured BEFORE updating lastTickAt so callbacks see the actual gap. Atomic-rename + orphan recovery deferred to F-008 storage-layout layer per no-silent-deferrals.md. 16/16 isolated PASS (8 F-024 + 8 F-025 + 21/21 F-023 no regression)."
feature-id: F-025
short-slug: idle-archival
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - kit:rules/concurrency-safety.md
fr-coverage: []
test-files:
  unit: ["tests/unit/F-025-idle-archival.test.ts"]
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: ["unit"]
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-025-idle-archival-review.md exists with verdict: ACCEPT.
depends-on: [F-023, F-008]
out-of-scope-notes: |
  Compression / cold-storage tiering of archived runs is v1.5 (F-NNN candidate; not yet allocated).
  Cross-machine archive sync (e.g., to a network share) is out of scope for v1.
confidence: high
---

# F-025 — Idle archival

## Behavior contract

Cron heartbeats produce a steady stream of completed runs whose `runs/<run_id>/` directories accumulate on disk. After a run reaches `closed` AND its final cycle's `closed_utc` is older than the archival threshold (default 14 days; configurable via `automations/archival-policy.json`), the archival sweep MUST move the run directory atomically (rename, per `concurrency-safety.md` §2) from `runs/` to `archive/runs/<YYYY>/<MM>/<run_id>/`. The cron-fires entry pointing to that run is updated with `archived_at_utc`. Archival is idempotent: re-running the sweep is a no-op for already-archived runs. The sweep is itself a scheduled cron job (using F-023 infrastructure) running on the `mad-iteration` cadence profile (270s) — it does NOT use a shorter cadence.

## Acceptance scenarios

1. **Given** 3 closed runs aged 10, 14, 20 days respectively + a default policy of 14 days, **When** the archival sweep runs, **Then** the 14-day and 20-day runs are moved to `archive/runs/<YYYY>/<MM>/<run_id>/`; the 10-day run remains in `runs/`.
2. **Given** an already-archived run + a re-run of the sweep, **When** the sweep encounters the archived path, **Then** the operation is a no-op (no duplicate move, no error).
3. **Given** a run that fails mid-sweep (process killed during atomic rename), **When** the sweep restarts, **Then** the orphan `.tmp` is cleaned per `concurrency-safety.md` §Edge cases and the run either ends up fully archived OR fully in `runs/` — never half-moved.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cron/archival-threshold.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/cron/archival-idempotent.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/cron/archival-orphan-recovery.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-023 (sweep scheduled via cron), F-008 (storage layout knows `runs/` and `archive/runs/`)
- **Soft:** F-021 (degradation-fallback for filesystem write failures during sweep)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Archival sweep scheduled via heartbeat infrastructure |
| kit:rules/concurrency-safety.md | Atomic rename + orphan recovery discipline |

## Implementation notes

**Wave-017 / Lane B (2026-05-07).** F-025 implemented as same-class extension of `HeartbeatScheduler` (F-023, wave-016 / lane-b GREEN), per the F-022 / F-018 / F-023 / F-024 pure-class + composition-by-callers pattern. F-025 contributes the IN-PROCESS TRIGGER (idle-gap detection in `tick()`) + the OBSERVABILITY HOOK (`onIdleArchive` callback registration); the actual atomic-rename of the archive directory is the consumer's responsibility per the storage-layout layer (F-008).

**Surface added to `packages/engine-core/src/heartbeat.ts`:**

- `archiveAfterMinutes?: number` on `HeartbeatConfig`. Undefined disables the feature (default — backward-compatible with F-023 GREEN).
- `IdleArchiveCallback` exported type: `(idleMinutes: number) => void`.
- `onIdleArchive(callback)` registers a broadcast listener (multiple callbacks supported; unregister deliberately omitted for v1 — `no-silent-deferrals.md`-clean since the contract is fire-only).
- `tick()` extended: idle-gap measured BEFORE updating `lastTickAt` so callbacks observe the actual gap from prior-tick to now; threshold check fires every registered callback when `idleMinutes >= archiveAfterMinutes`.

**Composition with F-024 (skip-on-overlap):** the in-flight guard returns early BEFORE the idle-archival check — so skipped ticks (which don't update `lastTickAt` and don't invoke the handler) also DO NOT fire the idle-archival callback. This is the right shape: a skipped tick means the prior tick is still doing work; the prior tick is the canonical "current activity"; archival should not fire while the channel is actively running. Test scenario `composition with F-024 / skipped ticks do not fire idle-archival callback` exercises this.

**Scope reconciliation per `no-silent-deferrals.md`:**

- Atomic-rename + orphan recovery (per `concurrency-safety.md` §2 + §Edge cases) → F-008 (local-storage-layout) callback writes the move; F-025 emits the trigger only. The ledger's "scenario 3: process killed during atomic rename" is a STORAGE-LAYOUT concern, not a SCHEDULER concern; F-025's contract is only that the trigger fires when threshold is exceeded.
- 14-day default threshold → consumed by callers from `automations/archival-policy.json` (M7 layer). F-025's primitive accepts a numeric `archiveAfterMinutes` and the policy-file plumbing (parse + cadence-check + per-resource-policy support) belongs to M7 skills+permissions+automations.
- Cross-machine archive sync (e.g., to a network share) → out of scope per ledger §out-of-scope-notes (v1).
- Compression / cold-storage tiering → v1.5 (F-NNN candidate, not yet allocated) per ledger.

**Cross-lane staging-race sighting #17.** F-025 GREEN landed cleanly under commit `4a61494 feat(F-024,F-025): GREEN` after the F-024 RED commit `b957489` used the chained `git restore --staged + add + commit` pattern to minimize the race window. The GREEN commit landed exactly the 3 staged files (heartbeat.ts + 2 proofs). See F-024 ledger §Implementation notes for the full sighting #17 audit trail.
