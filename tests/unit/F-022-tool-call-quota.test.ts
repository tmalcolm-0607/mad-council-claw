import { describe, it, expect } from 'vitest';
import {
  ToolCallQuota,
  type RunHaltedVerdict,
} from '@mad-council-claw/engine-core';

/**
 * F-022 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-022-tool-quota.md
 * acceptance scenarios. Authored RED-first in wave-010 / lane-c per the
 * wave-5 retro proposal (capture RED before flipping GREEN) — same pattern
 * as F-018 in wave-009 / lane-c.
 *
 * Behavior contract (from ledger):
 *   Every tool invocation an agent makes is counted against per-agent quotas:
 *     max_calls_per_cycle (default 50), max_calls_per_run (default 1000),
 *     max_tools_active (default 10 per `mcp-tiering.md`).
 *   When any quota is reached, further tool calls from that agent reject with
 *   `QUOTA_EXCEEDED: <quota_name>` and the rejection is logged to the audit
 *   chain. Quotas are per-agent (agent A and agent B have independent counters
 *   within the same run) and run-scoped (counters reset on new run).
 *
 * Scope reconciliation with wave-9 / F-018 (FETCH BEFORE CITE):
 *   F-018 wave-009 / lane-c already added a global `recordToolCall()` method
 *   on `HaltDetector` that emits `RUN_HALTED` with trigger `tool_calls_quota`.
 *   F-022 extends that surface with PER-AGENT tracking (separate counter per
 *   agent_id) — the F-018 global counter and the F-022 per-agent counter
 *   coexist; F-018 catches runaway global usage, F-022 catches per-spawn
 *   quota exhaustion. The F-022 ledger §depends-on lists [F-001, F-002] and
 *   §soft-deps F-018 (repeated rejections may trigger halt). The brief from
 *   wave-010 / lane-c instructs encoding F-022 as `ToolCallQuota` class with
 *   `recordCall(agentId)` returning `RunHaltedVerdict | null` — the same
 *   verdict shape F-018 introduced, with `trigger: 'tool_calls'` instead of
 *   `'tool_calls_quota'` to distinguish F-022 per-agent quota from F-018
 *   global tool-call counter.
 *
 *   Per `rules/canonical-skill-only.md`-equivalent discipline (FETCH BEFORE
 *   CITE on the F-018 ledger), the wave-010 / lane-c brief proposes
 *   `trigger: 'tool_calls'` as a NEW HaltTrigger value. The F-018 ledger's
 *   12-value union already includes `tool_calls_quota` for the global
 *   counter. Adding `tool_calls` as a 13th value preserves both surfaces:
 *   F-018's global `tool_calls_quota` and F-022's per-spawn `tool_calls`.
 *   Both feed F-014's `halted_by_tool_quota` retro outcome (already in the
 *   F-014 RetroOutcome enum).
 *
 * Acceptance scenarios mirrored from the ledger + brief:
 *   1. Per-agent counter increments independently — agent A's calls do not
 *      count against agent B's quota (ledger scenario 2).
 *   2. Exceeding maxPerAgent returns RUN_HALTED with trigger='tool_calls'.
 *   3. Verdict carries agent_id of the offending agent.
 *   4. reset(agentId) clears single agent's counter.
 *   5. resetAll() clears all agents' counters.
 *   6. getCount before any call returns 0.
 *   7. Default maxPerAgent=50 (mid-point between ledger's 50/1000 caps;
 *      brief specifies this default explicitly).
 *
 * Out of scope (per ledger):
 *   - F-006 logger surfacing of QUOTA_EXCEEDED events — F-022 emits the
 *     verdict; F-006 routes it.
 *   - F-015 audit-evidence binding — `trigger_evidence_sha256` field is
 *     optional in the verdict shape; binding to a real audit row is F-015's
 *     integration step.
 *   - max_calls_per_run (1000 default) and max_tools_active (10 default)
 *     are MENTIONED in the ledger Behavior contract but the wave-10 brief
 *     scopes F-022 to per-spawn (per agent_id) cap only. Other caps live
 *     in follow-on flips (M7 skill-allowlist owns max_tools_active per
 *     ledger §out-of-scope-notes).
 *   - Skill-allowlist + version-pinning per ledger §out-of-scope (M7 owns).
 */
