---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-016 / lane-b)
wave: wave-016
lane: lane-b
topic: F-023 cron-heartbeat RED → GREEN
date: 2026-05-07
status: complete
---

# Wave 16 / Lane B — F-023 cron-heartbeat RED → GREEN

## Scope

Flip F-023 (M3 cron / heartbeat) RED → GREEN per the ledger §Behavior contract. F-023 is the **first M3 feature** to transition. The behavior contract names a scheduled, recurring heartbeat scheduler that's cadence-aware per `kit:rules/loop-cadence-discipline.md` (the two named profiles `mad-iteration` 270s + `deployment-watch` 1500s; 280-1199s forbidden zone).

## Outcome

**F-023 RED → GREEN** in 5 commits (RED, GREEN-attributed-to-other-lane via cross-lane race, barrel restoration, proof artifacts, ledger update). 21/21 scenarios passing for F-023 isolated; full suite 179/179 across 24 test files.

| State | Test result | Files added/modified |
|---|---|---|
| RED  | 20/20 fail (`TypeError: HeartbeatScheduler is not a constructor`); 152 prior pass | tests/unit/F-023-cron-heartbeat.test.ts (new) |
| GREEN | 21/21 pass; 179/179 total | packages/engine-core/src/heartbeat.ts (new); packages/engine-core/src/index.ts (1 ownership-table comment + 1 re-export) |

