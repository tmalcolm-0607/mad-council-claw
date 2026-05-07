import { describe, it, expect } from 'vitest';
import {
  closeSession,
  RetroMissingError,
  type RetroSignal,
} from '@mad-council-claw/engine-core';

/**
 * F-014 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-014-pre-close-retro-signal.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal
 * (capture RED before flipping GREEN).
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. Run that completes naturally → retro carries 5 axes scored and
 *      outcome="completed".
 *   2. Run halted by kill-switch → retro carries outcome="halted_by_kill_switch"
 *      and trigger_evidence_sha256 matching the halt audit entry.
 *   3. Buggy impl that omits retro → close transition rejects with
 *      RETRO_MISSING; the run does not reach `closed`.
 *
 * Scope deviation from ledger (intentional, documented):
 *   The ledger names test files under `tests/integration/governance/` because
 *   it co-targets F-008 (storage layout for retro.json). F-014 is a unit-level
 *   flip here that exercises the in-memory `closeSession` boundary contract;
 *   filesystem persistence is F-008's job per the ledger out-of-scope-notes.
 *   The RETRO_MISSING rejection in scenario 3 is the boundary contract that
 *   F-008 will plug into. This mirrors the F-002 / wave-006 pattern (stamp
 *   primitive landed unit-level; storage path deferred to F-008).
 *
 * 5-axis Likert per ledger §Behavior contract:
 *   accuracy / completeness / tsg_alignment / dx / confidence (each 1-5).
 *
 * 7 pattern fields per the kit's `council-retro` skill rubric (cited in the
 * ledger's surface trace as kit:council-retro-skill):
 *   what_worked / what_was_hard / surprises / blockers / next_steps / notes
 *   / meta_observations.
 */
describe('F-014 pre-close-retro-signal', () => {
  // Reusable valid retro fixture — every required field present and in range.
  const validRetro = (): RetroSignal => ({
    accuracy: 4,
    completeness: 5,
    tsg_alignment: 3,
    dx: 4,
    confidence: 5,
    what_worked: 'parallel investigators decomposed cleanly',
    what_was_hard: 'baseline RBAC drift on the target RG',
    surprises: 'NSP propagation 5-15 min not 30s',
    blockers: 'none',
    next_steps: 'land F-015 hash-chained audit log next',
    notes: 'wave-008 / lane-a scope',
    meta_observations: 'RED-before-GREEN discipline held',
    outcome: 'completed',
  });

  it('scenario 1: closeSession with valid retro returns ok and accepts outcome=completed', () => {
    const result = closeSession(validRetro());
    expect(result.ok).toBe(true);
  });

  it('scenario 2: closeSession with no retro rejects with RETRO_MISSING', () => {
    expect(() => closeSession(null)).toThrow(RetroMissingError);
    expect(() => closeSession(null)).toThrow(/RETRO_MISSING/);
  });

  it('scenario 3a: closeSession with retro missing one Likert axis rejects', () => {
    const partial: Partial<RetroSignal> = { ...validRetro() };
    delete partial.tsg_alignment;
    expect(() => closeSession(partial)).toThrow(RetroMissingError);
    try {
      closeSession(partial);
    } catch (e) {
      expect(e).toBeInstanceOf(RetroMissingError);
      expect((e as RetroMissingError).missingFields).toContain('tsg_alignment');
    }
  });

  it('scenario 3b: closeSession with retro missing one pattern field rejects', () => {
    const partial: Partial<RetroSignal> = { ...validRetro() };
    delete partial.what_worked;
    expect(() => closeSession(partial)).toThrow(RetroMissingError);
    try {
      closeSession(partial);
    } catch (e) {
      expect((e as RetroMissingError).missingFields).toContain('what_worked');
    }
  });

  it('scenario 3c: closeSession with Likert score out of 1-5 range rejects', () => {
    const oor: RetroSignal = { ...validRetro(), accuracy: 7 };
    expect(() => closeSession(oor)).toThrow(RetroMissingError);
    try {
      closeSession(oor);
    } catch (e) {
      const msg = (e as RetroMissingError).missingFields.join(',');
      expect(msg).toMatch(/accuracy/);
    }
  });

  it('scenario 3d: closeSession with Likert score below 1 rejects', () => {
    const oor: RetroSignal = { ...validRetro(), confidence: 0 };
    expect(() => closeSession(oor)).toThrow(RetroMissingError);
  });

  it('halted-by carve-out: outcome=halted_by_kill_switch requires trigger_evidence_sha256', () => {
    // Ledger acceptance scenario 2: halted runs MUST carry trigger evidence.
    const halted: RetroSignal = {
      ...validRetro(),
      outcome: 'halted_by_kill_switch',
      // trigger_evidence_sha256 intentionally absent → must reject
    };
    expect(() => closeSession(halted)).toThrow(RetroMissingError);
    try {
      closeSession(halted);
    } catch (e) {
      expect((e as RetroMissingError).missingFields).toContain(
        'trigger_evidence_sha256',
      );
    }
  });

  it('halted-by carve-out: halted retro with trigger_evidence_sha256 succeeds', () => {
    const halted: RetroSignal = {
      ...validRetro(),
      outcome: 'halted_by_kill_switch',
      trigger_evidence_sha256: 'a'.repeat(64),
    };
    const result = closeSession(halted);
    expect(result.ok).toBe(true);
  });
});
