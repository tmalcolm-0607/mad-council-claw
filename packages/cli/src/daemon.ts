/**
 * F-031 cli-daemon-mode — long-lived tick-loop primitive.
 *
 * Authored wave-018 / lane-b (per docs/03-feature-catalog/M4-headless-cli/
 * F-031-daemon-mode.md). Composes against F-023 HeartbeatScheduler
 * (engine-core/heartbeat.ts) without modifying it — the wave-011/lane-a
 * "shared types live with their FIRST owner" convention applies.
 *
 * v1 / wave-018 scope is intentionally MINIMUM-VIABLE IN-PROCESS
 * PRIMITIVE per `no-silent-deferrals.md` + the wave-016/lane-c F-028
 * scope-deviation precedent. The F-031 ledger §Behavior contract
 * envisions a REAL OS-process daemon:
 *   - PID file at `<state-dir>/daemon/daemon.pid` (atomic write)
 *   - 127.0.0.1-only IPC socket binding (named pipe on Windows)
 *   - heartbeat.json refresh every 30s
 *   - `DAEMON_ALREADY_RUNNING` reject on second-start
 *   - Force-kill detection writes `outcome: "force_killed"` to final heartbeat
 *
 * v1 / lane-b ships only the IN-PROCESS orchestration spine:
 *   - `runDaemon(opts)` — long-lived async function driving a
 *     HeartbeatScheduler tick loop until graceful-shutdown OR maxTicks
 *   - Injectable `signals: EventEmitter` (defaults to `process`) so
 *     tests inject SIGTERM/SIGINT without spawning real processes
 *   - Injectable `maxTicks` test seam (default Infinity for production-
 *     equivalent shape; tests pass small values)
 *   - Returns `DaemonOutcome` with structured exit info
 *   - Removes its own signal listeners on exit (no leaks across
 *     invocations within the same process)
 *
 * Substantive guarantees PRESERVED:
 *   - Long-lived loop semantics (loop continues until told to stop)
 *   - Graceful-shutdown signal handling (SIGTERM + SIGINT)
 *   - F-023 HeartbeatScheduler tick wiring (composes via scheduler.tick())
 *   - Exit-code-bearing outcome shape (callers map outcome → exit code)
 *   - Listener cleanup (no resource leaks)
 *
 * DEFERRED to future features integrating F-008 + F-021 + binary-launcher
 * (F-104..F-109 territory):
 *   - OS-process detach (real `fork`/`spawn` with detached: true)
 *   - PID file persistence at `<state-dir>/daemon/daemon.pid`
 *   - IPC socket binding (127.0.0.1 + named pipe on Windows)
 *   - Heartbeat persistence (heartbeat.json every 30s)
 *   - Second-start `DAEMON_ALREADY_RUNNING` reject path
 *   - Force-kill detection + final-heartbeat outcome write
 *
 * The same shape F-028 used (wave-016 lane-c): "Windows-no-flash + IPv6
 * dual-stack NOT exercised in v1; those concerns belong to the binary
 * launcher (electron-builder / native shim), not the JS dispatcher,
 * tracked in F-031 (daemon-mode)" — F-031 v1 tracks only the in-process
 * spine. The OS-process shell is a launcher concern.
 *
 * F-029 closed-registry contract: F-029 ledger §out-of-scope-notes states
 * "Plugin-style subcommand extensibility ... is v1.5. v1 ships exactly
 * the canonical subcommand set described here." Adding `daemon` to
 * `standardSubcommands` would break F-029's closed-set test. So
 * `daemonSubcommand` is exported standalone here — callers wire it into
 * their own subcommand map (or merge with `standardSubcommands` via
 * spread when they need both). This preserves F-029's contract while
 * making daemon-mode readily wirable.
 */

import { EventEmitter } from 'node:events';
import type { Subcommand } from './index.js';
import { HeartbeatScheduler } from '@mad-council-claw/engine-core';

/**
 * Outcome shape returned by `runDaemon`. `outcome` indicates why the
 * loop terminated; `tickCount` reports how many ticks completed; the
 * other fields are observability for callers that want to log or
 * exit-code-encode the result.
 */
export interface DaemonOutcome {
  /** Why the loop stopped. */
  outcome: 'graceful_shutdown' | 'tick_exhausted' | 'force_killed';
  /** Total successful tick handler invocations. */
  tickCount: number;
  /** F-024 in-flight skip count surfaced through to caller. */
  skippedTicks: number;
  /** If a tick handler threw, the captured error (handler-throws don't
   *  abort the daemon — they're recorded and the loop continues; this
   *  surfaces the LAST error for post-mortem). */
  lastError?: Error;
}

/**
 * Configuration for `runDaemon`. The `scheduler` field is the F-023
 * HeartbeatScheduler primitive; the `handler` is the per-tick callback;
 * everything else has a sensible default for production-equivalent
 * shape and explicit test seams.
 */
