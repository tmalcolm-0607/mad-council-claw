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
feature-id: F-006
short-slug: logging-pipeline
milestone: M0
provenance:
  surfaces:
    - cp:src/main/logger
    - ce:FR-AUDIT-001
    - kit:lens-telemetry
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
  LOCKED if GREEN AND reviews/F-006-logging-pipeline-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008]
out-of-scope-notes: |
  Local OpenTelemetry export + crash reporting are tracked under M16 (F-110..F-113).
  This feature provides the structured-event pipeline that those telemetry features
  consume; it does not itself emit OTel spans.
confidence: high
---

# F-006 — Logging pipeline

## Behavior contract

A single structured-logging facade routes every engine event to two sinks: (1) a human-readable rolling text log under `runs/<run_id>/log.ndjson`, and (2) the hash-chained audit log per F-015. Every entry carries `{run_id, agent_id, parent_run_id, timestamp_utc, level, event_name, fields}`. Levels are `trace | debug | info | warn | error | fatal`. The facade is the ONLY supported way to emit logs from engine-core; direct `console.log` from engine code is forbidden by lint rule.

## Acceptance scenarios

1. **Given** an engine cycle emits `logger.info('cycle.start', { cycle: 3 })`, **When** the cycle completes, **Then** `runs/<run_id>/log.ndjson` contains a single JSON line with `event_name: "cycle.start"`, `fields.cycle: 3`, and the full identity triple.
2. **Given** a developer adds `console.log('debug')` inside `packages/engine-core/src/`, **When** lint runs, **Then** the rule `no-console` fires with severity error.
3. **Given** an info-level emit and an audit-log writer that's offline, **When** the logger is invoked, **Then** the text log still receives the entry AND the logger surfaces a degradation signal (per `degradation-fallback-policy.md` Rule 3) without crashing.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/logging/structured-event.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/logging/no-console-rule.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/logging/audit-sink-degraded.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine cycles produce events), F-002 (identity stamps every entry), F-008 (storage layout for `runs/<run_id>/log.ndjson`)
- **Soft:** F-015 (hash-audit consumes the same pipeline)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/main/logger | clawpilot main-process logger pattern |
| ce:FR-AUDIT-001 | hash-chained audit log feeds off this pipeline |
| kit:lens-telemetry | structured-event discipline (LoggerMessage source generators in .NET; same shape in TS) |

## Implementation notes

(empty — populated when implementation begins)
