#!/usr/bin/env node
/**
 * Pre-commit hook to validate token limits for Claude configuration files.
 *
 * Token limits:
 * - Agents: 800 tokens max
 * - Skills: 2000 tokens max
 * - Patterns: 1500 tokens max
 *
 * Usage:
 *   node .claude/hooks/pre-commit-tokens.js [--test]
 *
 * Options:
 *   --test  Run validation without blocking (for testing the hook)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const LIMITS = {
  agents: 800,
  skills: 2000,
  patterns: 1500
};

function estimateTokens(content) {
  const words = content.split(/\s+/).filter(w => w.length > 0);
  return Math.ceil(words.length * 1.3);
}

function getCategory(filePath) {
  const normalized = filePath.replace(/\\/g, '/');
  if (normalized.includes('.claude/agents/')) return 'agents';
  if (normalized.includes('.claude/skills/')) return 'skills';
  if (normalized.includes('.claude/rules/patterns/')) return 'patterns';
  return null;
}

function getStagedFiles() {
  try {
    const output = execSync('git diff --cached --name-only --diff-filter=ACM', { encoding: 'utf8' });
    return output.split('\n').filter(f => f.endsWith('.md'));
  } catch (e) {
    return [];
  }
}

function validateFiles(files, testMode = false) {
  const violations = [];

  for (const file of files) {
    const category = getCategory(file);
    if (!category) continue;

    const limit = LIMITS[category];
    if (!limit) continue;

    try {
      const content = fs.readFileSync(file, 'utf8');
      const tokens = estimateTokens(content);

      if (tokens > limit) {
        violations.push({
          file,
          category,
          tokens,
          limit,
          over: tokens - limit
        });
      }
    } catch (e) {
      // File might not exist yet in working directory
    }
  }

  if (violations.length > 0) {
    console.warn('\n⚠️  Token limit violations detected (WARNING ONLY):\n');
    for (const v of violations) {
      console.warn(`  ${v.file}`);
      console.warn(`    Category: ${v.category} (limit: ${v.limit})`);
      console.warn(`    Tokens: ${v.tokens} (+${v.over} over limit)\n`);
    }

    if (!testMode) {
      console.warn('⚠️  Warning: Files exceed recommended token limits. Consider reducing file size.');
      console.warn('Commit allowed - natural file growth is expected.\n');
    } else {
      console.log('(Test mode: would emit warnings)');
    }
  } else {
    console.log('✅ All staged Claude files within token limits');
  }

  return violations;
}

function findMdFiles(dir, files = []) {
  if (!fs.existsSync(dir)) return files;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      findMdFiles(fullPath, files);
    } else if (entry.name.endsWith('.md') && entry.name !== 'README.md') {
      files.push(fullPath);
    }
  }
  return files;
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
    // Main
    const args = process.argv.slice(2);
    const testMode = args.includes('--test');

    if (testMode) {
      console.log('Running token validation in test mode...\n');
      const allFiles = [];
      const dirs = ['.claude/agents', '.claude/skills', '.claude/rules/patterns'];
      for (const dir of dirs) {
        findMdFiles(dir, allFiles);
      }
      console.log(`Found ${allFiles.length} files to check\n`);
      validateFiles(allFiles, true);
      return;
    }

    // When running as a hook, read stdin to check if this is a git commit
    const input = await readStdin();
    const data = JSON.parse(input);
    const command = data.tool_input?.command || '';

    // Only run on git commit commands (handles plain `git commit` and `git -C <path> commit`)
    if (!/\bgit\b.*\bcommit\b/.test(command)) {
      process.exit(0);
    }

    const stagedFiles = getStagedFiles();
    if (stagedFiles.length === 0) {
      process.exit(0);
    }
    validateFiles(stagedFiles, false);
  } catch (err) {
    // Advisory hook - fail-open
    process.exit(0);
  }
}

main();
