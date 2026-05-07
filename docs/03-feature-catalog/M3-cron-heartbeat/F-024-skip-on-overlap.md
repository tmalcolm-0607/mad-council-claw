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
feature-id: F-024
short-slug: skip-on-overlap
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - ce:SC-007
    - ce:CronFireRecord
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
  LOCKED if GREEN AND reviews/F-024-skip-on-overlap-review.md exists with verdict: ACCEPT.
depends-on: [F-023]
out-of-scope-notes: |
  Cross-schedule contention (two different schedules firing at the same instant) is
  resolved by F-022 (tool-quota) + concurrency-safety atomic-rename — not by this feature.
  This feature only handles same-schedule overlap (a prior fire of the same schedule still active).
confidence: high
---

# F-024 — Skip-on-overlap

## Behavior contract

When a cron heartbeat (per F-023) is about to fire and a prior fire of the SAME schedule is still in `active` (i.e., its run has not reached `closed`), the scheduler MUST skip the new fire — NOT queue it, NOT run concurrently. The skipped fire is recorded as an append-only entry in `cron-fires.jsonl` with `outcome: "overlap_skipped"` and `prior_fire_id` referencing the still-running fire. Per ce:SC-007 the silent-overlap rate must be 0% across 100 simulated overlap conditions. Skipping is observable: the audit log + retro of the surviving prior run carry no acknowledgement of the skipped fire — the cron-fires.jsonl IS the record.

## Acceptance scenarios

1. **Given** a schedule firing every 30s and a run that takes 90s to complete, **When** the scheduler attempts fires at t=0, t=30, t=60, t=90, **Then** the fire at t=0 runs to completion; t=30 + t=60 are recorded with `outcome: "overlap_skipped"` and `prior_fire_id` pointing to t=0's fire; t=90 fires normally as a new run.
2. **Given** a fire skipped due to overlap, **When** an operator queries `cron-fires.jsonl`, **Then** the skipped entry has `actual_fire_utc` matching the scheduled time + `outcome: "overlap_skipped"` + `prior_fire_id` resolvable to a still-active or recently-closed run.
3. **Given** two different schedules (A every 30s, B every 30s offset by 15s) overlapping in time but NOT in schedule_id, **When** both fire concurrently, **Then** both run — overlap detection is per-schedule, not global.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cron/overlap-skip.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/cron/overlap-record-shape.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/cron/cross-schedule-no-skip.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-023 (cron scheduler + cron-fires.jsonl shape)
- **Soft:** F-001 (run lifecycle state used to detect "still active")
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Overlap detection within heartbeat scheduler |
| ce:SC-007 | 0% silent overlaps across 100 sims |
| ce:CronFireRecord | `overlap_skipped` outcome + `prior_fire_id` field |

## Implementation notes

(empty — populated when implementation begins)
