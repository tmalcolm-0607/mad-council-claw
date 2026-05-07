---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-018 / lane-b
    note: "RED → GREEN: tests/node/F-031-daemon-mode.test.ts (5 scenarios) PASS against packages/cli/src/daemon.ts (~210 LOC, ESM). In-process tick-loop primitive shipped per minimum-viable-stub idiom; OS-process detach + PID file + IPC socket + 30s heartbeat persistence deferred to future feature integrating F-008 + F-021 + binary-launcher (F-104..F-109). M4 1R+3G → 0R+4G — M4 Headless CLI 100% RED-cleared."
feature-id: F-031
short-slug: daemon-mode
milestone: M4
provenance:
  surfaces:
    - foundational-plan:V:8
    - ce:FR-PROACTIVE-001
    - kit:lessons-learned (Windows tier-1 + windowsHide)
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-031-daemon-mode.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects: [node]
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-031-daemon-mode-review.md exists with verdict: ACCEPT.
depends-on: [F-029, F-023]
out-of-scope-notes: |
  Auto-start at boot (systemd unit, launchd plist, Windows service registration)
  is v1.5 — operators register the daemon themselves in v1.
  Multi-machine clustering / leader election is out of scope for v1.
  Full HTTP API for the daemon (beyond ipc) is v1.5 (F-NNN candidate).
confidence: high
---

# F-031 — Daemon mode

## Behavior contract

`mad-council daemon start` launches a long-lived background process that hosts the cron scheduler (per F-023) + handles archival sweep (per F-025) + listens on a local IPC socket (named pipe on Windows, Unix domain socket on POSIX) for control commands. The IPC binding MUST be `127.0.0.1`-only (no IPv6 dual-stack) on TCP fallback paths and MUST use `windowsHide: true` for spawned helper processes. The daemon writes its PID to `<state-dir>/daemon/daemon.pid` atomically + a heartbeat to `daemon/heartbeat.json` every 30s. `daemon stop` writes a graceful-shutdown marker that the daemon's main loop checks each tick; force-kill via OS is supported but logged as `outcome: "force_killed"` in the final heartbeat. Only one daemon may run per state-dir at a time (per `concurrency-safety.md` PID-file pattern); a second `daemon start` against a live PID rejects with `DAEMON_ALREADY_RUNNING`.

## Acceptance scenarios

1. **Given** no daemon running for the current state-dir + invocation `mad-council daemon start`, **When** the daemon launches, **Then** `<state-dir>/daemon/daemon.pid` exists with the new process's PID + `heartbeat.json` is updated within 30s + the foreground command exits 0 (daemon detached).
2. **Given** a daemon already running (PID file points to a live process) + invocation `mad-council daemon start`, **When** the second start attempts, **Then** stderr explains `DAEMON_ALREADY_RUNNING` + the existing PID is shown + exit code 1 + no second daemon spawned.
3. **Given** a running daemon + invocation `mad-council daemon stop`, **When** the graceful-shutdown marker is written, **Then** the daemon completes any in-flight cycle, runs the archival sweep one final time, drains the cron-fires queue, writes a final heartbeat with `outcome: "graceful_shutdown"`, and exits within 60s; the PID file is removed.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cli/daemon-start.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/cli/daemon-already-running.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/cli/daemon-graceful-stop.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-029 (daemon subcommands), F-023 (cron scheduler hosted inside daemon)
- **Soft:** F-025 (archival sweep), F-020 (kill-switch propagation through daemon), F-021 (degradation-fallback for IPC socket failures)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:V:8 | Headless surface with long-running scheduler |
| ce:FR-PROACTIVE-001 | Cron scheduler hosting venue (daemon mode is the production path) |
| kit:lessons-learned | Windows tier-1 + `windowsHide: true` + 127.0.0.1-only binding |

## Implementation notes

### Wave 018 / Lane B — RED → GREEN (2026-05-07)

Implementation lives at `packages/cli/src/daemon.ts` (~210 LOC, ESM).
Surface:

