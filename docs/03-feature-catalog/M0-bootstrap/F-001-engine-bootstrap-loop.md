---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
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
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-001-engine-bootstrap-loop-review.md exists with verdict: ACCEPT.
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
| (TBD) `tests/unit/engine-core/bootstrap-loop.test.ts` | unit | RED — asserts lifecycle order; no impl | scenarios 1, 2 |
| (TBD) `tests/integration/engine-core/halt-path.test.ts` | integration | RED | scenario 3 |

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

(empty — populated when implementation begins)
