/**
 * F-027 Manual halt override — GREEN.
 *
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-027-manual-halt-override.md.
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
 *   HeartbeatScheduler caller integration; the bulk-pause consent gate
 *   (>5 schedules) is also caller-side.
 *
 * Dependencies (per ledger):
 *   - Hard: F-020 (kill-switch infrastructure for halting active runs;
 *     this primitive emits the verdict shape F-020's read-time propagation
 *     consumes), F-023 (scheduler reads pause state per tick).
 *   - Soft: F-014 (retro fires on halt), F-018 (halt is one of 13+ trigger
 *     enum values — this uses the `manual` trigger reserved for operator
 *     halts).
 */

import type { RunHaltedVerdict } from './halt.js';

/**
 * Inputs for {@link manualHaltOverride}. The injected `consentGate` is
 * the operator-confirmation hook — it MUST be supplied by the caller and
 * MUST return a boolean (or a Promise<boolean>) at invocation time. The
 * consent gate is always called on every invocation; there is no
 * cached-consent shortcut at this primitive layer.
 *
 * Why injection: the consent gate's UI is host-specific (CLI prompt,
 * desktop dialog, cron-pause auto-approve). Injecting it lets the same
 * primitive serve all hosts without conditional UI code.
 */
export interface ManualHaltOptions {
  /** F-002 run correlation id stamped onto the verdict. */
  runId: string;
  /**
   * Caller-supplied reason preserved verbatim on the verdict for audit
   * trail per `dangerous-operations-policy.md` §Enforcement (every consent
   * gate emission writes a line to consent-log.jsonl).
   */
  reason: string;
  /**
   * Caller-injected consent gate. Returns boolean OR Promise<boolean>.
   * When false → halt is aborted; an Error is thrown so callers can
   * distinguish abort-by-user from a real failure.
   */
  consentGate: () => boolean | Promise<boolean>;
}

/**
 * Operator-initiated halt. Awaits the injected consent gate; if denied,
 * throws an abort Error whose message contains "consent" and "denied" so
 * downstream callers can map abort-by-user → exit 0 (cancelled) vs real
 * errors → exit non-zero.
 *
 * Acceptance scenarios (from F-027 ledger + wave-017/lane-c brief):
 *   1. consentGate=()=>true → returns RunHaltedVerdict (type='RUN_HALTED',
 *      trigger='manual').
 *   2. consentGate=()=>false → throws Error containing "consent denied".
 *   3. runId is stamped onto verdict.run_id verbatim.
 *   4. reason is carried through to verdict.reason verbatim.
 *   5. async consentGate (Promise<boolean>) is awaited before halt fires.
 *   6. timestamp is captured at halt time as ISO-8601.
 *
 * The verdict shape itself is owned by halt.ts (F-018 first-owner per
 * the wave-011/lane-a barrel-ownership rule); this primitive constructs
 * it but does not extend it.
 */
export async function manualHaltOverride(
  opts: ManualHaltOptions,
): Promise<RunHaltedVerdict> {
  const consent = await opts.consentGate();
  if (!consent) {
    throw new Error(
      `Manual halt aborted: consent denied for run ${opts.runId}`,
    );
  }
  return {
    type: 'RUN_HALTED',
    trigger: 'manual',
    reason: opts.reason,
    timestamp: new Date().toISOString(),
    run_id: opts.runId,
  };
}
