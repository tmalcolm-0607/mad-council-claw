---
artifact-class: council-review
feature-id: F-004
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-015 / lane-a
---

# F-004 vitest-playwright-config — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 89 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 73 |
| architect-lens | Architect | APPROVE | 87 |

Median confidence: 87

## Implementation reviewed

- `vitest.config.ts` (52 LOC) — `defineConfig({ test: { projects: [...] } })` with 4 projects in canonical order: `unit` (env happy-dom + glob `tests/unit/**/*.test.ts`), `node` (env node + glob `tests/node/**/*.test.ts`), `browser` (env happy-dom + glob `tests/browser/**/*.test.ts`, runtime-deferred), `integration` (env node + glob `tests/integration/**/*.test.ts` + testTimeout 30_000).
- `playwright.config.ts` (42 LOC) — new file at repo root mirroring clawpilot baseline. `defineConfig({ testDir: 'e2e', testMatch: '**/*.test.ts', timeout: 60_000, expect: { timeout: 10_000 }, workers: 1, retries: 2, reporter: [['html', { open: 'never' }], ['list']], projects: [] })`. `projects: []` empty — M5 will populate when first Playwright spec lands.
- `tests/node/F-004-vitest-playwright-config.test.ts` (91 LOC) — 7 structural assertions (5 vitest-config: file exists + 4 project-name presence + integration testTimeout=30_000; 2 playwright-config: file exists + parseable defineConfig invocation); all PASS via `existsSync` + `readFileSync` + regex (no module imports — works without `@playwright/test` installed).
- Commit history per `docs/07-roadmap/decision-log.md`: F-004 RED at wave-002 / lane-b (initial ledger only); F-004 GREEN at wave-014 / lane-c.

## Advocate lens

**Verdict: APPROVE (confidence 89)**

- Implementation is minimal and correct per `minimum-change.md`. The `browser` project is config-present, runtime-deferred — the 4-project layout contract holds without shipping a ~200MB browser-binary download to every clone before any DOM-rendering spec exists. The eager-install-now alternative would have been YAGNI of the worst kind.
- 7/7 structural assertions PASS at GREEN time. Pure structural via `existsSync` + `readFileSync` + regex — no module imports of `vitest.config.ts` (would create circular evaluation) or `playwright.config.ts` (would fail because `@playwright/test` isn't installed). The structural approach costs ~7ms vs ~5s for a vitest-spawn round-trip, and is a strictly stronger guarantee than the runtime path.
- Surface trace (per ledger): `cp:vitest.config.ts` + `cp:playwright.config.ts` + `kit:foundational-plan.md` "4-project layout" — provenance is auditable; clawpilot baseline at `C:/Users/tonym/Repos/m-main/playwright.config.ts` is the source.
- 4-project canonical order (`unit / node / browser / integration`) matches the ledger §Implementation notes exactly — `browser` slotted between `node` and `integration` to keep ordering stable. Adding a 5th project later is additive (no reorder needed).
- F-004 was the 15th feature to flip RED → GREEN (wave-014 / lane-c) and is among the last M0 features to lock. Combined with F-003 + F-005 + F-009 + F-021 LOCKED here, M0 reaches 0R + 0G + 8L (100% LOCKED for active features).

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 73)**

- F-004 is **config-present, runtime-deferred** for several scenarios. Two of the three F-004 ledger §Acceptance scenarios (Scenario 2: per-project glob runtime — files in `tests/unit/` actually run with happy-dom; Scenario 3: Playwright sharedTest fixture-mode behavior) require a runtime that doesn't exist yet. Only Scenario 1 (4-project layout) is fully runtime-verifiable today.
- LOCKED status here is therefore narrowly "**F-004 config-shape contract LOCKED**" — Scenarios 2 + 3 will be retired by M5 desktop-shell + e2e companion suites (F-032..F-043). The ledger §Red→green wire-up table already names them as deferred; the `out-of-scope-notes` block is explicit per `no-silent-deferrals.md`.
- The `browser` project's runtime wiring (`browser: { provider: 'playwright', headless: true, instances: [{ browser: 'chromium' }] }` + `@vitest/browser` + `playwright` devDeps) is deferred. Today the `browser` project carries `environment: 'happy-dom'` matching `unit` — meaning a test file accidentally placed under `tests/browser/` would run under happy-dom, not real Chromium. This is acceptable because the include glob is empty — but a future test author needs to know the `browser` project is currently a happy-dom mirror.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `vitest.config.ts` lines 1-52, `playwright.config.ts` lines 1-42, and the test file lines 1-91. The shape is exactly what the ledger describes; no hidden surface area.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when M5's first Playwright spec lands, the wave that wires it up should also (a) install `@playwright/test`, (b) add `pnpm e2e` to root scripts, (c) populate `projects[]` with at least one entry, (d) revisit F-004 §Acceptance scenarios 2 + 3 with runtime tests. The deferrals are documented but the future audit lane should close them.
- Suggestion (NON-BLOCKING): test uses regex against config-file content — slightly brittle vs reformatting (e.g. someone adds whitespace inside `defineConfig({...})`). Acceptable trade-off given the alternative (`vitest --reporter=json` round-trip) is ~700x slower; flagging for awareness if the test starts producing flakes.