(The 20 → 21 delta is one type-witness scenario whose compile-time witness counts at GREEN time but didn't trigger as a runtime failure at RED time — minor count divergence; substance is the same 21-scenario coverage.)

## Test results

```
$ pnpm test
 Test Files  24 passed (24)
      Tests  179 passed (179)
   Duration  ~5s
```

## What landed

1. **`tests/unit/F-023-cron-heartbeat.test.ts`** (288 LOC, 21 scenarios across 6 describe blocks):
   - cadence profile resolution (5): mad-iteration → 270s; deployment-watch → 1500s; custom requires intervalSeconds; custom warm-cache + amortized accepted
   - forbidden-zone enforcement (6): 280s / 600s / 1199s rejected with `loop-cadence-discipline.md` remediation pointer; 270s + 1200s boundaries accepted; `enforceWarmCacheZones: false` bypasses
   - tick lifecycle (3): manual `tick()` increments tickCount + sets lastTickAt; tick before start works (manual-mode for tests); async handler awaited
   - start/stop lifecycle (4): isRunning toggles; double-start throws; stop is idempotent; fake-timers exercise actual setInterval cadence (handler fires after 270s elapses, three times across 810s window)
   - getStatus observability (2): intervalSeconds reported; initial state has tickCount=0, lastTickAt=null, isRunning=false
   - CadenceProfile type witness (1): compile-time check that the union has exactly the 3 documented values
2. **`packages/engine-core/src/heartbeat.ts`** (~145 LOC): `HeartbeatScheduler` class. Cadence-zone validation enforced at construction. `tick()` exposed publicly so tests + `/loop` dynamic-mode callers can drive without `setInterval`.
3. **`packages/engine-core/src/index.ts`**: 1 ownership-table comment + 1 re-export `export * from './heartbeat.js'`. Disjoint append zone per the wave-011/lane-a per-feature-files convention.
4. **`docs/09-examples-proof/F-023/{red,green}-test-output.txt`** + **`physical-proof.md`**: behavior witness, scope reconciliation with F-001 / F-006 / F-008 / F-024, cadence-zone math, drift accounting deferral note.
5. **F-023 ledger** (`docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md`): status: red → green; status-history append; test-files populated; Implementation notes section authored.
6. **Roadmap** (`roadmap.md`): F-023 row 🔴 → 🟢; M3 row 5R + 0G → 4R + 1G; TOTAL aggregate refresh; Wave-16 / Lane B transition note.
7. **Confidence ledger** (`docs/11-loop-state/confidence-ledger.md`): Wave 16 / Lane B entry block (this lane's findings).
8. This summary file.

## Scope reconciliation (FETCH BEFORE CITE on the F-023 ledger)

The ledger §Behavior contract names several capabilities — schedule registration, cron-expression parsing, fresh-run spawn (per F-001), `cron-fires.jsonl` append (per F-006/F-008), drift accounting (≤5% over 100-fire window per ce:SC-007). F-023's primitive is intentionally **just the scheduler** — pure-class, no I/O, no run spawn, no log append. Mirrors the F-022 ToolCallQuota / F-018 HaltDetector pattern: pure behavior + composition by callers.

Per `no-silent-deferrals.md`, every non-implemented surface is named and explicitly owned by a downstream feature:

- **Run spawn** → F-001 (engine-bootstrap-loop): orchestrator's tick handler invokes the boot path.
- **`cron-fires.jsonl` append** → F-006 (logging-pipeline) + F-008 (storage layout).
- **Overlap detection** → F-024 (skip-on-overlap): wraps the tick handler.
- **Agent identity** → F-002 (per-agent-identity-runid): caller resolves before invoking the handler.
- **Drift accounting** → F-026 / F-027 (per the M3 catalog): F-023 contributes the SHAPE (`getStatus.lastTickAt` + `tickCount`) but not the calculation.
- **Cron-expression parsing** → orchestrator-side (cron strings map to seconds before `HeartbeatScheduler` construction; the class accepts seconds, not cron strings, by design — keeps the primitive testable in isolation).

## Cross-lane staging-race sighting #16

At Lane B execution time, the working tree had heavy mid-flight WIP from concurrent lanes. Specifically:

- Wave-16 / Lane A was executing 4 LOCKED-flip commits (F-010/F-011/F-012/F-013 council-review verdicts).
- Wave-16 / Lane C (F-028 cli-entry) was concurrent — RED + GREEN for that lane landed during Lane B's window.
- Pre-existing uncommitted state from wave-15 / lane-d existed (the F-012 + F-013 barrel re-exports + roadmap row updates that never made it into a wave-15 commit).

The race manifested in two ways:

1. **F-023 GREEN files landed under wrong commit message.** Commit `fdede59 docs(F-011): post-impl council review verdict ACCEPT` (Lane A's commit) swept in `packages/engine-core/src/heartbeat.ts` + the F-023 barrel addition because pre-commit hooks committed broader scope than the explicit `git add` set. Substance preserved (F-023 isolated test 21/21 PASS at HEAD); credit attribution corrupted. Per `non-negotiable-rules.md` (no destructive git ops), no rebase/reset to fix history. Documented in F-023 ledger §Implementation notes + GREEN proof + this summary + confidence-ledger entry.

2. **F-012 + F-013 barrel re-exports lost.** The `index.ts` rewritten by `fdede59` only had F-023's barrel addition; the wave-15/lane-d-deferred F-012 + F-013 entries were silently dropped. Tests for F-012 (`createBackend is not a function`) + F-013 (`isTokenEvent is not a function`) failed in HEAD post-Lane-A. Lane B added a fix-forward commit `f59c4ce fix(barrel): restore F-012 + F-013 exports lost in cross-lane race` — pure barrel-layer restore, no source changes.

This is sighting #16 of the pattern documented in waves 9-15 (sightings #14, #15). The pattern is at this point **chronic** and warrants escalation.

**Wave-17+ candidate (escalation, repeated sighting):**

- Per-commit `git diff --cached --name-only` assert before each commit (lane explicitly verifies what's about to be committed).
- OR per-lane branches when concurrent lane count ≥ 3 (current direct-to-main pattern is the root cause).
- OR pre-commit hook that REQUIRES a per-feature scope manifest (e.g., `.mad/wave-N/lane-X/scope.txt` listing files; commit rejected if `git diff --cached` includes non-listed files).

The fix-forward pattern Lane B used (commit the barrel-layer restore as a separate commit) preserves substance + audit trail without rewriting history. It's the right tactical response per `non-negotiable-rules.md`; the strategic response is the escalation above.

## Cadence-zone enforcement (loop-cadence-discipline.md)

```
0s ─── 270s ─── 300s ─── 1200s ─── 3600s
       │          │            │
       │          └ "worst-of-both" wall ─ DO NOT PARK HERE
       │
       └ Warm-cache zone        └ Amortized-cache-miss zone
```

The constructor enforces this gate at registration time so misconfigured cron schedules are rejected before any timer is registered. `enforceWarmCacheZones: false` is the operator escape hatch — visible in code rather than silent — for the rare documented case (e.g., a 600s cadence required by an external system's contract).

## Test ergonomics

`tick()` is exposed as a public method so tests can drive the handler without `setInterval` and without fake-timers. The fake-timers test (scenario 4 in start/stop lifecycle) demonstrates the actual `setInterval` wiring; the rest of the suite uses manual `tick()` for determinism.

Async handlers are awaited by `tick()`, so consumers can use `await scheduler.tick()` to ensure handler completion in tests. `setInterval`-driven ticks fire-and-forget the promise (setInterval has no await semantics) but the unhandled-rejection surface is intentionally bounded by the contract: handlers are caller-owned.

## Why the test count differs (20 vs 21)

The original brief named 6+ scenarios; the implementation grew to 21 across 6 describe blocks during authoring (each describe block is a logical group; the 6+ requirement is comfortably exceeded). RED test output shows 20 hot-path scenarios fail with `TypeError: HeartbeatScheduler is not a constructor`; the 1 type-witness scenario (`accepts the three documented profile values`) passes at RED because it's a compile-time check on the type union, not a runtime construction. At GREEN, all 21 pass.

## Verification trail

```
$ git log --oneline -10
0d4c84a docs(F-023): GREEN proof artifacts
f59c4ce fix(barrel): restore F-012 + F-013 exports lost in cross-lane race
21dd875 docs(F-013): post-impl council review verdict ACCEPT
58aa119 docs(F-012): post-impl council review verdict ACCEPT
fdede59 docs(F-011): post-impl council review verdict ACCEPT  ← swept F-023 GREEN code
803f4be docs(F-010): post-impl council review verdict ACCEPT
fe44bbe feat(F-028): GREEN cli-entry runCli + dispatcher
2dd50c4 test(F-028): RED cli-entry runCli + dispatcher
f32aebe test(F-023): RED - cron-heartbeat 20 scenarios  ← this lane's RED
e237d0b docs(wave-015/lane-d): summary - F-012 + F-013 GREEN; M1 100% RED-cleared

$ pnpm test
 Test Files  24 passed (24)
      Tests  179 passed (179)
```

## Future M3 work

After this lane:
- **F-023 GREEN → LOCKED**: post-impl council review (verdict ACCEPT pending).
- **F-024 (skip-on-overlap)**: wraps the F-023 tick handler with an overlap check.
- **F-025 (cron-schedules.json)**: the `automations/cron-schedules.json` schema + registration/deregistration surface.
- **F-026 / F-027 (drift accounting + observability)**: consume `cron-fires.jsonl` (F-006/F-008) + compute the ≤5%-over-100-fire-window guarantee from ce:SC-007.

The M3 milestone has 4 features remaining RED after this flip (F-024, F-025, F-026, F-027).
