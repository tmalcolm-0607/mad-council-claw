/**
 * F-014 Pre-close retro signal — GREEN.
 * Per docs/03-feature-catalog/M2-governance-triad/F-014-pre-close-retro-signal.md.
 *
 * Adds RetroSignal (5-axis Likert 1-5 + 7 pattern fields + outcome + optional
 * trigger_evidence_sha256), RetroMissingError (carries .missingFields list),
 * and closeSession() — the boundary contract that fails the close transition
 * with RETRO_MISSING when the retro is absent / partial / out-of-range. The
 * filesystem write to runs/<run_id>/retro.json is F-008's job (storage layout)
 * per the F-014 ledger out-of-scope-notes; this flip lands the in-memory
 * boundary that F-008 will plug into.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

/**
 * Run outcomes recognized by the retro contract. `completed` covers
 * natural termination (completion + cycle_cap from F-001's TerminatedBy);
 * `halted_by_*` outcomes are the F-018/F-020 carve-outs and require a
 * `trigger_evidence_sha256` field linking to the audit entry that triggered
 * the halt (per F-014 ledger acceptance scenario 2).
 */
export type RetroOutcome =
  | 'completed'
  | 'halted_by_kill_switch'
  | 'halted_by_failure_pattern'
  | 'halted_by_tool_quota';

/**
 * The retro signal emitted during `closing` before the run reaches `closed`.
 *
 * Fields per F-014 ledger §Behavior contract:
 *   - 5-axis Likert 1-5 (accuracy / completeness / tsg_alignment / dx /
 *     confidence) — the kit:council-retro-skill rubric.
 *   - 7 pattern prose fields (what_worked / what_was_hard / surprises /
 *     blockers / next_steps / notes / meta_observations).
 *   - outcome: terminal classification.
 *   - trigger_evidence_sha256: required when outcome starts with `halted_by_`;
 *     SHA-256 hex (64 chars) linking to the audit entry that triggered the halt.
 */
export interface RetroSignal {
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
  // Terminal classification
  outcome: RetroOutcome;
  // Required iff outcome starts with `halted_by_`
  trigger_evidence_sha256?: string;
}

/**
 * RETRO_MISSING — thrown when {@link closeSession} is called with an absent,
 * partial, or out-of-range retro. The `missingFields` array enumerates the
 * specific fields that failed validation so callers can surface remediation.
 */
export class RetroMissingError extends Error {
  public readonly missingFields: string[];
  constructor(missingFields: string[]) {
    super(
      `RETRO_MISSING: pre-close retro signal is incomplete; missing or invalid fields: ${
        missingFields.join(', ') || '<entire retro object>'
      }`,
    );
    this.name = 'RetroMissingError';
    this.missingFields = missingFields;
    // Preserve prototype chain through transpilation (TS class extending Error).
    Object.setPrototypeOf(this, RetroMissingError.prototype);
  }
}

/** The 5 Likert axes — each MUST be an integer 1..5 inclusive. */
const LIKERT_AXES = [
  'accuracy',
  'completeness',
  'tsg_alignment',
  'dx',
  'confidence',
] as const satisfies readonly (keyof RetroSignal)[];

/** The 7 pattern prose fields — each MUST be a non-empty string. */
const PATTERN_FIELDS = [
  'what_worked',
  'what_was_hard',
  'surprises',
  'blockers',
  'next_steps',
  'notes',
  'meta_observations',
] as const satisfies readonly (keyof RetroSignal)[];

/** Recognized outcomes that require trigger_evidence_sha256. */
const HALTED_OUTCOMES: ReadonlySet<RetroOutcome> = new Set([
  'halted_by_kill_switch',
  'halted_by_failure_pattern',
  'halted_by_tool_quota',
]);

/**
 * Close a session with a mandatory retro signal.
 *
 * Acceptance scenarios from the F-014 ledger:
 *   1. Valid retro w/ outcome=completed → returns {ok: true}.
 *   2. Halted run carries trigger_evidence_sha256 matching the halt audit
 *      entry → returns {ok: true}; absence → RETRO_MISSING.
 *   3. Buggy impl that omits the retro → RETRO_MISSING; the run does NOT
 *      reach `closed` (the throw IS the failed close transition).
 *
 * Validation contract (in order):
 *   - retro must be a non-null object.
 *   - All 5 Likert axes present, integer, 1..5 inclusive.
 *   - All 7 pattern prose fields present, non-empty string.
 *   - `outcome` present and one of RetroOutcome.
 *   - If outcome starts with `halted_by_`, trigger_evidence_sha256 present
 *     and 64-char lowercase hex.
 */
export function closeSession(
  retro: Partial<RetroSignal> | null | undefined,
): { ok: true } {
  if (retro === null || retro === undefined) {
    throw new RetroMissingError([]);
  }

  const missing: string[] = [];

  // 5-axis Likert validation: present + integer + 1..5.
  for (const axis of LIKERT_AXES) {
    const v = retro[axis];
    if (v === undefined) {
      missing.push(axis);
      continue;
    }
    if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > 5) {
      missing.push(axis);
    }
  }

  // 7 pattern fields: present + non-empty string.
  for (const field of PATTERN_FIELDS) {
    const v = retro[field];
    if (v === undefined) {
      missing.push(field);
      continue;
    }
    if (typeof v !== 'string' || v.length === 0) {
      missing.push(field);
    }
  }

  // outcome: present + recognized.
  const outcome = retro.outcome;
  const validOutcomes: ReadonlySet<RetroOutcome> = new Set<RetroOutcome>([
    'completed',
    'halted_by_kill_switch',
    'halted_by_failure_pattern',
    'halted_by_tool_quota',
  ]);
  if (outcome === undefined) {
    missing.push('outcome');
  } else if (!validOutcomes.has(outcome)) {
    missing.push('outcome');
  }

  // halted-by carve-out: trigger_evidence_sha256 required iff halted_by_*.
  if (outcome !== undefined && HALTED_OUTCOMES.has(outcome)) {
    const sha = retro.trigger_evidence_sha256;
    if (sha === undefined) {
      missing.push('trigger_evidence_sha256');
    } else if (typeof sha !== 'string' || !/^[0-9a-f]{64}$/.test(sha)) {
      missing.push('trigger_evidence_sha256');
    }
  }

  if (missing.length > 0) {
    throw new RetroMissingError(missing);
  }

  return { ok: true };
}
