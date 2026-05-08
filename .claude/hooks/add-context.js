#!/usr/bin/env node
/**
 * Hook: UserPromptSubmit
 * Purpose: Add contextual information to user prompts
 *
 * This hook injects useful context like current git branch,
 * time, and project state into the conversation.
 */

const { execSync } = require('child_process');

function getBranch() {
  try {
    // Check if in a git repo
    execSync('git rev-parse --git-dir', { stdio: 'pipe' });
    const branch = execSync('git branch --show-current', { encoding: 'utf8', stdio: 'pipe' }).trim();
    return branch || 'detached';
  } catch {
    return '';
  }
}

function getGitStatus() {
  try {
    const status = execSync('git status --porcelain', { encoding: 'utf8', stdio: 'pipe' }).trim();
    return status ? '(uncommitted changes)' : '';
  } catch {
    return '';
  }
}

function main() {
  const branch = getBranch();
  const gitStatus = getGitStatus();
  const currentTime = new Date().toISOString().slice(0, 16).replace('T', ' ');

  if (branch) {
    console.log(`[Context: Branch: ${branch} ${gitStatus} | Time: ${currentTime}]`);
  }
}

main().catch((err) => {
  // fail-open: advisory hook should not crash session
  console.error('[add-context] ERROR:', err.message);
  process.exit(0);
});