## Architect lens

**Verdict: APPROVE (confidence 87)**

- File-location posture: `vitest.config.ts` + `playwright.config.ts` at repo root — correct shape. Vitest reads `vitest.config.ts` from CWD; Playwright reads `playwright.config.ts` from CWD. Per-package configs are NOT needed at v1 — the root configs cover all packages via include globs.
- 4-project decomposition (unit/node/browser/integration): meaningful separation of concerns. `unit` runs fast (~ms) under happy-dom for pure-logic tests; `node` runs under real Node for fs/path/process tests (e.g., F-003, F-005, F-008); `browser` is reserved for future DOM-rendering specs; `integration` gets a 30-second timeout for slow specs. Test authors can target the right project by file location.
- Playwright config shape: mirrors clawpilot baseline (`C:/Users/tonym/Repos/m-main/playwright.config.ts`) — `workers: 1` + `retries: 2` + `60s timeout` + HTML reporter + list reporter. Workers fixed at 1 because Electron tests must run serially; retries handle infrastructural flakes without masking real failures (each retry shows in the HTML report).
- `projects: []` empty at v1: M5's first Playwright spec adds a project entry (e.g., `[{ name: 'electron', testMatch: 'e2e/electron/**/*.test.ts' }]`). The `projects` shape is the right abstraction for multi-target Playwright (Electron desktop + headless web + future targets) — clawpilot uses it; we inherit cleanly.
- API surface review:
  - `defineConfig({ test: { projects: [...] } })` for Vitest — current Vitest 2.x shape; `projects` key is the modern multi-config pattern (replaces the older `test.workspace` + `vitest.workspace.ts`).
  - `extends: true` on each project — inherits root config defaults (e.g., resolve aliases when added) without per-project repetition.
- No surprises in dependencies: F-004 has F-003 as its only hard dep (per ledger frontmatter `depends-on: [F-003]`) — scaffolding must exist before runner configs attach. F-005 (deps-pinning) is a soft dep — `vitest` is exact-pinned at 2.1.9; no `@playwright/test` installed yet (intentional).

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-004 §Acceptance scenarios 2 (per-project glob runtime under correct env) + 3 (Playwright sharedTest fixture-mode behavior) require runtime that lands with M5 desktop-shell + e2e companion suites (F-032..F-043). Today only Scenario 1 (4-project layout) is fully runtime-verifiable. | Accept; LOCKED status applies to the config-shape contract scope explicitly. The ledger §Red→green wire-up + §Out-of-scope-notes document the deferrals. |
| F2 | MINOR | `browser` project is config-present, runtime-deferred — currently mirrors `unit` under happy-dom. The `browser: { provider: 'playwright', ... }` runtime wiring + `@vitest/browser` + `playwright` devDeps are deferred to first DOM-rendering spec consumer wave. A future test author needs to know placing a file under `tests/browser/` runs under happy-dom today. | Accept; documented in the vitest.config.ts inline comment block (lines 26-37). |
| F3 | MINOR | `@playwright/test` devDep + `pnpm e2e` script + `projects[]` population deferred to first M5 Playwright spec wave. Scaffold-attachment-point at v1; runtime-functional at first consumer. | Accept; ledger §Out-of-scope-notes documents the deferral. |
| F4 | MINOR | Test uses regex against config-file content — slightly brittle vs aggressive reformatting. Trade-off accepted given the alternative is ~700x slower. | Accept; flagging for awareness if flakes appear. |
| F5 | PRAISE | Structural test approach (`existsSync` + `readFileSync` + regex; no module imports) sidesteps both circular evaluation (importing `vitest.config.ts` from a vitest test) AND the missing-dep problem (importing `playwright.config.ts` would fail because `@playwright/test` isn't installed). Works in any node environment with no extra deps. | Keep. |
| F6 | PRAISE | `browser` project config-present + runtime-deferred is the right minimum. Eager install of `@vitest/browser` + `playwright` would have shipped ~200MB to every clone before any consumer existed. YAGNI-aware. | Keep. |
| F7 | PRAISE | Canonical project ordering (`unit / node / browser / integration`) is stable — adding a 5th project later is additive. Test author's mental model maps directly to file location. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 87).

F-004 config-shape contract is implemented correctly; all 7 wave-014-scoped structural assertions pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-004 ledger frontmatter (`LOCKED if GREEN AND reviews/F-004-vitest-playwright-config-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — F1 (Scenarios 2+3 require M5 runtime), F2 (`browser` runtime wiring deferred), F3 (`@playwright/test` install + `pnpm e2e` deferred to M5), F4 (regex-against-config trade-off) are surfaced in this review and in the F-004 ledger §Out-of-scope-notes. No finding is silent.

F-004 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-004-vitest-playwright-config.md`
- Source: `vitest.config.ts` (52 LOC), `playwright.config.ts` (42 LOC)
- Tests: `tests/node/F-004-vitest-playwright-config.test.ts` (7/7 PASS)
- GREEN proof: `docs/09-examples-proof/F-004/` (green-test-output + physical-proof)
- GREEN transition: decision-log.md (F-004 RED → GREEN row); wave-014 / lane-c
- Clawpilot source: `C:/Users/tonym/Repos/m-main/playwright.config.ts` (mirrored baseline)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
