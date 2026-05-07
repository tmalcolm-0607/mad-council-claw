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
    by: wave-014 / lane-d
    note: "RED → GREEN: tests/unit/F-009-ibackend-provider.test.ts (6 scenarios) + packages/engine-core/src/backend.ts (~190 LOC: IBackendProvider interface + BackendEvent discriminated union + BackendSessionConfig + StubBackend); barrel export added. 6/6 PASS; full suite 122/122 PASS. First M1 (backend pluggability) feature flipped; first feature in repo using session-oriented backend shape (startSession/sendPrompt/halt/stopSession) per wave-014 brief — generalizes ledger's iterator-of-events pattern and composes with F-018 RunHaltedVerdict. Scope deviation from ledger's complete()/cancel()/listModels() shape recorded openly in §Implementation notes per no-silent-deferrals.md."
  - status: locked
    at: 2026-05-07
    by: wave-015 / lane-a
    note: "Post-impl council review verdict ACCEPT (median confidence 89; advocate 91 / skeptic 76 / architect 89; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE). MINOR findings: concrete providers F-010/F-011 + factory F-012 + event-normalization F-013 remain RED; scope deviation from original ledger recorded openly; origin: string vs typed union design choice; additive union extension path. Review at docs/05-design-reviews/council-reviews/F-009-ibackendprovider-review.md. **First M1 (backend pluggability) feature LOCKED.**"
feature-id: F-009
short-slug: ibackendprovider
milestone: M1
provenance:
  surfaces:
    - kit:foundational-plan.md "G7 Both Anthropic+Copilot SDK pluggable"
    - cp:src/services/llm
fr-coverage: []
test-files:
  unit: ["tests/unit/F-009-ibackend-provider.test.ts"]
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: ["tests/unit"]
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

`IBackendProvider` is a TypeScript interface defining a uniform shape for every LLM backend. Engine code never imports a concrete SDK directly — it imports `IBackendProvider` and receives the implementation via the factory (F-012). Concrete backends (Anthropic per F-010, Copilot per F-011) implement this interface unchanged.

The v1 surface (per the wave-014 / lane-d implementation; see §Implementation notes for divergence from the original wave-002 spec):

| Member | Shape | Purpose |
|---|---|---|
| `origin: string` | readonly | Backend identifier (`"anthropic"` / `"copilot"` / `"stub"` / `"gateway"`); drives F-012 factory routing and observability tagging |
| `startSession(config)` | `(config: BackendSessionConfig) => Promise<{ sessionId: string }>` | Open a session with F-002 identity (Agent + Session) composed in; returns opaque `sessionId` for subsequent calls |
| `sendPrompt(sessionId, prompt)` | `(sessionId: string, prompt: string) => AsyncGenerator<BackendEvent>` | Stream events back; throws on unknown sessionId or transport failure |
| `halt(sessionId, verdict)` | `(sessionId: string, verdict: RunHaltedVerdict) => Promise<void>` | Cooperative cancel with F-018's verdict shape so providers can route cleanup by trigger; idempotent on already-stopped |
| `stopSession(sessionId)` | `(sessionId: string) => Promise<void>` | Graceful shutdown; idempotent on already-stopped |

`BackendEvent` is the discriminated union streamed by `sendPrompt`:

```typescript
type BackendEvent =
  | { type: 'token'; text: string }
  | { type: 'tool_call'; name: string; arguments: Record<string, unknown> }
  | { type: 'tool_result'; name: string; result: unknown }
  | { type: 'finish'; reason: 'stop' | 'length' | 'tool' | 'error'; details?: string };
```

## Acceptance scenarios

1. **Given** a mock `IBackendProvider` implementation, **When** engine code calls `provider.sendPrompt(sessionId, "hello")`, **Then** the stream is consumed and the engine treats events identically regardless of which provider it is. *(GREEN: scenario 3 — StubBackend yields `token` then `finish`; iterator-of-events shape is uniform across future Anthropic / Copilot providers.)*
2. **Given** a concrete provider whose `sendPrompt` is given an unknown sessionId, **When** engine code awaits the iteration, **Then** the error surfaces through the iterator's reject path, not as a silent swallow. *(GREEN: scenario 4 — `Unknown session: <id>` propagates from the AsyncGenerator.)*
3. **Given** the interface declaration, **When** TypeScript checks a class that omits any required method, **Then** the compile fails with TS2420 or TS2741. *(GREEN: scenario 1 — structural witness; runtime shape check confirms the bundle preserves the interface; type-system enforcement is fail-fast at compile.)*

## Red→green wire-up

| Test file | Project | Initial state | Final state | Verifies |
|---|---|---|---|---|
| `tests/unit/F-009-ibackend-provider.test.ts` | unit | RED (StubBackend not a constructor) | GREEN (6/6 PASS) | scenarios 1, 2, 3, 4, 5, 6 |

