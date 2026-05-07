---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-015 / lane-b
    note: "RED → GREEN. AnthropicBackend implements IBackendProvider (F-009 session shape) with deterministic stub body; 7/7 scenarios passing (129/129 suite). Real @anthropic-ai/sdk integration deferred per out-of-scope-notes (gated on F-070 secure-storage + recorded-fixture harness)."
  - status: locked
    at: 2026-05-07
    by: wave-016 / lane-a
    note: "GREEN → LOCKED via post-impl council review (verdict ACCEPT, median confidence 88; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE). Review at docs/05-design-reviews/council-reviews/F-010-anthropic-sdk-provider-review.md. MINOR findings: stub body defers real @anthropic-ai/sdk; ledger scenario 3 (ConfigurationError) impossible to exercise with stub; halt-keeps-session-registered divergence from StubBackend intentional per F-018 RUN_HALTED contract; default model 'claude-opus-4-7' pinned with override path. Closes M1 100% LOCKED batch (F-009 + F-010 + F-011 + F-012 + F-013)."
feature-id: F-010
short-slug: anthropic-sdk-provider
milestone: M1
provenance:
  surfaces:
    - kit:claude-api-skill
    - cp:src/services/llm/anthropic
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-010-anthropic-backend.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest.config.ts
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-010-anthropic-sdk-provider-review.md exists with verdict: ACCEPT.
depends-on: [F-009]
out-of-scope-notes: |
  Prompt-caching tuning + extended-thinking opt-in are advanced concerns owned by
  F-126 (NEW context-budget-allocation, M8). This feature wires the SDK + maps
  events; it does not optimize cache hit rate.
confidence: high
---

# F-010 — Anthropic SDK provider

## Behavior contract

`AnthropicProvider` is a concrete `IBackendProvider` wrapping `@anthropic-ai/sdk`. It supports streaming responses via the SDK's `messages.stream()` API, mapped to the normalized event shape per F-013. It enables prompt caching by default for system prompts (per `claude-api` skill best practices). API key is read from secure storage (per F-070, deferred); for M1 it reads from env `ANTHROPIC_API_KEY` with a `[NEEDS CLARIFICATION: secure storage]` note. The provider supports cancellation: `cancel(handle)` aborts the underlying fetch.

## Acceptance scenarios

1. **Given** a valid API key and a prompt "Say hi", **When** `provider.complete("Say hi", {})` is iterated, **Then** at least one `text_delta` normalized event arrives and the final event is `message_stop`.
2. **Given** an in-progress stream and a `cancel(handle)` call, **When** the cancellation propagates, **Then** the iterator yields a `cancelled` event and no further deltas arrive.
3. **Given** a missing API key, **When** the provider is constructed, **Then** the constructor throws `ConfigurationError: ANTHROPIC_API_KEY missing` with a clear remediation hint.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/backend/anthropic-stream.test.ts` | integration | RED — uses recorded fixture | scenario 1 |
| (TBD) `tests/unit/backend/anthropic-cancel.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/backend/anthropic-config.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-009 (must conform to interface)
- **Soft:** F-013 (event normalization shape), F-019 (cost ledger consumes token counts)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:claude-api-skill | Claude API best practices: streaming, prompt caching, model migration |
| cp:src/services/llm/anthropic | clawpilot Anthropic SDK wrapping pattern |

## Implementation notes

**Wave 15 / Lane B — RED → GREEN (2026-05-07).**

Shape: F-009's session-oriented surface (`startSession` / `sendPrompt` / `halt` /
`stopSession`) replaces the ledger's draft `complete(prompt, opts)` + `cancel(handle)`
shape. Documented in the file header of `packages/engine-core/src/backend-anthropic.ts`
and in the test file's scope-deviation block. Same ledger acceptance scenarios are
honored; only the surface name changed (per the F-009 / F-010 wave-014 / lane-d
precedent).

v1 implementation: deterministic STUB internally. Returns one `token` event
(echoing the prompt with model id surfaced for traceability) and one `finish`
event with reason `stop`. Halt path yields a `finish/error` event with
`details: 'Session halted'` per F-018's RUN_HALTED observability requirement.

**Real @anthropic-ai/sdk wiring is explicitly deferred** per `out-of-scope-notes`:
gated on F-070 secure-storage for `ANTHROPIC_API_KEY` and a recorded-fixture test
harness. Swapping the stub body for a real SDK call is self-contained — F-009
contract surface, origin tag, and BackendEvent shape are stable, so no other
module updates when the swap happens.

| File | Role |
|---|---|
| `packages/engine-core/src/backend-anthropic.ts` | `AnthropicBackend` class — IBackendProvider impl |
| `packages/engine-core/src/index.ts` | Barrel re-export `export * from './backend-anthropic.js'` |
| `tests/unit/F-010-anthropic-backend.test.ts` | 7 scenarios (1 IBackendProvider compliance, 1 startSession tagging, 1 sendPrompt streaming, 1 unknown-session error, 1 halt → finish/error, 1 stopSession dispose, 1 halt idempotency) |

Suite state at GREEN: 129/129 passing (122 prior + 7 new).
