---
artifact-class: feature-ledger
generated-by: hand-authored (wave-006 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-006 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-102
short-slug: briefing-schedule
milestone: M14
provenance:
  surfaces:
    - kit:foundational-plan.md M14 NEW Message 11
    - kit:rules/loop-cadence-discipline.md
    - cp:src/services/llm/factory
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
  LOCKED if GREEN AND reviews/F-102-briefing-schedule-review.md exists with verdict: ACCEPT.
depends-on: [F-061, F-101]
out-of-scope-notes: |
  Cron-expression authoring (full crontab syntax) is post-v1 — v1 supports a fixed enum
  of cadences (daily / weekdays-only / weekly). Multiple schedules per workspace is
  post-v1 — v1 is one schedule per F-074 workspace. Schedule-pause semantics (PTO mode)
  is post-v1. Schedule conflict detection (with other F-061 automations) is post-v1 —
  v1 schedules run independently. Catch-up runs (re-run missed briefings on resume)
  are post-v1; missed schedules are SKIPPED with an audit-chain MISSED_SCHEDULE entry.
confidence: high
---

# F-102 — Briefing schedule

## Behavior contract

The user can configure a **recurring schedule** for the F-101 daily briefing per F-074 workspace. Schedule cadence is one of: `daily` (every 24h at user-specified UTC time), `weekdays-only` (Mon-Fri at user-specified UTC time), or `weekly` (one user-specified day-of-week at user-specified time). The schedule registers as an F-061 automation; on fire, it invokes the F-101 generator for the window `[previous-fire, this-fire]` and dispatches the result via F-103 destination. Missed fires (engine offline at scheduled time) emit an audit-chain `MISSED_SCHEDULE` entry on next engine boot — the briefing is NOT silently skipped without a record. Schedule cadence MUST honor `rules/loop-cadence-discipline.md` — minimum interval is 24h (sub-daily briefings are rejected as a mis-use of the daily-briefing concept).

## Acceptance scenarios

1. **Given** the user configures `daily at 09:00 UTC` for workspace W, **When** the engine clock reaches 09:00 UTC, **Then** F-101 fires with window `[Yesterday 09:00 UTC, Today 09:00 UTC]` AND the result is dispatched via the configured F-103 destination AND an audit-chain `BRIEFING_SCHEDULED_FIRE` entry is appended.
2. **Given** the engine was offline from 08:00 to 11:00 UTC and a `daily at 09:00 UTC` schedule existed, **When** the engine boots at 11:01 UTC, **Then** an audit-chain `MISSED_SCHEDULE` entry is appended naming the missed 09:00 fire AND no catch-up briefing is auto-generated AND the next scheduled fire is the following day's 09:00 UTC.
3. **Given** the user attempts to configure a schedule with cadence `every 6 hours`, **When** the configuration is submitted, **Then** the operation rejects with `BRIEFING_CADENCE_INVALID` AND the F-074 workspace's schedule field is unchanged AND no automation is registered.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/briefing-schedule/schedule-fires-at-cadence.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/briefing-schedule/missed-schedule-emits-audit-entry.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/briefing-schedule/sub-daily-cadence-rejected.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-061 (automations-base provides the scheduling primitive), F-101 (daily-briefing generator is what gets scheduled)
- **Soft:** F-074 (project workspace scopes schedule), F-015 (audit chain records fires + missed fires), F-103 (destination is invoked on fire)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M14 NEW Message 11 | "schedule" verbatim from user's NEW-features answer (M14 row) |
| kit:rules/loop-cadence-discipline.md | Sub-daily briefings violate cadence discipline; minimum 24h interval enforced |
| cp:src/services/llm/factory | Existing factory pattern is the model for F-061 → F-102 scheduled-task registration shape |

## Implementation notes

(empty — populated when implementation begins; CronCreate vs internal scheduler choice deferred to M14 design wave council-review)
