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
feature-id: F-028
short-slug: cli-entry
milestone: M4
provenance:
  surfaces:
    - foundational-plan:V:8 (BOTH UI surfaces — desktop + headless CLI)
    - cp:src/main/index.ts (clawpilot main bootstrap shape)
    - kit:resume-handoff-skill
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
  LOCKED if GREEN AND reviews/F-028-cli-entry-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008]
out-of-scope-notes: |
  Auto-completion (bash/zsh/PowerShell completion scripts) is v1.5.
  Color-aware terminals + ANSI rendering is v1.5; v1 is plain UTF-8.
  Help-text generation from frontmatter (auto-doc) is v1.5.
confidence: high
---

# F-028 — CLI entry

## Behavior contract

The headless CLI is a single executable entrypoint (`mad-council` on POSIX, `mad-council.exe` on Windows) that exposes the engine's run lifecycle without requiring the desktop shell. It dispatches to subcommands (per F-029), supports a global `--state-dir` flag (default: platform-appropriate user data dir), respects `MAD_COUNCIL_*` env vars for non-interactive defaults, and never opens a window or background process unless explicitly told to (per F-031 daemon mode). The entry binary MUST be built for Windows / macOS / Linux from day 1 (Windows is tier-1 per `lessons-learned.md`). Path-separator hardcoding, IPv6 dual-stack binding, and console-window-flash are all known footguns to avoid.

## Acceptance scenarios

1. **Given** a fresh installation + invocation `mad-council --version`, **When** the binary runs, **Then** stdout is exactly the semver string + a newline, exit code 0, no other output, no state files created.
2. **Given** an invalid subcommand (e.g., `mad-council fooble`), **When** the binary runs, **Then** stderr lists available subcommands, stdout is empty, exit code is 64 (EX_USAGE — sysexits.h convention).
3. **Given** the binary on Windows under PowerShell with no terminal attached (e.g., spawned from a service), **When** any subcommand runs, **Then** no console window flashes (`windowsHide: true` for spawn) + no IPv6 dual-stack binding occurs (`127.0.0.1`-only for any local server).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cli/version-flag.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/cli/invalid-subcommand-exit-code.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/cli/windows-no-flash.test.ts` | integration | RED — Windows-only test | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel — CLI subcommands eventually invoke runs), F-002 (identity for spawned runs), F-008 (storage layout for state-dir resolution)
- **Soft:** F-029 (subcommands), F-030 (JSON output), F-031 (daemon mode)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:V:8 | "Targets BOTH UI surfaces" — Electron desktop + headless CLI |
| cp:src/main/index.ts | clawpilot Electron-main bootstrap shape (adapted for headless) |
| kit:resume-handoff-skill | CLI is the natural surface for `/resume-handoff`-style invocations |

## Implementation notes

(empty — populated when implementation begins)
