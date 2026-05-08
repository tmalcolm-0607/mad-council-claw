#!/usr/bin/env node
/**
 * Test fixture for block-smart-unicode-on-outbound.js
 *
 * Exercises:
 *   1. Outbound command + clean ASCII payload → exit 0 (allow)
 *   2. Outbound command + em-dash in payload → exit 2 (block)
 *   3. Outbound command + en-dash + ellipsis + smart quotes → exit 2 (block, all 3 listed)
 *   4. Non-outbound command + em-dash payload → exit 0 (don't block; not posting outbound)
 *   5. Outbound command + --allow-smart-unicode escape hatch → exit 0 (override)
 *   6. Inline -Content with smart-Unicode → exit 2 (block)
 *
 * Run: node .claude/hooks/__tests__/block-smart-unicode-on-outbound.test.js
 * Exit 0 = all pass; non-zero = first failing case.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.resolve(__dirname, '..', 'block-smart-unicode-on-outbound.js');
const TMP = path.resolve(__dirname, '..', '..', '..', '.mad', 'scratch', '_test-smart-unicode');

function setUp() {
  fs.mkdirSync(TMP, { recursive: true });
}

function runHook(toolInput) {
  const stdin = JSON.stringify({ tool_input: toolInput });
  const result = spawnSync('node', [HOOK], { input: stdin, encoding: 'utf8' });
  return { code: result.status, stderr: result.stderr || '', stdout: result.stdout || '' };
}

function writeFindings(name, comments) {
  const filePath = path.join(TMP, name);
  const findings = comments.map((c, i) => ({
    severity: 'CONSIDER',
    file: '/test.cs',
    line: i + 1,
    rule: 'test',
    confidence: 50,
    comment: c,
  }));
  fs.writeFileSync(filePath, JSON.stringify(findings, null, 2), 'utf8');
  return filePath;
}

const tests = [];
let passed = 0, failed = 0;

function test(name, fn) { tests.push({ name, fn }); }
function assert(cond, msg) { if (!cond) throw new Error(msg); }

// === Test cases ===

test('outbound command + clean ASCII payload allows', () => {
  const f = writeFindings('clean.json', ['regular ASCII comment with -- ascii dashes only']);
  const r = runHook({ command: `powershell.exe -NoProfile -File .mad/scripts/Post-ReviewFindings.ps1 -PrId 12345 -FindingsFile "${f}"` });
  assert(r.code === 0, `expected exit 0 (allow), got ${r.code}; stderr: ${r.stderr}`);
});

test('outbound command + em-dash blocks', () => {
  const f = writeFindings('em.json', ['comment with — em-dash inside']);
  const r = runHook({ command: `powershell.exe -NoProfile -File .mad/scripts/Post-ReviewFindings.ps1 -PrId 12345 -FindingsFile "${f}"` });
  assert(r.code === 2, `expected exit 2 (block), got ${r.code}`);
  assert(r.stderr.includes('em-dash'), `stderr should mention em-dash; got: ${r.stderr}`);
});

test('outbound command + multiple smart chars blocks with all listed', () => {
  const f = writeFindings('mix.json', ['comment with — and – and … and ‘smart’ and “fancy”']);
  const r = runHook({ command: `powershell.exe -NoProfile -File .mad/scripts/Post-ReviewFindings.ps1 -PrId 12345 -FindingsFile "${f}"` });
  assert(r.code === 2, `expected exit 2 (block), got ${r.code}`);
  for (const expected of ['em-dash', 'en-dash', 'ellipsis', 'single quote', 'double quote']) {
    assert(r.stderr.includes(expected), `stderr should mention ${expected}; got: ${r.stderr}`);
  }
});

test('non-outbound command + em-dash payload does NOT block', () => {
  const f = writeFindings('em.json', ['comment with — em-dash inside']);
  const r = runHook({ command: `cat ${f}` });
  assert(r.code === 0, `expected exit 0 (allow non-outbound), got ${r.code}; stderr: ${r.stderr}`);
});

test('outbound command + --allow-smart-unicode override allows', () => {
  const f = writeFindings('em.json', ['comment with — em-dash inside']);
  const r = runHook({ command: `powershell.exe -NoProfile -File .mad/scripts/Post-ReviewFindings.ps1 -PrId 12345 -FindingsFile "${f}" --allow-smart-unicode` });
  assert(r.code === 0, `expected exit 0 (override), got ${r.code}; stderr: ${r.stderr}`);
});

test('inline -Content with em-dash blocks', () => {
  const r = runHook({ command: `powershell.exe -NoProfile -File .mad/scripts/Ado-PR-Comment.ps1 -PrId 12345 -Action comment -Content "fix this — please"` });
  assert(r.code === 2, `expected exit 2 (block), got ${r.code}`);
  assert(r.stderr.includes('em-dash'), `stderr should mention em-dash; got: ${r.stderr}`);
});

test('az devops invoke POST with smart-Unicode in --in-file blocks', () => {
  const f = path.join(TMP, 'invoke-body.json');
  fs.writeFileSync(f, JSON.stringify({ comments: [{ content: 'review needs — fixing', commentType: 1 }] }), 'utf8');
  const r = runHook({ command: `az devops invoke --area git --resource pullRequestThreads --route-parameters project="X" repositoryId=Y pullRequestId=1 --http-method POST --api-version 7.0 --in-file "${f}"` });
  assert(r.code === 2, `expected exit 2 (block), got ${r.code}`);
});

test('missing FindingsFile path does not crash hook', () => {
  const r = runHook({ command: `powershell.exe -NoProfile -File .mad/scripts/Post-ReviewFindings.ps1 -PrId 12345 -FindingsFile /nonexistent/path.json` });
  assert(r.code === 0, `expected exit 0 (fail-open on missing file), got ${r.code}; stderr: ${r.stderr}`);
});

test('empty stdin does not crash hook', () => {
  const result = spawnSync('node', [HOOK], { input: '', encoding: 'utf8' });
  assert(result.status === 0, `expected exit 0 on empty stdin, got ${result.status}`);
});

// === Run ===

setUp();
for (const t of tests) {
  try {
    t.fn();
    passed++;
    console.log(`  PASS: ${t.name}`);
  } catch (e) {
    failed++;
    console.log(`  FAIL: ${t.name}\n        ${e.message}`);
  }
}

console.log(`\n${passed}/${passed + failed} tests passed`);
process.exit(failed === 0 ? 0 : 1);
