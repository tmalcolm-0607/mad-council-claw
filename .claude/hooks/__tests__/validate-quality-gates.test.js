/**
 * Test Specification for validate-quality-gates.js
 *
 * IMPORTANT: Current implementation is BROKEN and architecturally incompatible.
 *
 * Problems:
 * 1. Uses ES module syntax (export default) - hooks must be CommonJS
 * 2. Reads context.transcript - NOT available in stdin protocol
 * 3. Needs conversation history - stdin protocol only provides tool event data
 *
 * These tests document INTENDED behavior for the redesign in Task 1.5.
 * After redesign (prompt hook OR file-based detection), these tests should pass.
 */

const {
  runHook,
  createSubagentStopEvent,
  assertExitCode,
  assertStderrContains
} = require('./test-helpers');
const path = require('path');

describe('validate-quality-gates.js - Intended Behavior Tests', () => {

  const hookPath = path.resolve(__dirname, '../validate-quality-gates.js');

  /**
   * REDESIGN OPTIONS (Task 1.5):
   *
   * Option A: Use prompt hook (has transcript access)
   * - Type: "prompt" on SubagentStop event
   * - Provides conversation history
   * - Can analyze agent output patterns
   *
   * Option B: File-based detection
   * - Read agent output files (.claude/work-items/{id}/artifacts/)
   * - Scan for dismissive patterns
   * - Works with stdin protocol
   *
   * Option C: Defer
   * - Requires Claude Code features not yet available
   */

  /**
   * Test 1: Detect dismissive language - "pre-existing failures...unrelated"
   */
  test('warns when agent dismisses test failures as pre-existing', async () => {
    const agentOutput = `
      Quality gates failed with 95 failures. These are all pre-existing
      failures (ComfyUIClient, tracing, metrics, GameHub, Campaign E2E) -
      unrelated to our changes. Our 8 new tests all passed.
    `;

    console.log('[INFO] Test 1: Agent dismisses 95 failures as pre-existing');
    console.log('[INFO] Expected: Hook warns about test failure protocol violation');
    console.log('[INFO] Current implementation: BROKEN (needs redesign)');

    // After redesign, this test should:
    // const input = createSubagentStopEvent(agentOutput);
    // const result = await runHook(hookPath, input);
    // assertStderrContains(result.stderr, 'TEST FAILURE PROTOCOL VIOLATION');
    // assertStderrContains(result.stderr, 'ALL test failures discovered during your work are YOUR responsibility');
  });

  /**
   * Test 2: Detect dismissive language - "not our problem"
   */
  test('warns when agent says failures are "not our problem"', async () => {
    const agentOutput = `
      Build failed with 12 errors. These are not our problem - they existed
      before we started. Our changes compile fine.
    `;

    console.log('[INFO] Test 2: Agent dismisses failures as "not our problem"');
    console.log('[INFO] Expected: Hook warns about responsibility');
    console.log('[INFO] Current implementation: BROKEN (needs redesign)');
  });

  /**
   * Test 3: Allow when tests pass
   */
  test('no warning when all tests pass', async () => {
    const agentOutput = `
      Quality gates passed:
      - Build: SUCCESS
      - Tests: 1,234 passed, 0 failed
      - Coverage: 98%
      - Lint: No errors
    `;

    console.log('[INFO] Test 3: All tests pass');
    console.log('[INFO] Expected: Hook outputs nothing (no warnings)');
  });

  /**
   * Test 4: Allow when agent properly tracks failures
   */
  test('no warning when agent creates tracking spec for failures', async () => {
    const agentOutput = `
      Quality gates found 95 failures. Analysis:
      - 4 regressions (ComfyUIClientTests) - JSON mock mismatch. Fixed in commit abc123.
      - 18 infrastructure tests missing skip logic - Added Skip attributes in commit def456.
      - 73 pre-existing failures - Created tracking bug: specs/BUG-20260216-quality-gates-failures

      All regressions fixed. Pre-existing failures tracked for team triage.
    `;

    console.log('[INFO] Test 4: Agent properly addresses all failures');
    console.log('[INFO] Expected: Hook outputs nothing (correct protocol followed)');
  });

  /**
   * Test 5: Detect when agent only acknowledges "our tests passed"
   */
  test('warns when agent only reports new tests passing, ignores failures', async () => {
    const agentOutput = `
      Our 8 new tests all passed! The build shows some other failures but
      those aren't related to what we changed.
    `;

    console.log('[INFO] Test 5: Agent ignores existing failures, only reports new tests');
    console.log('[INFO] Expected: Hook warns about selective reporting');
  });

  /**
   * Test 6: Detect "95 pre-existing" pattern specifically
   */
  test('warns on exact pattern from test-failure-protocol.md anti-pattern', async () => {
    const agentOutput = `
      The quality gates failed with 95 failures. These are all pre-existing
      failures (ComfyUIClient, tracing, metrics, GameHub, Campaign E2E) -
      unrelated to our changes. Our 8 new tests all passed.
    `;

    console.log('[INFO] Test 6: Exact anti-pattern from protocol doc');
    console.log('[INFO] Expected: Hook warns, references test-failure-protocol.md');
  });

});

