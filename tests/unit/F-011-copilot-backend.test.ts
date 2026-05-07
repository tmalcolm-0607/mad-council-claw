import { describe, it, expect } from 'vitest';
import {
  CopilotBackend,
  createAgent,
  createSession,
  type IBackendProvider,
  type BackendEvent,
  type BackendSessionConfig,
  type RunHaltedVerdict,
} from '@mad-council-claw/engine-core';

/**
 * F-011 GitHub Copilot SDK provider — RED → GREEN test.
 * Per docs/03-feature-catalog/M1-backend/F-011-copilot-sdk-provider.md.
 *
 * Behavior contract (from ledger):
 *   CopilotBackend is a concrete IBackendProvider wrapping the GitHub Copilot
 *   CLI / SDK (`copilot --yolo -p ...` or the equivalent Node SDK when
 *   stable). It supports model selection from Copilot's exposed catalog
 *   (Claude Opus / GPT-5+ / etc.), streams text deltas mapped to the F-013
 *   normalized shape, and respects cancellation. Authentication uses
 *   GitHub's device-flow OAuth; the token is stored per F-070 (deferred —
 *   M1 reads from env COPILOT_TOKEN with the same `[NEEDS CLARIFICATION]`
 *   shape as F-010).
 *
 * Scope deviation from ledger (intentional, documented per the wave-014 / lane-d
 * + F-009 + wave-015 / lane-b F-010 precedent):
 *   The F-011 ledger acceptance scenarios reference a `provider.complete()`
 *   shape with a `cancel(handle)` companion. F-009's session-oriented surface
 *   (startSession / sendPrompt / halt / stopSession) is the agreed concrete
 *   shape every backend implements; F-011 follows it — same as F-010.
 *
 *   v1 minimal implementation uses a deterministic STUB internally — it does
 *   not actually shell out to the Copilot CLI or call any Copilot SDK. Real
 *   integration is gated on (a) Copilot CLI being installed and authed
 *   (device-flow OAuth + entitlement check) and (b) a recorded-fixture test
 *   harness so unit tests do not require a live CLI invocation. Both are
 *   explicit out-of-scope per the F-011 ledger out-of-scope-notes (multi-
 *   model adversarial dispatch is M10 / F-082..F-087; v1 here is the single-
 *   provider concrete impl).
 *
 *   The stub satisfies the F-009 structural contract (origin tag,
 *   IBackendProvider compliance, BackendEvent shape correctness, halt
 *   composing with F-018 RunHaltedVerdict), so F-012 (factory) and the M10
 *   adversarial-dispatch wave can wire against a real type today. Swapping
 *   the stub body for a real CLI/SDK call is a self-contained future change
 *   that does not require any other module to update.
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
 *
 * Acceptance scenarios mirrored from the ledger + F-009 contract:
 *   1. CopilotBackend implements IBackendProvider with origin === 'copilot'.
 *   2. startSession returns a sessionId tagged with the 'copilot-' prefix
 *      (provider-tagged for F-019 cost-ledger + F-015 audit-log routing).
 *   3. sendPrompt streams events: a 'token' chunk (with model id surfaced
 *      so traceability is observable at the test boundary, mirroring F-010)
 *      followed by a 'finish' event with reason 'stop'.
 *   4. sendPrompt on an unknown session id throws.
 *   5. halt prevents further token responses (yields finish/error rather
 *      than streaming tokens — F-018 RUN_HALTED observability).
 *   6. stopSession removes the session (subsequent sendPrompt throws).
 *   7. halt is idempotent (calling twice on same session is a no-op).
 *
 * Out of scope (per ledger):
 *   - Real Copilot CLI / SDK invocation (deferred — gated on device-flow
 *     OAuth token storage + recorded-fixture harness).
 *   - Multi-model adversarial dispatch (--council pattern; M10 / F-082..F-087).
 *   - Cost accounting (F-019 cost-ledger consumes token counts; the v1
 *     stub does not emit them — real CLI/SDK integration will).
 *   - ConfigurationError on missing Copilot CLI (the ledger's scenario 2
 *     references constructor-time CLI detection; v1 stub does not shell
 *     out, so the missing-CLI failure mode is deferred to the real-impl
 *     swap. Documented openly here per `no-silent-deferrals.md`).
 */
