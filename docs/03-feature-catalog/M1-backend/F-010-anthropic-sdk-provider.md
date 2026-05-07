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
feature-id: F-010
short-slug: anthropic-sdk-provider
milestone: M1
provenance:
  surfaces:
    - kit:claude-api-skill
    - cp:src/services/llm/anthropic
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

(empty — populated when implementation begins)
