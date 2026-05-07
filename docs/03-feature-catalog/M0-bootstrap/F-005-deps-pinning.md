---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-005
short-slug: deps-pinning
milestone: M0
provenance:
  surfaces:
    - cp:package-lock.json
    - kit:rules/verification-protocol.md (reproducible builds)
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
  LOCKED if GREEN AND reviews/F-005-deps-pinning-review.md exists with verdict: ACCEPT.
depends-on: [F-003]
out-of-scope-notes: |
  Vulnerability scanning + Dependabot auto-PRs are deferred to M16 (telemetry/CI hardening).
  This feature only enforces pinning + lockfile-presence at install time.
confidence: high
---

# F-005 — Dependency pinning

## Behavior contract

Every direct dependency in every `package.json` carries an exact version (no `^`, `~`, `>=`, or range operators). The repo ships a committed `package-lock.json` (npm) at the root; `npm ci` (NOT `npm install`) is the canonical install path in CI. Mismatched lockfile-vs-package-json fails CI immediately with a clear error. Transitive resolution is reproducible across machines: a fresh `npm ci` on Linux + macOS + Windows produces byte-identical `node_modules/` trees for the locked deps.

## Acceptance scenarios

1. **Given** a `package.json` with `"react": "^18.2.0"`, **When** the deps-pinning gate runs, **Then** the gate fails with `RANGE_OPERATOR_FORBIDDEN: react` and a remediation message.
2. **Given** a committed `package-lock.json` and a fresh `package.json` change that adds a new dep, **When** CI runs `npm ci`, **Then** CI fails with `EUSAGE` (lockfile out of sync) until the developer commits an updated lock.
3. **Given** the repo at HEAD on a clean checkout, **When** `npm ci` is run on Linux + macOS + Windows, **Then** all three produce the same set of installed package versions in `node_modules/`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/deps/no-range-operators.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/deps/lockfile-sync.test.ts` | integration | RED | scenario 2 |

## Dependencies

- **Hard:** F-003 (package.json files must exist to be checked)
- **Soft:** F-004 (vitest/playwright versions are pinned by this feature)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:package-lock.json | clawpilot lockfile commit pattern |
| kit:rules/verification-protocol.md | reproducible-build discipline (ACTUAL BEFORE PRESENT) |

## Implementation notes

(empty — populated when implementation begins)