describe('F-022 tool-call-quota', () => {
  it('scenario 1: per-agent counter increments independently — agent A and B do not interfere', () => {
    const quota = new ToolCallQuota(5);

    // Agent A makes 3 calls — no halt.
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.getCount('agent-A')).toBe(3);

    // Agent B makes 2 calls — independent counter, no halt.
    expect(quota.recordCall('agent-B')).toBeNull();
    expect(quota.recordCall('agent-B')).toBeNull();
    expect(quota.getCount('agent-B')).toBe(2);

    // Agent A's count unchanged by B's calls.
    expect(quota.getCount('agent-A')).toBe(3);
  });

  it('scenario 2: exceeding maxPerAgent returns RUN_HALTED with trigger="tool_calls"', () => {
    const quota = new ToolCallQuota(3);

    // First three calls within budget.
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.recordCall('agent-A')).toBeNull();

    // Fourth call exceeds quota — halt fires.
    const verdict = quota.recordCall('agent-A');
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      const v: RunHaltedVerdict = verdict;
      expect(v.type).toBe('RUN_HALTED');
      expect(v.trigger).toBe('tool_calls');
      // Reason mentions count vs cap so operators see the breach value.
      expect(v.reason).toContain('4');
      expect(v.reason).toContain('3');
      // ISO-8601 timestamp shape sanity check.
      expect(typeof v.timestamp).toBe('string');
      expect(new Date(v.timestamp).toString()).not.toBe('Invalid Date');
    }
  });

  it('scenario 3: verdict carries agent_id of the offending agent', () => {
    const quota = new ToolCallQuota(2);

    quota.recordCall('agent-X');
    quota.recordCall('agent-X');
    const verdict = quota.recordCall('agent-X');

    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.agent_id).toBe('agent-X');
    }
  });

  it('scenario 4: reset(agentId) clears a single agent\'s counter', () => {
    const quota = new ToolCallQuota(3);

    quota.recordCall('agent-A');
    quota.recordCall('agent-A');
    quota.recordCall('agent-B');
    expect(quota.getCount('agent-A')).toBe(2);
    expect(quota.getCount('agent-B')).toBe(1);

    quota.reset('agent-A');
    expect(quota.getCount('agent-A')).toBe(0);
    // Agent B's counter is untouched.
    expect(quota.getCount('agent-B')).toBe(1);

    // After reset, agent A can make 3 more calls before halt.
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.recordCall('agent-A')).toBeNull();
    expect(quota.recordCall('agent-A')).toBeNull();
    // The 4th call halts.
    expect(quota.recordCall('agent-A')).not.toBeNull();
  });

  it('scenario 5: resetAll() clears every agent\'s counter', () => {
    const quota = new ToolCallQuota(10);

    quota.recordCall('agent-A');
    quota.recordCall('agent-A');
    quota.recordCall('agent-B');
    quota.recordCall('agent-C');
    expect(quota.getCount('agent-A')).toBe(2);
    expect(quota.getCount('agent-B')).toBe(1);
    expect(quota.getCount('agent-C')).toBe(1);

    quota.resetAll();
    expect(quota.getCount('agent-A')).toBe(0);
    expect(quota.getCount('agent-B')).toBe(0);
    expect(quota.getCount('agent-C')).toBe(0);
  });

  it('scenario 6: getCount before any call returns 0', () => {
    const quota = new ToolCallQuota();
    expect(quota.getCount('never-seen-agent')).toBe(0);
  });

  it('scenario 7: default maxPerAgent is 50 — 50 calls succeed, 51st halts', () => {
    const quota = new ToolCallQuota();

    // 50 calls within the default budget.
    for (let i = 0; i < 50; i++) {
      expect(quota.recordCall('agent-A')).toBeNull();
    }

    // 51st call halts.
    const verdict = quota.recordCall('agent-A');
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe('tool_calls');
      expect(verdict.reason).toContain('51');
      expect(verdict.reason).toContain('50');
    }
  });

  it('per-agent quota: agent-B can keep calling after agent-A is over quota', () => {
    const quota = new ToolCallQuota(2);

    // Agent A exhausts.
    quota.recordCall('agent-A');
    quota.recordCall('agent-A');
    const aHalt = quota.recordCall('agent-A');
    expect(aHalt).not.toBeNull();
    if (aHalt !== null) {
      expect(aHalt.agent_id).toBe('agent-A');
    }

    // Agent B is independent — first two calls succeed.
    expect(quota.recordCall('agent-B')).toBeNull();
    expect(quota.recordCall('agent-B')).toBeNull();
    // Agent B's 3rd call halts on its OWN counter.
    const bHalt = quota.recordCall('agent-B');
    expect(bHalt).not.toBeNull();
    if (bHalt !== null) {
      expect(bHalt.agent_id).toBe('agent-B');
    }
  });
});