RED capture: [`docs/09-examples-proof/F-009/red-test-output.txt`](../../09-examples-proof/F-009/red-test-output.txt) (6/6 fail with `TypeError: StubBackend is not a constructor`).

GREEN capture: [`docs/09-examples-proof/F-009/green-test-output.txt`](../../09-examples-proof/F-009/green-test-output.txt) (6/6 PASS in 10ms).

## Dependencies

- **Hard:** F-001 (engine uses providers within cycles), F-002 (Agent + Session identity composed into `BackendSessionConfig`), F-018 (`RunHaltedVerdict` consumed by `halt`).
- **Soft:** F-013 (event normalization will define the canonical mapping from provider-specific events into `BackendEvent`).
- **Independent:** n/a.

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md G7 | "Both Anthropic SDK + GitHub Copilot SDK pluggable behind IBackendProvider" |
| cp:src/services/llm | clawpilot LLM service abstraction pattern |

## Implementation notes

**Source locations**:
- `packages/engine-core/src/backend.ts` — interface + types + StubBackend (~190 LOC).
- `packages/engine-core/src/index.ts` — barrel re-export.
- `tests/unit/F-009-ibackend-provider.test.ts` — 6 scenarios.

**Scope deviation from original ledger** (intentional, recorded per `no-silent-deferrals.md`):

The wave-002 / lane-b ledger named a `complete(prompt, opts) → AsyncIterable<NormalizedEvent>` shape paired with `cancel(handle)`, `listModels() → ModelInfo[]`, and `name: BackendName`. The wave-014 / lane-d implementation uses a session-oriented surface (`startSession` / `sendPrompt` / `halt` / `stopSession`) carrying a discriminated `BackendEvent` union.

Why the session shape is the right v1:
- `sendPrompt` returns `AsyncGenerator<BackendEvent>` — the iterator-of-events pattern from the original ledger is preserved.
- `halt` accepts a `RunHaltedVerdict` — composes cleanly with F-018's halt verdict shape so the M2 governance triad's `RUN_HALTED` contract is observable across backends.
- `origin: string` replaces the original `name: BackendName` (string instead of bespoke union, so adding new providers doesn't require a type-system change).
- `listModels()` is deferred — F-012 (factory) handles routing; per-provider model enumeration is provider-specific surface area we'd rather not standardize prematurely.
- `cancel(handle)` is replaced by `halt(sessionId, verdict)` + `stopSession(sessionId)` — the split distinguishes "trigger fired, halting" (carries verdict) from "we're done" (no verdict).

The three original ledger acceptance scenarios are honored by the new shape (see §Acceptance scenarios above).

**Composition with sibling features**:
- F-002 identity: `BackendSessionConfig` requires `agent: Agent` + `session: Session`; the runId / agentId thread through every started session for downstream F-014 (retro), F-015 (audit), F-019 (cost) consumption.
- F-018 halt: `halt(sessionId, verdict: RunHaltedVerdict)` accepts the canonical halt verdict from F-018's HaltDetector. When F-020 (kill-switch) / F-022 (tool-quota) / F-018 (overplanning) triggers fire, the verdict flows through to the provider so cleanup can be routed by trigger.

**StubBackend** is the deterministic test fixture: `origin === "stub"`, `sendPrompt` yields `{ type: 'token', text: 'STUB-RESPONSE-TO: <prompt>' }` then `{ type: 'finish', reason: 'stop' }`, `halt` and `stopSession` are idempotent. Used by F-009's own tests, future F-012 factory tests (origin routing), and future F-018 / F-020 / F-022 halt-integration tests.

**Out-of-scope (deferred per ledger §out-of-scope-notes + this implementation)**:
- F-010 AnthropicBackend wiring (real Anthropic SDK call) — separate feature, separate file.
- F-011 CopilotBackend wiring (real Copilot SDK call) — separate feature, separate file.
- F-012 backend-factory (`origin → IBackendProvider` routing) — separate feature.
- F-013 event-normalization (cross-provider mapping into the canonical `BackendEvent` union) — F-009 defines the union; F-013 wires concrete providers into it.
- F-124 multi-tier model routing (Haiku / Sonnet / Opus) — frontier-research candidate, M1 later wave.
- Audit-writer integration (F-002 stamping on emitted events) — F-002 ledger explicitly puts identity-stamping at the audit-writer boundary, not at provider event emission.

**Council review**: pending — per `red-green-rule` predicate, LOCKED requires
`reviews/F-009-ibackendprovider-review.md` with verdict ACCEPT. Wave-014 / lane-d
flips RED → GREEN; LOCKED is a follow-up wave.
