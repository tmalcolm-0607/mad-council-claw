/**
 * F-021 Degradation & fallback ladder — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-021-degradation-fallback.md
 * + wave-012 / lane-a brief.
 *
 * Behavior contract (lane-a brief shape):
 *   A 5-rung escalation ladder for graceful degradation:
 *     normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt
 *   Each rung represents a degradation strategy attempted before the next
 *   escalation. The ladder tracks current rung, last trigger reason, and
 *   transition history. Reaching `halt` produces a RUN_HALTED verdict
 *   (trigger: 'degrade_escalate') reusing the F-018 verdict shape per the
 *   wave-011 / lane-a "verdict-shape reuse across halt features" rule.
 *
 * Scope deviation from ledger (per `rules/no-silent-deferrals.md`):
 *   The F-021 ledger Behavior contract describes a 5-rule policy (per-resource
 *   circuit-breaker open/half-open/closed, Context-Gaps user-facing emission,
 *   required-vs-optional dependency classification with F-018 hand-off for
 *   required failures, sliding-window thresholds from `rules/anomaly-thresholds.md`).
 *   The wave-012 lane-a brief narrows initial F-021 scope to the in-memory
 *   escalation-ladder primitive that downstream features (circuit-breaker,
 *   Context-Gaps emitter, dependency classifier, F-006 logger integration,
 *   F-015 audit-log per-failure entries) will plug into. The substantive
 *   guarantees — escalation is one-rung-at-a-time; halt is terminal; history
 *   is auditable — are preserved here. Per FETCH BEFORE CITE + wave-008/wave-009/
 *   wave-010-b precedent, scope-narrowing in the brief is honored explicitly.
 *
 * Wave-011 / lane-a verdict-shape reuse rule applied:
 *   The halt verdict at the top of the ladder reuses F-018's `RunHaltedVerdict`
 *   shape with sibling trigger 'degrade_escalate' (a 14th value added to the
 *   `HaltTrigger` union in halt.ts in this same wave). This is distinct from
 *   F-018's existing `'degradation_threshold'` value: the latter fires when a
 *   sliding-window threshold trips (future scope); `'degrade_escalate'` fires
 *   when this ladder reaches the 'halt' rung after exhausting all fallbacks.
 *   Retro outcomes can tell escalation-exhaustion apart from threshold-tripped
 *   halts because the trigger names differ.
 */

import type { RunHaltedVerdict } from './halt.js';

/**
 * The 6 rungs of the degradation ladder. `normal` is steady state; `halt` is
 * the terminal rung that emits a `RunHaltedVerdict`. The 4 middle rungs are
 * progressively more constrained operating modes the engine can fall through
 * before halting.
 */
export type DegradationRung =
  | 'normal'
  | 'skill-fallback'
  | 'model-fallback'
  | 'reduced-tool-set'
  | 'headless'
  | 'halt';

/**
 * One transition entry recorded in the ladder's history. `rung` is the rung
 * the ladder was AT when the transition fired (i.e. the FROM state); `at` is
 * an ISO-8601 UTC timestamp; `trigger` is the caller-supplied reason string
 * (recover transitions are prefixed with `recover:` to disambiguate from
 * escalations).
 */
export interface DegradationTransition {
  rung: DegradationRung;
  at: string;
  trigger: string;
}

/**
 * Snapshot of the ladder's current state. `getState()` returns a Readonly
 * view; callers must not mutate. `current` is the rung the ladder is on now;
 * `trigger` is the most recent transition reason; `history` is the append-only
 * transition log.
 */
export interface DegradationState {
  current: DegradationRung;
  trigger: string;
  history: DegradationTransition[];
}

