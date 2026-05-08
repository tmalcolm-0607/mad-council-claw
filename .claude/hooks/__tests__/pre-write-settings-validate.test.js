/**
 * Tests for pre-write-settings-validate.js
 *
 * Verifies layer 3 of the iter8-settings-mystery defense:
 * 1. Ask permission decision when Write payload introduces absolute Windows
 *    hook path in .claude/settings.json
 * 2. Silent pass (exit 0, no JSON) when payload only uses relative paths
 * 3. Silent pass when file_path is not a settings file
 * 4. Fail-open on malformed/empty stdin
 * 5. Feature flag SETTINGS_GUARD_ENABLED=false disables the guard
 * 6. Edit-tool detection (new_string scanned)
 */

const { spawn } = require('child_process');
const path = require('path');

const HOOK_PATH = path.resolve(__dirname, '..', 'pre-write-settings-validate.js');

/**
 * Run the hook with given input + env, capture stdout/stderr/exitCode.
 */
function runHook(inputJSON, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [HOOK_PATH], {
      env: { ...process.env, ...env },
    });
    let stdout = '';
    let stderr = '';

    if (inputJSON !== undefined) {
      child.stdin.write(typeof inputJSON === 'string' ? inputJSON : JSON.stringify(inputJSON));
    }
    child.stdin.end();

    child.stdout.on('data', (d) => { stdout += d.toString(); });
    child.stderr.on('data', (d) => { stderr += d.toString(); });
    child.on('close', (exitCode) => { resolve({ stdout, stderr, exitCode }); });
    child.on('error', (err) => { reject(err); });
  });
}

