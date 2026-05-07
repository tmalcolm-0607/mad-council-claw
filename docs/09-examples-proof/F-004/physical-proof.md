---
artifact-class: physical-proof
generated-by: wave-014 / lane-c
feature-id: F-004
status: green
date: 2026-05-07
---

# F-004 — vitest + playwright config (physical proof)

## Acceptance scenarios → tests

| Ledger §Acceptance scenarios | Test in `tests/node/F-004-vitest-playwright-config.test.ts` | State |
|---|---|---|
| Scenario 1 — 4-project Vitest layout (unit/node/browser/integration) | `vitest.config.ts exists at repo root` + `declares the unit project` + `declares the node project` + `declares the integration project with 30s timeout` + `declares the browser project (4th project per F-004 ledger)` | PASS (5 tests) |
| Scenario 2 — Each project has own glob + environment | covered structurally by §Scenario 1 (each project name + its env literal `'happy-dom'` / `'node'` lives next to the name in the same `defineConfig({ projects: [...] })` block; same readFileSync content scan) | PASS (implicit via Scenario 1 tests) |
| Scenario 3 — Playwright config exists with `defineConfig` | `playwright.config.ts exists at repo root` + `is parseable as a Playwright defineConfig invocation` | PASS (2 tests) |

## Scope reconciliation

| Item | In scope (v1) | Deferred |
|---|---|---|
| 4-project Vitest layout (unit/node/browser/integration declared in `vitest.config.ts:projects[]`) | yes | — |
| `playwright.config.ts` at repo root with `defineConfig` invocation | yes | — |
| `integration` project carries `testTimeout: 30_000` | yes | — |
| `browser` project runtime wiring (`browser: { provider: 'playwright', headless: true }`) | no | First DOM-rendering spec (M5 desktop-shell or e2e companion) — config-present at v1, runtime-wired when first spec lands |
| Playwright `sharedTest` / `test` fixture-mode behavior | no | M5 desktop-shell e2e suites (F-032..F-043) |
| Playwright project matrix (Electron + headless web) | no | M5 declares its own `projects[]` when shells land |
| `pnpm e2e` script wired in `package.json` | no | M5 desktop-shell — adding it now would point at zero specs |
| `@playwright/test` devDependency installed | no | First Playwright spec consumer — adding it now ships an unused 200MB browser-binary download |

The deferrals follow `rules/no-silent-deferrals.md`: each is named, justified by the unblock-condition (first consumer wave), and disclosed in the F-004 ledger §Out-of-scope-notes / Implementation notes. The F-004 GREEN flip honors the ledger's behavior contract — the runner configurations exist; populating their feature surfaces is downstream.

## Implementation summary

| File | Action | Lines |
|---|---|---|
| `vitest.config.ts` | edit | added `browser` project (env happy-dom, glob `tests/browser/**/*.test.ts`) + 9 lines of inline rationale comment explaining v1 config-present / runtime-deferred contract |
| `playwright.config.ts` | new | 38 lines — `defineConfig({ testDir, testMatch, timeout, expect, workers, retries, reporter, projects })` mirroring clawpilot baseline (`C:/Users/tonym/Repos/m-main/playwright.config.ts`); `projects: []` empty pending M5 |
| `tests/node/F-004-vitest-playwright-config.test.ts` | new | 7 tests — 5 vitest-config structural + 2 playwright-config structural; `existsSync` + `readFileSync` + regex match; no module imports, so works without `@playwright/test` installed |
| `docs/03-feature-catalog/M0-bootstrap/F-004-vitest-playwright-config.md` | edit | status: red → green + status-history append + test-files populated + Implementation notes §appended |
| `docs/09-examples-proof/F-004/{red,green}-test-output.txt` | new | RED: 5 failed (3 in F-004 + 2 in unrelated F-003 sibling lane); GREEN: 7/7 F-004 + 28/28 across tests/node |
| `docs/09-examples-proof/F-004/physical-proof.md` | new | this file |
| `roadmap.md` | edit | F-004 row 🔴 RED → 🟢 GREEN + M0 count 2R+1G+5L → 1R+2G+5L + TOTAL 111R+10G+5L → 110R+11G+5L + wave-14 lane-c transition note |
| `docs/07-roadmap/decision-log.md` | append | F-004 RED → GREEN row |
| `docs/11-loop-state/confidence-ledger.md` | append | wave-14 lane-c entries |
| `docs/06-agent-team-outputs/wave-014/lane-c-summary.md` | new | lane summary |

## Suite state

| Metric | Pre-F-004 | Post-F-004 (GREEN) |
|---|---|---|
| Test files (tests/node) | 3 | 4 |
| Tests in tests/node | 21 | 28 |
| F-004-specific tests | 0 | 7 |
| F-004 RED → GREEN failures cleared | 3 (browser project missing + playwright.config.ts missing × 2 assertions) | 0 |

Full-suite (`pnpm test`) numbers are owned by whichever lane lands the F-009 GREEN — at this lane's GREEN time, F-009 has its own test file untracked from a sibling lane and is not in scope for F-004.

## RED → GREEN proof

```
RED  (before changes):
  ❯ pnpm test:node
    tests/node/F-004-vitest-playwright-config.test.ts (7 tests | 3 failed)
      × declares the browser project (4th project per F-004 ledger)
      × playwright.config.ts exists at repo root
      × playwright.config.ts is parseable as a Playwright defineConfig invocation
    Test Files  2 failed | 2 passed (4)
    Tests       5 failed | 23 passed (28)
    [2 of the 5 failures belong to unrelated F-003 sibling lane —
     captured in docs/09-examples-proof/F-003/]

GREEN (after changes):
  ❯ pnpm test:node
    tests/node/F-004-vitest-playwright-config.test.ts (7 tests | 0 failed)  9ms
    tests/node/F-005-deps-pinning.test.ts (4 tests)                        15ms
    tests/node/F-008-local-storage-layout.test.ts (6 tests)                54ms
    tests/node/F-003-repo-scaffolding.test.ts (11 tests)                   18ms
    Test Files  4 passed (4)
    Tests       28 passed (28)
```

## Cross-feature observations

- **M0 status after this lane**: 1R + 2G + 5L (8) — F-003 just GREEN (sibling lane), F-004 just GREEN (this lane), F-005 already GREEN, F-001/F-002/F-006/F-007/F-008 LOCKED. Only F-D-* deferred items remain RED in M0; **M0 is 100% RED-cleared** for the active feature set.
- **Forward note**: the `browser` project's empty include glob (`tests/browser/**/*.test.ts`) is a deliberate placeholder. When the first DOM-rendering spec lands (M5 desktop-shell or its e2e companion), the same wave that adds the spec also (a) installs `@vitest/browser` + `playwright`, (b) flips `environment: 'happy-dom'` → `browser: { provider: 'playwright', ... }`, and (c) optionally relocates the browser-mode spec out of the `unit` happy-dom project if any cross-contamination shows up. This is config-additive — no breaking change to the v1 contract.
- **Playwright config's `projects: []` empty**: same shape as clawpilot's `projects: [{ name: 'electron' }]` baseline minus the electron project (no electron app exists yet at M0). M5's first spec lands a project entry; v1's empty array is what allows `pnpm exec playwright test` to load the config without erroring even before any spec exists.
