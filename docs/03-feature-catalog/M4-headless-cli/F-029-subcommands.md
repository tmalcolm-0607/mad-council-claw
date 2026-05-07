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
feature-id: F-029
short-slug: subcommands
milestone: M4
provenance:
  surfaces:
    - foundational-plan:V:8
    - kit:lessons-learned (CLI surface enumeration)
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
  LOCKED if GREEN AND reviews/F-029-subcommands-review.md exists with verdict: ACCEPT.
depends-on: [F-028]
out-of-scope-notes: |
  Plugin-style subcommand extensibility (third-party `mad-council-foo` binaries on PATH)
  is v1.5. v1 ships exactly the canonical subcommand set described here.
  Interactive prompts within subcommands (TUI selectors) are out of scope for v1; CLI is non-interactive.
confidence: high
---

# F-029 — Subcommands

## Behavior contract

The CLI exposes a canonical subcommand surface for the engine's run + automation lifecycle. Each subcommand reads `--state-dir` (or env override), validates inputs, performs its operation, and writes structured output (per F-030). The v1 canonical subcommands:

| Subcommand | Purpose |
|---|---|
| `run start <config-path>` | Spawn a fresh run from a config file; prints `run_id` |
| `run status <run_id>` | Show lifecycle + cycle count + last audit entry |
| `run halt <run_id>` | Write to kill-switch (per F-020); halt within ≤1 cycle |
| `run list [--filter active\|closed\|halted]` | Enumerate runs in `<state-dir>/runs/` |
| `cron list` | List schedules from `automations/cron-schedules.json` |
| `cron pause <schedule_id>` / `cron resume <schedule_id>` | Manual halt override (per F-027) |
| `cron fires [--schedule <id>] [--since <ts>]` | Stream `cron-fires.jsonl` filtered |
| `audit query [--run <id>] [--agent <id>] [--since <ts>]` | F-016 query API surfaced via CLI |
| `audit verify <run_id>` | Run hash-chain verification (per F-015) |
| `daemon start` / `daemon stop` / `daemon status` | F-031 daemon-mode operations |

Every subcommand is non-interactive: no prompts, no TUI, no waiting on stdin unless `--input -` is passed. Operator-confirmation gates (per F-027 bulk-halt) require an explicit `--yes` flag; without it, the subcommand exits 1 with a stderr message describing what would happen.

## Acceptance scenarios

1. **Given** a valid run config at `./config.json`, **When** the operator runs `mad-council run start ./config.json`, **Then** a new run directory is created under `<state-dir>/runs/<run_id>/` + stdout prints exactly the run_id + newline + exit 0.
2. **Given** an unknown subcommand path (e.g., `mad-council run nonexistent`), **When** the binary runs, **Then** stderr explains `nonexistent` is not a valid `run` subcommand + lists available `run` subcommands + exit code is 64.
3. **Given** the operator running `mad-council cron pause sched-1 sched-2 sched-3 sched-4 sched-5 sched-6` (6 schedules), **When** the bulk-halt consent gate fires (per F-027), **Then** without `--yes` the operation refuses with stderr describing the consent requirement + exit 1; with `--yes` all 6 are paused.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cli/run-start.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/cli/unknown-subcommand.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/cli/bulk-halt-consent.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-028 (CLI entry dispatcher)
- **Soft:** F-001 (run start/status/halt subcommands invoke kernel), F-016 (audit query surfaces F-016's API), F-020 (run halt writes to kill-switch), F-023 (cron list reads schedules), F-027 (cron pause/resume), F-030 (output format), F-031 (daemon subcommands)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:V:8 | Headless CLI for cron / external orchestrators |
| kit:lessons-learned | CLI surface enumeration (`mad-council list`, `status`, `kill`) |

## Implementation notes

(empty — populated when implementation begins)
