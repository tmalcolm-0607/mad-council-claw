import { describe, it, expect } from 'vitest';
import {
  StubBackend,
  createAgent,
  createSession,
  type IBackendProvider,
  type BackendEvent,
  type BackendSessionConfig,
  type RunHaltedVerdict,
} from '@mad-council-claw/engine-core';

/**
 * F-009 IBackendProvider abstraction — RED → GREEN test.
 * Per docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md.
 *
 * Behavior contract (from ledger):
 *   IBackendProvider is a TypeScript interface defining a uniform shape for
 *   every LLM backend. Engine code never imports a concrete SDK directly —
 *   it imports IBackendProvider and receives the implementation via the
 *   factory (F-012). Concrete backends (Anthropic per F-010, Copilot per
 *   F-011) implement this interface unchanged.
 *
 * Scope deviation from ledger (intentional, documented per the wave-008 / lane-a
 * + wave-009 / lane-c precedent):
 *   The F-009 ledger names a `complete(prompt, opts) → AsyncIterable<NormalizedEvent>`
 *   shape paired with `cancel(handle)`, `listModels()`, `name: BackendName`.
 *   The wave-014 / lane-d brief replaces that shape with a session-oriented
 *   surface (`startSession`, `sendPrompt`, `halt`, `stopSession`) carrying a
 *   discriminated `BackendEvent` union (`token` | `tool_call` | `tool_result`
 *   | `finish`). The session shape generalizes the ledger's iterator-of-events
 *   pattern (sendPrompt returns AsyncGenerator<BackendEvent>) and adds a halt
 *   path that composes cleanly with F-018's RunHaltedVerdict — making the
 *   M2 governance triad's RUN_HALTED contract observable across backends.
 *   Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) the divergence
 *   is recorded openly here and in the ledger §Implementation notes; the
 *   ledger Acceptance scenarios (mock provider consumed identically; error
 *   propagation via reject path; compile-fail on omitted method) are honored
 *   by the session shape (StubBackend implements IBackendProvider; sendPrompt
 *   throws on unknown session and yields events; missing method fails TS2420).
 *
 * Acceptance scenarios mirrored from the ledger + brief:
 *   1. Type-level: StubBackend implements IBackendProvider (origin === 'stub';
 *      structural witness — a class missing any required method would fail
 *      TS2420 at compile time, satisfying ledger scenario 3).
 *   2. startSession returns a sessionId for a given config (BackendSessionConfig
 *      composes Agent + Session per F-002 identity).
 *   3. sendPrompt streams events: a 'token' chunk followed by a 'finish' event
 *      (ledger scenario 1: events consumed identically regardless of provider).
 *   4. sendPrompt on an unknown session id throws (ledger scenario 2: error
 *      propagation through the iterator's reject path).
 *   5. halt removes the session AND accepts a RunHaltedVerdict (composing with
 *      F-018's HaltDetector output — kill-switch / quota / overplanning path).
 *   6. stopSession removes the session.
 *
 * Out of scope (per ledger):
 *   - F-010 AnthropicBackend wiring (real Anthropic SDK call).
 *   - F-011 CopilotBackend wiring (real Copilot SDK call).
 *   - F-012 backend-factory (origin → implementation routing).
 *   - F-013 event-normalization (cross-provider mapping; the BackendEvent
 *     discriminated union here is the v1 shape future providers normalize TO).
 *   - F-002 identity-stamp on emitted events (BackendEvent is provider-side;
 *     identity stamping happens at the audit-writer boundary per F-002 ledger).
 *   - Multi-tier model routing (F-124 — frontier-research candidate).
 */
describe('F-009 ibackend-provider', () => {
  it('scenario 1: StubBackend implements IBackendProvider with origin="stub"', () => {
    const backend: IBackendProvider = new StubBackend();
    expect(backend.origin).toBe('stub');
    // Structural witness — these methods MUST exist (TS2420 at compile time
    // if any are missing); runtime check confirms the shape held through bundle.
    expect(typeof backend.startSession).toBe('function');
    expect(typeof backend.sendPrompt).toBe('function');
    expect(typeof backend.halt).toBe('function');
    expect(typeof backend.stopSession).toBe('function');
  });

  it('scenario 2: startSession returns a sessionId for a given config', async () => {
    const backend = new StubBackend();
    const agent = createAgent();
    const session = createSession();
    const config: BackendSessionConfig = { agent, session };
    const handle = await backend.startSession(config);
    expect(typeof handle.sessionId).toBe('string');
    expect(handle.sessionId.length).toBeGreaterThan(0);
    // The Stub composes session.runId into the sessionId for traceability.
    expect(handle.sessionId).toContain(session.runId);
  });

  it('scenario 3: sendPrompt streams a token event then a finish event', async () => {
    const backend = new StubBackend();
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
    }

    const finishEv = events.find((e) => e.type === 'finish');
    expect(finishEv).toBeDefined();
    if (finishEv && finishEv.type === 'finish') {
      expect(finishEv.reason).toBe('stop');
    }
  });

  it('scenario 4: sendPrompt on unknown session id throws', async () => {
    const backend = new StubBackend();
    // Iteration is required to surface the error from an AsyncGenerator.
    await expect(async () => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      for await (const _ev of backend.sendPrompt('does-not-exist', 'hi')) {
        // unreachable
      }
    }).rejects.toThrow(/Unknown session/i);
  });

  it('scenario 5: halt accepts a RunHaltedVerdict and removes the session', async () => {
    const backend = new StubBackend();
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

    // After halt, sendPrompt to the same id should fail (session removed).
    await expect(async () => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      for await (const _ev of backend.sendPrompt(sessionId, 'still there?')) {
        // unreachable
      }
    }).rejects.toThrow(/Unknown session/i);
  });

  it('scenario 6: stopSession removes the session', async () => {
    const backend = new StubBackend();
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
});
