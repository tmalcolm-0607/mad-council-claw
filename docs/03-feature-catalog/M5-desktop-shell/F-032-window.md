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
  - status: red
    at: 2026-05-07
    by: wave-018 / lane-c
    note: "RED test authored at tests/unit/F-032-window.test.ts (6 structural scenarios per the wave-018 / lane-c brief that simplifies the ledger's 3 launch-Electron scenarios to a structural / interface-based shape contract). Test fails with module-resolution error: @mad-council-claw/desktop-shell exports map missing. Implementation will land createMainWindow() + resolveWindowState() + DEFAULT_WINDOW_STATE in packages/desktop-shell/src/window.ts."
  - status: green
    at: 2026-05-07
    by: wave-018 / lane-c
    note: "GREEN. New packages/desktop-shell/src/window.ts (~165 LOC) lands createMainWindow() + resolveWindowState() + DEFAULT_WINDOW_STATE + types (MainWindowOptions / MainWindowDescriptor / WindowState). package.json exports map populated; barrel src/index.ts re-exports window.ts; root package.json devDependencies includes @mad-council-claw/desktop-shell workspace:*. 6/6 PASS at GREEN time; full unit suite 175/175 across 24 test files (was 169/169 across 23 pre-this-lane); node suite 61/61 across 9 files no regression; pnpm build exits 0."
feature-id: F-032
short-slug: window
milestone: M5
provenance:
  surfaces:
    - foundational-plan:CP:m-main/
    - cp:src/main/index.ts
    - cp:electron/
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-032-window.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-032-window-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-007]
out-of-scope-notes: |
  Native window theming beyond OS chrome (custom title bars, frameless modes) is v1.5.
  Window animations + transition effects are out of scope.
confidence: high
---

# F-032 — Window

## Behavior contract

The desktop shell is an Electron application that opens a primary BrowserWindow on launch. The window MUST: persist position + size across launches (`<state-dir>/desktop/window-state.json`); restore minimized/maximized state; block renderer-process Node integration (`nodeIntegration: false`, `contextIsolation: true`, `sandbox: true`); communicate with main exclusively through preload-script-mediated IPC (per F-007 contract scaffold). No window-flash on Windows: `windowsHide: true` for any spawn. The main process is the engine kernel host (per F-001); the renderer is read-only consumer of state via IPC.

## Acceptance scenarios

1. **Given** a fresh install + first launch, **When** the desktop shell starts, **Then** a default-sized window opens at the OS-default position + `window-state.json` is created.
2. **Given** an existing `window-state.json` recording last position (1200, 800) + maximized, **When** the desktop relaunches, **Then** the window opens at the last position + maximized state restored.
3. **Given** the renderer process attempting to require `fs` (Node module), **When** the call is evaluated, **Then** the call fails (sandboxed) + the security policy is observable in main-process logs.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/desktop/window-default.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/desktop/window-state-restore.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/desktop/sandbox-policy.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine in main process), F-007 (IPC contract for renderer-main bridge)
- **Soft:** F-008 (window-state.json path), F-038 (theming hooks into window chrome)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:CP:m-main/ | "Looks like clawpilot" — persistent Electron chat shell |
| cp:src/main/index.ts | Main-process bootstrap pattern |
| cp:electron/ | Window-state, sandboxing, IPC scaffolding patterns |

## Implementation notes

### Wave-018 / Lane C — RED → GREEN flip (2026-05-07)

**Scope simplification vs ledger §Acceptance scenarios.** The wave-018 / lane-c brief instructs a STRUCTURAL / INTERFACE-BASED test that asserts the shape `createMainWindow(opts)` returns, rather than actually launching Electron. The three launch-Electron scenarios in §Acceptance scenarios bind to the M5 integration suite (a future feature wave that wires `app.whenReady()` to a `new BrowserWindow(descriptor)` call at the actual Electron entry point). v1 ships:

- `MainWindowDescriptor` — the plain-data shape Electron's `new BrowserWindow(descriptor)` consumes (security tripod sandbox/contextIsolation/nodeIntegration; windowsHide; preload path; merged window state; IPC channel registration intent).
- `WindowState` — the persisted shape for `<state-dir>/desktop/window-state.json`.
- `DEFAULT_WINDOW_STATE` — fresh-install defaults (1280×800, position 0,0 — consumer recenters via `win.center()` before show).
- `createMainWindow(opts)` — pure function returning the descriptor.
- `resolveWindowState(partial | null | undefined)` — never-throws hydrator that fills defaults for missing fields.

