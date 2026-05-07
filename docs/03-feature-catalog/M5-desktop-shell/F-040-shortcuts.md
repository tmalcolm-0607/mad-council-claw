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
feature-id: F-040
short-slug: shortcuts
milestone: M5
provenance:
  surfaces:
    - cp:electron/show-hide-shortcut.ts
    - cp:electron/show-hide-shortcut.test
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
  LOCKED if GREEN AND reviews/F-040-shortcuts-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-041]
out-of-scope-notes: |
  Per-user keybinding remapping (config UI for changing shortcuts) is v1.5.
  Chord shortcuts (e.g., Ctrl+K Ctrl+S) are v1.5 — v1 ships single-chord only.
  Vim/Emacs keybinding modes are out of scope for v1.
confidence: high
---

# F-040 — Keyboard shortcuts

## Behavior contract

The desktop registers a canonical set of keyboard shortcuts:

| Shortcut | Action |
|---|---|
| `Ctrl/Cmd+N` | Open new-run dialog |
| `Ctrl/Cmd+W` | Close current window (multi-window per F-043) |
| `Ctrl/Cmd+,` | Open preferences |
| `Ctrl/Cmd+K` | Focus the rail filter (per F-033) |
| `Ctrl/Cmd+B` | Toggle left rail visibility |
| `Ctrl/Cmd+I` | Toggle right info panel (per F-034) |
| `Ctrl/Cmd+T` | Toggle theme (light↔dark, ignores `system`) |
| `Ctrl/Cmd+Shift+H` | Show/hide window globally (system-tray helper, per `cp:electron/show-hide-shortcut.ts`) |
| `Esc` | Dismiss focused dialog/dropdown |

Shortcuts are platform-aware: `Cmd` on macOS, `Ctrl` elsewhere. The global show-hide shortcut (`Ctrl/Cmd+Shift+H`) registers OS-wide via Electron's `globalShortcut` API + is unregistered on app quit (no dangling). All shortcuts are listed in the menu bar (per F-041) so they are discoverable; the keybindings are NOT configurable in v1.

## Acceptance scenarios

1. **Given** the desktop focused + the operator pressing `Ctrl/Cmd+N`, **When** the shortcut fires, **Then** the new-run dialog opens + the personality + model pickers are accessible via Tab.
2. **Given** the desktop running in the background (window hidden) + the operator pressing `Ctrl/Cmd+Shift+H` system-wide, **When** the global shortcut fires, **Then** the window shows + comes to focus.
3. **Given** the desktop running + the operator quitting the app, **When** the app exits, **Then** the global show-hide shortcut is unregistered + no dangling OS-level binding remains (verified via OS API check).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/shortcut-new-run.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/integration/desktop/global-show-hide.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/desktop/shortcut-cleanup.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window receives focus changes), F-041 (menu bar lists shortcuts)
- **Soft:** F-039 (toggle-theme shortcut), F-043 (multi-window — close-window shortcut)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/show-hide-shortcut.ts | Global shortcut registration pattern |
| cp:electron/show-hide-shortcut.test | Test for register + cleanup discipline |

## Implementation notes

(empty — populated when implementation begins)
