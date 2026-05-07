---
artifact-class: council-review
feature-id: F-028
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-018 / lane-a
---

# F-028 cli-entry — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 75 |
| architect-lens | Architect | APPROVE | 87 |

Median confidence: 87

## Implementation reviewed

- `packages/cli/src/index.ts` — ~103 LOC at review time. Exports `Subcommand` callable type (`(args: string[]) => Promise<number>`), `CliOptions` interface (`subcommands: Record<string, Subcommand>`, optional `defaultSubcommand`, optional `programName`), and the `runCli(argv, opts): Promise<number>` async dispatcher. Bottom-of-file `import.meta.url === \`file://${process.argv[1]}\`` block makes the file runnable directly via `node packages/cli/src/index.ts` (or via `tsx`) for development; production binary wiring lives in `packages/cli/package.json` `bin` field.
- `packages/cli/package.json` — `name: @mad-council-claw/cli`, `type: module` (ESM), `private: true`, `exports` map including `.` (entry) + `./subcommands` + `./json-output` (the latter two added in wave-017 / lane-d via F-029 + F-030 same-package additions; not under review here), `bin: { "nested-quilt": "./src/index.ts" }`. The bin field enables Node ESM-resolved invocation for `nested-quilt` after a future build/transpile step.
- `tests/node/F-028-cli-entry.test.ts` — 138 LOC, 7 acceptance scenarios using `vi.spyOn(process.stdout, 'write')` + `vi.spyOn(process.stderr, 'write')` to capture output without launching real processes: scenario 1 (root help on no args + exit 0); scenario 2 (`--help` + exit 0); scenario 3 (`-h` + exit 0); scenario 4 (unknown subcommand + non-zero + stderr error); scenario 5 (registered subcommand return code propagates); scenario 6 (subcommand args flow through after subcommand name); scenario 7 (`programName` override surfaces in help output). All 7/7 PASS at review time per `pnpm test` 2026-05-07 (full suite 225/225 across 31 test files).
- Composition with F-030 (wave-017 / lane-d): `runCli` now imports `stripJsonFlag` from `./json-output.js` and strips `--json` from `subArgs` before forwarding to the matched subcommand (line 71 of index.ts). The original F-028 contract (subcommand args flow through verbatim minus `--json`) is preserved — F-028's 7 scenarios continue to pass without modification because no scenario exercises `--json`. F-030 adds an additive responsibility on the dispatcher, not a contract change.
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-028 RED at wave-003 / lane-a (initial ledger creation only); F-028 GREEN at wave-016 / lane-c (RED test file 7 scenarios + GREEN impl ~95 LOC; first feature in the repo to live under `packages/cli/`).
- GREEN proof: `docs/09-examples-proof/F-028/{red,green}-test-output.txt` + `physical-proof.md`.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. ~103 LOC delivers the entire CLI entry + dispatcher surface: 1 callable type (`Subcommand`) + 1 interface (`CliOptions`) + 1 dispatcher function (`runCli`) + 1 helper (`printRootHelp`). No premature abstraction — no command class hierarchy, no flag-parser library dep, no subcommand registry abstraction beyond `Record<string, Subcommand>`.
- All 7 acceptance scenarios PASS. The 3 root-help scenarios (no args + `--help` + `-h`) verify the no-side-effect entry path: print help to stdout, return exit 0, never invoke a subcommand. The unknown-subcommand scenario verifies the negative path: stderr error message + exit non-zero + help also printed for context (consumer can recover by looking at the available list). The subcommand-return-code-propagation scenario verifies the positive path: subcommand's `Promise<number>` is awaited and surfaced as the dispatcher's return. The args-flow-through scenario verifies that arguments after the subcommand name reach the registered callable verbatim. The programName-override scenario verifies the customization point — useful when the same `runCli` runs as different binaries (e.g., `nested-quilt` for development, `mad-council-cli` for a future production rebrand).
- Async dispatcher returning `Promise<number>` is the right shape for an exit code carrier. The `import.meta.url === ...` direct-execution block awaits the promise then `process.exit(code)`. Unhandled rejection caught + logged to stderr + exit 1 (lines 96-101). The structure mirrors clawpilot's `cp:src/main/index.ts` bootstrap shape (cited in the file header docblock + ledger surface trace) — the dispatcher is the entry point that the build/transpile step turns into the Windows `mad-council.exe` / POSIX `mad-council` binary (per the F-028 ledger §Behavior contract).
- F-028 is the **first M4 (Headless CLI) feature** flipped (wave-016 / lane-c) and the cornerstone primitive — F-029 (subcommands), F-030 (json-output), and F-031 (daemon-mode) compose against this surface without changing it. By wave-017 / lane-d, F-029 + F-030 had landed (M4 = 1R + 3G + 0L pre-this-LOCKED-flip); the dispatcher contract has held across both extension features. F-029's `standardSubcommands: Record<string, Subcommand>` plugs directly into the existing `CliOptions.subcommands` map; F-030's `stripJsonFlag` is a 1-line additive responsibility on `runCli` that doesn't change any existing scenario's behavior.
- Test-ergonomics: `vi.spyOn(process.stdout, 'write')` + `vi.spyOn(process.stderr, 'write')` is the right shape for testing CLI output without launching subprocesses. The pattern mirrors how Node's own test harnesses test process IO. Scenarios are all in-process; total test time at GREEN was ~12ms (the slowest scenario in the entire test suite is ~57ms; F-028 is well under).
- Surface trace per ledger: `foundational-plan:V:8` ("BOTH UI surfaces — desktop + headless CLI") + `cp:src/main/index.ts` (clawpilot main bootstrap shape) + `kit:resume-handoff-skill` (CLI is the natural surface for `/resume-handoff`-style invocations). Provenance is auditable; the dispatcher shape mirrors clawpilot's main bootstrap but adapted for headless (no Electron `app.whenReady()`, no window opening; a future F-031 daemon-mode is the closest equivalent).

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 75)**

