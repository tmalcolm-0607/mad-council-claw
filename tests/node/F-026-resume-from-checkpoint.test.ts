import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  CheckpointManager,
  type Checkpoint,
} from '@mad-council-claw/engine-core';

/**
 * F-026 RED → GREEN test.
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-026-resume-from-checkpoint.md
 * acceptance scenarios + wave-017 / lane-c brief.
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
 *   save() writes atomically via `atomicWriteJson` (write-temp + rename) so
 *   readers never observe a half-written checkpoint per
 *   `concurrency-safety.md` §2.
 *   load() returns null when the file is missing (run never reached its first
 *   cycle boundary) — callers map this to the F-026 ledger scenario 2 path
 *   (`halted_by: lost_checkpoint`).
 *   exists() reflects file presence — useful for scheduler startup sweeps
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
 *   are preserved; the F-015 audit-chain integration (cycle_state_sha256
 *   verification, CHECKPOINT_INTEGRITY_FAIL halt) is deferred to the
 *   engine-cycle integration step that consumes this primitive (per
 *   F-018's `audit_chain_broken` trigger). Per FETCH BEFORE CITE +
 *   wave-016 lane-b precedent (HeartbeatScheduler is a primitive too).
 *
 * Acceptance scenarios:
 *   1. save() creates the checkpoint file at the configured path.
 *   2. load() round-trips the saved state.
 *   3. load() returns null when no checkpoint file exists.
 *   4. exists() reflects whether a saved file is present.
 *   5. schemaVersion is preserved verbatim through the save → load round-trip.
 *   6. savedAt is auto-injected at save time (caller does NOT supply it);
 *      the returned Checkpoint carries the timestamp.
 *
 * Out of scope (per `rules/no-silent-deferrals.md`):
 *   - F-015 audit-chain `cycle_state_sha256` verification + the
 *     CHECKPOINT_INTEGRITY_FAIL → F-018 `audit_chain_broken` halt path
 *     (engine-cycle integration step).
 *   - `last_completed_cycle` advancement semantics + scheduler resume
 *     dispatch (F-023 caller integration).
 *   - Resume-marker re-write on advance + the F-014 retro-on-lost-checkpoint
 *     emission (F-014 caller wiring).
 *   - Cross-machine resume (carry checkpoint to a different host) — v1
 *     out-of-scope per ledger §out-of-scope-notes.
 */
describe('F-026 resume-from-checkpoint', () => {
  let tempRoot: string;
  let cpPath: string;

  beforeEach(() => {
    // Each test gets its own isolated temp dir so concurrent test runs
    // do not contaminate each other's checkpoint state.
    tempRoot = mkdtempSync(join(tmpdir(), 'mad-council-claw-f026-'));
    cpPath = join(tempRoot, 'checkpoint.json');
  });

  afterEach(() => {
    if (existsSync(tempRoot)) {
      rmSync(tempRoot, { recursive: true, force: true });
    }
  });

  it('scenario 1: save() creates a checkpoint file at the configured path', () => {
    const mgr = new CheckpointManager(cpPath);
    expect(existsSync(cpPath)).toBe(false);

    mgr.save({
      runId: 'run-001',
      agentId: 'agent-A',
      pipelinePhase: 'plan',
      step: 3,
      data: { partial: 'progress' },
    });

    expect(existsSync(cpPath)).toBe(true);
    expect(existsSync(`${cpPath}.tmp`)).toBe(false);
  });

  it('scenario 2: load() returns the saved state intact', () => {
    const mgr = new CheckpointManager(cpPath);
    mgr.save({
      runId: 'run-002',
      agentId: 'agent-B',
      pipelinePhase: 'implement',
      step: 7,
      data: { fileCount: 12, lastFile: 'src/foo.ts' },
    });

    const loaded = mgr.load();
    expect(loaded).not.toBeNull();
    expect(loaded?.runId).toBe('run-002');
    expect(loaded?.agentId).toBe('agent-B');
    expect(loaded?.pipelinePhase).toBe('implement');
    expect(loaded?.step).toBe(7);
    expect(loaded?.data).toEqual({ fileCount: 12, lastFile: 'src/foo.ts' });
  });

  it('scenario 3: load() returns null when no checkpoint file exists', () => {
    const mgr = new CheckpointManager(cpPath);
    expect(mgr.load()).toBeNull();
  });

  it('scenario 4: exists() reflects file presence', () => {
    const mgr = new CheckpointManager(cpPath);
    expect(mgr.exists()).toBe(false);

    mgr.save({
      runId: 'run-003',
      agentId: 'agent-C',
      pipelinePhase: 'spec',
      step: 1,
      data: {},
    });

    expect(mgr.exists()).toBe(true);
  });

  it('scenario 5: schemaVersion is preserved through save → load round-trip', () => {
    const mgr = new CheckpointManager(cpPath);
    const saved: Checkpoint = mgr.save({
      runId: 'run-004',
      agentId: 'agent-D',
      pipelinePhase: 'analyze',
      step: 2,
      data: { phase: 'analyze' },
    });

    expect(saved.schemaVersion).toBe(1);
    const loaded = mgr.load();
    expect(loaded?.schemaVersion).toBe(1);
  });

  it('scenario 6: savedAt is auto-injected at save time (ISO-8601)', () => {
    const before = new Date().toISOString();
    const mgr = new CheckpointManager(cpPath);
    const saved = mgr.save({
      runId: 'run-005',
      agentId: 'agent-E',
      pipelinePhase: 'validate',
      step: 9,
      data: { ok: true },
    });
    const after = new Date().toISOString();

    expect(saved.savedAt).toBeDefined();
    // ISO-8601 lexicographic ordering: before <= savedAt <= after
    expect(saved.savedAt >= before).toBe(true);
    expect(saved.savedAt <= after).toBe(true);

    const loaded = mgr.load();
    expect(loaded?.savedAt).toBe(saved.savedAt);
  });
});
