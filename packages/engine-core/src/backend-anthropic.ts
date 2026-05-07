/**
 * F-010 Anthropic SDK provider — GREEN.
 *
 * Per docs/03-feature-catalog/M1-backend/F-010-anthropic-sdk-provider.md.
 *
 * Behavior contract (from ledger):
 *   AnthropicBackend is a concrete IBackendProvider wrapping the Anthropic
 *   Claude SDK. v1 implements the F-009 session-oriented surface
 *   (startSession / sendPrompt / halt / stopSession) and tags itself with
 *   origin === 'anthropic' so F-012's factory can route by origin and F-019
 *   can attribute cost.
 *
 * v1 minimal-impl note (intentional, documented):
 *   This implementation uses a deterministic STUB internally — it does NOT
 *   call @anthropic-ai/sdk over the network. Real SDK integration is gated
 *   on (a) F-070 secure-storage for ANTHROPIC_API_KEY (per ledger
 *   `[NEEDS CLARIFICATION: secure storage]` note) and (b) a recorded-fixture
 *   test harness so unit tests do not require a live API key + network.
 *   Both are explicit out-of-scope per the F-010 ledger
 *   `out-of-scope-notes` and the F-126 (NEW context-budget-allocation) M8
 *   roadmap entry.
 *
 *   The stub satisfies the F-009 structural contract (origin tag,
 *   IBackendProvider compliance, BackendEvent shape correctness, halt
 *   composing with F-018 RunHaltedVerdict), so F-012 (factory) and
 *   downstream callers can wire against a real type today. Swapping the
 *   stub body for a real SDK call is a self-contained future change that
 *   does not require any other module to update.
 *
 * Halt semantics (composes with F-018):
 *   Once halt(sessionId, verdict) is called, subsequent sendPrompt to the
 *   same session yields a single 'finish' event with reason 'error' and
 *   `details: 'Session halted'`. The session remains registered (so the
 *   verdict trigger is observable) until stopSession explicitly disposes
 *   it. This differs from StubBackend's halt-removes-session behavior
 *   intentionally: F-018's RUN_HALTED contract requires that callers
 *   observe a halt event from the provider, not just an "unknown session"
 *   error. F-020 (kill-switch) and F-022 (tool-call quota) both rely on
 *   this distinction.
 */

import type { IBackendProvider, BackendEvent, BackendSessionConfig } from './backend.js';
import type { RunHaltedVerdict } from './halt.js';

export class AnthropicBackend implements IBackendProvider {
  readonly origin = 'anthropic';
  private readonly sessions = new Map<string, BackendSessionConfig>();
  private readonly halted = new Set<string>();

  constructor(private readonly model: string = 'claude-opus-4-7') {}

  async startSession(config: BackendSessionConfig): Promise<{ sessionId: string }> {
    // Provider-tagged session id so F-019 (cost-ledger) and F-015 (audit-log)
    // can route by prefix without re-deriving the origin.
    const sessionId = `anthropic-${config.session.runId}`;
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
      // registered; the halt-trigger is the signal, not an exception.
      yield { type: 'finish', reason: 'error', details: 'Session halted' };
      return;
    }
    // Deterministic stub stream: one token chunk + one finish event. The
    // model id is surfaced in the chunk text so traceability is observable
    // at the test boundary without a separate metadata channel.
    yield { type: 'token', text: `[anthropic ${this.model}] STUB-RESPONSE-TO: ${prompt}` };
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
