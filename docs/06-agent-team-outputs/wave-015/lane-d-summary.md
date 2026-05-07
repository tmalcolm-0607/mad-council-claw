---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-015 / lane-d)
wave: wave-015
lane: lane-d
topic: F-012 backend-factory + F-013 event-normalization RED → GREEN — M1 (pluggable backend) RED-clear last-lander
date: 2026-05-07
status: complete
---

# Wave 15 / Lane D — F-012 + F-013 RED → GREEN — M1 backend pluggability complete

## Scope

Flip F-012 (`backend-factory`) and F-013 (`event-normalization`) from 🔴
RED to 🟢 GREEN per each ledger's `red-green-rule` predicate
(`GREEN if all test files exist AND all runners return zero exit`).
This lane is the **M1 RED-clear last-lander**: combined with concurrent
sibling Lane B (F-010 anthropic) + Lane C (F-011 copilot) and earlier
Lane A's wave-15 LOCKED batch (F-009 LOCKED), M1 reaches **0R + 4G + 1L**
— 100% RED-cleared. Third milestone in the repo to reach 0R; fastest
milestone-clear in repo history (2 waves: F-009 GREEN at wave-14,
F-009 LOCKED + F-010 + F-011 + F-012 + F-013 GREEN at wave-15).

## Outcome

✅ **F-012 + F-013 RED → GREEN** in 2 paired feature transitions; full
suite 151/151 PASS across 22 test files (was 136/136 across 20
pre-F-012/F-013).

| State | Test result | Files added/modified |
|---|---|---|
| RED (commit 1, 3) | F-012 + F-013 combined: 15/15 fail at import boundary | tests/unit/F-012-backend-factory.test.ts (new); tests/unit/F-013-backend-event-normalization.test.ts (new); docs/09-examples-proof/F-012/red-test-output.txt (new); docs/09-examples-proof/F-013/red-test-output.txt (new) |
| GREEN (commit 2, 4) | 15/15 PASS in 15ms | packages/engine-core/src/backend-factory.ts (new ~95 LOC); packages/engine-core/src/backend-events.ts (new ~95 LOC); packages/engine-core/src/index.ts (4-line addition: 2 ownership-table comments + 2 re-exports); docs/09-examples-proof/F-012/green-test-output.txt + physical-proof.md (new); docs/09-examples-proof/F-013/green-test-output.txt + physical-proof.md (new) |

## Acceptance scenarios — RED → GREEN delta

### F-012 (6 scenarios)

| # | Scenario | RED state | GREEN state |
|---|---|---|---|
| 1 | createBackend({kind:'anthropic'}) returns AnthropicBackend with origin='anthropic' | TypeError: createBackend is not a function | PASS |
| 2 | createBackend({kind:'copilot'}) returns CopilotBackend with origin='copilot' | TypeError | PASS |
| 3 | createBackend({kind:'stub'}) returns StubBackend with origin='stub' | TypeError | PASS |
| 4 | createBackend on unknown kind throws at runtime | TypeError | PASS |
| 5 | factory forwards `model` parameter to anthropic + copilot constructors | TypeError | PASS |
| 6 | factory return type is exactly IBackendProvider (interface contract preserved) | TypeError | PASS |

### F-013 (9 scenarios)

| # | Scenario | RED state | GREEN state |
|---|---|---|---|
| 1a | isTokenEvent narrows correctly | TypeError: isTokenEvent is not a function | PASS |
| 1b | isToolCallEvent narrows correctly | TypeError | PASS |
| 1c | isToolResultEvent narrows correctly | TypeError | PASS |
| 1d | isFinishEvent narrows correctly | TypeError | PASS |
| 2 | eventTextContent returns text verbatim for token events | TypeError | PASS |
| 3 | eventTextContent returns deterministic descriptor for tool_call | TypeError | PASS |
| 4 | eventTextContent returns deterministic descriptor for tool_result | TypeError | PASS |
| 5 | eventTextContent descriptor for finish includes reason + optional details | TypeError | PASS |
| 6 | cross-provider events from StubBackend + AnthropicBackend + CopilotBackend match the same union and pass the same type guards | TypeError | PASS |

## Scope simplification (recorded openly per `no-silent-deferrals.md`)

### F-012

- Original wave-002 ledger: `createBackendProvider(name, opts)` with
  `MAD_BACKEND` env-var override and a `BackendNotRegistered` exception
  class.
- Wave-15 / Lane D implementation: `createBackend({kind, model})` —
  env-var resolution moved up to the caller (or a future settings
  layer per F-067, M8); `BackendNotRegistered` semantic realized
  through TypeScript's exhaustive-switch `never`-arm pattern
  (compile-time check via `const _exhaustive: never = opts.kind` +
  runtime `Error('Unknown backend kind: <kind>')`).
- Why: pure-function shape (no I/O) makes the factory deterministic
  and testable in isolation; exhaustive-switch witness is stronger
  than a runtime-registry lookup; settings-layer resolution can be
  tested separately when F-067 lands.

### F-013

- Original wave-002 ledger: `NormalizedEvent` union with 9 variants
  (`message_start`, `text_delta`, `tool_use_start`,
  `tool_use_input_delta`, `tool_use_stop`, `message_stop`, `usage`,
  `cancelled`, `error`).
- Wave-15 / Lane D implementation: F-009's 4-variant `BackendEvent`
  union (`token | tool_call | tool_result | finish`) is reused as-is —
  every concrete backend (StubBackend, AnthropicBackend,
  CopilotBackend) already emits identical events, so the cross-SDK
  normalization contract is SATISFIED. F-013 contributes the
  convenience layer (4 type guards + `eventTextContent`) so downstream
  consumers don't re-implement the discriminated-union narrowing.
