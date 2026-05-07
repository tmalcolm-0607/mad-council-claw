/**
 * F-139 backend-event-usage-variant — GREEN.
 *
 * Per docs/03-feature-catalog/M1-backend/F-139-backend-event-usage-variant.md.
 *
 * Behavior contract (from ledger):
 *   The discriminated `BackendEvent` union (F-009 owner) gains a 5th variant:
 *   `{type:'usage', input_tokens, output_tokens, cache_read_tokens,
 *     cache_write_tokens, model, backend?}`. Concrete backends (F-010
 *   AnthropicBackend, F-011 CopilotBackend) emit this variant after `finish`
 *   so engine-cycle composers (F-138) can compute cost-ledger rows
 *   (F-019 CostLedger) without re-implementing token-count extraction inside
 *   the backend.
 *
 *   This file authors the variant-to-CostEntryInput mapper. The variant
 *   itself lives in backend.ts (F-009 owner, additive extension). The type
 *   guard `isUsageEvent` lives in backend-events.ts (F-013 owner, additive
 *   extension alongside the other 4 type guards).
 *
 * Anti-orchestrator-impostor discipline per `kit:rules/orchestrator-identity.md`:
 *   This module NEVER calls CostLedger.append directly. It produces a
 *   CostEntryInput; callers (F-138 cycle.ts in a future iteration) call
 *   `costLedger.append(input)` to commit the row. Cost-ledger ownership stays
 *   with F-019.
 *
 * No-invented-constraints discipline per `kit:rules/no-invented-constraints.md`:
 *   `usd_estimate` is computed ONLY when the caller supplies a `priceLookup`
 *   callback. Without the callback, `usd_estimate=0` (caller-deferred
 *   pricing). NO halt, NO budget-check, NO warning when costs are high —
 *   F-019's observable-only contract propagates through this mapper.
 *
 * Created in wave-019 / lane-b. Resolves wave-016 / lane-d D-36 (Opus C-2):
 * F-019 cost ledger now has an event source.
 */

import type { BackendEvent } from './backend.js';
import type { CostEntryInput } from './cost.js';

/**
 * Correlation triple supplied by the caller of {@link usageEventToCostEntry}.
 *
 * Mirrors F-019's CostEntry schema for the agent / run / parent-run fields.
 * `parent_run_id` is optional — present when the recording agent was spawned
 * from another session.
 */
export interface UsageEventContext {
  /** F-002 run/session identity (UUID v7). */
  run_id: string;
  /** F-002 agent identity (UUID v7). */
  agent_id: string;
  /** F-002 parent-run correlation; absent for root agents. */
  parent_run_id?: string;
}

/**
 * Per-token rate lookup function. Returns USD per token for the given
 * model + token kind. Caller supplies the price table (per F-019's deferred
 * `pricing/<backend>.json` per-model-rate concern).
 *
 * The mapper invokes the lookup twice per usage event — once for `'input'`
 * and once for `'output'`. Cache-read / cache-write token rates are NOT
 * separately looked up in v1; future M16 telemetry features may extend this
 * signature to handle cache-attribution analytics. v1 maps cache token
 * counts verbatim into the CostEntryInput shape but DOES NOT add their cost
 * to `usd_estimate` (the F-019 schema preserves them as observable counts;
 * downstream cache-cost analytics consume them via `getEntries()`).
 */
export type PriceLookup = (model: string, kind: 'input' | 'output') => number;

/**
 * Convert one F-139 usage event + correlation context (+ optional pricing)
 * into the F-019 CostLedger.append-ready shape.
 *
 * Acceptance scenarios from the F-139 ledger:
 *   1. Usage event + price lookup + correlation -> CostEntryInput with
 *      computed usd_estimate; F-019 round-trip yields a CostEntry with
 *      seq=0 and matching numeric fields.
 *   3. Usage event WITHOUT price lookup -> CostEntryInput with
 *      usd_estimate=0 and all 4 token-count fields mapped verbatim.
 *   5. parent_run_id in correlation context propagates to CostEntryInput.
 *
 * The function is intentionally pure — no I/O, no side effects, no
 * mutation of the input event. The returned CostEntryInput is a fresh
 * object that the caller composes into a CostLedger.append call.
 */
export function usageEventToCostEntry(
  event: Extract<BackendEvent, { type: 'usage' }>,
  ctx: UsageEventContext,
  priceLookup?: PriceLookup,
): CostEntryInput {
  // Caller-deferred pricing: no lookup -> usd_estimate=0. F-019's observable-
  // only contract is preserved; the cost row is appended at the caller's
  // discretion when (and if) a price table is available.
  let usd = 0;
  if (priceLookup !== undefined) {
    const inputRate = priceLookup(event.model, 'input');
    const outputRate = priceLookup(event.model, 'output');
    usd = event.input_tokens * inputRate + event.output_tokens * outputRate;
  }

  const input: CostEntryInput = {
    agent_id: ctx.agent_id,
    run_id: ctx.run_id,
    model: event.model,
    tokens_in: event.input_tokens,
    tokens_out: event.output_tokens,
    cache_read_tokens: event.cache_read_tokens,
    cache_write_tokens: event.cache_write_tokens,
    usd_estimate: usd,
  };
  if (ctx.parent_run_id !== undefined) {
    input.parent_run_id = ctx.parent_run_id;
  }
  if (event.backend !== undefined) {
    input.backend = event.backend;
  }
  return input;
}
