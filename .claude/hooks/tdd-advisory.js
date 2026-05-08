#!/usr/bin/env node

/**
 * TDD Advisory Hook (PreToolUse: Write|Edit)
 *
 * Non-blocking advisory that reminds developers to follow TDD workflow
 * when modifying source files without recent test file changes.
 *
 * Behavior:
 * 1. Feature flag: TDD_ADVISORY_ENABLED (default: enabled)
 * 2. Excludes docs, config, test files, styles, design files, infrastructure
 * 3. Tracks test file modifications in session state
 * 4. Emits one advisory per source file per session (cooldown)
 * 5. Always exits 0 (non-blocking)
 *
 * State file: .mad/scratch/tdd-state.json
 */

const fs = require('fs');
const path = require('path');

// ─── Configuration ───────────────────────────────────────────────────────────

const RECENCY_TOOL_COUNT = 10;
const RECENCY_TIME_MS = 5 * 60 * 1000; // 5 minutes

// ─── Exclusion Patterns ──────────────────────────────────────────────────────

// File extensions to exclude (documentation, config, styles, design)
const EXCLUDED_EXTENSIONS = [
  '.md', '.json', '.yml', '.yaml',  // documentation / config
  '.tsx',                            // design files (project requirement)
  '.css', '.scss', '.sass',         // styles
];

// Directory segments to exclude
const EXCLUDED_DIRS = [
  '/tests/',
  '/test/',
  '.test.',
  '.spec.',
  '/docs/',
  '/.claude/',
  '/migrations/',
  '/node_modules/',
];

// Source file extensions that trigger advisories
const SOURCE_EXTENSIONS = ['.cs', '.ts'];

// Test file indicators (for tracking test modifications)
const TEST_INDICATORS = [
  '/tests/',
  '/test/',
  '.test.',
  '.spec.',
  'Tests.cs',
  'Test.cs',
  'Tests/',
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

function normalize(filePath) {
  return filePath.replace(/\\/g, '/');
}

function getExtension(filePath) {
  const normalized = normalize(filePath).toLowerCase();
  const lastDot = normalized.lastIndexOf('.');
  if (lastDot === -1) return '';
  return normalized.slice(lastDot);
}

function isExcluded(filePath) {
  const normalized = normalize(filePath).toLowerCase();
  const ext = getExtension(filePath);

  // Check excluded extensions
  if (EXCLUDED_EXTENSIONS.includes(ext)) {
    return true;
  }

  // Check excluded directory patterns
  for (const dir of EXCLUDED_DIRS) {
    if (normalized.includes(dir.toLowerCase())) {
      return true;
    }
  }

  return false;
}

function isSourceFile(filePath) {
  const ext = getExtension(filePath);
  return SOURCE_EXTENSIONS.includes(ext);
}

function isTestFile(filePath) {
  const normalized = normalize(filePath).toLowerCase();
  for (const indicator of TEST_INDICATORS) {
    if (normalized.includes(indicator.toLowerCase())) {
      return true;
    }
  }
  return false;
}

// ─── State Management ────────────────────────────────────────────────────────

function getStatePath(projectDir) {
  return path.join(projectDir, '.mad', 'scratch', 'tdd-state.json');
}

function loadState(projectDir) {
  const statePath = getStatePath(projectDir);
  try {
    if (fs.existsSync(statePath)) {
      return JSON.parse(fs.readFileSync(statePath, 'utf8'));
    }
  } catch (e) {
    // Corrupted state - start fresh
  }
  return null;
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

function getOrCreateState(projectDir, sessionId) {
  let state = loadState(projectDir);

  // Reset state on new session
  if (!state || state.sessionId !== sessionId) {
    state = {
      sessionId: sessionId,
      lastTestModification: null,
      lastTestToolCount: -1,
      toolUseCount: 0,
      testFilesModified: [],
      sourceFilesWarned: [],
    };
  }

  return state;
}

// ─── Recency Check ──────────────────────────────────────────────────────────

function hasRecentTestModification(state) {
  if (!state.lastTestModification) {
    return false;
  }

  // Check tool count recency
  const toolCountDelta = state.toolUseCount - state.lastTestToolCount;
  if (toolCountDelta <= RECENCY_TOOL_COUNT) {
    return true;
  }

  // Check time recency
  const timeDelta = Date.now() - new Date(state.lastTestModification).getTime();
  if (timeDelta <= RECENCY_TIME_MS) {
    return true;
  }

  return false;
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  // Feature flag check (first thing)
  const flagValue = process.env.TDD_ADVISORY_ENABLED;
  if (flagValue === 'false' || flagValue === '0') {
    process.exit(0);
  }

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

  // Extract file path from tool input
  const toolInput = data.tool_input || data.toolInput || {};
  const filePath = toolInput.file_path || toolInput.filePath || '';

  if (!filePath) {
    process.exit(0);
  }

  // Check exclusions first (fast path)
  if (isExcluded(filePath)) {
    process.exit(0);
  }

  const projectDir = getProjectDir();
  const sessionId = data.session_id || process.env.CLAUDE_SESSION_ID || Date.now().toString(36);

  // Load or create state
  const state = getOrCreateState(projectDir, sessionId);
  state.toolUseCount++;

  const normalizedPath = normalize(filePath);

  // Handle test file modification
  if (isTestFile(filePath)) {
    state.lastTestModification = new Date().toISOString();
    state.lastTestToolCount = state.toolUseCount;
    if (!state.testFilesModified.includes(normalizedPath)) {
      state.testFilesModified.push(normalizedPath);
    }
    saveState(projectDir, state);
    process.exit(0);
  }

  // Only advise on source files
  if (!isSourceFile(filePath)) {
    saveState(projectDir, state);
    process.exit(0);
  }

  // Check if we have recent test modifications
  if (hasRecentTestModification(state)) {
    saveState(projectDir, state);
    process.exit(0);
  }

  // Check cooldown - one advisory per file per session
  if (state.sourceFilesWarned.includes(normalizedPath)) {
    saveState(projectDir, state);
    process.exit(0);
  }

  // Emit advisory
  const recentTestCount = state.testFilesModified.length;
  const fileName = path.basename(filePath);

  console.error(`[TDD Advisory] Modifying source file without recent test changes: ${fileName}`);
  console.error('');
  console.error('Consider following TDD workflow:');
  console.error('  1. Write/update test first (Red)');
  console.error('  2. Modify source to pass test (Green)');
  console.error('  3. Refactor if needed');
  console.error('');
  console.error(`Recent test modifications: ${recentTestCount} files within last ${RECENCY_TOOL_COUNT} tool uses`);
  console.error('');
  console.error('To disable this advisory: TDD_ADVISORY_ENABLED=false');

  // Add to cooldown list
  state.sourceFilesWarned.push(normalizedPath);
  saveState(projectDir, state);

  // Always non-blocking
  process.exit(0);
}

main().catch((err) => {
  // Hook error - never block
  console.error('[tdd-advisory] Error:', err.message);
  process.exit(0);
});
