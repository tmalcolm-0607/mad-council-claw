---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-110
short-slug: local-telemetry
milestone: M16
provenance:
  surfaces:
    - cp:src/main/logger
    - cp:src/services/telemetry
    - kit:rules/lens-telemetry-pattern
    - kit:rules/no-invented-constraints.md
    - kit:rules/single-owner-accountability.md
    - foundational-plan.md D-1 (default OpenTelemetry-compatible local-file)
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
  LOCKED if GREEN AND reviews/F-110-local-telemetry-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-006, F-008, F-113]
out-of-scope-notes: |
  Remote telemetry export (push to Geneva / OTel collector / Application Insights)
  is OUT for v1 default; F-113 telemetry-opt-in gates ANY remote export and v1
  ships with remote=off. Crash reporting is F-111 (separate ledger). Performance
  metrics aggregation + dashboards are F-112. PII redaction in telemetry payloads
  reuses F-018 (governance triad PII redaction) — not re-implemented here. BYOK /
  customer-managed keys for local telemetry encryption are v1.5.
confidence: high
---

# F-110 — Local telemetry (default OpenTelemetry-compatible local-file)

## Behavior contract

The engine MUST emit telemetry signals (logs, metrics, traces) to a local file in OpenTelemetry-compatible format by default per foundational-plan D-1. Signals are written to `<userData>/telemetry/otel-{date}.jsonl` (one JSON line per record) using OTLP/JSON encoding so any OTel-compatible collector can ingest the file later if the user opts in (per F-113). NO remote export occurs in default config — the file is the only sink. Each record carries: `timestamp_utc`, `signal_type` (log|metric|trace), `resource.session_id` (per F-002), `resource.engine_version`, and signal-specific payload. Logs include `severity`, `body`, structured attrs; metrics include `name`, `value`, `unit`, `dimensions`; traces include `trace_id`, `span_id`, `parent_span_id`, `operation_name`, `duration_ms`. PII redaction (per F-018) runs before write. The engine MUST NOT invent telemetry budgets, sampling caps, or quotas absent explicit user configuration (per `rules/no-invented-constraints.md`). File rotation: daily by date suffix; old files retained per F-008 storage layout policy.

## Acceptance scenarios

1. **Given** a fresh engine launch with default telemetry config (`telemetry.mode = local-only` per F-113), **When** the engine emits 100 mixed signals (logs, metrics, traces) over a 60-second run, **Then** `<userData>/telemetry/otel-2026-05-06.jsonl` contains 100 valid OTLP/JSON-encoded records, each parseable as JSON and validated against the OTel JSON schema; no network egress is observed (verified via test-time network-block).
2. **Given** a structured log call with attrs containing a synthetic email address, **When** the record is written, **Then** the persisted JSONL line has the email attr redacted per F-018 (e.g. `<email>` placeholder), and the original payload never reaches disk.
3. **Given** a span emitted from the engine's identity bootstrap (per F-002), **When** the trace record is written, **Then** the `resource.session_id` matches the engine's bound session_id, and the span's `parent_span_id` correctly chains to the originating run_id (per F-001 lifecycle).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/telemetry/local-otel-jsonl-roundtrip.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/telemetry/pii-redaction-before-write.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/telemetry/trace-session-binding.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel; signal emission hooks in lifecycle), F-006 (logger; upgrades from console to OTel format), F-008 (storage layout; telemetry directory), F-113 (opt-in modes; default = local-only)
- **Soft:** F-018 (PII redaction layer; reused not duplicated), F-002 (session_id binding for resource attrs), F-111 (crash reporting; shares the OTel sink for crash records)
- **Independent:** F-112 (perf metrics; consumes the same sink but writes are independent)

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/main/logger | clawpilot's existing logger; F-110 upgrades it to OTel-format output |
| cp:src/services/telemetry | clawpilot telemetry service shape; informs the engine's wrapper |
| kit:rules/lens-telemetry-pattern | LENS-Common AddLensTelemetry / IStructuredLogEvent shape; informs OTel record shape and field naming for cross-LENS observability |
| kit:rules/no-invented-constraints.md | engine MUST NOT invent sampling caps / budgets without explicit user config |
| kit:rules/single-owner-accountability.md | session_id binding ensures every signal traces to the engine's accountable identity |
| foundational-plan.md D-1 | default = OpenTelemetry-compatible local-file; remote export is opt-in (F-113) |

## Implementation notes

(empty — populated when implementation begins)
