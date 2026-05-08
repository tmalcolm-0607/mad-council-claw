/**
 * Tests for capture-learning.js
 *
 * Specifically targets the "useless empty-signature failure entries" bug:
 *   prior to the fix, every Bash failure that didn't expose a recognized
 *   error pattern produced an entry with signature: "unknown" and
 *   sample_error: "". failures.json accumulated 3,418 such rows that
 *   all collapsed into a single noise bucket.
 *
 * Verifies:
 * 1. Bash payload with stderr "FAILED tests/foo.test.js" produces a
 *    non-empty signature and writes a real entry.
 * 2. Bash payload with empty output does NOT write any entry.
 * 3. Bash payload that exposes stderr only via tool_response.stderr
 *    is still extracted (the original bug).
 * 4. extractErrorSignature behaviour for known patterns is preserved.
 */

const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

const hookPath = path.resolve(__dirname, '../capture-learning.js');
const {
  extractErrorSignature,
  extractErrorText,
  captureFailurePattern
} = require('../capture-learning.js');

/**
 * Run the hook with cwd pointed at a tmpDir that contains a .claude/
 * directory, so getProjectDir() resolves there. Returns parsed
 * failures.json (or null if not written).
 */
function runHookInTmpDir(tmpDir, inputJSON) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [hookPath], { cwd: tmpDir });
    let stdout = '';
    let stderr = '';
    child.stdin.write(JSON.stringify(inputJSON));
    child.stdin.end();
    child.stdout.on('data', (d) => { stdout += d.toString(); });
    child.stderr.on('data', (d) => { stderr += d.toString(); });
    child.on('close', (exitCode) => {
      const failuresPath = path.join(tmpDir, '.mad', 'learning', 'failures.json');
      const failures = fs.existsSync(failuresPath)
        ? JSON.parse(fs.readFileSync(failuresPath, 'utf8'))
        : null;
      resolve({ stdout, stderr, exitCode, failures });
    });
    child.on('error', (err) => { reject(err); });
  });
}

describe('capture-learning.js', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'capture-learning-test-'));
    fs.mkdirSync(path.join(tmpDir, '.claude'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  // ---------------------------------------------------------------------
  // Test 1: real stderr produces a real signature
  // ---------------------------------------------------------------------
  test('Bash failure with stderr produces a non-empty signature', async () => {
    const input = {
      hook_event_name: 'PostToolUse',
      tool_name: 'Bash',
      exit_code: 1,
      tool_input: { command: 'npm test' },
      tool_response: {
        stderr: 'FAILED tests/foo.test.js\nexpected 1 to equal 2'
      }
    };

    const result = await runHookInTmpDir(tmpDir, input);

    expect(result.exitCode).toBe(0);
    expect(result.failures).not.toBeNull();
    expect(result.failures.failures.length).toBe(1);
    const entry = result.failures.failures[0];
    expect(entry.pattern.error_signature).not.toBe('unknown');
    expect(entry.pattern.error_signature).not.toBe('');
    expect(entry.pattern.sample_error).not.toBe('');
    expect(entry.pattern.sample_error).toContain('FAILED');
  });

  // ---------------------------------------------------------------------
  // Test 2: empty payload does NOT write an entry (the bug)
  // ---------------------------------------------------------------------
  test('Bash failure with no stderr/stdout does NOT write an entry', async () => {
    const input = {
      hook_event_name: 'PostToolUse',
      tool_name: 'Bash',
      exit_code: 1,
      tool_input: { command: 'npm test' },
      tool_response: {}
    };

    const result = await runHookInTmpDir(tmpDir, input);

    expect(result.exitCode).toBe(0);
    // Either no failures.json was written, or it was written but the
    // failures array stayed empty. Both are acceptable; the key assertion
    // is that no "unknown"/"" noise entry was added.
    if (result.failures !== null) {
      expect(result.failures.failures.length).toBe(0);
    }
  });

  // ---------------------------------------------------------------------
  // Test 3: stderr nested under tool_response is extracted
  // ---------------------------------------------------------------------
  test('extractErrorText reads tool_response.stderr (the original bug)', () => {
    const data = {
      tool_response: { stderr: 'Build FAILED\nerror CS1002' }
    };
    expect(extractErrorText(data)).toContain('Build FAILED');
  });

  // ---------------------------------------------------------------------
  // Test 4: extractErrorText prefers stderr over stdout
  // ---------------------------------------------------------------------
  test('extractErrorText prefers stderr over stdout', () => {
    const data = {
      tool_response: { stdout: 'should be ignored', stderr: 'real error' }
    };
    expect(extractErrorText(data)).toBe('real error');
  });

  // ---------------------------------------------------------------------
  // Test 5: extractErrorText handles old-shape payloads
  // ---------------------------------------------------------------------
  test('extractErrorText falls back to legacy data.tool_output', () => {
    expect(extractErrorText({ tool_output: 'legacy err' })).toBe('legacy err');
  });

  // ---------------------------------------------------------------------
  // Test 6: extractErrorText returns '' on truly empty input
  // ---------------------------------------------------------------------
  test('extractErrorText returns empty string on empty input', () => {
    expect(extractErrorText({})).toBe('');
    expect(extractErrorText({ tool_response: {} })).toBe('');
    expect(extractErrorText({ tool_response: { stderr: '' } })).toBe('');
    expect(extractErrorText({ tool_response: { stderr: '   ' } })).toBe('');
  });

  // ---------------------------------------------------------------------
  // Test 7: extractErrorSignature still recognizes known patterns
  // ---------------------------------------------------------------------
  test('extractErrorSignature still classifies known patterns', () => {
    expect(extractErrorSignature('Build FAILED')).toBe('build_failed');
    expect(extractErrorSignature('Test Failed: foo')).toBe('test_failed');
    expect(extractErrorSignature('Cannot find module \'./missing\''))
      .toBe('module_not_found');
    expect(extractErrorSignature('')).toBe('unknown');
  });

  // ---------------------------------------------------------------------
  // Test 8: SubagentStop with no error is not classified as failure
  //         (regression check — make sure the success path still works)
  // ---------------------------------------------------------------------
  test('SubagentStop with no error does not write a failure entry', async () => {
    const input = {
      hook_event_name: 'SubagentStop',
      subagentType: 'code-investigator',
      tokens_used: 5000,
      duration_ms: 30000
    };

    const result = await runHookInTmpDir(tmpDir, input);

    expect(result.exitCode).toBe(0);
    if (result.failures !== null) {
      expect(result.failures.failures.length).toBe(0);
    }
  });
});
