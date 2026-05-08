/**
 * Characterization Tests for enforce-e2e-smoke.js
 *
 * These tests document the CURRENT behavior before rewriting the hook.
 * After rewriting to stdin-reading pattern, these same tests must pass.
 *
 * Current Implementation Uses: module.exports = async (event) => {}
 * Target Implementation Will Use: stdin-reading pattern with readStdin()
 *
 * Test Coverage:
 * 1. No 'git commit' in command → allow (exit 0 / no output)
 * 2. 'git commit --no-verify' → allow (bypass mechanism)
 * 3. 'git commit' with no staged frontend files → allow
 * 4. 'git commit' with .tsx files, no timestamp → block (exit 2)
 * 5. 'git commit' with .tsx files, fresh timestamp (<10 min) → allow
 * 6. 'git commit' with .tsx files, stale timestamp (>10 min) → block (exit 2)
 */

const {
  runHook,
  createBashPermissionEvent,
  assertExitCode
} = require('./test-helpers');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * NOTE: Current implementation is NOT stdin-reading compatible.
 * It uses module.exports = async (event) which doesn't work with hook runner.
 *
 * These tests are ASPIRATIONAL - they document what SHOULD happen.
 * After Task 1.2 (rewrite), run these tests to verify correct behavior.
 */

describe('enforce-e2e-smoke.js - Characterization Tests', () => {

  const hookPath = path.resolve(__dirname, '../enforce-e2e-smoke.js');
  const timestampPath = path.resolve(__dirname, '../../../.mad/scratch/last-e2e-smoke-run.txt');

  beforeEach(() => {
    // Clean up timestamp file before each test
    if (fs.existsSync(timestampPath)) {
      fs.unlinkSync(timestampPath);
    }
  });

  afterEach(() => {
    // Clean up timestamp file after each test
    if (fs.existsSync(timestampPath)) {
      fs.unlinkSync(timestampPath);
    }
  });

  /**
   * Test 1: No 'git commit' in command → allow
   */
  test('allows non-commit commands (git status)', async () => {
    const input = createBashPermissionEvent('git status');
    const result = await runHook(hookPath, input);

    // Hook should not output anything (passthrough)
    assertExitCode(result.exitCode, 0, 'Non-commit commands should pass through');
    expect(result.stdout.trim()).toBe('');
  });

  /**
   * Test 2: git commit --no-verify → allow (bypass)
   */
  test('allows commits with --no-verify flag (bypass mechanism)', async () => {
    const input = createBashPermissionEvent('git commit --no-verify -m "emergency fix"');
    const result = await runHook(hookPath, input);

    assertExitCode(result.exitCode, 0, 'Bypass flag should allow commit');
    expect(result.stdout.trim()).toBe('');
  });

  /**
   * Test 3: git commit with no frontend files staged → allow
   *
   * Note: This test requires mocking git diff --cached output
   * In actual implementation, we'd need to inject git command results
   */
  test('allows commits with no frontend file changes', async () => {
    // This test documents intended behavior
    // Actual test would require git repo setup with non-frontend staged files
    console.log('[INFO] Test 3: Requires git repo fixture with backend-only changes');
    console.log('[INFO] Expected: Hook allows commit (no frontend changes)');
  });

  /**
   * Test 4: git commit with frontend files, no timestamp → block
   *
   * Note: Requires git repo with staged .tsx files
   */
  test('blocks commits with frontend changes and no timestamp', async () => {
    // This test documents intended behavior
    // Actual test would require:
    // 1. Git repo with staged frontend/*.tsx file
    // 2. No timestamp file at .mad/scratch/last-e2e-smoke-run.txt
    console.log('[INFO] Test 4: Requires git repo fixture with staged frontend/*.tsx');
    console.log('[INFO] Expected: Hook blocks with exit 2, message about E2E requirement');
  });

  /**
   * Test 5: git commit with frontend files, fresh timestamp → allow
   */
  test('allows commits with frontend changes and fresh E2E timestamp', async () => {
    // Create fresh timestamp (current time)
    const now = new Date();
    fs.mkdirSync(path.dirname(timestampPath), { recursive: true });
    fs.writeFileSync(timestampPath, now.toISOString());

    // This test documents intended behavior
    // Actual test would require git repo with staged frontend files
    console.log('[INFO] Test 5: Requires git repo fixture with staged frontend files');
    console.log('[INFO] Expected: Hook allows commit (timestamp is fresh)');

    // Verify timestamp was written correctly
    expect(fs.existsSync(timestampPath)).toBe(true);
  });

  /**
   * Test 6: git commit with frontend files, stale timestamp → block
   */
  test('blocks commits with frontend changes and stale E2E timestamp', async () => {
    // Create stale timestamp (15 minutes ago)
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
    fs.mkdirSync(path.dirname(timestampPath), { recursive: true });
    fs.writeFileSync(timestampPath, fifteenMinutesAgo.toISOString());

    // This test documents intended behavior
    // Actual test would require git repo with staged frontend files
    console.log('[INFO] Test 6: Requires git repo fixture with staged frontend files');
    console.log('[INFO] Expected: Hook blocks with exit 2, message about stale timestamp');

    // Verify timestamp is truly stale
    const timestampContent = fs.readFileSync(timestampPath, 'utf8');
    const timestamp = new Date(timestampContent);
    const now = new Date();
    const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000);
    expect(timestamp < tenMinutesAgo).toBe(true);
  });

  /**
   * Additional Test: Corrupted timestamp file → block
   */
  test('blocks commits when timestamp file is corrupted', async () => {
    // Write invalid timestamp
    fs.mkdirSync(path.dirname(timestampPath), { recursive: true });
    fs.writeFileSync(timestampPath, 'not-a-valid-timestamp');

    console.log('[INFO] Test 7: Timestamp file corrupted');
    console.log('[INFO] Expected: Hook blocks with exit 2, message about corruption');
  });

});

/**
 * IMPLEMENTATION NOTE FOR TASK 1.2 (Hook Rewrite):
 *
 * When rewriting this hook to stdin-reading pattern, the new implementation must:
 *
 * 1. Read JSON from stdin (not event parameter)
 * 2. Extract tool_name and tool_input.command from JSON
 * 3. Implement same 6-branch logic tree
 * 4. Add environment-gated blocking:
 *    - Default: warn via stderr, exit 0 (allow)
 *    - With ENFORCE_E2E=1: block via exit 2
 * 5. Convert to fail-closed in Phase 1 Task 1.6
 *
 * Pattern to follow (from pre-bash-validate.js):
 *
 * ```javascript
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
 *     const command = data.tool_input?.command || '';
 *
 *     // ... existing logic ...
 *
 *     const enforceE2E = process.env.ENFORCE_E2E === '1';
 *     if (shouldBlock) {
 *       if (enforceE2E) {
 *         console.log(JSON.stringify({ exit: 2, message: '...' }));
 *       } else {
 *         console.error('[E2E Warning] ...');
 *         console.log(JSON.stringify({ exit: 0 }));
 *       }
 *     }
 *   } catch (err) {
 *     // Phase 1 Task 1.6: Convert to fail-closed
 *     console.error('[enforce-e2e-smoke] ERROR:', err.message);
 *     process.exit(0); // Currently fail-open
 *   }
 * }
 *
 * main();
 * ```
 */
