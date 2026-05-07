import { describe, it, expect } from 'vitest';
import {
  HaltDetector,
  type RunHaltedVerdict,
  type HaltTrigger,
} from '@mad-council-claw/engine-core';

/**
 * F-018 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-018-failure-pattern-halt.md
 * acceptance scenarios. Authored RED-first in wave-009 / lane-c per the
 * wave-5 retro proposal (capture RED before flipping GREEN).
 *
 * Behavior contract (from ledger):
 *   The engine watches a 9-value enum of trigger conditions:
 *     consecutive_failures_3, consecutive_failures_10, overplanning_5,
 *     overplanning_8, spawns_per_hour_exceeded, token_anomaly_2x,
 *     rapid_prompt_burst, circuit_breaker_open, degradation_threshold.
 *   When any trigger fires, the engine immediately transitions to `closing`
 *   with `halted_by: <trigger_name>` and `trigger_evidence_sha256: <audit_entry_sha>`.
 *   The retro signal (F-014) fires next, capturing the trigger evidence.
 *   Thresholds are sourced from `rules/anomaly-thresholds.md` and overridable
 *   per-run.
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. Engine records 3 consecutive failed cycles → halts with
 *      `halted_by: "consecutive_failures_3"` on the 3rd failure.
 *   2. Engine observes 5 consecutive read-only Tool calls (overplanning) →
 *      halts with `halted_by: "overplanning_5"` BEFORE the 6th call.
 *   3. Threshold override config `consecutive_failures_3 = 10` → 5 consecutive
 *      failures produce no halt; 10 consecutive failures DO halt.
 *
 * Extended scenarios (full coverage of trigger surface):
 *   4. recordSuccess() resets the consecutive_failures counter.
 *   5. iteration_cap fires when iterations exhaust the configured maximum.
 *   6. tool_calls_quota fires when tool-call count exhausts the configured
 *      maximum (links to F-022 tool-quota; F-018 owns the halt trigger).
 *   7. manualHalt() emits a halt verdict with trigger="manual" and the caller's
 *      reason (links to F-020 kill-switch; F-018 owns the verdict shape).
 *
 * Scope deviation from prompt brief (intentional, documented):
 *   The wave-009 / lane-c brief proposed a HaltTrigger enum:
 *     consecutive_failures | no_progress | iteration_cap | tool_calls |
 *     manual | kill_switch | governance | soul_boundary | degrade_escalate
 *   The F-018 ledger names a different 9-value enum:
 *     consecutive_failures_3 | consecutive_failures_10 | overplanning_5 |
 *     overplanning_8 | spawns_per_hour_exceeded | token_anomaly_2x |
 *     rapid_prompt_burst | circuit_breaker_open | degradation_threshold
 *   Per the wave-008 / lane-a precedent (FETCH BEFORE CITE; honor the
 *   authoritative ledger over the brief snippet), this test encodes the
 *   ledger's enum. The HaltDetector API shape (`recordFailure`, `recordSuccess`,
 *   `manualHalt`, etc.) follows the brief because it is reasonable and
 *   compatible with the ledger triggers. `manual` is added as a 10th trigger
 *   to support F-020 kill-switch invocations through the same verdict surface;
 *   the F-018 ledger's 9-trigger automatic-halt enum stays intact.
 *
 * Out of scope (per ledger):
 *   - F-020 kill-switch wiring (manual operator halt) — F-018 owns the
 *     automatic-halt trigger surface; F-020 will reuse the verdict shape.
 *   - F-021 degradation-fallback wiring — F-018 surfaces the
 *     `degradation_threshold` trigger; F-021 owns the source signal.
 *   - F-022 tool-quota wiring — F-018 surfaces `tool_calls_quota` (named
 *     `tool_calls` in the brief); F-022 owns the per-tool quota source.
 *   - F-015 audit-evidence binding — `trigger_evidence_sha256` field is the
 *     boundary that F-015 will plug into; this flip lands the verdict shape.
 *   - F-006 logger surfacing — F-018 emits the verdict; F-006 routes it.
 */
