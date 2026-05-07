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
feature-id: F-009
short-slug: ibackendprovider
milestone: M1
provenance:
  surfaces:
    - kit:foundational-plan.md "G7 Both Anthropic+Copilot SDK pluggable"
    - cp:src/services/llm
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
  LOCKED if GREEN AND reviews/F-009-ibackendprovider-review.md exists with verdict: ACCEPT.
depends-on: [F-001]
out-of-scope-notes: |
  Multi-tier routing across Haiku/Sonnet/Opus is tracked under F-124 (NEW frontier-research candidate)
  in M1's later wave. This feature defines the abstraction shape only.
confidence: high
---

# F-009 — IBackendProvider abstraction

## Behavior contract

`IBackendProvider` is a TypeScript interface defining a uniform shape for every LLM backend: methods `complete(prompt, opts) → AsyncIterable<NormalizedEvent>`, `cancel(handle)`, `listModels() → ModelInfo[]`, and `name: BackendName`. Every concrete backend (Anthropic SDK per F-010, Copilot SDK per F-011) implements this interface unchanged. Engine code never imports a concrete SDK directly — it imports `IBackendProvider` and receives the implementation via the factory (F-012).

## Acceptance scenarios

1. **Given** a mock `IBackendProvider` implementation, **When** engine code calls `provider.complete("hello", {})`, **Then** the mock's stream is consumed and the engine treats events identically regardless of which provider it is.
2. **Given** a concrete provider that throws on `complete`, **When** engine code awaits the iteration, **Then** the error surfaces through the iterator's reject path, not as a silent swallow.
3. **Given** the interface declaration, **When** TypeScript checks a class that omits any required method, **Then** the compile fails with TS2420 or TS2741.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/backend/interface-contract.test.ts` | unit | RED | scenarios 1, 3 |
| (TBD) `tests/unit/backend/error-propagation.test.ts` | unit | RED | scenario 2 |

## Dependencies

- **Hard:** F-001 (engine uses providers within cycles)
- **Soft:** F-013 (event normalization defines the iterator shape)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md G7 | "Both Anthropic SDK + GitHub Copilot SDK pluggable behind IBackendProvider" |
| cp:src/services/llm | clawpilot LLM service abstraction pattern |

## Implementation notes

(empty — populated when implementation begins)
