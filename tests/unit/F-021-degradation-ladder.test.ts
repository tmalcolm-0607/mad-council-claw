import { describe, it, expect } from 'vitest';
import {
  DegradationLadder,
  type DegradationRung,
  type DegradationState,
  type RunHaltedVerdict,
  type HaltTrigger,
} from '@mad-council-claw/engine-core';

/**
 * F-021 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-021-degradation-fallback.md
 * acceptance scenarios + wave-012 / lane-a brief.
 *
 * Behavior contract (lane-a brief shape):
 *   A 5-rung escalation ladder for graceful degradation:
 *     normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt
 *   Each rung represents a degradation strategy attempted before the next
 *   escalation. The ladder tracks current rung, last trigger reason, and
 *   transition history. Reaching `halt` produces a RUN_HALTED verdict
 *   (trigger: 'degrade_escalate') reusing the F-018 verdict shape per the
 *   wave-011 lane-a "verdict-shape reuse across halt features" rule.
 *
 * Scope deviation from ledger (intentional, documented per
 * `rules/no-silent-deferrals.md`):
 *   The F-021 ledger Behavior contract describes a 5-rule policy with
 *   circuit-breaker open/half-open/closed state for individual external
 *   resources, Context-Gaps emission tied to user-facing status, and
 *   required-vs-optional-dependency classification. The wave-012 lane-a brief
 *   narrows initial F-021 scope to the in-memory escalation-ladder primitive
 *   that downstream features (circuit-breaker, Context-Gaps emitter, dependency
 *   classifier) will plug into. The substantive guarantees — escalation is
 *   one-rung-at-a-time, halt is terminal, history is auditable — are
 *   preserved; the per-resource circuit-breaker state machine + Context-Gaps
 *   wiring + required-dependency classification + F-018 hand-off for required
 *   failures are deferred to engine-cycle integration.
 *   Per FETCH BEFORE CITE + wave-008/wave-009/wave-010-b precedent (honor the
 *   brief when it explicitly narrows scope; surface the gap explicitly).
 *
 * Acceptance scenarios:
 *   1. New ladder starts at rung 'normal'.
 *   2. escalate('reason') from 'normal' → moves to 'skill-fallback'; returns null.
 *   3. escalate sequence advances ONE rung at a time:
 *      normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt.
 *   4. escalate from 'headless' → reaches 'halt' AND returns a RunHaltedVerdict
 *      with type='RUN_HALTED', trigger='degrade_escalate', reason includes the
 *      caller-supplied trigger text, and an ISO-8601 timestamp.
 *   5. recover('reason') from a non-normal rung moves DOWN one rung; recover
 *      from 'normal' is a no-op.
 *   6. 'halt' is terminal: recover() from halt is a no-op; further escalate()
 *      calls keep returning a halt verdict (idempotent).
 *   7. State.history records every transition (rung at time of move, ISO
 *      timestamp, trigger reason).
 *
 * Out of scope (per `rules/no-silent-deferrals.md`):
 *   - Per-resource circuit-breaker open/half-open/closed state machine
 *     (F-021 ledger Behavior contract scenario 1).
 *   - Context-Gaps section emission tied to user-facing status output
 *     (F-021 ledger scenario 2).
 *   - Required-vs-optional-dependency classification + automatic F-018 halt
 *     hand-off when a required dependency fails (F-021 ledger scenario 3).
 *   - Sliding-window threshold sourcing from `rules/anomaly-thresholds.md`.
 *   - F-006 logger Context-Gaps line emission integration.
 *   - F-015 audit-log entry per failure observation.
 *
 * Wave-011 lane-a verdict-shape-reuse rule applied:
 *   The halt verdict emitted at the top of the ladder reuses F-018's
 *   `RunHaltedVerdict` shape with sibling trigger 'degrade_escalate' (the
 *   F-018 ledger's 9th automatic-halt trigger value `degradation_threshold`
 *   was reserved for sliding-window degradation; this primitive uses the
 *   ladder-top trigger which is deliberately distinct so retro outcomes can
 *   tell escalation-exhaustion apart from threshold-tripped halts).
 */
