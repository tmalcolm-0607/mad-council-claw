#!/usr/bin/env node
/**
 * Hook: CheckWorktree
 * Purpose: Warn when feature development commands run outside a worktree
 * Event: PreToolUse (Bash)
 *
 * This hook checks if commands that typically indicate feature development
 * (commits, PR creation, builds before commit) are being run from the main
 * repository instead of a worktree.
 */

const { execSync } = require('child_process');

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

// Commands that suggest feature development work
const FEATURE_WORK_PATTERNS = [
  /git commit/i,
  /git push/i,
  /gh pr create/i,
  /gh pr review/i,
  /npm run build.*&&.*git/i,  // Build before commit
  /npm test.*&&.*git/i,       // Test before commit
];

// Commands that are always safe (no worktree needed)
const SAFE_PATTERNS = [
  /git status/i,
  /git log/i,
  /git diff/i,
  /git branch/i,
  /git worktree/i,
  /^ls/i,
  /^cat/i,
  /^pwd/i,
];

function isFeatureWorkCommand(command) {
  // Skip if it's a safe command
  if (SAFE_PATTERNS.some(p => p.test(command))) {
    return false;
  }
  return FEATURE_WORK_PATTERNS.some(p => p.test(command));
}

function isInWorktree(cwd) {
  try {
    // Check if current directory is a worktree (not the main repo)
    const gitDir = execSync('git rev-parse --git-dir', {
      cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();

    // Main repo has .git as directory, worktree has .git as file pointing to main
    // Or check if git-dir contains 'worktrees'
    return gitDir.includes('worktrees') || gitDir.endsWith('.git/worktrees');
  } catch {
    return false;
  }
}

function getMainBranch(cwd) {
  try {
    const branch = execSync('git branch --show-current', {
      cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
    return branch;
  } catch {
    return 'unknown';
  }
}

async function main() {
  try {
    const input = await readStdin();
    let command = '';
    let cwd = process.cwd();

    try {
      const data = JSON.parse(input);
      command = data.tool_input?.command || '';
      cwd = data.cwd || process.cwd();
    } catch {
      // If can't parse, allow the command
      process.exit(0);
      return;
    }

    // Check if this looks like feature development work
    if (!isFeatureWorkCommand(command)) {
      process.exit(0);
      return;
    }

    // Check if we're in a worktree
    if (isInWorktree(cwd)) {
      process.exit(0);
      return;
    }

    // We're in the main repo doing feature work - warn!
    const branch = getMainBranch(cwd);
    const isMainBranch = ['main', 'master'].includes(branch);

    let message = '';
    if (isMainBranch) {
      message = `WARNING: Running feature development command on '${branch}' branch in main repository.\n` +
        `Consider using a worktree:\n` +
        `  git worktree add ../ccghcp-feature -b feature/name\n` +
        `  cd ../ccghcp-feature`;
    } else {
      message = `WARNING: Running feature development command in main repository (not a worktree).\n` +
        `Current branch: ${branch}\n` +
        `For isolated development, use a worktree:\n` +
        `  git worktree add ../ccghcp-${branch} ${branch}\n` +
        `  cd ../ccghcp-${branch}`;
    }

    // Output warning but allow command to continue (advisory hook)
    console.error(message);
    process.exit(0);

  } catch (error) {
    // Hook error - fail-open (advisory hook)
    console.error('[check-worktree] FATAL ERROR:', error.message);
    console.error('[check-worktree] Hook failed - continuing (advisory).');
    process.exit(0);
  }
}

main();
