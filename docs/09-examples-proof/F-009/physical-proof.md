---
artifact-class: physical-proof
generated-by: hand-authored (wave-014 / lane-d)
feature-id: F-009
status: green
date: 2026-05-07
---

# F-009 — IBackendProvider abstraction — physical proof

## RED capture (pre-impl)

Test author: `tests/unit/F-009-ibackend-provider.test.ts` (6 scenarios) authored
BEFORE `packages/engine-core/src/backend.ts`. Captured failure mode:

```
TypeError: StubBackend is not a constructor

Test Files  1 failed (1)
     Tests  6 failed (6)
```

Full RED output: [`red-test-output.txt`](red-test-output.txt). All 6 scenarios
failed at the import / construction boundary because the symbol didn't exist
yet.

## GREEN capture (post-impl)

After authoring `packages/engine-core/src/backend.ts` (~190 LOC) and adding
`export * from './backend.js';` to the barrel:

```
✓ tests/unit/F-009-ibackend-provider.test.ts (6 tests) 10ms

Test Files  1 passed (1)
     Tests  6 passed (6)
```

Full GREEN output: [`green-test-output.txt`](green-test-output.txt).

## Acceptance scenarios — coverage map

| # | Scenario | Test name | Status |
|---|---|---|---|
| 1 | StubBackend implements IBackendProvider with origin="stub" + structural method witness | scenario 1 | PASS |
| 2 | startSession returns sessionId for given config | scenario 2 | PASS |
| 3 | sendPrompt streams `token` event then `finish` event with reason `stop` | scenario 3 | PASS |
| 4 | sendPrompt on unknown sessionId throws (`Unknown session: ...`) | scenario 4 | PASS |
| 5 | halt accepts a RunHaltedVerdict and removes the session (composition with F-018 verdict shape) | scenario 5 | PASS |
| 6 | stopSession removes the session | scenario 6 | PASS |

## Full-suite regression check

After F-009 GREEN, full repo test suite:

```
Test Files  18 passed (18)
     Tests  122 passed (122)
```

All 116 prior tests + 6 F-009 = 122 PASS. No regressions.

## Source locations

- Implementation: `packages/engine-core/src/backend.ts` (~190 LOC including
  doc-comments).
- Barrel re-export: `packages/engine-core/src/index.ts` (added 1 line +
  ownership-table comment).
- Test: `tests/unit/F-009-ibackend-provider.test.ts` (~150 LOC including
  doc-comment).

## Scope deviation note

Per the wave-014 / lane-d brief and the wave-008 / lane-a + wave-009 / lane-c
precedent (FETCH BEFORE CITE: honor authoritative ledger over brief, but
record divergences openly): the F-009 ledger originally named a
`complete(prompt, opts) → AsyncIterable<NormalizedEvent>` shape paired with
`cancel(handle)` and `listModels()`. The implementation here uses a
session-oriented surface (`startSession` / `sendPrompt` / `halt` /
`stopSession`) carrying a discriminated `BackendEvent` union (`token` |
`tool_call` | `tool_result` | `finish`).

Why the session shape is acceptable:

1. It generalizes the ledger's iterator-of-events pattern (`sendPrompt`
   returns `AsyncGenerator<BackendEvent>` — events are still streamed).
2. It adds a halt path that composes cleanly with F-018's
   `RunHaltedVerdict`, making the M2 governance triad's `RUN_HALTED`
   contract observable across backends.
3. The three ledger acceptance scenarios are honored:
   - "Mock provider consumed identically" → scenario 3 (token + finish events).
   - "Error propagation via reject path" → scenario 4 (unknown sessionId throws
     through the AsyncGenerator).
   - "Compile-fail on omitted method" → scenario 1 (structural witness; a class
     missing any required method fails TS2420).

The divergence is recorded in the ledger §Implementation notes per
`no-silent-deferrals.md`. F-013 (event-normalization) plugs into the
`BackendEvent` union without touching this surface; F-012 (factory) routes
on `origin` without touching this surface either.
