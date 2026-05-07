/**
 * F-009 IBackendProvider abstraction — GREEN.
 *
 * Per docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md.
 *
 * Behavior contract (from ledger):
 *   IBackendProvider is a TypeScript interface defining a uniform shape for
 *   every LLM backend. Engine code never imports a concrete SDK directly —
 *   it imports IBackendProvider and receives the implementation via the
 *   factory (F-012). Concrete backends (Anthropic per F-010, Copilot per
 *   F-011) implement this interface unchanged.
 *
 * Scope deviation from ledger (intentional, documented):
 *   The F-009 ledger names a `complete(prompt, opts) → AsyncIterable<NormalizedEvent>`
 *   shape. The wave-014 / lane-d brief replaces that shape with a session-
 *   oriented surface (`startSession` / `sendPrompt` / `halt` / `stopSession`)
 *   carrying a discriminated `BackendEvent` union. The session shape
 *   generalizes the ledger's iterator-of-events pattern (sendPrompt returns
 *   AsyncGenerator<BackendEvent>) and adds a halt path that composes cleanly
 *   with F-018's RunHaltedVerdict — making the M2 governance triad's
 *   RUN_HALTED contract observable across backends. The ledger's three
 *   acceptance scenarios (mock provider consumed identically, error
 *   propagation via reject path, compile-fail on omitted method) are honored
 *   by the session shape; F-013 (event-normalization) and F-012 (factory)
 *   plug in without touching this surface.
 *
 * This file authors the SHAPE (interface + types + StubBackend). Concrete
 * providers (F-010 Anthropic, F-011 Copilot) implement the same interface
 * in their own files. The Stub exists to:
 *   1. Satisfy the F-009 acceptance scenarios without an external SDK call.
 *   2. Provide a deterministic fixture for downstream test authoring (F-012
 *      factory tests, F-018 halt-integration tests).
 *
 * Related types reused from sibling files (per the wave-011 / lane-a barrel
 * convention — "shared types live with their FIRST owner; later features
 * import via `./<owner>.js`"):
 *   - Agent, Session — F-002 (identity.ts)
 *   - RunHaltedVerdict — F-018 (halt.ts)
 */

import type { Agent, Session } from './identity.js';
import type { RunHaltedVerdict } from './halt.js';

/**
 * Token-stream event from a backend.
 *
 * Type-discriminated so downstream consumers can switch on `event.type` and
 * the TypeScript compiler narrows the payload on each branch. The four
 * variants cover the v1 surface every concrete backend MUST emit:
 *
 *   - `token`       — a streamed text chunk from the model (no aggregation;
 *                     callers concatenate `text` across `token` events).
 *   - `tool_call`   — the model invoked a tool; payload is `name` + an
 *                     opaque `arguments` record (provider-specific shape;
 *                     F-013 will normalize).
 *   - `tool_result` — the runtime returned a tool's result back to the
 *                     model; payload is `name` + opaque `result`.
 *   - `finish`      — the response is complete; `reason` is the canonical
 *                     enum (`stop` | `length` | `tool` | `error`); optional
 *                     `details` carries provider-specific text (e.g. an
 *                     error message when reason === 'error').
 *
 * The shape is deliberately small; F-013 (event-normalization) is where
 * cross-provider mapping happens. Adding new variants is a backwards-
 * incompatible change and triggers a council review.
 */
export type BackendEvent =
  | { type: 'token'; text: string }
  | { type: 'tool_call'; name: string; arguments: Record<string, unknown> }
  | { type: 'tool_result'; name: string; result: unknown }
  | { type: 'finish'; reason: 'stop' | 'length' | 'tool' | 'error'; details?: string };

/**
 * Configuration passed to `IBackendProvider.startSession`.
 *
 * Composes F-002 identity (Agent + Session) so every started session carries
 * the run_id / agent_id correlation used by F-015 (audit), F-019 (cost),
 * and F-014 (retro). Optional fields (systemMessage / model / tools) are
 * forwarded by concrete providers; the Stub ignores them.
 */
export interface BackendSessionConfig {
  /** F-002 Agent. Carries agentId + parentRunId for correlation. */
  agent: Agent;
  /** F-002 Session. Carries runId for correlation. */
  session: Session;
  /** Optional system instruction; forwarded verbatim to the model. */
  systemMessage?: string;
  /** Optional model id (e.g. "claude-opus-4-7", "gpt-5"). Provider-specific. */
  model?: string;
  /** Optional tool registrations exposed to the model. Schema is JSON Schema. */
  tools?: { name: string; description: string; schema: Record<string, unknown> }[];
}