export interface DaemonOptions {
  /** F-023 scheduler primitive whose tick() drives the loop. */
  scheduler: HeartbeatScheduler;
  /** Per-tick handler. Throws are caught + logged; loop continues. */
  handler: () => void | Promise<void>;
  /**
   * Test seam — bounded tick count. Default: Number.POSITIVE_INFINITY
   * (production-equivalent: run until signal). Tests pass small ints.
   */
  maxTicks?: number;
  /**
   * Test seam — milliseconds to wait between ticks. Default: 0 (run
   * ticks back-to-back as fast as possible). Production-equivalent
   * with cadence honoring is left to a future feature; v1's tick
   * loop is driven by setInterval inside HeartbeatScheduler.start()
   * OR by maxTicks for tests, not by an embedded cadence here.
   */
  tickIntervalMs?: number;
  /**
   * Signal source. Default: process (real OS signals). Tests pass an
   * EventEmitter and emit('SIGTERM' | 'SIGINT') without spawning real
   * processes. The signals object must support .on / .off so we can
   * register + remove listeners cleanly.
   */
  signals?: NodeJS.EventEmitter;
}

/**
 * Long-lived tick loop. Returns when (a) a graceful-shutdown signal is
 * received, OR (b) `maxTicks` ticks have completed.
 *
 * Discipline:
 *   - Listener cleanup is the load-bearing detail: signal listeners are
 *     attached on entry, removed on exit. Tests assert listenerCount
 *     returns to baseline after each invocation. A leaked listener
 *     across daemon lifecycles is the kind of slow-burn bug that
 *     produces "double-shutdown" in long-running processes.
 *   - Handler throws DO NOT abort the loop — `runDaemon` catches and
 *     records the last error (F-021 degradation-fallback territory; a
 *     real cron daemon must be resilient to single failed ticks). The
 *     final DaemonOutcome carries lastError for post-mortem.
 *   - The `shutdownRequested` flag is checked between ticks; a
 *     SIGTERM/SIGINT received mid-tick allows that tick to complete
 *     (graceful) but suppresses the next tick.
 *
 * @param opts DaemonOptions — required scheduler + handler; optional
 *             maxTicks + tickIntervalMs + signals test seams.
 * @returns DaemonOutcome — structured exit info.
 */
export async function runDaemon(opts: DaemonOptions): Promise<DaemonOutcome> {
  const {
    scheduler,
    handler,
    maxTicks = Number.POSITIVE_INFINITY,
    tickIntervalMs = 0,
    signals = process,
  } = opts;

  let shutdownRequested = false;
  let lastError: Error | undefined = undefined;

  const onSigterm = (): void => {
    shutdownRequested = true;
  };
  const onSigint = (): void => {
    shutdownRequested = true;
  };

  signals.on('SIGTERM', onSigterm);
  signals.on('SIGINT', onSigint);

  let tickCount = 0;
  try {
    while (!shutdownRequested && tickCount < maxTicks) {
      try {
        await scheduler.tick();
        await handler();
        tickCount++;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
        tickCount++; // count failed-handler ticks too — observability matches F-018 recordFailure shape
      }

      if (shutdownRequested || tickCount >= maxTicks) break;

      if (tickIntervalMs > 0) {
        await new Promise<void>((resolve) => setTimeout(resolve, tickIntervalMs));
      }
    }
  } finally {
    // Always remove our listeners — even on throw — to prevent leaks
    // across daemon invocations within the same process. Tests assert
    // listenerCount returns to baseline.
    signals.off('SIGTERM', onSigterm);
    signals.off('SIGINT', onSigint);
  }

  const outcome: DaemonOutcome['outcome'] = shutdownRequested
    ? 'graceful_shutdown'
    : 'tick_exhausted';

  return {
    outcome,
    tickCount,
    skippedTicks: scheduler.getStatus().skippedTicks,
    ...(lastError != null ? { lastError } : {}),
  };
}

/**
 * F-031 minimum-viable-stub-with-deterministic-stdout (per F-029's
 * registered idiom). The real-binary daemon is the future
 * OS-process feature; this stub proves the subcommand surface works +
 * emits a deterministic line for downstream wave verification.
 *
 * NOT included in F-029's `standardSubcommands` registry per the F-029
 * closed-set contract — callers compose this into their own subcommand
 * map (or spread-merge with standardSubcommands when they need both).
 */
export const daemonSubcommand: Subcommand = async (args: string[]): Promise<number> => {
  const argsStr = args.length === 0 ? 'none' : args.join(' ');
  process.stdout.write(
    `F-031 stub: subcommand 'daemon' (args: ${argsStr}) — in-process tick-loop primitive available via runDaemon; OS-process detach + PID file + IPC socket + 30s heartbeat persistence deferred to future feature integrating F-008 + F-021 + binary-launcher\n`,
  );
  return 0;
};

/**
 * Convenience entry for callers that want to merge daemon into their
 * subcommand map: `{ ...standardSubcommands, ...daemonSubcommandEntry }`.
 * Preserves F-029's closed-set contract while making the daemon
 * subcommand readily wirable.
 */
export const daemonSubcommandEntry: Record<string, Subcommand> = {
  daemon: daemonSubcommand,
};
