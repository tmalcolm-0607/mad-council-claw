---
artifact-class: feature-ledger
generated-by: hand-authored (wave-017 / lane-a)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-017 / lane-a
    note: "Initial creation; behavior contract + 3 acceptance scenarios drafted; addresses wave-016/lane-d Copilot CLI HARD-BLOCK F1 (no engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014). RED test scaffold authored alongside ledger."
  - status: green
    at: 2026-05-07
    by: wave-017 / lane-a
    note: "RED test scaffold + impl landed in same lane (RED-then-GREEN micro-session per wave-5 retro proposal). Test at tests/unit/F-138-engine-cycle-orchestrator.test.ts; impl at packages/engine-core/src/cycle.ts (~120 LOC: runEngineCycle composes F-002 createAgent/createSession + F-009 IBackendProvider startSession/sendPrompt/stopSession + F-018 HaltDetector + F-019 CostLedger + F-015 appendAuditEntry + F-014 closeSession). 3/3 acceptance scenarios passing. Resolves wave-016 HARD-BLOCK F1; F-138 IS the M3-prerequisite composition layer the 18 LOCKED M0/M1/M2 primitives lacked."
feature-id: F-138
short-slug: engine-cycle-orchestrator
milestone: M0
provenance:
  surfaces:
    - ce:FR-LIFECYCLE-001
    - kit:rules/orchestrator-identity.md
    - cp:src/engine/cycle
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-138-engine-cycle-orchestrator.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-138-engine-cycle-orchestrator-review.md exists with verdict: ACCEPT.
green-evidence:
  test-runner: vitest@2.1.9 (project: unit, filter: tests/unit/F-138)
  scenarios-passing: 3
  scenarios-total: 3
depends-on: [F-001, F-002, F-009, F-014, F-015, F-018, F-019]
out-of-scope-notes: |
  Per `rules/no-silent-deferrals.md`, the v1 surface is intentionally narrow:

  - **F-017 audit-pii-redaction integration**: cycle.ts records audit entries
    via appendAuditEntry but does NOT pipe them through `redact()` before
    write. Redaction is a future audit-egress wave's job; F-138 lands the
    composition spine, not the per-event sanitization pass.

  - **F-021 degradation-fallback ladder**: cycle.ts has no DegradationLadder
    instance; backend errors mid-stream propagate as `finish/error` events
    that the halt detector consumes via recordFailure. The escalation ladder
    (skill-fallback → model-fallback → reduced-tool-set → headless) wires in
    when real backend errors land in M3.

  - **F-020 kill-switch polling**: cycle.ts does NOT instantiate a KillSwitch
    watcher. The `forceHaltTrigger: 'manual'` test seam exercises the manual
    halt verdict shape (HaltDetector.manualHalt) without the file-system
    polling loop. Real kill-switch integration lands in M3 when the
    cron-heartbeat (F-023) is wired.

  - **F-022 per-spawn tool-call quota**: cycle.ts uses HaltDetector's GLOBAL
    `recordToolCall` (trigger=`tool_calls_quota`); the per-spawn (per
    agent_id) variant from F-022 (trigger=`tool_calls`) is not yet wired.
    Single-agent runs are the v1 scope.

  - **F-002 stamp on every audit entry**: cycle.ts threads `agent_id` /
    `run_id` into the cycle audit event payload but does NOT call
    `stampIdentity` at the audit-writer boundary; F-006 logging-pipeline +
    F-008 storage-layout integrations will close that gap when persistence
    lands. The IDENTITY_MISSING boundary contract from F-002 stays
    authoritative for downstream composers.

  - **F-013 event-normalization usage variant**: cycle.ts does NOT compute
    cost-ledger rows from BackendEvent because BackendEvent has no `usage`
    variant per wave-016 D-36. CostLedger is instantiated and its `totalUsd()`
    is reported in RunOutcome, but no rows are appended in v1. F-139
    backend-event-usage-variant (D-36) closes this gap.

  - **Multi-iteration cycle loop**: v1 runs ONE prompt → one event stream →
    one close. Multi-turn conversation, tool-call → tool-result round trips,
    and iteration-cap drive (HaltDetector.recordIteration) are M3+.

  These are the 7 honest scope-narrowing notes; every primitive F-138
  composes is LOCKED, so the composition itself is the v1 deliverable.

  Filesystem persistence (runs/<run_id>/manifest.json, audit.ndjson,
  cost-ledger.ndjson, retro.json) belongs to F-008 storage-layout and lands
  in M3 when F-138's RunOutcome shape is wired through to disk via the
  storage atomicWriteJson primitive.
