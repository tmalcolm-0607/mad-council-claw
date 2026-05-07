---
artifact-class: physical-proof
generated-by: hand-authored (wave-015 / lane-d)
feature-id: F-013
status: green
date: 2026-05-07
---

# F-013 — Backend event normalization — physical proof

## RED capture (pre-impl)

Test author: `tests/unit/F-013-backend-event-normalization.test.ts` (9
scenarios across 4 type-guard + 4 content-extractor + 1 cross-provider
witness) authored BEFORE `packages/engine-core/src/backend-events.ts`.
Captured failure mode:

```
TypeError: isTokenEvent is not a function
TypeError: eventTextContent is not a function
(15 of 15 failing across F-012 + F-013 — combined RED capture)

Test Files  2 failed (2)
     Tests  15 failed (15)
```

Full RED output: [`red-test-output.txt`](red-test-output.txt). All 9 F-013
scenarios failed at the import boundary because the helper symbols didn't
exist yet.

## GREEN capture (post-impl)

After authoring `packages/engine-core/src/backend-events.ts` (~95 LOC) and
adding `export * from './backend-events.js';` to the barrel:

```
✓ tests/unit/F-012-backend-factory.test.ts (6 tests) 6ms
✓ tests/unit/F-013-backend-event-normalization.test.ts (9 tests) 9ms

Test Files  2 passed (2)
     Tests  15 passed (15)
```

Full GREEN output: [`green-test-output.txt`](green-test-output.txt).

## Acceptance scenarios — coverage map

| # | Scenario | Test name | Status |
|---|---|---|---|
| 1a | isTokenEvent narrows correctly | scenario 1a | PASS |
| 1b | isToolCallEvent narrows correctly | scenario 1b | PASS |
| 1c | isToolResultEvent narrows correctly | scenario 1c | PASS |
| 1d | isFinishEvent narrows correctly | scenario 1d | PASS |
| 2 | eventTextContent returns text verbatim for token events | scenario 2 | PASS |
| 3 | eventTextContent returns deterministic descriptor for tool_call | scenario 3 | PASS |
| 4 | eventTextContent returns deterministic descriptor for tool_result | scenario 4 | PASS |
| 5 | eventTextContent descriptor for finish includes reason + optional details | scenario 5 | PASS |
| 6 | cross-provider events from StubBackend, AnthropicBackend, CopilotBackend all match the same BackendEvent shape and pass the same type guards | scenario 6 | PASS |

## Full-suite regression check

After F-013 + F-012 GREEN, full repo test suite:

```
Test Files  22 passed (22)
     Tests  151 passed (151)
```

All 136 prior tests + 6 F-012 + 9 F-013 = 151 PASS. No regressions.

## Source locations

- Implementation: `packages/engine-core/src/backend-events.ts` (~95 LOC
  including doc-comments).
- Barrel re-export: `packages/engine-core/src/index.ts` (added 1 line +
  ownership-table comment).
- Test: `tests/unit/F-013-backend-event-normalization.test.ts` (~165 LOC
  including doc-comment).

## Scope deviation note

Per the wave-015 / lane-d brief and the wave-014 / lane-d F-009 precedent:
the F-013 ledger originally named the union `NormalizedEvent` with 9
variants (`message_start`, `text_delta`, `tool_use_start`,
`tool_use_input_delta`, `tool_use_stop`, `message_stop`, `usage`,
`cancelled`, `error`). The wave-014 / lane-d F-009 implementation already
settled on a smaller `BackendEvent` union (`token` | `tool_call` |
`tool_result` | `finish`) that every concrete backend (F-010
AnthropicBackend, F-011 CopilotBackend, StubBackend) emits identically.

The ledger's "cross-SDK normalization" goal is therefore SATISFIED by
F-009's union — F-013's contribution is the convenience layer (4 type
guards + `eventTextContent`) so downstream consumers (F-014 retro, F-015
audit, F-019 cost-ledger) don't re-implement the discriminated-union
narrowing.

The 5 ledger variants the v1 union lacks (`message_start`,
`tool_use_input_delta`, `usage`, `cancelled`, `error`) are tracked for the
future provider-event-richness wave per `no-silent-deferrals.md`. v1
covers the four event classes that matter for the M2 governance triad's
observability requirements (token stream, tool dispatch, tool result,
terminal state). `error` is partially covered by `{type:'finish',
reason:'error', details}` — F-018 RUN_HALTED observability surfaces here.

The divergence is recorded in the ledger §Implementation notes. Future
SDK-specific event mapping (Anthropic `content_block_delta` → `token`,
Copilot CLI line-buffered output → `token`) lives alongside each backend's
real-impl swap and is gated on F-070 secure-storage; the normalization
CONTRACT (the union shape itself) lives in `backend.ts` and is unchanged
by that future swap.
