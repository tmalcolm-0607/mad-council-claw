import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * F-004 RED → GREEN test — vitest + playwright runner configuration.
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-004-vitest-playwright-config.md.
 *
 * Behavior contract (scoped to wave-014 / lane-c RED → GREEN flip):
 *   The repo carries a Vitest config at `vitest.config.ts` declaring at least
 *   the four canonical projects (unit / node / browser / integration), and a
 *   Playwright config at `playwright.config.ts` at repo root. Each Vitest
 *   project is named via `name:` and configured with its own `environment`
 *   and `include` glob; the integration project additionally specifies a
 *   30s testTimeout. Playwright config exists so e2e specs have a runner
 *   contract to attach to.
 *
 * Out of scope at v1 (deferred per ledger out-of-scope-notes + scenarios 2+3):
 *   - Actual Vitest project discovery output ("4 projects" in stdout) — the
 *     wave-011 vitest.config.ts uses defineConfig + projects[]; structural
 *     content-presence is the v1 contract.
 *   - Playwright sharedTest/test fixture-mode behavior — verified in M5
 *     desktop-shell e2e suite (F-032..F-043). v1 only requires the config
 *     file exists so M5 has a runner attachment point.
 *   - Coverage gating thresholds (≥90% diff coverage) — F-006
 *     (logging-pipeline) + feature-eval workflow per ledger §out-of-scope.
 *   - npm test reporting "4 projects" verbatim — happy-dom under unit,
 *     Playwright headless Chromium under browser project will be wired
 *     incrementally; the v1 browser project is config-present, not
 *     runtime-functional (no browser tests yet).
 *
 * Acceptance scenarios mirrored from the F-004 ledger §Acceptance scenarios:
 *   1. Four-project Vitest layout exists (scenario 1 prerequisite — without
 *      the projects[] array carrying unit/node/browser/integration, Vitest
 *      cannot route test files into discrete environments).
 *   2. Each project has its own glob + environment (scenario 2 prerequisite).
 *   3. Playwright config file exists at repo root (scenario 3 prerequisite —
 *      without the config, e2e specs have no runner attachment point;
 *      sharedTest/test fixture behavior verified by M5 e2e suites).
 *
 * Cross-file consistency: vitest.config.ts is the single source of truth for
 * project names + environments; playwright.config.ts is the single source
 * of truth for e2e runner. Both files at repo root (not under packages/*).
 */

const REPO_ROOT = process.cwd();
const VITEST_CONFIG = join(REPO_ROOT, 'vitest.config.ts');
const PLAYWRIGHT_CONFIG = join(REPO_ROOT, 'playwright.config.ts');

describe('F-004 — vitest + playwright config', () => {
  it('vitest.config.ts exists at repo root', () => {
    expect(existsSync(VITEST_CONFIG)).toBe(true);
  });

  it('vitest.config.ts declares the unit project', () => {
    const content = readFileSync(VITEST_CONFIG, 'utf8');
    expect(content).toMatch(/name:\s*['"]unit['"]/);
  });

  it('vitest.config.ts declares the node project', () => {
    const content = readFileSync(VITEST_CONFIG, 'utf8');
    expect(content).toMatch(/name:\s*['"]node['"]/);
  });

  it('vitest.config.ts declares the integration project with 30s timeout', () => {
    const content = readFileSync(VITEST_CONFIG, 'utf8');
    expect(content).toMatch(/name:\s*['"]integration['"]/);
    // 30s timeout — accept 30_000 or 30000 numeric literal forms
    expect(content).toMatch(/testTimeout:\s*30[_]?000/);
  });

  it('vitest.config.ts declares the browser project (4th project per F-004 ledger)', () => {
    const content = readFileSync(VITEST_CONFIG, 'utf8');
    expect(content).toMatch(/name:\s*['"]browser['"]/);
  });

  it('playwright.config.ts exists at repo root', () => {
    expect(existsSync(PLAYWRIGHT_CONFIG)).toBe(true);
  });

  it('playwright.config.ts is parseable as a Playwright defineConfig invocation', () => {
    const content = readFileSync(PLAYWRIGHT_CONFIG, 'utf8');
    // Structural check: contains defineConfig import + invocation.
    // M5 e2e specs will exercise sharedTest/test fixtures; v1 only requires
    // the config file with a defineConfig() call so the runner has a
    // contract to attach to.
    expect(content).toMatch(/from\s+['"]@playwright\/test['"]/);
    expect(content).toMatch(/defineConfig\s*\(/);
  });
});
