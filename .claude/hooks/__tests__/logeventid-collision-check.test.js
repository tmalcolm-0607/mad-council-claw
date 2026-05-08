/**
 * Tests for logeventid-collision-check.js
 *
 * Verifies:
 * 1. Exit 0 when file doesn't match trigger pattern
 * 2. Exit 0 when no collisions found (unique IDs)
 * 3. Exit 2 when collision found (duplicate EventId values)
 * 4. Exit 0 on scan error (fail-open)
 * 5. Handles Write tool input format
 * 6. Handles Edit tool input format
 */

const { runHook } = require('./test-helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

describe('logeventid-collision-check.js', () => {
  const hookPath = path.resolve(__dirname, '../logeventid-collision-check.js');

  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'logeventid-test-'));
    // Create a .git directory so the hook treats tmpDir as a repo root
    fs.mkdirSync(path.join(tmpDir, '.git'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  // -----------------------------------------------------------------------
  // Test 1: Non-matching file exits 0 immediately
  // -----------------------------------------------------------------------
  test('exits 0 when file does not match trigger pattern', async () => {
    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: 'C:/repo/src/Foo.cs',
        content: 'public class Foo {}'
      }
    };
    const result = await runHook(hookPath, input);

    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe('');
  });

  // -----------------------------------------------------------------------
  // Test 2: No collisions -- unique EventIds across files
  // -----------------------------------------------------------------------
  test('exits 0 when all EventIds are unique', async () => {
    // Create two files with unique IDs
    fs.writeFileSync(
      path.join(tmpDir, 'LogEventIds.cs'),
      [
        'public static class LogEventIds',
        '{',
        '    public const int Started = 1000;',
        '    public const int Stopped = 1001;',
        '}'
      ].join('\n')
    );

    fs.writeFileSync(
      path.join(tmpDir, 'OtherLogEventIds.cs'),
      [
        'public static class OtherLogEventIds',
        '{',
        '    public const int Connected = 2000;',
        '    public const int Disconnected = 2001;',
        '}'
      ].join('\n')
    );

    const filePath = path.join(tmpDir, 'LogEventIds.cs');
    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: filePath,
        content: 'does not matter -- hook reads from disk'
      }
    };

    const result = await runHook(hookPath, input);

    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 3: Collision detected -- same EventId value, different names
  // -----------------------------------------------------------------------
  test('exits 2 when collision found between different constant names', async () => {
    // Two files, both define EventId 1000 under different names
    fs.writeFileSync(
      path.join(tmpDir, 'LogEventIds.cs'),
      [
        'public static class LogEventIds',
        '{',
        '    public const int Started = 1000;',
        '}'
      ].join('\n')
    );

    fs.writeFileSync(
      path.join(tmpDir, 'MoreLogEventIds.cs'),
      [
        'public static class MoreLogEventIds',
        '{',
        '    public const int Initialized = 1000;',
        '}'
      ].join('\n')
    );

    const filePath = path.join(tmpDir, 'LogEventIds.cs');
    const input = {
      tool_name: 'Edit',
      tool_input: {
        file_path: filePath,
        old_string: 'Started = 1000',
        new_string: 'Started = 1000'
      }
    };

    const result = await runHook(hookPath, input);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain('LogEventId Collision');
    expect(result.stderr).toContain('1000');
  });

  // -----------------------------------------------------------------------
  // Test 4: Fail-open on scan error
  // -----------------------------------------------------------------------
  test('exits 0 on scan error (fail-open)', async () => {
    // Point to a non-existent directory so walkSync fails gracefully
    const filePath = path.join(tmpDir, 'nonexistent', 'deep', 'LogEventIds.cs');

    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: filePath,
        content: 'anything'
      }
    };

    const result = await runHook(hookPath, input);

    // Hook should fail-open (exit 0) because repo root resolution
    // will find .git in tmpDir or fall back, and the scan should
    // not crash. If it does error internally, it catches and exits 0.
    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 5: Handles Write tool input format
  // -----------------------------------------------------------------------
  test('handles Write tool input format (file_path + content)', async () => {
    fs.writeFileSync(
      path.join(tmpDir, 'LogMessages.cs'),
      [
        'public static partial class LogMessages',
        '{',
        '    [LoggerMessage(EventId = 5000, Level = LogLevel.Information, Message = "Hello")]',
        '    public static partial void SayHello(this ILogger logger);',
        '}'
      ].join('\n')
    );

    const filePath = path.join(tmpDir, 'LogMessages.cs');
    const input = {
      tool_name: 'Write',
      tool_input: {
        file_path: filePath,
        content: 'new content'
      }
    };

    const result = await runHook(hookPath, input);

    // No collision -- single file with one EventId
    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 6: Handles Edit tool input format
  // -----------------------------------------------------------------------
  test('handles Edit tool input format (file_path + old_string + new_string)', async () => {
    fs.writeFileSync(
      path.join(tmpDir, 'LogEventIds.cs'),
      [
        'public static class LogEventIds',
        '{',
        '    public const int Alpha = 100;',
        '}'
      ].join('\n')
    );

    const filePath = path.join(tmpDir, 'LogEventIds.cs');
    const input = {
      tool_name: 'Edit',
      tool_input: {
        file_path: filePath,
        old_string: 'Alpha = 100',
        new_string: 'Alpha = 200'
      }
    };

    const result = await runHook(hookPath, input);

    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 7: Same name in different files is NOT a collision
  // -----------------------------------------------------------------------
  test('does not flag same constant name in different files as collision', async () => {
    // LogEventIds.cs defines the constant, LogMessages.cs uses the same
    // numeric literal -- both have name "Started" at value 1000
    fs.writeFileSync(
      path.join(tmpDir, 'LogEventIds.cs'),
      [
        'public static class LogEventIds',
        '{',
        '    public const int Started = 1000;',
        '}'
      ].join('\n')
    );

    fs.writeFileSync(
      path.join(tmpDir, 'LogMessages.cs'),
      [
        'public static partial class LogMessages',
        '{',
        '    [LoggerMessage(EventId = 1000, Level = LogLevel.Information, Message = "Started")]',
        '    public static partial void Started(this ILogger logger);',
        '}'
      ].join('\n')
    );

    const filePath = path.join(tmpDir, 'LogEventIds.cs');
    const input = {
      tool_name: 'Edit',
      tool_input: {
        file_path: filePath,
        old_string: 'Started = 1000',
        new_string: 'Started = 1000'
      }
    };

    const result = await runHook(hookPath, input);

    expect(result.exitCode).toBe(0);
  });

  // -----------------------------------------------------------------------
  // Test 8: Empty stdin exits 0
  // -----------------------------------------------------------------------
  test('exits 0 on empty stdin', async () => {
    const { spawn } = require('child_process');

    const result = await new Promise((resolve) => {
      const child = spawn('node', [hookPath]);
      let stdout = '';
      let stderr = '';

      child.stdin.end();

      child.stdout.on('data', (d) => { stdout += d.toString(); });
      child.stderr.on('data', (d) => { stderr += d.toString(); });
      child.on('close', (exitCode) => { resolve({ stdout, stderr, exitCode }); });
    });

    expect(result.exitCode).toBe(0);
  });
});
