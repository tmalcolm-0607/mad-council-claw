import { describe, it, expect } from 'vitest';
import {
  closeSession,
  RetroMissingError,
  buildDegradationRetro,
  type RetroSignal,
  type RunHaltedVerdict,
  type DegradationRetroFields,
  type DegradationTransition,
} from '@mad-council-claw/engine-core';

/**
 * F-140 RED -> GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-140-retro-outcome-degradation.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal.
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. degrade_escalate verdict + valid Likert + valid SHA -> RetroSignal
 *      with outcome='halted_by_degradation' + trigger_evidence_sha256;
 *      closeSession(retro) returns {ok:true}.
 *   2. 60-char SHA (3-char-too-short) -> closeSession throws
 *      RetroMissingError with missingFields containing
 *      'trigger_evidence_sha256'.
 *   3. Wrong-trigger verdict (consecutive_failures_3) ->
 *      buildDegradationRetro throws Error mentioning 'expected
 *      trigger=degrade_escalate'.
 *   4. historyRender callback supplied -> meta_observations contains the
 *      rendered history string verbatim.
 *   5. No historyRender callback -> meta_observations is the caller-supplied
 *      verbatim value (no auto-injection).
 *   6. closeSession switch over outcome accepts the 5 values without
 *      unhandled-case warnings (compile-time).
 *
 * Resolves wave-016 / lane-d F21/m-1 (Opus single-model Minor):
 * RetroOutcome lacks halted_by_degradation. F-021 DegradationLadder emits a
 * halt with trigger=degrade_escalate but no matching RetroOutcome value.
 */

const VALID_FIELDS: DegradationRetroFields = {
  accuracy: 3,
  completeness: 3,
  tsg_alignment: 3,
  dx: 3,
  confidence: 3,
  what_worked: 'ladder caught the failure mode before terminal halt',
  what_was_hard: 'cascading rung escalations confused operator',
  surprises: 'reduced-tool-set rung was tripped by an unexpected resource',
  blockers: 'no feedback signal between rung 3 and rung 4',
  next_steps: 'instrument circuit-breaker per F-021 §out-of-scope-notes',
  notes: 'verdict carries trigger=degrade_escalate per F-021 contract',
  meta_observations: 'ladder history: normal -> skill-fallback -> halt',
};

const SHA_OK = 'a'.repeat(64); // 64-char lowercase hex

const DEGRADE_VERDICT: RunHaltedVerdict = {
  type: 'RUN_HALTED',
  trigger: 'degrade_escalate',
  reason: 'Degradation ladder reached halt: all fallbacks exhausted',
  timestamp: '2026-05-07T12:00:00.000Z',
};

describe('F-140 retro-outcome-degradation', () => {
  it('scenario 1: degrade_escalate verdict + valid fields + valid SHA -> validated RetroSignal; closeSession returns {ok:true}', () => {
    const retro: RetroSignal = buildDegradationRetro(
      DEGRADE_VERDICT,
      VALID_FIELDS,
      SHA_OK,
    );

    expect(retro.outcome).toBe('halted_by_degradation');
    expect(retro.trigger_evidence_sha256).toBe(SHA_OK);
    expect(retro.accuracy).toBe(3);
    expect(retro.completeness).toBe(3);
    expect(retro.tsg_alignment).toBe(3);
    expect(retro.dx).toBe(3);
    expect(retro.confidence).toBe(3);
    expect(retro.what_worked).toBe(VALID_FIELDS.what_worked);
    expect(retro.next_steps).toBe(VALID_FIELDS.next_steps);

    // F-014 close-transition contract: closeSession accepts the new value
    // and returns {ok:true} when the halted-by carve-out is satisfied.
    const result = closeSession(retro);
    expect(result.ok).toBe(true);
  });

  it('scenario 2: 60-char SHA (too short) -> closeSession throws RetroMissingError with trigger_evidence_sha256 in missingFields', () => {
    const tooShort = 'a'.repeat(60);
    const retro: RetroSignal = buildDegradationRetro(
      DEGRADE_VERDICT,
      VALID_FIELDS,
      tooShort,
    );

    let caught: unknown = null;
    try {
      closeSession(retro);
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(RetroMissingError);
    if (caught instanceof RetroMissingError) {
      expect(caught.missingFields).toContain('trigger_evidence_sha256');
    }
  });

  it('scenario 3: wrong-trigger verdict -> buildDegradationRetro throws Error mentioning expected trigger', () => {
    const wrongVerdict: RunHaltedVerdict = {
      type: 'RUN_HALTED',
      trigger: 'consecutive_failures_3',
      reason: 'consecutive failures threshold tripped',
      timestamp: '2026-05-07T12:00:00.000Z',
    };

    expect(() => {
      buildDegradationRetro(wrongVerdict, VALID_FIELDS, SHA_OK);
    }).toThrow(/expected trigger=degrade_escalate/);
  });

  it('scenario 4: historyRender callback supplied -> meta_observations contains rendered history verbatim', () => {
    const history: DegradationTransition[] = [
      { rung: 'normal', at: '2026-05-07T12:00:00.000Z', trigger: 'init' },
      {
        rung: 'skill-fallback',
        at: '2026-05-07T12:01:00.000Z',
        trigger: 'rate-limit-hit',
      },
      {
        rung: 'model-fallback',
        at: '2026-05-07T12:02:00.000Z',
        trigger: 'context-overrun',
      },
    ];
    const renderedExpected =
      'normal -> skill-fallback -> model-fallback (3 transitions)';
    const historyRender = (h: readonly DegradationTransition[]): string => {
      const path = h.map((t) => t.rung).join(' -> ');
      const tail = ` (${h.length} transitions)`;
      return path + tail;
    };

    const retro: RetroSignal = buildDegradationRetro(
      DEGRADE_VERDICT,
      VALID_FIELDS,
      SHA_OK,
      { history, historyRender },
    );
    expect(retro.meta_observations).toBe(renderedExpected);
  });

  it('scenario 5: no historyRender callback -> meta_observations is caller-supplied verbatim (no auto-injection)', () => {
    const retro: RetroSignal = buildDegradationRetro(
      DEGRADE_VERDICT,
      VALID_FIELDS,
      SHA_OK,
    );
    expect(retro.meta_observations).toBe(VALID_FIELDS.meta_observations);
  });

  it('scenario 6: RetroOutcome union extends to 5 values; closeSession accepts halted_by_degradation', () => {
    // Compile-time witness: assigning each enum value to a typed variable
    // ensures the union has at least these 5 values. Runtime check verifies
    // closeSession's switch accepts the 5th value.
    const outcomes: RetroSignal['outcome'][] = [
      'completed',
      'halted_by_kill_switch',
      'halted_by_failure_pattern',
      'halted_by_tool_quota',
      'halted_by_degradation',
    ];
    expect(outcomes).toHaveLength(5);

    // Round-trip: build a halted_by_degradation retro and verify closeSession
    // accepts it without a thrown RetroMissingError.
    const retro: RetroSignal = buildDegradationRetro(
      DEGRADE_VERDICT,
      VALID_FIELDS,
      SHA_OK,
    );
    expect(() => closeSession(retro)).not.toThrow();
  });
});
