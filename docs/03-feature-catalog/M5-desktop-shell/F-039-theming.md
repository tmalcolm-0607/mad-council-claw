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
feature-id: F-039
short-slug: theming
milestone: M5
provenance:
  surfaces:
    - cp:electron/theme.ts
    - cp:electron/theme-flash-prevention.test.ts
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
  LOCKED if GREEN AND reviews/F-039-theming-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-038]
out-of-scope-notes: |
  User-customizable themes (BYO palette via JSON) is v1.5.
  High-contrast accessibility theme is v1.5 — light + dark + system are v1.
  Theme animations (smooth color transitions on switch) are out of scope for v1.
confidence: high
---

# F-039 — Theming (light/dark + flash prevention)

## Behavior contract

The desktop supports three themes: `light`, `dark`, `system` (follows OS). Theme choice persists in `<state-dir>/desktop/preferences.json:theme`. All UI primitives (per F-038) consume color via design tokens — no hardcoded hex values outside the token system. Theme switching takes effect immediately without window reload. CRITICAL: NO theme flash on launch — the main process reads the preference + applies the theme to the BrowserWindow's background BEFORE the renderer's first paint (per `cp:electron/theme.ts` pattern). System theme follows OS dark/light mode + responds to OS-level changes within ≤1s.

## Acceptance scenarios

1. **Given** preference set to `theme: dark` + the desktop launching, **When** the window first paints, **Then** the dark theme is active from frame 1 (no light-theme flash) — verified via screenshot at first-paint time.
2. **Given** an active session in light theme + the user toggling to dark via preferences, **When** the toggle fires, **Then** all primitives re-render in dark colors + no full-window reload occurs + the change persists for next launch.
3. **Given** preference set to `theme: system` + the user changing OS dark/light mode while the desktop is open, **When** the OS broadcasts the change, **Then** the theme follows within ≤1s without user intervention.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/desktop/theme-no-flash.test.ts` | integration | RED — screenshot-based assertion | scenario 1 |
| (TBD) `tests/browser/desktop/theme-toggle-live.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/integration/desktop/theme-system-follow.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window background applied pre-paint), F-038 (primitives consume tokens)
- **Soft:** F-040 (shortcuts can include theme-toggle binding)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/theme.ts | Pre-paint theme application pattern |
| cp:electron/theme-flash-prevention.test.ts | Test pattern for flash-prevention assertion |

## Implementation notes

(empty — populated when implementation begins)
