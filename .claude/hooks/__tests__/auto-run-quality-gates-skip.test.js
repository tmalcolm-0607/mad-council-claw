/**
 * Tests for auto-run-quality-gates.js — kit/spec-only + doc-only skip paths
 *
 * Added 2026-05-02 per iter15-hook-misfire fix (plan-backlog Entry 9).
 *
 * Verifies the two skip paths added so the PostToolUse gate runner does
 * NOT spawn Run-DotnetGates.ps1 when:
 *   1. The repo root has no .sln AND no .csproj (kit / spec-only repo), OR
 *   2. The triggering edit is doc-only (.md/.json/.yml/.yaml/.txt).
 *
 * Run standalone with:
 *   node .claude/hooks/__tests__/auto-run-quality-gates-skip.test.js
 *
 * (No package.json / jest in this repo — these tests use plain assertions
 *  so they run with vanilla node.)
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const {
  hasDotnetBuildTarget,
  isDocOnlyEdit,
  DOC_ONLY_EXTENSIONS,
} = require('../auto-run-quality-gates.js');

let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  PASS: ${name}`);
  } catch (err) {
    failed++;
    failures.push({ name, err });
    console.log(`  FAIL: ${name}\n    ${err.message}`);
  }
}

// --- hasDotnetBuildTarget ---

console.log('\nhasDotnetBuildTarget:');

test('returns false for empty directory (kit/spec-only shape)', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gates-test-empty-'));
  try {
    assert.strictEqual(hasDotnetBuildTarget(tmp), false);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('returns false for directory with only .md / .json files', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gates-test-docs-'));
  try {
    fs.writeFileSync(path.join(tmp, 'README.md'), '# kit');
    fs.writeFileSync(path.join(tmp, 'CLAUDE.md'), 'plan');
    fs.writeFileSync(path.join(tmp, 'config.json'), '{}');
    assert.strictEqual(hasDotnetBuildTarget(tmp), false);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('returns true when .sln present at root', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gates-test-sln-'));
  try {
    fs.writeFileSync(path.join(tmp, 'CMS.sln'), '');
    assert.strictEqual(hasDotnetBuildTarget(tmp), true);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('returns true when .csproj present at root (no .sln)', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gates-test-csproj-'));
  try {
    fs.writeFileSync(path.join(tmp, 'Api.csproj'), '');
    assert.strictEqual(hasDotnetBuildTarget(tmp), true);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('returns true with mixed .sln + .csproj at root', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gates-test-mixed-'));
  try {
    fs.writeFileSync(path.join(tmp, 'CMS.sln'), '');
    fs.writeFileSync(path.join(tmp, 'Api.csproj'), '');
    assert.strictEqual(hasDotnetBuildTarget(tmp), true);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('returns false for non-existent path (graceful failure)', () => {
  assert.strictEqual(hasDotnetBuildTarget('/nonexistent/xyz/path'), false);
});

test('does NOT recurse into subdirectories', () => {
  // Kit/spec repos may have .csproj files deep inside references/ — those
  // do not constitute a build target for THIS repo. Only root counts.
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gates-test-deep-'));
  try {
    const sub = path.join(tmp, 'references', 'LENS-DCS');
    fs.mkdirSync(sub, { recursive: true });
    fs.writeFileSync(path.join(sub, 'Some.csproj'), '');
    assert.strictEqual(hasDotnetBuildTarget(tmp), false);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

// --- isDocOnlyEdit ---

console.log('\nisDocOnlyEdit:');

test('returns true for .md file', () => {
  assert.strictEqual(isDocOnlyEdit('specs/15-collab-engine/plan.md'), true);
});

test('returns true for .json file', () => {
  assert.strictEqual(isDocOnlyEdit('config/settings.json'), true);
});

test('returns true for .yml file', () => {
  assert.strictEqual(isDocOnlyEdit('.github/workflows/ci.yml'), true);
});

test('returns true for .yaml file', () => {
  assert.strictEqual(isDocOnlyEdit('manifest.yaml'), true);
});

test('returns true for .txt file', () => {
  assert.strictEqual(isDocOnlyEdit('notes.txt'), true);
});

test('returns true regardless of extension case', () => {
  assert.strictEqual(isDocOnlyEdit('README.MD'), true);
  assert.strictEqual(isDocOnlyEdit('config.JSON'), true);
});

test('returns false for .cs file', () => {
  assert.strictEqual(isDocOnlyEdit('src/Api/Program.cs'), false);
});

test('returns false for .ts file', () => {
  assert.strictEqual(isDocOnlyEdit('frontend/src/App.ts'), false);
});

test('returns false for .tsx file', () => {
  assert.strictEqual(isDocOnlyEdit('frontend/src/App.tsx'), false);
});

test('returns false for .ps1 file', () => {
  assert.strictEqual(isDocOnlyEdit('scripts/Deploy.ps1'), false);
});

test('returns false for empty / null filePath', () => {
  assert.strictEqual(isDocOnlyEdit(''), false);
  assert.strictEqual(isDocOnlyEdit(null), false);
  assert.strictEqual(isDocOnlyEdit(undefined), false);
});

// --- DOC_ONLY_EXTENSIONS shape ---

console.log('\nDOC_ONLY_EXTENSIONS:');

test('exposes the expected extension allowlist', () => {
  assert.ok(DOC_ONLY_EXTENSIONS instanceof Set);
  assert.ok(DOC_ONLY_EXTENSIONS.has('.md'));
  assert.ok(DOC_ONLY_EXTENSIONS.has('.json'));
  assert.ok(DOC_ONLY_EXTENSIONS.has('.yml'));
  assert.ok(DOC_ONLY_EXTENSIONS.has('.yaml'));
  assert.ok(DOC_ONLY_EXTENSIONS.has('.txt'));
  assert.ok(!DOC_ONLY_EXTENSIONS.has('.cs'));
  assert.ok(!DOC_ONLY_EXTENSIONS.has('.tsx'));
});

// --- Summary ---

console.log(`\n${passed} passed, ${failed} failed (${passed + failed} total)\n`);

if (failed > 0) {
  for (const f of failures) {
    console.log(`FAIL ${f.name}: ${f.err.stack || f.err.message}`);
  }
  process.exit(1);
}

process.exit(0);
