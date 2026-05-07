---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-018 / lane-c)
wave: wave-018
lane: lane-c
topic: F-032 window RED -> GREEN — opens M5 desktop-shell milestone
date: 2026-05-07
status: complete
---

# Wave 18 / Lane C — F-032 RED -> GREEN, M5 desktop-shell opens

## Scope

Flip F-032 (`window` — Electron BrowserWindow descriptor + window-state hydration helpers) from RED to GREEN per the ledger's `red-green-rule` predicate:

```
GREEN if all test files exist AND all runners return zero exit.
```

This is the **first M5 desktop-shell feature transition.** M5 was 12R + 0G at wave-18 lane start (no prior M5 feature had ever been touched after the wave-3 lane-a catalog drop). This lane drops 12R + 0G -> 11R + 1G (M5 opens).

The wave-018 / lane-c brief simplified the ledger's three launch-Electron acceptance scenarios to a STRUCTURAL / INTERFACE-BASED test asserting the shape of `createMainWindow(opts)` rather than actually launching Electron. Substantive guarantees (security tripod, windowsHide, default vs. restored state, IPC channel registration shape) are preserved by the structural test; full Electron BrowserWindow instantiation + on-disk round-trip + renderer runtime block are deferred to the M5 integration wave per `no-silent-deferrals.md`.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test (F-032) | `tests/unit/F-032-window.test.ts` | new (~140 LOC, 6 scenarios) |
| Source (F-032) | `packages/desktop-shell/src/window.ts` | new (~165 LOC, ESM) |
| Source (F-032) | `packages/desktop-shell/src/index.ts` | new (barrel re-export) |
| Wiring | `packages/desktop-shell/package.json` | modified (exports map populated: `.` + `./window`) |
| Wiring | `package.json` (root) | modified (devDependencies adds `@mad-council-claw/desktop-shell: workspace:*`) |
| Wiring | `pnpm-lock.yaml` | modified (`pnpm install --no-frozen-lockfile` regenerates with desktop-shell workspace entry) |
| Examples-proof | `docs/09-examples-proof/F-032/red-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-032/green-test-output.txt` | new (verbose reporter output) |
| Ledger flip (F-032) | `docs/03-feature-catalog/M5-desktop-shell/F-032-window.md` | modified (status: red -> green; status-history append documenting wave-018/lane-c flip; test-files.unit + test-runner-projects populated; Implementation notes section appended documenting scope simplification + 5 deferrals + cross-feature composition + new "descriptor-as-data, instantiation-deferred" idiom) |
| Roadmap rows | `roadmap.md` | modified (F-032 row 🔴 -> 🟢; M5 row 12R+0G -> 11R+1G; TOTAL 98R+5G+24L -> 97R+6G+24L; M5 table extended to 4-column "Test files" header for the GREEN row; wave-018/lane-c transition note inserted after wave-018/lane-a note) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 18 Lane C section + 3 entries: Lane-C-w18-F-032-GREEN, Lane-C-w18-new-deferral-idiom-descriptor-as-data, Lane-C-w18-staging-race-sighting-20) |
| Lane summary | `docs/06-agent-team-outputs/wave-018/lane-c-summary.md` | new (this file) |

## Acceptance scenarios verified at GREEN

### F-032 — 6/6 PASS

| # | Scenario | What it proves |
|---|---|---|
| 1 | `createMainWindow()` no-opts returns descriptor with default-state + canonical security webPreferences | Default-state contract (ledger scenario 1: fresh install, no state file); security tripod (sandbox: true / contextIsolation: true / nodeIntegration: false) is non-overridable; windowsHide: true honored; preload path is a non-empty string |
| 2 | `createMainWindow({windowState})` restores last position + maximized state | Last-state contract (ledger scenario 2); security tripod still enforced regardless of restored state |
| 3 | `createMainWindow({preloadPath})` uses caller-supplied preload | Preload path passthrough; preload-mediated IPC per F-007's contract scaffold |
| 4 | `createMainWindow().ipcChannels` is an array; default empty (F-007 IpcInvokeMap is empty); caller-supplied channels passed through | IPC channel registration shape; type-checked against `keyof IpcInvokeMap` at the consumer call site (TS subset-of-known-channels enforcement) |
| 5 | `resolveWindowState(null \| undefined \| {} \| partial \| full)` always yields a complete WindowState; never throws | Partial-state hydration contract; F-008 atomic-write discipline prevents half-written files but caller's null-on-missing flow still must produce a usable state |
| 6 | Descriptor is JSON-cloneable; no functions / class instances / Date objects | Plain-data contract; F-008 storage layout could persist a snapshot for restart-on-crash without serialization changes |

6/6 PASS at GREEN time. **Full unit suite 175/175 across 24 test files** (was 169/169 across 23 pre-this-lane). **Node suite 61/61 across 9 files** no regression. **Re-verified at lane-summary time: full suite 236/236 across 33 test files via `pnpm test`.** **Build: pnpm build => exit 0.**

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) + `no-silent-deferrals.md`:

