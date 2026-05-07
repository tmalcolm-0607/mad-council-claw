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
feature-id: F-109
short-slug: cli-binary-pkg
milestone: M15
provenance:
  surfaces:
    - cp:packaging
    - cp:package.json (bin field; cli build script)
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
  LOCKED if GREEN AND reviews/F-109-cli-binary-pkg-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-108]
out-of-scope-notes: |
  Homebrew tap publication is OUT for v1; users install via npm or download
  raw binary from GitHub Releases. winget / chocolatey distribution is OUT
  for v1. Linux package-manager distribution (apt, dnf, pacman) is OUT —
  npm + GitHub Releases tarball cover v1's Linux CLI distribution. Native
  binary compilation via pkg / nexe / @yao-pkg/pkg (single-file standalone
  Node binary with no Node runtime dependency) is the v1 baseline; ESM-only
  packaging targets (Deno / Bun runtimes) are OUT. Self-update for the CLI
  binary (mirror of F-105 for desktop) is v1.5; v1 CLI users update via
  `npm update -g mad-council-cli` or re-download.
confidence: high
---

# F-109 — CLI binary packaging

## Behavior contract

The engine MUST publish a standalone CLI binary alongside the desktop installers, distributed via two channels: (1) npm as `mad-council-cli` (semver-versioned, semver-tagged stable / beta), installable via `npm install -g mad-council-cli`; (2) GitHub Releases as platform-specific standalone binaries (no Node.js runtime required) — `mad-council-cli-{macos,linux,win}-{x64,arm64}` — built via a single-file packager (pkg or @yao-pkg/pkg). The CLI exposes the engine's headless surface (per M4) for CI / scripting / power-user contexts where the desktop shell is unwanted. Both channels publish in lockstep with the desktop release per F-108. Version output (`mad-council --version`) reports the same semver as the desktop release for traceability.

## Acceptance scenarios

1. **Given** a published v1.0.0 release, **When** a user runs `npm install -g mad-council-cli@1.0.0`, **Then** the CLI installs to the user's npm global bin, `mad-council --version` returns `1.0.0`, and `mad-council --help` lists the headless command surface from M4.
2. **Given** a published v1.0.0 release, **When** a user downloads `mad-council-cli-macos-arm64` from the GitHub Release page and `chmod +x` it, **Then** the binary runs standalone (no Node.js installed required), `--version` returns `1.0.0`, and the binary file size is under 100 MB.
3. **Given** a desktop release fires per F-108, **When** the npm publish job runs, **Then** the CLI binary publishes within the same workflow run (parallel matrix job), and `npm view mad-council-cli versions` shows the new version within 5 minutes of the desktop GitHub Release going live.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cli-pkg/npm-install-global.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/cli-pkg/standalone-binary-runs.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/cli-pkg/lockstep-with-desktop-release.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel + headless surface from M4 must build cleanly), F-108 (CI orchestrates parallel CLI publish)
- **Soft:** F-107 (CLI binary signed alongside desktop installers when cert path covers Node single-file binaries), F-105 (CLI auto-update is v1.5 — not depended on for v1)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:packaging | clawpilot's packaging surface area patterns generalized to CLI single-file binary output |
| cp:package.json (bin field; cli build script) | wire-up shape: `bin` field for npm CLI exposure; `build:cli` script for standalone binary |
| kit:rules/no-silent-deferrals.md | v1.5 deferrals (homebrew, winget, apt, deno, bun, self-update) are explicit in `out-of-scope-notes` |

## Implementation notes

(empty — populated when implementation begins)