confidence: high
---

# F-138 — Engine-cycle orchestrator

## Behavior contract

The engine-cycle orchestrator runs a single MAD-pipeline iteration end-to-end by composing the 18 LOCKED M0/M1/M2 primitives. `runEngineCycle({backend, prompt, retro})` spawns an agent + session (F-002), opens a backend session (F-009), audits every lifecycle event (F-015), tracks halt triggers (F-018), records cost-ledger state (F-019), and closes with a mandatory retro signal (F-014). It returns a structured `RunOutcome` with the run's `status` (`completed` | `halted`), correlation triple, audit chain head, halt trigger (when halted), the captured event stream, and the cost total. The orchestrator is the integration spine that makes the 18 standalone primitives observable as a single MAD pipeline.

## Acceptance scenarios

1. **Given** a configured orchestrator with a StubBackend, **When** `runEngineCycle({backend, prompt, retro})` is called with a single user prompt, **Then** the orchestrator returns a `RunOutcome` with `status='completed'`, a UUID-v7 `runId`, a UUID-v7 `agentId`, and a 64-hex `auditChainHead`.
2. **Given** an orchestrator configured with `forceHaltTrigger='manual'` (test seam exercising HaltDetector.manualHalt + IBackendProvider.halt), **When** `runEngineCycle(...)` is called, **Then** the orchestrator returns a `RunOutcome` with `status='halted'`, `haltTrigger='manual'`, and `haltReason` carrying the test-driven halt rationale.
3. **Given** an orchestrator whose `retro` factory returns `null`, **When** `runEngineCycle(...)` is called, **Then** the F-014 `closeSession` boundary throws `RetroMissingError` (the run's mandatory close transition fails per F-014's RETRO_MISSING contract).

## Red→green wire-up

| Test file | Project | Final state | Verifies |
|---|---|---|---|
| `tests/unit/F-138-engine-cycle-orchestrator.test.ts` | unit | GREEN — 3/3 scenarios PASS | scenarios 1, 2, 3 |

## Dependencies

- **Hard:**
  - F-001 (engine-bootstrap-loop) — lifecycle scaffold the cycle orchestrator extends from in-memory primitive to event-driven composition
  - F-002 (per-agent-identity-runid) — `createAgent` + `createSession` allocate the correlation triple
  - F-009 (ibackendprovider) — `IBackendProvider.startSession` / `sendPrompt` / `halt` / `stopSession` is the backend surface
  - F-014 (pre-close-retro-signal) — `closeSession(retro)` is the mandatory close-transition boundary
  - F-015 (hash-chained-audit-log) — `appendAuditEntry` records every cycle lifecycle event (`cycle.start`, `backend.session.start`, `backend.event`, `cycle.halted`, `backend.session.stop`, `cycle.end`)
  - F-018 (failure-pattern-halt) — `HaltDetector` emits the `RunHaltedVerdict` shape consumed by the halted-path RunOutcome and threaded through `IBackendProvider.halt`
  - F-019 (cost-ledger) — `CostLedger` is instantiated; `totalUsd()` reported in RunOutcome (no rows appended in v1 pending F-139 usage-variant)
- **Soft:** F-006 (logging pipeline — future audit-event sink), F-008 (storage layout — future runs/<run_id>/ persistence), F-017 (PII redaction — future audit-egress sanitization), F-021 (degradation-fallback — future error-path escalation), F-020 (kill-switch — future cron-driven halt poller), F-022 (per-spawn tool-call quota — multi-agent variant)

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-LIFECYCLE-001 | end-to-end MAD-pipeline single-iteration orchestration |
| kit:rules/orchestrator-identity.md | "compose; do not re-implement" — orchestrator delegates to LOCKED primitives without re-doing their work |
| cp:src/engine/cycle | clawpilot per-cycle orchestrator pattern |

