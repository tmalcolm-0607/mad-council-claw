/**
 * F-001 Engine Bootstrap Loop — GREEN implementation.
 * Per docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md.
 *
 * Behavior contract: a single CoClaw run with deterministic lifecycle
 * (open → active → closing → closed), cycle-bounded (≤50), with hash-chained
 * audit on every cycle. Termination always passes through `closing` so the
 * pre-close retro signal (F-014) fires before reaching `closed`.
 *
 * This is the minimal implementation that satisfies F-001's three acceptance
 * scenarios. F-014 retro-signal wiring, F-015 hash-chain crypto, F-019 cost
 * ledger, and F-021 exception-injection seam are tracked separately and will
 * extend this loop without breaking the contract.
 */

import { createHash } from 'node:crypto';

export type LifecycleState = 'open' | 'active' | 'closing' | 'closed';

export type TerminatedBy = 'completion' | 'cycle_cap' | 'exception';

/** Hard cap per F-001 ledger ("≤50 cycles per run"). */
export const MAX_CYCLES_HARD_CAP = 50;

export interface RunConfig {
  /** Maximum cycles before forced transition to closing. Effective cap is min(maxCycles, 50). */
  maxCycles: number;
}

export interface AuditEntry {
  /** Monotonic cycle index, starting at 1. */
  cycle: number;
  /** Hash chained from prior entry; first entry chains from genesis. */
  hash: string;
  /** Lifecycle state captured at audit-write time. */
  state: LifecycleState;
}

export interface RunResult {
  /** Ordered lifecycle transitions emitted across the run. */
  lifecycle: LifecycleState[];
  /** One entry per cycle that ran. */
  audit: AuditEntry[];
  /** Why the run terminated. */
  terminatedBy: TerminatedBy;
}

/** Genesis hash — first audit entry chains from this constant. */
const GENESIS_HASH = '0'.repeat(64);

/**
 * Compute the hash for an audit entry by chaining from the prior hash.
 * SHA-256 of `${priorHash}|${cycle}|${state}` — F-015 will extend this with
 * cycle payload + signature; for F-001 the chain shape is what matters.
 */
function chainHash(priorHash: string, cycle: number, state: LifecycleState): string {
  return createHash('sha256').update(`${priorHash}|${cycle}|${state}`).digest('hex');
}

/**
 * Boot a single run and execute it to termination.
 *
 * Acceptance scenarios from the F-001 ledger:
 *   1. maxCycles=3 → lifecycle [open, active, closing, closed], 3 audit entries
 *   2. maxCycles=50 → 50 audit entries, terminatedBy='cycle_cap'
 *   3. exception path still transitions through closing (F-021 seam will inject;
 *      for F-001 the type surface is what's promised)
 */
export async function bootstrap(config: RunConfig): Promise<RunResult> {
  if (!Number.isInteger(config.maxCycles) || config.maxCycles < 1) {
    throw new Error(
      `F-001: maxCycles must be a positive integer; got ${String(config.maxCycles)}`,
    );
  }

  const lifecycle: LifecycleState[] = ['open'];
  const audit: AuditEntry[] = [];

  // Transition open → active. The active state runs the cycle loop.
  lifecycle.push('active');

  // Effective cap: never exceed the hard cap (F-001 ledger: "≤50 cycles per run").
  // If caller asks for ≥50, we run exactly 50 then terminate by cycle_cap.
  // If caller asks for <50, we run that many then terminate by completion.
  const requested = config.maxCycles;
  const cyclesToRun = Math.min(requested, MAX_CYCLES_HARD_CAP);
  const willHitCap = requested >= MAX_CYCLES_HARD_CAP;

  let priorHash = GENESIS_HASH;
  for (let cycle = 1; cycle <= cyclesToRun; cycle++) {
    const hash = chainHash(priorHash, cycle, 'active');
    audit.push({ cycle, hash, state: 'active' });
    priorHash = hash;
  }

  // Termination always flows through `closing` so F-014's pre-close retro
  // signal can fire. This ordering is load-bearing — scenarios 1, 2, and 3
  // all assert it.
  lifecycle.push('closing');
  lifecycle.push('closed');

  const terminatedBy: TerminatedBy = willHitCap ? 'cycle_cap' : 'completion';

  return { lifecycle, audit, terminatedBy };
}
