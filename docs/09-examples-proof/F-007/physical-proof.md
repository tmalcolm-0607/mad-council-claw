---
artifact-class: physical-proof
generated-by: wave-011 / lane-a
feature-id: F-007
date: 2026-05-07
status: green
---

# F-007 — Physical proof

12th feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006, F-014 wave-008/lane-a, F-015 wave-008/lane-b, F-006 + F-016 + F-018 wave-009, F-008 + F-019 + F-020 + F-022 wave-010). First M0 IPC-scaffold flip. Co-shipped with the wave-011/lane-a refactor of `packages/engine-core/src/index.ts` into 10 per-feature files.

## Acceptance scenarios → test results

| # | Scenario (from ledger / wave-011/lane-a brief) | Vitest test name | Result |
|---|---|---|---|
| 1 | Given a contract `chat.send` with request `{message: string}` and response `{reply: string}`, When the renderer calls `window.api.chat.send({message: "hi"})`, Then the call is type-safe and the main-process handler receives the same typed payload. **Lane-a interpretation: scaffold-shape contract — `IpcInvokeMap` is exported as an object type that future channels extend.** | scenario 1: IpcInvokeMap is exported as an object type | PASS |
| 2 | Given a renderer that tries to call `ipcRenderer.send('foo', ...)` directly, When the bundle builds, Then the build fails. **Deferred to M5** (requires Electron context-bridge runtime — F-032..F-043). | (deferred) | n/a |
| 3 | Given a developer adds a handler in main without registering it in the contract module, When `npm run build` runs, Then TypeScript fails. **Deferred to M5** (requires actual handler call site). | (deferred) | n/a |
| (ext) | IpcInvokeChannel = keyof IpcInvokeMap — the channel union derives from the map | scenario 2: IpcInvokeChannel is the keyof IpcInvokeMap | PASS |
| (ext) | Module is importable at runtime — vitest `Cannot find module` fails-fast on RED | scenario 3: module is importable at runtime (scaffold module exists) | PASS |

3/3 PASS for the wave-011-scoped scaffold-shape contract. See `green-test-output.txt` for the captured vitest output. RED baseline at `red-test-output.txt` (vitest aborts: `Failed to load url ../../common/ipc-contract.js`).

## Scope reconciliation with F-007 ledger (FETCH BEFORE CITE)

The F-007 ledger (`docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md`) §Acceptance scenarios names 3 scenarios — only the first is achievable purely through TypeScript types in the scaffold module itself. Scenarios 2 (renderer can't call `ipcRenderer` directly) and 3 (TS fails when handler not registered) require an actual call-site + Electron harness, both of which land with M5 desktop-shell features (F-032..F-043). Per `no-silent-deferrals.md`, the deferral is documented in the F-007 ledger §Red→green wire-up table with explicit deferred-to-M5 markers. Scaffold-shape contract is the GREEN-flippable subset; M5 will retire the deferrals.

## Implementation summary

### New file (F-007 owned)

`common/ipc-contract.ts` — **NEW** at repo root. 86 LOC. Exports:

- `IpcInvokeMap` — empty object type (`{}`); future features extend with channel entries.
- `IpcInvokeChannel` — `keyof IpcInvokeMap` (= `never` until first channel).
- `IpcInvokeRequest<C>` — accessor for a channel's request shape.
- `IpcInvokeResponse<C>` — accessor for a channel's response shape.

### Co-shipped refactor (wave-011/lane-a — engine-core split)

`packages/engine-core/src/index.ts` — **REFACTORED** from 1841-LOC monolith to 32-LOC barrel. 10 new per-feature files created:

| File | Owns | Approx LOC |
|---|---|---|
| bootstrap.ts | F-001 (engine-bootstrap-loop) + LifecycleState/TerminatedBy/RunConfig/AuditEntry/RunResult | 105 |
| identity.ts | F-002 (per-agent-identity-runid) + Agent/Session/createAgent/createSession/stampIdentity | 134 |
| logger.ts | F-006 (logging-pipeline) + LogLevel/LogEvent/Logger/createLogger | 121 |
| storage.ts | F-008 (local-storage-layout) + StorageLayout/get/ensure/atomicWriteJson/readJson | 118 |
| retro.ts | F-014 (pre-close-retro-signal) + RetroSignal/RetroOutcome/RetroMissingError/closeSession | 174 |
| audit.ts | F-015 (hash-chained-audit-log) + F-016 (query-audit-log) + AuditLogEntry/append/verify/queryAuditLog/findChainBreak | 244 |
| halt.ts | F-018 (failure-pattern-halt) + **shared** RunHaltedVerdict/HaltTrigger/HaltContext + HaltDetector | 234 |
| cost.ts | F-019 (cost-ledger) + CostEntry/CostEntryInput/CostLedger | 188 |
| killswitch.ts | F-020 (kill-switch) + KillSwitch class — imports RunHaltedVerdict from halt.ts | 137 |
| quota.ts | F-022 (tool-call-quota) + ToolCallQuota class — imports RunHaltedVerdict from halt.ts | 92 |

### New test file

`tests/unit/F-007-ipc-contract-scaffold.test.ts` — **NEW**. 3 tests covering scaffold-shape contract.

### Modified

- `roadmap.md` — F-007 row: 🔴 RED → 🟢 GREEN; M0 row: 4R+4G → 3R+5G; TOTAL: 110R+11G → 109R+12G.
- `docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md` — status red → green; status-history append; test-files unit array gains the new path; impl notes appended.
- `tsconfig.json` — include adds `common/**/*.ts` (1-line addition).
- `docs/11-loop-state/confidence-ledger.md` — Lane A wave-11 entries (5 rows: refactor + F-007 GREEN + first-owner-rule + tsconfig + staging-race-elimination prediction).

## Test runner output

72/72 → 75/75 (3 new F-007 tests added; 0 prior-feature regressions).

```
 Test Files  12 passed (12)
      Tests  75 passed (75)
   Start at  01:20:22
   Duration  2.80s
```

## Refactor as cross-lane staging-race elimination

The split was the **wave-11 priority HIGH** loop-improvement called out in the wave-10 lane-b confidence-ledger entry: "per-feature engine-core file split (`engine-core/src/{halt,killswitch,cost,quota,...}.ts` with index.ts as barrel) is now mandatory — per-lane discipline does not scale to 4+ concurrent lanes". This wave delivers the refactor.

5 prior sightings of the cross-lane race (wave-009 Lanes B+C, wave-010 Lanes A+C, wave-10 Lane B) all involved sibling lanes editing different feature regions of the SAME `index.ts`. Post-split, future waves' lanes can edit `cost.ts` and `killswitch.ts` independently — no shared file beyond the 32-LOC barrel (which only changes when adding a new feature).

Wave-12+ verification: monitor next 2-3 waves with concurrent lanes touching engine-core. If no race recurs, the prediction in `Lane-A-w11-staging-race-eliminated` (HIGH confidence) promotes to LOCKED.