## Implementation notes

Wave-17 / Lane A — first NEW (not promotion) feature lane in the repo and the first feature whose explicit purpose is to **integrate** prior LOCKED primitives.

- Implementation: `packages/engine-core/src/cycle.ts` — exports `runEngineCycle`, `EngineCycleConfig`, `RunOutcome`.
- Public surface (3 symbols):
  - `runEngineCycle(config: EngineCycleConfig): Promise<RunOutcome>` — async dispatcher.
  - `EngineCycleConfig` — `{backend, prompt, retro, maxToolCalls?, maxIterations?, forceHaltTrigger?}`.
  - `RunOutcome` — `{status: 'completed'|'halted', runId, agentId, auditChainHead, haltTrigger?, haltReason?, events, costTotalUsd}`.
- Composition order:
  1. `createAgent()` + `createSession()` (F-002) — allocates correlation triple.
  2. `appendAuditEntry(audit, {cycle: 1, action: 'cycle.start', fields: {agent_id, run_id}})` (F-015).
  3. `backend.startSession({agent, session})` (F-009) — opens provider session.
  4. Audit `backend.session.start` event.
  5. If `forceHaltTrigger==='manual'`: `halt.manualHalt(reason)` → `backend.halt(sessionId, verdict)` → audit `cycle.halted` → `backend.stopSession(sessionId)` → return halted RunOutcome.
  6. Else: iterate `for await (event of backend.sendPrompt(sessionId, prompt))`:
     - Audit each event.
     - On `tool_call`: `halt.recordToolCall()` (F-018 / F-022 global counter); break loop on halt verdict.
     - On `finish` with reason `stop`: `halt.recordSuccess()` (resets failure streak); break loop.
     - On `finish` with reason `error`: `halt.recordFailure()`; break loop on halt verdict.
  7. `backend.stopSession(sessionId)` (F-009).
  8. Audit `backend.session.stop`.
  9. `closeSession(retro())` (F-014) — throws `RetroMissingError` if retro is null/invalid.
  10. Audit `cycle.end`.
  11. Return RunOutcome with `auditChainHead = audit.getRows()[last].hash`.
- **wave-016 HARD-BLOCK F1 status: RESOLVED** — both Opus and gpt-5.5 flagged "no engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014" as HARD BLOCK on M3 entry. F-138 GREEN ships the composition spine; D-35 in `docs/10-backlog/design-decisions-pending.md` is marked resolved.
- **Scope-deviation discipline** per `no-silent-deferrals.md`: 7 honest scope-narrowing notes in `out-of-scope-notes` enumerate every primitive that is composed but not yet end-to-end wired (F-017 redaction, F-021 ladder, F-020 polling, F-022 per-spawn, F-002 stamp, F-013 usage variant, multi-iteration loop). Each has a follow-on wave home; none silently dropped.
- **Anti-orchestrator-impostor discipline** per `kit:rules/orchestrator-identity.md`: cycle.ts NEVER re-implements primitive logic. It calls `appendAuditEntry` (does not compute hash chains itself), it calls `closeSession` (does not validate retro itself), it calls `backend.startSession` (does not invoke any SDK directly). The orchestrator orchestrates; the primitives compute.
- **Test seams**: `forceHaltTrigger: 'manual'` exercises the halt path without requiring a contrived backend error injection. `maxToolCalls: 0` is the natural-halt path the seam mirrors; both produce the same RunOutcome shape.
- **AuditChain helper-class scope**: cycle.ts uses a thin `AuditChain` adapter class wrapping `appendAuditEntry` for ergonomics (`audit.append('action', fields)` instead of threading the array through every call site). The adapter is private to cycle.ts; callers consuming `RunOutcome.auditChainHead` see the F-015 `entry_sha256` value unchanged. F-016 `queryAuditLog` continues to work on the underlying array; the adapter is a thin alias.
- **Cross-lane staging-discipline**: per user directive 2026-05-07, NO `git reset` (any flavor) for staging-race recovery; explicit `git add <paths>` for each commit; `git status --short` audit before each commit. Push at end of lane authorized for this loop session.