- F-028 lands the **entry + dispatcher scaffold only**. Three deviations from the ledger §Behavior contract + §Acceptance scenarios are recorded openly per `no-silent-deferrals.md`:
  1. **Exit code on unknown subcommand is `1`, not `64` (EX_USAGE)** per the ledger §Acceptance scenarios scenario 2. The wave-016 / lane-c brief deferred sysexits.h normalization to F-029 (subcommands), which itself recorded another deferral in wave-017 / lane-d (F-029 still emits `1`, not `64`). The ledger §Implementation notes paragraph 1 documents this openly. F-029's brief explicitly preserves F-028's exit code `1` shape; sysexits.h normalization is now a future M4+ feature, not part of the current GREEN flips. Surfaced honestly; the deferral chain is one-step deeper than expected at wave-016 time.
  2. **Windows-no-flash + IPv6 dual-stack (ledger scenario 3) NOT exercised in v1.** Those concerns belong to the binary launcher (electron-builder / native shim), not the JS dispatcher. The scaffold cannot exercise them; tracked in F-031 (daemon-mode, RED at this review time).
  3. **`--state-dir` flag + `MAD_COUNCIL_*` env-var resolution** (ledger §Behavior contract) deferred. They belong with concrete subcommands that read state, not with the entry dispatcher. F-029 ships subcommand stubs only; concrete behavior is itself deferred.
