---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-011 / lane-a)
wave: wave-011
lane: lane-a
topic: engine-core-file-split + F-007-ipc-contract-scaffold-RED-GREEN
date: 2026-05-07
status: complete
---

# Wave 11 / Lane A — engine-core split + F-007 ipc-contract-scaffold RED → GREEN

## Scope (two work-items)

**Primary: critical refactor — split `packages/engine-core/src/index.ts` into per-feature files.** The wave-10 lane-b confidence-ledger entry flagged this as the **wave-11 priority HIGH** loop-improvement: "per-feature engine-core file split is now mandatory — per-lane discipline does not scale to 4+ concurrent lanes." 5 prior sightings of cross-lane staging absorption (wave-009 Lanes B+C, wave-010 Lanes A+B+C) all rooted in sibling lanes editing different feature regions of the SAME monolithic 1841-LOC `index.ts`. This lane delivers the split.

**Secondary: F-007 ipc-contract-scaffold flip RED → GREEN.** Touches `common/ipc-contract.ts` (NEW at repo root) — entirely separate from engine-core, so naturally pairable with the refactor.

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| **Refactor (engine-core split)** | | | |
| Per-feature files (10 new) | `packages/engine-core/src/{bootstrap,identity,logger,storage,retro,audit,halt,cost,killswitch,quota}.ts` | new | 10 |
| Barrel | `packages/engine-core/src/index.ts` | rewrite (1841 → 32 LOC) | 1 |
| **F-007 scaffold + test** | | | |
| Scaffold module | `common/ipc-contract.ts` | new | 1 |
| RED→GREEN test | `tests/unit/F-007-ipc-contract-scaffold.test.ts` | new | 1 |
| Vitest output capture | `docs/09-examples-proof/F-007/red-test-output.txt` + `green-test-output.txt` | new | 2 |
| Physical proof | `docs/09-examples-proof/F-007/physical-proof.md` | new | 1 |
| **Build / config** | | | |
| TS config | `tsconfig.json` | modified (1-line: add `common/**/*.ts` to include) | 1 |
| **Ledger / roadmap / docs** | | | |
| Ledger flip | `docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md` | modified (status red→green; status-history; test-files unit; wire-up table; impl notes) | 1 |
| Roadmap update | `roadmap.md` | modified (F-007 row → 🟢 GREEN; M0 row 4R+4G → 3R+5G; TOTAL row 110R+11G → 109R+12G) | 1 |
| Confidence ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Lane A wave-11 — 5 rows) | 1 |
| **This summary** | `docs/06-agent-team-outputs/wave-011/lane-a-summary.md` | new | 1 |
| **Total touched** | | | **20 artifacts** |

## Test result

**75/75 PASS** across 12 test files (vitest run, ~2.8s).

- Pre-refactor baseline: 72/72 across 11 files.
- Post-refactor: 72/72 (pure refactor, no behavior change).
- Post-F-007 GREEN: 75/75 (+3 new F-007 tests).

```
 Test Files  12 passed (12)
      Tests  75 passed (75)
   Duration  2.80s
```

`npx tsc --noEmit` clean after both the refactor and the tsconfig include extension.

## RED baseline captured

`docs/09-examples-proof/F-007/red-test-output.txt` shows vitest aborting:

```
FAIL  tests/unit/F-007-ipc-contract-scaffold.test.ts [...]
Error: Failed to load url ../../common/ipc-contract.js (resolved id: ../../common/ipc-contract.js) ... Does the file exist?
```

This is the canonical RED gate the wildcard `import * as IpcContract from '../../common/ipc-contract.js'` enforces — type-only imports get stripped by esbuild, but a wildcard runtime import fails-fast when the module is missing. RED is meaningful, not silent.

## Engine-core split — design decisions

### Authoritative ownership map (locked into index.ts barrel comment)

| File | Owns |
|---|---|
| bootstrap.ts | F-001 + `LifecycleState` / `TerminatedBy` / `RunConfig` / `AuditEntry` / `RunResult` |
| identity.ts | F-002 + `Agent` / `Session` / `createAgent` / `createSession` / `stampIdentity` |
| logger.ts | F-006 + `LogLevel` / `LogEvent` / `Logger` / `createLogger` |
| storage.ts | F-008 + `StorageLayout` / `getStorageLayout` / `ensureStorageLayout` / `atomicWriteJson` / `readJson` |
| retro.ts | F-014 + `RetroSignal` / `RetroOutcome` / `RetroMissingError` / `closeSession` |
| audit.ts | F-015 + F-016 + `AuditLogEntry` / `appendAuditEntry` / `verifyAuditChain` / `queryAuditLog` / `findChainBreak` / `GENESIS_SENTINEL` |
| halt.ts | F-018 + **shared** `RunHaltedVerdict` / `HaltTrigger` / `HaltContext` + `HaltDetector` |
| cost.ts | F-019 + `CostEntry` / `CostEntryInput` / `CostLedger` |
| killswitch.ts | F-020 + `KillSwitch` (imports `RunHaltedVerdict` from halt.ts) |
| quota.ts | F-022 + `ToolCallQuota` (imports `RunHaltedVerdict` from halt.ts) |

### Shared types: first-owner rule

`RunHaltedVerdict` + `HaltTrigger` were introduced by F-018 — they live in `halt.ts`. F-020 (KillSwitch) and F-022 (ToolCallQuota) reuse the shape rather than redeclaring; both `import type { RunHaltedVerdict } from './halt.js';`. This is the canonical pattern when splitting monolithic files: shared types live with their FIRST owner; later features import via ESM-style relative path.

