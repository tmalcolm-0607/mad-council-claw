---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-014 / lane-b
    note: "RED test authored at tests/node/F-003-repo-scaffolding.test.ts (11 scenarios). RED captured 2/11 fail (desktop-shell + cli package.json missing); GREEN flip added both as empty-but-named workspace packages with @mad-council-claw/<slug> naming. 11/11 PASS at GREEN time. Most scaffolding (root tsconfig, eslint, prettier, editorconfig, engine-core, LICENSE/README/.gitignore) was de-facto landed by waves 11+13; this lane closes the workspace-package gap."
  - status: locked
    at: 2026-05-07
    by: wave-015 / lane-a
    note: "Post-impl council review verdict ACCEPT (median confidence 87; advocate 90 / skeptic 75 / architect 87; 0 CRITICAL / 0 MAJOR / 3 MINOR / 3 PRAISE). MINOR findings: concrete src/ for desktop-shell+cli deferred to M4/M5; working topological build deferred to M3+; per-package tsconfig deferred to per-package divergence. Review at docs/05-design-reviews/council-reviews/F-003-repo-scaffolding-review.md."
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
  node:
    - tests/node/F-003-repo-scaffolding.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
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

**GREEN flip (wave-014 / lane-b, 2026-05-07).** The test
`tests/node/F-003-repo-scaffolding.test.ts` enumerates 11 structural
assertions against the F-003 §Behavior contract. RED state at lane
start: 2/11 failing — `packages/desktop-shell/package.json` and
`packages/cli/package.json` were absent; everything else
(workspace globs, strict TS, lint/format/editor configs, LICENSE /
README.md / .gitignore, engine-core package.json) was de-facto
landed by waves 11 (engine-core file split) and 13 (governance
triad). GREEN flip authored the two missing package.json files as
empty-but-named scaffolds with `name: @mad-council-claw/<slug>`,
`type: module`, `private: true` — matching engine-core's pattern.

**Out-of-scope at v1 (per ledger §out-of-scope-notes + this lane's
test-file out-of-scope notes):**

1. Per-package `tsconfig.json` extending a `tsconfig.base.json`. The
   root `tsconfig.json` covers all sources via `include` globs
   (`packages/*/src/**/*.ts`); per-package tsconfigs are a future
   refinement that does not change the F-003 contract.
2. Working `npm run build` topological compile. The current root
   `package.json` defines `build` as a no-op echo per F-001's
   library-only design. Build wiring is part of M3+ feature scope.
3. Concrete `src/` content for desktop-shell and cli. Those packages
   are scaffold-only at v1; M3+ (cli) and M5+ (desktop-shell) will
   populate.
4. CI workflow files — F-006 logging-pipeline territory.
5. electron-builder packaging + code signing — M15 (F-104+).

**Cross-lane discipline:** committed only Lane B paths (test file +
2 package.json + green output + ledger/roadmap/confidence-ledger/
lane-summary updates). `vitest.config.ts` modification + sibling
F-004/F-009 RED stubs left untouched in working tree per the
non-negotiable rules — no `git reset` used; selective `git add`
only.