/**
 * In-memory degradation ladder.
 *
 * Acceptance scenarios from the F-021 ledger + wave-012 lane-a brief:
 *   1. New ladder starts at 'normal'.
 *   2. escalate() advances exactly one rung at a time.
 *   3. escalate() returns null until the ladder reaches 'halt'; the
 *      halt-reaching call returns a `RunHaltedVerdict` with
 *      trigger='degrade_escalate'.
 *   4. recover() moves down exactly one rung; recover at 'normal' is a no-op;
 *      recover from 'halt' is a no-op (halt is terminal).
 *   5. Every transition is recorded in the history with FROM-rung + timestamp
 *      + trigger reason; recover entries are prefixed `recover:` so the log
 *      disambiguates from escalations.
 *
 * Halt termination:
 *   Once the ladder reaches 'halt', further escalate() calls are idempotent —
 *   they keep returning a halt verdict but do NOT add to history (no state
 *   change to record). recover() from halt is also a no-op. The only way out
 *   of halt is constructing a fresh ladder.
 */
export class DegradationLadder {
  private readonly rungs: DegradationRung[] = [
    'normal',
    'skill-fallback',
    'model-fallback',
    'reduced-tool-set',
    'headless',
    'halt',
  ];
  private state: DegradationState;

  constructor() {
    this.state = {
      current: 'normal',
      trigger: 'init',
      history: [],
    };
  }

  /** Current rung. */
  getCurrent(): DegradationRung {
    return this.state.current;
  }

  /**
   * Snapshot of current state. Returned object is typed `Readonly` to signal
   * non-mutation; callers should treat it as immutable. (For perf this is the
   * live reference, not a deep clone — tests and downstream consumers must
   * not modify it.)
   */
  getState(): Readonly<DegradationState> {
    return this.state;
  }

  /**
   * Escalate one rung. The `trigger` string is recorded in history and
   * propagated into the halt verdict reason if this call reaches 'halt'.
   *
   * Returns:
   *   - null if the ladder advanced to a non-halt rung (or was already at
   *     halt; see termination rule below).
   *   - a `RunHaltedVerdict` (trigger='degrade_escalate') if this call lands
   *     on or remains at 'halt'. Idempotent: subsequent calls from halt also
   *     return a halt verdict without further state change.
   */
  escalate(trigger: string): RunHaltedVerdict | null {
    const idx = this.rungs.indexOf(this.state.current);
    if (this.state.current === 'halt') {
      // Terminal: no state change, but signal halt to the caller.
      return this.haltVerdict(trigger);
    }
    const next = this.rungs[idx + 1];
    if (next === undefined) {
      // Defensive: should be unreachable given the halt branch above.
      return this.haltVerdict(trigger);
    }
    this.state.history.push({
      rung: this.state.current,
      at: new Date().toISOString(),
      trigger,
    });
    this.state.current = next;
    this.state.trigger = trigger;
    if (next === 'halt') {
      return this.haltVerdict(trigger);
    }
    return null;
  }

  /**
   * Recover one rung. The `reason` string is prefixed with `recover:` and
   * recorded in history. recover() at 'normal' is a no-op (no rung to drop
   * to). recover() from 'halt' is also a no-op (halt is terminal).
   */
  recover(reason: string): void {
    if (this.state.current === 'halt') {
      // Terminal — recover is a no-op.
      return;
    }
    const idx = this.rungs.indexOf(this.state.current);
    if (idx <= 0) {
      // Already at 'normal' — nothing to recover toward.
      return;
    }
    const prev = this.rungs[idx - 1];
    if (prev === undefined) {
      // Defensive: should be unreachable given the idx<=0 check above.
      return;
    }
    this.state.history.push({
      rung: this.state.current,
      at: new Date().toISOString(),
      trigger: `recover:${reason}`,
    });
    this.state.current = prev;
    this.state.trigger = `recover:${reason}`;
  }

  private haltVerdict(trigger: string): RunHaltedVerdict {
    return {
      type: 'RUN_HALTED',
      trigger: 'degrade_escalate',
      reason: `Degradation ladder reached halt: ${trigger}`,
      timestamp: new Date().toISOString(),
    };
  }
}
