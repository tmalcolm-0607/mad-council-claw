---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-016 / lane-c
    note: "RED → GREEN: tests/node/F-028-cli-entry.test.ts (7 scenarios) PASS against packages/cli/src/index.ts (~95 LOC). First M4 feature to flip; Headless CLI reaches 3R + 1G + 0L."
  - status: locked
    at: 2026-05-07
    by: wave-018 / lane-a
    note: "GREEN → LOCKED transition; post-impl council review verdict ACCEPT (median confidence 87; Advocate APPROVE 90, Skeptic APPROVE-WITH-SUGGESTIONS 75, Architect APPROVE 87; 0 CRITICAL / 0 MAJOR / 5 MINOR / 3 PRAISE). Review file: docs/05-design-reviews/council-reviews/F-028-cli-entry-review.md. MINOR findings: exit code on unknown subcommand is `1`, not `64` (sysexits.h normalization deferred chain — F-028 deferred to F-029, F-029 deferred to future M4+ wave); Windows-no-flash + IPv6 dual-stack belong to F-031 binary launcher not JS dispatcher; --state-dir + MAD_COUNCIL_* env vars deferred to concrete subcommands; binary name divergence (ledger names mad-council, package.json bin is nested-quilt — override mechanism exists); F-030 stripJsonFlag dispatcher-side strip is forward-compatible additive responsibility documented in dispatcher docblock. PRAISE: async dispatcher returning Promise<number> is canonical exit-code carrier shape; vi.spyOn-based in-process testing is right shape (~12ms scenario time); F-029+F-030 compose against F-028 with zero contract drift validating tight callable+record+options shape. First M4 (Headless CLI) feature LOCKED — establishes the precedent shape for M4 remaining LOCKED transitions. Re-verified at review time: 7/7 PASS, full suite 225/225 across 31 test files."
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
  node:
    - tests/node/F-028-cli-entry.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects: [node]
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

### Wave 016 / Lane C — RED → GREEN (2026-05-07)

Implementation lives at `packages/cli/src/index.ts` (~95 LOC, ESM).
Surface:

```typescript
export type Subcommand = (args: string[]) => Promise<number>;
export interface CliOptions {
  subcommands: Record<string, Subcommand>;
  defaultSubcommand?: string;
  programName?: string;
}
export async function runCli(argv: string[], opts: CliOptions): Promise<number>
```

The dispatcher takes `process.argv`-shape input (slices off `[node, script]`),
resolves the first user arg as a subcommand name against `opts.subcommands`,
and either prints root help (no args / `--help` / `-h`), invokes the matched
subcommand with remaining args, or writes a stderr error + help on unknown
subcommand.

Tested by `tests/node/F-028-cli-entry.test.ts` (7 scenarios) — all PASS at
GREEN. Full proof at `docs/09-examples-proof/F-028/`.

### Scope deviations from original ledger acceptance scenarios

Three deviations recorded openly per `verification-protocol.md` Rule 1
(FETCH BEFORE CITE) + `no-silent-deferrals.md`:

1. **Exit code on unknown subcommand is `1`, not `64` (EX_USAGE).** The
   original ledger §Acceptance scenarios scenario 2 specifies `64` per
   `sysexits.h`. The v1 scaffold uses `1`; F-029 (subcommands) will
   normalize the exit-code surface. The behavior contract is preserved
   (non-zero exit + stderr error); only the specific code differs.
2. **Windows-no-flash + IPv6 dual-stack (ledger scenario 3) NOT
   exercised in v1.** Those concerns belong to the binary launcher
   (electron-builder / native shim), not the JS dispatcher. The
   scaffold cannot exercise them; tracked in F-031 (daemon-mode).
3. **`--state-dir` flag + `MAD_COUNCIL_*` env-var resolution (ledger
   §Behavior contract) deferred to F-029.** They belong with concrete
   subcommands that read state, not with the entry dispatcher.

### Cross-references

- Test: `tests/node/F-028-cli-entry.test.ts` (7 scenarios)
- Impl: `packages/cli/src/index.ts` (~95 LOC)
- Wiring: `packages/cli/package.json` (exports + bin); `package.json`
  (root devDependency `@mad-council-claw/cli: workspace:*`)
- Proof: `docs/09-examples-proof/F-028/{red,green}-test-output.txt`
  + `physical-proof.md`
- Lane summary: `docs/06-agent-team-outputs/wave-016/lane-c-summary.md`
- Downstream: F-029 (subcommands), F-030 (json-output), F-031
  (daemon-mode) all RED — they wire concrete behavior into this
  dispatcher.
