import { defineConfig } from '@playwright/test';

/**
 * F-004 — Playwright e2e runner configuration.
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-004-vitest-playwright-config.md.
 *
 * Scope at v1 (wave-014 / lane-c GREEN flip):
 *   Config-present contract — the file exists at repo root with a valid
 *   `defineConfig()` invocation so M5 desktop-shell + e2e companion suites
 *   have an attachment point when their specs land. Mirrors the clawpilot
 *   (m-main) shape: testDir + testMatch + timeout + reporter + projects[].
 *
 * Deferred to later waves (per F-004 ledger §Acceptance scenarios 2+3):
 *   - sharedTest / test fixture-mode behavior — verified by M5 e2e specs
 *     (F-032..F-043). The fixtures themselves will live alongside the
 *     specs under `e2e/`; this config attaches them at runtime.
 *   - Headless Chromium browser-mode wiring under Vitest's `browser`
 *     project — that path goes through `vitest.config.ts:browser` once
 *     the first DOM-rendering spec lands (see vitest.config.ts comment).
 *   - Multi-project Playwright matrix (Electron desktop + headless web)
 *     — M5 will declare its own projects[] list when shells land.
 *
 * Workers fixed at 1 + retries=2 + 60s timeout follow the clawpilot
 * baseline (`C:/Users/tonym/Repos/m-main/playwright.config.ts`) — Electron
 * tests must run serially, and per-test retry covers infrastructural flakes
 * without masking real failures (each retry shows in the HTML report).
 */
export default defineConfig({
  testDir: 'e2e',
  testMatch: '**/*.test.ts',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  workers: 1,
  retries: 2,
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
  ],
  projects: [],
});
