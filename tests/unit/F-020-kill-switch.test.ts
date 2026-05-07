import { describe, it, expect } from 'vitest';
import {
  KillSwitch,
  type RunHaltedVerdict,
  type HaltTrigger,
} from '@mad-council-claw/engine-core';

/**
 * F-020 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-020-kill-switch.md
 * acceptance scenarios + wave-010 / lane-b brief. Authored RED-first per
 * the wave-5 retro proposal (capture RED before flipping GREEN).
 *
 * Behavior contract (lane-b brief shape):
 *   A read-time-propagating kill switch checked at the START of every model +
 *   tool call. Kill state surfaces from EITHER:
 *     - environment variable `MAD_KILL=1` (or `MAD_KILL=true`), OR
 *     - existence of a designated file (e.g. `<session-dir>/kill`).
 *   When triggered:
 *     - `isTriggered()` returns true (idempotent; multiple checks safe).
 *     - `checkOrThrow()` throws an Error decorated with a `RunHaltedVerdict`
 *       whose `trigger` is `manual` (the F-018 sibling trigger reserved for
 *       operator/kill-switch invocations) per the F-018 verdict-shape contract.
 *
 * Scope deviation from ledger (intentional, documented):
 *   The F-020 ledger §Behavior contract specifies a richer JSON file at
 *   `userData/mad-council-claw/kill-switch.json` with `{halted, reason, set_at_utc, set_by}`
 *   schema and read-time propagation via the engine cycle hook. The wave-010
 *   lane-b brief simplifies this to a `KillSwitch` class taking an optional
 *   file path + env-var name + injected fileExistsFn + injected env. The
 *   substantive guarantees — read-time propagation, RUN_HALTED verdict on
 *   trigger, defaults to halted=false when neither signal is present — are
 *   preserved; the JSON parsing + reason/set_at_utc fields are deferred to
 *   the engine-cycle integration step that consumes this primitive.
 *   Per FETCH BEFORE CITE + wave-008/wave-009 precedent (honor the brief
 *   when it explicitly narrows scope; surface the gap explicitly per
 *   `rules/no-silent-deferrals.md`).
 *
 * Acceptance scenarios:
 *   1. Env var `MAD_KILL=1` → isTriggered() returns true.
 *   2. Env var `MAD_KILL=true` → isTriggered() returns true.
 *   3. Env var unset, kill-file exists → isTriggered() returns true.
 *   4. Env var unset, no kill-file path configured → isTriggered() returns false.
 *   5. Env var unset, kill-file path configured but fileExistsFn returns false
 *      → isTriggered() returns false.
 *   6. checkOrThrow() throws when triggered; the thrown Error carries a
 *      RunHaltedVerdict with type='RUN_HALTED', trigger='manual', a non-empty
 *      reason, and an ISO-8601 timestamp.
 *   7. checkOrThrow() does nothing (no throw, no return value) when not
 *      triggered.
 *   8. Idempotency: multiple isTriggered() calls return the same answer
 *      without side effects (no internal state mutation).
 *   9. Custom env-var name: constructor accepts an alternate envVarName, and
 *      the default `MAD_KILL` is NOT consulted when overridden.
 *
 * Out of scope (per `rules/no-silent-deferrals.md`):
 *   - JSON parsing of `userData/mad-council-claw/kill-switch.json` (ledger
 *     full surface) — engine-cycle integration step.
 *   - F-008 storage layout for the kill-switch file path resolution.
 *   - F-014 retro-signal `outcome: halted_by_kill_switch` consumer wiring —
 *     the engine cycle that catches the throw and routes to closing.
 *   - F-015 audit-log entry for the kill-switch read result.
 *   - Read-at-cycle-start hook integration with F-001's bootstrap loop.
 *
 * The KillSwitch primitive is the in-memory boundary that the engine-cycle
 * integration will plug into; this flip lands the primitive shape only.
 */
