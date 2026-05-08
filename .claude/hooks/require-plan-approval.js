#!/usr/bin/env node

/**
 * Plan Mode Enforcement Hook (PreToolUse: Write|Edit)
 *
 * Encourages planning before implementation with a non-blocking warning.
 * Research shows 2 minutes of planning saves 20 minutes of refactoring (10x ROI).
 *
 * Behavior:
 * 1. Triggers on Edit/Write targeting src/**\/*.{cs,ts,tsx,js,jsx}
 * 2. Checks if plan.md exists with approval marker in active work item
 * 3. Emits non-blocking warning if no approved plan found
 * 4. Cooldown: max 1 warning per 30 minutes per work item
 * 5. Never blocks (exit 0 only)
 */

const fs = require('fs');
const path = require('path');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

const COOLDOWN_MS = 30 * 60 * 1000; // 30 minutes
const STATE_FILE = '.mad/scratch/plan-mode-warnings.json';

// File extensions that indicate implementation code
const IMPL_EXTENSIONS = new Set(['.cs', '.ts', '.tsx', '.js', '.jsx']);

// Approval markers in plan.md
const APPROVAL_MARKERS = [
  /\[APPROVED\]/i,
  /Plan:\s*APPROVED/i,
  /Status:\s*APPROVED/i,
  /##\s*Approval.*\n.*approved/i,
  /\*\*Status\*\*:\s*Approved/i
];

/**
 * Get project directory by walking up to find .claude folder
 */
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

/**
 * Check if the target file is implementation code under src/
 */
function isImplementationFile(filePath, projectDir) {
  const normalized = filePath.replace(/\\/g, '/');
  const normalizedProject = projectDir.replace(/\\/g, '/');

  let relativePath = normalized;
  if (normalized.startsWith(normalizedProject)) {
    relativePath = normalized.slice(normalizedProject.length);
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.slice(1);
    }
  }

  // Must be under src/
  if (!relativePath.startsWith('src/')) {
    return false;
  }

  // Must have an implementation file extension
  const ext = path.extname(relativePath).toLowerCase();
  return IMPL_EXTENSIONS.has(ext);
}

/**
 * Get the active work item ID via session-aware helper
 */
function getActiveWorkItemId(projectDir, data) {
  try {
    const { wiId } = resolveActiveWI(data, projectDir);
    return wiId;
  } catch (e) {
    return null;
  }
}

/**
 * Find plan.md for the active work item or in specs/
 */
function findPlanFile(projectDir, workItemId) {
  const candidates = [];

  // Check work item's spec directory via manifest
  if (workItemId) {
    try {
      const manifestPath = path.join(projectDir, '.claude/work-items', workItemId, 'manifest.json');
      if (fs.existsSync(manifestPath)) {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
        const specDir = manifest.spec_dir || manifest.specDir;
        if (specDir) {
          candidates.push(path.join(projectDir, specDir, 'plan.md'));
        }
      }
    } catch (e) {
      // Ignore manifest errors
    }
  }

  // Check common spec directories
  try {
    const specsDir = path.join(projectDir, 'specs');
    if (fs.existsSync(specsDir)) {
      const entries = fs.readdirSync(specsDir);
      for (const entry of entries) {
        const planPath = path.join(specsDir, entry, 'plan.md');
        candidates.push(planPath);
      }
    }
  } catch (e) {
    // Ignore
  }

  return candidates;
}

/**
 * Check if any plan file has an approval marker
 */
function hasApprovedPlan(projectDir, workItemId) {
  const candidates = findPlanFile(projectDir, workItemId);

  for (const planPath of candidates) {
    try {
      if (!fs.existsSync(planPath)) continue;

      const content = fs.readFileSync(planPath, 'utf8');
      for (const marker of APPROVAL_MARKERS) {
        if (marker.test(content)) {
          return true;
        }
      }
    } catch (e) {
      // Ignore read errors
    }
  }

  return false;
}

/**
 * Load cooldown state
 */
function loadState(projectDir) {
  const statePath = path.join(projectDir, STATE_FILE);
  try {
    if (fs.existsSync(statePath)) {
      return JSON.parse(fs.readFileSync(statePath, 'utf8'));
    }
  } catch (e) {
    // Start fresh on error
  }
  return {};
}

/**
 * Save cooldown state
 */
function saveState(projectDir, state) {
  const statePath = path.join(projectDir, STATE_FILE);
  try {
    const dir = path.dirname(statePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  } catch (e) {
    // Silently fail - state is ephemeral
  }
}

/**
 * Check if we're within cooldown for this work item
 */
function isInCooldown(state, workItemId) {
  const key = workItemId || '__no_work_item__';
  const lastWarning = state[key];
  if (!lastWarning) return false;

  return (Date.now() - lastWarning) < COOLDOWN_MS;
}

/**
 * Record warning timestamp for cooldown
 */
function recordWarning(state, workItemId) {
  const key = workItemId || '__no_work_item__';
  state[key] = Date.now();
}

/**
 * Main hook handler
 */
async function main() {
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

  const projectDir = getProjectDir();

  // Only check implementation files under src/
  if (!isImplementationFile(filePath, projectDir)) {
    process.exit(0);
  }

  const workItemId = getActiveWorkItemId(projectDir, data);

  // Check if there's an approved plan
  if (hasApprovedPlan(projectDir, workItemId)) {
    process.exit(0);
  }

  // Check cooldown
  const state = loadState(projectDir);
  if (isInCooldown(state, workItemId)) {
    process.exit(0);
  }

  // Emit non-blocking warning
  console.error(`
[PLAN-MODE] Consider plan mode first
${'='.repeat(50)}

Research shows 2 minutes of planning saves 20 minutes of refactoring (10x ROI).

No approved plan found for the current work item.
Use EnterPlanMode tool or /mad-plan skill to create a plan before implementing.

This is a non-blocking reminder. You may continue without a plan.
${'='.repeat(50)}
`);

  // Record warning for cooldown
  recordWarning(state, workItemId);
  saveState(projectDir, state);

  // Always exit 0 (non-blocking)
  process.exit(0);
}

main().catch((err) => {
  // Hook error - fail-open (advisory hook)
  console.error('[require-plan-approval] FATAL ERROR:', err.message);
  console.error('[require-plan-approval] Hook failed - continuing (advisory).');
  process.exit(0);
});