### ESM extension convention

Per Node ESM convention + tsconfig `moduleResolution: "Bundler"`, all relative imports use the `.js` extension (not `.ts`) even when source is `.ts`. The barrel uses `export * from './bootstrap.js'` etc.; cross-file type imports use `from './halt.js'`.

### Single quirk: `HaltTrigger` extension for F-022

Pre-split, `HaltTrigger` had 12 values (the 9-value F-018 ledger enum + 3 sibling triggers `manual`/`iteration_cap`/`tool_calls_quota`). F-022 added a 13th value `tool_calls` (no `_quota` suffix) for the per-spawn quota trigger — F-018 emits `tool_calls_quota` for the global counter; F-022 emits `tool_calls` for per-agent quota exhaustion. The 13-value union is preserved verbatim in halt.ts. Comment in halt.ts §HaltTrigger documents the F-018-vs-F-022 trigger-name distinction.

## Anomalies

**A0 — none observed.** Pure refactor + standalone scaffold-flip; no cross-lane staging interaction this lane. The 75/75 pass count includes 0 regressions and 3 new tests, exactly as predicted.

**A1 — Wave-11 lane-b in-flight at lane-a's start.** Lane B's F-001 GREEN → LOCKED commits (4519cd6, f13ff71, 5796949) had already landed before lane-a started. Lane B's confidence-ledger entry (`Lane-B-w11-cross-lane-WIP-staging-discipline`) explicitly notes lane-a's file split was uncommitted at the time of lane-b's review — Lane B reviewed the (then-current) monolithic `index.ts` per `verification-protocol.md` Rule 4 (ACTUAL BEFORE PRESENT). Lane A's split happens AFTER Lane B's LOCKED commits land; this is the correct chronological order, not an anomaly. The F-001 review's MINOR finding F2 (file-location divergence brief vs source) becomes obsolete once lane-a's split is committed — but the review verdict (ACCEPT) stands because the verdict was on F-001's *behavior contract*, which is unchanged by the split.

**A2 — F-007 test-runtime-witness pattern.** Originally drafted F-007 test used type-only imports (`import type {...}`); esbuild stripped them and the test passed silently even with no module on disk — the opposite of RED-then-GREEN. Caught and corrected: added a wildcard runtime import (`import * as IpcContract`) that forces vitest to resolve the module at runtime, plus a runtime assertion `expect(IpcContract).toBeDefined()`. RED then meaningfully failed; GREEN cleanly passes. **Wave-12 reusable**: any future scaffold-flip whose contract is type-only MUST include a runtime witness so the RED state is observable through vitest.

## Time budget

≤8 min wall-clock per the brief. Actual: ~7 min — within budget despite the heavier scope (refactor + flip together).

## Wave-12 follow-ups (none blocking)

1. **Verify no cross-lane race recurs** — monitor wave-12 + wave-13 for engine-core lanes; if 2+ waves pass cleanly with concurrent lanes, promote `Lane-A-w11-staging-race-eliminated` from HIGH to LOCKED.
2. **F-001 review's MINOR F2 finding becomes stale** — the file-location divergence noted in lane-b's council review is resolved by lane-a's split. Future LOCKED transitions for F-002/F-006/F-008/F-014/F-015/F-016/F-018/F-019/F-020/F-022 can cite the per-feature file paths directly without scope-divergence.
3. **F-007 M5 deferrals** — context-bridge runtime + handler-not-registered build-time tests deferred to M5 (F-032..F-043) per `no-silent-deferrals.md`. Tracked in F-007 ledger §Red→green wire-up.
4. **`HaltTrigger` 13-value union normalization** — F-018 ledger names a 9-value automatic-halt enum; the implementation extends with 4 sibling triggers (`manual`, `iteration_cap`, `tool_calls_quota`, `tool_calls`). Wave-12+ governance review may want to either (a) update the F-018 ledger to acknowledge the 4 sibling triggers or (b) move sibling triggers to the F-020/F-022 ledgers explicitly. Currently the divergence is documented inline in halt.ts but not in any ledger §authoritative-enum block.

## Commit chain (separate atomic commits)

Five commits planned per the brief:

1. `refactor(engine-core): split src/index.ts into per-feature files (eliminates cross-lane race)`
2. `feat(F-007): ipc-contract-scaffold — common/ipc-contract.ts + RED→GREEN test`
3. `docs(catalog): F-007 ledger RED → GREEN`
4. `docs(roadmap): F-007 GREEN; M0 4 RED + 4 GREEN`
5. `docs(examples-proof): F-007 GREEN — vitest output + physical-proof + lane-a summary`

(Actual SHAs filled in commit-by-commit below; see git log after lane completion.)

## Reusable-pattern proposals for `apply-learnings`

1. **First-owner rule for shared types in a per-feature file split** — codify in a kit rule (`rules/per-feature-file-split.md`?) for any future repo doing the same kind of split.
2. **Runtime witness in scaffold tests** — RED state for type-only contracts MUST include a wildcard runtime import + minimal runtime assertion to force vitest module resolution. Document in `rules/red-green-discipline.md` (or equivalent).
3. **ESM `.js` extension consistency** — when splitting a Bundler-mode `.ts` monolith, all cross-file imports use `.js` extensions. Catch in pre-commit hook?
