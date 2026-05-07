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
feature-id: F-023
short-slug: cron-heartbeat
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - ce:US-7
    - ce:US-8
    - ce:CronFireRecord
    - kit:loop-skill
    - kit:rules/loop-cadence-discipline.md
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
  LOCKED if GREEN AND reviews/F-023-cron-heartbeat-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-006, F-008]
out-of-scope-notes: |
  Skill-allowlist + version-pinning at heartbeat fire is M7 (F-051..F-056).
  Conditional-trigger automations (event-driven, not cron) are M7 (F-061..F-063).
  Multistep automations (chained cron-fires) are M7 (F-064).
confidence: high
---

# F-023 — Cron heartbeat

## Behavior contract

The engine supports cron-driven heartbeats: scheduled, recurring, autonomous run invocations registered in `automations/cron-schedules.json`. A heartbeat scheduler reads each schedule's cron expression, computes next-fire times, and at each fire spawns a fresh run (per F-001) under the configured agent identity (per F-002). Each fire is recorded as an append-only entry in `automations/cron-fires.jsonl` with `fire_id`, `schedule_id`, `scheduled_utc`, `actual_fire_utc`, `run_id`, and `outcome`. Schedule drift (actual_fire_utc vs scheduled_utc) MUST stay ≤5% of the cadence interval over a 100-fire window (per ce:SC-007). The scheduler is cadence-aware per `kit:rules/loop-cadence-discipline.md` — the two named profiles (`mad-iteration` 270s, `deployment-watch` 1500s) are the canonical defaults; the 280-1199s zone is forbidden.

## Acceptance scenarios

1. **Given** a registered cron schedule `*/5 * * * *` (every 5 min, mapped to `deployment-watch` profile @ 300s nearest), **When** the scheduler runs for 1 hour, **Then** `cron-fires.jsonl` contains exactly 12 entries (±1 for boundary), each with `outcome: "completed"` and drift ≤15s (5% of 300s).
2. **Given** a heartbeat fire that boots a run, **When** the run completes, **Then** the cron-fires entry is updated with the resulting `run_id` + final outcome (cross-referenced with that run's audit log).
3. **Given** a heartbeat scheduled with cadence in the forbidden zone (`delaySeconds: 600`), **When** the scheduler validates the schedule, **Then** registration is rejected with `CADENCE_FORBIDDEN_ZONE` and a remediation pointer to `loop-cadence-discipline.md`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cron/scheduler-drift.test.ts` | unit | RED — drift accounting | scenario 1 |
| (TBD) `tests/integration/cron/heartbeat-run-spawn.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/cron/cadence-zone-validation.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (run lifecycle to spawn), F-006 (logging for fire entries), F-008 (storage layout for `automations/cron-fires.jsonl`)
- **Soft:** F-024 (skip-on-overlap fires when this scheduler would double-fire), F-002 (identity for spawned-run agent_id)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Cron-driven heartbeat with overlap detection |
| ce:US-7 | Heartbeat user story (P3) |
| ce:US-8 | Cron proactive execution user story |
| ce:CronFireRecord | Append-only `cron-fires.jsonl` schema |
| kit:loop-skill | `/loop` cadence pattern as the substrate |
| kit:rules/loop-cadence-discipline.md | Cadence profiles + forbidden zone enforcement |

## Implementation notes

(empty — populated when implementation begins)
