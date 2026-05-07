---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-015 / lane-c
    note: "RED → GREEN flip. tests/unit/F-011-copilot-backend.test.ts (7/7 PASS) authored against F-009 session-oriented surface (parity with F-010 wave-015/lane-b). packages/engine-core/src/backend-copilot.ts implements CopilotBackend (origin='copilot', deterministic stub, default model 'gpt-5') with halt-flips-state semantics matching F-010. v1 minimal impl — real Copilot CLI / SDK invocation deferred per ledger out-of-scope-notes (gated on CLI install + device-flow OAuth + recorded-fixture harness)."
  - status: locked
    at: 2026-05-07
    by: wave-016 / lane-a
    note: "GREEN → LOCKED via post-impl council review (verdict ACCEPT, median confidence 87; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE). Review at docs/05-design-reviews/council-reviews/F-011-copilot-sdk-provider-review.md. MINOR findings: stub body defers real Copilot CLI / SDK; ledger scenario 2 (ConfigurationError on missing CLI) impossible to exercise with stub; multi-model catalog validation deferred; F-010 + F-011 share the same coupled deferral set (recorded-fixture harness shape is shared). Cross-provider parity with F-010 is the architectural validation."
feature-id: F-011
short-slug: copilot-sdk-provider
milestone: M1
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
    - cp:src/services/llm/copilot
    - kit:.claude/scripts/Invoke-CopilotMultiModel.ps1
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-011-copilot-backend.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-011-copilot-sdk-provider-review.md exists with verdict: ACCEPT.
depends-on: [F-009]
out-of-scope-notes: |
  Multi-model adversarial dispatch (--council pattern) is owned by M10 (F-082..F-087).
  This feature implements Copilot as one of the providers; the dispatch orchestration
  that selects two-providers-in-parallel lives in M10.
confidence: high
---

# F-011 — GitHub Copilot SDK provider

## Behavior contract

`CopilotProvider` is a concrete `IBackendProvider` wrapping the GitHub Copilot CLI / SDK (`copilot --yolo -p ...` or the equivalent Node SDK when stable). It supports model selection (Claude Opus / GPT-5+ / etc. per Copilot's exposed catalog), streams text deltas mapped to the F-013 normalized shape, and respects cancellation. Authentication uses GitHub's device-flow OAuth; the token is stored per F-070 (deferred — M1 reads from env `COPILOT_TOKEN` with the same `[NEEDS CLARIFICATION]` shape as F-010).

## Acceptance scenarios

1. **Given** a valid Copilot token and `model: "gpt-5"`, **When** `provider.complete("Hello", {model: "gpt-5"})` is iterated, **Then** the stream yields normalized text_delta events and final `message_stop`.
2. **Given** a Copilot CLI that is not installed on the host, **When** the provider is constructed, **Then** the constructor throws `ConfigurationError: copilot CLI not found` with a remediation hint pointing at the install instructions.
3. **Given** an in-progress completion and a `cancel(handle)` call, **When** the cancellation propagates, **Then** the underlying child process is killed and no further deltas arrive.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/backend/copilot-stream.test.ts` | integration | RED — recorded fixture | scenario 1 |
| (TBD) `tests/unit/backend/copilot-cli-missing.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/backend/copilot-cancel.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-009 (must conform to interface)
- **Soft:** F-013 (event normalization shape), F-019 (cost ledger consumes token counts)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | dispatch shape used in --council mode |
| cp:src/services/llm/copilot | clawpilot Copilot SDK wrapping pattern |
| kit:Invoke-CopilotMultiModel.ps1 | local dispatcher precedent for parallel CLI invocation |

## Implementation notes

### wave-015 / lane-c — RED → GREEN flip (2026-05-07)

**Scope deviation from original ledger acceptance scenarios** (intentional, recorded openly per `verification-protocol.md` Rule 1 + `no-silent-deferrals.md`):

- The ledger's three acceptance scenarios reference a `provider.complete(prompt, opts)` shape with a `cancel(handle)` companion. F-009 (wave-014 / lane-d) standardized every backend on a session-oriented surface: `startSession` / `sendPrompt` (returns `AsyncGenerator<BackendEvent>`) / `halt` / `stopSession`. F-011 follows the F-009 contract — same as F-010 (wave-015 / lane-b).
- The session shape is a strict generalization of the iterator-of-events pattern in the original scenarios; the ledger's "stream yields normalized text_delta events and final message_stop" maps to "sendPrompt yields a `token` event then a `finish` event with reason `stop`". The "cancel kills the underlying child process" maps to F-009's `halt` + F-018 `RunHaltedVerdict`.

**v1 minimal impl is a deterministic STUB.** Real Copilot CLI / SDK invocation is gated on:

1. Copilot CLI installed AND authed on the host (device-flow OAuth + entitlement check). The kit's `Invoke-CopilotMultiModel.ps1` does the `which copilot` / `which agency` detection and the `copilot --yolo -p ...` shell-out; the future real-impl swap will mirror that pattern.
2. A recorded-fixture test harness so unit tests do not require a live CLI invocation. The harness shape is shared with F-010's deferred real-Anthropic-SDK harness; both unblock together.

Both deferrals are explicit per the ledger `out-of-scope-notes`. The stub satisfies the F-009 structural contract (origin tag, IBackendProvider compliance, BackendEvent shape correctness, halt composing with F-018 RunHaltedVerdict), so F-012 (factory) and the M10 adversarial-dispatch wave (F-082..F-087) can wire against a real type today. Swapping the stub body for a real CLI/SDK call is a self-contained future change that does not require any other module to update.

**ConfigurationError: copilot CLI not found** (ledger scenario 2) is also deferred. The v1 stub does not shell out, so the missing-CLI failure mode is impossible to exercise. When the real-impl swap lands, the constructor will detect the CLI and throw `ConfigurationError` with a remediation hint.

**Halt semantics are intentionally identical to F-010.** Once `halt(sessionId, verdict)` is called, subsequent `sendPrompt` to the same session yields a single `finish` event with `reason: 'error'` and `details: 'Session halted'`. The session remains registered (so the verdict trigger is observable) until `stopSession` explicitly disposes it. F-018's RUN_HALTED contract requires that callers observe a halt event from the provider, not just an "unknown session" error; F-020 (kill-switch) and F-022 (tool-call quota) both rely on this cross-provider parity.

**Files created / modified:**

- `tests/unit/F-011-copilot-backend.test.ts` — new (7 scenarios; structural witness, prefix-tagged sessionId, token+finish stream with model id surfaced, unknown-session throw, halt yields finish/error, stopSession removes session, halt is idempotent).
- `packages/engine-core/src/backend-copilot.ts` — new (~95 LOC; `CopilotBackend implements IBackendProvider` with `origin = 'copilot'`, default model `'gpt-5'` constructor-injectable, sessions Map + halted Set + halt-flips-state semantics).
- `packages/engine-core/src/index.ts` — re-export added (`export * from './backend-copilot.js'`) + ownership-table comment row appended.
- `docs/09-examples-proof/F-011/{red-test-output.txt, green-test-output.txt, physical-proof.md}` — proof artifacts.
- `roadmap.md` (F-011 row + M1 count + wave-015 transition note + TOTAL) and `docs/11-loop-state/confidence-ledger.md` (wave-015 / lane-c entries) and `docs/06-agent-team-outputs/wave-015/lane-c-summary.md` updated in the same batch.
