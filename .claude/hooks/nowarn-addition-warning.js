#!/usr/bin/env node

/**
 * Hook: PreToolUse (Write|Edit)
 * Purpose: Advisory warning when adding to <NoWarn> in .csproj or .props files
 *
 * Non-blocking (always exits 0). Warns once per file per session.
 * State file: .mad/scratch/nowarn-state.json
 *
 * Catches: Pattern #13 (Warning suppression papering over real issues)
 * from PR comment pattern analysis.
 */

const fs = require('fs');
const path = require('path');

// ─── Helpers ─────────────────────────────────────────────────────────────────

function normalize(filePath) {
  return filePath.replace(/\\/g, '/');
}

function getProjectDir() {
  let dir = process.cwd();
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, '.claude'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

function isTargetFile(filePath) {
  const normalized = normalize(filePath).toLowerCase();
  return normalized.endsWith('.csproj') || normalized.endsWith('.props');
}

// ─── State Management ────────────────────────────────────────────────────────

function getStatePath(projectDir) {
  return path.join(projectDir, '.mad', 'scratch', 'nowarn-state.json');
}

function loadState(projectDir, sessionId) {
  const statePath = getStatePath(projectDir);
  try {
    if (fs.existsSync(statePath)) {
      const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
      if (state.sessionId === sessionId) {
        return state;
      }
    }
  } catch (e) {
    // Corrupted state - start fresh
  }
  return { sessionId, filesWarned: [] };
}

function saveState(projectDir, state) {
  const statePath = getStatePath(projectDir);
  try {
    const dir = path.dirname(statePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  } catch (e) {
    // Best effort - don't fail the hook
  }
}

// ─── NoWarn Detection ────────────────────────────────────────────────────────

/**
 * Check if the tool input content adds to a <NoWarn> element.
 *
 * For Write: checks if <NoWarn> appears in the full content
 * For Edit: checks if the new_string adds or expands <NoWarn>
 */
function detectsNoWarnAddition(toolName, toolInput) {
  const noWarnPattern = /<NoWarn\b/i;

  if (toolName === 'Write') {
    const content = toolInput.content || '';
    return noWarnPattern.test(content);
  }

  if (toolName === 'Edit') {
    const newString = toolInput.new_string || '';
    const oldString = toolInput.old_string || '';

    // Case 1: new_string introduces <NoWarn> that wasn't in old_string
    if (noWarnPattern.test(newString) && !noWarnPattern.test(oldString)) {
      return true;
    }

    // Case 2: both have <NoWarn> but new_string has more content (expanded)
    if (noWarnPattern.test(newString) && noWarnPattern.test(oldString)) {
      const oldMatch = oldString.match(/<NoWarn\b[^>]*>([^<]*)<\/NoWarn>/i);
      const newMatch = newString.match(/<NoWarn\b[^>]*>([^<]*)<\/NoWarn>/i);
      if (oldMatch && newMatch && newMatch[1].length > oldMatch[1].length) {
        return true;
      }
    }

    return false;
  }

  return false;
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  // Read stdin
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch (e) {
    process.exit(0);
  }

  const toolName = data.tool_name || '';
  const toolInput = data.tool_input || data.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';

  if (!filePath) {
    process.exit(0);
  }

  // Only target .csproj and .props files
  if (!isTargetFile(filePath)) {
    process.exit(0);
  }

  // Check if the change adds to <NoWarn>
  if (!detectsNoWarnAddition(toolName, toolInput)) {
    process.exit(0);
  }

  // Session-based dedup: warn once per file per session
  const projectDir = getProjectDir();
  const sessionId = data.session_id || process.env.CLAUDE_SESSION_ID || Date.now().toString(36);
  const state = loadState(projectDir, sessionId);
  const normalizedPath = normalize(filePath);

  if (state.filesWarned.includes(normalizedPath)) {
    process.exit(0);
  }

  // Emit advisory warning
  const fileName = path.basename(filePath);
  console.error(`[NoWarn Advisory] Adding global warning suppression in ${fileName}. Consider using #pragma warning disable at the specific callsite instead.`);

  // Record that we warned for this file
  state.filesWarned.push(normalizedPath);
  saveState(projectDir, state);

  // Always non-blocking
  process.exit(0);
}

main().catch((err) => {
  // Fail-open: never block on hook error
  console.error('[nowarn-addition-warning] Error:', err.message);
  process.exit(0);
});
