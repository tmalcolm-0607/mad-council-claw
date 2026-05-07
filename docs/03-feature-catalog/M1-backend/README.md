---
artifact-class: milestone-overview
generated-by: hand-authored (wave-002 / lane-b)
status: red
milestone: M1
short-slug: backend
features: F-009..F-013
authored: 2026-05-07
---

# M1 — Pluggable backend abstraction

Goal G7 (`foundational-plan.md`): "Both Anthropic SDK + GitHub Copilot SDK pluggable behind `IBackendProvider`." M1 makes the engine backend-agnostic — engine-core never imports a concrete SDK directly.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-009 | ibackendprovider | TypeScript interface every backend implements: `complete()`, `cancel()`, `listModels()`, `name` |
| F-010 | anthropic-sdk-provider | Concrete `IBackendProvider` wrapping `@anthropic-ai/sdk`, prompt-caching enabled, cancellation support |
| F-011 | copilot-sdk-provider | Concrete `IBackendProvider` wrapping the GitHub Copilot CLI/SDK, model selection, child-process cancel |
| F-012 | backend-factory | `createBackendProvider(name, opts)` — single entry point; env-var override; engine-core forbidden from direct SDK import |
| F-013 | event-normalization | `NormalizedEvent` discriminated union: every backend's native stream maps to the same shape |

## Dependency DAG

```
F-001 (engine kernel from M0) ──→ F-009 (interface) ──→ F-013 (event shape)
                                       │
                                       ├──→ F-010 (anthropic)
                                       └──→ F-011 (copilot)
                                                │
                                                ▼
                                          F-012 (factory) — depends on all 3
```

## Milestone exit criteria

- All 5 ledgers GREEN
- `createBackendProvider("anthropic", {})` and `createBackendProvider("copilot", {})` both produce a working provider
- Recorded-fixture integration tests for both providers pass (no live API calls in CI)
- Switching backends in run config does not require touching any engine-core code

## Frontier-research follow-ups (NEW F-NNN candidates per `foundational-plan.md` § True Synthesis)

These extend M1 in subsequent waves; not included in the M1 exit criteria:
- F-124 — multi-tier-routing (Haiku for cheap calls, Opus for hard reasoning)

## Out of scope (tracked elsewhere)

- M10 multi-model adversarial dispatch (`--council` mode) — F-082..F-087
- M9 MSAL/WAM auth + WorkIQ adapter — F-076..F-081
- M8 encrypted storage of API keys — F-070..F-071

## Provenance

`kit:claude-api-skill`, `kit:lens-multi-model-review-pattern.md`, `cp:src/services/llm/*`. See per-ledger `provenance.surfaces`.
