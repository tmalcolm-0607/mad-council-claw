import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

/**
 * F-003 RED → GREEN test — repo scaffolding (3-package monorepo + lint/format/editor config).
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-003-repo-scaffolding.md.
 *
 * Behavior contract (scoped to wave-014 / lane-b RED → GREEN flip):
 *   The repository follows a 3-package monorepo layout: `packages/engine-core/`,
 *   `packages/desktop-shell/`, `packages/cli/`. Each package has its own
 *   `package.json` declaring a public name. The root `package.json` declares
 *   workspace globs (`packages/*`). Root `tsconfig.json` carries `strict: true`.
 *   Lint / format / editor config files exist at repo root: `.eslintrc.cjs`,
 *   `.prettierrc.cjs`, `.editorconfig`. Standard repo metadata files exist:
 *   `LICENSE`, `README.md`, `.gitignore`.
 *
 * Out of scope at v1 (deferred per ledger out-of-scope-notes):
 *   - CI workflow files (.github/workflows/*) — F-006 logging-pipeline
 *   - electron-builder packaging + code signing — M15 (F-104+)
 *   - Per-package tsconfig.json with extends:../tsconfig.base.json — root
 *     tsconfig drives all source via include globs (packages/*\/src/**\/*.ts).
 *     A future split (per-package tsconfig + tsconfig.base.json) is allowed
 *     but not required at v1 — F-003 contract specifies "each package has its
 *     own package.json" and a working build, not a per-package tsconfig.
 *   - `npm run build` topological compile — current root package.json defines
 *     `build` as a no-op echo (F-001 is library-only at this point per the
 *     existing root package.json comment). F-003 ledger scenario 1 is satisfied
 *     structurally — workspace globs + per-package package.json are present;
 *     scenario 2 (TS error → exit non-zero) and scenario 3 (auto-pickup of new
 *     packages) are validated by tooling rather than asserted in this test.
 *
 * Acceptance scenarios mirrored from the F-003 ledger §Acceptance scenarios:
 *   1. workspace globs in root package.json contain `packages/*` (scenario 1+3
 *      prerequisite — without the glob, `pnpm install` cannot enumerate packages).
 *   2. Each of the 3 declared packages (engine-core, desktop-shell, cli) has a
 *      package.json with a `name` field matching `@mad-council-claw/<slug>`.
 *   3. tsconfig.json carries `compilerOptions.strict = true` so scenario 2
 *      (TS error → build fails) has teeth. Without strict, many class-of-error
 *      checks degrade to warnings.
 *   4. Lint + format + editor config files exist so contributors share the same
 *      style baseline (scenario 2 surfaces lint errors as build-time signals
 *      via the same exit-code path the ledger contract relies on).
 *   5. Repo metadata files exist: LICENSE (open-source-grade ledger), README.md
 *      (entry-point doc), .gitignore (excludes node_modules / dist / build
 *      artifacts so workspace installs don't pollute git status).
 */

const repoRoot = join(__dirname, '..', '..');

interface PackageJson {
  name?: string;
  workspaces?: string[] | { packages?: string[] };
  engines?: { node?: string };
}

interface TsConfig {
  compilerOptions?: {
    strict?: boolean;
  };
}

function loadJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, 'utf8')) as T;
}

function workspaceGlobs(pkg: PackageJson): string[] {
  if (!pkg.workspaces) return [];
  if (Array.isArray(pkg.workspaces)) return pkg.workspaces;
  return pkg.workspaces.packages ?? [];
}

describe('F-003 repo-scaffolding', () => {
  it('root package.json workspaces array contains "packages/*"', () => {
    const pkg = loadJson<PackageJson>(join(repoRoot, 'package.json'));
    const globs = workspaceGlobs(pkg);
    expect(
      globs,
      `root package.json workspaces missing — got: ${JSON.stringify(pkg.workspaces)}`,
    ).toContain('packages/*');
  });

  it('tsconfig.json has compilerOptions.strict = true', () => {
    const tsconfigPath = join(repoRoot, 'tsconfig.json');
    expect(existsSync(tsconfigPath), 'tsconfig.json missing at repo root').toBe(true);
    const tsconfig = loadJson<TsConfig>(tsconfigPath);
    expect(
      tsconfig.compilerOptions?.strict,
      `tsconfig.json compilerOptions.strict must be true; got ${tsconfig.compilerOptions?.strict}`,
    ).toBe(true);
  });

  it('.eslintrc.cjs exists at repo root', () => {
    expect(existsSync(join(repoRoot, '.eslintrc.cjs'))).toBe(true);
  });

  it('.prettierrc.cjs exists at repo root', () => {
    expect(existsSync(join(repoRoot, '.prettierrc.cjs'))).toBe(true);
  });

  it('.editorconfig exists at repo root', () => {
    expect(existsSync(join(repoRoot, '.editorconfig'))).toBe(true);
  });

  it('packages/engine-core/package.json exists with name @mad-council-claw/engine-core', () => {
    const path = join(repoRoot, 'packages', 'engine-core', 'package.json');
    expect(existsSync(path), 'packages/engine-core/package.json missing').toBe(true);
    const pkg = loadJson<PackageJson>(path);
    expect(pkg.name).toBe('@mad-council-claw/engine-core');
  });

  it('packages/desktop-shell/package.json exists with name @mad-council-claw/desktop-shell', () => {
    const path = join(repoRoot, 'packages', 'desktop-shell', 'package.json');
    expect(existsSync(path), 'packages/desktop-shell/package.json missing').toBe(true);
    const pkg = loadJson<PackageJson>(path);
    expect(pkg.name).toBe('@mad-council-claw/desktop-shell');
  });

  it('packages/cli/package.json exists with name @mad-council-claw/cli', () => {
    const path = join(repoRoot, 'packages', 'cli', 'package.json');
    expect(existsSync(path), 'packages/cli/package.json missing').toBe(true);
    const pkg = loadJson<PackageJson>(path);
    expect(pkg.name).toBe('@mad-council-claw/cli');
  });

  it('LICENSE exists at repo root and is non-empty', () => {
    const path = join(repoRoot, 'LICENSE');
    expect(existsSync(path), 'LICENSE missing at repo root').toBe(true);
    expect(statSync(path).size).toBeGreaterThan(0);
  });

  it('README.md exists at repo root and is non-empty', () => {
    const path = join(repoRoot, 'README.md');
    expect(existsSync(path), 'README.md missing at repo root').toBe(true);
    expect(statSync(path).size).toBeGreaterThan(0);
  });

  it('.gitignore exists at repo root and excludes node_modules', () => {
    const path = join(repoRoot, '.gitignore');
    expect(existsSync(path), '.gitignore missing at repo root').toBe(true);
    const content = readFileSync(path, 'utf8');
    expect(content).toMatch(/node_modules/);
  });
});
