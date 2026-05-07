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
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
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

(empty — populated when implementation begins)