### Scope simplification: structural-shape contract, not Electron-launch

The F-032 ledger §Acceptance scenarios specifies three end-to-end scenarios:

1. Fresh install + first launch -> default-sized window opens at OS-default position + `window-state.json` is created
2. Existing `window-state.json` (1200, 800, maximized) -> window opens at last position + maximized state restored
3. Renderer attempting to require `fs` -> call fails (sandboxed) + security policy observable in main-process logs

The wave-018 / lane-c brief simplifies the v1 shape to a STRUCTURAL / INTERFACE-BASED test that asserts what `createMainWindow(opts)` returns — the descriptor — rather than launching Electron. Per F-004's "browser project runtime wiring deferred to first DOM-rendering spec consumer wave," booting Electron in the unit-test path would be premature; the integration wave is the consumer.

**Substantive guarantees preserved:**
- **Security tripod** (compile-time constants in descriptor body): `sandbox: true`, `contextIsolation: true`, `nodeIntegration: false`. The renderer cannot break out of this at runtime — F-032 scenario 3 is satisfied for static configuration.
- **Windows-no-flash** (`windowsHide: true`).
- **Default-state branching** when no `windowState` supplied (ledger scenario 1).
- **Last-state restoration** when `windowState` IS supplied (ledger scenario 2).
- **IPC channel registration shape** typed against F-007's `IpcInvokeMap`.
- **JSON-cloneability** so a future feature can persist a descriptor snapshot for restart-on-crash.

### Five deferrals to the M5 integration wave

