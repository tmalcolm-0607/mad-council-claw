/**
 * F-020 Read-time-propagating kill switch — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-020-kill-switch.md
 * + wave-010 / lane-b brief.
 *
 * Behavior contract (lane-b brief shape): a `KillSwitch` class checked at
 * the START of every model + tool call. Kill state surfaces from EITHER
 * an environment variable (default `MAD_KILL=1` or `=true`) OR the
 * existence of a designated file (caller-supplied path; checked via the
 * injected `fileExistsFn`). When triggered:
 *   - `isTriggered()` returns true (idempotent across reads — read-time
 *     propagation per the F-020 ledger; no internal state mutation).
 *   - `checkOrThrow()` throws an Error decorated with a `RunHaltedVerdict`
 *     whose `trigger` is `manual` (the F-018 sibling trigger reserved for
 *     operator/kill-switch invocations) per the F-018 verdict-shape contract.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

import type { RunHaltedVerdict } from './halt.js';

/**
 * Default function used to test file existence. Wraps `node:fs.existsSync`
 * so callers don't have to import `fs` themselves; the module is loaded
 * lazily via `require` so test harnesses can pass an injected stub without
 * the real fs module being touched.
 *
 * Errors during the check are swallowed (return false) — a permissions
 * error or a transient FS hiccup should NOT be interpreted as "the
 * kill-file exists." Read-time propagation per the ledger means we
 * fail-safe to "not halted" when the FS layer misbehaves; an explicit
 * env-var override (`MAD_KILL=1`) remains the operator's belt-and-braces
 * path.
 */
function defaultKillFileExists(path: string): boolean {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires -- lazy CJS require so injected stubs in tests never trigger fs load.
    const fs = require('node:fs') as typeof import('node:fs');
    return fs.existsSync(path);
  } catch {
    return false;
  }
}

/**
 * Read-time-propagating kill switch.
 *
 * Construction is parameterized for testability — the env source and the
 * file-existence check are both injectable, so unit tests can drive the
 * full state matrix without touching the real filesystem or process env.
 * The default shape (no args) consults `process.env.MAD_KILL` and treats
 * a null kill-file path as "no file check configured."
 *
 * Acceptance scenarios from the wave-010 / lane-b brief + F-020 ledger:
 *   1-2. Env var MAD_KILL=1 or =true → triggered.
 *   3.   Env unset, kill-file exists → triggered.
 *   4-5. Env unset, no path OR path with non-existent file → not triggered.
 *   6.   checkOrThrow() throws Error+verdict (trigger='manual') when triggered.
 *   7.   checkOrThrow() is a no-op when not triggered.
 *   8.   Multiple isTriggered() calls are idempotent (no state mutation).
 *   9.   Custom envVarName respected; default MAD_KILL not consulted.
 *
 * Read-time propagation: every `isTriggered()` call re-reads the env + FS
 * sources, so a kill triggered AFTER engine boot is observed on the NEXT
 * cycle (per the F-020 ledger acceptance scenario 1).
 *
 * The verdict shape is the F-018 `RunHaltedVerdict` with `trigger='manual'`,
 * preserving a single uniform halt-reporting surface across F-018
 * (failure-pattern halt), F-020 (kill-switch), F-021 (degradation), and
 * F-022 (tool-quota). Callers downstream of `checkOrThrow()` can pattern-match
 * on `error.verdict.trigger` to route to the right F-014 retro outcome
 * (`halted_by_kill_switch` for trigger='manual' from a kill-switch source).
 */
export class KillSwitch {
  constructor(
    private readonly killFilePath: string | null = null,
    private readonly envVarName: string = 'MAD_KILL',
    private readonly fileExistsFn: (path: string) => boolean = defaultKillFileExists,
    private readonly env: Record<string, string | undefined> = process.env,
  ) {}

  /**
   * Read the kill-switch state at this exact moment. Returns true if EITHER
   * the configured env var is `'1'` or `'true'`, OR the kill-file path is
   * configured AND `fileExistsFn` returns true for it.
   *
   * No internal state is mutated — multiple calls are idempotent in the
   * sense that the same inputs produce the same outputs. Inputs CAN
   * change between calls (the env Record may be mutated, the file may be
   * created or removed), and the read-time-propagation contract requires
   * those changes to be observed on the next call.
   */
  isTriggered(): boolean {
    const envVal = this.env[this.envVarName];
    if (envVal === '1' || envVal === 'true') {
      return true;
    }
    if (this.killFilePath !== null && this.fileExistsFn(this.killFilePath)) {
      return true;
    }
    return false;
  }

  /**
   * Throw a `RunHaltedVerdict`-decorated Error if the kill switch is
   * triggered; otherwise return undefined (no-op). The thrown Error's
   * `verdict` property carries the F-018 verdict shape with
   * `trigger='manual'` and a non-empty `reason` describing which source
   * tripped (env var or file).
   *
   * Designed to be called at the START of every model + tool call —
   * cycle-start hook integration is the engine-bootstrap (F-001)
   * integration step that this primitive feeds.
   */
  checkOrThrow(): void {
    if (!this.isTriggered()) {
      return;
    }

    // Identify the source for the verdict reason — gives the operator + the
    // F-014 retro a precise audit trail.
    const envVal = this.env[this.envVarName];
    const envTripped = envVal === '1' || envVal === 'true';
    const fileTripped =
      this.killFilePath !== null && this.fileExistsFn(this.killFilePath);

    let reason: string;
    if (envTripped && fileTripped) {
      reason = `Kill switch triggered: env ${this.envVarName}=${envVal} AND file ${this.killFilePath} exists`;
    } else if (envTripped) {
      reason = `Kill switch triggered: env ${this.envVarName}=${envVal}`;
    } else if (fileTripped) {
      reason = `Kill switch triggered: file ${this.killFilePath} exists`;
    } else {
      // Should be unreachable — isTriggered() returned true above.
      reason = 'Kill switch triggered';
    }

    const verdict: RunHaltedVerdict = {
      type: 'RUN_HALTED',
      trigger: 'manual',
      reason,
      timestamp: new Date().toISOString(),
    };

    const err = new Error(reason) as Error & { verdict: RunHaltedVerdict };
    err.verdict = verdict;
    throw err;
  }
}
