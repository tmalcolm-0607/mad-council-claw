/**
 * Tests for nowarn-addition-warning.js
 *
 * Verifies:
 * 1. Exit 0 when file doesn't match pattern (not .csproj/.props)
 * 2. Exit 0 with no stderr when no NoWarn changes
 * 3. Exit 0 with advisory stderr when NoWarn is added to .csproj
 * 4. Exit 0 on error (fail-open)
 * 5. Session dedup: second call for same file produces no warning
 */

const { runHook } = require('./test-helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

describe('nowarn-addition-warning.js', () => {
  const hookPath = path.resolve(__dirname, '../nowarn-addition-warning.js');

  let tmpDir;
  let statePath;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'nowarn-test-'));
    // Create .claude directory so getProjectDir() resolves to tmpDir
    fs.mkdirSync(path.join(tmpDir, '.claude'));
    // Create .mad/scratch for state file
    fs.mkdirSync(path.join(tmpDir, '.mad', 'scratch'), { recursive: true });
    statePath = path.join(tmpDir, '.mad', 'scratch', 'nowarn-state.json');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  /**
   * Helper: run the hook with cwd set to tmpDir so getProjectDir() finds .claude there.
   */
  function runHookInTmpDir(inputJSON) {
    return new Promise((resolve, reject) => {
      const { spawn } = require('child_process');
      const child = spawn('node', [hookPath], { cwd: tmpDir });
      let stdout = '';
      let stderr = '';

      child.stdin.write(JSON.stringify(inputJSON));
      child.stdin.end();

      child.stdout.on('data', (d) => { stdout += d.toString(); });
      child.stderr.on('data', (d) => { stderr += d.toString(); });
      child.on('close', (exitCode) => { resolve({ stdout, stderr, exitCode }); });
      child.on('error', (err) => { reject(err); });
    });
  }

  // -----------------------------------------------------------------------
  // Test 1: Non-matching file exits 0 with no stderr
  // -----------------------------------------------------------------------
  test('exits 0 when file does not match .csproj or .props', async () => {
    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: 'C:/repo/src/Foo.cs',
        content: '<NoWarn>CS1591</NoWarn>'
      },
      session_id: 'test-session-1'
    };

    const result = await runHookInTmpDir(input);

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe('');
  });

  // -----------------------------------------------------------------------
  // Test 2: No NoWarn changes -- exit 0, no warning
  // -----------------------------------------------------------------------
  test('exits 0 with no stderr when Write has no NoWarn content', async () => {
    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: path.join(tmpDir, 'MyProject.csproj'),
        content: '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>'
      },
      session_id: 'test-session-2'
    };

    const result = await runHookInTmpDir(input);

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe('');
  });

  // -----------------------------------------------------------------------
  // Test 3: NoWarn added to .csproj -- exit 0 with advisory stderr
  // -----------------------------------------------------------------------
  test('exits 0 with advisory when NoWarn is added to .csproj via Write', async () => {
    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: path.join(tmpDir, 'MyProject.csproj'),
        content: '<Project><PropertyGroup><NoWarn>CS1591;NU1900</NoWarn></PropertyGroup></Project>'
      },
      session_id: 'test-session-3'
    };

    const result = await runHookInTmpDir(input);

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toContain('[NoWarn Advisory]');
    expect(result.stderr).toContain('MyProject.csproj');
    expect(result.stderr).toContain('#pragma warning disable');
  });

  // -----------------------------------------------------------------------
  // Test 3b: NoWarn added via Edit (new_string introduces NoWarn)
  // -----------------------------------------------------------------------
  test('exits 0 with advisory when NoWarn is added via Edit', async () => {
    const input = {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(tmpDir, 'Directory.Build.props'),
        old_string: '<TargetFramework>net8.0</TargetFramework>',
        new_string: '<TargetFramework>net8.0</TargetFramework>\n    <NoWarn>NU1900</NoWarn>'
      },
      session_id: 'test-session-3b'
    };

    const result = await runHookInTmpDir(input);

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toContain('[NoWarn Advisory]');
    expect(result.stderr).toContain('Directory.Build.props');
  });

  // -----------------------------------------------------------------------
  // Test 3c: NoWarn expanded via Edit (both old and new have NoWarn, but new is longer)
  // -----------------------------------------------------------------------
  test('exits 0 with advisory when NoWarn is expanded via Edit', async () => {
    const input = {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(tmpDir, 'MyProject.csproj'),
        old_string: '<NoWarn>CS1591</NoWarn>',
        new_string: '<NoWarn>CS1591;NU1900</NoWarn>'
      },
      session_id: 'test-session-3c'
    };

    const result = await runHookInTmpDir(input);

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toContain('[NoWarn Advisory]');
  });

  // -----------------------------------------------------------------------
  // Test 4: Fail-open on error
  // -----------------------------------------------------------------------
  test('exits 0 on malformed JSON (fail-open)', async () => {
    const { spawn } = require('child_process');

    const result = await new Promise((resolve) => {
      const child = spawn('node', [hookPath], { cwd: tmpDir });
      let stdout = '';
      let stderr = '';

      child.stdin.write('not valid json{{{');
      child.stdin.end();

      child.stdout.on('data', (d) => { stdout += d.toString(); });
      child.stderr.on('data', (d) => { stderr += d.toString(); });
      child.on('close', (exitCode) => { resolve({ stdout, stderr, exitCode }); });
    });

    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 4b: Fail-open on empty stdin
  // -----------------------------------------------------------------------
  test('exits 0 on empty stdin (fail-open)', async () => {
    const { spawn } = require('child_process');

    const result = await new Promise((resolve) => {
      const child = spawn('node', [hookPath], { cwd: tmpDir });
      let stdout = '';
      let stderr = '';

      child.stdin.end();

      child.stdout.on('data', (d) => { stdout += d.toString(); });
      child.stderr.on('data', (d) => { stderr += d.toString(); });
      child.on('close', (exitCode) => { resolve({ stdout, stderr, exitCode }); });
    });

    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 5: Session dedup -- second call for same file produces no warning
  // -----------------------------------------------------------------------
  test('suppresses warning on second call for same file in same session', async () => {
    const sessionId = 'test-session-dedup';
    const filePath = path.join(tmpDir, 'MyProject.csproj');

    const makeInput = () => ({
      tool_name: 'Write',
      tool_input: {
        file_path: filePath,
        content: '<Project><PropertyGroup><NoWarn>CS1591</NoWarn></PropertyGroup></Project>'
      },
      session_id: sessionId
    });

    // First call: should warn
    const result1 = await runHookInTmpDir(makeInput());
    expect(result1.exitCode).toBe(0);
    expect(result1.stderr).toContain('[NoWarn Advisory]');

    // Second call: same file, same session -- should NOT warn
    const result2 = await runHookInTmpDir(makeInput());
    expect(result2.exitCode).toBe(0);
    expect(result2.stderr).toBe('');
  });

  // -----------------------------------------------------------------------
  // Test 5b: Different session ID resets dedup
  // -----------------------------------------------------------------------
  test('warns again when session ID changes', async () => {
    const filePath = path.join(tmpDir, 'MyProject.csproj');

    const makeInput = (sessionId) => ({
      tool_name: 'Write',
      tool_input: {
        file_path: filePath,
        content: '<Project><PropertyGroup><NoWarn>CS1591</NoWarn></PropertyGroup></Project>'
      },
      session_id: sessionId
    });

    // First call with session A
    const result1 = await runHookInTmpDir(makeInput('session-A'));
    expect(result1.exitCode).toBe(0);
    expect(result1.stderr).toContain('[NoWarn Advisory]');

    // Second call with session B (different session) -- should warn again
    const result2 = await runHookInTmpDir(makeInput('session-B'));
    expect(result2.exitCode).toBe(0);
    expect(result2.stderr).toContain('[NoWarn Advisory]');
  });

  // -----------------------------------------------------------------------
  // Test 6: Edit with NoWarn in both old and new but same length -- no warning
  // -----------------------------------------------------------------------
  test('no warning when NoWarn unchanged in Edit (same content)', async () => {
    const input = {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(tmpDir, 'MyProject.csproj'),
        old_string: '<NoWarn>CS1591</NoWarn>',
        new_string: '<NoWarn>NU1900</NoWarn>'
      },
      session_id: 'test-session-same-len'
    };

    const result = await runHookInTmpDir(input);

    // Same length NoWarn content -- hook sees no expansion
    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe('');
  });
});
