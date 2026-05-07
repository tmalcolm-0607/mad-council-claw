import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { EventEmitter } from 'node:events';
import {
  runDaemon,
  daemonSubcommand,
  type DaemonOutcome,
} from '@mad-council-claw/cli/daemon';
import { HeartbeatScheduler } from '@mad-council-claw/engine-core';

/**
 * F-031 RED → GREEN test (tests/node — Node-environment).
 * Per docs/03-feature-catalog/M4-headless-cli/F-031-daemon-mode.md
 * acceptance scenarios + wave-018 lane-b brief.
 *
 * Behavior contract (lane-b brief shape):
 *   The daemon-mode primitive is a long-lived async function `runDaemon`
 *   that wraps an F-023 HeartbeatScheduler tick loop. It:
 *     - Registers graceful-shutdown listeners for SIGTERM + SIGINT on
 *       an injectable signals EventEmitter (defaults to `process`)
 *     - Drives a tick loop (await scheduler.tick() in a loop) bounded
 *       by a graceful-shutdown signal OR an injectable max-ticks seam
 *       (`maxTicks`, default Infinity) for test ergonomics
 *     - Returns a structured DaemonOutcome with outcome (graceful_shutdown
 *       | tick_exhausted | force_killed), tickCount, skippedTicks,
 *       lastError?
 *     - Removes its own listeners on exit (no leaks across daemon
 *       invocations within the same process)
 *
 *   The `daemonSubcommand` export is a Subcommand-shaped wrapper that
 *   tests can dispatch via runCli; it constructs a default scheduler
 *   (mad-iteration profile, no idle-archival) + runs ONE bounded tick
 *   loop in test mode so we can exercise the subcommand surface
 *   without spawning a real long-lived process.
 *
 * Scope deviation from ledger (intentional, documented per
 * `no-silent-deferrals.md` + wave-016 lane-c F-028 precedent):
 *   The F-031 ledger §Behavior contract specifies a real OS-process
 *   daemon (PID file at <state-dir>/daemon/daemon.pid, IPC socket
 *   binding 127.0.0.1-only / named pipe on Windows, atomic PID-file
 *   write, heartbeat.json every 30s, force-kill detection,
 *   DAEMON_ALREADY_RUNNING reject path on second-start). The wave-018
 *   lane-b brief simplifies this to an in-process tick-loop primitive
 *   with injectable signals + bounded test seam. The substantive
 *   guarantees — long-lived loop semantics, graceful-shutdown signal
 *   handling, scheduler tick wiring, exit-code-bearing outcome shape,
 *   listener cleanup — are preserved; the OS-process detach + PID
 *   file + IPC socket + 30s heartbeat persistence are deferred to a
 *   future feature that integrates F-008 (storage-layout) +
 *   F-021 (degradation-fallback for IPC failures) + the binary
 *   launcher (electron-builder / native shim — F-104..F-109 territory).
 *
 *   This is the same shape F-028 used (wave-016 lane-c): "Windows-
 *   no-flash + IPv6 dual-stack NOT exercised in v1; those concerns
 *   belong to the binary launcher, tracked in F-031" — F-031 v1
 *   tracks only the in-process orchestration spine.
 *
 * Wired-down acceptance scenarios (5 test scenarios; F-031 ledger
 * lists 3 broader OS-process scenarios — these test the in-process
 * primitive that callers compose into a real daemon binary in a
 * future feature):
 *
 *   1. runDaemon with maxTicks=3 + a no-op handler runs exactly 3
 *      ticks then resolves with outcome='tick_exhausted', tickCount=3.
 *   2. runDaemon resolves with outcome='graceful_shutdown' when
 *      SIGTERM is emitted on the injected signals EventEmitter
 *      mid-loop (between ticks).
 *   3. runDaemon resolves with outcome='graceful_shutdown' when
 *      SIGINT is emitted on the injected signals EventEmitter.
 *   4. runDaemon registers signal listeners on entry and removes
 *      them on exit (count returns to baseline; no listener leaks
 *      across invocations).
 *   5. daemonSubcommand is a Subcommand that returns 0 when invoked
 *      with --max-ticks=2 + emits a deterministic line on stdout
 *      per the minimum-viable-stub-with-deterministic-stdout idiom.
 */

