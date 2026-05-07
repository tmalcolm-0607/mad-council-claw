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
feature-id: F-062
short-slug: automations-cron-type
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/automations/schedule.ts
    - cp:electron/automations/triggering.ts
    - kit:rules/loop-cadence-discipline.md
    - kit:rules/anomaly-thresholds.md
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
  LOCKED if GREEN AND reviews/F-062-automations-cron-type-review.md exists with verdict: ACCEPT.
depends-on: [F-061, F-023]
out-of-scope-notes: |
  Automations base manager is F-061; condition triggers are F-063.
  Cron heartbeat as engine primitive is F-023 (M3); this feature is the AUTOMATION-typed wrapper that calls F-023.
  Skip-on-overlap semantics inherit from F-024 (M3 cron skip-on-overlap).
  Overlap detection across multiple cron-type automations is F-064 + F-066.
  Timezone-aware cron is OUT OF SCOPE for v1; cron expressions evaluate against local system time. UTC-only mode is v1.5.
configurable: |
  Cron expression syntax follows standard 5-field UNIX cron + optional 6th-field seconds.
  Maximum effective cadence is 1 minute (per F-023 + loop-cadence-discipline).
confidence: high
---

# F-062 — Automations cron-type trigger

## Behavior contract

An automation with `trigger: { type: "cron", expression: string }` is registered with the engine's cron heartbeat (F-023). The schedule layer (`schedule.ts`-style) parses the cron expression at automation save time; invalid expressions reject with `CRON_EXPRESSION_INVALID` and the automation is NOT persisted. On each heartbeat tick, the trigger fires the automation's steps via the manager's run-now path (F-061). If a previous run is still in-flight when the next tick fires, the new tick is skipped and a `CRON_OVERLAP_SKIPPED` event is recorded (per `cp:electron/automations/triggering.ts` + F-024 skip-on-overlap). A duplicate brief automation on the same expression is rejected at save time per the `71fcbec3` clawpilot fix ("prevent duplicate brief automations") — the manager rejects with `AUTOMATION_DUPLICATE` when a same-expression+same-steps entry already exists.

## Acceptance scenarios

1. **Given** an automation `{ trigger: { type: "cron", expression: "0 9 * * MON-FRI" }, ... }` saved at 8:30am, **When** the heartbeat ticks at 9:00am on a Monday, **Then** the automation's steps execute exactly once AND a run record is appended to history.jsonl.
2. **Given** the same automation, **When** the user attempts to save a SECOND automation with the same expression + identical steps, **Then** the manager rejects with `AUTOMATION_DUPLICATE` and the second is NOT persisted.
3. **Given** a cron-typed automation whose previous run is still executing at the next tick, **When** the heartbeat fires, **Then** the new tick is skipped AND a `CRON_OVERLAP_SKIPPED` event records `{ automation_id, skipped_tick_utc, in_flight_run_id }`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/automations/cron-fires-on-schedule.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/automations/cron-duplicate-rejection.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/automations/cron-overlap-skip.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-061 (automations base — this feature is a trigger type that wraps base manager + run-now), F-023 (cron heartbeat that ticks the schedule)
- **Soft:** F-024 (skip-on-overlap semantics inherited at the heartbeat layer), F-058 (every step still goes through permission classifier), F-066 (results-in-shell — cron run output surfaces here)
- **Independent:** F-051..F-057 (skills can be a step target but the dependency is via F-061 step kind)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "cron" is item 12 of the M7 catalog list |
| cp:electron/automations/schedule.ts | Cron parsing + tick-routing pattern |
| cp:electron/automations/triggering.ts | Trigger dispatch + overlap detection |
| kit:rules/loop-cadence-discipline.md | Min-cadence floor (60s warm-cache zone) |
| kit:rules/anomaly-thresholds.md | If a cron repeats anomalies above threshold, the engine's anomaly detector pauses the automation |

## Implementation notes

(empty — populated when implementation begins)
