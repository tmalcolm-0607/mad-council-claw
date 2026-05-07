---
artifact-class: council-review
feature-id: F-011
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-016 / lane-a
---

# F-011 copilot-sdk-provider — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 89 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 72 |
| architect-lens | Architect | APPROVE | 87 |

Median confidence: 87

## Implementation reviewed

- `packages/engine-core/src/backend-copilot.ts` (~104 LOC) — `CopilotBackend implements IBackendProvider` with `origin = 'copilot'`; constructor takes optional `model` (default `'gpt-5'`); `sessions: Map<string, BackendSessionConfig>` + `halted: Set<string>` for per-session state; `startSession` returns `'copilot-<runId>'`-prefixed sessionId; `sendPrompt` yields one `token` event (model id surfaced in chunk text) then a `finish/stop` event; `halt(sessionId, _verdict)` adds to halted set without removing the session; `stopSession` clears both maps idempotently. Halt semantics intentionally identical to F-010 (cross-provider parity).
- `packages/engine-core/src/index.ts` — barrel re-export `export * from './backend-copilot.js';`.
- `tests/unit/F-011-copilot-backend.test.ts` — 7 scenarios: structural witness (IBackendProvider compliance + origin tag); `startSession` sessionId prefix; `sendPrompt` token+finish stream + model id surfaced; unknown sessionId throws; halt yields finish/error rather than removing session — F-018 RUN_HALTED observability variant matching F-010; `stopSession` removes session; halt is idempotent. 7/7 PASS at GREEN time per ledger §Implementation notes.
- Commit history per `docs/07-roadmap/decision-log.md`: F-011 RED at wave-002 / lane-b (initial ledger only); F-011 GREEN at wave-015 / lane-c.
- GREEN proof: `docs/09-examples-proof/F-011/{red-test-output.txt, green-test-output.txt, physical-proof.md}` exists (verified).

## Advocate lens

**Verdict: APPROVE (confidence 89)**

- Implementation is minimal and correct per `minimum-change.md`. ~104 LOC delivers a complete F-009 IBackendProvider compliance with a deterministic stub body. Symmetric to F-010 (AnthropicBackend) — same shape, same halt semantics, same per-session state pattern. The symmetry is the validation: F-009's contract accepts BOTH concrete providers without contract drift.
- F-011 is the **third M1 feature** flipped (after F-009 LOCKED + F-010 GREEN at wave-015) — proves the F-009 contract surface accepts a second concrete provider class with no contract change. This is the cross-provider parity claim from F-009's review F4 finding, now empirically validated.
- Composition with F-018 RUN_HALTED is identical to F-010 — `halt(sessionId, verdict)` keeps the session registered so subsequent `sendPrompt` yields `finish/error` with `details: 'Session halted'`. F-020 (kill-switch) and F-022 (tool-call quota) work uniformly across both providers per F-018's contract.
- 7/7 acceptance scenarios PASS at GREEN time per ledger §Implementation notes.
- Provider-tagged sessionId (`'copilot-<runId>'`) is forward-compatible with F-019 (cost-ledger) and F-015 (audit-log).
- Constructor accepts `model: string = 'gpt-5'` so F-012's factory + the M10 multi-model adversarial-dispatch wave (F-082..F-087) can pin specific catalog entries (e.g., `'claude-opus-4-7'` for cross-model adversarial review per `lens-multi-model-review-pattern.md`).
- File header lines 33-38 explicitly cite the kit's `Invoke-CopilotMultiModel.ps1` precedent — when the real-SDK swap lands, the future implementation will mirror that dispatcher's `which copilot` / `which agency` detection + `copilot --yolo -p ...` shell-out pattern. Forward path is named.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 72)**

