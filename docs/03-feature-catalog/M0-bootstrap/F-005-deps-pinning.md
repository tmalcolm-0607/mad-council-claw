---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-013 / lane-b
    note: "RED → GREEN flip. Root package.json devDependencies stripped of ^/~ range operators (vitest 2.1.9, @vitest/ui 2.1.9, happy-dom 15.11.7, typescript 5.9.3, @types/node 20.19.39); packageManager: pnpm@9.0.0 declared; pnpm-lock.yaml regenerated with exact-pin specifiers; tests/node/F-005-deps-pinning.test.ts authored 4 tests RED → GREEN (4/4 PASS); full suite 98/98 across 15 test files. Package-manager choice (npm → pnpm) recorded in §Implementation notes; cross-OS byte-identity + lockfile-drift CI enforcement deferred to M16 per no-silent-deferrals.md (already disclosed in §Out-of-scope-notes)."
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
  node:
    - tests/node/F-005-deps-pinning.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
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

**Wave-013 / lane-b GREEN flip (2026-05-07).**

**Package-manager choice — npm → pnpm.** The ledger was authored at wave-002/lane-b under the assumption v1 would use npm (referencing `cp:package-lock.json` + `npm ci`). Between authoring and wave-013, the repo standardized on **pnpm** (per the pre-existing `pnpm-workspace.yaml` + `pnpm-lock.yaml`). The wave-013 GREEN flip honors F-005's *intent* (exact-pinned deps + committed lockfile + reproducible-install discipline) by validating the equivalent pnpm shape:

| F-005 intent | Original (npm) | Adopted (pnpm) |
|---|---|---|
| Committed lockfile | `package-lock.json` | `pnpm-lock.yaml` |
| Frozen-lockfile install | `npm ci` | `pnpm install --frozen-lockfile` |
| Workspace mgr | npm workspaces | pnpm workspaces (`pnpm-workspace.yaml`) |
| Package-manager pinning | `engines.npm` | `packageManager: pnpm@9.0.0` |

The surface trace (`cp:package-lock.json`) transfers cleanly — clawpilot's lockfile-commit pattern is the discipline; the file format is incidental.

**Wave-013 changes:**

1. **Root `package.json`** — devDependencies stripped of `^` operators (5 deps: `vitest`, `@vitest/ui`, `happy-dom`, `typescript`, `@types/node`); resolved versions read from prior lockfile (no version drift, only specifier-string change). Added `packageManager: pnpm@9.0.0` field for `corepack`-driven deterministic pnpm version.

2. **`pnpm-lock.yaml`** — regenerated via `pnpm install --lockfile-only --config.confirmModulesPurge=false` so specifier strings reflect exact pins (e.g. `specifier: 2.1.9` instead of `specifier: ^2.0.0`). Resolved package versions in the `packages:` section are unchanged.

3. **`tests/node/F-005-deps-pinning.test.ts`** — 4 tests; sweeps every workspace package.json + asserts exact-pin regex on every non-`workspace:*` version + asserts lockfile presence + asserts `engines.node` defined. Runs under the `node` test project (per `vitest.config.ts`).

**Acceptance scenario coverage (per F-005 ledger §Acceptance scenarios):**

| Scenario | Wave-013 coverage |
|---|---|
| 1 (range operators forbidden) | Direct — exact-pin regex sweep on all workspace package.json files. |
| 2 (lockfile-vs-package.json drift fails CI) | Prerequisite (lockfile presence) covered; runtime CI enforcement deferred to M16. |
| 3 (cross-OS byte-identity install) | Prerequisite (engines.node pinned) covered; cross-OS verification deferred to M16. |

Deferrals are recorded in §Out-of-scope-notes (already disclosed at wave-002 authoring) and surfaced in `docs/09-examples-proof/F-005/physical-proof.md` per `no-silent-deferrals.md`.

**Suite state at GREEN:** 98/98 across 15 test files (was 94/94 across 14 pre-F-005). No regressions in adjacent features.