/**
 * The pluggable backend interface.
 *
 * Implementations (planned):
 *   - {@link StubBackend}    — origin "stub", in-memory, no real model call.
 *   - AnthropicBackend (F-010) — origin "anthropic".
 *   - CopilotBackend (F-011)   — origin "copilot".
 *   - GatewayBackend           — origin "gateway" (future research).
 *
 * Engine code MUST NOT import any concrete provider. It imports this
 * interface and receives the implementation from F-012's factory. The
 * single observable cross-provider surface lives here; per-provider
 * idiosyncrasies are normalized into BackendEvent by F-013.
 *
 * Error semantics:
 *   - startSession rejects on validation failure (e.g. unknown model);
 *     never silently downgrades.
 *   - sendPrompt yields events on success; throws (rejects the
 *     AsyncGenerator) on transport failure or unknown sessionId.
 *   - halt is unconditional — accepts a RunHaltedVerdict so F-020 / F-022 /
 *     F-018 can pass the verdict through to the provider for any cleanup;
 *     idempotent on already-stopped sessions (no-op rather than throw).
 *   - stopSession is the graceful-shutdown counterpart of halt; idempotent.
 */
export interface IBackendProvider {
  /**
   * Backend identifier (`"anthropic"` / `"copilot"` / `"stub"` / etc.).
   * Drives F-012 factory routing and observability tagging.
   */
  readonly origin: string;

  /**
   * Start a session. Returns a session handle whose `sessionId` is the
   * opaque identifier the caller passes to subsequent `sendPrompt` /
   * `halt` / `stopSession` calls.
   */
  startSession(config: BackendSessionConfig): Promise<{ sessionId: string }>;

  /**
   * Send a user prompt and stream events back as an AsyncGenerator.
   * Caller iterates with `for await (const ev of provider.sendPrompt(...))`.
   * The generator throws on unknown sessionId or transport failure.
   */
  sendPrompt(sessionId: string, prompt: string): AsyncGenerator<BackendEvent>;

  /**
   * Halt a running session (cooperative cancel) with the supplied
   * RunHaltedVerdict. The verdict's `trigger` (e.g. `manual`,
   * `tool_calls_quota`, `overplanning_5`) tells the provider WHY the halt
   * is happening so it can route cleanup appropriately.
   *
   * Idempotent: halting an already-stopped session is a no-op.
   */
  halt(sessionId: string, verdict: RunHaltedVerdict): Promise<void>;

  /**
   * Graceful stop / dispose of a session. Distinct from `halt` because
   * `stopSession` carries no halt verdict — it's the "we're done" path,
   * not the "something fired a trigger" path.
   *
   * Idempotent: stopping an already-stopped session is a no-op.
   */
  stopSession(sessionId: string): Promise<void>;
}

/**
 * In-memory stub backend for testing.
 *
 * Behavior:
 *   - origin === "stub"
 *   - startSession registers a session keyed by `stub-<runId>` and stores
 *     the config so sendPrompt can validate the session and (optionally)
 *     reflect the systemMessage in its echo.
 *   - sendPrompt yields exactly two events: a `token` chunk echoing
 *     `STUB-RESPONSE-TO: <prompt>`, and a `finish` event with reason `stop`.
 *   - halt and stopSession both remove the session from the in-memory Map
 *     (idempotent — no error on already-removed).
 *   - sendPrompt on an unknown session throws `Unknown session: <id>` —
 *     the AsyncGenerator surfaces this through the iterator's reject path
 *     per the F-009 ledger acceptance scenario 2.
 *
 * Used by:
 *   - tests/unit/F-009-ibackend-provider.test.ts (this feature's own tests).
 *   - Future F-012 factory tests (origin === "stub" routing path).
 *   - Future F-018 / F-020 / F-022 halt-integration tests.
 */
export class StubBackend implements IBackendProvider {
  readonly origin = 'stub';
  private readonly sessions = new Map<string, BackendSessionConfig>();

  async startSession(config: BackendSessionConfig): Promise<{ sessionId: string }> {
    const sessionId = `stub-${config.session.runId}`;
    this.sessions.set(sessionId, config);
    return { sessionId };
  }

  async *sendPrompt(sessionId: string, prompt: string): AsyncGenerator<BackendEvent> {
    if (!this.sessions.has(sessionId)) {
      throw new Error(`Unknown session: ${sessionId}`);
    }
    yield { type: 'token', text: `STUB-RESPONSE-TO: ${prompt}` };
    yield { type: 'finish', reason: 'stop' };
  }

  async halt(sessionId: string, _verdict: RunHaltedVerdict): Promise<void> {
    this.sessions.delete(sessionId);
  }

  async stopSession(sessionId: string): Promise<void> {
    this.sessions.delete(sessionId);
  }
}