- F-011 is a **stub-shaped** feature today: the ledger is explicit at line 14 and `out-of-scope-notes` at lines 38-41 — real Copilot CLI / SDK invocation is deferred. The current `sendPrompt` yields a hardcoded `[copilot <model>] STUB-RESPONSE-TO: <prompt>` token and a `finish/stop` event. **No actual Copilot CLI shell-out happens.** No process is spawned, no OAuth device flow is exercised, no entitlement check runs. A reader of the ledger contract (lines 45-49) might assume the implementation truly streams from the CLI; the §Implementation notes (lines 81-105) explicitly disclaim this.
- LOCKED status here is therefore narrowly "**F-011 minimal-contract LOCKED**" with the deterministic stub body. The contract is permanent; the real-CLI swap is gated on TWO independent prerequisites per the ledger `out-of-scope-notes`:
  1. Copilot CLI installed AND authed on the host (device-flow OAuth + entitlement check).
  2. A recorded-fixture test harness so unit tests do not require a live CLI invocation.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/backend-copilot.ts` lines 1-104 directly + the ledger lines 1-105 directly. The implementation matches the §Implementation notes; no `child_process` import exists; no `spawn` / `exec` call exists; the stub body is what the file says it is.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): scenario 2 in the ledger (`ConfigurationError: copilot CLI not found`) is impossible to exercise with the stub body — the constructor does not invoke `which copilot` or `which agency`. When the real-CLI swap lands, the constructor must detect the CLI and throw `ConfigurationError` with a remediation hint pointing at the install instructions.
- Suggestion (NON-BLOCKING): the Copilot CLI exposes a multi-model catalog (Claude Opus / GPT-5+ / etc.). The current stub surfaces the model id in the chunk text but does not validate the model against a catalog. When the real-CLI swap lands, the constructor (or the first `sendPrompt` call) should validate the model against the CLI's exposed catalog and throw `UnsupportedModel: <model>` with a hint at the supported set. M10 (multi-model adversarial dispatch) will rely on this.
- The cross-provider parity with F-010 is a strength architecturally, but it does mean F-010 + F-011 share the same deferral set. When F-070 secure-storage lands, BOTH stubs need to be swapped; their unblock conditions are coupled (the recorded-fixture harness shape is shared per the F-010 ledger §Implementation notes line 90-91).

## Architect lens

**Verdict: APPROVE (confidence 87)**

- File-location posture: `packages/engine-core/src/backend-copilot.ts` — correct shape per the wave-011 / lane-a engine-core split convention. F-011's file is owned by F-011; sibling F-010 / F-012 / F-013 own theirs. No engine-core file collisions.
- API surface review:
  - `CopilotBackend implements IBackendProvider` with `readonly origin = 'copilot'` — provider tag is the canonical string for this backend; F-012's factory routes by string-literal kind in the same dispatch shape.
  - Constructor `constructor(private readonly model: string = 'gpt-5')` — model is constructor-injectable; default `'gpt-5'` is Copilot's flagship as of 2026-05; M10's adversarial dispatch wave (F-082..F-087) can pin `'claude-opus-4-7'` per session for the Claude-vs-GPT cross-model pattern.
  - Session/halted Maps + halt-keeps-session-registered semantic: parity with F-010 (AnthropicBackend). The architectural choice to mirror F-010's halt semantics is documented at file header lines 40-48 — F-018's RUN_HALTED contract is uniform across providers.
  - `sendPrompt` is `async *` — async generator returning `AsyncGenerator<BackendEvent>` per F-009. Halt path yields a single `finish/error` event with `details: 'Session halted'` — identical shape to F-010.
  - `halt(sessionId, _verdict)` — accepts `RunHaltedVerdict` from F-018 but does not inspect it. Identical to F-010's stance — for v1 the verdict is the trigger signal, not the cleanup metadata. When the real-CLI swap lands, the verdict's `trigger` field may route different cleanup paths (e.g., `kill_switch` SIGKILLs the child process; `degrade_escalate` waits for the current chunk).
- Composition with F-009 + F-018:
  - Imports: `IBackendProvider`, `BackendEvent`, `BackendSessionConfig` from `./backend.js`; `RunHaltedVerdict` from `./halt.js`. Same imports as F-010, same convention. The wave-011 / lane-a "shared types live with their FIRST owner" convention is reinforced.
  - sessionId prefix `'copilot-<runId>'` parallels F-010's `'anthropic-<runId>'` — both routable by string-prefix in F-019/F-015.
- Cross-provider parity with F-010 is the architecturally-correct shape. The F-009 surface (5 members) is the contract; both AnthropicBackend and CopilotBackend implement it with the same control-flow shape; the only differences are origin string + sessionId prefix + default model. Future SDK-bound features (F-029..F-031 MCP transports, F-184..F-187 Foundry memory) can reuse this pattern per the confidence-ledger `Lane-B-w15-stub-body-vs-deferred-real-SDK-pattern`.
- The kit dispatcher precedent (`Invoke-CopilotMultiModel.ps1` at `.claude/scripts/`) is cited at file header lines 33-38. The future real-CLI swap mirrors that dispatcher's shape — detection, $TEMP_DIR brief, parallel `copilot --yolo -p ...` shell-out, stdout streaming. The forward path is documented and aligned with the kit-vendored pattern in `.claude/rules/lens-multi-model-review-pattern.md`.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-011 is stub-shaped today; real Copilot CLI / SDK invocation is explicitly deferred per ledger `out-of-scope-notes`. Gated on (a) CLI installed + authed and (b) recorded-fixture test harness. | Accept; LOCKED status applies to the minimal-contract scope explicitly. |
| F2 | MINOR | Ledger scenario 2 (`ConfigurationError: copilot CLI not found`) is impossible to exercise with the stub body. The constructor does not detect the CLI. Future real-CLI swap will surface this. | Accept; the deferral is forward-known and documented in the ledger §Implementation notes lines 95-96. |
| F3 | MINOR | Multi-model catalog validation (UnsupportedModel) is not exercised with the stub. M10's multi-model dispatch wave (F-082..F-087) will require it. | Accept; flagged for the future real-CLI swap. |
| F4 | MINOR | F-010 + F-011 share the same deferral set (F-070 secure-storage + recorded-fixture harness). Both stubs unblock together. | Accept; the coupling is by design — the harness shape is shared. |
| F5 | PRAISE | Cross-provider parity with F-010 is the right architectural shape. F-009's contract surface accepts both providers without contract drift; F-018's RUN_HALTED is uniform across providers; F-019/F-015 routing is by string-prefix. | Keep. |
| F6 | PRAISE | The kit dispatcher precedent (`Invoke-CopilotMultiModel.ps1`) is cited at file header lines 33-38 — the future real-CLI swap has a documented and aligned forward path. | Keep. |
| F7 | PRAISE | Constructor-injectable model with default `'gpt-5'` — M10's adversarial-dispatch wave can pin specific catalog entries per session (e.g., `'claude-opus-4-7'`) without requiring a separate provider class. The configuration boundary is at the constructor, not at the provider. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 87).

F-011 minimal-contract is implemented correctly; all 7 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-011 ledger frontmatter (`LOCKED if GREEN AND reviews/F-011-copilot-sdk-provider-review.md exists with verdict: ACCEPT`).

The MINOR findings F1+F2+F3+F4 are honest scope-narrowing notes per `no-silent-deferrals.md` — the stub body and the impossible-to-exercise-with-stub scenarios are explicit in the ledger `out-of-scope-notes` + §Implementation notes. The cross-provider deferral coupling (F4) is by design. Nothing is silent.

F-011 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M1-backend/F-011-copilot-sdk-provider.md`
- Source: `packages/engine-core/src/backend-copilot.ts` (~104 LOC)
- Tests: `tests/unit/F-011-copilot-backend.test.ts` (7/7 PASS)
- GREEN proof: `docs/09-examples-proof/F-011/` (red-test-output + green-test-output + physical-proof)
- GREEN transition: decision-log.md F-011 row; wave-015 / lane-c
- Composing features: F-009 (`IBackendProvider`, `BackendEvent`, `BackendSessionConfig`), F-018 (`RunHaltedVerdict`)
- Sibling feature: F-010 (AnthropicBackend, mirrored shape)
- Pattern: confidence-ledger `Lane-B-w15-stub-body-vs-deferred-real-SDK-pattern` + `Lane-C-w15-cross-provider-parity-pattern`
- Kit precedent: `.claude/scripts/Invoke-CopilotMultiModel.ps1` + `.claude/rules/lens-multi-model-review-pattern.md`
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
