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
feature-id: F-003
short-slug: repo-scaffolding
milestone: M0
provenance:
  surfaces:
    - cp:package.json
    - cp:tsconfig.json
    - cp:packages/
    - kit:foundational-plan.md M-1 contents
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
  LOCKED if GREEN AND reviews/F-003-repo-scaffolding-review.md exists with verdict: ACCEPT.
depends-on: []
out-of-scope-notes: |
  CI workflow files (.github/workflows/ci.yml, feature-eval.yml) are tracked
  by F-006 (logging-pipeline) for log aggregation and the wave-002 self-improvement
  scaffolding. Code signing + electron-builder packaging deferred to M15 (F-104+).
confidence: high
---

# F-003 — Repo scaffolding

## Behavior contract

The repository follows a 3-package monorepo layout: `packages/engine-core/`, `packages/desktop-shell/`, `packages/cli/`. Each package has its own `tsconfig.json` extending a root `tsconfig.base.json`, and a `package.json` declaring its public entrypoint. The root `package.json` defines workspace globs and shared scripts (`build`, `test`, `lint`, `format`). `npm install` at the repo root installs all package dependencies; `npm run build` compiles every package in topological order. The scaffold compiles cleanly with zero TypeScript errors on a fresh clone.

## Acceptance scenarios

1. **Given** a fresh clone of the repo, **When** `npm install && npm run build` is run, **Then** all three packages compile with exit code 0 and `dist/` directories appear under each package.
2. **Given** a TypeScript change in `packages/engine-core/src/index.ts` that imports a non-existent type, **When** `npm run build` is run, **Then** the build fails with a TS2305 error pointing at the package.
3. **Given** the workspace globs in root `package.json`, **When** a developer runs `npm install` after adding `packages/new-pkg/package.json`, **Then** the new package is automatically picked up without manual config.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/scaffolding/package-layout.test.ts` | unit | RED — asserts file existence + workspace config | scenarios 1, 3 |
| (TBD) `tests/integration/scaffolding/build-fails-on-error.test.ts` | integration | RED | scenario 2 |

## Dependencies

- **Hard:** none
- **Soft:** F-005 (deps pinning informs package.json content)
- **Independent:** F-001..F-002 (those features inhabit this scaffold but don't depend on it being complete)

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:package.json | clawpilot root package layout |
| cp:tsconfig.json | clawpilot tsconfig hierarchy pattern |
| cp:packages/ | clawpilot multi-package monorepo shape |
| kit:foundational-plan.md M-1 | M-1 bootstrap content list |

## Implementation notes

(empty — populated when implementation begins)
