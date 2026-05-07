---
artifact-class: physical-proof
generated-by: wave-010 / lane-b
feature-id: F-020
date: 2026-05-07
status: green
---

# F-020 — Physical proof

Eighth feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006, F-014 wave-008/lane-a, F-015 wave-008/lane-b, F-006 wave-009/lane-a, F-016 wave-009/lane-b, F-018 wave-009/lane-c, F-008 + F-019 wave-010 sibling lanes). Third standalone M2 governance feature beyond F-014/F-015/F-018 to flip GREEN — completes the kill-switch primitive that F-001 cycle-start hook will call before every model + tool invocation. This file binds the wave-010 / lane-b brief's acceptance scenarios (plus F-020 ledger contract) to actual vitest output, per Goal G27 (full behavior tests + physical proof).

## Acceptance scenarios → test results

| # | Scenario (from brief / ledger) | Vitest test name | Result |
|---|---|---|---|
| 1 | Env var `MAD_KILL=1` → `isTriggered()` returns true | scenario 1: env var MAD_KILL=1 triggers isTriggered() | PASS |
| 2 | Env var `MAD_KILL=true` → `isTriggered()` returns true | scenario 2: env var MAD_KILL=true triggers isTriggered() | PASS |
| 3 | Env unset, kill-file exists → `isTriggered()` returns true | scenario 3: env unset, kill-file exists triggers isTriggered() | PASS |
| 4 | Env unset, no kill-file path → `isTriggered()` returns false | scenario 4: env unset and no kill-file path → isTriggered() false | PASS |
| 5 | Env unset, kill-file path set but file does not exist → `isTriggered()` returns false | scenario 5: env unset, kill-file path set but fileExistsFn returns false → isTriggered() false | PASS |
| 6 | `checkOrThrow()` throws Error with attached `RunHaltedVerdict` (`trigger='manual'`, non-empty reason, ISO timestamp) when triggered | scenario 6: checkOrThrow() throws with attached RunHaltedVerdict (trigger=manual) when triggered | PASS |
| 7 | `checkOrThrow()` is a no-op when not triggered | scenario 7: checkOrThrow() is a no-op when not triggered | PASS |
| 8 | Multiple `isTriggered()` calls are idempotent (no internal state mutation) | scenario 8: multiple isTriggered() calls are idempotent | PASS |
| 9 | Custom `envVarName` override — default `MAD_KILL` is not consulted | scenario 9: custom envVarName override — default MAD_KILL is not consulted | PASS |
| (ext) | Env value other than `'1'`/`'true'` does NOT trigger (e.g. `'0'`, `'false'`, `''`, `'no'`, `'off'`) | env value other than "1"/"true" does NOT trigger | PASS |
| (ext) | Read-time propagation: env mutation between checks is observed | read-time propagation: env mutation between checks is observed | PASS |

11/11 PASS. See `green-test-output.txt` for the captured vitest output. RED baseline at `red-test-output.txt` (11/11 fail with `TypeError: KillSwitch is not a constructor`).

## Scope deviation from F-020 ledger (intentional, documented)

The F-020 ledger §Behavior contract names a JSON file at `userData/mad-council-claw/kill-switch.json` with `{halted, reason?, set_at_utc?, set_by?}` schema and read-time propagation via the engine cycle hook. The wave-010 / lane-b brief simplifies this to a `KillSwitch` class taking optional file path + env-var name + injected `fileExistsFn` + injected env. The substantive guarantees — read-time propagation, RUN_HALTED verdict on trigger, defaults to halted=false when neither signal is present — are preserved; the JSON parsing + reason/set_at_utc/set_by fields are deferred to the engine-cycle integration step that consumes this primitive.

Per FETCH BEFORE CITE + wave-008/wave-009 precedent (honor the brief when it explicitly narrows scope; surface the gap explicitly per `rules/no-silent-deferrals.md`), this flip lands the in-memory primitive only. Five explicit out-of-scope items are listed in the F-020 region header in `packages/engine-core/src/index.ts` and in the ledger §out-of-scope-notes.

## Implementation summary

`packages/engine-core/src/index.ts` — F-001 / F-002 / F-006 / F-008 / F-014 / F-015 / F-016 / F-018 / F-019 / F-022 unchanged (sibling lanes); F-020 appends ~175 LOC at end-of-file:

- `defaultKillFileExists(path)` — lazy `node:fs.existsSync` wrapper that fail-safes to `false` on errors. Read-time propagation per ledger means we fail-safe to "not halted" when the FS layer misbehaves; an explicit env-var override remains the operator's belt-and-braces path.
- `KillSwitch` class — constructor takes 4 dependencies, all defaulted for ergonomics + all injectable for testability:
  - `killFilePath: string | null = null` — when null, no file check is performed.
  - `envVarName: string = 'MAD_KILL'` — the env var consulted for the truthy gate.
  - `fileExistsFn: (path: string) => boolean = defaultKillFileExists` — injectable existence check.
  - `env: Record<string, string | undefined> = process.env` — injectable env source.
- `isTriggered()` — returns true when env var === `'1'` OR `'true'`, OR kill-file path is configured AND `fileExistsFn(path)` returns true. No internal state mutation.
- `checkOrThrow()` — throws Error decorated with F-018 `RunHaltedVerdict` (`trigger='manual'`, non-empty `reason` describing which source tripped, ISO-8601 `timestamp`).

