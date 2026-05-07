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
feature-id: F-107
short-slug: code-signing
milestone: M15
provenance:
  surfaces:
    - cp:packaging
    - cp:electron-builder.yml (codeSign / sign / certificateFile config)
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/single-owner-accountability.md
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
  LOCKED if GREEN AND reviews/F-107-code-signing-review.md exists with verdict: ACCEPT.
depends-on: [F-104, F-108]
out-of-scope-notes: |
  Certificate sourcing is TBD pending decision: (a) Microsoft-internal cert via
  Engineering-Hub corporate signing service vs (b) external EV cert procured for
  this project vs (c) ad-hoc dev cert (signed but not trusted by OS by default).
  Decision is a triage-gate item for the M15 implementation wave; v1 ships
  whichever path lands first. Notarization (macOS) is in scope when cert path
  is decided. Hardware-backed signing keys (HSM / YubiKey) are v1.5 hardening.
  Signing on developer workstations (vs CI-only) is OUT — signing happens in
  CI only per F-108, with cert material accessed from CI secret storage.
  Reproducible builds (bit-identical output across machines) is v1.5.
confidence: high
---

# F-107 — code signing

## Behavior contract

The engine MUST distribute signed installers in the STABLE channel so OS-level smart-screen / gatekeeper / quarantine prompts do not block first-run installation. Per platform: macOS DMG + `.app` are signed with a Developer ID certificate AND notarized via Apple's notarization service (notarization staple embedded in the DMG); Windows NSIS installer + bundled `.exe` are signed with an Authenticode certificate (timestamped); Linux AppImage is GPG-signed (best-effort — Linux has no OS-level enforcement, but the signature is published alongside the artifact for users who verify). Signing happens in CI only per F-108; cert material is sourced from CI secret storage and never lands on developer workstations. Unsigned dev builds remain possible locally for development, marked clearly in their version string (`-dev` suffix).

## Acceptance scenarios

1. **Given** a published v1.0.0 release on STABLE channel, **When** a macOS user downloads + opens the DMG, **Then** Gatekeeper accepts the signature + notarization staple, the `.app` launches without the "downloaded from internet" warning escalating to a blocker, and `codesign --verify --deep --strict /Applications/MAD-Council.app` returns success.
2. **Given** a published v1.0.0 release on STABLE channel, **When** a Windows user downloads + runs the NSIS installer, **Then** SmartScreen does not display "Windows protected your PC" (publisher is recognized), the signature is valid + timestamped, and `signtool verify /pa /v MAD-Council-Setup-1.0.0.exe` returns success.
3. **Given** a published v1.0.0 release on STABLE channel, **When** a Linux user downloads the AppImage AND the published `.AppImage.sig` next to it, **Then** `gpg --verify MAD-Council-1.0.0.AppImage.sig MAD-Council-1.0.0.AppImage` returns a valid signature against the published public key.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/code-signing/macos-codesign-and-notarize.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/code-signing/windows-authenticode-verify.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/code-signing/linux-appimage-gpg-verify.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-104 (signing wraps the unsigned electron-builder output), F-108 (CI is where signing executes; cert material lives in CI secret storage)
- **Soft:** F-105 (signed installers feed auto-update; electron-updater verifies signatures on update download)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:packaging | clawpilot's signing surface area + per-platform signing-step orchestration |
| cp:electron-builder.yml (codeSign / sign / certificateFile config) | wire-up shape for cert sourcing + notarization flags |
| kit:rules/dangerous-operations-policy.md | cert material is high-consequence; access requires owner-tier authorization in CI |
| kit:rules/single-owner-accountability.md | signing-cert ownership is single-owner-accountable per the cert authority's rules |

## Implementation notes

(empty — populated when implementation begins)
