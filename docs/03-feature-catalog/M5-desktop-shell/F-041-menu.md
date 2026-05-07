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
feature-id: F-041
short-slug: menu
milestone: M5
provenance:
  surfaces:
    - cp:electron/ (menu pattern)
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
  LOCKED if GREEN AND reviews/F-041-menu-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-040]
out-of-scope-notes: |
  Context (right-click) menus on individual rail entries are v1.5.
  Custom menu items contributed by skills (a-la VSCode contributions) are v1.5.
  System tray icon + tray menu is v1.5 — global shortcut (per F-040) is the v1 path.
confidence: high
---

# F-041 — Menu bar

## Behavior contract

The desktop application registers a native menu bar (macOS top bar; Windows/Linux window-bar). Menu structure:

- **App / File**: New Run (`Ctrl/Cmd+N`), Preferences (`Ctrl/Cmd+,`), Quit
- **Edit**: Cut, Copy, Paste, Select All (standard system roles)
- **View**: Toggle Left Rail (`Ctrl/Cmd+B`), Toggle Info Panel (`Ctrl/Cmd+I`), Toggle Theme (`Ctrl/Cmd+T`), Reload (only in dev builds)
- **Run**: Halt Selected Run, Verify Audit Chain, Open Run Directory in File Explorer
- **Help**: Documentation (opens external URL), Keyboard Shortcuts Reference, About

Each menu item displays the matching shortcut from F-040 (so shortcuts are discoverable). Menu items respect run-context state — "Halt Selected Run" is greyed out if no run is selected or selected run is already closed. The menu is built at app start in main process; renderer-process triggers are routed via IPC (per F-007 contract scaffold).

## Acceptance scenarios

1. **Given** a fresh desktop launch, **When** the menu bar renders, **Then** all top-level menus are present + "Toggle Theme" shows `Ctrl/Cmd+T` next to its label.
2. **Given** no run selected in the rail, **When** the user opens the Run menu, **Then** "Halt Selected Run" is disabled (greyed) + "Open Run Directory" is disabled.
3. **Given** an active run selected + the user invoking "Verify Audit Chain" from the menu, **When** the action fires, **Then** the F-015 verification runs + the result is shown via Toast (per F-038 primitive) + the info panel's chain badge updates.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/desktop/menu-presence.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/browser/desktop/menu-context-aware.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/integration/desktop/menu-verify-chain.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window with menu attachment), F-040 (shortcuts surfaced in menu labels)
- **Soft:** F-015 (audit-chain verification action), F-038 (Toast primitive for action results)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/ | Native menu construction pattern |

## Implementation notes

(empty — populated when implementation begins)
