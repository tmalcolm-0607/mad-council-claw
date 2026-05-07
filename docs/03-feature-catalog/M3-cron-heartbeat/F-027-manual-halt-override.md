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
feature-id: F-027
short-slug: manual-halt-override
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - ce:FR-KILL-001
    - kit:rules/dangerous-operations-policy.md
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
  LOCKED if GREEN AND reviews/F-027-manual-halt-override-review.md exists with verdict: ACCEPT.
depends-on: [F-020, F-023]
out-of-scope-notes: |
  Multi-operator quorum on halts (e.g., 2-person rule) is out of scope for v1.
  Per-schedule role-based authorization (only the schedule owner may halt) is v1.5.
  In v1 any operator with filesystem write access to `automations/` may pause/halt.
confidence: high
---

# F-027 — Manual halt override

## Behavior contract

An operator MUST be able to halt cron heartbeats manually without modifying source. Two distinct operations are supported:

1. **Pause schedule** — write `paused: true` (with `paused_at_utc` + `paused_reason`) into `automations/cron-schedules.json` for the target schedule. The scheduler reads this on each tick; paused schedules are skipped (recorded in `cron-fires.jsonl` with `outcome: "paused_skipped"`). Resuming clears `paused: true`.
2. **Halt active run** — independent of pausing the schedule, an operator may write to the engine-wide `kill-switch.json` (per F-020) which propagates within ≤1 cycle to halt any in-flight runs (cron-spawned or otherwise). The cron-fires entry's `outcome` is updated to `halted_by_kill_switch`.

Both operations are observable + recoverable: pause leaves the schedule intact; kill-switch fires the retro per F-014. The dangerous-operations consent gate (per `kit:rules/dangerous-operations-policy.md` §Force Reclaim category) does NOT apply to pause (it's reversible) but DOES apply to bulk-halt (pausing >5 schedules in one operation requires explicit "yes").

## Acceptance scenarios

1. **Given** an active cron schedule + an operator writing `paused: true` to its entry, **When** the next scheduled fire-time arrives, **Then** no run is spawned + `cron-fires.jsonl` contains an entry with `outcome: "paused_skipped"`.
2. **Given** an in-flight run spawned from a heartbeat fire + an operator setting `kill-switch.json: { "halt_run_id": "<id>" }`, **When** the run's next cycle hook checks, **Then** the run halts within ≤1 cycle, transitions through `closing`, fires the retro with `halted_by: kill_switch`, and the cron-fires entry is updated with `outcome: "halted_by_kill_switch"`.
3. **Given** an operator attempting to pause 6 schedules at once, **When** the bulk-pause command is invoked, **Then** the dangerous-operations consent gate fires + the operation does NOT proceed without explicit "yes" + a preview of the 6 schedules is shown.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cron/manual-pause.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/cron/manual-halt-active-run.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/cron/bulk-pause-consent-gate.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-020 (kill-switch infrastructure for halting active runs), F-023 (scheduler reads pause state per tick)
- **Soft:** F-014 (retro fires on halt), F-018 (halt is one of 9 trigger enum values)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Manual halt + pause operations on cron schedules |
| ce:FR-KILL-001 | Kill-switch propagation into cron-spawned runs |
| kit:rules/dangerous-operations-policy.md | Bulk-halt consent gate |

## Implementation notes

(empty — populated when implementation begins)
