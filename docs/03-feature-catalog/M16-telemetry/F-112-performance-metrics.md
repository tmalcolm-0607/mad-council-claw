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
feature-id: F-112
short-slug: performance-metrics
milestone: M16
provenance:
  surfaces:
    - cp:src/services/llm/factory
    - cp:src/services/telemetry
    - kit:rules/lens-telemetry-pattern
    - kit:rules/anomaly-thresholds.md
    - kit:rules/no-invented-constraints.md
    - foundational-plan.md M16 telemetry section
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
  LOCKED if GREEN AND reviews/F-112-performance-metrics-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-110, F-113]
out-of-scope-notes: |
  Live in-app metrics dashboard / chart UI is OUT for v1 (M12 visualization owns
  any telemetry-aware UI). Aggregation across sessions is OUT — each session
  emits raw counters/histograms; aggregation is a downstream concern at the
  collector if user opts in via F-113. Cost forecasting / anomaly detection on
  metrics is OUT (covered by F-020 cost ledger + F-019 halt for engine-level
  budgets; metrics here are observational only). Custom user-defined metrics
  (an SDK for users to add their own) are v1.5.
confidence: high
---

# F-112 — Performance metrics

## Behavior contract

The engine MUST emit a fixed set of OTel-format performance metrics to F-110's local sink covering: LLM-call latency (histogram, dimensions: `provider`, `model`, `success`), tokens-in / tokens-out (counters, dimensions: `provider`, `model`), MCP tool-invocation latency (histogram, dimensions: `tool_name`, `success`), engine-cycle duration (histogram, dimensions: `phase`), per-cycle queue depth (gauge), and process resource snapshots (RSS bytes, CPU %) sampled every 30s. Metrics use OTel semantic-conventions naming where applicable (`gen_ai.client.token.usage`, `gen_ai.client.operation.duration` per OTel GenAI conventions). Histograms use OTel default exponential buckets — the engine MUST NOT invent custom bucket boundaries absent explicit user config (per `rules/no-invented-constraints.md`). Metric records are append-only to the same `otel-{date}.jsonl` file as F-110 with `signal_type: metric`. Anomaly thresholds (per `rules/anomaly-thresholds.md`) drive operator-visible warnings ONLY when explicit thresholds are configured; default config emits raw metrics without threshold-based reactions.

## Acceptance scenarios

1. **Given** an engine running a single LLM call to Anthropic's Claude API (per F-009 backend), **When** the call completes, **Then** F-110's JSONL sink contains a histogram record `gen_ai.client.operation.duration` with dimensions `{provider: anthropic, model: claude-opus-4-7, success: true}` and a counter record `gen_ai.client.token.usage` with the token count from the response.
2. **Given** an MCP tool invocation that fails with timeout, **When** the failure is recorded, **Then** the tool-invocation histogram records `success: false` AND a separate counter `mcp.tool.errors` increments — both signals reach the sink (no silent deferrals).
3. **Given** a 5-minute engine run with the resource sampler active, **When** the run completes, **Then** at least 10 RSS-bytes gauge records exist in the sink (one per ~30s sample), each carrying a parseable timestamp and a numeric value within plausible RSS bounds (>50MB and <8GB for a desktop Electron app).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/telemetry/llm-latency-histogram.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/telemetry/mcp-tool-error-counter.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/telemetry/resource-sampler-cadence.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel; cycle phase markers), F-008 (storage), F-110 (shared OTel sink), F-113 (opt-in mode gates emission cadence at the highest privacy tier)
- **Soft:** F-009 (Anthropic backend; first LLM-call instrumentation surface), F-029 (MCP tool layer; tool-invocation instrumentation)
- **Independent:** F-111 (crash reporting; orthogonal signal path)

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/services/llm/factory | clawpilot's LLM factory has timing hooks; engine extends to OTel histograms |
| cp:src/services/telemetry | clawpilot telemetry service shape; informs metric naming conventions |
| kit:rules/lens-telemetry-pattern | LENS QOS metric pattern (Counter/Histogram attributes); informs cardinality discipline |
| kit:rules/anomaly-thresholds.md | thresholds drive opt-in operator warnings; defaults emit raw metrics only |
| kit:rules/no-invented-constraints.md | engine uses OTel default buckets; custom buckets only if explicitly configured |
| foundational-plan.md M16 | telemetry plane scope: latency / tokens / cost + resource utilization for engine forensics |

## Implementation notes

(empty — populated when implementation begins)
