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
feature-id: F-013
short-slug: event-normalization
milestone: M1
provenance:
  surfaces:
    - kit:foundational-plan.md "event normalization"
    - ce:events.md (12 numbered event types)
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

(empty — populated when implementation begins)
