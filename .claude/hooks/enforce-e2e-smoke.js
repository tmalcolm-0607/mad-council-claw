#!/usr/bin/env node
/**
 * E2E Smoke Test Enforcement Hook
 *
 * Purpose: Block git commits with frontend changes unless E2E smoke tests have run recently
 * Trigger: PreToolUse(Bash) when command contains 'git commit'
 *
 * Tag Taxonomy (dual recognition during migration):
 *   @p0 = legacy (deprecated), @smoke = current (use @smoke @ci for new tests)
 *   @p1 = legacy (deprecated), @flow = current (use @flow for new tests)
 *   Both old and new tags are accepted during the 30-day transition period.
 *
 * Enforcement Mode (configurable via E2E_ENFORCEMENT_MODE env var):
 * - 'block' (default): Prevent commits without recent E2E tests (fail-closed)
 * - 'warn': Log violations but allow commits (transition mode, fail-open)
 *
 * Logic:
 * 1. Check if git commit command is being executed
 * 2. Check git diff --cached for frontend file changes (*.ts, *.tsx, *.css, *.html)
 * 3. If frontend changes found, check if E2E smoke tests ran recently (last 4 hours)
 * 4. If not, BLOCK (default) or WARN (with E2E_ENFORCEMENT_MODE=warn)
 *
 * Bypass mechanism: Use --no-verify flag for emergency commits
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Read JSON input from stdin
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Main hook logic
 */
async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);

    // Extract tool information
    const toolName = data.tool_name || '';
    const toolInput = data.tool_input || {};
    const command = toolInput.command || '';

    // Only intercept Bash tool with git commit commands
    if (toolName !== 'Bash' || !command.includes('git commit')) {
      process.exit(0); // Not a commit, passthrough
    }

    // Allow bypass with --no-verify flag
    if (command.includes('--no-verify') || command.includes('-n')) {
      process.exit(0); // Bypass flag present, allow
    }

    // Check for staged frontend files
    let stagedFiles;
    try {
      stagedFiles = execSync('git diff --cached --name-only', {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe']
      }).split('\n').filter(Boolean);
    } catch (gitError) {
      // Git command failed - allow commit (don't block on git errors)
      console.error('[enforce-e2e-smoke] Git command failed (non-blocking):', gitError.message);
      process.exit(0);
    }

    // Frontend file patterns that require E2E validation
    const frontendFilePattern = /^frontend\/.*\.(tsx?|jsx?|css|html|scss|less)$/;
    const hasFrontendChanges = stagedFiles.some(file => frontendFilePattern.test(file));

    if (!hasFrontendChanges) {
      // No frontend changes, allow commit
      process.exit(0);
    }

    // Frontend changes detected - check if E2E smoke tests ran recently
    let repoRoot;
    try {
      repoRoot = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
    } catch (gitError) {
      console.error('[enforce-e2e-smoke] Could not determine repo root (non-blocking):', gitError.message);
      process.exit(0);
    }

    const e2eTimestampPath = path.join(repoRoot, '.mad', 'scratch', 'last-e2e-smoke-run.txt');

    // Check if timestamp file exists
    if (!fs.existsSync(e2eTimestampPath)) {
      return handleE2ERequired(stagedFiles, frontendFilePattern, 'no timestamp file');
    }

    // Check timestamp staleness (4 hours)
    const timestampContent = fs.readFileSync(e2eTimestampPath, 'utf8').trim();
    const lastRunTime = new Date(timestampContent);
    const now = new Date();
    const fourHoursAgo = new Date(now.getTime() - 4 * 60 * 60 * 1000);

    if (isNaN(lastRunTime.getTime())) {
      // Invalid timestamp format
      return handleE2ERequired(stagedFiles, frontendFilePattern, 'corrupted timestamp');
    }

    if (lastRunTime < fourHoursAgo) {
      const hoursAgo = ((now - lastRunTime) / 3600000).toFixed(1);
      return handleE2ERequired(stagedFiles, frontendFilePattern, `stale timestamp (${hoursAgo} hours ago)`);
    }

    // E2E smoke tests are fresh - allow commit
    process.exit(0);

  } catch (error) {
    // Hook error - fail-open (currently, will be fail-closed in Phase 1 Task 1.6)
    console.error('[enforce-e2e-smoke] Hook error (non-blocking):', error.message);
    process.exit(0);
  }
}

/**
 * Handle E2E test requirement with environment-gated blocking
 *
 * @param {string[]} stagedFiles - List of staged files
 * @param {RegExp} frontendFilePattern - Pattern to match frontend files
 * @param {string} reason - Reason for E2E requirement
 */
function handleE2ERequired(stagedFiles, frontendFilePattern, reason) {
  const frontendFiles = stagedFiles.filter(f => frontendFilePattern.test(f));

  const message = [
    '❌ E2E smoke tests required for frontend changes',
    '',
    `Reason: ${reason}`,
    '',
    'Frontend files staged:',
    ...frontendFiles.map(f => `  - ${f}`),
    '',
    'Run E2E tests via ACI:',
    '  powershell.exe -NoProfile -File .claude/scripts/Test-E2E-ACI.ps1 -Environment tonym',
    '',
    'Or run quality gates:',
    '  powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1',
    '',
    'Bypass (emergency only):',
    '  git commit --no-verify',
    ''
  ].join('\n');

  // Enforcement mode (configurable via .claude/settings.local.json):
  //   - 'block' (default): Prevent commits without recent E2E tests
  //   - 'warn': Log violations but allow commits (transition mode)
  const enforcementMode = process.env.E2E_ENFORCEMENT_MODE || 'block';

  if (enforcementMode === 'warn') {
    // WARN mode: Inform but allow commit
    console.error('[E2E Warning] Frontend changes detected but E2E tests not run recently');
    console.error('');
    console.error(message);
    process.exit(0); // Allow commit
  } else {
    // BLOCK mode (default): Exit with error
    console.log(JSON.stringify({
      exit: 2,
      message: message
    }));
    process.exit(2); // Prevent commit
  }
}

main();
