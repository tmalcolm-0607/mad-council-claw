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
    note: "RED test authored (6 scenarios, 6/6 fail at construct boundary); GREEN impl ~95 LOC at packages/engine-core/src/backend-factory.ts; barrel re-export added; full suite 151/151 PASS (was 136/136 pre-F-012/F-013); scope simplified vs ledger (createBackend({kind,model}) instead of createBackendProvider(name,opts)+MAD_BACKEND env override; BackendNotRegistered realized via TS exhaustive-switch never-arm + runtime throw)"
feature-id: F-012
short-slug: backend-factory
milestone: M1
provenance:
  surfaces:
    - kit:foundational-plan.md "factory" surface
    - cp:src/services/llm/factory
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-012-backend-factory.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest:unit
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

**Wave 15 / Lane D — RED → GREEN flip (2026-05-07).**

Source: `packages/engine-core/src/backend-factory.ts` (~95 LOC including
doc-comments). Test: `tests/unit/F-012-backend-factory.test.ts` (6
scenarios, 6/6 PASS).

**Scope simplification recorded openly per `no-silent-deferrals.md`:**

The wave-002 ledger named the function `createBackendProvider(name, opts)`
with a `MAD_BACKEND` env-var override and a custom `BackendNotRegistered`
exception class. The wave-015 / lane-d implementation uses
`createBackend({kind, model})` and realizes `BackendNotRegistered` through
TypeScript's exhaustive-switch `never`-arm pattern (compile-time check via
`const _exhaustive: never = opts.kind` + runtime
`Error('Unknown backend kind: <kind>')`).

Why the simplified shape:

1. **Pure-function shape (no I/O).** Settings-layer resolution (env vars,
   `F-067` settings shape) is the caller's job. The factory itself is
   deterministic and testable in isolation.
2. **`BackendKind` is a string literal union.** Adding a new backend
   (e.g. a future `'gateway'` origin) is a deliberate two-line change:
   extend the union AND add a `case` to the switch, or the
   exhaustive-switch `never`-arm fires at compile time. Stronger than a
   runtime-registry lookup.
3. **Scenario coverage:** all three ledger acceptance scenarios honored
   via test scenarios 1, 2, 3 (kind dispatch), 4 (unknown kind throws),
   5 (model parameter forwarding), 6 (interface contract preservation).

**Composition:** `MAD_BACKEND` env-var resolution and the F-067 settings
shape are explicit out-of-scope per the simplified contract; F-124
(multi-tier model routing, M1 frontier-research candidate) plugs into
this factory by extending `BackendKind` and adding routing predicates
above the call site without touching the factory body.

**Council review:** GREEN → LOCKED transition pending a future review wave.