describe('F-031 daemon-mode — runDaemon long-lived loop primitive', () => {
  let stdoutChunks: string[];
  let stderrChunks: string[];
  let stdoutSpy: ReturnType<typeof vi.spyOn>;
  let stderrSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    stdoutChunks = [];
    stderrChunks = [];
    stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(((chunk: string | Uint8Array) => {
      stdoutChunks.push(typeof chunk === 'string' ? chunk : Buffer.from(chunk).toString('utf8'));
      return true;
    }) as typeof process.stdout.write);
    stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(((chunk: string | Uint8Array) => {
      stderrChunks.push(typeof chunk === 'string' ? chunk : Buffer.from(chunk).toString('utf8'));
      return true;
    }) as typeof process.stderr.write);
  });

  afterEach(() => {
    stdoutSpy.mockRestore();
    stderrSpy.mockRestore();
  });

  it('scenario 1: runDaemon runs exactly maxTicks ticks then exits with tick_exhausted', async () => {
    const scheduler = new HeartbeatScheduler({
      profile: 'custom',
      intervalSeconds: 1,
      enforceWarmCacheZones: false, // 1s is in forbidden zone; bypass for tests
    });
    let handlerInvocations = 0;
    const outcome: DaemonOutcome = await runDaemon({
      scheduler,
      handler: async () => {
        handlerInvocations++;
      },
      maxTicks: 3,
      tickIntervalMs: 0, // no real-time delay between ticks in tests
    });
    expect(outcome.outcome).toBe('tick_exhausted');
    expect(outcome.tickCount).toBe(3);
    expect(handlerInvocations).toBe(3);
    expect(outcome.skippedTicks).toBe(0);
  });

  it('scenario 2: runDaemon exits with graceful_shutdown on SIGTERM', async () => {
    const scheduler = new HeartbeatScheduler({
      profile: 'custom',
      intervalSeconds: 1,
      enforceWarmCacheZones: false,
    });
    const signals = new EventEmitter();
    let tickCount = 0;
    const daemonPromise = runDaemon({
      scheduler,
      handler: async () => {
        tickCount++;
        if (tickCount === 2) {
          // Emit SIGTERM mid-loop after 2 successful ticks.
          // The daemon's between-tick check sees the shutdown flag
          // and exits before tick 3 is invoked.
          signals.emit('SIGTERM');
        }
      },
      maxTicks: 100,
      tickIntervalMs: 0,
      signals,
    });
    const outcome = await daemonPromise;
    expect(outcome.outcome).toBe('graceful_shutdown');
    // Either 2 (SIGTERM caught between tick 2 and tick 3) or 3 (one
    // more tick completed before the loop checked the flag) is
    // acceptable; the key invariant is it stopped well before maxTicks=100.
    expect(outcome.tickCount).toBeGreaterThanOrEqual(2);
    expect(outcome.tickCount).toBeLessThanOrEqual(3);
  });

  it('scenario 3: runDaemon exits with graceful_shutdown on SIGINT', async () => {
    const scheduler = new HeartbeatScheduler({
      profile: 'custom',
      intervalSeconds: 1,
      enforceWarmCacheZones: false,
    });
    const signals = new EventEmitter();
    let tickCount = 0;
    const outcome = await runDaemon({
      scheduler,
      handler: async () => {
        tickCount++;
        if (tickCount === 1) {
          signals.emit('SIGINT');
        }
      },
      maxTicks: 100,
      tickIntervalMs: 0,
      signals,
    });
    expect(outcome.outcome).toBe('graceful_shutdown');
    expect(outcome.tickCount).toBeGreaterThanOrEqual(1);
    expect(outcome.tickCount).toBeLessThanOrEqual(2);
  });

  it('scenario 4: runDaemon removes signal listeners on exit (no leaks)', async () => {
    const scheduler = new HeartbeatScheduler({
      profile: 'custom',
      intervalSeconds: 1,
      enforceWarmCacheZones: false,
    });
    const signals = new EventEmitter();
    // Register a baseline non-daemon listener to confirm we only
    // remove our own listeners, not all listeners on the emitter.
    const baseline = vi.fn();
    signals.on('SIGTERM', baseline);
    signals.on('SIGINT', baseline);
    const baselineSigterm = signals.listenerCount('SIGTERM');
    const baselineSigint = signals.listenerCount('SIGINT');
    expect(baselineSigterm).toBe(1);
    expect(baselineSigint).toBe(1);

    await runDaemon({
      scheduler,
      handler: async () => {},
      maxTicks: 1,
      tickIntervalMs: 0,
      signals,
    });

    // Exactly one tick ran; daemon exited via tick_exhausted; both
    // listeners were registered + removed during the run; baseline
    // listeners remain.
    expect(signals.listenerCount('SIGTERM')).toBe(baselineSigterm);
    expect(signals.listenerCount('SIGINT')).toBe(baselineSigint);

    // Run a second invocation to confirm no listener accumulation
    // across daemon lifecycles.
    await runDaemon({
      scheduler: new HeartbeatScheduler({
        profile: 'custom',
        intervalSeconds: 1,
        enforceWarmCacheZones: false,
      }),
      handler: async () => {},
      maxTicks: 1,
      tickIntervalMs: 0,
      signals,
    });
    expect(signals.listenerCount('SIGTERM')).toBe(baselineSigterm);
    expect(signals.listenerCount('SIGINT')).toBe(baselineSigint);
  });

  it('scenario 5: daemonSubcommand is callable and emits a deterministic stub line', async () => {
    expect(typeof daemonSubcommand).toBe('function');
    // No --max-ticks flag → daemonSubcommand defaults to maxTicks=1
    // (test-mode default; real-binary mode uses Infinity but is
    // deferred per ledger §Implementation notes).
    const code = await daemonSubcommand([]);
    expect(code).toBe(0);
    const stdout = stdoutChunks.join('');
    expect(stdout).toContain('F-031');
    expect(stdout).toMatch(/daemon/i);
  });
});
