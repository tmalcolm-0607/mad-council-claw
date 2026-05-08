#!/usr/bin/env node
/**
 * Tests for detect-anomaly.js
 *
 * Covers two bug fixes (loop-iter2-audit Lane B):
 *   B1 — PostToolUse exit-code overcounting: `grep` exit 1 must NOT trip
 *        consecutiveFailures; `dotnet test` exit 1 MUST trip it.
 *   B2 — OVERPLANNING ledger never decays: a Write/Edit/Bash tool must
 *        clear `OVERPLANNING_*` entries from `anomaliesDetected` AND from
 *        `anomalyLedger`.
 *
 * Plus regression coverage:
 *   - Hook still exits 0 on a sample PostToolUse payload (fail-open).
 *   - DEFAULT_THRESHOLDS unchanged (anomaly-thresholds.md is the contract).
 *
 * Runner: this file is a self-contained Node script (no jest dependency).
 *   node .claude/hooks/__tests__/detect-anomaly.test.js
 *
 * It also defines describe/test/expect shims at the bottom when run under
 * `node` directly so it doubles as a Jest spec.
 */

'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawnSync } = require('child_process');

const HOOK_PATH = path.resolve(__dirname, '..', 'detect-anomaly.js');
const hook = require(HOOK_PATH);

// -----------------------------------------------------------------------------
// Tiny test harness — works standalone OR under Jest.
// -----------------------------------------------------------------------------
const isJest = typeof global.test === 'function' && typeof global.expect === 'function';

