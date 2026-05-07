---
artifact-class: milestone-overview
generated-by: hand-authored (wave-003 / lane-a)
status: red
milestone: M4
short-slug: headless-cli
features: F-028..F-031
authored: 2026-05-07
---

# M4 — Headless CLI

The non-interactive surface (`foundational-plan.md` § Architecture, V:8). External orchestrators, cron infrastructure, CI pipelines, and operator scripts all consume the engine through M4. M4 deliberately ships before M5 (desktop shell) because every desktop feature is reachable as a CLI subcommand first — the desktop is sugar on top of CLI primitives, not a separate surface with its own contracts. M4 is also the path that satisfies "Targets BOTH UI surfaces" (V:8) and the lessons-learned tier-1 Windows requirement.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-028 | cli-entry | Single binary `mad-council` (POSIX) / `mad-council.exe` (Windows); cross-platform from day 1; `windowsHide: true` + 127.0.0.1-only |
| F-029 | subcommands | Canonical surface: `run start/status/halt/list`, `cron list/pause/resume/fires`, `audit query/verify`, `daemon start/stop/status`; non-interactive |
| F-030 | json-output | `--format json` for single records, NDJSON for streaming; error envelopes go to stdout; sysexits.h conventions |
| F-031 | daemon-mode | Long-lived background hosts cron + archival; IPC via local socket; PID-file singleton; graceful-shutdown <60s |

## Dependency DAG

```
F-001 (kernel) ──→ F-028 (CLI eventually invokes runs)
F-002 (identity) ──→ F-028 (run config carries agent_id)
F-008 (storage) ──→ F-028 (state-dir resolution)

F-028 (entry) ──→ F-029 (dispatch to subcommands)
              └──→ F-030 (output format flag)
              └──→ F-031 (daemon subcommand subset)

F-029 ──→ F-030 (every subcommand emits output via this contract)
F-029 ──→ F-031 (daemon start/stop/status are subcommands)

F-023 (cron scheduler) ──→ F-031 (daemon hosts the scheduler)
F-025 (archival sweep) ──→ F-031 (daemon hosts the sweep)
F-020 (kill-switch) ──→ F-029 (run halt subcommand)
F-016 (audit query) ──→ F-029 (audit query subcommand)
F-015 (hash-chain verify) ──→ F-029 (audit verify subcommand)
F-027 (manual halt) ──→ F-029 (cron pause/resume subcommands)
```

## Milestone exit criteria

- All 4 ledgers GREEN
- `mad-council --version` exits 0 with semver on Windows + macOS + Linux
- `mad-council run start ./config.json` produces a valid run on all 3 platforms
- `mad-council audit query --format json` against a 50k-entry run completes in <30s with bounded memory (<200MB)
- `mad-council daemon start` followed by `daemon stop` returns within 60s on a non-empty schedule set
- A second `daemon start` against a live PID rejects with `DAEMON_ALREADY_RUNNING`
- Spawned via Windows service-runner (no terminal), no console window flashes

## Out of scope (tracked elsewhere)

- Auto-completion scripts (bash/zsh/PowerShell) → v1.5
- ANSI color rendering in `--format text` mode → v1.5
- Auto-doc help text from frontmatter → v1.5
- Plugin-style third-party subcommands on PATH → v1.5
- Boot-time daemon registration (systemd / launchd / Windows service) → v1.5
- Multi-machine clustering / leader election → out of scope for v1
- Full HTTP API for the daemon → v1.5 (F-NNN candidate)
- Pretty-printed JSON / YAML / TOML output → out of scope for v1; JSON only
- Interactive TUI prompts → out of scope; CLI is non-interactive

## Provenance

`foundational-plan:V:8` (BOTH UI surfaces — desktop + headless), `cp:src/main/index.ts` (clawpilot Electron main bootstrap shape adapted for headless), `kit:lessons-learned` (Windows tier-1, windowsHide, 127.0.0.1-only, no path-separator hardcoding), `kit:resume-handoff-skill` (CLI is the natural surface for resume), `ce:FR-PROACTIVE-001` (daemon hosts the cron scheduler), `kit:rules/{verification-protocol,concurrency-safety}.md`. Per-ledger `provenance.surfaces`.
