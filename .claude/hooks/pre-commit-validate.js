#!/usr/bin/env node
/**
 * Hook: PreToolUse (Bash) - Git Commit Validation
 * Purpose: Block git commits that don't include gate verification
 *
 * This hook intercepts `git commit` commands and validates:
 * 1. Commit message includes gate results OR
 * 2. Tests were recently run and passed
 *
 * Enforcement: Commits without test verification are BLOCKED.
 */

const fs = require('fs');
const path = require('path');

// Gate result patterns that indicate proper verification
const GATE_PATTERNS = [
  /Gate Results:/i,
  /Tests:\s*\d+\s*passed/i,
  /\d+\s*passed,\s*0\s*failed/i,
  /Coverage:\s*\d+%/i,
  /Build:\s*✅/i,
  /Tests:\s*✅/i,
];

// Check if this is a git commit command
function isGitCommit(command) {
  return /git\s+commit/i.test(command);
}

// Check if commit message contains gate verification
function hasGateVerification(command) {
  for (const pattern of GATE_PATTERNS) {
    if (pattern.test(command)) {
      return true;
    }
  }
  return false;
}

// Check if tests were recently run (within last 5 minutes)
function testsRecentlyRun() {
  const possibleTestOutputs = [
    'node_modules/.cache/vitest',
    'coverage',
    '.nyc_output',
    'test-results',
  ];

  const fiveMinutesAgo = Date.now() - (5 * 60 * 1000);

  for (const outputPath of possibleTestOutputs) {
    try {
      const fullPath = path.resolve(process.cwd(), outputPath);
      const stats = fs.statSync(fullPath);
      if (stats.mtime.getTime() > fiveMinutesAgo) {
        return true;
      }
    } catch {
      // Path doesn't exist, continue checking
    }
  }

  return false;
}

// Check for test result file
function getTestResultFile() {
  const testResultPath = path.resolve(process.cwd(), '.mad/scratch/gate-results.json');
  try {
    const content = fs.readFileSync(testResultPath, 'utf-8');
    const results = JSON.parse(content);
    const fiveMinutesAgo = Date.now() - (5 * 60 * 1000);

    if (results.timestamp && results.timestamp > fiveMinutesAgo) {
      return results;
    }
  } catch {
    // No results file
  }
  return null;
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);
    const command = data.tool_input?.command || '';

    // Only check git commit commands
    if (!isGitCommit(command)) {
      process.exit(0);
    }

    // Allow --amend and other non-message commits (they modify existing commits)
    if (/--amend/i.test(command) && !/-m/i.test(command)) {
      process.exit(0);
    }

    // Check 1: Does commit message contain gate verification?
    if (hasGateVerification(command)) {
      process.exit(0); // Allow
    }

    // Check 2: Were tests recently run?
    const recentResults = getTestResultFile();
    if (recentResults && recentResults.passed) {
      process.exit(0); // Allow
    }

    if (testsRecentlyRun()) {
      // Warn but allow if tests were run recently
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'ask',
          permissionDecisionReason: 'Commit does not include gate results. Tests appear to have run recently. Include gate results in commit message for better traceability.',
          additionalContext: 'Recommended: Include "Gate Results:" section with test counts in commit message.'
        }
      }));
      process.exit(0);
    }

    // Block: No gate verification and no recent tests
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: `BLOCKED: Commit without gate verification.

Before committing, you MUST:
1. Run: npm run build
2. Run: npm test
3. Include gate results in commit message OR run tests within last 5 minutes

Example commit message format:
  feat: implement feature X

  Gate Results:
  - Build: ✅
  - Tests: 217 passed, 0 failed
  - Coverage: 85%

Run 'npm test' and try again.`,
        additionalContext: 'This enforcement ensures code quality by requiring test verification before commits.'
      }
    }));
    process.exit(0);

  } catch (error) {
    // Hook error - fail-closed
    console.error('[pre-commit-validate] FATAL ERROR:', error.message);
    console.error('[pre-commit-validate] Hook failed - operation blocked for safety.');
    console.log(JSON.stringify({
      exit: 2,
      message: `pre-commit-validate failed: ${error.message}. Operation blocked for safety.`
    }));
    process.exit(2);
  }
}

main();