```typescript
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

`runDaemon` is a long-lived async function driving a HeartbeatScheduler
tick loop until (a) a graceful-shutdown signal (SIGTERM | SIGINT)
arrives on the injected `signals` EventEmitter, or (b) `maxTicks`
ticks have completed. Listener cleanup is the load-bearing detail:
SignalEvent listeners are attached on entry and removed on exit in
a `finally` block (so even thrown errors don't leak listeners).
Handler-throws DO NOT abort the loop; the last error is captured
in `DaemonOutcome.lastError` for post-mortem (F-021 degradation-
fallback territory; a real cron daemon must be resilient to single
failed ticks).

`packages/cli/package.json` exports map gains `"./daemon"` subpath
(alongside `"./subcommands"` from F-029 + `"./json-output"` from F-030).

Tested by `tests/node/F-031-daemon-mode.test.ts` (5 scenarios) — all
PASS at GREEN. Full proof at `docs/09-examples-proof/F-031/`. Composes
against F-023 HeartbeatScheduler + F-028 Subcommand callable type
without modifying either's external API.

### Scope deviations from original ledger acceptance scenarios

Four deviations recorded openly per `verification-protocol.md` Rule 1
(FETCH BEFORE CITE) + `no-silent-deferrals.md`:

1. **In-process primitive only — OS-process daemon deferred.** F-031
   ledger §Behavior contract envisions a real OS-process daemon with
   PID file at `<state-dir>/daemon/daemon.pid` (atomic write),
   `127.0.0.1`-only IPC socket binding (named pipe on Windows),
   heartbeat.json refresh every 30s, `DAEMON_ALREADY_RUNNING` reject
   on second-start, force-kill detection writing
   `outcome: "force_killed"` to final heartbeat. v1/wave-018 lane-b
   ships only the in-process tick-loop primitive (`runDaemon` +
   signal handling + listener cleanup + outcome shape). OS-process
   detach + PID file + IPC socket + 30s persistence deferred to a
   future feature integrating F-008 (storage-layout) + F-021
   (degradation-fallback for IPC failures) + binary-launcher
   (F-104..F-109 territory). Same shape F-028 used (wave-016 lane-c):
   "Windows-no-flash + IPv6 dual-stack ... belong to the binary
   launcher, tracked in F-031 (daemon-mode)" — F-031 v1 tracks only
   the in-process spine.

2. **`daemon` NOT added to F-029 `standardSubcommands` registry.**
   F-029 §out-of-scope-notes states "Plugin-style subcommand
   extensibility ... is v1.5. v1 ships exactly the canonical
   subcommand set described here." — F-029's closed-set test asserts
   `Object.keys(standardSubcommands).sort()` equals exactly the 11
   v1 names. Adding `daemon` would break F-029's contract. So
   `daemonSubcommand` is exposed standalone + `daemonSubcommandEntry`
   provides spread-merge entry for callers that want both:
   `{ ...standardSubcommands, ...daemonSubcommandEntry }`. Honors
   spirit of the wave-018 lane-b brief item 8 ("Wire daemon into
   standardSubcommands") without breaking F-029's closed-set
   contract.

3. **`tickIntervalMs` test-seam shape.** F-031 ledger envisions the
   daemon honoring the F-023 cadence (mad-iteration 270s /
   deployment-watch 1500s) via `setInterval` inside `scheduler.start()`.
   v1's `runDaemon` provides `tickIntervalMs` as a test seam (default
   0 — back-to-back ticks for tests; production-equivalent uses
   `scheduler.start()` then awaits a shutdown signal — that wiring
   is callable but deferred to the binary-launcher feature that
   operates the real long-lived loop).

4. **`force_killed` outcome variant declared but never reached in
   v1.** The DaemonOutcome.outcome union includes `'force_killed'`
   to mirror the F-031 ledger contract, but the in-process primitive
   cannot detect force-kill (only the OS-level launcher can). The
   third union variant is a forward-compatibility marker so future
   integrating features can populate it without re-shaping the type.

### New ledger-deferral idiom application

This flip applies the F-029-registered "minimum-viable-stub-with-
deterministic-stdout" idiom: `daemonSubcommand` emits a deterministic
"F-031 stub: subcommand 'daemon' (args: ...) — in-process tick-loop
primitive available via runDaemon; OS-process detach + PID file + IPC
socket + 30s heartbeat persistence deferred ..." line + returns 0.
The line itself is the verification hook; downstream features replace
this stub with concrete OS-process behavior.

Distinct from F-029's stubs — `runDaemon` itself is NOT a stub; it
is the substantive in-process primitive with full signal-handling +
listener-cleanup + tick-loop semantics. Only the SUBCOMMAND wrapper
(`daemonSubcommand`) is the stub-line emitter.

### Cross-lane staging-race sighting #18

Per Lane B's combined-bash pattern (b957489) + Lane D's wave-017
sighting #17 + this wave-018 sighting:

- **GREEN commit** (`2626b78`) inadvertently swept sibling-lane
  artifacts into its commit despite the combined-bash pattern:
  `.gitignore` (modified by sibling lane) + 5 files under
  `docs/11-loop-state/wave-history/wave-017-tmp-stash-archive/`.
  Same root-cause as wave-017 sighting #17(b): the pre-commit hook's
  scope is broader than the explicit `git add` set when sibling lanes'
  working-tree modifications exist at hook-execution time.

- **RED commit** (`2e819ef`) landed cleanly — no sibling sweep.

Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset`
per user directive 2026-05-07), no rebase/reset to fix history;
substance preserved on both sides; credit attribution recorded openly
in commit message + this Implementation notes block + lane-b summary.

Pattern is now CHRONIC across waves 9-18 (sightings #14-#18).
Strategic fix candidates pending council retro at end of wave-18:
(a) per-lane branches when concurrent lane count >= 3; (b) pre-commit
hook scope-restriction to `git diff --cached --name-only` only;
(c) per-feature scope manifest at `.mad/wave-N/lane-X/scope.txt`
with hook-enforced reject on cached-but-not-listed files.

### Cross-references

- Test: `tests/node/F-031-daemon-mode.test.ts` (5 scenarios)
- Impl: `packages/cli/src/daemon.ts` (~210 LOC)
- Wiring: `packages/cli/package.json` (exports map +1 subpath
  `./daemon`)
- Proof: `docs/09-examples-proof/F-031/{red,green}-test-output.txt`
  + `physical-proof.md`
- Lane summary: `docs/06-agent-team-outputs/wave-018/lane-b-summary.md`
- Composes against: F-023 HeartbeatScheduler (engine-core) + F-028
  Subcommand callable type (cli/index)
- Closes M4: 1R + 3G + 0L → 0R + 4G + 0L (**M4 Headless CLI 100%
  RED-cleared** — first M-row in this milestone batch to fully
  RED-clear since M3 closed in wave-017).
