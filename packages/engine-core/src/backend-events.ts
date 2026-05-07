/**
 * F-013 backend-event-normalization — GREEN.
 *
 * Per docs/03-feature-catalog/M1-backend/F-013-event-normalization.md.
 *
 * Behavior contract (from ledger):
 *   A single discriminated event union models every event a backend can
 *   emit. Engine code consumes only the normalized shape; switching
 *   providers does not require touching consumer code. The shape is stable
 *   across provider versions; provider-version drift is absorbed in the
 *   mapper.
 *
 * Why this file (the v1 'is just helpers' shape):
 *   `BackendEvent` from F-009 (backend.ts) IS the normalized shape across
 *   all backends — StubBackend, AnthropicBackend (F-010), and CopilotBackend
 *   (F-011) all already emit the same discriminated union. F-013's
 *   contribution is therefore the convenience layer (type guards + content
 *   extractor) so downstream consumers don't re-implement the
 *   discriminated-union narrowing.
 *
 *   When a future SDK swap (real @anthropic-ai/sdk or real Copilot CLI)
 *   needs provider-specific event mapping (e.g. Anthropic's
 *   `content_block_delta` → `BackendEvent token`), the mapper functions
 *   live alongside the swap in the relevant `backend-*.ts` file. The
 *   normalization CONTRACT (the union shape itself) lives in `backend.ts`;
 *   the helpers here are downstream-consumer-facing only.
 *
 * Scope deviation from ledger (intentional, documented per the wave-014 /
 * lane-d + F-009 precedent):
 *   The ledger names the union `NormalizedEvent` with 9 variants
 *   (`message_start`, `text_delta`, `tool_use_start`, `tool_use_input_delta`,
 *   `tool_use_stop`, `message_stop`, `usage`, `cancelled`, `error`). The
 *   wave-014 / lane-d F-009 implementation already settled on a smaller
 *   `BackendEvent` union (`token` | `tool_call` | `tool_result` | `finish`)
 *   that every concrete backend already emits identically.
 *
 *   Variants the v1 union lacks (`message_start`, `tool_use_input_delta`,
 *   `usage`, `cancelled`, `error`) are tracked for the future provider-
 *   event-richness wave per `no-silent-deferrals.md`. v1 covers the four
 *   event classes that matter for the M2 governance triad's observability
 *   requirements (token stream, tool dispatch, tool result, terminal state).
 *   `error` is partially covered by `{type:'finish', reason:'error', details}`.
 */

import type { BackendEvent } from './backend.js';

/**
 * Type guard for `token` events. Narrows the discriminated union so
 * TypeScript callers can access `text` without a manual `if (e.type === ...)`
 * re-check.
 */
export function isTokenEvent(e: BackendEvent): e is Extract<BackendEvent, { type: 'token' }> {
  return e.type === 'token';
}

/**
 * Type guard for `tool_call` events. Narrows to expose `name` + `arguments`.
 */
export function isToolCallEvent(
  e: BackendEvent,
): e is Extract<BackendEvent, { type: 'tool_call' }> {
  return e.type === 'tool_call';
}

/**
 * Type guard for `tool_result` events. Narrows to expose `name` + `result`.
 */
export function isToolResultEvent(
  e: BackendEvent,
): e is Extract<BackendEvent, { type: 'tool_result' }> {
  return e.type === 'tool_result';
}

/**
 * Type guard for `finish` events. Narrows to expose `reason` + optional
 * `details`. F-018 RUN_HALTED observability surfaces here as
 * `{type:'finish', reason:'error', details:'Session halted'}`.
 */
export function isFinishEvent(e: BackendEvent): e is Extract<BackendEvent, { type: 'finish' }> {
  return e.type === 'finish';
}

/**
 * Type guard for `usage` events (F-139). Narrows to expose the 4 token-count
 * fields + `model` + optional `backend`. Engine-cycle composers (F-138) use
 * this to filter the BackendEvent stream and route only usage events to
 * F-019 CostLedger.append via the F-139 `usageEventToCostEntry` mapper.
 */
export function isUsageEvent(e: BackendEvent): e is Extract<BackendEvent, { type: 'usage' }> {
  return e.type === 'usage';
}

/**
 * Render a single-line string for any `BackendEvent`.
 *
 * Intended for log/audit/UI surfaces that need a deterministic summary
 * without re-implementing the discriminated-union switch. Token events
 * surface their `text` verbatim; tool events surface a `[tool_call: <name>]`
 * / `[tool_result: <name>]` descriptor; finish events surface
 * `[finish: <reason>]` with an optional details suffix.
 *
 * Deliberate format choices:
 *   - tool events do NOT serialize `arguments` / `result` into the descriptor
 *     because those payloads are arbitrary-shape and may be large. Consumers
 *     that need the payload access it directly via `event.arguments` /
 *     `event.result` after narrowing with the type guards above.
 *   - finish events join `reason` + `details` with a single space (when
 *     details is present) — this preserves greppability without breaking
 *     when details itself contains spaces. Format is documented and
 *     covered by F-013 scenario 5.
 */
export function eventTextContent(e: BackendEvent): string {
  if (e.type === 'token') return e.text;
  if (e.type === 'tool_call') return `[tool_call: ${e.name}]`;
  if (e.type === 'tool_result') return `[tool_result: ${e.name}]`;
  if (e.type === 'finish') return `[finish: ${e.reason}${e.details ? ' ' + e.details : ''}]`;
  // F-139 usage variant: deterministic descriptor with all 4 token counts
  // surfaced. Greppable for log-mining; consistent with the existing
  // `[finish: <reason>]` and `[tool_call: <name>]` formats.
  if (e.type === 'usage') {
    return `[usage: input=${e.input_tokens} output=${e.output_tokens} cache_read=${e.cache_read_tokens} cache_write=${e.cache_write_tokens}]`;
  }
  // Exhaustive-switch witness. If a new BackendEvent variant is added
  // without a branch here, TS narrows `e` to `never` and the assignment
  // below fails TS2322. The empty-string fallback is a runtime safety
  // net for the never-can-happen path.
  const _exhaustive: never = e;
  void _exhaustive;
  return '';
}