describe('pre-write-settings-validate.js', () => {
  // ------------------------------------------------------------------
  // Test 1: Ask decision on absolute-path Write to settings.json
  // ------------------------------------------------------------------
  test('emits ask decision when Write introduces node "C:/... in settings.json', async () => {
    const settingsContent = JSON.stringify({
      hooks: {
        PreToolUse: [
          {
            matcher: 'Write|Edit',
            hooks: [
              {
                type: 'command',
                command: 'node "C:/Users/tonym/Repos/MAD - Clean/.claude/hooks/some-hook.js"',
                timeout: 5,
              },
            ],
          },
        ],
      },
    }, null, 2);

    const result = await runHook({
      tool_name: 'Write',
      tool_input: {
        file_path: 'C:/Users/tonym/Repos/MAD - Clean/.claude/settings.json',
        content: settingsContent,
      },
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).not.toBe('');
    const parsed = JSON.parse(result.stdout);
    expect(parsed.hookSpecificOutput.hookEventName).toBe('PreToolUse');
    expect(parsed.hookSpecificOutput.permissionDecision).toBe('ask');
    expect(parsed.hookSpecificOutput.permissionDecisionReason).toContain('pre-write-settings-validate');
    expect(parsed.hookSpecificOutput.additionalContext).toContain('Kit standard: relative paths');
    expect(parsed.hookSpecificOutput.additionalContext).toContain('SETTINGS_GUARD_ENABLED=false');
  });

  // ------------------------------------------------------------------
  // Test 2: Silent pass for relative-path content
  // ------------------------------------------------------------------
  test('exits 0 with no JSON when settings.json content is all relative paths', async () => {
    const settingsContent = JSON.stringify({
      hooks: {
        PreToolUse: [
          {
            matcher: 'Write|Edit',
            hooks: [
              {
                type: 'command',
                command: 'node .claude/hooks/some-hook.js',
                timeout: 5,
              },
            ],
          },
        ],
      },
    }, null, 2);

    const result = await runHook({
      tool_name: 'Write',
      tool_input: {
        file_path: 'C:/Users/tonym/Repos/MAD - Clean/.claude/settings.json',
        content: settingsContent,
      },
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('');
  });

  // ------------------------------------------------------------------
  // Test 3: Out-of-scope file path is silently passed through
  // ------------------------------------------------------------------
  test('exits 0 with no JSON when file_path is not a settings file', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: {
        file_path: 'C:/Users/tonym/Repos/MAD - Clean/src/foo.cs',
        content: 'node "C:/some/absolute/path/script.js"',
      },
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('');
  });

  // ------------------------------------------------------------------
  // Test 4a: Empty stdin -> fail-open (exit 0)
  // ------------------------------------------------------------------
  test('exits 0 on empty stdin (fail-open)', async () => {
    const result = await runHook(undefined);
    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('');
  });

  // ------------------------------------------------------------------
  // Test 4b: Malformed JSON -> fail-open (exit 0)
  // ------------------------------------------------------------------
  test('exits 0 on malformed JSON (fail-open)', async () => {
    const result = await runHook('not valid json{{{');
    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('');
  });

  // ------------------------------------------------------------------
  // Test 5: Feature flag disables the guard
  // ------------------------------------------------------------------
  test('exits 0 silently when SETTINGS_GUARD_ENABLED=false even with bad content', async () => {
    const settingsContent = '"command": "node \\"C:/Users/tonym/.../hook.js\\""';

    const result = await runHook(
      {
        tool_name: 'Write',
        tool_input: {
          file_path: '.claude/settings.json',
          content: settingsContent,
        },
      },
      { SETTINGS_GUARD_ENABLED: 'false' }
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('');
  });

  // ------------------------------------------------------------------
  // Test 6: Edit tool with new_string introducing absolute path
  // ------------------------------------------------------------------
  test('emits ask decision when Edit new_string introduces absolute path', async () => {
    const result = await runHook({
      tool_name: 'Edit',
      tool_input: {
        file_path: '.claude/settings.json',
        old_string: '"command": "node .claude/hooks/x.js"',
        new_string: '"command": "node \\"C:/Users/tonym/Repos/MAD - Clean/.claude/hooks/x.js\\""',
      },
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).not.toBe('');
    const parsed = JSON.parse(result.stdout);
    expect(parsed.hookSpecificOutput.permissionDecision).toBe('ask');
  });

  // ------------------------------------------------------------------
  // Test 6b: Edit tool with relative-only new_string is silent
  // ------------------------------------------------------------------
  test('exits 0 silently when Edit new_string only uses relative paths', async () => {
    const result = await runHook({
      tool_name: 'Edit',
      tool_input: {
        file_path: '.claude/settings.json',
        old_string: '"command": "node .claude/hooks/x.js"',
        new_string: '"command": "node .claude/hooks/y.js"',
      },
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.trim()).toBe('');
  });

  // ------------------------------------------------------------------
  // Test 7: settings.local.json is also in scope
  // ------------------------------------------------------------------
  test('treats settings.local.json the same as settings.json', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: {
        file_path: '.claude/settings.local.json',
        content: '"command": "node \\"C:/abs/path/hook.js\\""',
      },
    });

    expect(result.exitCode).toBe(0);
    const parsed = JSON.parse(result.stdout);
    expect(parsed.hookSpecificOutput.permissionDecision).toBe('ask');
  });

  // ------------------------------------------------------------------
  // Test 8: pwsh / powershell.exe absolute paths also detected
  // ------------------------------------------------------------------
  test('detects pwsh "C:/... absolute path', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: {
        file_path: '.claude/settings.json',
        content: '"command": "pwsh \\"C:/Users/x/script.ps1\\""',
      },
    });

    expect(result.exitCode).toBe(0);
    const parsed = JSON.parse(result.stdout);
    expect(parsed.hookSpecificOutput.permissionDecision).toBe('ask');
  });

  test('detects powershell.exe "C:/... absolute path', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: {
        file_path: '.claude/settings.json',
        content: '"command": "powershell.exe \\"C:/Users/x/script.ps1\\""',
      },
    });

    expect(result.exitCode).toBe(0);
    const parsed = JSON.parse(result.stdout);
    expect(parsed.hookSpecificOutput.permissionDecision).toBe('ask');
  });
});
