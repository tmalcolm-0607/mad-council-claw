import { describe, it, expect } from 'vitest';
import {
  StubBackend,
  AnthropicBackend,
  CopilotBackend,
  createAgent,
  createSession,
  isTokenEvent,
  isToolCallEvent,
  isToolResultEvent,
  isFinishEvent,
  eventTextContent,
  type BackendEvent,
} from '@mad-council-claw/engine-core';

/**
 * F-013 backend-event-normalization — RED → GREEN test.
 * Per docs/03-feature-catalog/M1-backend/F-013-event-normalization.md.
 *
 * Behavior contract (from ledger):
 *   A single discriminated event union models every event a backend can emit.
 *   Engine code consumes only the normalized shape; switching providers does
 *   not require touching consumer code. The shape is stable across provider
 *   versions; provider-version drift is absorbed in the mapper.
 *
 * Scope deviation from ledger (intentional, documented):
 *   The ledger names the union `NormalizedEvent` with 9 variants
 *   (`message_start`, `text_delta`, `tool_use_start`, `tool_use_input_delta`,
 *   `tool_use_stop`, `message_stop`, `usage`, `cancelled`, `error`). The
 *   wave-014 / lane-d F-009 implementation already settled on a smaller
 *   `BackendEvent` union (`token` | `tool_call` | `tool_result` | `finish`)
 *   that every concrete backend (F-010 AnthropicBackend, F-011 CopilotBackend)
 *   already emits identically. The ledger's "cross-SDK normalization" goal
 *   is therefore SATISFIED by F-009's union — F-013's contribution is the
 *   convenience layer (type guards + content extractor) so downstream
 *   consumers (F-014 retro, F-015 audit, F-019 cost-ledger) don't
 *   re-implement the discriminated-union narrowing.
 *
 *   The ledger's 9-variant superset is informational: the variants the v1
 *   union lacks (`message_start`, `tool_use_input_delta`, `usage`,
 *   `cancelled`, `error`) are tracked for the future provider-event-richness
 *   wave per `no-silent-deferrals.md`. v1 covers the four event classes that
 *   matter for the M2 governance triad's observability requirements (token
 *   stream, tool dispatch, tool result, terminal state).
 *
 * Acceptance scenarios mirrored from the ledger + brief:
 *   1. Type guards correctly narrow each BackendEvent variant.
 *   2. eventTextContent returns the text payload for 'token' events
 *      verbatim (no truncation, no prefixing).
 *   3. eventTextContent returns a deterministic descriptor string for
 *      'tool_call' events (consumers can render a single-line summary
 *      without re-implementing the format).
 *   4. eventTextContent returns a deterministic descriptor for
 *      'tool_result' events.
 *   5. eventTextContent returns a deterministic descriptor for 'finish'
 *      events (with reason and optional details).
 *   6. Cross-provider normalization: events streamed from StubBackend,
 *      AnthropicBackend, and CopilotBackend all match the same
 *      `BackendEvent` union shape and pass the same type guards.
 *
 * Out of scope (per ledger):
 *   - 9-variant ledger superset (`message_start`, `tool_use_input_delta`,
 *     `usage`, `cancelled`, `error`). Tracked for future event-richness
 *     wave; v1 covers the 4-variant minimum.
 *   - OpenTelemetry GenAI semantic-convention spans — F-123 (NEW M16
 *     frontier-research candidate).
 *   - Anthropic/Copilot SDK-specific stream-event mapping (e.g.
 *     `content_block_delta` → `text_delta`). Today's stub backends already
 *     emit BackendEvent directly; the mapping wave fires when the real SDK
 *     swap happens (gated on F-070 secure storage).
 */