describe('F-011 copilot-backend', () => {
  it('scenario 1: CopilotBackend implements IBackendProvider with origin="copilot"', () => {
    const backend: IBackendProvider = new CopilotBackend();
    expect(backend.origin).toBe('copilot');
    // Structural witness — TS2420 at compile time if any required method is missing.
    expect(typeof backend.startSession).toBe('function');
    expect(typeof backend.sendPrompt).toBe('function');
    expect(typeof backend.halt).toBe('function');
    expect(typeof backend.stopSession).toBe('function');
  });

  it('scenario 2: startSession returns a sessionId tagged with the copilot- prefix', async () => {
    const backend = new CopilotBackend();
    const agent = createAgent();
    const session = createSession();
    const config: BackendSessionConfig = { agent, session };
    const handle = await backend.startSession(config);
    expect(typeof handle.sessionId).toBe('string');
    expect(handle.sessionId.startsWith('copilot-')).toBe(true);
    expect(handle.sessionId).toContain(session.runId);
  });

  it('scenario 3: sendPrompt streams a token event (with model id) then a finish event', async () => {
    const backend = new CopilotBackend('gpt-5');
    const agent = createAgent();
    const session = createSession();
    const { sessionId } = await backend.startSession({ agent, session });

    const events: BackendEvent[] = [];
    for await (const ev of backend.sendPrompt(sessionId, 'hello')) {
      events.push(ev);
    }
    expect(events.length).toBeGreaterThanOrEqual(2);

    const tokenEv = events.find((e) => e.type === 'token');
    expect(tokenEv).toBeDefined();
    if (tokenEv && tokenEv.type === 'token') {
      expect(tokenEv.text).toContain('hello');
      // Model id is surfaced in the stub response so traceability is observable.
      expect(tokenEv.text).toContain('gpt-5');
    }

    const finishEv = events.find((e) => e.type === 'finish');
    expect(finishEv).toBeDefined();
    if (finishEv && finishEv.type === 'finish') {
      expect(finishEv.reason).toBe('stop');
    }
  });

  it('scenario 4: sendPrompt on unknown session id throws', async () => {
    const backend = new CopilotBackend();
    await expect(async () => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      for await (const _ev of backend.sendPrompt('does-not-exist', 'hi')) {
        // unreachable
      }
    }).rejects.toThrow(/Unknown session/i);
  });

  it('scenario 5: halt prevents further token responses (yields finish/error)', async () => {
    const backend = new CopilotBackend();
    const agent = createAgent();
    const session = createSession();
    const { sessionId } = await backend.startSession({ agent, session });

    const verdict: RunHaltedVerdict = {
      type: 'RUN_HALTED',
      trigger: 'manual',
      reason: 'operator kill-switch',
      timestamp: new Date().toISOString(),
    };
    await backend.halt(sessionId, verdict);

    const events: BackendEvent[] = [];
    for await (const ev of backend.sendPrompt(sessionId, 'still there?')) {
      events.push(ev);
    }
    // After halt, the session is still registered (so sendPrompt does not throw)
    // but it short-circuits to a finish/error event — composes with F-018's
    // RUN_HALTED contract observability requirement across backends.
    const tokenEv = events.find((e) => e.type === 'token');
    expect(tokenEv).toBeUndefined();
    const finishEv = events.find((e) => e.type === 'finish');
    expect(finishEv).toBeDefined();
    if (finishEv && finishEv.type === 'finish') {
      expect(finishEv.reason).toBe('error');
    }
  });

  it('scenario 6: stopSession removes the session (subsequent sendPrompt throws)', async () => {
    const backend = new CopilotBackend();
    const agent = createAgent();
    const session = createSession();
    const { sessionId } = await backend.startSession({ agent, session });

    await backend.stopSession(sessionId);

    await expect(async () => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      for await (const _ev of backend.sendPrompt(sessionId, 'still there?')) {
        // unreachable
      }
    }).rejects.toThrow(/Unknown session/i);
  });

  it('scenario 7: halt is idempotent (calling twice on same session is a no-op)', async () => {
    const backend = new CopilotBackend();
    const agent = createAgent();
    const session = createSession();
    const { sessionId } = await backend.startSession({ agent, session });

    const verdict: RunHaltedVerdict = {
      type: 'RUN_HALTED',
      trigger: 'tool_calls_quota',
      reason: 'F-022 tool-call quota exceeded',
      timestamp: new Date().toISOString(),
    };
    await backend.halt(sessionId, verdict);
    // Second call MUST NOT throw — idempotency is part of the contract.
    await expect(backend.halt(sessionId, verdict)).resolves.toBeUndefined();
  });
});
