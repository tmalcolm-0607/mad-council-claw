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
feature-id: F-108
short-slug: ci-build-pipeline
milestone: M15
provenance:
  surfaces:
    - cp:.github/workflows/
    - cp:packaging
    - kit:rules/quality-gates.md
    - kit:rules/concurrency-safety.md
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
  LOCKED if GREEN AND reviews/F-108-ci-build-pipeline-review.md exists with verdict: ACCEPT.
depends-on: [F-104, F-106, F-107, F-109]
out-of-scope-notes: |
  Self-hosted runners are OUT for v1; GitHub-hosted runners only. macOS arm64
  signing on GitHub-hosted requires the macOS-14+ runner image (verified
  available). Cross-compilation (building Windows on Linux runners) is OUT —
  each platform builds on its native runner image. Nightly / scheduled builds
  are OUT for v1; only tag pushes trigger releases. PR validation runs build
  but skips packaging + signing + publish (cost). Build matrix expansion to
  multiple Node.js versions is OUT — single LTS version per release. ADO
  pipeline mirroring (for Microsoft-internal CI) is v1.5.
confidence: high
---

# F-108 — CI build pipeline

## Behavior contract

The engine MUST build, test, package, sign, and publish artifacts via GitHub Actions on every push of a release tag matching `v*.*.*` (or `v*.*.*-beta.*` for beta channel). The workflow file lives under `.github/workflows/release.yml` and orchestrates a fan-out matrix of three native-platform jobs (macos-latest, windows-latest, ubuntu-latest), each running: checkout → install deps → run tests (per F-001 quality gates) → build engine → run electron-builder per F-104 → sign per F-107 → publish per-platform artifacts to the GitHub Release named after the tag. The CLI binary (F-109) builds in a separate matrix job and publishes to npm + GitHub Release in parallel. PR pushes run a smaller validation matrix (build + test only — no package, sign, or publish) to keep PR-cycle cost bounded.

## Acceptance scenarios

1. **Given** a maintainer pushes tag `v1.0.0`, **When** the release workflow fires, **Then** three platform jobs run in parallel (macos / windows / linux), each produces its installer per F-104, signs it per F-107, and uploads to the `v1.0.0` GitHub Release; the cli-binary job (F-109) publishes to npm in parallel; the workflow finishes green within 30 minutes wall-clock.
2. **Given** a maintainer opens a PR against `main`, **When** CI runs, **Then** the validation workflow runs (build + test on all three OSes) but does NOT execute packaging, signing, or publish steps; PR-cycle wall-clock stays under 10 minutes.
3. **Given** a release-job failure on one platform (e.g., macOS notarization timeout), **When** the workflow completes, **Then** the GitHub Release shows the artifacts that DID upload (Windows + Linux), the failed-platform job is clearly marked failed, and the maintainer can re-run the failed job without re-triggering the successful platforms.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/ci/release-tag-triggers-fan-out.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/ci/pr-validation-skips-publish.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/ci/per-job-failure-isolation.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-104 (CI invokes electron-builder), F-106 (icons present at build time), F-107 (signing happens in CI per F-107 contract), F-109 (CLI binary build matrix runs alongside)
- **Soft:** F-001 (quality gates determine which tests block CI), F-105 (CI publishes the releases auto-update consumes)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:.github/workflows/ | clawpilot's GitHub Actions workflow patterns: matrix shape, secret access, artifact upload |
| cp:packaging | clawpilot's CI-side packaging orchestration (script entrypoints, env-var contract) |
| kit:rules/quality-gates.md | quality-gate contract that determines blocking tests in CI |
| kit:rules/concurrency-safety.md | per-platform jobs run in parallel safely (artifact uploads use atomic-rename semantics) |

## Implementation notes

(empty — populated when implementation begins)
