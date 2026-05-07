# F-138 Physical Proof — Engine-cycle orchestrator

**Date:** 2026-05-07 (wave-017 / lane-a)

## Files landed

| Path | Purpose |
|---|---|
| `packages/engine-core/src/cycle.ts` | F-138 implementation (`runEngineCycle`, `EngineCycleConfig`, `RunOutcome` + private `AuditChain` adapter) |
| `tests/unit/F-138-engine-cycle-orchestrator.test.ts` | 3 acceptance scenarios |
| `packages/engine-core/src/index.ts` | barrel: `+ export * from './cycle.js'` + 1-line ownership comment |
| `docs/03-feature-catalog/M0-bootstrap/F-138-engine-cycle-orchestrator.md` | feature ledger (RED → GREEN in same lane) |
| `docs/09-examples-proof/F-138/red-test-output.txt` | RED baseline (`runEngineCycle is not a function` × 3) |
| `docs/09-examples-proof/F-138/green-test-output.txt` | GREEN evidence (3/3 PASS in 7ms) |

## Test results

- F-138 isolated: **3/3 PASS** (vitest 2.1.9, 7ms)
- Full unit suite at GREEN time: 147 PASS / 16 FAIL (16 failures pre-existing — F-024/F-025 RED scenarios + F-030 CLI; +3 PASS vs pre-F-138 baseline of 144 PASS / 19 FAIL).

## Wave-016 HARD-BLOCK F1 resolution

Both Opus and gpt-5.5 flagged on 2026-05-07 (`docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-016-impl-review.md`):

> "No engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014. `bootstrap()` makes zero backend/governance calls; 18 primitives have no composition layer."

**Decision** (per the wave-016 review): "HARD BLOCK (severity escalates to Critical via Opus; gpt-5.5 confirms gap). Promote F-138 engine-cycle-orchestrator as M3 pre-impl prerequisite."

**Status as of wave-017 / lane-a GREEN:** F-138 GREEN; HARD-BLOCK F1 resolved at the composition-spine level. D-35 in `docs/10-backlog/design-decisions-pending.md` marked resolved with reference to this lane.

## What's wired vs deferred

**Wired (every primitive composed in cycle.ts):**

- F-002 `createAgent` / `createSession` — correlation triple
- F-009 `IBackendProvider.startSession` / `sendPrompt` / `halt` / `stopSession`
- F-014 `closeSession(retro)` — mandatory close-transition boundary
- F-015 `appendAuditEntry` (via thin private `AuditChain` adapter)
- F-018 `HaltDetector.recordToolCall` / `recordSuccess` / `recordFailure` / `manualHalt`
- F-019 `CostLedger` (instantiated; `totalUsd()` reported in RunOutcome)

**Deferred per `no-silent-deferrals.md` (7 honest scope-narrowing notes in ledger §out-of-scope-notes):**

- F-017 redaction NOT yet at audit-egress (audit-egress wave)
- F-021 ladder NOT instantiated (M3 error-path wave)
- F-020 kill-switch polling NOT wired (M3 cron-heartbeat integration)
- F-022 per-spawn quota NOT wired (multi-agent variant; v1 uses global)
- F-002 `stampIdentity` boundary NOT yet at audit-writer (F-006/F-008 wave)
- F-013 `usage` variant NOT yet on `BackendEvent` (D-36 / F-139 — cost rows can't append until then)
- Multi-iteration loop NOT yet (M3+)

## Orchestrator-identity discipline

Per `kit:rules/orchestrator-identity.md` ("ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF"): cycle.ts re-implements ZERO primitive logic.

- It calls `appendAuditEntry` (does not compute hash chains itself).
- It calls `closeSession` (does not validate retro itself).
- It calls `backend.startSession` / `sendPrompt` / `halt` / `stopSession` (does not invoke any SDK directly).
- It calls `halt.manualHalt` / `recordToolCall` / `recordFailure` / `recordSuccess` (does not classify failure patterns itself).

The orchestrator orchestrates; the LOCKED primitives compute.
