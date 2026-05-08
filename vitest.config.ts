import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Kit tooling under .claude/ + .mad/ ships its own test files written for
    // node:test (not vitest); exclude them from vitest's default scan so they
    // don't trip "describe is not defined" errors when discovery runs outside
    // the per-project `include` globs.
    exclude: ['**/node_modules/**', '**/dist/**', '.claude/**', '.mad/**'],
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          environment: 'happy-dom',
          include: ['tests/unit/**/*.test.ts'],
        },
      },
      {
        extends: true,
        test: {
          name: 'node',
          environment: 'node',
          include: ['tests/node/**/*.test.ts'],
        },
      },
      {
        extends: true,
        test: {
          name: 'browser',
          // v1: config-present, runtime-deferred. The 'browser' project is
          // declared so F-004's 4-project layout contract holds and so future
          // browser-mode tests (Playwright headless Chromium per
          // docs/03-feature-catalog/M0-bootstrap/F-004-vitest-playwright-config.md)
          // have an attachment point. The include glob is empty until the
          // first browser-mode spec lands; vitest treats no-match as 0 tests
          // discovered for this project, which is the v1 contract. Wiring
          // the actual `browser: { provider: 'playwright', ... }` runtime
          // is deferred to the wave that adds the first DOM-rendering spec
          // (M5 desktop-shell or its e2e companion suites).
          environment: 'happy-dom',
          include: ['tests/browser/**/*.test.ts'],
        },
      },
      {
        extends: true,
        test: {
          name: 'integration',
          environment: 'node',
          include: ['tests/integration/**/*.test.ts'],
          testTimeout: 30_000,
        },
      },
    ],
  },
});