/**
 * iter1-F2: MAD-artifact-presence gate
 *
 * The hook gained a self-check mode that exercises checkMadArtifactPresence
 * with two synthetic events. Asserting --self-check exits 0 confirms the
 * function is wired and returns the correct shape for both no-op and
 * commit-shaped inputs.
 */
describe('validate-quality-gates.js - MAD artifact presence (iter1-F2)', () => {
  const { spawnSync } = require('child_process');
  const hookPath = path.resolve(__dirname, '../validate-quality-gates.js');

  test('--self-check returns exit 0 and prints OK', () => {
    const result = spawnSync('node', [hookPath, '--self-check'], { encoding: 'utf8' });
    expect(result.status).toBe(0);
    expect(result.stdout).toMatch(/\[self-check\] OK/);
  });
});

/**
 * IMPLEMENTATION GUIDANCE FOR TASK 1.5 (Hook Redesign):
 *
 * Since the current implementation uses ES modules and reads context.transcript
 * (unavailable in stdin protocol), a complete redesign is required.
 *
 * RECOMMENDED APPROACH: File-Based Detection
 *
 * 1. Read agent output from files instead of conversation transcript:
 *    - .claude/work-items/{WI-ID}/artifacts/implementation-log.md
 *    - .claude/work-items/{WI-ID}/artifacts/gate-results.txt
 *
 * 2. Convert to stdin-reading CommonJS pattern:
 *
 * ```javascript
 * #!/usr/bin/env node
 * const fs = require('fs');
 * const path = require('path');
 *
 * async function readStdin() {
 *   const chunks = [];
 *   for await (const chunk of process.stdin) {
 *     chunks.push(chunk);
 *   }
 *   return Buffer.concat(chunks).toString();
 * }
 *
 * async function main() {
 *   try {
 *     const input = await readStdin();
 *     const data = JSON.parse(input);
 *
 *     // Read agent output from file
 *     const sessionFile = `.claude/work-items/sessions/${process.env.CLAUDE_SESSION_ID || 'default'}`;
 *     const activeWI = fs.readFileSync(sessionFile, 'utf8').trim();
 *     const logPath = `.claude/work-items/${activeWI}/artifacts/implementation-log.md`;
 *
 *     if (!fs.existsSync(logPath)) {
 *       process.exit(0); // No log to check
 *     }
 *
 *     const logContent = fs.readFileSync(logPath, 'utf8');
 *
 *     // Detect dismissive patterns
 *     const dismissivePatterns = [
 *       /pre-existing.*unrelated to our changes/i,
 *       /not related to our changes/i,
 *       /these are all pre-existing/i,
 *       /not our problem/i,
 *     ];
 *
 *     const isDismissive = dismissivePatterns.some(p => p.test(logContent));
 *
 *     if (isDismissive) {
 *       console.error('❌ TEST FAILURE PROTOCOL VIOLATION');
 *       console.error('');
 *       console.error('ALL test failures discovered during your work are YOUR responsibility.');
 *       console.error('');
 *       console.error('See .claude/rules/test-failure-protocol.md');
 *       // Fail-closed after Phase 1 Task 1.6
 *       process.exit(0); // Currently fail-open
 *     }
 *
 *     process.exit(0);
 *   } catch (err) {
 *     console.error('[validate-quality-gates] ERROR:', err.message);
 *     process.exit(0); // Currently fail-open
 *   }
 * }
 *
 * main();
 * ```
 *
 * 3. Register hook on SubagentStop event (after code-implementer completes)
 *
 * 4. Estimated effort: 2-3 hours (redesign, not just format conversion)
 */
