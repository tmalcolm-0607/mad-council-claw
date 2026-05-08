/**
 * Hook Test Helpers
 *
 * Utilities for characterization testing of hooks before rewrites.
 * Provides process spawning, stdin feeding, and output capture.
 */

const { spawn } = require('child_process');
const path = require('path');

/**
 * Run a hook with given input and capture output
 *
 * @param {string} hookPath - Absolute or relative path to hook file
 * @param {object} inputJSON - JSON object to send as stdin
 * @returns {Promise<{stdout: string, stderr: string, exitCode: number}>}
 */
function runHook(hookPath, inputJSON) {
  return new Promise((resolve, reject) => {
    // Resolve relative paths to absolute
    const absolutePath = path.isAbsolute(hookPath)
      ? hookPath
      : path.resolve(__dirname, '..', hookPath);

    const child = spawn('node', [absolutePath]);
    let stdout = '';
    let stderr = '';

    // Send input JSON to stdin
    child.stdin.write(JSON.stringify(inputJSON));
    child.stdin.end();

    // Capture stdout
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    // Capture stderr
    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    // Handle completion
    child.on('close', (exitCode) => {
      resolve({
        stdout,
        stderr,
        exitCode
      });
    });

    // Handle errors
    child.on('error', (err) => {
      reject(new Error(`Failed to spawn hook: ${err.message}`));
    });
  });
}

/**
 * Create a mock Bash tool permission event
 *
 * @param {string} command - Bash command to test
 * @returns {object} - Mock PermissionRequest event
 */
function createBashPermissionEvent(command) {
  return {
    tool_name: 'Bash',
    tool_input: {
      command: command
    }
  };
}

/**
 * Create a mock Read tool event
 *
 * @param {string} file_path - File path to read
 * @returns {object} - Mock PreToolUse event
 */
function createReadToolEvent(file_path) {
  return {
    tool_name: 'Read',
    tool_input: {
      file_path: file_path
    }
  };
}

/**
 * Create a mock SubagentStop event
 *
 * @param {string} agentOutput - Agent's output text
 * @returns {object} - Mock SubagentStop event
 */
function createSubagentStopEvent(agentOutput) {
  return {
    event_type: 'SubagentStop',
    agent_output: agentOutput,
    agent_id: 'test-agent-123'
  };
}

/**
 * Assert that exit code matches expected value
 *
 * @param {number} actual - Actual exit code
 * @param {number} expected - Expected exit code
 * @param {string} message - Optional message
 */
function assertExitCode(actual, expected, message = '') {
  if (actual !== expected) {
    throw new Error(
      `Expected exit code ${expected}, got ${actual}. ${message}`
    );
  }
}

/**
 * Assert that stdout contains expected JSON with specific fields
 *
 * @param {string} stdout - Hook stdout
 * @param {object} expectedFields - Expected JSON fields
 */
function assertJSONOutput(stdout, expectedFields) {
  if (!stdout.trim()) {
    throw new Error('Expected JSON output, got empty stdout');
  }

  let parsed;
  try {
    parsed = JSON.parse(stdout);
  } catch (err) {
    throw new Error(`Expected valid JSON, got: ${stdout.substring(0, 100)}`);
  }

  for (const [key, expectedValue] of Object.entries(expectedFields)) {
    const actualValue = getNestedValue(parsed, key);
    if (actualValue !== expectedValue) {
      throw new Error(
        `Expected ${key}=${expectedValue}, got ${actualValue}`
      );
    }
  }
}

/**
 * Get nested object value by dot notation key
 *
 * @param {object} obj - Object to traverse
 * @param {string} key - Dot-notation key (e.g., "hookSpecificOutput.exit")
 * @returns {any} - Value at key path
 */
function getNestedValue(obj, key) {
  return key.split('.').reduce((current, part) =>
    current ? current[part] : undefined, obj);
}

/**
 * Assert that stderr contains expected text
 *
 * @param {string} stderr - Hook stderr
 * @param {string} expectedText - Text that should appear in stderr
 */
function assertStderrContains(stderr, expectedText) {
  if (!stderr.includes(expectedText)) {
    throw new Error(
      `Expected stderr to contain "${expectedText}", got: ${stderr.substring(0, 200)}`
    );
  }
}

module.exports = {
  runHook,
  createBashPermissionEvent,
  createReadToolEvent,
  createSubagentStopEvent,
  assertExitCode,
  assertJSONOutput,
  assertStderrContains
};
