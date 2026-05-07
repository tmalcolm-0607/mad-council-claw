---
artifact-class: council-review
feature-id: F-010
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-016 / lane-a
---

# F-010 anthropic-sdk-provider — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 73 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/backend-anthropic.ts` (~91 LOC) — `AnthropicBackend implements IBackendProvider` with `origin = 'anthropic'`; constructor takes optional `model` (default `'claude-opus-4-7'`); `sessions: Map<string, BackendSessionConfig>` + `halted: Set<string>` for per-session state; `startSession` returns `'anthropic-<runId>'`-prefixed sessionId; `sendPrompt` yields one `token` event (model id surfaced in chunk text) then a `finish/stop` event; `halt(sessionId, _verdict)` adds to halted set without removing the session; `stopSession` clears both maps idempotently.
- `packages/engine-core/src/index.ts` — barrel re-export `export * from './backend-anthropic.js';`.
- `tests/unit/F-010-anthropic-backend.test.ts` — 7 scenarios: structural witness (IBackendProvider compliance + origin tag); `startSession` sessionId prefix; `sendPrompt` token+finish stream + model id surfaced; unknown sessionId throws; halt yields finish/error rather than removing session — F-018 RUN_HALTED observability variant; `stopSession` removes session; halt is idempotent. 7/7 PASS at GREEN time per ledger §Implementation notes.
- Commit history per `docs/07-roadmap/decision-log.md`: F-010 RED at wave-002 / lane-b (initial ledger only); F-010 GREEN at wave-015 / lane-b (impl landed inside the cross-lane staging-race commit `1499d07` per the wave-015 / lane-b summary's documented stowaway).

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. ~91 LOC delivers a complete F-009 IBackendProvider compliance with a deterministic stub body. No premature abstraction — no helper functions invented before they have a caller, no model catalog, no retry policy.
- F-010 is the **second M1 feature** flipped (after F-009 LOCKED at wave-015 / lane-a) — proves the F-009 contract surface accepts a concrete provider class without any contract drift. The session shape (`startSession` / `sendPrompt` / `halt` / `stopSession`) maps cleanly onto a real Anthropic SDK call site (the future swap is documented at the file header lines 13-28).
- Composition with F-018 RUN_HALTED is clean. The halt-keeps-session-registered semantic (vs StubBackend's halt-removes-session) makes the `finish/error` event observable to callers — F-020 (kill-switch) and F-022 (tool-call quota) both depend on this cross-provider parity per the F-009 review F4 + F7 findings. The divergence is intentional and documented at the file header lines 30-39.
- 7/7 acceptance scenarios PASS at GREEN time. Full suite at GREEN time: 129/129 across 19 test files (per ledger §Implementation notes line 105).
- Provider-tagged sessionId (`'anthropic-<runId>'`) is forward-compatible with F-019 (cost-ledger) and F-015 (audit-log) — both can route by prefix without re-deriving the origin from `provider.origin`.
- Constructor accepts `model: string = 'claude-opus-4-7'` so F-012 (factory, GREEN at wave-015 / lane-d, GREEN → LOCKED candidate in this same wave-016 batch) can pin a specific model entry per instance.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 73)**

- F-010 is a **stub-shaped** feature today: the ledger is explicit at line 14 and `out-of-scope-notes` at lines 38-40 — real `@anthropic-ai/sdk` integration is deferred. The current `sendPrompt` yields a hardcoded `[anthropic <model>] STUB-RESPONSE-TO: <prompt>` token and a `finish/stop` event. **No actual Anthropic API call happens.** A reader of the ledger contract (lines 44-54) might assume the implementation truly streams from the SDK; the §Implementation notes (lines 79-105) explicitly disclaim this.
- LOCKED status here is therefore narrowly "**F-010 minimal-contract LOCKED**" with the deterministic stub body. The contract is permanent (the F-009 IBackendProvider surface, the origin tag, the BackendEvent shape correctness, the halt-composing-with-F-018 RunHaltedVerdict semantic). The real-SDK swap is a future self-contained change that does not require any other module to update.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/backend-anthropic.ts` lines 1-91 directly + the ledger lines 1-105 directly. The implementation matches the §Implementation notes; no `@anthropic-ai/sdk` import exists; the stub body is what the file says it is.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when F-070 secure-storage lands and the recorded-fixture test harness ships, the wave that swaps the stub body for a real SDK call should re-verify that the F-009 session-oriented contract maps cleanly to Anthropic's `messages.stream()` API. The ledger §Behavior contract (line 48) names `messages.stream()` explicitly — the future swap should preserve the iterator-of-events shape (sendPrompt returns AsyncGenerator<BackendEvent>) without altering the contract.
- Suggestion (NON-BLOCKING): scenario 3 in the ledger (`ConfigurationError: ANTHROPIC_API_KEY missing`) is currently impossible to exercise — the stub does not read any environment variable. When the real-SDK swap lands, the constructor must detect missing credentials and throw `ConfigurationError` with a clear remediation hint pointing at F-070 secure-storage.
- Halt-semantics divergence from StubBackend (halt-keeps-session vs halt-removes-session) is intentional and documented at file header lines 30-39, but a reader who only sees the F-009 review F6 PRAISE for StubBackend's idempotent halt might be surprised when AnthropicBackend's halt does not remove the session. The §Implementation notes paragraph at lines 80-97 + the file header are the authoritative explanation.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-location posture: `packages/engine-core/src/backend-anthropic.ts` — correct shape per the wave-011 / lane-a engine-core split convention (per-feature files instead of a single `index.ts`). F-009 owns its file; F-010 owns its file; F-011 / F-012 / F-013 own theirs. Clean separation of concerns; the wave-15 4-concurrent-lane staging-race churn on `index.ts` (per the wave-015 / lane-d staging-discipline-sighting-15 entry) was the only contention point and was resolved via per-lane re-application of barrel exports.
- API surface review:
  - `AnthropicBackend implements IBackendProvider` with `readonly origin = 'anthropic'` — provider tag is a string literal, matching the F-009 design choice that adding a new backend doesn't require a type-system change. F-010 contributes the canonical `'anthropic'` value to the convention.
  - Constructor `constructor(private readonly model: string = 'claude-opus-4-7')` — model is constructor-injectable so F-012's factory can forward an opt-in model id. Default `'claude-opus-4-7'` is the current Claude flagship as of 2026-05; pinning here is acceptable for v1, with the understanding that F-124 (multi-tier model routing, frontier-research candidate) layers above F-012 to choose models per-tier.
  - `sessions: Map<string, BackendSessionConfig>` + `halted: Set<string>` — per-session state is per-instance (not module-level), which means parallel sessions across one AnthropicBackend instance work correctly. The `Map`/`Set` choice is appropriate; no concurrency primitive needed (Node.js single-threaded event loop) for the v1 stub.
  - `sendPrompt` is `async *` — async generator. F-009's `AsyncGenerator<BackendEvent>` return type is honored. Halt path yields a single `finish/error` event with `details: 'Session halted'` — F-018 RUN_HALTED contract is honored.
  - `halt(sessionId, _verdict)` — accepts `RunHaltedVerdict` from F-018 but does NOT inspect it (`_verdict` prefixed with underscore). For v1 this is acceptable: the verdict is the trigger signal, not the cleanup metadata. When the real-SDK swap lands, the verdict's `trigger` field may route different cleanup paths (e.g., `kill_switch` aborts mid-stream; `degrade_escalate` waits for current chunk).
- Composition with F-009 + F-018 + F-019 forward path:
  - Imports: `IBackendProvider`, `BackendEvent`, `BackendSessionConfig` from `./backend.js` (F-009's file); `RunHaltedVerdict` from `./halt.js` (F-018's file). The wave-011 / lane-a "shared types live with their FIRST owner" convention extends across milestones cleanly.
  - sessionId prefix `'anthropic-<runId>'` — F-019 (cost-ledger, LOCKED at wave-13 / lane-d) can route by prefix to attribute cost; F-015 (audit-log, LOCKED at wave-13 / lane-c) can tag entries by provider without re-deriving from the origin string.
- Halt-semantics divergence from StubBackend is the right call architecturally. F-018's RUN_HALTED contract requires that callers observe a halt event from the provider; an "Unknown session" throw (StubBackend's path) is OK for a deterministic test fixture but loses observability for production providers. The divergence is documented at file header lines 30-39 and in the F-010 ledger §Implementation notes.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-010 is stub-shaped today; real `@anthropic-ai/sdk` integration is explicitly deferred per ledger `out-of-scope-notes`. Gated on F-070 secure-storage + recorded-fixture test harness. | Accept; LOCKED status applies to the minimal-contract scope explicitly. |
| F2 | MINOR | Ledger scenario 3 (`ConfigurationError: ANTHROPIC_API_KEY missing`) is impossible to exercise with the stub body; the constructor does not read any environment variable. Future real-SDK swap will surface this. | Accept; the deferral is forward-known and documented in the ledger §Implementation notes. |
| F3 | MINOR | Halt-semantics divergence from StubBackend (halt-keeps-session vs halt-removes-session) is intentional but a reader might be surprised. Documented at file header lines 30-39 and in §Implementation notes. | Accept; the divergence is required by F-018's RUN_HALTED observability contract; F-020 + F-022 depend on it. |
| F4 | MINOR | Default model `'claude-opus-4-7'` is pinned in the constructor. When F-124 (multi-tier model routing) lands, callers may want to override per-tier; the constructor parameter already supports this. | Accept; the `model` parameter is the override point. |
| F5 | PRAISE | Provider-tagged sessionId (`'anthropic-<runId>'`) makes F-019 (cost-ledger) + F-015 (audit-log) routing trivial. Forward-compatible with cross-provider features. | Keep. |
| F6 | PRAISE | Halt-semantics divergence is the right architectural call: F-018's RUN_HALTED contract requires a halt event from the provider, not just an "Unknown session" throw. Cross-provider parity with F-011 (CopilotBackend) per the F-011 review F-010-mirror finding. | Keep. |
| F7 | PRAISE | The "stub-body-vs-deferred-real-SDK" pattern (named in confidence-ledger Lane-B-w15-stub-body-vs-deferred-real-SDK-pattern) is a clean boundary: concrete class implements the real interface; stub body satisfies the structural contract; future swap is self-contained. F-029..F-031 MCP transports + F-184..F-187 Foundry memory should reuse this pattern. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-010 minimal-contract is implemented correctly; all 7 acceptance scenarios pass per the recorded test outputs (full suite 129/129 at GREEN time per ledger §Implementation notes); no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-010 ledger frontmatter (`LOCKED if GREEN AND reviews/F-010-anthropic-sdk-provider-review.md exists with verdict: ACCEPT`).

The MINOR findings F1+F2 are honest scope-narrowing notes per `no-silent-deferrals.md` — the stub body and the impossible-to-exercise-with-stub scenarios are explicit in the ledger `out-of-scope-notes` + §Implementation notes. F3 (halt semantics) and F4 (default model) are design choices documented at the file header. Nothing is silent.

F-010 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M1-backend/F-010-anthropic-sdk-provider.md`
- Source: `packages/engine-core/src/backend-anthropic.ts` (~91 LOC)
- Tests: `tests/unit/F-010-anthropic-backend.test.ts` (7/7 PASS)
- GREEN transition: decision-log.md F-010 row; impl landed in cross-lane stowaway commit `1499d07`; wave-015 / lane-b
- Composing features: F-009 (`IBackendProvider`, `BackendEvent`, `BackendSessionConfig`), F-018 (`RunHaltedVerdict`)
- Sibling feature: F-011 (CopilotBackend, mirrored shape)
- Pattern: confidence-ledger `Lane-B-w15-stub-body-vs-deferred-real-SDK-pattern`
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
