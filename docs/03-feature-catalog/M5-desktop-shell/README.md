---
artifact-class: milestone-overview
generated-by: hand-authored (wave-003 / lane-a)
status: red
milestone: M5
short-slug: desktop-shell
features: F-032..F-043
authored: 2026-05-07
---

# M5 — Desktop chat shell

The interactive surface (`foundational-plan.md` § Architecture, V:8 + CP:m-main/). An Electron-based persistent chat shell that surfaces every engine + governance + automation primitive as visible, manipulable UI. M5 is deliberately built ON TOP of M4 (headless CLI) — every desktop feature has a CLI equivalent first; the desktop is sugar on top, not a separate surface with its own contracts. M5 is the "looks like clawpilot" half of the foundational synthesis (`foundational-plan` V/Vision § "Looks like clawpilot, disciplines like canonical-e").

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-032 | window | Electron BrowserWindow; persistent state; sandboxed renderer; preload-mediated IPC; `windowsHide: true` |
| F-033 | history | Multi-session left rail; sorted by last-activity; virtualized at >100 runs; live-updates ≤2s |
| F-034 | info-panel | Right pane: identity + lifecycle + cycle count + chain badge + cost sub-totals + retro; read-only |
| F-035 | model-picker | Dropdown sourced from backend factory's listModels(); tier + cost-per-MToken hints; persists to preferences |
| F-036 | personality | Bundled preset list; selection sets system message; `personality_content_sha256` audit-logged for reproducibility |
| F-037 | system-message | Composed from personality preset + override; immutable post-start; rejects mid-run modification |
| F-038 | primitives | Button/Dialog/Tab/TextField/Toast/Toggle/Badge/Tooltip/ProgressIndicator; keyboard accessible; ARIA-correct; theme-token-only |
| F-039 | theming | Light/dark/system; pre-paint application (no flash); responsive to OS changes ≤1s |
| F-040 | shortcuts | Canonical keymap (Ctrl/Cmd-aware); global show-hide; cleanup on quit |
| F-041 | menu | Native menu bar; shortcuts surfaced in labels; context-aware enable/disable |
| F-042 | notifications | OS-native for halt/complete/chain-break/cron-fail; throttled 5/min; deduped 30s window; persisted to notifications.jsonl |
| F-043 | multi-window | Multiple windows on one engine; per-window state; shared preferences; graceful drain on last close |

## Dependency DAG

```
F-001 (kernel) ──→ F-032 (engine in main process)
F-007 (IPC contract) ──→ F-032 (renderer-main bridge)

F-032 (window) ──→ F-033 (rail), F-034 (info), F-035-F-037 (pickers + msg),
                   F-038 (primitives), F-039 (theming), F-040 (shortcuts),
                   F-041 (menu), F-042 (notifications), F-043 (multi-window)

F-038 (primitives) ──→ F-033, F-034, F-035, F-036, F-041 (consume primitives)
F-039 (theming) ──→ F-038 (token consumers)

F-036 (personality) ──→ F-037 (composes system message)
F-035 (model-picker) ──→ F-009 + F-012 (backend listModels source)
F-034 (info-panel) ──→ F-015 (chain badge), F-019 (cost sub-totals), F-014 (retro summary)
F-040 (shortcuts) ──→ F-041 (menu shows them), F-039 (toggle-theme), F-043 (close-window)
F-042 (notifications) ──→ F-018 (halt triggers), F-020 (kill-switch), F-019 (cost), F-015 (chain-break), F-023 (cron-fail)
F-043 (multi-window) ──→ F-031 (reconnect to daemon)
F-033 (history rail) ──→ F-019 (cost-ledger total per entry), F-008 (runs + archive paths)

F-021 (degradation) ──→ F-034 (Context Gap on missing data), F-035 (cached model list on transport down)
```

## Milestone exit criteria

- All 12 ledgers GREEN
- A fresh launch on Windows + macOS + Linux opens the window without theme flash
- Left rail virtualizes at 500 runs without jank
- Info panel re-verifies audit chain on demand + shows red badge + banner when broken
- Model picker enumerates models from the active backend factory (per F-012)
- Personality preset selection produces a run whose audit log carries `personality_content_sha256`
- System message rejects mid-run modification with `SYSTEM_MESSAGE_IMMUTABLE`
- All UI primitives carry `.telemetry.test.tsx` companion + zero-error report
- Theme toggle ≤1s with no full-window reload
- All shortcuts in the keymap activate the documented action
- Menu bar shows shortcut next to each item; context-aware items enable/disable correctly
- Notification fires on halt + click focuses the run in the rail
- Three windows open + close two: engine main process stays alive

## Out of scope (tracked elsewhere)

- Skill marketplace + custom-load + 3-tier perms → M7 (F-051..F-066)
- Live trace timeline + step-by-step replay scrubber → M11 (F-088..F-092)
- Tabbed-window UI (multiple runs in one window) → v1.5
- User-customizable themes (BYO palette) → v1.5
- Per-user keybinding remapping → v1.5
- Chord shortcuts → v1.5
- High-contrast accessibility theme → v1.5
- System tray icon + tray menu → v1.5
- Push notifications via remote service → out of scope for v1
- Personality marketplace / import-from-URL → out of scope for v1
- Workspace-style saved window layouts → v1.5

## Provenance

`foundational-plan:CP:m-main/` (persistent Electron chat shell), `foundational-plan:V:8` (BOTH UI surfaces), `cp:src/main/index.ts` + `cp:electron/` + `cp:src/features/` (clawpilot patterns), `cp:src/features/chat/components/{ChatInput,ChatMessage,DefaultModelPicker,PersonalityPicker,HorizonPanel}.tsx`, `cp:electron/{theme.ts,theme-flash-prevention.test.ts,show-hide-shortcut.ts,ipc/personality-ipc.ts}`, `kit:rules/{verification-protocol,canonical-skill-only,model-selection,dangerous-operations-policy,degradation-fallback-policy}.md`. Per-ledger `provenance.surfaces`.
