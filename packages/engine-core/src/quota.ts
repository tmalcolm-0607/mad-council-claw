/**
 * F-022 Per-spawn tool-call quota — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-022-tool-quota.md.
 * Behavior contract (from ledger):
 *   Every tool invocation an agent makes is counted against per-agent quotas.
 *   When a quota is reached, further tool calls reject with
 *   `QUOTA_EXCEEDED: <quota_name>` and the rejection is logged. Quotas are
 *   per-agent (independent counters per agent_id) and run-scoped (counters
 *   reset on new run).
 *
 * Scope reconciliation with F-018 (FETCH BEFORE CITE):
 *   F-018 already added a GLOBAL `recordToolCall()` method on `HaltDetector`
 *   that emits `RUN_HALTED` with trigger `tool_calls_quota`. F-022 extends
 *   that surface with PER-AGENT tracking — separate counter keyed by
 *   agent_id. The two surfaces coexist:
 *     - F-018's global counter catches runaway aggregate usage across a run
 *     - F-022's per-agent counter catches per-spawn quota exhaustion
 *   Both reuse `RunHaltedVerdict`. F-022 emits trigger `'tool_calls'`
 *   (added to HaltTrigger union); F-018 emits `'tool_calls_quota'`. F-014's
 *   `halted_by_tool_quota` retro outcome (already in RetroOutcome enum)
 *   consumes both.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

import type { RunHaltedVerdict } from './halt.js';

/**
 * Per-spawn (per agent_id) tool-call quota enforcer.
 *
 * Acceptance scenarios from the F-022 ledger + wave-10 brief:
 *   1. Per-agent counter independence — agent A and B have separate counters
 *      within the same run (ledger scenario 2).
 *   2. Exceeding `maxPerAgent` returns `RunHaltedVerdict` with
 *      `trigger: 'tool_calls'` (ledger scenario 1).
 *   3. Verdict carries `agent_id` of the offending agent (audit anchor).
 *   4. `reset(agentId)` clears a single agent's counter.
 *   5. `resetAll()` clears every agent's counter.
 *   6. `getCount` before any call returns 0.
 *   7. Default `maxPerAgent = 50` (mid-point between ledger's 50/1000 caps;
 *      wave-10 brief specifies 50 explicitly as the per-spawn default).
 *
 * The class is in-memory only — persistence (`runs/<run_id>/quota-state.json`)
 * is F-008's job per the F-022 ledger §depends-on. The verdict shape reuses
 * F-018's `RunHaltedVerdict` so F-014's retro consumer needs no changes.
 *
 * Reset semantics:
 *   - `reset(agentId)`: clears one agent's counter (e.g. spawn lifecycle end).
 *   - `resetAll()`: clears every agent's counter (e.g. run boundary).
 *   - No automatic decay — counters are monotonic per-agent until reset.
 *     (The run is the natural reset boundary; sub-run resets are F-001's
 *     cycle-boundary call site, which will use `reset` per-agent at cycle
 *     end if/when per-cycle quotas land — not in scope for this flip.)
 */
export class ToolCallQuota {
  private readonly callsByAgent = new Map<string, number>();
  private readonly maxPerAgent: number;

  constructor(maxPerAgent = 50) {
    this.maxPerAgent = maxPerAgent;
  }

  /**
   * Record a tool call by `agentId`. Returns a halt verdict if this call
   * pushed the agent's count past `maxPerAgent`; null otherwise.
   *
   * The counter increments BEFORE the threshold check, so the verdict's
   * `reason` reports the actual breach value (e.g. "51 > 50"), giving
   * operators a precise audit anchor.
   */
  recordCall(agentId: string): RunHaltedVerdict | null {
    const current = (this.callsByAgent.get(agentId) ?? 0) + 1;
    this.callsByAgent.set(agentId, current);
    if (current > this.maxPerAgent) {
      return {
        type: 'RUN_HALTED',
        trigger: 'tool_calls',
        reason: `Agent ${agentId} exceeded per-spawn tool-call quota (${current} > ${this.maxPerAgent})`,
        timestamp: new Date().toISOString(),
        agent_id: agentId,
      };
    }
    return null;
  }

  /** Return the current call count for `agentId`. Unseen agents return 0. */
  getCount(agentId: string): number {
    return this.callsByAgent.get(agentId) ?? 0;
  }

  /** Clear a single agent's counter. No-op when the agent is unseen. */
  reset(agentId: string): void {
    this.callsByAgent.delete(agentId);
  }

  /** Clear every agent's counter. Used at run-boundary reset. */
  resetAll(): void {
    this.callsByAgent.clear();
  }
}
