---
artifact-class: physical-proof
generated-by: hand-authored (wave-015 / lane-d)
feature-id: F-012
status: green
date: 2026-05-07
---

# F-012 — Backend factory — physical proof

## RED capture (pre-impl)

Test author: `tests/unit/F-012-backend-factory.test.ts` (6 scenarios) authored
BEFORE `packages/engine-core/src/backend-factory.ts`. Captured failure mode:

```
TypeError: createBackend is not a function
(15 of 15 failing across F-012 + F-013 — combined RED capture)

Test Files  2 failed (2)
     Tests  15 failed (15)
```

Full RED output: [`red-test-output.txt`](red-test-output.txt). All 6 F-012
scenarios failed at the import boundary because `createBackend`,
`BackendKind`, and the helper symbols didn't exist yet.

## GREEN capture (post-impl)

After authoring `packages/engine-core/src/backend-factory.ts` (~95 LOC) and
adding `export * from './backend-factory.js';` to the barrel:

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
| 1 | createBackend({kind:'anthropic'}) returns AnthropicBackend with origin='anthropic' | scenario 1 | PASS |
| 2 | createBackend({kind:'copilot'}) returns CopilotBackend with origin='copilot' | scenario 2 | PASS |
| 3 | createBackend({kind:'stub'}) returns StubBackend with origin='stub' | scenario 3 | PASS |
| 4 | createBackend on an unknown kind throws at runtime (`Error('Unknown backend kind: ...')`) | scenario 4 | PASS |
| 5 | factory forwards `model` parameter to anthropic + copilot constructors | scenario 5 | PASS |
| 6 | factory return type is exactly IBackendProvider (interface contract preserved across all kinds) | scenario 6 | PASS |

## Full-suite regression check

After F-012 + F-013 GREEN, full repo test suite:

```
Test Files  22 passed (22)
     Tests  151 passed (151)
```

All 136 prior tests + 6 F-012 + 9 F-013 = 151 PASS. No regressions.

## Source locations

- Implementation: `packages/engine-core/src/backend-factory.ts` (~95 LOC
  including doc-comments).
- Barrel re-export: `packages/engine-core/src/index.ts` (added 1 line +
  ownership-table comment).
- Test: `tests/unit/F-012-backend-factory.test.ts` (~110 LOC including
  doc-comment).

## Scope deviation note

Per the wave-015 / lane-d brief and the wave-014 / lane-d F-009 precedent
(FETCH BEFORE CITE: honor authoritative ledger over brief, but record
divergences openly): the F-012 ledger originally named the function
`createBackendProvider(name, opts)` with a `MAD_BACKEND` env-var override
and a custom `BackendNotRegistered` exception. The implementation here uses
`createBackend({kind, model})` — env-var resolution is moved up to the
caller (or a future settings layer per F-067, M8) and the
`BackendNotRegistered` semantic is realized through TypeScript's
exhaustive-switch `never`-arm pattern (compile-time check + runtime
`Error('Unknown backend kind: ...')`).

Why the simplified shape is acceptable:

1. The factory contract surface is unchanged: kind in → IBackendProvider
   out. The same three concrete backends (anthropic, copilot, stub) are
   reachable; the ledger's "single supported way" mandate is preserved.
2. Pure-function shape (no I/O) makes the factory deterministic and
   testable in isolation. Settings-layer resolution can be tested
   separately when F-067 lands.
3. Exhaustive-switch witness is a stronger compile-time check than a
   runtime registry lookup: adding a new BackendKind without adding a
   matching `case` is a TS2322 error, not a runtime regression.

The divergence is recorded in the ledger §Implementation notes per
`no-silent-deferrals.md`. Multi-tier model routing (F-124 — frontier-
research candidate, M1 later wave) plugs into this factory by extending
`BackendKind` and adding routing predicates above the factory call site.
