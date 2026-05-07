# Wave-17 / Lane A — F-138 engine-cycle-orchestrator NEW (not promotion) RED → GREEN

**Date:** 2026-05-07
**Lane:** wave-017 / lane-a
**Lane theme:** address wave-016 / lane-d Copilot CLI HARD-BLOCK F1 — ship the M3-prerequisite engine-cycle orchestrator that wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014.

## Outcome

| Outcome | Detail |
|---|---|
| RED → GREEN | F-138 engine-cycle-orchestrator (3/3 acceptance scenarios PASS) |
| HARD-BLOCK F1 | RESOLVED at composition-spine level |
| D-35 in design-decisions-pending.md | OPEN → RESOLVED |
| Files added | `packages/engine-core/src/cycle.ts` (~210 LOC); `tests/unit/F-138-engine-cycle-orchestrator.test.ts`; `docs/03-feature-catalog/M0-bootstrap/F-138-engine-cycle-orchestrator.md`; `docs/09-examples-proof/F-138/{red,green}-test-output.txt`; `docs/09-examples-proof/F-138/physical-proof.md`; this lane summary |
| Files updated | `packages/engine-core/src/index.ts` (+ ownership comment + barrel re-export); `docs/03-feature-catalog/M0-bootstrap/README.md` (F-138 row); `roadmap.md` (M0 row + TOTAL row + F-138 row in M0 section + wave-17 transition note); `docs/10-backlog/design-decisions-pending.md` (D-35 marked RESOLVED); `docs/11-loop-state/confidence-ledger.md` (Wave-17 section + 3 entries) |
| Test stability | F-138 isolated 3/3 PASS in 7ms; full unit suite 147/163 (16 pre-existing failures unrelated: F-024/F-025 RED scenarios + F-030 cli-json-output) |

## Behavior contract (from ledger)

`runEngineCycle({backend, prompt, retro})` runs a single MAD-pipeline iteration end-to-end by composing the 18 LOCKED M0/M1/M2 primitives. Returns `RunOutcome {status: 'completed'|'halted', runId, agentId, auditChainHead, haltTrigger?, haltReason?, events, costTotalUsd}`.

## Composition order (no primitive logic re-implemented)

1. `createAgent()` + `createSession()` (F-002) — correlation triple
2. `appendAuditEntry` cycle.start (F-015 via private `AuditChain` adapter)
3. `backend.startSession({agent, session})` (F-009)
4. EITHER: `forceHaltTrigger='manual'` → `halt.manualHalt` → `backend.halt` → halted RunOutcome
   OR: `for await (event of backend.sendPrompt)` → audit each event + halt detection
5. `backend.stopSession(sessionId)` (F-009)
6. `closeSession(retro)` (F-014) — throws RetroMissingError on null/invalid
7. Return RunOutcome with `auditChainHead = audit.headHash()`

## Honest scope-narrowing (per `no-silent-deferrals.md`)

7 numbered notes in ledger §out-of-scope-notes:

1. F-017 redaction NOT yet at audit-egress (audit-egress wave)
2. F-021 ladder NOT instantiated (M3 error-path wave)
3. F-020 kill-switch polling NOT wired (M3 cron-heartbeat integration)
4. F-022 per-spawn quota NOT wired (multi-agent variant; v1 uses global counter)
5. F-002 `stampIdentity` NOT yet at audit-writer (F-006/F-008 wave)
6. F-013 `usage` variant NOT yet on BackendEvent (D-36 / F-139)
7. Multi-iteration loop NOT yet (M3+)

Each cites its follow-on wave home; none silently dropped.

## Orchestrator-identity discipline (canary)

cycle.ts re-implements ZERO primitive logic — every step delegates to a LOCKED primitive. Concretely:

- Calls `appendAuditEntry` (does not compute hash chains itself)
- Calls `closeSession` (does not validate retro itself)
- Calls `backend.startSession` / `sendPrompt` / `halt` / `stopSession` (does not invoke any SDK directly)
- Calls `halt.manualHalt` / `recordToolCall` / `recordFailure` (does not classify failure patterns itself)

This is the canary that prevents the wave-016 HARD-BLOCK from re-emerging in inverted form (an orchestrator that papers over primitive contracts with re-implementation would superficially "wire" the primitives but actually hide their boundaries).

## Wave-016 HARD-BLOCK F1 status

> "No engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014. `bootstrap()` makes zero backend/governance calls; 18 primitives have no composition layer."

— Cross-model: claude-opus-4.7 Critical + gpt-5.5 Major (`docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-016-impl-review.md`)

**RESOLVED** at composition-spine level. v1 single-iteration; multi-turn + ladder/polling/redaction integration follow per ledger §out-of-scope-notes.

## What this lane does NOT close (still wave-17+ candidates)

The wave-016 review surfaced 1 HARD BLOCK + 6 MUST-FIXes + 8 SHOULD-FIXes. F-138 closes the HARD BLOCK only.

The 6 MUST-FIXes remain open:
- F2 IBackendProvider over-normalization (D-?)
- F4 public API barrel leak (D-39)
- F7 F-129..F-134 milestone assignment (D-40)
- F12 IPC contract scaffold under common/ (no D yet)
- F15 no concurrency tests (no D yet)
- F16 no cross-feature integration test (partially addressed by F-138's `RunOutcome` shape — future integration tests can compose runEngineCycle with concurrent calls)

The 8 SHOULD-FIXes (F3 halt-as-kernel, F5 catalog/API mismatch on F-013, F6 catalog/API mismatch on F-022, F8 BackendEvent usage variant per D-36, F9 StubBackend halt-contract per D-38, F10 mutable refs from getEntries/getState, F11 dead code in F-001 exception path, F13 CJS require in killswitch, F17 degradation failure-path coverage, F18 SIGTERM coverage) remain open as wave-17+ candidates.

## Push status

Push at end of lane authorized for this loop session per user directive 2026-05-07. Per `non-negotiable-rules.md`, no destructive git ops; selective `git add <paths>` only; `git status --short` audit before each commit.

## Commits planned (5-commit pattern)

1. `test(F-138): RED — engine-cycle-orchestrator acceptance scenarios + ledger`
2. `feat(F-138): GREEN — runEngineCycle composes F-002/F-009/F-014/F-015/F-018/F-019`
3. `docs(F-138): proof artifacts + M0 README row + ledger transition`
4. `docs(F-138): roadmap + design-decisions-pending D-35 RESOLVED + confidence-ledger`
5. `docs(F-138): wave-017 lane-a summary`

## Reporting metric

- F-138 GREEN: 3/3 PASS
- HARD-BLOCK F1: RESOLVED
- D-35: OPEN → RESOLVED
- Roadmap: M0 +1 feature (8 → 9); TOTAL active +1 (126 → 127)
- 24th feature transition RED → GREEN in the repo
- First NEW (not promotion) feature lane since wave-002 catalog authorship
- First feature whose explicit purpose is to **integrate** prior LOCKED primitives