- LOCKED status here is therefore narrowly "**F-028 dispatcher-scaffold contract LOCKED**" — the dispatcher shape (Subcommand + CliOptions + runCli) is permanent; the runtime concerns (exit-code normalization, Windows-no-flash, env-var resolution, state-dir resolution) are deferred to subsequent M4+ flips that the dispatcher composes against.
- **Behavior-contract vs impl-scope divergence**: the ledger §Behavior contract paragraph reads "The headless CLI is a single executable entrypoint (`mad-council` on POSIX, `mad-council.exe` on Windows) ... supports a global `--state-dir` flag (default: platform-appropriate user data dir), respects `MAD_COUNCIL_*` env vars for non-interactive defaults, and never opens a window or background process unless explicitly told to (per F-031 daemon mode). The entry binary MUST be built for Windows / macOS / Linux from day 1 (Windows is tier-1 per `lessons-learned.md`)." — the impl provides the JS dispatcher only; the binary build (electron-builder / native shim) + Windows tier-1 packaging + state-dir resolution + env-var defaults are all caller-integration work owned by future features. Surfaced honestly per `no-silent-deferrals.md`: F-028 LOCKED applies to the dispatcher scaffold scope.
- **Binary name divergence**: ledger §Behavior contract names the binary `mad-council` / `mad-council.exe`; package.json `bin` field is `nested-quilt`. The default `programName` in `runCli` is also `nested-quilt` (line 48 of index.ts) but it's overridable via `CliOptions.programName` (scenario 7 covers the override). The mismatch is intentional but not advertised in the F-028 ledger — `nested-quilt` is the project codename / temporary CLI name; `mad-council` is the eventual public-facing binary name. A consumer reading the ledger §Behavior contract paragraph could be surprised by `nested-quilt` showing up in help output. Acceptable for v1 because the override mechanism exists; surfaced for the future binary-naming + packaging wave.
- **Direct-execution block`import.meta.url === \`file://${process.argv[1]}\`** (lines 88-102 of index.ts): the in-place fallback subcommand registry only wires `version` (returns "0.0.0\n"). When the file is invoked directly via `node packages/cli/src/index.ts` (without a transpile step) or `tsx packages/cli/src/index.ts`, only `version` is recognized; everything else is "unknown subcommand". This is intentional — the production path is to import `runCli` from a parent that supplies the F-029 `standardSubcommands` map. The file-as-binary path is for development-only smoke tests; production binary wiring requires the F-031 daemon-mode + electron-builder packaging. Surfaced for the future binary packaging wave.
- **F-030 stripJsonFlag side effect** (line 71 of index.ts, added in wave-017 / lane-d): `runCli` now strips `--json` from subArgs BEFORE forwarding. F-028's 7 scenarios don't exercise `--json`, so they continue to pass — but the contract has subtly shifted: a subcommand can no longer observe a literal `--json` token in its args. F-029's subcommand stubs all PASS with the strip behavior because they emit deterministic stdout regardless of `--json` presence (the strip is a no-op on args without the flag). Acceptable; the contract change is forward-compatible (subcommands authored against F-028 alone never expected `--json` to appear). The behavior is documented in the docblock lines 67-71. Surfaced for the future F-030 LOCKED review (when F-030 is itself reviewed, this dispatcher-side strip should be cited as the integration point).
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/cli/src/index.ts` lines 1-103 directly + `tests/node/F-028-cli-entry.test.ts` lines 1-138 directly + `packages/cli/package.json` directly + the F-028 ledger lines 1-134 directly. The implementation matches the contract; the dispatcher is async + pure (no side effects beyond `process.stdout`/`process.stderr` writes); subcommands run with their own args slice; unknown subcommand path writes the error to stderr THEN prints help (so `code !== 0 + stderr non-empty` is the negative-path witness per scenario 4). The `-h` and `--help` paths share the same code path with no-args (line 51).

## Architect lens

**Verdict: APPROVE (confidence 87)**

- File-location posture: `packages/cli/src/index.ts` per the wave-014 / lane-b workspace scaffold (F-003). The `packages/cli/` workspace was scaffolded empty in wave-014 / lane-b and stayed empty until wave-016 / lane-c authored the first src/ entry (this feature). The wave-011 / lane-a "shared types live with their FIRST owner" convention applies: `Subcommand` + `CliOptions` + `runCli` live with F-028; F-029 (subcommands.ts) + F-030 (json-output.ts) are co-located in the same package as additive surfaces, importing `Subcommand` from `./index.js` (line 1 of subcommands.ts) and `runCli` from the same.
- Public API surface (`runCli` + `Subcommand` + `CliOptions`): minimal and predictable.
  - `Subcommand = (args: string[]) => Promise<number>`: the simplest correct callable shape. Async (so subcommands can `await` engine-core calls); takes `string[]` (the post-subcommand-name args slice); returns `Promise<number>` (exit code carrier). No optional second parameter, no context object — keep the interface tight; if subcommands need more context, the concrete subcommand can close over it via the closure that registers it in the map.
  - `CliOptions { subcommands: Record<string, Subcommand>; defaultSubcommand?: string; programName?: string }`: the dispatcher's input contract. `subcommands` is required (no point dispatching with no targets). `defaultSubcommand` is optional but currently unused (line 51 prints help unconditionally on no-args — `defaultSubcommand` reservation is for a future feature that wants `nested-quilt` to default to a specific command without args). `programName` is optional with default `nested-quilt`.
  - `runCli(argv, opts): Promise<number>`: the dispatcher itself. argv-shape mirrors `process.argv` (slices off `[node, script]` at line 47). The slicing is the canonical Node entry-point convention.