describe('F-020 kill-switch', () => {
  it('scenario 1: env var MAD_KILL=1 triggers isTriggered()', () => {
    const ks = new KillSwitch(
      null,
      'MAD_KILL',
      () => false,
      { MAD_KILL: '1' },
    );
    expect(ks.isTriggered()).toBe(true);
  });

  it('scenario 2: env var MAD_KILL=true triggers isTriggered()', () => {
    const ks = new KillSwitch(
      null,
      'MAD_KILL',
      () => false,
      { MAD_KILL: 'true' },
    );
    expect(ks.isTriggered()).toBe(true);
  });

  it('scenario 3: env unset, kill-file exists triggers isTriggered()', () => {
    const ks = new KillSwitch(
      '/tmp/mad-kill',
      'MAD_KILL',
      (p) => p === '/tmp/mad-kill',
      {},
    );
    expect(ks.isTriggered()).toBe(true);
  });

  it('scenario 4: env unset and no kill-file path → isTriggered() false', () => {
    const ks = new KillSwitch(
      null,
      'MAD_KILL',
      () => true, // even if file would exist, no path means no check
      {},
    );
    expect(ks.isTriggered()).toBe(false);
  });

  it('scenario 5: env unset, kill-file path set but fileExistsFn returns false → isTriggered() false', () => {
    const ks = new KillSwitch(
      '/tmp/mad-kill',
      'MAD_KILL',
      () => false,
      {},
    );
    expect(ks.isTriggered()).toBe(false);
  });

  it('scenario 6: checkOrThrow() throws with attached RunHaltedVerdict (trigger=manual) when triggered', () => {
    const ks = new KillSwitch(
      null,
      'MAD_KILL',
      () => false,
      { MAD_KILL: '1' },
    );
    let thrown: unknown = null;
    try {
      ks.checkOrThrow();
    } catch (err) {
      thrown = err;
    }
    expect(thrown).not.toBeNull();
    expect(thrown).toBeInstanceOf(Error);
    const errWithVerdict = thrown as Error & { verdict?: RunHaltedVerdict };
    expect(errWithVerdict.verdict).toBeDefined();
    if (errWithVerdict.verdict !== undefined) {
      expect(errWithVerdict.verdict.type).toBe('RUN_HALTED');
      expect(errWithVerdict.verdict.trigger).toBe<HaltTrigger>('manual');
      expect(typeof errWithVerdict.verdict.reason).toBe('string');
      expect(errWithVerdict.verdict.reason.length).toBeGreaterThan(0);
      expect(typeof errWithVerdict.verdict.timestamp).toBe('string');
      expect(new Date(errWithVerdict.verdict.timestamp).toString()).not.toBe(
        'Invalid Date',
      );
    }
  });

  it('scenario 7: checkOrThrow() is a no-op when not triggered', () => {
    const ks = new KillSwitch(
      null,
      'MAD_KILL',
      () => false,
      {},
    );
    expect(() => ks.checkOrThrow()).not.toThrow();
    // Returns undefined per TS signature; explicitly assert.
    expect(ks.checkOrThrow()).toBeUndefined();
  });

  it('scenario 8: multiple isTriggered() calls are idempotent (no internal state mutation)', () => {
    let fileChecks = 0;
    const ks = new KillSwitch(
      '/tmp/mad-kill',
      'MAD_KILL',
      (_p) => {
        fileChecks++;
        return false;
      },
      {},
    );
    expect(ks.isTriggered()).toBe(false);
    expect(ks.isTriggered()).toBe(false);
    expect(ks.isTriggered()).toBe(false);
    // The fileExistsFn IS called each time (read-time propagation per ledger).
    // What we assert is that the answer is stable when inputs don't change.
    expect(fileChecks).toBeGreaterThanOrEqual(3);
  });

  it('scenario 9: custom envVarName override — default MAD_KILL is not consulted', () => {
    const ks = new KillSwitch(
      null,
      'CUSTOM_HALT_VAR',
      () => false,
      { MAD_KILL: '1', CUSTOM_HALT_VAR: undefined as unknown as string },
    );
    // MAD_KILL is set but the configured var is CUSTOM_HALT_VAR (unset).
    expect(ks.isTriggered()).toBe(false);

    const ks2 = new KillSwitch(
      null,
      'CUSTOM_HALT_VAR',
      () => false,
      { CUSTOM_HALT_VAR: '1' },
    );
    expect(ks2.isTriggered()).toBe(true);
  });

  it('env value other than "1"/"true" does NOT trigger (e.g., "0", "false", "")', () => {
    for (const v of ['0', 'false', '', 'no', 'off']) {
      const ks = new KillSwitch(
        null,
        'MAD_KILL',
        () => false,
        { MAD_KILL: v },
      );
      expect(ks.isTriggered()).toBe(false);
    }
  });

  it('read-time propagation: env mutation between checks is observed', () => {
    const env: Record<string, string | undefined> = { MAD_KILL: undefined };
    const ks = new KillSwitch(null, 'MAD_KILL', () => false, env);

    expect(ks.isTriggered()).toBe(false);

    env.MAD_KILL = '1';
    expect(ks.isTriggered()).toBe(true);

    env.MAD_KILL = '0';
    expect(ks.isTriggered()).toBe(false);
  });
});
