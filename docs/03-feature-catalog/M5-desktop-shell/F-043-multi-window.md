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
feature-id: F-043
short-slug: multi-window
milestone: M5
provenance:
  surfaces:
    - cp:electron/ (multi-window pattern)
    - foundational-plan:CP:m-main/ (persistent Electron chat shell — extended)
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
  LOCKED if GREEN AND reviews/F-043-multi-window-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-007]
out-of-scope-notes: |
  Tabbed-window UI (multiple runs in one window via tabs) is v1.5.
  Window-state-sync between windows (e.g., theme change in one syncs to all) IS in v1
  via shared preferences; UI-state sync (which run selected in each window) is NOT.
  Workspace-style window arrangement (saved layouts) is v1.5.
confidence: high
---

# F-043 — Multi-window

## Behavior contract

The desktop supports opening multiple BrowserWindow instances against the same engine state-dir. Each window is independent in selection state (which run is selected, which panels open) but shares: the engine main process (one daemon per state-dir), preferences (theme, model picker default), and notification queue. Opening a new window: from File menu (`Ctrl/Cmd+Shift+N`), from a rail entry's right-click "Open in New Window" (v1.5 right-click → use the menu in v1), or programmatically via IPC. Window-state persistence (per F-032) is per-window-id stored in `<state-dir>/desktop/windows/<window-id>.json`. Closing the LAST window quits the app gracefully, draining IPC + flushing audit + cost ledgers — never abrupt termination.

## Acceptance scenarios

1. **Given** an active desktop window + invocation of "New Window" from the File menu, **When** the new window opens, **Then** it inherits theme + model preferences but starts with no run selected + has its own window-state file.
2. **Given** 3 windows open + the user closing 2, **When** only 1 window remains, **Then** the engine main process stays alive (daemon-mode behavior) + the remaining window functions normally.
3. **Given** 1 window open + the user closing it, **When** the close fires, **Then** the engine drains pending IPC (≤5s grace) + flushes audit + cost-ledger writers + the daemon (if running per F-031) continues separately + the desktop process exits cleanly.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/desktop/multi-window-open.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/desktop/multi-window-shared-engine.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/desktop/multi-window-graceful-quit.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (single window — multi extends it), F-007 (IPC contract — must support multiple renderer subscriptions)
- **Soft:** F-031 (daemon mode — windows reconnect to the daemon's IPC)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/ | Multi-window registry + shared-main-process pattern |
| foundational-plan:CP:m-main/ | "persistent Electron chat shell" — extended to N concurrent windows |

## Implementation notes

(empty — populated when implementation begins)
