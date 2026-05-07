/**
 * F-001 Engine Bootstrap Loop — RED state stub.
 * Per docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md.
 * Implementation lands in M0 implementation wave.
 *
 * The behavior contract: a single CoClaw run with deterministic lifecycle
 * (open → active → closing → closed), cycle-bounded (≤50), with hash-chained
 * audit on every cycle and pre-close retro signal on every termination path.
 */

export type LifecycleState = 'open' | 'active' | 'closing' | 'closed';

export type TerminatedBy = 'completion' | 'cycle_cap' | 'exception';

export interface RunConfig {
  /** Maximum cycles before forced transition to closing. ≤50 per F-001 contract. */
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

/**
 * Boot a single run and execute it to termination.
 * RED: throws not-yet-implemented; M0 wave will implement.
 */
export async function bootstrap(_config: RunConfig): Promise<RunResult> {
  throw new Error(
    'F-001 not yet implemented — RED by design (see docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md)',
  );
}