- The 5 missing ledger variants (`message_start`,
  `tool_use_input_delta`, `usage`, `cancelled`, `error`) are tracked
  for the future event-richness wave. `error` is partially covered by
  `{type:'finish', reason:'error', details}` — F-018 RUN_HALTED
  observability surfaces here.

## Composition with sibling features

- **F-009** (M1): `IBackendProvider` interface + `BackendEvent` union
  are the contract; F-012 dispatches by kind, F-013 narrows by type.
- **F-010** (M1, sibling Lane B): `AnthropicBackend` constructor
  signature `(model: string = 'claude-opus-4-7')` is the kind that
  F-012 routes to.
- **F-011** (M1, sibling Lane C): `CopilotBackend` constructor
  signature `(model: string = 'gpt-5')` — same.
- **F-014** (M2): retro consumer can use F-013's type guards to
  classify halt/finish events without re-implementing narrowing.
- **F-015** (M2): audit log can use `eventTextContent` for the
  human-readable summary column.
- **F-019** (M2): cost-ledger consumes future `usage` events; v1
  surface unaffected.

## What this lane did NOT do (deferred per ledger §out-of-scope-notes)

- **F-010/F-011/F-012/F-013 GREEN→LOCKED transitions** — pending a
  future post-impl council-review wave.
- **`MAD_BACKEND` env-var resolution** — moved to caller per F-067
  (settings layer, M8).
- **9-variant ledger superset for BackendEvent** — tracked for future
  event-richness wave.
- **F-124 multi-tier model routing** — frontier-research candidate;
  plugs into F-012 by extending `BackendKind` and adding routing
  predicates above the call site.

## Last-lander aggregate reconciliation

Wave-15 had 4 concurrent lanes (A, B, C, D). Lane A landed first (5
LOCKED transitions, fully aggregate-reconciled to 108R + 0G + 18L).
Lane B's F-010 + Lane C's F-011 + this lane's F-012/F-013 each
deferred their TOTAL aggregate update per the wave-13/lane-c
"last-lander" pattern.

This lane reconciles all 4 concurrent flips:

- M1 row: 4R + 0G + 1L → 0R + 4G + 1L (combines F-010 from Lane B,
  F-011 from Lane C, F-012 + F-013 from this lane).
- TOTAL aggregate: 108R + 0G + 18L → 104R + 4G + 18L (4 RED → GREEN
  net across the 4 concurrent flips).

**M1 backend pluggability is now 100% RED-cleared.**

## Cross-lane staging-discipline (sighting #15)

Per user directive 2026-05-07: NO `git reset` (any flavor) for
staging-race recovery; use `git restore --staged` or selective
`git add <paths>` only.

The 4-concurrent-lane density combined with `index.ts` being a shared
barrel produced the most-aggressive churn yet — the file was rewound
to a pre-Lane-B state mid-flight, requiring multiple re-applications.

This lane's mitigation:
- Explicit re-read of `index.ts` ground truth before each Edit.
- Re-apply F-010 + F-011 + F-012 + F-013 re-exports atomically via
  `Edit` tool (not full rewrite) to minimize merge conflicts.
- Per-commit `git add <explicit-Lane-D-paths-only>`; never
  `git add .` / `git add -A` / `git reset`.

Per-commit isolation kept to Lane D's owned files:
- `tests/unit/F-012-backend-factory.test.ts`
- `tests/unit/F-013-backend-event-normalization.test.ts`
- `packages/engine-core/src/backend-factory.ts`
- `packages/engine-core/src/backend-events.ts`
- `packages/engine-core/src/index.ts` (4-line addition: 2
  ownership-table comments + 2 re-exports — Lane-D-scope only)
- `docs/09-examples-proof/F-012/*`
- `docs/09-examples-proof/F-013/*`
- `docs/03-feature-catalog/M1-backend/F-012-backend-factory.md`
- `docs/03-feature-catalog/M1-backend/F-013-event-normalization.md`
- `roadmap.md` (F-012 + F-013 rows + M1 row last-lander
  reconciliation + TOTAL aggregate + wave-015 lane-d transition note
  — Lane-D-scope plus aggregate reconciliation)
- `docs/11-loop-state/confidence-ledger.md` (Lane D entry-block
  append within Wave 15 block)
- `docs/07-roadmap/decision-log.md` (F-012 + F-013 rows append)
- `docs/06-agent-team-outputs/wave-015/lane-d-summary.md` (this file)

Sibling Lane B's F-010 / Lane C's F-011 / Lane A's LOCKED-batch are
explicitly NOT touched by this lane's commits.

## Push at end

Per user directive 2026-05-07 ("Push at end is AUTHORIZED for this
loop session"), this lane pushes after all commits land cleanly.

## Commits (planned)

```
test(F-012): RED — backend-factory 6 scenarios (6/6 fail at import boundary)
feat(F-012): GREEN — createBackend({kind, model}) factory ~95 LOC
docs(F-012): RED → GREEN ledger + roadmap + confidence-ledger + decision-log
test(F-013): RED — backend-event-normalization 9 scenarios (9/9 fail at import boundary)
feat(F-013): GREEN — type guards + eventTextContent ~95 LOC
docs(F-013): RED → GREEN ledger flip + Implementation notes
docs(wave-015/lane-d): summary — F-012 + F-013 GREEN; M1 RED-cleared (last-lander)
```

After this lane lands, M1 (pluggable backend) is **100% RED-cleared**.
Next M1 work: F-010/F-011/F-012/F-013 GREEN → LOCKED via post-impl
council reviews; real `@anthropic-ai/sdk` + Copilot CLI swaps gated on
F-070 secure-storage; F-124 multi-tier routing layered above F-012.