- ESM module style throughout: `type: module` in package.json + `.js` import extensions even for `.ts` source files (e.g., `import { stripJsonFlag } from './json-output.js'` line 25) per Node ESM convention + tsconfig `moduleResolution: Bundler`. The convention is consistent with `packages/engine-core/src/*.ts` ESM imports (e.g., `import { RunHaltedVerdict } from './halt.js'`).
- Direct-execution block via `import.meta.url === \`file://${process.argv[1]}\``: the canonical ESM-aware "is this file the entry point" check. Equivalent to CommonJS's `if (require.main === module)` but works in ESM. Pre-built path: invoked via `node packages/cli/src/index.ts` directly. Production-build path: package.json `bin` field exposes `nested-quilt` as a callable; npm/pnpm symlinks it into `node_modules/.bin`.
- Composition with F-029 + F-030 (already shipped, wave-017 / lane-d):
  - F-029 imports `Subcommand` from `@mad-council-claw/cli` (the package's `.` export); F-029 is consumed by external callers via `@mad-council-claw/cli/subcommands` (the `./subcommands` export added in wave-017 / lane-d).
  - F-030 imports nothing from F-028's index.ts (it's a leaf module: just `JsonOutput` interface + 3 functions). F-028's index.ts imports `stripJsonFlag` from F-030 (1-import, 1-call).
  - The dependency direction is acyclic: index.ts ← json-output.ts (F-030); subcommands.ts (F-029) ← index.ts (Subcommand type). No `runCli` ↔ `standardSubcommands` cycle. Clean module graph.
- Forward path for F-031 daemon-mode + Windows binary packaging:
  - F-031 will compose against `runCli` by adding a `daemon` subcommand that detaches from the parent terminal (Windows: `windowsHide: true` + `detached: true`; POSIX: `setsid` + `nohup`). The dispatcher contract doesn't change; F-031 is purely a `Subcommand` registration + a child-process spawn helper.
  - Windows binary packaging will pick up `bin: nested-quilt` from package.json + run electron-builder (or pkg / nexe) to produce `nested-quilt.exe`. The IPv6 dual-stack + console-window-flash concerns are launcher-shim-level, not dispatcher-level; F-031's daemon-mode + the packaging wave own them.
- Hard deps per ledger: F-001 (engine kernel — CLI subcommands eventually invoke runs), F-002 (identity for spawned runs), F-008 (storage layout for state-dir resolution). The current impl has compile-time dep on NONE of these (the dispatcher knows nothing about engine-core; it dispatches abstract `Subcommand`s). The boundary is in place; concrete subcommands wire the deps when they invoke engine code. Forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE) — same architectural shape as F-009 IBackendProvider (interface lives separately from concrete providers).
- Soft deps per ledger: F-029 (subcommands, GREEN at wave-017 / lane-d), F-030 (json-output, GREEN at wave-017 / lane-d), F-031 (daemon-mode, RED). F-029 + F-030 have already composed cleanly against F-028 with zero contract drift; F-031 is RED but the dispatcher contract is forward-compatible.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Exit code on unknown subcommand is `1`, not `64` (EX_USAGE) per ledger acceptance scenario 2. Wave-016 / lane-c deferred sysexits.h normalization to F-029; F-029 wave-017 / lane-d ALSO deferred (preserved exit code `1` unchanged). Sysexits.h normalization is now a future M4+ feature. | Accept; ledger §Implementation notes paragraph 1 documents this openly + F-029 ledger §Implementation notes documents the chained deferral. Backlog item: M4 sysexits.h normalization wave (covers F-028 + F-029 + F-031 unknown-subcommand / data-error / config-error paths). |
| F2 | MINOR | Windows-no-flash + IPv6 dual-stack (ledger scenario 3) NOT exercised. Those concerns belong to the binary launcher (electron-builder / native shim), not the JS dispatcher. Tracked in F-031 (daemon-mode, RED). | Accept; ledger §Implementation notes paragraph 2 documents this openly. F-031 ledger owns the integration. |
| F3 | MINOR | `--state-dir` flag + `MAD_COUNCIL_*` env-var resolution deferred. They belong with concrete subcommands that read state, not with the entry dispatcher. F-029 stubs do not read state; concrete behavior deferred. | Accept; ledger §Implementation notes paragraph 3 documents this openly. Future M4+ feature when concrete subcommand behavior lands. |
| F4 | MINOR | Binary name divergence: ledger names binary `mad-council` / `mad-council.exe`; package.json `bin` + default `programName` are `nested-quilt`. The mismatch is intentional (project codename) but not advertised in the F-028 ledger. | Accept; CliOptions.programName override mechanism exists; future binary-naming + packaging wave normalizes. |
| F5 | MINOR | F-030 stripJsonFlag side effect: `runCli` now strips `--json` from subArgs before forwarding (added wave-017 / lane-d). Subcommand can no longer observe a literal `--json` token. F-028's 7 scenarios don't exercise `--json` so contract is preserved; subtle dispatcher-level shift. | Accept; behavior is documented in dispatcher docblock lines 67-71 + F-030 ledger. F-030's eventual LOCKED review should cite this dispatcher-side strip as the integration point. |
| F6 | PRAISE | Async dispatcher returning `Promise<number>` is the canonical exit-code carrier shape. The `import.meta.url === ...` direct-execution block awaits + `process.exit(code)`. Unhandled rejection caught + logged to stderr + exit 1. Production-quality entry-point shape. | Keep. |
| F7 | PRAISE | Test-ergonomics via `vi.spyOn(process.stdout/stderr, 'write')` is the right shape for in-process CLI testing — no subprocess launch, no shell quoting, no platform-specific path issues. ~12ms scenario time; well under the 50ms threshold. Pattern mirrors Node's own test harnesses. | Keep. |
| F8 | PRAISE | F-029 (subcommands) + F-030 (json-output) compose against F-028's surface with zero contract drift. F-029 plugs into `CliOptions.subcommands` map; F-030's stripJsonFlag is 1-import + 1-call additive responsibility. The clean module graph (index.ts ← json-output.ts; subcommands.ts ← index.ts) validates F-028's tight callable-+-record-+-options shape. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 87).

