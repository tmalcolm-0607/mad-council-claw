import { describe, it, expect } from 'vitest';
import {
  runEngineCycle,
  StubBackend,
  RetroMissingError,
  type RetroSignal,
} from '@mad-council-claw/engine-core';

/**
 * F-138 RED → GREEN test.
 * Per docs/03-feature-catalog/M0-bootstrap/F-138-engine-cycle-orchestrator.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal.
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. Configured orchestrator + StubBackend → RunOutcome status='completed'
 *      with UUID-v7 runId, UUID-v7 agentId, 64-hex auditChainHead.
 *   2. forceHaltTrigger='manual' → RunOutcome status='halted' with
 *      haltTrigger='manual' and haltReason carrying caller's reason.
 *   3. retro factory returns null → closeSession throws RetroMissingError
 *      (the F-014 RETRO_MISSING boundary contract fires).
 *
 * Resolves wave-016 / lane-d Copilot CLI HARD-BLOCK F1 (no engine-cycle
 * orchestrator wires the 18 LOCKED M0/M1/M2 primitives). F-138 IS the
 * M3-prerequisite composition layer.
 */

const validRetro: RetroSignal = {
  accuracy: 4,
  completeness: 4,
  tsg_alignment: 4,
  dx: 4,
  confidence: 4,
  what_worked: 'orchestrator composed primitives without re-implementing their logic',
  what_was_hard: 'staging-race avoidance across concurrent lanes in wave-17',
  surprises: 'none — the primitives composed cleanly per their LOCKED contracts',
  blockers: 'none',
  next_steps: 'wire F-017 redaction + F-021 ladder + F-020 polling in M3',
  notes: 'F-138 v1 is the spine; F-138 v2 is the multi-iteration loop',
  meta_observations:
    'orchestrator-identity rule (compose; do not re-implement) held throughout',
  outcome: 'completed',
};

describe('F-138 engine-cycle-orchestrator', () => {
  it('scenario 1: completed run returns RunOutcome with status=completed', async () => {
    const outcome = await runEngineCycle({
      backend: new StubBackend(),
      prompt: 'hello',
      retro: () => validRetro,
    });

    expect(outcome.status).toBe('completed');
    // UUID v7 canonical 8-4-4-4-12 hex form (per F-002 identity contract)
    expect(outcome.runId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(outcome.agentId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    // F-015 entry_sha256 — 64-char lowercase hex
    expect(outcome.auditChainHead).toMatch(/^[0-9a-f]{64}$/);
    // StubBackend yields token + finish; orchestrator captured both
    expect(outcome.events.length).toBeGreaterThanOrEqual(2);
    expect(outcome.events.some((e) => e.type === 'finish')).toBe(true);
    // CostLedger instantiated; v1 has no usage variant so total is 0 (F-019 contract)
    expect(outcome.costTotalUsd).toBe(0);
  });

  it('scenario 2: forceHaltTrigger=manual returns halted RunOutcome', async () => {
    const haltedRetro: RetroSignal = {
      ...validRetro,
      outcome: 'halted_by_kill_switch',
      // F-014 requires trigger_evidence_sha256 when outcome starts halted_by_*
      trigger_evidence_sha256:
        '0000000000000000000000000000000000000000000000000000000000000000',
    };
    const outcome = await runEngineCycle({
      backend: new StubBackend(),
      prompt: 'hello',
      retro: () => haltedRetro,
      forceHaltTrigger: 'manual',
    });

    expect(outcome.status).toBe('halted');
    expect(outcome.haltTrigger).toBe('manual');
    expect(outcome.haltReason).toMatch(/manual/i);
    // Even halted runs still allocate correlation triple + audit chain head
    expect(outcome.runId).toMatch(/^[0-9a-f-]{36}$/);
    expect(outcome.agentId).toMatch(/^[0-9a-f-]{36}$/);
    expect(outcome.auditChainHead).toMatch(/^[0-9a-f]{64}$/);
  });

  it('scenario 3: missing retro throws RetroMissingError', async () => {
    await expect(
      runEngineCycle({
        backend: new StubBackend(),
        prompt: 'hello',
        // F-014 closeSession boundary throws on null retro
        retro: () => null as unknown as RetroSignal,
      }),
    ).rejects.toBeInstanceOf(RetroMissingError);
  });
});
