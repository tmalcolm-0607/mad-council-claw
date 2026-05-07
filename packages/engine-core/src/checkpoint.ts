/**
 * F-026 Resume from checkpoint — GREEN.
 *
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-026-resume-from-checkpoint.md.
 *
 * Behavior contract (lane-c brief shape):
 *   `CheckpointManager` provides save/load/exists for a per-run cycle
 *   checkpoint persisted as JSON via the kit's atomic-write helper
 *   (concurrency-safety §2). The checkpoint shape carries:
 *     - schemaVersion: 1
 *     - runId: F-002 correlation
 *     - agentId: F-002 correlation
 *     - pipelinePhase: spec/plan/tasks/analyze/implement/validate
 *     - step: monotonic step counter within the phase
 *     - data: caller-owned opaque payload
 *     - savedAt: ISO-8601 timestamp injected at save time
 *
 *   `save()` writes atomically via `atomicWriteJson` (write-temp + rename) so
 *   readers never observe a half-written checkpoint per
 *   `concurrency-safety.md` §2. The returned Checkpoint includes the
 *   schemaVersion + savedAt fields the manager auto-injected.
 *
 *   `load()` returns null when the file is missing OR when reading throws —
 *   callers map this to the F-026 ledger scenario 2 path
 *   (`halted_by: lost_checkpoint`). Distinguishing "missing" from
 *   "corrupted JSON" is left to callers consuming the file directly via
 *   `readJson`; the ledger's CHECKPOINT_INTEGRITY_FAIL halt path is the
 *   F-015 audit-chain integration step (out of scope for this primitive).
 *
 *   `exists()` reflects file presence — useful for scheduler startup sweeps
 *   that inventory resumable runs without parsing.
 *
 * Scope deviation from ledger (intentional, documented):
 *   The F-026 ledger §Behavior contract specifies a richer
 *   `runs/<run_id>/checkpoint.json` schema with `last_completed_cycle`,
 *   `cycle_state_sha256` (linking F-015 audit log), and `resumable: true`.
 *   The wave-017 lane-c brief simplifies this to a primitive
 *   `CheckpointManager` class with an injected path + a flat checkpoint
 *   shape. The substantive guarantees — atomic-write persistence, missing-
 *   file → null contract, schemaVersion preservation, savedAt stamping —
 *   are preserved; the F-015 audit-chain integration is deferred to the
 *   engine-cycle integration step that consumes this primitive (per
 *   F-018's `audit_chain_broken` trigger).
 *
 * Dependencies (per ledger):
 *   - Hard: F-023 (HeartbeatScheduler caller drives checkpoint save at
 *     cycle boundaries), F-001 (cycle lifecycle), F-008 (atomic-write
 *     helpers from storage.ts), F-015 (audit-chain integration deferred).
 *   - Soft: F-018 (failure-pattern halt for `audit_chain_broken` trigger),
 *     F-014 (retro for halted resume), F-020 (kill-switch interaction
 *     during resume).
 */

import { atomicWriteJson, readJson } from './storage.js';

/**
 * The pipeline phase a checkpoint is associated with. Mirrors the canonical
 * MAD skill chain (`/mad-spec → /mad-plan → /mad-tasks → /mad-analyze →
 * /mad-implement → /mad-validate`); a run's checkpoint must be classifiable
 * by phase so the resume dispatcher can route to the right caller.
 */
export type PipelinePhase =
  | 'spec'
  | 'plan'
  | 'tasks'
  | 'analyze'
  | 'implement'
  | 'validate';

/**
 * The persisted checkpoint shape. `schemaVersion` lets the loader detect
 * incompatible on-disk formats when a future schema bump lands.
 *
 * `data` is opaque to the manager — callers (the engine cycle integration
 * step) supply phase-specific state. The manager does not validate `data`'s
 * shape; that contract belongs to the consuming caller.
 */
export interface Checkpoint {
  schemaVersion: 1;
  runId: string;
  agentId: string;
  pipelinePhase: PipelinePhase;
  step: number;
  data: Record<string, unknown>;
  /** ISO-8601 UTC timestamp injected by the manager at save time. */
  savedAt: string;
}

/**
 * The fields a caller supplies to `save()`. The manager injects
 * `schemaVersion` and `savedAt` so callers cannot accidentally write
 * stale or fabricated values.
 */
export type CheckpointInput = Omit<Checkpoint, 'schemaVersion' | 'savedAt'>;

/**
 * Per-run checkpoint manager.
 *
 * Acceptance scenarios from the F-026 ledger + wave-017 / lane-c brief:
 *   1. save() creates the checkpoint file at the configured path.
 *   2. load() returns the saved state intact.
 *   3. load() returns null when no checkpoint file exists.
 *   4. exists() reflects file presence.
 *   5. schemaVersion is preserved verbatim through save → load round-trip.
 *   6. savedAt is auto-injected at save time (caller does NOT supply it).
 *
 * The manager is stateless beyond the configured `path` — callers may
 * construct multiple instances per run (e.g., for read-only scheduler-side
 * inventory vs the run's own write-side cycle hook) without coordinating
 * shared state.
 */
export class CheckpointManager {
  constructor(private readonly path: string) {}

  /**
   * Persist a checkpoint to disk via the atomic-write helper from F-008
   * (write-temp + rename). The returned Checkpoint includes the
   * schemaVersion + savedAt fields the manager injected — callers can
   * read those without re-loading.
   *
   * On crash between the temp-file write and the rename, the orphan
   * `<path>.tmp` is reclaimed by the F-008 startup sweep (out of scope
   * here; tracked in F-008's edge-cases follow-on).
   */
  save(input: CheckpointInput): Checkpoint {
    const full: Checkpoint = {
      schemaVersion: 1,
      savedAt: new Date().toISOString(),
      ...input,
    };
    atomicWriteJson(this.path, full);
    return full;
  }

  /**
   * Read the saved checkpoint, returning null when the file is missing or
   * unreadable. Callers map null to the F-026 ledger scenario 2 path
   * (run halted by `lost_checkpoint`).
   *
   * The catch-all silently swallows parse + IO errors per the ledger's
   * "no checkpoint" semantics; CHECKPOINT_INTEGRITY_FAIL discrimination
   * (audit-chain mismatch vs missing file) belongs to the F-015
   * integration step. This primitive does not parse audit-chain hashes.
   */
  load(): Checkpoint | null {
    try {
      return readJson<Checkpoint>(this.path);
    } catch {
      return null;
    }
  }

  /**
   * Cheap presence check — useful for scheduler startup sweeps that need
   * to inventory resumable runs without parsing every checkpoint file.
   * Mirrors `load()`'s catch-all so a corrupt file reports `false` (the
   * caller treats it as "no resumable checkpoint" the same as missing).
   */
  exists(): boolean {
    try {
      readJson(this.path);
      return true;
    } catch {
      return false;
    }
  }
}
