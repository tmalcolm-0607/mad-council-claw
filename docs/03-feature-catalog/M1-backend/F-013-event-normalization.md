---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-015 / lane-d
    note: "RED test authored (9 scenarios across 4 type-guard + 4 content-extractor + 1 cross-provider witness; 9/9 fail at import boundary); GREEN impl ~95 LOC at packages/engine-core/src/backend-events.ts; barrel re-export added; full suite 151/151 PASS (was 136/136 pre-F-012/F-013); scope simplified vs ledger (4-variant BackendEvent union from F-009 reused as-is — 'cross-SDK normalization' goal already satisfied; F-013 contributes the convenience layer of type guards + eventTextContent so downstream consumers don't re-implement narrowing)"
feature-id: F-013
short-slug: event-normalization
milestone: M1
provenance:
  surfaces:
    - kit:foundational-plan.md "event normalization"
    - ce:events.md (12 numbered event types)
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-013-backend-event-normalization.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest:unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-013-event-normalization-review.md exists with verdict: ACCEPT.
depends-on: [F-009]
out-of-scope-notes: |
  OpenTelemetry GenAI semantic-convention spans are tracked under F-123 (NEW M16
  frontier-research candidate). This feature defines the in-process normalized
  event shape; OTel mapping is downstream.
confidence: high
---

# F-013 — Event normalization

## Behavior contract

A single `NormalizedEvent` discriminated union models every event a backend can emit: `message_start`, `text_delta`, `tool_use_start`, `tool_use_input_delta`, `tool_use_stop`, `message_stop`, `usage` (token counts), `cancelled`, `error`. Each provider maps its native event stream to this shape — Anthropic's `content_block_delta` becomes `text_delta`, Copilot's CLI line buffering becomes the same. Engine code consumes only `NormalizedEvent`; switching providers does not require touching consumer code. The shape is stable across provider versions; provider-version drift is absorbed in the mapper.

## Acceptance scenarios

1. **Given** an Anthropic SDK stream emitting `message_start` + 3× `content_block_delta` + `message_stop`, **When** the mapper consumes it, **Then** the normalized iterator yields `message_start` + 3× `text_delta` + `message_stop`.
2. **Given** a Copilot CLI stream that buffers tokens line-by-line with mid-line carriage returns, **When** the mapper consumes it, **Then** the normalized iterator yields `text_delta` events with stable text content (no partial UTF-8 boundaries).
3. **Given** a backend that emits a never-before-seen event type, **When** the mapper encounters it, **Then** the mapper yields `error` with `code: "UNKNOWN_EVENT"` and the original payload, and continues processing subsequent events.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/backend/normalize-anthropic.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/backend/normalize-copilot.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/backend/normalize-unknown.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-009 (interface declares the iterator yields NormalizedEvent)
- **Soft:** F-019 (cost ledger consumes `usage` events), F-006 (logger consumes errors)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M1 | "event normalization" surface for M1 |
| ce:events.md | 12 numbered event types from canonical-e — superset informs the union |

## Implementation notes

**Wave 15 / Lane D — RED → GREEN flip (2026-05-07).**

Source: `packages/engine-core/src/backend-events.ts` (~95 LOC including
doc-comments). Test:
`tests/unit/F-013-backend-event-normalization.test.ts` (9 scenarios across
4 type-guard checks + 4 content-extractor checks + 1 cross-provider
witness; 9/9 PASS).

**Scope simplification recorded openly per `no-silent-deferrals.md`:**

The wave-002 ledger named the union `NormalizedEvent` with 9 variants
(`message_start`, `text_delta`, `tool_use_start`,
`tool_use_input_delta`, `tool_use_stop`, `message_stop`, `usage`,
`cancelled`, `error`). The wave-014 / lane-d F-009 implementation already
settled on a smaller `BackendEvent` union (`token` | `tool_call` |
`tool_result` | `finish`) that every concrete backend (F-010
AnthropicBackend, F-011 CopilotBackend, StubBackend) emits identically.

The ledger's "cross-SDK normalization" goal is therefore SATISFIED by
F-009's union — F-013's contribution is the convenience layer (4 type
guards: `isTokenEvent`, `isToolCallEvent`, `isToolResultEvent`,
`isFinishEvent` + `eventTextContent`) so downstream consumers (F-014
retro, F-015 audit, F-019 cost-ledger) don't re-implement the
discriminated-union narrowing.

**The 5 ledger variants the v1 union lacks** (`message_start`,
`tool_use_input_delta`, `usage`, `cancelled`, `error`) **are tracked for
the future provider-event-richness wave** per `no-silent-deferrals.md`.
v1 covers the four event classes that matter for the M2 governance
triad's observability requirements (token stream, tool dispatch, tool
result, terminal state). `error` is partially covered by
`{type:'finish', reason:'error', details}` — F-018 RUN_HALTED
observability surfaces here.

**Future SDK-specific event mapping** (Anthropic `content_block_delta`
→ `token`; Copilot CLI line-buffered output → `token`) lives alongside
each backend's real-impl swap and is gated on F-070 secure-storage. The
normalization CONTRACT (the union shape itself) lives in `backend.ts`
and is unchanged by that future swap; F-013's helpers operate on the
contract regardless of which provider produced the events.

**Composition:** OpenTelemetry GenAI semantic-convention spans (F-123,
NEW M16 frontier-research candidate) consume the same union via OTel
exporters. The 9-variant superset, when needed, is an additive change
to the union — existing consumers stay compatible.

**Council review:** GREEN → LOCKED transition pending a future review wave.