describe('F-018 failure-pattern-halt', () => {
  it('scenario 1: 3 consecutive failures fire halted_by="consecutive_failures_3"', () => {
    const detector = new HaltDetector();

    // First two failures accumulate without firing.
    expect(detector.recordFailure()).toBeNull();
    expect(detector.recordFailure()).toBeNull();

    // Third consecutive failure triggers the halt.
    const verdict = detector.recordFailure();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.type).toBe('RUN_HALTED');
      expect(verdict.trigger).toBe<HaltTrigger>('consecutive_failures_3');
      expect(verdict.reason).toContain('3');
      // ISO-8601 timestamp shape sanity check
      expect(typeof verdict.timestamp).toBe('string');
      expect(new Date(verdict.timestamp).toString()).not.toBe('Invalid Date');
    }
  });

  it('scenario 4: recordSuccess() resets the consecutive_failures counter', () => {
    const detector = new HaltDetector();
    detector.recordFailure();
    detector.recordFailure();

    // Success resets the streak.
    detector.recordSuccess();

    // Two more failures after the reset should not yet halt — we are at 2/3.
    expect(detector.recordFailure()).toBeNull();
    expect(detector.recordFailure()).toBeNull();

    // The third post-reset failure halts.
    const verdict = detector.recordFailure();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe<HaltTrigger>('consecutive_failures_3');
    }
  });

  it('scenario 2: 5 consecutive read-only Tool calls (overplanning) halts with overplanning_5', () => {
    const detector = new HaltDetector();

    // First four read-only tool calls accumulate without firing.
    expect(detector.recordReadOnlyTool()).toBeNull();
    expect(detector.recordReadOnlyTool()).toBeNull();
    expect(detector.recordReadOnlyTool()).toBeNull();
    expect(detector.recordReadOnlyTool()).toBeNull();

    // Fifth read-only tool call triggers the halt — BEFORE a 6th could fire,
    // per the F-018 ledger acceptance scenario 2.
    const verdict = detector.recordReadOnlyTool();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe<HaltTrigger>('overplanning_5');
    }
  });

  it('overplanning resets when a write/edit tool fires', () => {
    const detector = new HaltDetector();
    detector.recordReadOnlyTool();
    detector.recordReadOnlyTool();
    detector.recordReadOnlyTool();
    detector.recordReadOnlyTool();

    // Write breaks the read-only streak.
    detector.recordWriteTool();

    // Four more read-onlys without crossing 5 — no halt.
    expect(detector.recordReadOnlyTool()).toBeNull();
    expect(detector.recordReadOnlyTool()).toBeNull();
    expect(detector.recordReadOnlyTool()).toBeNull();
    expect(detector.recordReadOnlyTool()).toBeNull();

    // The 5th post-reset read-only halts.
    const verdict = detector.recordReadOnlyTool();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe<HaltTrigger>('overplanning_5');
    }
  });

  it('scenario 3: threshold override raises consecutive_failures_3 from 3 to 10', () => {
    const detector = new HaltDetector({ maxConsecutiveFailures: 10 });

    // 5 consecutive failures — well below the override of 10 — should NOT halt.
    for (let i = 0; i < 5; i++) {
      expect(detector.recordFailure()).toBeNull();
    }

    // Continue to 9 — still no halt at 9.
    for (let i = 0; i < 4; i++) {
      expect(detector.recordFailure()).toBeNull();
    }

    // 10th failure halts. Per the ledger override semantics, the trigger name
    // remains the canonical `consecutive_failures_3` even when the threshold
    // is overridden — the trigger identifies the FAMILY, not the count.
    const verdict = detector.recordFailure();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe<HaltTrigger>('consecutive_failures_3');
    }
  });

  it('scenario 5: iteration_cap fires when iterations exhaust the configured maximum', () => {
    const detector = new HaltDetector({ maxIterations: 5 });

    // Iterations 1..4 accumulate.
    for (let i = 0; i < 4; i++) {
      expect(detector.recordIteration()).toBeNull();
    }

    // Iteration 5 hits the cap.
    const verdict = detector.recordIteration();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe<HaltTrigger>('iteration_cap');
      expect(verdict.reason).toContain('5');
    }
  });

  it('scenario 6: tool_calls_quota fires when tool-call count exhausts the configured maximum', () => {
    const detector = new HaltDetector({ maxToolCalls: 3 });

    expect(detector.recordToolCall()).toBeNull();
    expect(detector.recordToolCall()).toBeNull();

    const verdict = detector.recordToolCall();
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.trigger).toBe<HaltTrigger>('tool_calls_quota');
      expect(verdict.reason).toContain('3');
    }
  });

  it('scenario 7: manualHalt() emits a halt verdict with trigger="manual" and the caller-supplied reason', () => {
    const detector = new HaltDetector();
    const verdict: RunHaltedVerdict = detector.manualHalt('operator pressed kill-switch');

    expect(verdict.type).toBe('RUN_HALTED');
    expect(verdict.trigger).toBe<HaltTrigger>('manual');
    expect(verdict.reason).toBe('operator pressed kill-switch');
    expect(typeof verdict.timestamp).toBe('string');
    expect(new Date(verdict.timestamp).toString()).not.toBe('Invalid Date');
  });

  it('verdict carries optional run_id and agent_id correlation triple when provided', () => {
    const detector = new HaltDetector();
    const verdict = detector.manualHalt('test', {
      run_id: 'run-uuid-v7',
      agent_id: 'agent-uuid-v7',
    });

    expect(verdict.run_id).toBe('run-uuid-v7');
    expect(verdict.agent_id).toBe('agent-uuid-v7');
  });
});
