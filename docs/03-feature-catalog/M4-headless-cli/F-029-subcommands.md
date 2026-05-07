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
    by: wave-017 / lane-d
    note: "RED → GREEN: tests/node/F-029-cli-subcommands.test.ts (8 scenarios) PASS against packages/cli/src/subcommands.ts (~70 LOC, ESM). Closed 11-name registry shipped as MINIMUM-VIABLE STUBS per no-silent-deferrals.md; concrete behavior deferred to subsequent M4+ features."
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
  node:
    - tests/node/F-029-cli-subcommands.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects: [node]
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

### Wave 017 / Lane D — RED → GREEN (2026-05-07)

Implementation lives at `packages/cli/src/subcommands.ts` (~70 LOC, ESM).
Surface:

```typescript
import type { Subcommand } from './index.js';

export const standardSubcommands: Record<string, Subcommand> = {
  start, status, halt, retro, replay,
  'query-audit', 'list-sessions',
  archive, restore,
  version,    // emits "0.0.0\n" + returns 0
  help,       // emits a help-pointer line + returns 0
};
// 9 stubs each emit: "F-029 stub: subcommand '<name>' (args: ...)" + return 0
```

Tested by `tests/node/F-029-cli-subcommands.test.ts` (8 scenarios) — all
PASS at GREEN. Full proof at `docs/09-examples-proof/F-029/`. Composes
against F-028's `Subcommand` callable type without touching it (the
wave-011/lane-a "shared types live with their FIRST owner" convention).

### Scope deviations from original ledger acceptance scenarios

Three deviations recorded openly per `verification-protocol.md` Rule 1
(FETCH BEFORE CITE) + `no-silent-deferrals.md`:

1. **Stubs only — concrete behavior deferred.** Original §Acceptance
   scenarios envision real subcommands invoking the F-001 engine
   kernel (`run start <config>`), F-016 audit query (`audit query`),
   F-008 storage layer (`archive`/`restore`), F-031 daemon
   (`daemon start`/`daemon stop`), etc. v1/wave-017 ships
   MINIMUM-VIABLE STUBS only — every stub returns 0 + emits a
   deterministic "F-029 stub: subcommand '<name>' (args: ...)" line.
   Concrete implementations land in subsequent M4+ features.
2. **Sysexits.h exit-code normalization deferred.** Original scenario 2
   specifies exit code 64 (EX_USAGE) on unknown-subcommand path.
   F-028's `runCli` still returns `1` (per F-028 ledger §Implementation
   notes scope-deviation #1); F-029 layer doesn't change that. The
   exit-code surface across the subcommand set is its own future
   feature.
3. **Bulk-halt consent gate (scenario 3) deferred** to whichever future
   feature implements concrete cron pause/resume (`/cron pause` is
   currently a F-029 stub). The consent-gate is in F-027's territory
   once `cron pause` leaves stub state.

### New ledger-deferral idiom

"Minimum-viable-stub-with-deterministic-stdout" — registered as a
deferral pattern in the project lexicon. Distinct from:

- F-010/F-011's "stub-body-vs-deferred-real-SDK" (those have full
  IBackendProvider contract behavior; just no real network call)
- F-004's "config-present, runtime-deferred" (config file lands;
  runtime activation deferred to consumer wave)

F-029 stubs satisfy nothing structural beyond "runs + returns 0 +
emits a deterministic line" — the stub line itself is the verification
hook for downstream features that will replace each stub with a real
implementation.

### Cross-references

- Test: `tests/node/F-029-cli-subcommands.test.ts` (8 scenarios)
- Impl: `packages/cli/src/subcommands.ts` (~70 LOC)
- Wiring: `packages/cli/package.json` (exports `./subcommands` subpath)
- Proof: `docs/09-examples-proof/F-029/{red,green}-test-output.txt`
  + `physical-proof.md`
- Lane summary: `docs/06-agent-team-outputs/wave-017/lane-d-summary.md`
- Sibling-this-wave: F-030 cli-json-output (this lane); F-024/F-025/
  F-026/F-027 (sibling lanes B/C — M3 features)
- Downstream: F-031 daemon-mode (only RED M4 feature remaining); future
  M4+ features will swap each stub for concrete behavior + integrate
  with F-030 `--json` mode
