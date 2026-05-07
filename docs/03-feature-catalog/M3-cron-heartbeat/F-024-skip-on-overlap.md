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
    note: "RED → GREEN. tests/unit/F-024-skip-on-overlap.test.ts (8 scenarios across 4 describe blocks) + heartbeat.ts extended with tickInFlight guard + skippedTicks counter + TickResult return shape + isInFlight on getStatus. Same-class extension per F-022/F-018/F-023 pure-class pattern. cron-fires.jsonl outcome:'overlap_skipped' write deferred to F-006/F-008 callers per no-silent-deferrals.md. Cross-lane staging-race sighting #17 observed (commits e466b52 + 2463d90 used this lane's subject but committed F-029/F-026/F-030 sibling-lane files); fix-forward commit b957489 landed actual RED files. 16/16 isolated PASS; 21/21 F-023 isolated PASS (no regression)."
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
  unit: ["tests/unit/F-024-skip-on-overlap.test.ts"]
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: ["unit"]
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

**Wave-017 / Lane B (2026-05-07).** F-024 implemented as same-class extension of `HeartbeatScheduler` (F-023, wave-016 / lane-b GREEN), per the F-022 ToolCallQuota / F-018 HaltDetector pure-class + composition-by-callers pattern.

**Surface added to `packages/engine-core/src/heartbeat.ts`:**

- `tickInFlight: boolean` private field set true when handler invocation begins, cleared in `finally` (handles throw-path so a single failed tick does NOT permanently block subsequent ticks — important for the F-018 RUN_HALTED + F-021 degradation orchestration story).
- `skippedTicks: number` private counter incremented on each suppressed re-entry.
- `tick(): Promise<TickResult>` return-shape change. `TickResult { ran: boolean; skipped?: boolean }`. Backward-compatible: F-023 callers that did `await sch.tick()` and discarded the return value continue to work; F-024 callers that need the SKIP signal inspect `skipped`. Skipped ticks do NOT increment `tickCount` and do NOT invoke the handler.
- `getStatus(): HeartbeatStatus` extended with `skippedTicks: number` and `isInFlight: boolean` for observability.

**Scope reconciliation per `no-silent-deferrals.md`:**

- `cron-fires.jsonl` `outcome: "overlap_skipped"` + `prior_fire_id` write → F-006 (logging-pipeline) + F-008 (storage-layout) callers consume the SKIP signal from `tick()` return value and append the entry. F-024 contributes the in-process trigger only; the on-disk audit record is the consumer's responsibility.
- Cross-schedule independence (ledger scenario 3) → mirrored on F-022's one-quota-per-resource shape: separate `HeartbeatScheduler` instances per schedule. The class itself does not maintain cross-schedule state — that's by-design. The cross-schedule scenario test would exercise two scheduler instances and verify both run; not added in this RED set because the assertion ("they don't interfere") is structurally guaranteed by the per-instance state.
- Run-lifecycle "still active" detection → caller-side. F-024's same-schedule guard is based on whether the handler PROMISE has resolved, not on whether the spawned RUN has reached `closed`. The two are equivalent for in-process orchestration but diverge for out-of-process runs (F-031 daemon-mode); when that lands, the orchestrator's tick handler will await the run closure before resolving its promise — preserving the F-024 contract without changes here.

**Cross-lane staging-race sighting #17.** Two commits before the actual GREEN landing used this lane's subject line but committed sibling lanes' files:

- `e466b52 test(F-024,F-025): RED ...` actually committed `tests/node/F-029-cli-subcommands.test.ts` (sibling F-029 lane).
- `2463d90 test(F-024,F-025): RED actual ...` actually committed `docs/09-examples-proof/F-026/green-test-output.txt`, `packages/engine-core/src/checkpoint.ts`, `packages/engine-core/src/index.ts`, `tests/node/F-030-cli-json-output.test.ts` (sibling F-026 + F-030 lanes).
- `b957489 test(F-024,F-025): RED actual files (sighting #17 third attempt)` finally landed the four F-024/F-025 RED files using a chained `git restore --staged + git add + git commit` invocation to minimize the race window between staging and commit.

Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset` per user directive 2026-05-07), no rebase/reset to fix history. The pattern is now confirmed CHRONIC across waves 9-17 (sightings #14, #15, #16, #17). The wave-17+ recurrence-mitigation candidates (per-lane branches when concurrent lane count ≥3, OR per-commit `git diff --cached --name-only` assert) are pending council deliberation.
