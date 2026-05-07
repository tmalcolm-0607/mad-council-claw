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
feature-id: F-105
short-slug: auto-update
milestone: M15
provenance:
  surfaces:
    - cp:electron/auto-update.ts
    - cp:auto-update
    - cp:electron-updater dependency pin
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/degradation-fallback-policy.md
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
  LOCKED if GREEN AND reviews/F-105-auto-update-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-104, F-107, F-108]
out-of-scope-notes: |
  Per D-7 (foundational-plan decision), v1 ships with the STABLE channel only as
  the default. The BETA channel is opt-in via the settings plane (M8) — users who
  want pre-release builds explicitly toggle in. Silent / forced auto-update is OUT
  for v1; updates always require user confirmation per
  rules/dangerous-operations-policy.md (an auto-update is a side-effect on the
  user's installed binary). Differential / delta updates are v1.5. Rollback to a
  prior version from the running app is v1.5; v1 users uninstall + reinstall
  the older artifact from GitHub Releases.
confidence: high
---

# F-105 — auto-update

## Behavior contract

The engine MUST check for updates via `electron-updater` against the GitHub Releases feed for the project repo. Per D-7 (foundational-plan), v1 default channel is STABLE — only releases tagged with semver MAJOR.MINOR.PATCH (no pre-release suffix) are picked up. The BETA channel (opt-in via M8 settings) picks up pre-release tags (`-beta.N`). Update checks fire on app launch + every 4 hours while running. When an update is available, the engine notifies the user and requires explicit confirmation before download per `rules/dangerous-operations-policy.md` (modifying installed binaries is a Dangerous Operation). On confirmation, the update downloads in background; install applies on next app restart. Update server failures degrade per `rules/degradation-fallback-policy.md` Rule 3 — surfaced as a Context Gap, never a hard error.

## Acceptance scenarios

1. **Given** an installed engine on STABLE channel (v1.0.0) and a new GitHub Release tagged `v1.0.1`, **When** the engine launches, **Then** the update check fires, the user sees an "Update available: v1.0.1" notification, and no download starts until the user clicks "Install update".
2. **Given** an installed engine on STABLE channel and a new GitHub Release tagged `v1.1.0-beta.1`, **When** the update check runs, **Then** the engine ignores the pre-release tag (STABLE is default per D-7) and surfaces no notification.
3. **Given** an installed engine where the user has opted into BETA via M8 settings, **When** a `v1.1.0-beta.1` release publishes, **Then** the update check picks it up and presents the same explicit-confirmation flow as STABLE.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/auto-update/stable-channel-picks-up-release.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/auto-update/stable-ignores-prerelease.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/auto-update/beta-opt-in-picks-up-prerelease.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine lifecycle owns update-check timing), F-104 (electron-builder produces the update-publish manifest), F-107 (signed installers verify signatures via electron-updater), F-108 (CI publishes releases the updater consumes)
- **Soft:** M8 settings (BETA opt-in toggle), F-015 audit (update events appended to chain)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/auto-update.ts | clawpilot's auto-update orchestration module — channel selection, notification flow, download-confirm gate |
| cp:auto-update | clawpilot's auto-update surface area + electron-updater configuration |
| cp:electron-updater dependency pin | SDK version baseline (matches clawpilot to inherit security + signature-verification track) |
| kit:rules/dangerous-operations-policy.md | binary modification = Dangerous Operation → explicit user "yes" before install |
| kit:rules/degradation-fallback-policy.md | Rule 3: update-server failures surface as Context Gap, never hard error |

## Implementation notes

(empty — populated when implementation begins)