describe('F-013 backend-event-normalization', () => {
  it('scenario 1a: isTokenEvent narrows correctly', () => {
    const ev: BackendEvent = { type: 'token', text: 'hello' };
    expect(isTokenEvent(ev)).toBe(true);
    if (isTokenEvent(ev)) {
      // TypeScript narrowing witness: ev.text is accessible without a
      // type assertion or explicit `if (ev.type === 'token')` re-check.
      expect(ev.text).toBe('hello');
    }
    const other: BackendEvent = { type: 'finish', reason: 'stop' };
    expect(isTokenEvent(other)).toBe(false);
  });

  it('scenario 1b: isToolCallEvent narrows correctly', () => {
    const ev: BackendEvent = { type: 'tool_call', name: 'read', arguments: { path: '/x' } };
    expect(isToolCallEvent(ev)).toBe(true);
    if (isToolCallEvent(ev)) {
      expect(ev.name).toBe('read');
      expect(ev.arguments).toEqual({ path: '/x' });
    }
    expect(isToolCallEvent({ type: 'token', text: 'a' })).toBe(false);
  });

  it('scenario 1c: isToolResultEvent narrows correctly', () => {
    const ev: BackendEvent = { type: 'tool_result', name: 'read', result: 'file contents' };
    expect(isToolResultEvent(ev)).toBe(true);
    if (isToolResultEvent(ev)) {
      expect(ev.name).toBe('read');
      expect(ev.result).toBe('file contents');
    }
    expect(isToolResultEvent({ type: 'finish', reason: 'stop' })).toBe(false);
  });

  it('scenario 1d: isFinishEvent narrows correctly', () => {
    const ev: BackendEvent = { type: 'finish', reason: 'error', details: 'halted' };
    expect(isFinishEvent(ev)).toBe(true);
    if (isFinishEvent(ev)) {
      expect(ev.reason).toBe('error');
      expect(ev.details).toBe('halted');
    }
    expect(isFinishEvent({ type: 'token', text: 'a' })).toBe(false);
  });

  it('scenario 2: eventTextContent returns text verbatim for token events', () => {
    const ev: BackendEvent = { type: 'token', text: 'streamed-chunk' };
    expect(eventTextContent(ev)).toBe('streamed-chunk');
  });

  it('scenario 3: eventTextContent returns a deterministic descriptor for tool_call events', () => {
    const ev: BackendEvent = { type: 'tool_call', name: 'read_file', arguments: { path: '/x' } };
    // Format is descriptor-only (no JSON of arguments) so callers can
    // log/render without leaking large argument payloads to UIs that
    // aren't designed for it. Arguments are still on the event itself
    // for consumers that DO need them (audit log, cost ledger).
    expect(eventTextContent(ev)).toBe('[tool_call: read_file]');
  });

  it('scenario 4: eventTextContent returns a deterministic descriptor for tool_result events', () => {
    const ev: BackendEvent = { type: 'tool_result', name: 'read_file', result: 'contents' };
    expect(eventTextContent(ev)).toBe('[tool_result: read_file]');
  });

  it('scenario 5: eventTextContent returns a descriptor including reason + details for finish events', () => {
    expect(eventTextContent({ type: 'finish', reason: 'stop' })).toBe('[finish: stop]');
    expect(eventTextContent({ type: 'finish', reason: 'error', details: 'halted' })).toBe(
      '[finish: error halted]',
    );
  });

  it('scenario 6: cross-provider events all match the same BackendEvent shape and pass type guards', async () => {
    const agent = createAgent();
    const session = createSession();
    const providers = [new StubBackend(), new AnthropicBackend(), new CopilotBackend()] as const;

    for (const backend of providers) {
      const { sessionId } = await backend.startSession({ agent, session });
      const events: BackendEvent[] = [];
      for await (const ev of backend.sendPrompt(sessionId, 'normalize me')) {
        events.push(ev);
      }
      // Every backend must emit at least one token + one finish under the
      // happy path. F-013's normalization claim is that the SAME type guards
      // work across all three.
      expect(events.some(isTokenEvent)).toBe(true);
      expect(events.some(isFinishEvent)).toBe(true);
      // No ill-formed events (every event has a type that is one of the
      // four discriminants — exhaustive-switch witness).
      for (const ev of events) {
        const isOneOfFour =
          isTokenEvent(ev) || isToolCallEvent(ev) || isToolResultEvent(ev) || isFinishEvent(ev);
        expect(isOneOfFour).toBe(true);
      }
    }
  });
});
