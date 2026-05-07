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
feature-id: F-004
short-slug: vitest-playwright-config
milestone: M0
provenance:
  surfaces:
    - cp:vitest.config.ts
    - cp:playwright.config.ts
    - kit:foundational-plan.md "4-project layout"
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
  LOCKED if GREEN AND reviews/F-004-vitest-playwright-config-review.md exists with verdict: ACCEPT.
depends-on: [F-003]
out-of-scope-notes: |
  Coverage gating thresholds (e.g. ≥90% diff coverage) are enforced by
  F-006 (logging-pipeline) + the feature-eval workflow, not by this feature.
  This feature only configures the runners.
confidence: high
---

# F-004 — Vitest + Playwright configuration

## Behavior contract

The repo carries a 4-project Vitest layout (unit / node / browser / integration) per `vitest.config.ts`, plus a Playwright configuration with `sharedTest` + `test` fixture modes per `playwright.config.ts` (copied from clawpilot patterns). Each Vitest project has its own glob, environment, and setup-files. `npm test` runs all four Vitest projects in parallel; `npm run e2e` runs Playwright. Test files outside the configured globs are NOT picked up — globs are the authoritative discovery mechanism.

## Acceptance scenarios

1. **Given** the four Vitest project configs, **When** `npm test` is run, **Then** Vitest reports "4 projects" and runs each project's test files in parallel.
2. **Given** a test file at `tests/unit/foo.test.ts` and another at `tests/browser/bar.test.ts`, **When** Vitest discovers tests, **Then** `foo.test.ts` runs in `unit` project (Node env) and `bar.test.ts` runs in `browser` project (jsdom env).
3. **Given** a Playwright spec using the `sharedTest` fixture, **When** the spec runs, **Then** the fixture is shared across describes within the file but isolated across files.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/config/vitest-projects.test.ts` | unit | RED | scenarios 1, 2 |
| (TBD) `tests/e2e/config/playwright-fixtures.spec.ts` | e2e | RED | scenario 3 |

## Dependencies

- **Hard:** F-003 (scaffolding must exist before runner configs attach)
- **Soft:** F-005 (deps pinning resolves vitest + playwright versions)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:vitest.config.ts | clawpilot 4-project layout (verbatim copy with rename) |
| cp:playwright.config.ts | clawpilot sharedTest/test fixture modes |
| kit:foundational-plan.md M-1 | "4-project layout copied from `[CP:vitest.config.ts]`" |

## Implementation notes

(empty — populated when implementation begins)
