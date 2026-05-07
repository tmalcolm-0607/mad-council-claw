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
feature-id: F-104
short-slug: electron-builder-pkg
milestone: M15
provenance:
  surfaces:
    - cp:electron-builder.yml
    - cp:package.json (build scripts: build:mac, build:win, build:linux)
    - cp:packaging
    - kit:rules/no-silent-deferrals.md
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
  LOCKED if GREEN AND reviews/F-104-electron-builder-pkg-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-106]
out-of-scope-notes: |
  MSI installer (Windows enterprise deployment) is OUT for v1; NSIS-only.
  v1.5 considers MSI when enterprise customers request Group Policy distribution.
  Snap / Flatpak Linux packaging is OUT — AppImage covers v1's "single-file Linux"
  requirement. Mac App Store distribution is OUT (sandboxing constraints conflict
  with deep-link redirect URI handler from F-076). Per-architecture matrix
  (x64 vs arm64) is in scope; universal mac binary is in scope.
confidence: high
---

# F-104 — electron-builder packaging

## Behavior contract

The engine MUST produce installable artifacts for all three desktop platforms via `electron-builder` configured in `electron-builder.yml`. Outputs: macOS DMG (universal binary, x64 + arm64), Windows NSIS installer (x64 + arm64), Linux AppImage (x64 + arm64). Build scripts in `package.json` (`build:mac`, `build:win`, `build:linux`, `build:all`) drive electron-builder per platform. Artifacts include the engine's runtime assets (per F-008 storage layout), embedded MAD kit, and platform-specific icons + metadata (per F-106). The packaging step does NOT include code-signing (F-107) or auto-update wiring (F-105) — those are layered on top in their own ledgers. Build outputs land in `dist/` with predictable filenames so CI (F-108) can find + upload them.

## Acceptance scenarios

1. **Given** a clean checkout on macOS, **When** `pnpm build:mac` runs, **Then** `dist/MAD-Council-{version}-universal.dmg` exists, opens cleanly in Finder, mounts as an installable app, and the dragged `.app` launches the engine without unsigned-binary OS warnings beyond the expected first-run quarantine prompt.
2. **Given** a clean checkout on Windows, **When** `pnpm build:win` runs, **Then** `dist/MAD-Council-Setup-{version}.exe` (NSIS) exists, runs the installer wizard, installs to `%LOCALAPPDATA%\Programs\MAD-Council\`, creates Start menu + desktop shortcuts, and registers the `ms-mad-council://` deep-link protocol per F-076.
3. **Given** a clean checkout on Linux, **When** `pnpm build:linux` runs, **Then** `dist/MAD-Council-{version}.AppImage` exists, has executable permissions, runs portably without install (no system packages added), and registers desktop integration when prompted.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/packaging/macos-dmg-builds.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/packaging/windows-nsis-builds.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/packaging/linux-appimage-builds.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel must build cleanly before packaging), F-008 (storage layout determines which assets ship in the bundle), F-106 (platform icons embedded at packaging time)
- **Soft:** F-107 (code-signing layered on signed installers), F-108 (CI orchestrates per-platform builds), F-105 (auto-update wires into electron-builder's update channel)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron-builder.yml | electron-builder configuration shape: targets per platform, file globs, output filename templates |
| cp:package.json (build scripts) | per-platform build script entrypoints (`build:mac`, `build:win`, `build:linux`, `build:all`) |
| cp:packaging | clawpilot's packaging surface area: NSIS template, DMG layout, AppImage entrypoint script |
| kit:rules/no-silent-deferrals.md | v1.5 deferrals (MSI, Snap, Flatpak, Mac App Store) are explicit in `out-of-scope-notes`, not silent drops |

## Implementation notes

(empty — populated when implementation begins)
