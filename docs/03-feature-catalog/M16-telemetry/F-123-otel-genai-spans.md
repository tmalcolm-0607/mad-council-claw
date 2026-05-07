---
artifact-class: feature-ledger
generated-by: hand-authored (wave-012 / lane-c)
status: red
status-since: 2026-05-07
status-history:
  - status: planned
    at: 2026-05-06
    by: foundational-plan.md catalog deltas
    note: "F-NNN reserved as one of 5 frontier-research candidates"
  - status: red
    at: 2026-05-07
    by: wave-012 / lane-c
    note: "Initial ledger created; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-123
short-slug: otel-genai-spans
milestone: M16
provenance:
  surfaces:
    - foundational-plan.md "Plus 5 NEW F-NNN candidates" F-123
    - foundational-plan.md "[R:msft-learn Foundry observability]"
    - docs/06-agent-team-outputs/wave-001/lane-b-summary.md (finding 16 — OTel GenAI semantic conventions)
    - kit:rules/lens-telemetry-pattern (LENS structured-event shape; informs OTel record naming)
    - kit:rules/no-invented-constraints.md (no sampling caps or budgets without explicit user config)
    - kit:rules/single-owner-accountability.md (session_id on every span)
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
  LOCKED if GREEN AND reviews/F-123-otel-genai-spans-review.md exists with verdict: ACCEPT.
depends-on: [F-110, F-112, F-002, F-013]
out-of-scope-notes: |
  Remote OTel collector export — gated by F-113 telemetry-opt-in tri-state; v1 default
  is `local-only`, no remote push of GenAI spans.
  Foundry-hosted agent deployment (Azure AI Foundry's own observability stack) — tracked
  under F-D-017 (deferred); F-123 emits OTel-conformant local spans that any Foundry
  collector can ingest if the user opts in.
  Per-token granularity inside a single completion (token-by-token spans) — out for v1;
  F-123 emits one span per provider call with cumulative token-usage attributes.
  Cost dashboards / per-span cost rollup UI — M12 visualization concern (F-093..F-095);
  cost ledger is F-019.
  Live in-app trace viewer / waterfall UI — M12 visualization concern.
confidence: high
---

# F-123 — OpenTelemetry GenAI semantic-convention spans

## Behavior contract

The engine MUST emit per-LLM-call spans conforming to the OpenTelemetry GenAI semantic
conventions (`gen_ai.*` attribute namespace) for every backend provider invocation
(Anthropic, Copilot, future providers). Spans are written through the F-110 local
telemetry sink (no separate OTel SDK pipeline; spans share the JSONL file) and carry
the canonical `gen_ai.system` (`anthropic` | `copilot` | provider name),
`gen_ai.request.model` (e.g. `claude-opus-4-7`), `gen_ai.request.temperature`,
`gen_ai.request.max_tokens`, `gen_ai.response.id`, `gen_ai.response.model`,
`gen_ai.response.finish_reasons`, `gen_ai.usage.input_tokens`,
`gen_ai.usage.output_tokens`, and `gen_ai.usage.total_tokens` attributes. Span
`operation_name` MUST follow the OTel GenAI convention (`chat <model>` for chat
completions; `text_completion <model>` for completion APIs). Each span is a child of the
engine-cycle span (per F-112) so the F-110 trace tree shows engine-cycle → orchestration
→ LLM-call. Tool-use within a chat completion emits a child span per tool invocation
with `gen_ai.tool.name` and `gen_ai.tool.call.id` attributes, chained from the parent
LLM-call span. The engine MUST NOT invent sampling caps / budgets / quotas (per
`rules/no-invented-constraints.md`); every span is emitted unless the user explicitly
configures sampling.

## Acceptance scenarios

1. **Given** the engine in `local-only` telemetry mode (per F-113) and a single
   Anthropic SDK chat completion call with a 200-token prompt + 150-token response,
   **When** the call completes, **Then** the F-110 OTel JSONL file contains exactly one
   span with `gen_ai.system: "anthropic"`, `gen_ai.request.model` matching the request,
   `gen_ai.usage.input_tokens: 200`, `gen_ai.usage.output_tokens: 150`,
   `gen_ai.usage.total_tokens: 350`, and `operation_name: "chat <model>"`.
2. **Given** an LLM call that invokes 2 tools mid-completion via tool_use events
   (normalized per F-013), **When** the completion finishes, **Then** the trace tree
   shows: 1 parent `chat` span + 2 child spans each with `gen_ai.tool.name` set to the
   invoked tool's name and `gen_ai.tool.call.id` matching the provider's tool_use_id;
   `parent_span_id` on each child correctly references the parent chat span's
   `span_id`.
3. **Given** an LLM call that fails mid-stream with a provider-emitted error, **When**
   the mapper (per F-013) yields the `error` event, **Then** the span is closed with
   `status.code: ERROR`, `status.description` containing the provider error code,
   `gen_ai.response.finish_reasons: ["error"]`, and partial token-usage attributes set
   from whatever the provider reported before the failure.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/telemetry/otel-genai-chat-span.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/telemetry/otel-genai-tool-use-children.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/telemetry/otel-genai-error-status.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-110 (local OTel sink writes the spans), F-112 (engine-cycle parent span),
  F-002 (session_id + run_id resource attrs), F-013 (event normalization yields the
  per-call lifecycle hooks the span consumes)
- **Soft:** F-019 (cost ledger consumes `gen_ai.usage.*` attributes for per-call cost
  rollup), F-018 (PII redaction runs on prompt/response bodies before they hit the
  span attributes — sensitive prompt content stays redacted in the trace)
- **Independent:** F-093..F-095 (M12 visualization is downstream; F-123 produces the
  data; M12 renders it)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan.md F-123 | reserved F-NNN allocation; M16 placement; "[R:msft-learn Foundry observability]" provenance |
| docs/06-agent-team-outputs/wave-001/lane-b-summary.md finding 16 | OTel GenAI semantic conventions identified as 2026 frontier observability standard |
| kit:rules/lens-telemetry-pattern | LENS structured-event shape; informs OTel record naming + cross-LENS observability conventions |
| kit:rules/no-invented-constraints.md | no sampling caps without explicit user config; every span is emitted by default |
| kit:rules/single-owner-accountability.md | session_id resource attribute on every span; spans trace to the engine's accountable identity |

## Implementation notes

(empty — populated when implementation begins)