1. **Actual Electron BrowserWindow instantiation + `app.whenReady()` wiring** belongs in the M5 e2e companion suite (per F-004's "browser project runtime wiring deferred to first DOM-rendering spec consumer wave"). F-032 v1 is the prerequisite; the integration wave is the consumer.
2. **On-disk `window-state.json` round-trip with the F-008 storage layout** — caller resolves `<state-dir>/desktop/window-state.json` via F-008's atomic-read helpers and passes the parsed value to `createMainWindow({ windowState })`. F-032 produces the descriptor; F-008 owns the persistence path.
3. **Renderer-process `require('fs')` runtime block** — only the static `webPreferences` guarantee is enforced here. The runtime check requires booting Electron + a renderer process attempting the require; that's an integration scenario.
4. **Multi-window orchestration** — F-043's scope.
5. **Window-state SAVE on resize/move/maximize events** — belongs with the integration consumer that wires `win.on('resize', ...)` listeners. F-032's `resolveWindowState` only handles the read side.

## New ledger-deferral idiom registered

**"descriptor-as-data, instantiation-deferred"**

Distinct from prior idioms in the project lexicon:

| Idiom | First seen | What ships v1 | What's deferred |
|---|---|---|---|
| config-present, runtime-deferred | F-004 (wave-14) | `vitest.config.ts` browser project + `playwright.config.ts` | `@playwright/test` devDep + sharedTest fixtures + `pnpm e2e` script |
| stub-body-vs-deferred-real-SDK | F-010, F-011 (wave-15) | Full IBackendProvider contract behavior with deterministic stub yields | Real `@anthropic-ai/sdk` / Copilot CLI swaps (gated on F-070 secure-storage + recorded fixtures) |
| minimum-viable-stub-with-deterministic-stdout | F-029 (wave-17) | Subcommand registry + 9 stubs returning 0 + emitting deterministic stdout line | Concrete subcommand behavior (engine kernel calls, audit query, archive, etc.) |
| in-process primitive only | F-031 (wave-18) | runDaemon orchestration spine in-process | OS-process shell (PID file, IPC socket, 30s heartbeat persistence, force-kill detection) |
| **descriptor-as-data, instantiation-deferred** | **F-032 (wave-18)** | **Plain-data descriptor (`MainWindowDescriptor`) ready for `new BrowserWindow(descriptor)` consumption** | **The instantiation step itself + on-disk round-trip + renderer runtime block** |

The "descriptor-as-data" idiom differs from the others: the OUTPUT (a plain object shape) is the entire deliverable; the consumer step is purely "pass this to a foreign constructor." The idiom enables structural testing without bundling Electron into the test runner. F-038..F-043 will compose against this same descriptor without changing it.

Future Electron-bound features (M5 integration wave, F-038 primitives, F-043 multi-window) should cite this entry.

## Cross-feature composition

| Composes against | LOCKED state | Role |
|---|---|---|
| F-007 ipc-contract-scaffold | LOCKED (wave-13/lane-b) | `MainWindowOptions.ipcChannels` types as `ReadonlyArray<IpcInvokeChannel>`. The scaffold's `IpcInvokeMap` is empty in v1, so the default subscription set is `[]`; future M5 features (F-033..F-043) extend `IpcInvokeMap` and pass channel names here. |
| F-008 local-storage-layout | LOCKED (wave-12/lane-d) | Caller reads `<state-dir>/desktop/window-state.json` via F-008's atomic-read helpers and passes the parsed value to `createMainWindow({ windowState })`. F-032 produces the descriptor; F-008 owns the persistence path. |
| F-001 engine-bootstrap-loop | LOCKED (wave-11/lane-b) | The eventual Electron entry hosts the engine kernel in the main process; `createMainWindow` is called from that entry point. |
| F-038, F-039, F-040, F-041, F-042, F-043 | RED (all M5 siblings) | Future M5 features compose against `MainWindowDescriptor` unchanged. F-032 doesn't change with their composition. |

## Cross-lane staging-race sighting #20

Observed during this lane's GREEN commit attempt.

**RED commit (5980e93)** landed cleanly. Selective `git add tests/unit/F-032-window.test.ts docs/03-feature-catalog/M5-desktop-shell/F-032-window.md docs/09-examples-proof/F-032/red-test-output.txt && git commit` in a single-bash invocation produced a clean 3-file commit.

**GREEN commit attempt** was absorbed by sibling Lane D's commit `ffafb3a` (subject "docs(wave-18-d): audit followups + absolute-paths directive + wave-history line"). 7 files this lane authored — F-032 ledger flip, green-test-output.txt, root package.json, packages/desktop-shell/package.json, packages/desktop-shell/src/index.ts, packages/desktop-shell/src/window.ts, pnpm-lock.yaml — were swept under Lane D's commit message. Same root cause as wave-017 sighting #17(b) and wave-018 sighting #18: the pre-commit hook's scope is broader than the explicit `git add` set when sibling lanes' working-tree modifications exist at hook-execution time.

Per user directive 2026-05-07 (NO `git reset` (any flavor); fix-forward only):
- **Substance preserved**: F-032 6/6 PASS; full unit suite 175/175 across 24 test files; node suite 61/61 across 9 files; re-verified at lane-summary time 236/236 across 33 test files.
- **Credit attribution corrupted** on the GREEN commit (Lane D's commit message claims responsibility for files this lane authored).
- **Provenance restored** via:
  - This lane summary (the canonical record)
  - F-032-window.md ledger §Implementation notes
  - The wave-018/lane-c transition note in roadmap.md
  - The Lane-C-w18-staging-race-sighting-20 entry in confidence-ledger.md

**Pattern is now CHRONIC across waves 9-18** (sightings #14, #15, #16, #17(a)+(b), #18, #19+, #20). The combined-bash mitigation introduced by wave-017's commit `b957489` is TACTICAL — it minimizes (does not eliminate) the race window. **Strategic fix candidates pending council retro at end of wave-18** (carried over from wave-17 lane-d's note + wave-18 lane-b sighting #18 + this Lane C entry):

(a) Per-lane branches when concurrent lane count >= 3
(b) Pre-commit-hook scope-restriction to `git diff --cached --name-only` only (reject any modification to files not in the cached diff)
(c) Per-feature scope manifest at `.mad/wave-N/lane-X/scope.txt` with hook-enforced reject

**Pattern is no longer "occasionally observed" — it is the DEFAULT outcome when 3+ lanes operate concurrently with overlapping working-tree modifications.** Council retro at wave-18 close should escalate from tactical mitigation (combined-bash) to strategic mitigation (one of (a)/(b)/(c)).

## Push status

Push at end of lane authorized for this loop session per user directive 2026-05-07. Per `non-negotiable-rules.md`, no destructive git ops; selective `git add <paths>` only; `git status --short` audit before each commit.

## Reporting metric

- F-032 GREEN: 6/6 PASS
- M5 desktop-shell milestone OPENS (12R+0G -> 11R+1G; first M5 feature transition)
- TOTAL: 98R+5G+24L -> 97R+6G+24L
- 30th feature transition RED -> GREEN in the repo (sequential count after F-138 / F-024 / F-025 / F-026 / F-027 / F-029 / F-030 / F-031)
- First feature in `packages/desktop-shell/` (workspace was scaffolded empty in M0, populated by this lane)
- New ledger-deferral idiom registered: "descriptor-as-data, instantiation-deferred"
- Cross-lane staging-race sighting #20 observed (chronic; strategic fix pending wave-18 retro)

## Commits

| # | Subject | SHA | Status |
|---|---|---|---|
| 1 | `test(F-032): RED — window structural scenarios + ledger flip` | `5980e93` | landed clean |
| 2 | (GREEN) `feat(F-032): GREEN — createMainWindow descriptor + window-state hydration` | absorbed by sibling Lane D's `ffafb3a` per sighting #20 | substance preserved; credit corrupted; provenance restored via this summary + ledger Implementation notes |
| 3 | (this lane summary + roadmap + confidence-ledger updates) | TBD | pending |
