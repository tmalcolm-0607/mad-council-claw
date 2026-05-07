import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * F-005 RED → GREEN test — dependency pinning + lockfile presence + engines.
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-005-deps-pinning.md.
 *
 * Behavior contract (scoped to wave-013 / lane-b RED → GREEN flip):
 *   Every direct devDependency in the root `package.json` is exact-pinned —
 *   no `^`, `~`, or range operators. The repo ships a committed lockfile
 *   (`pnpm-lock.yaml` — pnpm chosen as v1 package manager per
 *   `pnpm-workspace.yaml` + existing lockfile). `engines.node` is specified
 *   so reproducible-build discipline ties to a known runtime floor.
 *
 * Out of scope at v1 (deferred per ledger out-of-scope-notes):
 *   - npm-style `package-lock.json` (we picked pnpm)
 *   - Cross-OS byte-identity verification (CI feature, M16)
 *   - Vulnerability scanning + Dependabot auto-PRs (M16 hardening)
 *   - Workspace package.json files (currently devDeps live at root only;
 *     packages/engine-core/package.json carries no devDeps so no pins to
 *     check — the test enumerates all package.json files and accepts an
 *     empty devDependencies object as trivially compliant).
 *
 * Acceptance scenarios mirrored from the F-005 ledger §Acceptance scenarios:
 *   1. Root package.json devDependencies are exact-pinned (scenario 1 from
 *      ledger: `"react": "^18.2.0"` would fail; we assert the inverse for
 *      every dep we ship).
 *   2. Lockfile is present at repo root (scenario 2 prerequisite — without
 *      a committed lockfile, `pnpm install --frozen-lockfile` cannot enforce
 *      reproducible installs).
 *   3. Engines.node is specified (scenario 3 prerequisite — reproducible
 *      installs require a known runtime floor).
 *
 * Cross-file consistency: every workspace package.json (root + packages/*)
 * is sweeped — all devDependencies / dependencies / peerDependencies must
 * be exact-pinned. workspace:* protocol values are skipped (they are
 * workspace-internal references resolved by pnpm at install time, not
 * versions).
 */

const repoRoot = join(__dirname, '..', '..');

interface PackageJson {
  name?: string;
  engines?: { node?: string };
  devDependencies?: Record<string, string>;
  dependencies?: Record<string, string>;
  peerDependencies?: Record<string, string>;
}

function loadPackageJson(path: string): PackageJson {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function isWorkspaceProtocol(version: string): boolean {
  return version.startsWith('workspace:');
}

function isExactPinned(version: string): boolean {
  // Reject leading range operators: ^, ~, >=, >, <=, <, ||, &&, x, *, latest
  // Accept: bare semver (1.2.3), pre-release (1.2.3-beta.1), pinned with build
  // metadata (1.2.3+build), git/file/http URLs (we use none of these in v1).
  return /^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$/.test(version);
}

describe('F-005 deps-pinning', () => {
  it('root package.json devDependencies are exact-pinned (no ^, ~, or range operators)', () => {
    const pkg = loadPackageJson(join(repoRoot, 'package.json'));
    const dev = pkg.devDependencies ?? {};
    const violations: string[] = [];
    for (const [name, version] of Object.entries(dev)) {
      if (isWorkspaceProtocol(version)) continue;
      if (!isExactPinned(version)) {
        violations.push(`${name}@${version}`);
      }
    }
    expect(
      violations,
      `Found range-pinned devDependencies (must be exact): ${violations.join(', ')}`,
    ).toEqual([]);
  });

  it('every workspace package.json (root + packages/*) has exact-pinned deps', () => {
    const pkgPaths = [
      join(repoRoot, 'package.json'),
      join(repoRoot, 'packages', 'engine-core', 'package.json'),
    ];
    const violations: string[] = [];
    for (const path of pkgPaths) {
      if (!existsSync(path)) continue;
      const pkg = loadPackageJson(path);
      const buckets: Array<[string, Record<string, string> | undefined]> = [
        ['devDependencies', pkg.devDependencies],
        ['dependencies', pkg.dependencies],
        ['peerDependencies', pkg.peerDependencies],
      ];
      for (const [bucketName, bucket] of buckets) {
        if (!bucket) continue;
        for (const [name, version] of Object.entries(bucket)) {
          if (isWorkspaceProtocol(version)) continue;
          if (!isExactPinned(version)) {
            violations.push(`${path} → ${bucketName}.${name}@${version}`);
          }
        }
      }
    }
    expect(
      violations,
      `Found range-pinned deps in workspace package.json files: ${violations.join('; ')}`,
    ).toEqual([]);
  });

  it('pnpm-lock.yaml exists at repo root (committed lockfile)', () => {
    expect(existsSync(join(repoRoot, 'pnpm-lock.yaml'))).toBe(true);
  });

  it('engines.node is specified in root package.json', () => {
    const pkg = loadPackageJson(join(repoRoot, 'package.json'));
    expect(pkg.engines?.node, 'engines.node missing — reproducible installs need a runtime floor').toBeDefined();
    expect(typeof pkg.engines?.node).toBe('string');
  });
});
