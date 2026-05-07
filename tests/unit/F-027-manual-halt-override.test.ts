import { describe, it, expect } from 'vitest';
import {
  manualHaltOverride,
  type RunHaltedVerdict,
} from '@mad-council-claw/engine-core';

/**
 * F-027 RED → GREEN test.
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-027-manual-halt-override.md
 * acceptance scenarios + wave-017 / lane-c brief.
 *
 * Behavior contract (lane-c brief shape):
 *   `manualHaltOverride({runId, reason, consentGate})` is the operator-side
 *   counterpart to F-020's KillSwitch. Where F-020 propagates a halt signal
 *   read at cycle boundaries (file/env-var watcher), F-027 is the explicit
 *   one-shot entry point an operator invokes from a CLI / UI / cron-pause
 *   command. The injected `consentGate` honors `dangerous-operations-policy.md`
 *   §Cross-org / Bulk-halt category — bulk operations can supply a
 *   user-confirmation function that returns false to abort.
 *
 *   Returns a `RunHaltedVerdict` with:
 *     - type: 'RUN_HALTED'
 *     - trigger: 'manual'  (the F-018 sibling reserved for operator halts)
 *     - reason: caller-supplied verbatim (preserves audit trail intent)
 *     - run_id: stamped onto the verdict for F-002 correlation
 *     - timestamp: ISO-8601 UTC at fire time
 *
 *   The consent gate semantics:
 *     - consentGate() returns true (or Promise<true>) → halt proceeds,
 *       verdict returned.
 *     - consentGate() returns false (or Promise<false>) → manualHaltOverride
 *       throws an Error with message containing "consent" + "denied" so the
 *       caller can distinguish abort-by-user from a real failure.
 *     - Async consent gates are awaited (operators may need an async UI
 *       confirmation step).
 *
 * Scope deviation from ledger (intentional, documented):
 *   The F-027 ledger §Behavior contract specifies TWO distinct operations:
 *     (1) "Pause schedule" — write `paused: true` to
 *         `automations/cron-schedules.json`, scheduler skips on next tick.
 *     (2) "Halt active run" — write to `kill-switch.json` (per F-020) which
 *         propagates within ≤1 cycle to halt in-flight runs.
 *   The wave-017 lane-c brief simplifies to operation (2) only, exposed as
 *   a pure function `manualHaltOverride()` that returns the verdict shape
 *   shared with F-018/F-020. The pause-schedule path lives with F-023's
 *   HeartbeatScheduler caller integration (out of scope for this primitive
 *   per `no-silent-deferrals.md`); the bulk-pause consent gate (>5 schedules)
 *   is also caller-side. Per FETCH BEFORE CITE + wave-016 lane-b precedent
 *   (HeartbeatScheduler is a primitive too).
 *
 * Acceptance scenarios:
 *   1. consentGate=()=>true → manualHaltOverride returns RunHaltedVerdict
 *      with type='RUN_HALTED', trigger='manual'.
 *   2. consentGate=()=>false → manualHaltOverride throws an Error whose
 *      message contains "consent" + "denied" (caller distinguishes abort).
 *   3. The supplied runId is stamped onto verdict.run_id verbatim.
 *   4. The supplied reason is carried through to verdict.reason verbatim
 *      (preserved for audit trail per dangerous-operations-policy.md).
 *
 * Out of scope (per `rules/no-silent-deferrals.md`):
 *   - Pause-schedule operation (write to automations/cron-schedules.json)
 *     — caller-side integration with F-023 HeartbeatScheduler.
 *   - Bulk-halt consent gate (>5 schedules) — caller-side per
 *     dangerous-operations-policy.md.
 *   - kill-switch.json file write integration (F-020 caller wiring).
 *   - F-014 retro-on-manual-halt emission (F-014 caller wiring).
 *   - Multi-operator quorum on halts (v1 ledger out-of-scope).
 *   - Per-schedule role-based authorization (v1.5 ledger out-of-scope).
 */
describe('F-027 manual-halt-override', () => {
  it('scenario 1: consentGate returns true → RUN_HALTED verdict with trigger=manual', async () => {
    const verdict: RunHaltedVerdict = await manualHaltOverride({
      runId: 'run-001',
      reason: 'operator stopped: schedule retired',
      consentGate: () => true,
    });

    expect(verdict.type).toBe('RUN_HALTED');
    expect(verdict.trigger).toBe('manual');
  });

  it('scenario 2: consentGate returns false → throws abort error mentioning consent denied', async () => {
    await expect(
      manualHaltOverride({
        runId: 'run-002',
        reason: 'operator pressed halt',
        consentGate: () => false,
      }),
    ).rejects.toThrow(/consent|denied/i);
  });

  it('scenario 3: runId is stamped onto verdict.run_id verbatim', async () => {
    const verdict = await manualHaltOverride({
      runId: 'run-abc-123',
      reason: 'operator halt',
      consentGate: () => true,
    });

    expect(verdict.run_id).toBe('run-abc-123');
  });

  it('scenario 4: reason is carried through to verdict.reason verbatim', async () => {
    const operatorReason =
      'Halted manually by tonym at 2026-05-07T00:00Z; SB NSP rule retired, no further heartbeat needed';
    const verdict = await manualHaltOverride({
      runId: 'run-004',
      reason: operatorReason,
      consentGate: () => true,
    });

    expect(verdict.reason).toBe(operatorReason);
  });

  it('scenario 5: async consentGate is awaited (Promise<true> resolves to halt)', async () => {
    // Operators may inject an async consent UI; await must be honored.
    const verdict = await manualHaltOverride({
      runId: 'run-005',
      reason: 'async-confirmed halt',
      consentGate: () => Promise.resolve(true),
    });

    expect(verdict.type).toBe('RUN_HALTED');
    expect(verdict.trigger).toBe('manual');
  });

  it('scenario 6: timestamp is an ISO-8601 string captured at halt time', async () => {
    const before = new Date().toISOString();
    const verdict = await manualHaltOverride({
      runId: 'run-006',
      reason: 'halt with timestamp check',
      consentGate: () => true,
    });
    const after = new Date().toISOString();

    expect(verdict.timestamp).toBeDefined();
    // Lexicographic ordering on ISO-8601 strings: before <= timestamp <= after
    expect(verdict.timestamp >= before).toBe(true);
    expect(verdict.timestamp <= after).toBe(true);
  });
});
