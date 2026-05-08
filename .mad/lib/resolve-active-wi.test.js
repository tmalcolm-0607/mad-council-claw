'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { resolveActiveWI } = require('./resolve-active-wi.js');

function makeTempProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mad-resolve-wi-'));
  fs.mkdirSync(path.join(dir, '.claude', 'work-items'), { recursive: true });
  return dir;
}

function cleanup(dir) {
  try {
    fs.rmSync(dir, { recursive: true, force: true });
  } catch {
    // best-effort
  }
}

test('returns null when ACTIVE file is missing', () => {
  const dir = makeTempProject();
  try {
    const result = resolveActiveWI(null, dir);
    assert.deepEqual(result, { wiId: null });
  } finally {
    cleanup(dir);
  }
});

test('returns null when ACTIVE file is empty', () => {
  const dir = makeTempProject();
  try {
    fs.writeFileSync(path.join(dir, '.claude', 'work-items', 'ACTIVE'), '');
    const result = resolveActiveWI(null, dir);
    assert.deepEqual(result, { wiId: null });
  } finally {
    cleanup(dir);
  }
});

test('returns null when ACTIVE file is whitespace only', () => {
  const dir = makeTempProject();
  try {
    fs.writeFileSync(path.join(dir, '.claude', 'work-items', 'ACTIVE'), '   \n\t  ');
    const result = resolveActiveWI(null, dir);
    assert.deepEqual(result, { wiId: null });
  } finally {
    cleanup(dir);
  }
});

test('returns trimmed wiId when ACTIVE file has content', () => {
  const dir = makeTempProject();
  try {
    fs.writeFileSync(
      path.join(dir, '.claude', 'work-items', 'ACTIVE'),
      'WI-20260502-1200-test-feature\n'
    );
    const result = resolveActiveWI(null, dir);
    assert.deepEqual(result, { wiId: 'WI-20260502-1200-test-feature' });
  } finally {
    cleanup(dir);
  }
});

test('returns wiId without trailing whitespace', () => {
  const dir = makeTempProject();
  try {
    fs.writeFileSync(
      path.join(dir, '.claude', 'work-items', 'ACTIVE'),
      '  WI-20260502-1200-foo  \r\n'
    );
    const result = resolveActiveWI(null, dir);
    assert.deepEqual(result, { wiId: 'WI-20260502-1200-foo' });
  } finally {
    cleanup(dir);
  }
});

test('falls back to process.cwd() when projectDir absent', () => {
  const dir = makeTempProject();
  const originalCwd = process.cwd();
  try {
    process.chdir(dir);
    fs.writeFileSync(
      path.join(dir, '.claude', 'work-items', 'ACTIVE'),
      'WI-cwd-fallback'
    );
    const result = resolveActiveWI(null);
    assert.deepEqual(result, { wiId: 'WI-cwd-fallback' });
  } finally {
    process.chdir(originalCwd);
    cleanup(dir);
  }
});

test('never throws on bogus projectDir', () => {
  const result = resolveActiveWI(null, '/this/path/does/not/exist/anywhere/xyz');
  assert.deepEqual(result, { wiId: null });
});

test('never throws when called with no arguments', () => {
  // Should fall back to cwd; result varies but call must not throw
  assert.doesNotThrow(() => resolveActiveWI());
});

test('never throws when data argument is malformed', () => {
  const dir = makeTempProject();
  try {
    fs.writeFileSync(path.join(dir, '.claude', 'work-items', 'ACTIVE'), 'WI-x');
    // data is unused today but contract requires not throwing on any shape
    const result = resolveActiveWI({ random: 'shape' }, dir);
    assert.deepEqual(result, { wiId: 'WI-x' });
  } finally {
    cleanup(dir);
  }
});
