/**
 * Comprehensive Tests for enforce-orchestration.js
 *
 * These tests verify the orchestrator delegation pattern enforcement:
 * - Orchestrator cannot read code files (must use Grep/Glob or spawn agents)
 * - Subagents CAN read code files (they do the work)
 * - Config, docs, and hook files are always readable
 * - Fail-closed on errors
 * - All code file extensions are blocked
 * - Non-Read tools are not intercepted
 *
 * Test Coverage:
 * 1. Block orchestrator code read (shows Grep/Glob guidance)
 * 2. Allow subagent code read
 * 3. Allow orchestrator config read
 * 4. Allow orchestrator hook read
 * 5. Fail-closed on error
 * 6. Block multiple code file extensions
 * 7. Passthrough non-Read tools
 */

const {
  runHook,
  createReadToolEvent,
  assertExitCode,
  assertJSONOutput
} = require('./test-helpers');
const path = require('path');

describe('enforce-orchestration.js - Comprehensive Tests', () => {

  const hookPath = path.resolve(__dirname, '../enforce-orchestration.js');

  /**
   * Test 1: Block orchestrator from reading code files
   * Expected: Hook denies with Grep/Glob guidance in message
   */
  test('blocks orchestrator from reading code files with Grep/Glob guidance', async () => {
    const input = createReadToolEvent('src/Controllers/GameController.cs');
    const result = await runHook(hookPath, input);

    // Hook should exit 0 but output deny JSON
    assertExitCode(result.exitCode, 0, 'Hook should exit 0 (deny via JSON)');

    // Parse and verify JSON structure
    const output = JSON.parse(result.stdout);
    expect(output.hookSpecificOutput).toBeDefined();
    expect(output.hookSpecificOutput.hookEventName).toBe('PreToolUse');
    expect(output.hookSpecificOutput.permissionDecision).toBe('deny');

    // Verify new message contains Grep/Glob guidance
    const reason = output.hookSpecificOutput.permissionDecisionReason;
    expect(reason).toContain('BLOCKED: Reading code file directly');
    expect(reason).toContain('Grep');
    expect(reason).toContain('Glob');
    expect(reason).toContain('Grep pattern=');
    expect(reason).toContain('Glob pattern=');
    expect(reason).toContain('src/Controllers/GameController.cs');
  });

  /**
   * Test 2: Allow subagents to read code files
   * Expected: Hook passes through (exit 0, no output)
   */
  test('allows subagents to read code files', async () => {
    const input = {
      tool_name: 'Read',
      tool_input: {
        file_path: 'src/Services/AuthService.ts'
      },
      agent_id: 'code-investigator-abc123' // Subagent marker
    };
    const result = await runHook(hookPath, input);

    // Hook should pass through silently
    assertExitCode(result.exitCode, 0, 'Subagent should be allowed');
    expect(result.stdout.trim()).toBe('');
  });

  /**
   * Test 3: Allow orchestrator to read config/docs files
   * Expected: Hook passes through (exit 0, no output)
   */
  test('allows orchestrator to read config and documentation files', async () => {
    const configFiles = [
      'CLAUDE.md',
      'package.json',
      'appsettings.json',
      '.claude/rules/quality-gates.md',
      'specs/001-feature/spec.md',
      'docs/architecture.md',
      'config/settings.yaml',
      '.env',
      '.gitignore',
      'Dockerfile',
      'docker-compose.yml'
    ];

    for (const file of configFiles) {
      const input = createReadToolEvent(file);
      const result = await runHook(hookPath, input);

      assertExitCode(result.exitCode, 0, `Config file ${file} should be allowed`);
      expect(result.stdout.trim()).toBe('');
    }
  });

  /**
   * Test 4: Allow orchestrator to read hook files
   * Expected: Hook passes through (exit 0, no output)
   */
  test('allows orchestrator to read hook files (infrastructure)', async () => {
    const input = createReadToolEvent('.claude/hooks/enforce-orchestration.js');
    const result = await runHook(hookPath, input);

    assertExitCode(result.exitCode, 0, 'Hook files should be readable');
    expect(result.stdout.trim()).toBe('');
  });

  /**
   * Test 5: Fail-closed on malformed input
   * Expected: Hook exits 2 (hard-deny) with error message.
   *
   * Per `.claude/hooks/hook-fail-open-policy.md`: enforce-orchestration is a
   * Security/Blocking PreToolUse hook. On unexpected error it must fail-closed
   * via exit 2 (the Claude Code contract for "block this action"). exit 1 is
   * undefined behavior and explicitly forbidden by the policy.
   */
  test('fails closed on malformed JSON input', async () => {
    const { spawn } = require('child_process');

    const result = await new Promise((resolve) => {
      const child = spawn('node', [hookPath]);
      let stdout = '';
      let stderr = '';

      // Send invalid JSON
      child.stdin.write('not valid json{');
      child.stdin.end();

      child.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (exitCode) => {
        resolve({ stdout, stderr, exitCode });
      });
    });

    // Hook should exit 2 (fail-closed / hard-deny per hook-fail-open-policy.md)
    assertExitCode(result.exitCode, 2, 'Malformed input should fail closed (exit 2 per hook-fail-open-policy)');
    expect(result.stderr).toContain('enforce-orchestration');
    expect(result.stderr).toContain('FATAL ERROR');
  });

  /**
   * Test 6: Block all code file extensions
   * Expected: All code extensions are blocked
   */
  test('blocks all configured code file extensions', async () => {
    const codeFiles = [
      'src/Program.cs',           // C#
      'src/services/api.ts',      // TypeScript
      'src/components/App.tsx',   // TSX
      'src/utils/helper.js',      // JavaScript
      'src/components/Button.jsx', // JSX
      'scripts/migrate.py',       // Python
      'cmd/server/main.go',       // Go
      'src/lib.rs',               // Rust
      'src/Main.java',            // Java
      'src/engine.cpp',           // C++
      'src/utils.c',              // C
      'include/types.h',          // C header
      'include/utils.hpp'         // C++ header
    ];

    for (const file of codeFiles) {
      const input = createReadToolEvent(file);
      const result = await runHook(hookPath, input);

      assertExitCode(result.exitCode, 0, `File ${file} should be blocked`);
      const output = JSON.parse(result.stdout);
      expect(output.hookSpecificOutput.permissionDecision).toBe('deny');
      expect(output.hookSpecificOutput.permissionDecisionReason).toContain('BLOCKED');
    }
  });

  /**
   * Test 7: Passthrough non-Read tools
   * Expected: Grep, Glob, Write, Edit, Bash are not intercepted
   */
  test('passes through non-Read tools without interception', async () => {
    const nonReadTools = [
      {
        tool_name: 'Grep',
        tool_input: {
          pattern: 'class.*Controller',
          glob: '**/*.cs'
        }
      },
      {
        tool_name: 'Glob',
        tool_input: {
          pattern: '**/*.ts'
        }
      },
      {
        tool_name: 'Write',
        tool_input: {
          file_path: 'src/NewFile.cs',
          content: 'namespace Test {}'
        }
      },
      {
        tool_name: 'Edit',
        tool_input: {
          file_path: 'src/Existing.cs',
          old_string: 'foo',
          new_string: 'bar'
        }
      },
      {
        tool_name: 'Bash',
        tool_input: {
          command: 'dotnet build'
        }
      }
    ];

    for (const input of nonReadTools) {
      const result = await runHook(hookPath, input);

      assertExitCode(result.exitCode, 0, `Tool ${input.tool_name} should pass through`);
      expect(result.stdout.trim()).toBe('');
    }
  });

  /**
   * Test 8: Allow subagents identified by context.agent_id
   * Expected: Hook passes through for alternative agent_id field location
   */
  test('allows subagents identified by context.agent_id', async () => {
    const input = {
      tool_name: 'Read',
      tool_input: {
        file_path: 'src/Domain/Entities/Game.cs'
      },
      context: {
        agent_id: 'code-implementer-xyz789'
      }
    };
    const result = await runHook(hookPath, input);

    assertExitCode(result.exitCode, 0, 'Subagent via context.agent_id should be allowed');
    expect(result.stdout.trim()).toBe('');
  });

  /**
   * Test 9: Allow subagents identified by is_subagent flag
   * Expected: Hook passes through for alternative subagent marker
   */
  /**
   * Regression: orchestrator must be able to verify subagent commits in
   * references/<repo>-*-fix-* worktrees and inspect external reference repos.
   * Without this, every code-implementer-driven fix loop blocks at verification.
   */
  test('allows orchestrator to read code files under references/', async () => {
    const referenceFiles = [
      'references/LENS-DCS/sources/dev/DataCollector/Foo.cs',
      'references/LENS-DCS-cosmos-fix2/sources/dev/DataCollector/Foo.cs',
      'references/LENS-Common/some/Component.ts',
      'C:/Users/x/Repos/MAD - Clean/references/LENS-DCS/Foo.cs',
    ];
    for (const file of referenceFiles) {
      const input = createReadToolEvent(file);
      const result = await runHook(hookPath, input);
      assertExitCode(result.exitCode, 0, `references/ path should be allowed: ${file}`);
      expect(result.stdout.trim()).toBe('');
    }
  });

  test('still blocks orchestrator from reading project-tree code files', async () => {
    const projectFiles = [
      'src/components/Foo.tsx',
      'app/api/handler.ts',
      'lib/util.js',
    ];
    for (const file of projectFiles) {
      const input = createReadToolEvent(file);
      const result = await runHook(hookPath, input);
      assertExitCode(result.exitCode, 0, 'Hook always exits 0 for project code (deny via decision)');
      const out = JSON.parse(result.stdout || '{}');
      expect(out.hookSpecificOutput?.permissionDecision).toBe('deny');
      expect(out.hookSpecificOutput?.permissionDecisionReason).toMatch(/BLOCKED: Reading code file directly/);
    }
  });

  test('allows subagents identified by is_subagent flag', async () => {
    const input = {
      tool_name: 'Read',
      tool_input: {
        file_path: 'src/Application/Services/GameService.cs'
      },
      is_subagent: true
    };
    const result = await runHook(hookPath, input);

    assertExitCode(result.exitCode, 0, 'Subagent via is_subagent flag should be allowed');
    expect(result.stdout.trim()).toBe('');
  });

});