describe('F-021 degradation ladder', () => {
  it('scenario 1: new ladder starts at rung "normal"', () => {
    const ladder = new DegradationLadder();
    expect(ladder.getCurrent()).toBe<DegradationRung>('normal');
  });

  it('scenario 2: escalate from "normal" → moves to "skill-fallback" and returns null', () => {
    const ladder = new DegradationLadder();
    const result = ladder.escalate('mcp 503');
    expect(result).toBeNull();
    expect(ladder.getCurrent()).toBe<DegradationRung>('skill-fallback');
  });

  it('scenario 3: escalate sequence advances exactly one rung at a time', () => {
    const ladder = new DegradationLadder();
    const sequence: DegradationRung[] = [
      'skill-fallback',
      'model-fallback',
      'reduced-tool-set',
      'headless',
      'halt',
    ];
    for (const expected of sequence) {
      ladder.escalate(`step-to-${expected}`);
      expect(ladder.getCurrent()).toBe<DegradationRung>(expected);
    }
  });

  it('scenario 4: escalate from "headless" → reaches "halt" AND returns RunHaltedVerdict (trigger=degrade_escalate)', () => {
    const ladder = new DegradationLadder();
    // Climb to headless.
    ladder.escalate('a');
    ladder.escalate('b');
    ladder.escalate('c');
    ladder.escalate('d');
    expect(ladder.getCurrent()).toBe<DegradationRung>('headless');

    const verdict = ladder.escalate('all-fallbacks-exhausted');
    expect(ladder.getCurrent()).toBe<DegradationRung>('halt');
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.type).toBe('RUN_HALTED');
      expect(verdict.trigger).toBe<HaltTrigger>('degrade_escalate');
      expect(typeof verdict.reason).toBe('string');
      expect(verdict.reason.length).toBeGreaterThan(0);
      expect(verdict.reason).toContain('all-fallbacks-exhausted');
      expect(typeof verdict.timestamp).toBe('string');
      expect(new Date(verdict.timestamp).toString()).not.toBe('Invalid Date');
    }
  });

  it('scenario 5a: recover from non-normal rung moves DOWN one rung', () => {
    const ladder = new DegradationLadder();
    ladder.escalate('mcp 503');
    ladder.escalate('telemetry timeout');
    expect(ladder.getCurrent()).toBe<DegradationRung>('model-fallback');

    ladder.recover('mcp recovered');
    expect(ladder.getCurrent()).toBe<DegradationRung>('skill-fallback');

    ladder.recover('telemetry recovered');
    expect(ladder.getCurrent()).toBe<DegradationRung>('normal');
  });

  it('scenario 5b: recover from "normal" is a no-op', () => {
    const ladder = new DegradationLadder();
    expect(ladder.getCurrent()).toBe<DegradationRung>('normal');
    const sizeBefore = ladder.getState().history.length;
    ladder.recover('nothing-to-recover');
    expect(ladder.getCurrent()).toBe<DegradationRung>('normal');
    expect(ladder.getState().history.length).toBe(sizeBefore);
  });

  it('scenario 6a: "halt" is terminal — recover from halt is a no-op', () => {
    const ladder = new DegradationLadder();
    // Climb all the way to halt.
    for (let i = 0; i < 5; i++) {
      ladder.escalate(`step-${i}`);
    }
    expect(ladder.getCurrent()).toBe<DegradationRung>('halt');

    const sizeBefore = ladder.getState().history.length;
    ladder.recover('attempted-recover-from-halt');
    expect(ladder.getCurrent()).toBe<DegradationRung>('halt');
    expect(ladder.getState().history.length).toBe(sizeBefore);
  });

  it('scenario 6b: further escalate from "halt" remains at halt and returns a halt verdict (idempotent)', () => {
    const ladder = new DegradationLadder();
    for (let i = 0; i < 5; i++) {
      ladder.escalate(`step-${i}`);
    }
    expect(ladder.getCurrent()).toBe<DegradationRung>('halt');

    const v1: RunHaltedVerdict | null = ladder.escalate('post-halt-attempt');
    expect(v1).not.toBeNull();
    if (v1 !== null) {
      expect(v1.type).toBe('RUN_HALTED');
      expect(v1.trigger).toBe<HaltTrigger>('degrade_escalate');
    }
    expect(ladder.getCurrent()).toBe<DegradationRung>('halt');
  });

  it('scenario 7: state.history records every transition with rung, timestamp, trigger', () => {
    const ladder = new DegradationLadder();
    ladder.escalate('first');
    ladder.escalate('second');
    ladder.recover('relief');

    const state: Readonly<DegradationState> = ladder.getState();
    expect(state.current).toBe<DegradationRung>('skill-fallback');
    expect(state.history.length).toBe(3);

    // First entry: was at 'normal' when 'first' fired.
    expect(state.history[0]?.rung).toBe<DegradationRung>('normal');
    expect(state.history[0]?.trigger).toBe('first');
    expect(typeof state.history[0]?.at).toBe('string');
    expect(new Date(state.history[0]!.at).toString()).not.toBe('Invalid Date');

    // Second entry: was at 'skill-fallback' when 'second' fired.
    expect(state.history[1]?.rung).toBe<DegradationRung>('skill-fallback');
    expect(state.history[1]?.trigger).toBe('second');

    // Third entry: was at 'model-fallback' when recover('relief') fired.
    expect(state.history[2]?.rung).toBe<DegradationRung>('model-fallback');
    expect(state.history[2]?.trigger).toBe('recover:relief');
  });

  it('robustness: escalate trigger reason is preserved verbatim in halt verdict reason', () => {
    const ladder = new DegradationLadder();
    for (let i = 0; i < 4; i++) {
      ladder.escalate(`climb-${i}`);
    }
    const verdict = ladder.escalate('terminal-reason-with-special-chars: 503/timeout/<x>');
    expect(verdict).not.toBeNull();
    if (verdict !== null) {
      expect(verdict.reason).toContain('terminal-reason-with-special-chars: 503/timeout/<x>');
    }
  });

  it('robustness: getState() returns a current snapshot with all 3 fields', () => {
    const ladder = new DegradationLadder();
    ladder.escalate('only-trigger');
    const state = ladder.getState();
    expect(state.current).toBe<DegradationRung>('skill-fallback');
    expect(state.trigger).toBe('only-trigger');
    expect(Array.isArray(state.history)).toBe(true);
    expect(state.history.length).toBe(1);
  });
});