F-028 dispatcher-scaffold contract is implemented correctly; all 7 acceptance scenarios pass per the recorded green-test-output proof and re-verified at review time (`pnpm test` 2026-05-07: 31 test files / 225 tests / 0 failed); no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-028 ledger frontmatter (`LOCKED if GREEN AND reviews/F-028-cli-entry-review.md exists with verdict: ACCEPT`).

The MINOR findings F1-F5 are honest scope-narrowing notes per `no-silent-deferrals.md`. F1+F2+F3 are deferrals already documented in the ledger §Implementation notes and confirmed propagating cleanly into F-029's deferral set. F4 (binary name divergence) is a packaging-wave concern with an existing override mechanism. F5 (F-030 stripJsonFlag dispatcher-side strip) is forward-compatible additive responsibility documented in the dispatcher docblock. PRAISE findings F6-F8 capture three load-bearing architectural choices: async dispatcher exit-code shape, in-process testing ergonomics, and the clean module graph that F-029 + F-030 validate empirically.

F-028 transitions GREEN → LOCKED.

**This LOCKED transition is the first M4 (Headless CLI) feature LOCKED — the cornerstone primitive. M4 sibling features F-029 + F-030 are GREEN and LOCKED-eligible against this dispatcher contract; F-031 is RED but composes against F-028 forward-compatibly. This review establishes the precedent shape future M4 LOCKED reviews follow.**

## Cross-references

- Ledger: `docs/03-feature-catalog/M4-headless-cli/F-028-cli-entry.md`
- Source: `packages/cli/src/index.ts` (~103 LOC; F-028-owned ~95 LOC + 1-import + 1-line F-030 strip integration)
- Package: `packages/cli/package.json` (`bin: nested-quilt`, `exports` map with `.` + `./subcommands` + `./json-output`)
- Tests: `tests/node/F-028-cli-entry.test.ts` (7/7 PASS at GREEN time + at review time)
- GREEN proof: `docs/09-examples-proof/F-028/{red,green}-test-output.txt` + `physical-proof.md`
- GREEN transition: ledger status-history wave-016 / lane-c (first feature in the repo to live under `packages/cli/`)
- Engine-core file-split convention applied to packages/cli/: same pattern (per-feature .ts files; barrel re-export via package.json exports map)
- Same-package extensions: F-029 (subcommands, wave-017 / lane-d) + F-030 (json-output, wave-017 / lane-d) — both composed against F-028's surface with zero contract drift
- Composing features (forward): F-031 (daemon-mode, RED) + future Windows binary packaging wave (electron-builder / pkg / nexe) + future sysexits.h normalization wave (covers F-028 + F-029 + F-031 exit codes)
- Surface trace: `foundational-plan:V:8` + `cp:src/main/index.ts` (clawpilot main bootstrap shape adapted for headless) + `kit:resume-handoff-skill`
- Kit rule: `council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence: 87 + Decision: ACCEPT + size > 500B)
- Pattern: async dispatcher + Promise<number> exit code carrier + in-process spy-based testing (also used by Node's own test harnesses)
- Precedent: F-007 review (wave-013 / lane-b — scaffold-shape contract LOCKED narrowly), F-009 review (wave-014 / lane-d — interface contract LOCKED with concrete providers deferred)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
