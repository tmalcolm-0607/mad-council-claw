#!/usr/bin/env node

/**
 * Parallel Opportunity Detector Hook
 *
 * Triggers: UserPromptSubmit
 * Purpose: Detect when 3+ independent tasks could be parallelized but aren't
 *
 * Detects parallel execution opportunities and warns when:
 * - 3+ tasks in wave 1 (no dependencies)
 * - No team has been created
 * - Estimated time savings ≥ threshold
 * - Not within cooldown period
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
let resolveActiveWI;
try {
  ({ resolveActiveWI } = require('../../.mad/lib/resolve-active-wi'));
} catch {
  resolveActiveWI = () => ({ wiId: null });
}

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  MIN_PARALLEL_TASKS: 3,
  MIN_TIME_SAVINGS_MINUTES: 15,
  COOLDOWN_SECONDS: 300, // 5 minutes
  MAX_TEAMMATES_PER_WAVE: 6,
  STATE_FILE: path.join(__dirname, '..', '..', '.mad', 'scratch', 'parallel-opportunities-state.json'),
  THRESHOLDS_FILE: path.join(__dirname, '../rules/parallel-opportunity-thresholds.md')
};

// ============================================================================
// Utilities
// ============================================================================

function readJsonFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const content = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    return null;
  }
}

function writeJsonFile(filePath, data) {
  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
    return true;
  } catch (error) {
    return false;
  }
}

function readTextFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return fs.readFileSync(filePath, 'utf-8');
  } catch (error) {
    return null;
  }
}

function computeFingerprint(taskIds) {
  const sorted = [...taskIds].sort();
  return crypto.createHash('sha256').update(sorted.join(',')).digest('hex');
}

// ============================================================================
// State Management
// ============================================================================

function loadState() {
  return readJsonFile(CONFIG.STATE_FILE) || {
    lastWarningTimestamp: null,
    workItemId: null,
    tasksAnalyzed: [],
    fingerprint: null
  };
}

function saveState(state) {
  return writeJsonFile(CONFIG.STATE_FILE, state);
}

function isWithinCooldown(state) {
  if (!state.lastWarningTimestamp) return false;

  const lastWarning = new Date(state.lastWarningTimestamp);
  const now = new Date();
  const secondsSinceLastWarning = (now - lastWarning) / 1000;

  return secondsSinceLastWarning < CONFIG.COOLDOWN_SECONDS;
}

// ============================================================================
// Active Work Item Detection
// ============================================================================

function getActiveWorkItem(data) {
  const projectDir = path.resolve(__dirname, '../..');
  const { wiId } = resolveActiveWI(data, projectDir);
  return wiId || null;
}

function getTasksFilePath(workItemId) {
  // Try to find tasks.md in the work item or spec directory
  const workItemDir = path.join(__dirname, '../work-items', workItemId);
  const manifestPath = path.join(workItemDir, 'manifest.json');

  const manifest = readJsonFile(manifestPath);
  if (!manifest || !manifest.spec_directory) return null;

  // Spec directory might be relative to repo root
  const repoRoot = path.resolve(__dirname, '../..');
  const specDir = path.resolve(repoRoot, manifest.spec_directory);
  const tasksPath = path.join(specDir, 'tasks.md');

  if (!fs.existsSync(tasksPath)) return null;

  return tasksPath;
}

// ============================================================================
// DAG Analysis (Simple Wave Detection)
// ============================================================================

function parseTasksSimple(tasksContent) {
  const tasks = [];
  const taskRegex = /^-\s+\[[ x]\]\s+(T\d+)[\s:]+(.+)$/gm;

  let match;
  while ((match = taskRegex.exec(tasksContent)) !== null) {
    const taskId = match[1];
    const taskName = match[2];

    // Extract dependencies if present
    const taskSection = extractTaskSection(tasksContent, taskId);
    const dependencies = extractDependencies(taskSection);
    const ownedFiles = extractOwnedFiles(taskSection);
    const duration = estimateDuration(taskSection);

    tasks.push({
      id: taskId,
      name: taskName,
      dependencies: dependencies,
      ownedFiles: ownedFiles,
      estimatedMinutes: duration
    });
  }

  return tasks;
}

function extractTaskSection(content, taskId) {
  const lines = content.split('\n');
  const startIndex = lines.findIndex(line => line.includes(taskId));

  if (startIndex === -1) return '';

  // Find the next task or end of file
  let endIndex = lines.length;
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (lines[i].match(/^-\s+\[[ x]\]\s+T\d+/)) {
      endIndex = i;
      break;
    }
  }

  return lines.slice(startIndex, endIndex).join('\n');
}

function extractDependencies(taskSection) {
  const depMatch = taskSection.match(/\*\*Dependencies\*\*:\s*([^\n]+)/i);
  if (!depMatch) return [];

  const depString = depMatch[1].trim();
  if (depString.toLowerCase() === 'none') return [];

  // Extract T010, T020 format
  const deps = depString.match(/T\d+/g);
  return deps || [];
}

function extractOwnedFiles(taskSection) {
  const filesMatch = taskSection.match(/\*\*Owned Files\*\*:\s*([^\n]+)/i);
  if (!filesMatch) return [];

  const filesString = filesMatch[1].trim();
  if (filesString.toLowerCase() === 'none') return [];

  // Split by comma or semicolon
  return filesString.split(/[,;]/).map(f => f.trim()).filter(f => f);
}

function estimateDuration(taskSection) {
  // Check for explicit duration
  const durationMatch = taskSection.match(/\*\*Duration\*\*:\s*(\d+)\s*min/i);
  if (durationMatch) return parseInt(durationMatch[1], 10);

  // Heuristics based on content
  const lineCount = taskSection.split('\n').length;

  if (taskSection.toLowerCase().includes('test')) return 20;
  if (taskSection.toLowerCase().includes('documentation')) return 10;

  if (lineCount < 10) return 15; // Simple
  if (lineCount < 20) return 30; // Medium
  return 60; // Complex
}

function computeWaves(tasks) {
  const waves = [];
  const completed = new Set();
  let currentWaveTasks = [];

  // Find wave 1: tasks with no dependencies
  for (const task of tasks) {
    if (task.dependencies.length === 0) {
      currentWaveTasks.push(task);
    }
  }

  if (currentWaveTasks.length > 0) {
    waves.push(currentWaveTasks);
  }

  // We only care about wave 1 for this hook
  return waves;
}

function detectFileConflicts(tasks) {
  const conflicts = [];

  for (let i = 0; i < tasks.length; i++) {
    for (let j = i + 1; j < tasks.length; j++) {
      const task1 = tasks[i];
      const task2 = tasks[j];

      // Check for overlapping files
      const overlap = task1.ownedFiles.some(f1 =>
        task2.ownedFiles.some(f2 => f1 === f2 || hasWildcardOverlap(f1, f2))
      );

      if (overlap) {
        conflicts.push({ task1: task1.id, task2: task2.id });
      }
    }
  }

  return conflicts;
}

function hasWildcardOverlap(pattern1, pattern2) {
  // Simple wildcard check
  if (pattern1.includes('**') || pattern2.includes('**')) {
    // Extract the base path
    const base1 = pattern1.split('**')[0];
    const base2 = pattern2.split('**')[0];

    return pattern2.startsWith(base1) || pattern1.startsWith(base2);
  }

  return false;
}

// ============================================================================
// Warning Generation
// ============================================================================

function generateWarning(wave1Tasks, timeSavings, sequential, workItemId) {
  const count = wave1Tasks.length;
  const percentage = Math.round((timeSavings / sequential) * 100);

  const taskLines = wave1Tasks.map(t =>
    `  - ${t.id}: ${t.name} (~${t.estimatedMinutes}min)`
  ).join('\n');

  return `
[Parallel Opportunity] ${count} independent tasks detected (wave 1):
${taskLines}

  Estimated time savings: ${percentage}% (${formatDuration(timeSavings)} vs ${formatDuration(sequential)} sequential)

  Recommend: TeamCreate + spawn ${Math.min(count, CONFIG.MAX_TEAMMATES_PER_WAVE)} teammates in parallel

  See: .claude/rules/parallel-opportunity-thresholds.md for thresholds
  Work Item: ${workItemId}
`;
}

function formatDuration(minutes) {
  if (minutes < 60) return `${minutes}min`;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return mins > 0 ? `${hours}h ${mins}min` : `${hours}h`;
}

// ============================================================================
// Main Hook Logic
// ============================================================================

async function main() {
  try {
    // Parse stdin for hook payload (contains session_id for resolveActiveWI)
    let data = {};
    try {
      let input = '';
      for await (const chunk of process.stdin) {
        input += chunk;
      }
      if (input.trim()) {
        data = JSON.parse(input);
      }
    } catch (_) {
      // Use empty data — resolveActiveWI will fall back to CLAUDE_SESSION_ID env var
    }

    // 1. Check if there's an active work item
    const workItemId = getActiveWorkItem(data);
    if (!workItemId) {
      process.exit(0); // No active work item, nothing to check
    }

    // 2. Find tasks.md
    const tasksPath = getTasksFilePath(workItemId);
    if (!tasksPath) {
      process.exit(0); // No tasks.md found
    }

    // 3. Parse tasks
    const tasksContent = readTextFile(tasksPath);
    if (!tasksContent) {
      process.exit(0); // Can't read tasks
    }

    const tasks = parseTasksSimple(tasksContent);
    if (tasks.length < CONFIG.MIN_PARALLEL_TASKS) {
      process.exit(0); // Not enough tasks
    }

    // 4. Compute waves
    const waves = computeWaves(tasks);
    if (waves.length === 0 || waves[0].length < CONFIG.MIN_PARALLEL_TASKS) {
      process.exit(0); // Wave 1 doesn't have enough parallel tasks
    }

    const wave1Tasks = waves[0];

    // 5. Check for file conflicts
    const conflicts = detectFileConflicts(wave1Tasks);
    if (conflicts.length > 0) {
      process.exit(0); // File conflicts prevent parallelization
    }

    // 6. Calculate time savings
    const sequential = wave1Tasks.reduce((sum, t) => sum + t.estimatedMinutes, 0);
    const parallel = Math.max(...wave1Tasks.map(t => t.estimatedMinutes));
    const timeSavings = sequential - parallel;

    if (timeSavings < CONFIG.MIN_TIME_SAVINGS_MINUTES) {
      process.exit(0); // Not enough time savings
    }

    // 7. Check deduplication
    const state = loadState();
    const fingerprint = computeFingerprint(wave1Tasks.map(t => t.id));

    if (state.fingerprint === fingerprint && state.workItemId === workItemId) {
      if (isWithinCooldown(state)) {
        process.exit(0); // Within cooldown for same task set
      }
    }

    // 8. Emit warning
    const warning = generateWarning(wave1Tasks, timeSavings, sequential, workItemId);
    console.error(warning);

    // 9. Update state
    saveState({
      lastWarningTimestamp: new Date().toISOString(),
      workItemId: workItemId,
      tasksAnalyzed: wave1Tasks.map(t => t.id),
      fingerprint: fingerprint
    });

    process.exit(0); // Always exit 0 (non-blocking)

  } catch (error) {
    // fail-open: advisory hook should not crash session
    console.error('[parallel-opportunity-detector] ERROR:', error.message);
    process.exit(0);
  }
}

// ============================================================================
// Entry Point
// ============================================================================

if (require.main === module) {
  main().catch(e => {
    // fail-open: advisory hook should not crash session
    console.error('[parallel-opportunity-detector] ERROR:', e.message);
    process.exit(0);
  });
}

module.exports = { main };
