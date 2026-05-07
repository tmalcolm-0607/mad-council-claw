---
artifact-class: milestone-overview
generated-by: hand-authored (wave-006 / lane-c)
status: red
milestone: M15
short-slug: build-packaging
features: F-104..F-109
authored: 2026-05-06
---

# M15 — Build / packaging / distribution

The shipping plane. Once the engine works (M0..M11) and the desktop shell renders it (M5), this milestone makes it land on a user's machine: per-platform installers (electron-builder), an auto-update channel (STABLE-default per D-7, BETA opt-in), branding assets, code-signing, a CI pipeline that fans out per platform on tag push, and a parallel CLI binary distribution.

This milestone consumes everything upstream and produces the artifacts users actually run. It is the load-bearing surface for "engine ships as installable binaries on macOS / Windows / Linux + a CLI for headless use" per the foundational-plan distribution goal.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-104 | electron-builder-pkg | macOS DMG (universal) + Windows NSIS + Linux AppImage; outputs land in `dist/` |
| F-105 | auto-update | electron-updater against GitHub Releases; D-7 default = STABLE only; BETA opt-in via M8 |
| F-106 | app-icon-branding | platform icons (icns / ico / png) embedded at packaging time; consistent branding metadata |
| F-107 | code-signing | macOS Developer ID + notarization; Windows Authenticode + timestamp; Linux GPG; signing in CI only; cert sourcing TBD |
| F-108 | ci-build-pipeline | GitHub Actions release.yml; per-platform fan-out on tag push; PR validation skips publish |
| F-109 | cli-binary-pkg | standalone Node binary via pkg/yao-pkg; npm publish + GitHub Releases; lockstep with desktop |

## Dependency DAG

```
M0 (F-001 kernel, F-008 storage) ──→ all M15 features

F-104 (electron-builder)  ──┬──→ F-105 (auto-update wraps the published artifacts)
                            ├──→ F-106 (icons embed at packaging time)
                            ├──→ F-107 (signing wraps unsigned builder output)
                            └──→ F-108 (CI orchestrates electron-builder runs)

F-106 (icons)             ──→ F-104 (consumed at packaging time)
F-107 (signing)           ──→ F-105 (signed artifacts feed updater signature verification)
F-107 (signing)           ──→ F-108 (signing happens in CI only; cert in CI secrets)
F-108 (CI)                ──→ F-105 (CI publishes the releases auto-update consumes)
F-108 (CI)                ──→ F-109 (CLI binary builds + publishes in parallel matrix job)
F-109 (CLI)               ──→ M4 (CLI exposes the headless command surface from M4)
M8 settings              ──→ F-105 (BETA opt-in toggle)
F-015 audit              ──→ F-105 (update events appended to chain)
```

## Milestone exit criteria

- All 6 ledgers GREEN
- A tag push on a feature branch (e.g. `v1.0.0-beta.1`) triggers the GitHub Actions matrix and lands signed installers on the GitHub Release within 30 minutes
- macOS DMG passes Gatekeeper (signed + notarized); Windows NSIS passes SmartScreen (Authenticode + timestamp); Linux AppImage GPG signature verifies
- electron-updater on STABLE channel ignores `-beta.*` tags by default; toggling BETA in M8 settings picks them up
- All three desktop platforms produce installers under one CI workflow run; CLI binary publishes to npm + GitHub Releases in the same workflow
- Per-job failure in CI does not block successful platforms from publishing their artifacts
- App icons render at native resolution on all three platforms (no fallback "generic app" icon)
- `npm install -g mad-council-cli@<version>` matches the desktop release version 1:1

## Out of scope (tracked elsewhere)

- MSI installer (Windows enterprise / Group Policy distribution) — v1.5
- Snap / Flatpak Linux packaging — v1.5
- Mac App Store distribution — explicitly OUT (sandboxing breaks F-076 deep-link)
- Differential / delta auto-update — v1.5
- Rollback to prior version from running app — v1.5
- Animated app icons (macOS Sonoma+) / adaptive Linux icons / per-channel icon variants — v1.5
- Hardware-backed signing keys (HSM / YubiKey) — v1.5
- Reproducible builds — v1.5
- Self-hosted CI runners — v1.5; v1 = GitHub-hosted only
- Cross-compilation (e.g. building Windows on Linux) — v1 builds each platform on its native runner
- Nightly / scheduled builds — v1 = tag-push only
- Multiple Node.js version matrix — v1 = single LTS
- ADO pipeline mirroring (Microsoft-internal CI) — v1.5
- Homebrew / winget / chocolatey / apt / dnf / pacman CLI distribution — v1.5
- Native Deno / Bun runtime targets for CLI — OUT
- CLI self-update (mirror of F-105 for desktop) — v1.5

## Provenance

`cp:packaging` (clawpilot's full packaging surface), `cp:electron-builder.yml`, `cp:electron/auto-update.ts`, `cp:auto-update`, `cp:.github/workflows/`, `cp:build/icons/`, `cp:package.json` (build scripts + bin field), `cp:electron-updater` dependency pin, `kit:rules/dangerous-operations-policy.md` (F-105 binary modification + F-107 cert handling), `kit:rules/degradation-fallback-policy.md` (F-105 update-server failures = Context Gap), `kit:rules/quality-gates.md` (F-108 blocking-test contract), `kit:rules/concurrency-safety.md` (F-108 parallel-platform artifact uploads), `kit:rules/single-owner-accountability.md` (F-107 cert ownership), `kit:rules/no-silent-deferrals.md` (F-104 / F-109 v1.5 deferrals explicit), `foundational-plan.md` D-7 (STABLE channel default; BETA opt-in). Per-ledger `provenance.surfaces`.
