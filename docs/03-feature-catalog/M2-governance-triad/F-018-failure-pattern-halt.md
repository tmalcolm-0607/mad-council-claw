---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-018
short-slug: failure-pattern-halt
milestone: M2
provenance:
  surfaces:
    - kit:foundational-plan.md "halt" surface for M2
    - kit:rules/anomaly-thresholds.md
    - ce:halted_by_* trigger enum
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
  LOCKED if GREEN AND reviews/F-018-failure-pattern-halt-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-014, F-015]
out-of-scope-notes: |
  Manual operator halt (kill-switch JSON) is owned by F-020. This feature is the
  AUTOMATIC failure-pattern halt that fires on detected anomalies (consecutive
  failures, OVERPLANNING, runaway spawns).
confidence: high
---

# F-018 — Failure-pattern halt

## Behavior contract

The engine watches a 9-value enum of trigger conditions: `consecutive_failures_3`, `consecutive_failures_10`, `overplanning_5`, `overplanning_8`, `spawns_per_hour_exceeded`, `token_anomaly_2x`, `rapid_prompt_burst`, `circuit_breaker_open`, `degradation_threshold`. When any trigger fires, the engine immediately transitions to `closing` with `halted_by: <trigger_name>` and `trigger_evidence_sha256: <audit_entry_sha>`. The retro signal (F-014) fires next, capturing the trigger evidence. Thresholds are sourced from `rules/anomaly-thresholds.md` and overridable per-run.

## Acceptance scenarios

1. **Given** an engine that records 3 consecutive failed cycles, **When** the 3rd failure lands, **Then** the engine transitions to `closing` with `halted_by: "consecutive_failures_3"` and the retro carries `trigger_evidence_sha256` matching the 3rd failure's audit entry.
2. **Given** an engine that observes 5 consecutive read-only Tool calls (Read/Grep/Glob with no Write/Edit), **When** the 6th would-be-read fires, **Then** the engine halts with `halted_by: "overplanning_5"` BEFORE the 6th call.
3. **Given** thresholds overridden via run config `consecutive_failures_3 = 10`, **When** the engine records 5 consecutive failures, **Then** no halt fires (threshold = 10 not yet reached); on the 10th failure, halt fires.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/halt/consecutive-failures.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/halt/overplanning.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/halt/threshold-override.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (lifecycle transitions), F-014 (retro consumes trigger_evidence_sha256), F-015 (audit log provides the SHA)
- **Soft:** F-006 (logger surfaces halt events), F-021 (degradation reuses anomaly thresholds)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M2 | "halt" surface |
| kit:rules/anomaly-thresholds.md | 9-value enum + numeric thresholds |
| ce:halted_by_* | trigger enum from canonical-e |

## Implementation notes

(empty — populated when implementation begins)
