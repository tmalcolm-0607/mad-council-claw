import { describe, it, expect } from 'vitest';
import {
  AnthropicBackend,
  createAgent,
  createSession,
  type IBackendProvider,
  type BackendEvent,
  type BackendSessionConfig,
  type RunHaltedVerdict,
} from '@mad-council-claw/engine-core';

/**
 * F-010 Anthropic SDK provider — RED → GREEN test.
 * Per docs/03-feature-catalog/M1-backend/F-010-anthropic-sdk-provider.md.
 *
 * Behavior contract (from ledger):
 *   AnthropicBackend is a concrete IBackendProvider wrapping @anthropic-ai/sdk.
 *   It supports streaming responses mapped to the normalized BackendEvent
 *   shape per F-013. API key reads from env ANTHROPIC_API_KEY (per F-070
 *   secure storage, deferred). Cancellation aborts the underlying fetch.
 *
 * Scope deviation from ledger (intentional, documented per the wave-014 / lane-d
 * + F-009 precedent):
 *   The F-010 ledger acceptance scenarios reference a `complete(prompt, opts)`
 *   shape with a `cancel(handle)` companion. F-009's session-oriented surface
 *   (startSession / sendPrompt / halt / stopSession) is the agreed concrete
 *   shape every backend implements; F-010 follows it.
 *
 *   v1 minimal implementation uses a deterministic STUB internally — it does
 *   not actually call @anthropic-ai/sdk. Real SDK integration is gated on
 *   F-070 (secure storage for ANTHROPIC_API_KEY) and a recorded-fixture test
 *   harness; both are out-of-scope for this wave per the ledger
 *   out-of-scope-notes. The stub satisfies the structural contract (origin,
 *   IBackendProvider compliance, event-shape correctness) so F-012 (factory)
 *   and downstream callers can wire against a real type today; swapping the
 *   stub body for a real SDK call is a self-contained future change that
 *   does not require any other module to update.
 *
 * Acceptance scenarios mirrored from the ledger + F-009 contract:
 *   1. AnthropicBackend implements IBackendProvider with origin === 'anthropic'.
 *   2. startSession returns a sessionId string with the 'anthropic-' prefix
 *      (provider-tagged for F-019 cost-ledger + F-015 audit-log routing).
 *   3. sendPrompt streams events: a 'token' chunk (with the prompt echoed
 *      and the model id surfaced for traceability) followed by a 'finish'
 *      event with reason 'stop'.
 *   4. sendPrompt on an unknown session id throws.
 *   5. halt prevents further responses (subsequent sendPrompt yields a
 *      'finish' with reason 'error' rather than streaming tokens — composes
 *      with F-018's RunHaltedVerdict propagation).
 *
 * Out of scope (per ledger):
 *   - Real @anthropic-ai/sdk integration (deferred to a future feature
 *     gated on F-070 secure storage + recorded-fixture test harness).
 *   - Prompt-caching tuning (F-126 NEW context-budget-allocation, M8).
 *   - Extended-thinking opt-in (F-126).
 *   - Cost accounting (F-019 cost-ledger consumes token counts; the v1
 *     stub does not emit them — real SDK integration will).
 */
describe('F-010 anthropic-backend', () => {
  it('scenario 1: AnthropicBackend implements IBackendProvider with origin="anthropic"', () => {
    const backend: IBackendProvider = new AnthropicBackend();
    expect(backend.origin).toBe('anthropic');
    // Structural witness — TS2420 at compile time if any required method is missing.
    expect(typeof backend.startSession).toBe('function');
    expect(typeof backend.sendPrompt).toBe('function');
    expect(typeof backend.halt).toBe('function');
    expect(typeof backend.stopSession).toBe('function');
  });

  it('scenario 2: startSession returns a sessionId tagged with the anthropic- prefix', async () => {
    const backend = new AnthropicBackend();
    const agent = createAgent();
    const session = createSession();
    const config: BackendSessionConfig = { agent, session };
    const handle = await backend.startSession(config);
    expect(typeof handle.sessionId).toBe('string');
    expect(handle.sessionId.startsWith('anthropic-')).toBe(true);
    expect(handle.sessionId).toContain(session.runId);
  });

  it('scenario 3: sendPrompt streams a token event (with model id) then a finish event', async () => {
    const backend = new AnthropicBackend('claude-opus-4-7');
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
      expect(tokenEv.text).toContain('claude-opus-4-7');
    }

    const finishEv = events.find((e) => e.type === 'finish');
    expect(finishEv).toBeDefined();
    if (finishEv && finishEv.type === 'finish') {
      expect(finishEv.reason).toBe('stop');
    }
  });

  it('scenario 4: sendPrompt on unknown session id throws', async () => {
    const backend = new AnthropicBackend();
    await expect(async () => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      for await (const _ev of backend.sendPrompt('does-not-exist', 'hi')) {
        // unreachable
      }
    }).rejects.toThrow(/Unknown session/i);
  });

  it('scenario 5: halt prevents further token responses (yields finish/error)', async () => {
    const backend = new AnthropicBackend();
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
    const backend = new AnthropicBackend();
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
    const backend = new AnthropicBackend();
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
