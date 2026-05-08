#!/usr/bin/env node
/**
 * Phase Gates - Quality Gate Runner
 *
 * Executes build, test, and lint gates to ensure code quality at phase boundaries.
 * Each gate runs a shell command and reports pass/fail with timing and output.
 *
 * Features:
 * - Configurable gate commands (build, test, lint)
 * - Fail-fast mode (stops on first failure)
 * - Timeout protection per gate
 * - Detailed output capture for debugging
 *
 * Usage:
 *   const { runPhaseGates } = require('./phase-gates.js');
 *   const result = runPhaseGates({ gates: ['build', 'test'] });
 */

const { execSync } = require('child_process');
const path = require('path');

// ============================================================
// Default Gate Commands
// ============================================================

const DEFAULT_GATE_COMMANDS = {
  build: 'dotnet build',
  test: 'dotnet test --no-build',
  lint: 'dotnet format --verify-no-changes'
};

const DEFAULT_GATE_TIMEOUT = 120000; // 120 seconds
const DEFAULT_GATES = ['build', 'test'];

// ============================================================
// Custom Error Types
// ============================================================

class PhaseGateError extends Error {
  constructor(message, gateResults) {
    super(message);
    this.name = 'PhaseGateError';
    this.gateResults = gateResults;
  }
}

// ============================================================
// Gate Execution
// ============================================================

/**
 * Run a single gate command.
 *
 * @param {string} gateName - Name of the gate (build, test, lint, etc.)
 * @param {Object} config - Gate configuration
 * @param {string} [config.projectRoot] - Project root directory (default: cwd)
 * @param {Object} [config.gateCommands] - Custom gate commands
 * @param {number} [config.gateTimeout] - Timeout per gate in ms (default: 120000)
 * @returns {Object} { passed: boolean, duration: number, output: string, error?: string }
 *
 * @example
 *   const result = runGate('build', { projectRoot: '/path/to/project' });
 *   if (result.passed) {
 *     console.log('Build passed:', result.duration, 'ms');
 *   }
 */
function runGate(gateName, config = {}) {
  const projectRoot = config.projectRoot || process.cwd();
  const gateCommands = { ...DEFAULT_GATE_COMMANDS, ...(config.gateCommands || {}) };
  const timeout = config.gateTimeout || DEFAULT_GATE_TIMEOUT;

  const command = gateCommands[gateName];
  if (!command) {
    return {
      passed: false,
      duration: 0,
      output: '',
      error: `Unknown gate: ${gateName}. No command configured.`
    };
  }

  const startTime = Date.now();

  try {
    const output = execSync(command, {
      cwd: projectRoot,
      timeout: timeout,
      encoding: 'utf8',
      stdio: 'pipe', // Capture output
      maxBuffer: 10 * 1024 * 1024 // 10MB buffer
    });

    return {
      passed: true,
      duration: Date.now() - startTime,
      output: output.trim()
    };
  } catch (error) {
    return {
      passed: false,
      duration: Date.now() - startTime,
      output: error.stdout ? error.stdout.toString().trim() : '',
      error: error.stderr ? error.stderr.toString().trim() : error.message
    };
  }
}

/**
 * Run multiple phase gates in sequence.
 *
 * @param {Object} config - Gate runner configuration
 * @param {string} [config.projectRoot] - Project root directory (default: cwd)
 * @param {string[]} [config.gates] - Gates to run (default: ['build', 'test'])
 * @param {boolean} [config.failFast] - Stop on first failure (default: true)
 * @param {Object} [config.gateCommands] - Custom gate commands
 * @param {number} [config.gateTimeout] - Timeout per gate in ms (default: 120000)
 * @returns {Object} { success: boolean, results: Array<Object>, totalDuration: number }
 *
 * @throws {PhaseGateError} If failFast is true and a gate fails
 *
 * @example
 *   const result = runPhaseGates({
 *     gates: ['build', 'test'],
 *     failFast: true,
 *     projectRoot: '/path/to/project'
 *   });
 *   if (result.success) {
 *     console.log('All gates passed');
 *   }
 */
function runPhaseGates(config = {}) {
  const gates = config.gates || DEFAULT_GATES;
  const failFast = config.failFast !== false; // Default true
  const startTime = Date.now();

  const results = [];

  for (const gateName of gates) {
    const gateResult = runGate(gateName, config);
    results.push({
      gate: gateName,
      ...gateResult
    });

    // If failFast enabled and gate failed, stop immediately
    if (failFast && !gateResult.passed) {
      const totalDuration = Date.now() - startTime;
      throw new PhaseGateError(
        `Phase gate '${gateName}' failed. Execution halted.`,
        {
          success: false,
          results: results,
          totalDuration: totalDuration,
          failedGate: gateName
        }
      );
    }
  }

  const totalDuration = Date.now() - startTime;
  const allPassed = results.every(r => r.passed);

  return {
    success: allPassed,
    results: results,
    totalDuration: totalDuration
  };
}

// ============================================================
// Exports
// ============================================================

module.exports = {
  runGate,
  runPhaseGates,
  PhaseGateError
};
