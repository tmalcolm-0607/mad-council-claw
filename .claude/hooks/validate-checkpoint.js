#!/usr/bin/env node

/**
 * validate-checkpoint.js
 *
 * Purpose: Warn when phase transitions happen without plan updates.
 *
 * This hook monitors for signs of phase transitions in the workflow and
 * warns if the plan.md file hasn't been updated recently. This helps
 * ensure that progress is tracked in real-time as required by the
 * plan-management rules.
 *
 * Event: PostToolUse (Bash) - checks after commands that suggest phase transitions
 * Behavior: Warning only (non-blocking)
 *
 * Detects phase transition indicators:
 * - "phase complete" or "phase [N] complete" in tool output
 * - Moving to next phase keywords
 * - Checkpoint completion markers
 *
 * Checks:
 * - Was plan.md modified in the last 5 minutes?
 * - Does ACTIVE work item exist?
 */

const fs = require('fs');
const path = require('path');

// Phase transition keywords to detect
const PHASE_TRANSITION_KEYWORDS = [
  'phase complete',
  'phase 1 complete',
  'phase 2 complete',
  'phase 3 complete',
  'phase 4 complete',
  'phase 5 complete',
  'phase 6 complete',
  'phase 7 complete',
  'phase 8 complete',
  'phase 9 complete',
  'phase 10 complete',
  'moving to phase',
  'proceeding to phase',
  'checkpoint complete',
  'implementation complete',
  'investigation complete',
  'review complete',
  'verification complete'
];

// Time threshold for "recent" plan update (5 minutes)
const PLAN_UPDATE_THRESHOLD_MS = 5 * 60 * 1000;

/**
 * Find the active work item directory
 */
function findActiveWorkItem(projectDir) {
  const activeFile = path.join(projectDir, '.claude', 'work-items', 'ACTIVE');

  try {
    if (fs.existsSync(activeFile)) {
      const workItemId = fs.readFileSync(activeFile, 'utf8').trim();
      if (workItemId) {
        return path.join(projectDir, '.claude', 'work-items', workItemId);
      }
    }
  } catch (err) {
    // Ignore errors reading ACTIVE file
  }

  return null;
}

/**
 * Find plan.md files that might be relevant
 */
function findPlanFiles(projectDir, workItemDir) {
  const planFiles = [];

  // Check work item directory
  if (workItemDir) {
    const workItemPlan = path.join(workItemDir, 'plan.md');
    if (fs.existsSync(workItemPlan)) {
      planFiles.push(workItemPlan);
    }
  }

  // Check specs directory for feature plans
  const specsDir = path.join(projectDir, 'specs');
  if (fs.existsSync(specsDir)) {
    try {
      const specDirs = fs.readdirSync(specsDir, { withFileTypes: true })
        .filter(d => d.isDirectory())
        .map(d => d.name);

      for (const specDir of specDirs) {
        const specPlan = path.join(specsDir, specDir, 'plan.md');
        if (fs.existsSync(specPlan)) {
          planFiles.push(specPlan);
        }
      }
    } catch (err) {
      // Ignore errors reading specs directory
    }
  }

  return planFiles;
}

/**
 * Check if any plan file was recently modified
 */
function isPlanRecentlyUpdated(planFiles) {
  const now = Date.now();

  for (const planFile of planFiles) {
    try {
      const stats = fs.statSync(planFile);
      const mtime = stats.mtimeMs;

      if (now - mtime < PLAN_UPDATE_THRESHOLD_MS) {
        return { recent: true, file: planFile, mtime };
      }
    } catch (err) {
      // Ignore errors checking file stats
    }
  }

  return { recent: false };
}

/**
 * Check if output indicates a phase transition
 */
function detectsPhaseTransition(output) {
  if (!output) return false;

  const lowerOutput = output.toLowerCase();

  for (const keyword of PHASE_TRANSITION_KEYWORDS) {
    if (lowerOutput.includes(keyword)) {
      return keyword;
    }
  }

  return false;
}

/**
 * Main hook execution
 */
async function main() {
  let input = '';

  // Read JSON input from stdin
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    process.exit(0);
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch (err) {
    // Invalid JSON, skip
    process.exit(0);
  }

  // Only check PostToolUse events for Bash
  if (data.hook_event_name !== 'PostToolUse' || data.tool_name !== 'Bash') {
    process.exit(0);
  }

  const toolOutput = data.tool_output || '';

  // Check if the output indicates a phase transition
  const transitionKeyword = detectsPhaseTransition(toolOutput);

  if (!transitionKeyword) {
    // No phase transition detected
    process.exit(0);
  }

  // Phase transition detected - check if plan was updated
  const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const workItemDir = findActiveWorkItem(projectDir);
  const planFiles = findPlanFiles(projectDir, workItemDir);

  if (planFiles.length === 0) {
    // No plan files found - this is okay, may not be using MAD workflow
    process.exit(0);
  }

  const planStatus = isPlanRecentlyUpdated(planFiles);

  if (!planStatus.recent) {
    // Plan not recently updated - emit warning
    console.error(`
WARNING: Phase transition detected but plan.md may not be updated.

Detected: "${transitionKeyword}"

Plan files checked:
${planFiles.map(f => `  - ${f}`).join('\n')}

REMINDER: Per plan-management rules, you MUST update the plan file:
  - Mark checkboxes as [x] when tasks complete
  - Fill Results sections with findings
  - Update phase status to "Complete"
  - Include file:line references for code findings

The plan file is the SOURCE OF TRUTH for progress tracking.
`);
  }

  // Always exit 0 (non-blocking warning)
  process.exit(0);
}

main().catch(err => {
  console.error(`validate-checkpoint.js error: ${err.message}`);
  process.exit(0); // Non-blocking
});
