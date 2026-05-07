---
artifact-class: examples-proof
generated-by: hand-authored (wave-018 / lane-b)
feature-id: F-031
short-slug: daemon-mode
date: 2026-05-07
status: green
---

# F-031 daemon-mode — physical proof

## Files

| Role | Path | Wave |
|---|---|---|
| Test | `tests/node/F-031-daemon-mode.test.ts` | wave-018 / lane-b RED |
| Impl | `packages/cli/src/daemon.ts` | wave-018 / lane-b GREEN |
| Wiring | `packages/cli/package.json` (exports map +1 subpath `./daemon`) | wave-018 / lane-b GREEN |
| Proof | `docs/09-examples-proof/F-031/red-test-output.txt` | wave-018 / lane-b RED |
| Proof | `docs/09-examples-proof/F-031/green-test-output.txt` | wave-018 / lane-b GREEN |
| Proof | `docs/09-examples-proof/F-031/physical-proof.md` (this file) | wave-018 / lane-b GREEN |

## Test scenarios

5 acceptance scenarios, all PASS at GREEN time:

| # | Scenario | What it proves |
|---|---|---|
| 1 | runDaemon with maxTicks=3 + no-op handler runs 3 ticks then exits with outcome='tick_exhausted' | Bounded loop terminates correctly |
| 2 | runDaemon resolves outcome='graceful_shutdown' on SIGTERM | Signal handling for SIGTERM works |
| 3 | runDaemon resolves outcome='graceful_shutdown' on SIGINT | Signal handling for SIGINT works |
| 4 | runDaemon registers signal listeners on entry, removes them on exit (no leaks across invocations) | Listener cleanup discipline |
| 5 | daemonSubcommand callable + emits deterministic "F-031 ... daemon ..." stub line | Subcommand surface works for downstream wiring |

## Behavior surface

```typescript
// packages/cli/src/daemon.ts
export interface DaemonOutcome {
  outcome: 'graceful_shutdown' | 'tick_exhausted' | 'force_killed';
  tickCount: number;
  skippedTicks: number;
  lastError?: Error;
}

export interface DaemonOptions {
  scheduler: HeartbeatScheduler;
  handler: () => void | Promise<void>;
  maxTicks?: number;          // test seam; default Infinity
  tickIntervalMs?: number;    // test seam; default 0
  signals?: NodeJS.EventEmitter; // test seam; default process
}

export async function runDaemon(opts: DaemonOptions): Promise<DaemonOutcome>;

export const daemonSubcommand: Subcommand;
export const daemonSubcommandEntry: Record<string, Subcommand>;
```

## Test runner output (GREEN)

See `green-test-output.txt`. Summary:

```
✓ tests/node/F-031-daemon-mode.test.ts (5 tests) 11ms
Test Files  1 passed (1)
     Tests  5 passed (5)
```

## RED output (before impl)

See `red-test-output.txt`. Summary: vitest reports
`Missing "./daemon" specifier in "@mad-council-claw/cli" package` — module
resolution fails because `packages/cli/src/daemon.ts` does not yet exist.
This is the canonical RED shape for a new module-level export contract.

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) +
`no-silent-deferrals.md`:

1. **In-process primitive only — OS-process daemon deferred.** F-031
   ledger §Behavior contract envisions a real OS-process daemon with
   PID file at `<state-dir>/daemon/daemon.pid` (atomic write),
   `127.0.0.1`-only IPC socket binding (named pipe on Windows),
   heartbeat.json refresh every 30s, `DAEMON_ALREADY_RUNNING` reject
   on second-start, force-kill detection writing
   `outcome: "force_killed"` to final heartbeat. v1/wave-018 lane-b
   ships only the in-process tick-loop primitive (`runDaemon` + signal
   handling + listener cleanup + outcome shape). OS-process detach +
   PID file + IPC socket + 30s persistence deferred to a future feature
   integrating F-008 (storage-layout) + F-021 (degradation-fallback for
   IPC failures) + binary-launcher (F-104..F-109 territory).

2. **`daemon` NOT added to F-029 `standardSubcommands` registry.**
   F-029 §out-of-scope-notes states "Plugin-style subcommand
   extensibility ... is v1.5. v1 ships exactly the canonical subcommand
   set described here." — the F-029 closed-set test asserts
   `Object.keys(standardSubcommands).sort()` equals exactly the 11
   v1 names. Adding `daemon` would break F-029's contract. So
   `daemonSubcommand` is exposed standalone here; callers compose it
   into their own subcommand map (or merge via spread:
   `{ ...standardSubcommands, ...daemonSubcommandEntry }`). This
   honors the spirit of "wire daemon subcommand" without breaking
   F-029's closed-set contract.

3. **`tickIntervalMs` test-seam shape.** F-031 ledger envisions the
   daemon honoring the F-023 cadence (mad-iteration 270s /
   deployment-watch 1500s) via setInterval inside scheduler.start().
   v1's `runDaemon` provides a `tickIntervalMs` option as a test seam
   (default 0 — back-to-back ticks for tests; production-equivalent
   would use `scheduler.start()` then await a shutdown signal — that
   wiring is callable but deferred to the binary-launcher feature
   that operates the real long-lived loop).

4. **`force_killed` outcome value declared but never reached in v1.**
   The DaemonOutcome.outcome union includes `'force_killed'` to mirror
   the F-031 ledger contract, but the in-process primitive cannot
   detect force-kill (only the OS-level launcher can). The third
   union variant is a forward-compatibility marker so future
   integrating features can populate it without re-shaping the type.

## Composition

`runDaemon` composes against:

- **F-023 HeartbeatScheduler** — pure-class primitive providing
  `tick()`, `start()`, `stop()`, `getStatus()`. The daemon calls
  `scheduler.tick()` each loop iteration and reports
  `getStatus().skippedTicks` in the final outcome.

The F-029 + F-030 surfaces are NOT modified. The F-028 dispatcher is
NOT modified. Callers compose `daemonSubcommand` into their own
subcommand map (or via `daemonSubcommandEntry` spread) when they
want it dispatched via `runCli`.

## Listener cleanup discipline

Test scenario 4 is the load-bearing detail. SignalEvent listeners
attached on entry are removed on exit (in a `finally` block, so
even thrown errors don't leak listeners). Tests assert listenerCount
returns to baseline AND that a second daemon invocation on the same
EventEmitter does not accumulate listeners across the lifetimes.

A leaked listener across daemon lifecycles is the kind of slow-burn
bug that produces "double-shutdown" in long-running processes — when
Sig X fires, every leaked listener handles it, and downstream cleanup
runs N times instead of 1. Listener cleanup at exit is the same
discipline the kit's `loop-cadence-discipline.md` enforces in the
heartbeat layer (timer cleanup on stop()).
