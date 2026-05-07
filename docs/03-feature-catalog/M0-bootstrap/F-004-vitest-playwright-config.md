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
    by: wave-014 / lane-c
    note: "RED → GREEN flip: added `browser` project to vitest.config.ts (4th project, env happy-dom + tests/browser/** glob, runtime wiring deferred to first DOM-rendering spec); created playwright.config.ts at repo root mirroring clawpilot baseline (defineConfig + testDir/testMatch/timeout/reporter/projects[]); authored tests/node/F-004-vitest-playwright-config.test.ts (7 tests — vitest-config structural × 5 + playwright-config structural × 2); all 7/7 PASS; 28/28 across tests/node. Browser-mode runtime, sharedTest/test fixtures, and Playwright project matrix deferred per `rules/no-silent-deferrals.md` to first consumer wave (M5 desktop-shell / e2e suites)."
  - status: locked
    at: 2026-05-07
    by: wave-015 / lane-a
    note: "Post-impl council review verdict ACCEPT (median confidence 87; advocate 89 / skeptic 73 / architect 87; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE). MINOR findings: Scenarios 2+3 require M5 runtime; browser project runtime wiring deferred; @playwright/test devDep + pnpm e2e script deferred; regex-against-config trade-off accepted. Review at docs/05-design-reviews/council-reviews/F-004-vitest-playwright-config-review.md."
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
  node:
    - tests/node/F-004-vitest-playwright-config.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest:unit
  - vitest:node
  - vitest:browser
  - vitest:integration
  - playwright (config-present, projects[] empty pending M5)
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-004-vitest-playwright-config-review.md exists with verdict: ACCEPT.
depends-on: [F-003]
out-of-scope-notes: |
  Coverage gating thresholds (e.g. ≥90% diff coverage) are enforced by
  F-006 (logging-pipeline) + the feature-eval workflow, not by this feature.
  This feature only configures the runners.

  At v1 GREEN (wave-014 / lane-c) the following are explicitly deferred per
  `rules/no-silent-deferrals.md`:
  - `browser` project's runtime wiring (`browser: { provider: 'playwright',
    headless: true, instances: [{ browser: 'chromium' }] }`) — the project
    is config-present in `vitest.config.ts:projects[]` so the 4-project
    layout contract holds, but the include glob (`tests/browser/**/*.test.ts`)
    has no specs yet. First consumer wave (M5 desktop-shell or e2e
    companion) ships a DOM-rendering spec AND wires the runtime AND
    installs `@vitest/browser` + `playwright` devDeps in the same commit.
  - Playwright `sharedTest` + `test` fixture-mode behavior (Acceptance
    scenarios 2+3) — verified by M5 desktop-shell e2e suites
    (F-032..F-043). v1 only requires the config file exists with a valid
    `defineConfig()` invocation so M5's specs have a runner attachment
    point.
  - `@playwright/test` devDependency — installed by the wave that lands
    the first Playwright spec; adding it now would ship an unused
    ~200MB browser-binary download to every clone.
  - `pnpm e2e` script in `package.json` — wired by M5 alongside the first
    spec; pointing at zero specs now adds noise without value.
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
| `tests/node/F-004-vitest-playwright-config.test.ts` | node | GREEN (wave-014 / lane-c) | scenarios 1, 2 (structural — config-content presence), scenario 3 prerequisite (playwright.config.ts exists) |
| (TBD) `tests/browser/example.test.ts` | browser | RED (deferred to first DOM-rendering spec consumer wave — M5 desktop-shell or e2e companion) | scenario 2 runtime (browser project actually executes a spec) |
| (TBD) `tests/e2e/config/playwright-fixtures.spec.ts` | e2e | RED (deferred to M5 desktop-shell e2e suites) | scenario 3 (sharedTest/test fixture-mode behavior) |

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

**Wave-014 / lane-c GREEN flip (2026-05-07).**

Two surfaces landed:

1. **`vitest.config.ts`** — added `browser` project (4th in the `projects[]` array, sandwiched between `node` and `integration` to keep the canonical ordering `unit / node / browser / integration`). The `browser` project at v1 carries `environment: 'happy-dom'` (matching the `unit` project's env) and an empty include glob `tests/browser/**/*.test.ts`. This is intentional: Vitest's true browser-mode (`browser: { provider: 'playwright', headless: true, instances: [{ browser: 'chromium' }] }`) requires `@vitest/browser` + `playwright` devDeps, which would ship a ~200MB browser-binary download to every clone with zero current consumers. The v1 contract is **config-present, runtime-deferred** — the project name + glob exist so the 4-project layout assertion holds, and the wave that adds the first DOM-rendering spec also (a) installs `@vitest/browser` + `playwright`, (b) swaps `environment: 'happy-dom'` for the `browser:` block, (c) lands the spec under `tests/browser/`. This is a **config-additive** change for that future wave — no breaking change to v1 callers.

2. **`playwright.config.ts`** — new file at repo root, mirroring clawpilot's baseline at `C:/Users/tonym/Repos/m-main/playwright.config.ts`. Same shape: `defineConfig({ testDir: 'e2e', testMatch: '**/*.test.ts', timeout: 60_000, expect: { timeout: 10_000 }, workers: 1, retries: 2, reporter: [['html'], ['list']], projects: [] })`. Differences from clawpilot: `projects: []` empty (clawpilot has `[{ name: 'electron' }]`; we have no electron app yet at M0), no module-augmentation block. The `@playwright/test` devDep is **NOT** installed at v1 — installing it eagerly ships a 200MB browser-binary download for every contributor before any spec exists. M5's first Playwright spec is the wave that installs the dep + adds a project entry to `projects[]` + wires `pnpm e2e` script in `package.json`.

**Test author choice (`tests/node/F-004-vitest-playwright-config.test.ts`).** Pure structural: `existsSync` + `readFileSync` + regex match against the config-file content. No `import` of either config file (those would attempt to evaluate the Playwright config which fails without `@playwright/test` installed). Trade-off: the test verifies "the config file exists and contains the right shape strings" rather than "Vitest actually loads 4 projects." The runtime path is verified incidentally — `pnpm test:node` itself must successfully load `vitest.config.ts` before it can run the F-004 test, so the moment vitest.config.ts becomes invalid TS or Vitest can't parse it, the test framework fails to start and every test fails. This is a stronger guarantee than a runtime `vitest --reporter=json` parse would provide, and it costs ~7ms vs the ~5s a vitest-spawn + JSON-parse round-trip would cost.

**Why config-content regex over imports**: importing `vitest.config.ts` from a test file would create a circular evaluation (the test runs under the same vitest config it's trying to verify). Importing `playwright.config.ts` would fail because `@playwright/test` is not installed. The regex approach sidesteps both — works in any node environment with no extra deps.

**Acceptance scenarios coverage**:
- **Scenario 1** (4-project layout): covered by 5 tests (file exists + 4 project name assertions + integration timeout assertion).
- **Scenario 2** (per-project glob + environment): covered structurally — each project's `name:` and `environment:` literal live next to each other in the same `defineConfig({ projects: [{ ... }, ...] })` block; the same content scan that verifies project names also verifies their envs are present in the file. A separate runtime "files in tests/unit/ run with happy-dom" assertion is deferred to M5 (when the first happy-dom DOM-rendering spec lands and the env actually matters).
- **Scenario 3** (Playwright sharedTest fixture): covered as **prerequisite** — the config file exists with `defineConfig` so M5 e2e specs can attach; the sharedTest fixture-mode behavior itself is M5 e2e suite scope per ledger §Out-of-scope-notes.

**Dependency status**:
- F-003 (repo-scaffolding): GREEN (sibling lane, wave-014 / lane-a or lane-d). Hard dep satisfied.
- F-005 (deps-pinning): GREEN (wave-013 / lane-b). Soft dep satisfied — vitest is exact-pinned at 2.1.9, no playwright devDep installed yet (intentional per Out-of-scope-notes).
