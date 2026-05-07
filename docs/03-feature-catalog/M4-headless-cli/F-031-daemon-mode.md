---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
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
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
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

(empty — populated when implementation begins)
