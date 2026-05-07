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
feature-id: F-025
short-slug: idle-archival
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - kit:rules/concurrency-safety.md
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

(empty — populated when implementation begins)
