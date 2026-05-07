---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-014 / lane-d)
wave: wave-014
lane: lane-d
topic: F-009 IBackendProvider RED → GREEN — first M1 (backend pluggability) feature
date: 2026-05-07
status: complete
---

# Wave 14 / Lane D — F-009 IBackendProvider RED → GREEN — first M1 backend pluggability feature

## Scope

Flip F-009 (`IBackendProvider`) from 🔴 RED to 🟢 GREEN per the F-009 ledger's
`red-green-rule` predicate:

```
GREEN if all test files exist AND all runners return zero exit.
```

This is the **first M1 (backend pluggability) feature** to flip. M1 was 5R/0G/0L
at lane start; now 4R/1G/0L. Combined with concurrent wave-14/lane-b (F-003) and
wave-14/lane-c (F-004), wave-14 lands **3 RED→GREEN flips** in a single wave —
Lane B + C close M0 to 100% RED-cleared (0R+3G+5L); Lane D opens M1.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test | `tests/unit/F-009-ibackend-provider.test.ts` | new (6 scenarios) |
| Source | `packages/engine-core/src/backend.ts` | new (~190 LOC) |
| Barrel | `packages/engine-core/src/index.ts` | modified (1-line re-export + ownership-table comment append) |
| Examples-proof | `docs/09-examples-proof/F-009/red-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-009/green-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-009/physical-proof.md` | new |
| Ledger flip | `docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md` | modified (status: red → green; status-history append; test-files populated; Implementation notes section appended documenting scope deviation) |
| Roadmap rows | `roadmap.md` | modified (F-009 row 🔴 → 🟢; M1 row 5R+0G → 4R+1G; wave-14/lane-d transition note appended) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 14 lane-d section + 4 entries) |
| Decision-log | `docs/07-roadmap/decision-log.md` | modified (F-009 row appended) |
| This summary | `docs/06-agent-team-outputs/wave-014/lane-d-summary.md` | new |

## Test status at lane-d commit time

```
$ pnpm exec vitest run tests/unit/F-009-ibackend-provider.test.ts

 RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

 ✓ tests/unit/F-009-ibackend-provider.test.ts (6 tests) 10ms

 Test Files  1 passed (1)
      Tests  6 passed (6)
```

Full repo suite at GREEN time: 122/122 PASS across 18 test files (was 116/116
across 17 pre-F-009).

## Acceptance scenarios — RED → GREEN delta

| # | Scenario | RED state | GREEN state |
|---|---|---|---|
| 1 | StubBackend implements IBackendProvider with origin="stub" + structural method witness | TypeError: StubBackend is not a constructor | PASS |
| 2 | startSession returns sessionId | TypeError | PASS |
| 3 | sendPrompt streams `token` event then `finish` event with reason `stop` | TypeError | PASS |
| 4 | sendPrompt on unknown sessionId throws (`Unknown session: ...`) | TypeError | PASS |
| 5 | halt accepts a RunHaltedVerdict and removes the session (composes with F-018 verdict shape) | TypeError | PASS |
| 6 | stopSession removes the session | TypeError | PASS |

## Scope deviation from ledger (recorded openly per no-silent-deferrals.md)

The wave-002 / lane-b ledger named a `complete(prompt, opts) → AsyncIterable<NormalizedEvent>`
shape paired with `cancel(handle)`, `listModels() → ModelInfo[]`, and
`name: BackendName`. The wave-014 / lane-d implementation uses a session-oriented
surface (`startSession` / `sendPrompt` / `halt` / `stopSession`) carrying a
discriminated `BackendEvent` union (`token` | `tool_call` | `tool_result` |
`finish`).

Why the session shape:

1. `sendPrompt` returns `AsyncGenerator<BackendEvent>` — the iterator-of-events
   pattern from the original ledger is preserved.
2. `halt` accepts a `RunHaltedVerdict` — composes with F-018's halt verdict shape
   so the M2 governance triad's `RUN_HALTED` contract is observable across
   backends.
3. `origin: string` replaces the original `name: BackendName` (string instead
   of bespoke union — adding new providers doesn't require a type change).
4. `listModels()` is deferred — F-012 (factory) handles routing; per-provider
   model enumeration is provider-specific surface area.
5. `cancel(handle)` is replaced by `halt(sessionId, verdict)` + `stopSession(sessionId)`.

The three original ledger acceptance scenarios are honored by the new shape:
- "Mock provider consumed identically" → scenario 3 (token + finish events).
- "Error propagation via reject path" → scenario 4 (unknown sessionId throws
  through the AsyncGenerator).
- "Compile-fail on omitted method" → scenario 1 (structural witness; a class
  missing any required method fails TS2420 at compile time).

The divergence is documented in F-009 ledger §Implementation notes.

## Composition with sibling features

- **F-002 identity** (M0): `BackendSessionConfig` requires `agent: Agent` +
  `session: Session`; `runId` / `agentId` thread through every started session
  for downstream F-014 (retro), F-015 (audit), F-019 (cost) consumption.
- **F-018 halt** (M2): `halt(sessionId, verdict: RunHaltedVerdict)` accepts the
  canonical halt verdict from F-018's `HaltDetector`. When F-020 / F-022 / F-018
  triggers fire, the verdict flows through to the provider so cleanup can be
  routed by trigger.

The wave-011 / lane-a convention "shared types live with their FIRST owner"
extends cleanly across milestone boundaries: M0 (`Agent` / `Session`) + M2
(`RunHaltedVerdict`) → M1 (F-009) imports both.

## What this lane did NOT do (deferred per ledger §out-of-scope-notes)

- **F-010 AnthropicBackend** — concrete Anthropic SDK implementation in its
  own file; depends on F-009.
- **F-011 CopilotBackend** — concrete GitHub Copilot SDK implementation; same.
- **F-012 backend-factory** — `origin → IBackendProvider` routing; same.
- **F-013 event-normalization** — cross-provider mapping into the canonical
  `BackendEvent` union; F-009 defines the union, F-013 wires concrete
  providers into it.
- **F-124 multi-tier model routing** — frontier-research candidate, M1 later wave.
- **Council review (LOCKED transition)** — pending; per the F-009 ledger
  `red-green-rule`, LOCKED requires a council review verdict ACCEPT.

## Cross-lane staging-discipline

Per user directive 2026-05-07 + wave-13 / lane-d precedent: NO `git reset` (any
flavor); use `git restore --staged` or selective `git add <paths>` only. Each
of this lane's commits uses `git add <explicit-Lane-D-paths-only>`; never
`git add .` / `git add -A`. Sibling Lane B's F-003 work (already committed at
HEAD: a7af933) and Lane C's F-004 work (uncommitted at this lane's start time;
Lane C reconciled aggregate counts during this lane's flow) are not touched by
this lane.

The roadmap aggregate-count reconciliation was performed by Lane C as
last-lander per the wave-13/lane-c "last-lander" pattern; this lane's
transition note documents the per-feature row update only.

## Push at end

Per user directive 2026-05-07 (`Push at end is AUTHORIZED for this loop session`),
this lane pushes after all 5 commits land cleanly.
