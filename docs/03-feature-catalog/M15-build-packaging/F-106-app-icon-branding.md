---
artifact-class: feature-ledger
generated-by: hand-authored (wave-006 / lane-c)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-006 / lane-c
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-106
short-slug: app-icon-branding
milestone: M15
provenance:
  surfaces:
    - cp:build/icons/
    - cp:packaging
    - cp:electron-builder.yml (icon path config)
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
  LOCKED if GREEN AND reviews/F-106-app-icon-branding-review.md exists with verdict: ACCEPT.
depends-on: [F-104]
out-of-scope-notes: |
  Animated app icons (macOS Sonoma+ feature) are OUT for v1; static icons only.
  Adaptive icons (Linux desktop themes that recolor based on theme) are OUT.
  Per-channel icon variants (different icon for BETA channel installs) is a v1.5
  visual-distinction nicety — v1 ships one icon set across STABLE + BETA.
  Branded splash screen / first-run welcome animations are M5 desktop-shell
  scope, not M15 packaging scope.
confidence: high
---

# F-106 — app icon + branding assets

## Behavior contract

The engine MUST ship platform-correct icon assets bundled into each installer per F-104. Source: a single canonical SVG (or high-resolution PNG) is exported into the platform-specific formats — `icon.icns` (macOS), `icon.ico` (Windows), and `icon.png` (Linux, multiple resolutions: 16, 32, 48, 64, 128, 256, 512). Icon paths are wired into `electron-builder.yml` so packaging picks them up automatically. The icon also appears in the app's window chrome, dock / taskbar entry, system tray (if F-001 wires one), and OS notification surface. Branding metadata (product name "MAD Council", company / publisher string, copyright year) is consistent across all three platforms' installer metadata.

## Acceptance scenarios

1. **Given** a built macOS DMG, **When** the user mounts it and inspects the `.app` bundle in Finder, **Then** the icon shown in Finder + dock + window-title-bar is the canonical MAD Council icon at native retina resolution (no fallback "generic app" icon).
2. **Given** a built Windows NSIS installer, **When** the installer runs and lands the executable, **Then** the icon shown in Explorer + Start menu + taskbar + system tray uses the embedded `icon.ico` resource (multiple sizes), and Windows does not display the default "blank" application icon.
3. **Given** a built Linux AppImage, **When** the user runs it and accepts desktop integration, **Then** the canonical icon appears in the application menu + window-list + alt-tab switcher, sourced from the bundled `icon.png` resolution-set.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/branding/macos-dmg-bundles-icns.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/branding/windows-nsis-bundles-ico.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/branding/linux-appimage-bundles-png.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-104 (electron-builder consumes the icon paths at packaging time)
- **Soft:** F-001 (window chrome + tray surface uses the icon at runtime), M5 desktop-shell (window-title bar branding)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:build/icons/ | canonical icon assets directory layout (icns / ico / png) — clawpilot pattern |
| cp:packaging | clawpilot's branding-asset embedding in electron-builder packaging step |
| cp:electron-builder.yml (icon path config) | wire-up shape: per-platform `icon:` keys pointing to source files |

## Implementation notes

(empty — populated when implementation begins)
