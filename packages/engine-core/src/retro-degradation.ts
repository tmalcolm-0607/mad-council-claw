/**
 * F-140 retro-outcome-degradation — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-140-retro-outcome-degradation.md.
 *
 * Behavior contract (from ledger):
 *   The `RetroOutcome` discriminated union (F-014 owner) gains a 5th value:
 *   `halted_by_degradation`. The F-014 `closeSession` validation accepts the
 *   new value as a halted-by carve-out (requires `trigger_evidence_sha256`
 *   64-hex). This file authors a helper that constructs a degradation-halt
 *   RetroSignal from a F-021 RunHaltedVerdict (trigger='degrade_escalate')
 *   + caller-supplied 5-axis Likert + 7 pattern-prose fields + audit chain
 *   head, returning the validated retro object the caller passes to
 *   closeSession.
 *
 *   The RetroOutcome enum extension lives in retro.ts (F-014 owner, additive
 *   modification: 5th union value + HALTED_OUTCOMES set entry +
 *   validOutcomes set entry inside closeSession). Persistence to
 *   runs/<run_id>/retro.json is F-008's job per the F-014 ledger.
 *
 * Anti-orchestrator-impostor discipline per `kit:rules/orchestrator-identity.md`:
 *   This module NEVER calls `closeSession` directly. It returns a validated
 *   RetroSignal; the caller (F-138 cycle.ts in a future iteration) calls
 *   `closeSession(retro)` to fire the F-014 boundary. The F-014
 *   close-transition stays with F-014.
 *
 * Boundary-validation discipline:
 *   `buildDegradationRetro` throws `Error` (NOT RetroMissingError — that's
 *   F-014's specific contract) when `verdict.trigger !== 'degrade_escalate'`.
 *   This is a defensive boundary that prevents callers from feeding a
 *   wrong-shape halt verdict into the helper and getting a misleading
 *   `halted_by_degradation` retro for what was actually e.g. a
 *   `consecutive_failures_3` halt.
 *
 * No-invented-constraints discipline per `kit:rules/no-invented-constraints.md`:
 *   The helper does NOT auto-fill any field from the verdict (e.g. it does
 *   not derive `next_steps` prose from the ladder history). The 7 pattern-
 *   prose fields are caller-supplied verbatim. The optional `historyRender`
 *   callback is the ONLY hook for ladder-state injection, and it modifies
 *   ONLY `meta_observations`.
 *
 * Created in wave-019 / lane-b. Resolves wave-016 / lane-d F21 / m-1
 * (Opus single-model Minor): RetroOutcome lacks halted_by_degradation.
 */

import type { RunHaltedVerdict } from './halt.js';
import type { RetroSignal } from './retro.js';
import type { DegradationTransition } from './degradation.js';

/**
 * Caller-supplied 5-axis Likert + 7 pattern-prose fields shape. Mirrors the
 * F-014 RetroSignal Likert + pattern fields (excluding outcome +
 * trigger_evidence_sha256 which the helper supplies). Each Likert value
 * MUST be an integer 1..5; each pattern field MUST be a non-empty string.
 * Validation happens at the F-014 closeSession boundary; this helper does
 * NOT pre-validate (per the orchestrator-identity rule "compose; do not
 * re-implement" — F-014's validator is authoritative).
 */
export interface DegradationRetroFields {
  // 5-axis Likert (each 1-5)
  accuracy: number;
  completeness: number;
  tsg_alignment: number;
  dx: number;
  confidence: number;
  // 7 pattern fields
  what_worked: string;
  what_was_hard: string;
  surprises: string;
  blockers: string;
  next_steps: string;
  notes: string;
  meta_observations: string;
}

/**
 * Optional history-rendering options for {@link buildDegradationRetro}.
 *
 * When `historyRender` is supplied alongside `history`, the helper invokes
 * the callback with the supplied history array and stores the returned
 * string in the resulting RetroSignal's `meta_observations` field
 * (overriding the caller-supplied `meta_observations` from
 * DegradationRetroFields). When the callback is absent, the caller-supplied
 * `meta_observations` is preserved verbatim.
 *
 * v1 ships only this minimal hook; production rendering (e.g. multi-line
 * markdown table) belongs to a future M11 retro-introspection feature.
 */
export interface DegradationRetroOptions {
  history?: readonly DegradationTransition[];
  historyRender?: (history: readonly DegradationTransition[]) => string;
}

/**
 * Construct a validated `halted_by_degradation` RetroSignal from a F-021
 * degradation-halt verdict + caller-supplied Likert + pattern fields +
 * audit chain head.
 *
 * Acceptance scenarios from the F-140 ledger:
 *   1. degrade_escalate verdict + valid Likert + valid SHA -> RetroSignal
 *      with outcome='halted_by_degradation' + trigger_evidence_sha256;
 *      closeSession(retro) returns {ok:true}.
 *   3. Wrong-trigger verdict -> throws Error mentioning expected trigger.
 *   4. historyRender callback supplied -> meta_observations contains
 *      rendered history verbatim.
 *   5. No historyRender callback -> meta_observations is caller-supplied
 *      verbatim (no auto-injection).
 *
 * The returned RetroSignal is NOT yet validated through F-014's
 * closeSession — the caller passes it to closeSession to trigger the
 * mandatory close-transition. closeSession will throw RetroMissingError if
 * the audit chain head fails 64-hex validation (scenario 2 from the
 * F-140 ledger).
 */
export function buildDegradationRetro(
  verdict: RunHaltedVerdict,
  fields: DegradationRetroFields,
  auditChainHead: string,
  opts?: DegradationRetroOptions,
): RetroSignal {
  // Boundary check: helper rejects mis-routed halt verdicts so callers
  // can't accidentally produce a halted_by_degradation retro for a
  // consecutive_failures or kill-switch halt.
  if (verdict.trigger !== 'degrade_escalate') {
    throw new Error(
      `buildDegradationRetro: expected trigger=degrade_escalate, got trigger=${verdict.trigger}`,
    );
  }

  // History rendering: if both history AND callback are supplied, the
  // rendered string overrides meta_observations. Otherwise the caller-
  // supplied verbatim meta_observations is preserved (no auto-injection
  // per the no-invented-constraints rule).
  let meta_observations = fields.meta_observations;
  if (opts?.history !== undefined && opts.historyRender !== undefined) {
    meta_observations = opts.historyRender(opts.history);
  }

  return {
    accuracy: fields.accuracy,
    completeness: fields.completeness,
    tsg_alignment: fields.tsg_alignment,
    dx: fields.dx,
    confidence: fields.confidence,
    what_worked: fields.what_worked,
    what_was_hard: fields.what_was_hard,
    surprises: fields.surprises,
    blockers: fields.blockers,
    next_steps: fields.next_steps,
    notes: fields.notes,
    meta_observations,
    outcome: 'halted_by_degradation',
    trigger_evidence_sha256: auditChainHead,
  };
}
