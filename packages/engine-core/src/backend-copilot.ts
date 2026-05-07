/**
 * F-011 GitHub Copilot SDK provider — GREEN.
 *
 * Per docs/03-feature-catalog/M1-backend/F-011-copilot-sdk-provider.md.
 *
 * Behavior contract (from ledger):
 *   CopilotBackend is a concrete IBackendProvider wrapping the GitHub Copilot
 *   CLI / SDK. v1 implements the F-009 session-oriented surface (startSession
 *   / sendPrompt / halt / stopSession) and tags itself with origin === 'copilot'
 *   so F-012's factory can route by origin and F-019 can attribute cost. The
 *   Copilot CLI exposes a multi-model catalog (Claude Opus / GPT-5+ / etc.);
 *   the model is selectable per-instance via constructor.
 *
 * v1 minimal-impl note (intentional, documented):
 *   This implementation uses a deterministic STUB internally — it does NOT
 *   shell out to the Copilot CLI (`copilot --yolo -p ...`) or call any
 *   Copilot Node SDK. Real integration is gated on:
 *     (a) Copilot CLI being installed AND authed (device-flow OAuth +
 *         entitlement check) on the host, and
 *     (b) a recorded-fixture test harness so unit tests do not require a
 *         live CLI invocation.
 *   Both are explicit out-of-scope per the F-011 ledger out-of-scope-notes
 *   (multi-model adversarial dispatch is M10 / F-082..F-087; v1 here is
 *   the single-provider concrete impl).
 *
 *   The stub satisfies the F-009 structural contract (origin tag,
 *   IBackendProvider compliance, BackendEvent shape correctness, halt
 *   composing with F-018 RunHaltedVerdict), so F-012 (factory) and the
 *   M10 adversarial-dispatch wave can wire against a real type today.
 *   Swapping the stub body for a real CLI/SDK call is a self-contained
 *   future change that does not require any other module to update.
 *
 *   Per the kit's `lens-multi-model-review-pattern.md` (vendored from
 *   LENS-Common PR #5138039) and `Invoke-CopilotMultiModel.ps1`, the
 *   future real-impl swap will mirror the existing dispatcher: detect
 *   `which copilot` / `which agency`, save the brief to $TEMP_DIR, spawn
 *   `copilot --yolo -p ...` with `-m <model>` selecting the catalog
 *   entry, and stream stdout deltas into BackendEvent shape.
 *
 * Halt semantics (composes with F-018, parity with F-010):
 *   Once halt(sessionId, verdict) is called, subsequent sendPrompt to the
 *   same session yields a single 'finish' event with reason 'error' and
 *   `details: 'Session halted'`. The session remains registered (so the
 *   verdict trigger is observable) until stopSession explicitly disposes
 *   it. This is the same shape F-010 (AnthropicBackend) uses; F-018's
 *   RUN_HALTED contract requires that callers observe a halt event from
 *   the provider, not just an "unknown session" error. F-020 (kill-switch)
 *   and F-022 (tool-call quota) both rely on this cross-provider parity.
 */

import type { IBackendProvider, BackendEvent, BackendSessionConfig } from './backend.js';
import type { RunHaltedVerdict } from './halt.js';

export class CopilotBackend implements IBackendProvider {
  readonly origin = 'copilot';
  private readonly sessions = new Map<string, BackendSessionConfig>();
  private readonly halted = new Set<string>();

  // Default model: Copilot's flagship as of 2026-05. Constructor-injectable so
  // F-012's factory + the M10 multi-model dispatch wave can pin a specific
  // catalog entry per session (e.g. 'claude-opus-4-7' for the cross-model
  // adversarial pattern).
  constructor(private readonly model: string = 'gpt-5') {}

  async startSession(config: BackendSessionConfig): Promise<{ sessionId: string }> {
    // Provider-tagged session id so F-019 (cost-ledger) and F-015 (audit-log)
    // can route by prefix without re-deriving the origin. Mirrors F-010.
    const sessionId = `copilot-${config.session.runId}`;
    this.sessions.set(sessionId, config);
    return { sessionId };
  }

  async *sendPrompt(sessionId: string, prompt: string): AsyncGenerator<BackendEvent> {
    if (!this.sessions.has(sessionId)) {
      throw new Error(`Unknown session: ${sessionId}`);
    }
    if (this.halted.has(sessionId)) {
      // F-018 RUN_HALTED observability: emit a finish/error event so callers
      // see WHY the response stopped. Do not throw — the session is still
      // registered; the halt-trigger is the signal, not an exception. Parity
      // with F-010 AnthropicBackend.
      yield { type: 'finish', reason: 'error', details: 'Session halted' };
      return;
    }
    // Deterministic stub stream: one token chunk + one finish event. The
    // model id is surfaced in the chunk text so traceability is observable
    // at the test boundary without a separate metadata channel. Mirrors F-010.
    yield { type: 'token', text: `[copilot ${this.model}] STUB-RESPONSE-TO: ${prompt}` };
    yield { type: 'finish', reason: 'stop' };
  }

  async halt(sessionId: string, _verdict: RunHaltedVerdict): Promise<void> {
    // Idempotent: Set#add is naturally idempotent. We do NOT remove the
    // session from `sessions` here — see Halt semantics in the file header.
    this.halted.add(sessionId);
  }

  async stopSession(sessionId: string): Promise<void> {
    // Idempotent: Map#delete and Set#delete return false on missing keys
    // without throwing — exactly the no-op semantics F-009 requires.
    this.sessions.delete(sessionId);
    this.halted.delete(sessionId);
  }
}
