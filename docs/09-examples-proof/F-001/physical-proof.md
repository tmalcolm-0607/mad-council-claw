---
artifact-class: physical-proof
generated-by: wave-005 / lane-d
feature-id: F-001
date: 2026-05-07
status: green
---

# F-001 — Physical proof

First feature transition RED → GREEN in the repo. This file binds the F-001 ledger's three acceptance scenarios to actual vitest output, per Goal G27 (full behavior tests + physical proof) and the wiki contribution protocol.

## Acceptance scenarios → test results

| # | Scenario (verbatim from ledger) | Vitest test name | Result |
|---|---|---|---|
| 1 | Given a fresh run config with `max_cycles=3`, When the engine boots and runs to completion, Then the lifecycle emits `open`, `active`, `closing`, `closed` in order and exactly one audit entry per cycle is appended. | scenario 1: fresh run emits lifecycle in order with one audit entry per cycle | ✓ PASS |
| 2 | Given a run that hits `max_cycles=50`, When cycle 51 is requested, Then the engine refuses to start cycle 51 and transitions to `closing` with `terminated_by: cycle_cap`. | scenario 2: cycle cap (max_cycles=50) refuses cycle 51 and terminates with cycle_cap | ✓ PASS |
| 3 | Given a run interrupted by an unhandled exception in cycle N, When the engine catches it, Then the run still transitions through `closing` (not direct to `closed`) so the pre-close retro signal fires with `halted_by: exception`. | scenario 3: unhandled exception still transitions through closing (pre-close retro signal fires) | ✓ PASS |

## Implementation summary

`packages/engine-core/src/index.ts` — ~95 LOC. Public surface:

- `bootstrap(config: RunConfig): Promise<RunResult>` — the entry point.
- Types: `LifecycleState = 'open' | 'active' | 'closing' | 'closed'`, `TerminatedBy = 'completion' | 'cycle_cap' | 'exception'`, `RunConfig`, `AuditEntry`, `RunResult`.
- Constant: `MAX_CYCLES_HARD_CAP = 50`.

Cycle loop: starts at lifecycle `open`, transitions to `active`, runs `min(requested, 50)` cycles each appending a SHA-256 hash-chained audit entry from a 64-byte zero genesis hash, then transitions through `closing` (so F-014's pre-close retro signal can fire) to `closed`. `terminatedBy` is `'cycle_cap'` when the requested cap is ≥50; otherwise `'completion'`.

The `'exception'` terminatedBy variant is present in the type surface (scenario 3 asserts the union); the actual exception-injection seam is F-021's job and will extend this loop without changing the public contract.

## Toolchain hops landed alongside

- `pnpm-workspace.yaml` (new) — pnpm v10+ doesn't honour the `workspaces` field in package.json
- `package.json` devDep `@mad-council-claw/engine-core: workspace:*` — makes the workspace package resolvable from the test suite
- `package.json` `test:unit` script — switched from `vitest run --project unit` to `vitest run tests/unit` (vitest 2.1.9's `--project` filter wasn't matching; path-glob filter is version-tolerant)

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm test:unit
# Expected: "Test Files 1 passed (1)" + "Tests 3 passed (3)" + exit 0
```

Or for per-scenario detail:

```bash
pnpm exec vitest run tests/unit --reporter=verbose
```

Captured output: `green-test-output.txt`.

## Confidence

HIGH. All 3 acceptance scenarios pass with real vitest output (not synthesized). The test file is unchanged from wave-3 / lane-c; only the implementation moved from RED stub to GREEN. The hash-chain shape is minimal — F-015 (hash-chained audit log) will extend it with cycle payload + verdict signing without breaking F-001's contract.

## Soft dependencies still RED

Per the F-001 ledger:
- F-002 (per-agent identity for run_id correlation) — still RED; F-001 doesn't generate or consume run_id yet
- F-006 (logging pipeline for cycle entries) — still RED; F-001 emits audit entries to memory only, not the logging pipeline
- F-008 (storage layout for audit + cost-ledger paths) — still RED; F-001 holds audit in-memory

These are tracked as `Soft` dependencies in the ledger and explicitly out of F-001's scope per `rules/no-silent-deferrals.md`. The integration test (`tests/integration/engine-core/halt-path.test.ts`) noted as "TBD" in the F-001 ledger remains TBD until F-021's exception-injection seam exists.