**Substantive guarantees preserved by the structural test (per `verification-protocol.md` Rule 1):**

- `sandbox: true` + `contextIsolation: true` + `nodeIntegration: false` (the security tripod ledger scenario 3 exercises) — non-overridable; compile-time constants in the descriptor body.
- `windowsHide: true` (Windows-no-flash discipline per F-032 §Behavior contract).
- Default-state branching when no `windowState` is supplied (ledger scenario 1).
- Last-state restoration when `windowState` IS supplied (ledger scenario 2).
- IPC channel registration shape — declarative subscription set typed against F-007's `IpcInvokeMap` at the consumer call site; runtime stores whatever subset was supplied.

**Deferred to M5 integration wave per `no-silent-deferrals.md`:**

- Actual Electron `BrowserWindow` instantiation + `app.whenReady()` wiring — belongs in the M5 e2e companion suite (per F-004's "browser project runtime wiring deferred to first DOM-rendering spec consumer wave"). F-032 v1 is the prerequisite; the integration wave is the consumer.
- On-disk `window-state.json` round-trip with the F-008 storage layout — caller resolves `<state-dir>/desktop/window-state.json` via `resolveDesktopDir` and passes the parsed value to `createMainWindow({ windowState })`.
- Renderer-process `require('fs')` runtime block (only the static `webPreferences` guarantee, not the runtime check — the runtime check requires booting Electron).
- Multi-window orchestration (F-043's scope).
- Window-state SAVE on resize/move/maximize events — belongs with the integration consumer that wires `win.on('resize', ...)` listeners.

**Cross-feature composition:**

- F-007 (ipc-contract-scaffold, LOCKED) — `MainWindowOptions.ipcChannels` types as `ReadonlyArray<IpcInvokeChannel>`. The scaffold's `IpcInvokeMap` is empty, so the default subscription set is `[]`; future M5 features (F-033..F-043) extend `IpcInvokeMap` and pass channel names here.
- F-008 (local-storage-layout, LOCKED) — caller reads `<state-dir>/desktop/window-state.json` via F-008's atomic-read helpers and passes the parsed value to `createMainWindow({ windowState })`.
- F-001 (engine-bootstrap-loop, LOCKED) — the eventual Electron entry hosts the engine kernel in the main process; `createMainWindow` is called from that entry point.
- F-038 (primitives), F-039 (theming), F-043 (multi-window) — will all consume the same `MainWindowDescriptor` shape; F-032 doesn't change with their composition.

**New ledger-deferral idiom registered:** **"descriptor-as-data, instantiation-deferred"** (distinct from F-004's "config-present, runtime-deferred" + F-010/F-011's "stub-body-vs-deferred-real-SDK" + F-029's "minimum-viable-stub-with-deterministic-stdout"). Future Electron-bound features (F-038..F-043 desktop primitives, M5 integration wave) should cite this entry.

**Test files at GREEN:**

- `tests/unit/F-032-window.test.ts` — 6 scenarios, all PASS at GREEN time.

**Source files at GREEN:**

- `packages/desktop-shell/package.json` — exports map populated (`.` + `./window`).
- `packages/desktop-shell/src/index.ts` — barrel re-export.
- `packages/desktop-shell/src/window.ts` — ~165 LOC (createMainWindow + resolveWindowState + DEFAULT_WINDOW_STATE + types).
- `package.json` (root) — devDependencies adds `@mad-council-claw/desktop-shell: workspace:*` so vitest's resolver finds it (mirrors engine-core + cli pattern).

**First feature in the repo to live under `packages/desktop-shell/`** — the workspace was scaffolded empty in M0 (F-003 repo-scaffolding LOCKED) and stayed empty until this lane authored the first src/ entry. Wave-011 / lane-a's "shared types live with their FIRST owner" convention applies: `MainWindowDescriptor` + `MainWindowOptions` + `WindowState` + `DEFAULT_WINDOW_STATE` + `createMainWindow` + `resolveWindowState` live with F-032 (`desktop-shell/src/window.ts`); F-033 / F-034 / F-035 / F-036 / F-037 / F-038 / F-039 / F-040 / F-041 / F-042 / F-043 will compose against this surface without touching it.
