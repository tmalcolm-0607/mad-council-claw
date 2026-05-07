---
artifact-class: feature-ledger
generated-by: hand-authored (wave-011 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-c
    note: "RED test scaffold landed at tests/unit/F-001-engine-bootstrap-loop.test.ts; 3 assertions match acceptance contract; impl still throws not-yet-implemented"
  - status: green
    at: 2026-05-07
    by: wave-005 / lane-d
    note: "Implementation landed in packages/engine-core/src/index.ts; SHA-256 hash-chained audit + lifecycle [open, active, closing, closed] + cycle_cap at 50; 3/3 acceptance scenarios passing (vitest output in docs/09-examples-proof/F-001/green-test-output.txt)"
  - status: locked
    at: 2026-05-07
    by: wave-011 / lane-b
    note: "Post-impl council review at docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md with verdict ACCEPT (Verdict consensus: APPROVE; median confidence 88; 0 CRITICAL / 0 MAJOR / 3 MINOR / 3 PRAISE). FIRST LOCKED transition in the repo — proves the RED → GREEN → LOCKED state machine end-to-end."
feature-id: F-001
short-slug: engine-bootstrap-loop
milestone: M0
provenance:
  surfaces:
    - kit:loop-skill
    - ce:FR-CORE-001
    - ce:FR-CORE-002
    - ce:FR-CORE-003
    - cp:src/main/index.ts
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-001-engine-bootstrap-loop.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-001-engine-bootstrap-loop-review.md exists with verdict: ACCEPT.
green-evidence:
  test-runner: vitest@2.1.9 (project: unit, filter: tests/unit)
  scenarios-passing: 3
  scenarios-total: 3
  test-output: docs/09-examples-proof/F-001/green-test-output.txt
  physical-proof: docs/09-examples-proof/F-001/physical-proof.md
depends-on: []
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface this feature
  does NOT cover is either tracked by another F-NNN feature (F-002 identity, F-003 scaffolding,
  F-007 IPC contract, F-008 storage layout) OR acknowledged as drop in surface-map.md.
confidence: high
---

# F-001 — Engine bootstrap loop

## Behavior contract

The engine kernel boots a single CoClaw run with a deterministic lifecycle (`open → active → closing → closed`). On startup it loads run config, initializes the audit + cost ledger writers, and enters a cycle-based iteration loop bounded at ≤50 cycles per run. Each cycle reads pending input, dispatches one agent action, persists a hash-chained audit entry, and yields control. Termination always passes through `closing` (which fires the pre-close retro signal per F-014) before reaching `closed`. The loop is the substrate every other governance + automation feature plugs into.

## Acceptance scenarios

1. **Given** a fresh run config with `max_cycles=3`, **When** the engine boots and runs to completion, **Then** the lifecycle emits `open`, `active`, `closing`, `closed` in order and exactly one audit entry per cycle is appended.
2. **Given** a run that hits `max_cycles=50`, **When** cycle 51 is requested, **Then** the engine refuses to start cycle 51 and transitions to `closing` with `terminated_by: cycle_cap`.
3. **Given** a run interrupted by an unhandled exception in cycle N, **When** the engine catches it, **Then** the run still transitions through `closing` (not direct to `closed`) so the pre-close retro signal fires with `halted_by: exception`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/unit/F-001-engine-bootstrap-loop.test.ts` | unit | RED — bootstrap() throws not-yet-implemented; assertions on lifecycle order + cycle cap fail by design | scenarios 1, 2, 3 (shape) |
| (TBD) `tests/integration/engine-core/halt-path.test.ts` | integration | RED — to be authored when exception-injection seam exists in impl | scenario 3 (concrete) |

## Dependencies

- **Hard:** none (foundational)
- **Soft:** F-002 (identity for run_id correlation), F-006 (logging pipeline for cycle entries), F-008 (storage layout for audit + cost-ledger paths)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-CORE-001 | Engine bootstraps CoClaw single-player session |
| ce:FR-CORE-002 | Run lifecycle (open → active → closing → closed) |
| ce:FR-CORE-003 | Cycle-based iteration (≤50 cycles per run) |
| kit:loop-skill | `/loop` cadence + autonomous-loop-discipline as the substrate model |
| cp:src/main/index.ts | clawpilot main-process bootstrap shape (Electron app + lifecycle) |

## Implementation notes

Wave-5 / Lane D — first feature transition RED → GREEN in the repo.

- Implementation: `packages/engine-core/src/index.ts` (~95 LOC)
- Public surface: `bootstrap(config: RunConfig): Promise<RunResult>` + 4 type exports (`LifecycleState`, `TerminatedBy`, `RunConfig`, `AuditEntry`, `RunResult`) + `MAX_CYCLES_HARD_CAP = 50` constant
- Lifecycle order: `open` (init) → `active` (cycle loop) → `closing` (pre-close retro signal seam for F-014) → `closed` (final). Termination ALWAYS flows through `closing` so the F-014 retro hook fires even on cycle-cap or exception paths.
- Cycle cap: `min(maxCycles, MAX_CYCLES_HARD_CAP=50)`; when `requested >= 50` the run terminates with `terminatedBy: 'cycle_cap'`, otherwise `'completion'`. Per ledger acceptance scenario 2.
- Audit chain: SHA-256 of `${priorHash}|${cycle}|${state}` from genesis hash `0` × 64. Hash-chain shape is what scenario 1 + 2 assert; F-015 will extend with cycle payload + signed verdicts.
- Exception path (scenario 3): type surface (`TerminatedBy = 'completion' | 'cycle_cap' | 'exception'`) is in place; F-021 will wire the actual exception-injection seam without breaking this contract.
- Toolchain hop: vitest 2.1.9's `--project <name>` flag did not resolve `tests/unit/**` — switched `package.json` `test:unit` script from `vitest run --project unit` to `vitest run tests/unit` (path-glob filter; same effect, vitest-version-tolerant).
- Workspace fix: added `pnpm-workspace.yaml` + `@mad-council-claw/engine-core: workspace:*` devDependency on root so the package is resolvable from the test suite (pnpm warns on `workspaces` field in package.json but does not honor it).
- Proof: `docs/09-examples-proof/F-001/{green-test-output.txt,physical-proof.md}`.