const failures = [];
let currentSuite = '';
function _describe(name, fn) {
  const prev = currentSuite;
  currentSuite = prev ? `${prev} > ${name}` : name;
  try { fn(); } finally { currentSuite = prev; }
}
function _test(name, fn) {
  const label = currentSuite ? `${currentSuite} :: ${name}` : name;
  try {
    const result = fn();
    if (result && typeof result.then === 'function') {
      // Async tests not used in this file; would need awaiting in main().
      throw new Error(`Async test "${label}" requires Jest runner.`);
    }
    process.stdout.write(`  PASS  ${label}\n`);
  } catch (err) {
    failures.push({ label, err });
    process.stdout.write(`  FAIL  ${label}\n        ${err.message}\n`);
  }
}
function _expect(actual) {
  return {
    toBe(expected) {
      if (actual !== expected) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
    toEqual(expected) {
      if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
    toBeTruthy() {
      if (!actual) throw new Error(`Expected truthy, got ${JSON.stringify(actual)}`);
    },
    toBeFalsy() {
      if (actual) throw new Error(`Expected falsy, got ${JSON.stringify(actual)}`);
    },
    toContain(item) {
      if (!Array.isArray(actual) && typeof actual !== 'string') {
        throw new Error(`Expected array or string, got ${typeof actual}`);
      }
      if (!actual.includes(item)) {
        throw new Error(`Expected ${JSON.stringify(actual)} to contain ${JSON.stringify(item)}`);
      }
    },
    not: {
      toContain(item) {
        if (Array.isArray(actual) && actual.includes(item)) {
          throw new Error(`Expected ${JSON.stringify(actual)} NOT to contain ${JSON.stringify(item)}`);
        }
        if (typeof actual === 'string' && actual.includes(item)) {
          throw new Error(`Expected ${JSON.stringify(actual)} NOT to contain ${JSON.stringify(item)}`);
        }
      }
    }
  };
}

const describe = isJest ? global.describe : _describe;
const test = isJest ? global.test : _test;
const expect = isJest ? global.expect : _expect;

// -----------------------------------------------------------------------------
// Bug 1 — PostToolUse exit-code overcounting (B1)
// -----------------------------------------------------------------------------
describe('Bug 1 — Bash exit-code overcounting (B1)', () => {

  test('grep with no matches (exit 1) is NOT a real failure', () => {
    const data = {
      hook_event_name: 'PostToolUse',
      tool_name: 'Bash',
      tool_input: { command: "grep -E 'nope' file.txt" },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(false);
  });

  test('git diff --quiet (exit 1) is NOT a real failure', () => {
    const data = {
      hook_event_name: 'PostToolUse',
      tool_name: 'Bash',
      tool_input: { command: 'git diff --quiet' },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(false);
  });

  test('test/[ boolean check (exit 1) is NOT a real failure', () => {
    const data = {
      hook_event_name: 'PostToolUse',
      tool_name: 'Bash',
      tool_input: { command: '[ -f /nope/file ]' },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(false);
  });

  test('dotnet test (exit 1) IS a real failure', () => {
    const data = {
      hook_event_name: 'PostToolUse',
      tool_name: 'Bash',
      tool_input: { command: 'dotnet test sources/test/CMS/src/Common.Tests/Common.Tests.csproj' },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(true);
  });

  test('dotnet build (exit 1) IS a real failure', () => {
    const data = {
      tool_input: { command: 'dotnet build CMS.sln' },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(true);
  });

  test('npm test (exit 1) IS a real failure', () => {
    const data = {
      tool_input: { command: 'npm test --silent' },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(true);
  });

  test('pytest (exit 1) IS a real failure', () => {
    const data = {
      tool_input: { command: 'pytest tests/ -v' },
      exit_code: 1
    };
    expect(hook.isRealFailure(data, 'Bash', 1)).toBe(true);
  });

  test('Bash exit 0 on a build command IS a real success', () => {
    const data = {
      tool_input: { command: 'dotnet test CMS.sln' },
      exit_code: 0
    };
    expect(hook.isRealSuccess(data, 'Bash', 0)).toBe(true);
  });

  test('Bash exit 0 on a grep does NOT count as success (no reset)', () => {
    const data = {
      tool_input: { command: 'grep -r foo .' },
      exit_code: 0
    };
    // Conservative: a benign grep success should not erase a prior real failure streak.
    expect(hook.isRealSuccess(data, 'Bash', 0)).toBe(false);
  });

  test('Task tool with explicit failure marker IS a failure', () => {
    expect(hook.isRealFailure({ is_error: true }, 'Task', 0)).toBe(true);
    expect(hook.isRealFailure({ failed: true }, 'Task', 0)).toBe(true);
  });

  test('Task tool with no failure marker is NOT a failure', () => {
    expect(hook.isRealFailure({}, 'Task', 0)).toBe(false);
  });

  test('Write tool exit 1 with error message IS a failure', () => {
    const data = { error: 'Permission denied', exit_code: 1 };
    expect(hook.isRealFailure(data, 'Write', 1)).toBe(true);
  });

  test('Write tool exit 1 with no error is NOT a failure', () => {
    expect(hook.isRealFailure({ exit_code: 1 }, 'Write', 1)).toBe(false);
  });

  test('Read tool exit 1 is NOT a failure', () => {
    expect(hook.isRealFailure({}, 'Read', 1)).toBe(false);
  });
});

// -----------------------------------------------------------------------------
// Bug 2 — OVERPLANNING ledger decay on write tool (B2)
// -----------------------------------------------------------------------------
describe('Bug 2 — OVERPLANNING ledger decay (B2)', () => {

  // Use a temporary state file to avoid touching the real one.
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'detect-anomaly-test-'));
  const tmpClaude = path.join(tmpRoot, '.claude');
  fs.mkdirSync(tmpClaude, { recursive: true });
  fs.mkdirSync(path.join(tmpRoot, '.mad', 'scratch'), { recursive: true });

  test('Write tool clears OVERPLANNING_* from anomaliesDetected', () => {
    // Spawn the hook with a state file already polluted with OVERPLANNING entries.
    const stateDir = path.join(tmpRoot, '.mad', 'scratch');
    const statePath = path.join(stateDir, 'anomaly-state.json');
    const sessionId = 'test-session-b2-' + Date.now();
    const initialState = {
      sessionId,
      startTime: Date.now(),
      promptTimes: [],
      agentSpawns: [],
      consecutiveFailures: 0,
      totalTokens: 0,
      promptCount: 0,
      anomaliesDetected: ['OVERPLANNING_8', 'OVERPLANNING_9', 'OVERPLANNING_15', 'LONG_SESSION'],
      toolUses: [],
      anomalyLedger: {
        'OVERPLANNING|some normalized message': { lastEmittedAt: Date.now(), suppressedCount: 3 },
        'EXCESSIVE_SPAWNS|other': { lastEmittedAt: Date.now(), suppressedCount: 0 }
      }
    };
    fs.writeFileSync(statePath, JSON.stringify(initialState, null, 2));

    const payload = {
      session_id: sessionId,
      hook_event_name: 'PostToolUse',
      tool_name: 'Write',
      tool_input: { file_path: 'src/foo.cs' },
      exit_code: 0
    };
    const result = spawnSync('node', [HOOK_PATH], {
      input: JSON.stringify(payload),
      cwd: tmpRoot,
      encoding: 'utf8'
    });
    expect(result.status).toBe(0);

    const after = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    expect(after.anomaliesDetected.includes('OVERPLANNING_8')).toBe(false);
    expect(after.anomaliesDetected.includes('OVERPLANNING_9')).toBe(false);
    expect(after.anomaliesDetected.includes('OVERPLANNING_15')).toBe(false);
    // Non-OVERPLANNING entries must be preserved.
    expect(after.anomaliesDetected.includes('LONG_SESSION')).toBe(true);
    // Ledger: OVERPLANNING fingerprint cleared, others preserved.
    expect(Object.keys(after.anomalyLedger || {}).some(k => k.startsWith('OVERPLANNING|'))).toBe(false);
    expect(Object.keys(after.anomalyLedger || {}).some(k => k.startsWith('EXCESSIVE_SPAWNS|'))).toBe(true);
  });

  test('Edit tool also clears OVERPLANNING_*', () => {
    const stateDir = path.join(tmpRoot, '.mad', 'scratch');
    const statePath = path.join(stateDir, 'anomaly-state.json');
    const sessionId = 'test-session-b2-edit-' + Date.now();
    fs.writeFileSync(statePath, JSON.stringify({
      sessionId,
      startTime: Date.now(),
      promptTimes: [],
      agentSpawns: [],
      consecutiveFailures: 0,
      totalTokens: 0,
      promptCount: 0,
      anomaliesDetected: ['OVERPLANNING_42'],
      toolUses: [],
      anomalyLedger: {}
    }, null, 2));

    const payload = {
      session_id: sessionId,
      hook_event_name: 'PostToolUse',
      tool_name: 'Edit',
      exit_code: 0
    };
    const result = spawnSync('node', [HOOK_PATH], {
      input: JSON.stringify(payload),
      cwd: tmpRoot,
      encoding: 'utf8'
    });
    expect(result.status).toBe(0);

    const after = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    expect(after.anomaliesDetected.includes('OVERPLANNING_42')).toBe(false);
  });

  test('Read tool does NOT clear OVERPLANNING_*', () => {
    const stateDir = path.join(tmpRoot, '.mad', 'scratch');
    const statePath = path.join(stateDir, 'anomaly-state.json');
    const sessionId = 'test-session-b2-read-' + Date.now();
    fs.writeFileSync(statePath, JSON.stringify({
      sessionId,
      startTime: Date.now(),
      promptTimes: [],
      agentSpawns: [],
      consecutiveFailures: 0,
      totalTokens: 0,
      promptCount: 0,
      anomaliesDetected: ['OVERPLANNING_8'],
      toolUses: [],
      anomalyLedger: {}
    }, null, 2));

    const payload = {
      session_id: sessionId,
      hook_event_name: 'PostToolUse',
      tool_name: 'Read',
      exit_code: 0
    };
    const result = spawnSync('node', [HOOK_PATH], {
      input: JSON.stringify(payload),
      cwd: tmpRoot,
      encoding: 'utf8'
    });
    expect(result.status).toBe(0);

    const after = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    expect(after.anomaliesDetected.includes('OVERPLANNING_8')).toBe(true);
  });
});

// -----------------------------------------------------------------------------
// Regression: hook still exits 0 on a vanilla PostToolUse payload (fail-open).
// -----------------------------------------------------------------------------
describe('Regression — fail-open behavior', () => {

  test('hook exits 0 on a sample PostToolUse payload', () => {
    const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'detect-anomaly-failopen-'));
    fs.mkdirSync(path.join(tmpRoot, '.claude'), { recursive: true });
    fs.mkdirSync(path.join(tmpRoot, '.mad', 'scratch'), { recursive: true });

    const result = spawnSync('node', [HOOK_PATH], {
      input: JSON.stringify({
        session_id: 'failopen-' + Date.now(),
        hook_event_name: 'PostToolUse',
        tool_name: 'Bash',
        tool_input: { command: 'echo hi' },
        exit_code: 0
      }),
      cwd: tmpRoot,
      encoding: 'utf8'
    });
    expect(result.status).toBe(0);
  });

  test('hook exits 0 on malformed input', () => {
    const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'detect-anomaly-malformed-'));
    fs.mkdirSync(path.join(tmpRoot, '.claude'), { recursive: true });

    const result = spawnSync('node', [HOOK_PATH], {
      input: 'not json{{{',
      cwd: tmpRoot,
      encoding: 'utf8'
    });
    expect(result.status).toBe(0);
  });

  test('hook exits 0 on empty input', () => {
    const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'detect-anomaly-empty-'));
    fs.mkdirSync(path.join(tmpRoot, '.claude'), { recursive: true });

    const result = spawnSync('node', [HOOK_PATH], {
      input: '',
      cwd: tmpRoot,
      encoding: 'utf8'
    });
    expect(result.status).toBe(0);
  });

  test('DEFAULT_THRESHOLDS contract preserved', () => {
    expect(hook.DEFAULT_THRESHOLDS.consecutive_failures).toBe(3);
    expect(hook.DEFAULT_THRESHOLDS.planning_turns_without_write).toBe(8);
    expect(hook.DEFAULT_THRESHOLDS.spawns_per_hour).toBe(10);
  });
});

// -----------------------------------------------------------------------------
// Standalone runner — print summary and exit non-zero on any failures so CI
// can pick up regressions.
// -----------------------------------------------------------------------------
if (!isJest) {
  if (failures.length === 0) {
    process.stdout.write(`\nAll detect-anomaly tests passed.\n`);
    process.exit(0);
  } else {
    process.stdout.write(`\n${failures.length} detect-anomaly test(s) FAILED.\n`);
    process.exit(1);
  }
}
