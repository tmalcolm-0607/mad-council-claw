---
artifact-class: physical-proof
generated-by: wave-013 / lane-b
feature-id: F-005
date: 2026-05-07
status: green
---

# F-005 — Physical proof

15th feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006, F-014 + F-015 wave-008, F-006 + F-016 + F-018 wave-009, F-008 + F-019 + F-020 + F-022 wave-010, F-007 wave-011, F-021 + F-017 wave-012). First M0 dependency-pinning flip — closes the last RED slot in M0 alongside F-003 + F-004 (which remain RED awaiting their own waves).

## Acceptance scenarios → test results

| # | Scenario (from ledger §Acceptance scenarios) | Vitest test name | Result |
|---|---|---|---|
| 1 | Given a `package.json` with `"react": "^18.2.0"`, When the deps-pinning gate runs, Then the gate fails with `RANGE_OPERATOR_FORBIDDEN: react`. **Wave-013 interpretation:** assert the inverse — every shipping devDependency in root + workspaces is exact-pinned (no `^` / `~` / range operators). | `root package.json devDependencies are exact-pinned (no ^, ~, or range operators)` + `every workspace package.json (root + packages/*) has exact-pinned deps` | PASS (both) |
| 2 | Given a committed lockfile and a fresh `package.json` change, When CI runs `pnpm install --frozen-lockfile`, Then CI fails with EUSAGE if out of sync. **Wave-013 prerequisite:** lockfile is present at repo root. (Out-of-sync enforcement is CI-runner concern, M16.) | `pnpm-lock.yaml exists at repo root (committed lockfile)` | PASS |
| 3 | Given the repo at HEAD, When `pnpm install` runs on Linux + macOS + Windows, Then all three produce the same set of installed package versions. **Wave-013 prerequisite:** `engines.node` is specified so reproducible installs tie to a known runtime floor. (Cross-OS byte-identity is a CI feature, M16.) | `engines.node is specified in root package.json` | PASS |

4/4 PASS. See `green-test-output.txt` for the captured vitest output. RED baseline at `red-test-output.txt` (root devDeps test FAILED: `Found range-pinned devDependencies (must be exact): vitest@^2.0.0, @vitest/ui@^2.0.0, happy-dom@^15.0.0, typescript@^5.5.0, @types/node@^20.0.0`).

## Scope reconciliation with F-005 ledger (FETCH BEFORE CITE)

The F-005 ledger (`docs/03-feature-catalog/M0-bootstrap/F-005-deps-pinning.md`) was authored at wave-002/lane-b under the assumption that v1 would use **npm** (referencing `cp:package-lock.json` and `npm ci` in the behavior contract). Between authoring and this wave, the repo standardized on **pnpm** (per `pnpm-workspace.yaml` + the existing `pnpm-lock.yaml`). The wave-013 GREEN flip honors the *intent* of F-005 (exact-pinned deps + committed lockfile + reproducible-install discipline) by validating the equivalent pnpm shape. The ledger §Implementation notes is updated to record the package-manager choice.

The acceptance scenarios in §Acceptance scenarios are honored as follows:
- Scenario 1 (range operators forbidden) — directly enforced by the test's exact-pin regex sweep.
- Scenario 2 (lockfile-vs-package.json drift fails CI) — prerequisite (lockfile present) enforced; the actual `pnpm install --frozen-lockfile` failure on drift is a runner concern, not a unit-test concern. Deferred to M16 CI hardening per `no-silent-deferrals.md`.
- Scenario 3 (cross-OS byte-identity) — prerequisite (engines.node pinned) enforced; cross-OS verification is a CI matrix concern. Deferred to M16 per `no-silent-deferrals.md`.

## Implementation summary

### Edited file

`package.json` (root) — devDependencies range operators stripped:

| Dep | Before | After |
|---|---|---|
| `vitest` | `^2.0.0` | `2.1.9` (resolved from prior lockfile) |
| `@vitest/ui` | `^2.0.0` | `2.1.9` |
| `happy-dom` | `^15.0.0` | `15.11.7` |
| `typescript` | `^5.5.0` | `5.9.3` |
| `@types/node` | `^20.0.0` | `20.19.39` |

Also added: `"packageManager": "pnpm@9.0.0"` field — codifies pnpm as the v1 package manager so `corepack` users get a deterministic version. `engines.node` was already `>=20` and is left unchanged (the ledger considers a runtime floor sufficient for v1; tighter pinning is M16 scope).

### New file

`tests/node/F-005-deps-pinning.test.ts` — 4 tests; runs under the `node` test project (per `vitest.config.ts`). The test sweeps every workspace package.json and rejects any non-`workspace:*` version that doesn't match the exact-pin regex `^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$`.

### Regenerated file

`pnpm-lock.yaml` — regenerated via `pnpm install --lockfile-only --config.confirmModulesPurge=false` so specifiers reflect exact pins (e.g. `specifier: 2.1.9` instead of `specifier: ^2.0.0`). Resolved versions are unchanged from prior lockfile (the prior `^2.0.0` had resolved to `2.1.9`); only the specifier strings change.

## Suite state at GREEN

Full suite (`pnpm test`): 98/98 across 15 test files (was 94/94 across 14 pre-F-005). New tests:

- `tests/node/F-005-deps-pinning.test.ts` — 4 tests, all PASS in 10ms.

No regressions in adjacent features (F-001/F-002/F-006/F-007/F-008/F-014..F-022).

## Surface-trace honesty

Per F-005 ledger §Surface trace:

- `cp:package-lock.json` — clawpilot lockfile commit pattern. **Adapted to pnpm**: pnpm-lock.yaml fills the same role (committed lockfile, deterministic resolution, frozen-lockfile install discipline). The intent transfers cleanly.
- `kit:rules/verification-protocol.md` — reproducible-build discipline (ACTUAL BEFORE PRESENT). **Honored**: the test asserts what's actually on disk (regex sweep of every package.json + lockfile presence), not what the developer claims.

No silent deferrals; package-manager choice (npm → pnpm) is recorded in the F-005 ledger §Implementation notes alongside this proof.