Verdict-shape reuse: `trigger='manual'` is the F-018 sibling trigger reserved for operator/kill-switch invocations — same uniform halt-reporting surface across F-018 (failure-pattern), F-020 (kill-switch), F-021 (degradation), F-022 (tool-quota). Verified consistent with `tests/unit/F-018-failure-pattern-halt.test.ts` scenario 7.

## Toolchain hops landed alongside

None. Wave-005 / lane-d already landed `pnpm-workspace.yaml` + `@mad-council-claw/engine-core: workspace:*` devDep + `test:unit` script fix. F-020 inherits all three.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-020-kill-switch.test.ts
# Expected: "Test Files 1 passed (1)" + "Tests 11 passed (11)" + exit 0
```

Or for per-scenario detail:

```bash
pnpm exec vitest run tests/unit/F-020-kill-switch.test.ts --reporter=verbose
```

Captured: `green-test-output.txt`. Stability: re-run after sibling-lane work landed; 11/11 PASS, no flake. Full unit suite: 66/66 across 10 test files.

## Anomalies / context gaps

### A1 — RED commit absorbed sibling lane F-022 RED stub

**Severity**: HIGH (load-bearing for commit-history cleanliness; substantively benign — the work landed correctly).

When wave-010 / lane-b started authoring the F-020 RED test, sibling lanes had uncommitted F-022 RED stub files in the working tree (`tests/unit/F-022-tool-call-quota.test.ts` + `docs/09-examples-proof/F-022/red-test-output.txt`). Lane B's RED commit `f142eb1 test(F-020): RED test stub for kill-switch` absorbed those F-022 files via a staging-race mechanism documented in detail in `docs/11-loop-state/confidence-ledger.md` (`Lane-B-w10-staging-race-with-sibling-lanes`).

The substantive F-020 work is correctly attributed (test file + RED output paths are F-020-named). The audit trail is honestly surfaced here, in the commit message, and in the confidence-ledger entry.

### A2 — GREEN commit was clean

Lane B's GREEN commit `7b70c5a feat(F-020): GREEN impl — read-time-propagating kill switch` staged ONLY:
- `packages/engine-core/src/index.ts` (F-020 region append)
- `docs/09-examples-proof/F-020/green-test-output.txt`

Sibling lanes' working-tree changes (F-019 ledger updates, F-022 ledger, etc.) were correctly NOT staged — the wave-010 single-shell stage-then-commit discipline worked on the second pass. This validates that the discipline DOES work when one lane is not actively staging the same file in the same window; the A1 race only manifested during the RED commit because sibling lanes were ALSO staging concurrently.

## Lessons / loop-improvement notes for wave-11

1. **Per-feature engine-core file split is now overdue (HIGH).** Five sightings of the cross-lane staging-race pattern across waves 9-10 (Lane B w9, Lane C w9, Lane A w10, Lane B w10 [this lane], Lane C w10). The "explicit per-lane staging discipline" mitigation works for 2-3 concurrent lanes but NOT for 4+. Wave-11 should land `engine-core/src/{halt,killswitch,cost,quota,storage,audit,query,logging,...}.ts` with `index.ts` as a barrel re-exporter. Per-file ownership eliminates the contention zone entirely.

2. **Brief-vs-ledger reconciliation discipline (5th sighting; PROMOTING TO HIGH).** Lane A wave-010 entry flagged "promote from MEDIUM to HIGH at next wave if 5th sighting occurs." Lane B wave-010 brief vs F-020 ledger IS the 5th sighting. Wave-11 mandate: brief-generation tooling MUST diff against live ledger frontmatter + behavior contract at brief-write time and surface divergences inline.

3. **Verdict-shape reuse pattern validated (HIGH).** F-020's `checkOrThrow()` reuses F-018's `RunHaltedVerdict` shape with `trigger='manual'` rather than introducing a parallel error class. This preserves a single uniform halt-reporting surface across F-018/F-020/F-021/F-022 — the F-014 `RetroOutcome` already maps `manual` to `halted_by_kill_switch` etc. Wave-11 reusable pattern: when a feature emits a halt, REUSE the F-018 verdict shape with the appropriate sibling trigger; adding a new top-level halt type means adding it to the F-018 `HaltTrigger` union FIRST.

## Confidence

HIGH. All 11 scenarios pass with real vitest output (not synthesized). Stable re-run after sibling-lane churn (11/11 PASS). RED baseline captured BEFORE the impl flip per the wave-5 retro proposal — see `red-test-output.txt`. Read-time propagation explicitly tested via the env-mutation scenario (env Record mutated between three `isTriggered()` calls; each observation reflects the current state).

## Soft dependencies still open

Per the F-020 ledger:
- F-001 (engine bootstrap) — F-001's cycle loop will call `KillSwitch.checkOrThrow()` at the START of each cycle.
- F-008 (local storage layout) — F-008 owns the resolution of the kill-switch file path (e.g. `<userData>/mad-council-claw/kill`).
- F-014 (pre-close retro signal) — F-014's `RetroOutcome.halted_by_kill_switch` consumes the verdict; the engine cycle catches the throw and routes there.
- F-015 (hash-chained audit log) — F-015 will record each kill-switch read result for forensic replay.
- JSON schema parsing of `kill-switch.json` — deferred to engine-cycle integration; the brief-scoped primitive only covers existence-check.
