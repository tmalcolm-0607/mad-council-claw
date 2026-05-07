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
feature-id: F-012
short-slug: backend-factory
milestone: M1
provenance:
  surfaces:
    - kit:foundational-plan.md "factory" surface
    - cp:src/services/llm/factory
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
  LOCKED if GREEN AND reviews/F-012-backend-factory-review.md exists with verdict: ACCEPT.
depends-on: [F-009, F-010, F-011]
out-of-scope-notes: |
  Multi-tier routing (route to Haiku for cheap calls, Opus for hard reasoning) is
  tracked under F-124 (NEW M1 frontier-research candidate). This feature handles
  single-provider selection only.
confidence: high
---

# F-012 — Backend factory

## Behavior contract

`createBackendProvider(name, opts)` is a single function that takes a `BackendName` (`"anthropic" | "copilot"`) and returns the matching `IBackendProvider` instance. It reads the active backend selection from settings (per F-067 settings shape, deferred) with env-var override (`MAD_BACKEND`). The factory is the ONLY supported way for engine code to obtain a provider — direct instantiation of `AnthropicProvider` or `CopilotProvider` from engine-core is forbidden (lint rule). On unknown name, throws `BackendNotRegistered`.

## Acceptance scenarios

1. **Given** `createBackendProvider("anthropic", {})`, **When** invoked, **Then** the result satisfies `IBackendProvider` and `result.name === "anthropic"`.
2. **Given** `MAD_BACKEND=copilot` env override and settings configured for anthropic, **When** the factory consults the environment, **Then** the env wins and `result.name === "copilot"`.
3. **Given** `createBackendProvider("ollama", {})`, **When** invoked, **Then** the call throws `BackendNotRegistered: ollama` with a list of supported names in the error message.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/backend/factory-dispatch.test.ts` | unit | RED | scenarios 1, 3 |
| (TBD) `tests/unit/backend/factory-env-override.test.ts` | unit | RED | scenario 2 |

## Dependencies

- **Hard:** F-009 (interface), F-010 (anthropic), F-011 (copilot)
- **Soft:** F-067 (settings shape; deferred to M8)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M1 | "factory" surface enumerated for M1 |
| cp:src/services/llm/factory | clawpilot factory dispatch pattern |

## Implementation notes

(empty — populated when implementation begins)
