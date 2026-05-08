#!/usr/bin/env node
/**
 * File Ownership Analyzer Library
 *
 * Prevents race conditions in parallel task execution by detecting when
 * multiple tasks in the same wave modify the same files.
 *
 * Features:
 * - Extract file paths from task metadata (dag.ownedFiles) or description text
 * - Build file-to-task mappings
 * - Detect conflicts (same file, same wave)
 * - Propose resolution strategies (serialize or move-to-next-wave)
 *
 * All exported functions are pure (no side effects, no I/O).
 *
 * Usage:
 *   const { analyzeFileOwnership } = require('./file-ownership.js');
 *   const result = analyzeFileOwnership(tasks);
 *   if (result.conflicts.length > 0) { ... }
 */

// ============================================================
// Path Extraction
// ============================================================

/**
 * Regex patterns for extracting file paths from description text.
 *
 * Order matters: backtick and quoted patterns are checked first to
 * extract paths from delimited contexts before falling back to
 * bare path matching.
 */
const BACKTICK_PATH_RE = /`([^`]+\.[a-zA-Z]{1,5})`/g;
const QUOTED_PATH_RE = /"([^"]+\.[a-zA-Z]{1,5})"/g;
const BARE_PATH_RE = /(?:(?:\.\.?\/)?(?:[a-zA-Z0-9_\-]+\/)+[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*\.[a-zA-Z]{1,5})/g;

/**
 * Prefixes that indicate a path is a valid source file rather than
 * an arbitrary string that happens to contain dots and slashes.
 */
const VALID_PATH_PREFIXES = ['src/', 'tests/', 'test/', 'lib/', 'frontend/', 'infra/'];

/**
 * Normalize a file path by stripping leading ./ or ../ prefixes.
 *
 * @param {string} filePath - Raw file path
 * @returns {string} Normalized path
 */
function normalizePath(filePath) {
  let normalized = filePath;
  // Strip leading ./ or ../
  while (normalized.startsWith('./') || normalized.startsWith('../')) {
    if (normalized.startsWith('./')) {
      normalized = normalized.slice(2);
    } else if (normalized.startsWith('../')) {
      normalized = normalized.slice(3);
    }
  }
  // Normalize backslashes to forward slashes
  normalized = normalized.replace(/\\/g, '/');
  return normalized;
}

/**
 * Check if a path looks like a valid source file path.
 *
 * @param {string} filePath - Normalized file path
 * @returns {boolean} True if the path starts with a recognized prefix or contains a glob pattern
 */
function isValidSourcePath(filePath) {
  // Glob patterns are always kept
  if (filePath.includes('**') || filePath.includes('*')) {
    return true;
  }
  // Must start with a known source prefix
  return VALID_PATH_PREFIXES.some(prefix => filePath.startsWith(prefix));
}

/**
 * Extract file paths from a description string.
 *
 * Applies multiple regex patterns to find file references, normalizes
 * them, filters to valid source paths, and deduplicates.
 *
 * @param {string} description - Task description text
 * @returns {string[]} Array of unique, normalized file paths
 */
function extractPathsFromDescription(description) {
  if (!description || typeof description !== 'string') {
    return [];
  }

  const found = new Set();

  // Extract backtick-quoted paths: `path/file.ext`
  let match;
  BACKTICK_PATH_RE.lastIndex = 0;
  while ((match = BACKTICK_PATH_RE.exec(description)) !== null) {
    const normalized = normalizePath(match[1]);
    if (isValidSourcePath(normalized)) {
      found.add(normalized);
    }
  }

  // Extract double-quoted paths: "path/file.ext"
  QUOTED_PATH_RE.lastIndex = 0;
  while ((match = QUOTED_PATH_RE.exec(description)) !== null) {
    const normalized = normalizePath(match[1]);
    if (isValidSourcePath(normalized)) {
      found.add(normalized);
    }
  }

  // Extract bare paths: path/to/file.ext
  BARE_PATH_RE.lastIndex = 0;
  while ((match = BARE_PATH_RE.exec(description)) !== null) {
    const normalized = normalizePath(match[0]);
    if (isValidSourcePath(normalized)) {
      found.add(normalized);
    }
  }

  return Array.from(found);
}

/**
 * Extract file paths from a task's ownedFiles metadata or description.
 *
 * Prefers explicit dag.ownedFiles when available. Falls back to parsing
 * the task description for file path references.
 *
 * @param {Object} task - Task object with optional dag.ownedFiles and description
 * @returns {string[]} Array of file paths this task modifies
 */
function extractFilesFromTask(task) {
  if (!task || typeof task !== 'object') {
    return [];
  }

  // Prefer explicit metadata
  if (task.dag && typeof task.dag === 'object' && Array.isArray(task.dag.ownedFiles)) {
    // Return normalized paths, filtering empty strings
    return task.dag.ownedFiles
      .filter(f => typeof f === 'string' && f.length > 0)
      .map(normalizePath);
  }

  // Fallback: parse from description
  if (task.description) {
    return extractPathsFromDescription(task.description);
  }

  return [];
}

// ============================================================
// File Map Building
// ============================================================

/**
 * Build a mapping of file paths to the task IDs that modify them.
 *
 * @param {Object[]} tasks - Array of task objects
 * @returns {Object} Map where keys are file paths and values are arrays of task IDs
 */
function buildFileMap(tasks) {
  if (!Array.isArray(tasks)) {
    return {};
  }

  const fileMap = {};

  for (const task of tasks) {
    if (!task || !task.id) continue;

    const files = extractFilesFromTask(task);
    for (const file of files) {
      if (!fileMap[file]) {
        fileMap[file] = [];
      }
      if (!fileMap[file].includes(task.id)) {
        fileMap[file].push(task.id);
      }
    }
  }

  return fileMap;
}

// ============================================================
// Conflict Detection
// ============================================================

/**
 * Check if a glob/wildcard pattern could overlap with a specific file path.
 *
 * Uses simple heuristic matching:
 * - `src/**\/*.ts` overlaps with any `src/.../file.ts`
 * - `*.ts` overlaps with any `.ts` file
 *
 * @param {string} pattern - Glob pattern (contains * or **)
 * @param {string} filePath - Specific file path
 * @returns {boolean} True if the pattern could match the file path
 */
function wildcardOverlaps(pattern, filePath) {
  // Extract the directory prefix before any glob wildcard
  const globIndex = pattern.indexOf('*');
  if (globIndex === -1) return false;

  const prefix = pattern.slice(0, globIndex);

  // If the file starts with the same prefix, there is potential overlap
  if (prefix.length > 0 && filePath.startsWith(prefix)) {
    // Check extension match if the pattern specifies one
    const extMatch = pattern.match(/\*\.([a-zA-Z]+)$/);
    if (extMatch) {
      return filePath.endsWith('.' + extMatch[1]);
    }
    return true;
  }

  // If prefix is empty (e.g., *.ts), check extension only
  if (prefix.length === 0) {
    const extMatch = pattern.match(/\*\.([a-zA-Z]+)$/);
    if (extMatch) {
      return filePath.endsWith('.' + extMatch[1]);
    }
    return true;
  }

  return false;
}

/**
 * Detect file ownership conflicts within execution waves.
 *
 * A conflict occurs when multiple tasks in the same wave modify the same file.
 * Wildcard patterns are checked for overlap with specific file paths.
 *
 * @param {Object[]} tasks - Tasks with wave assignments
 * @param {Object} fileMap - File-to-task-ID mapping from buildFileMap
 * @returns {Object[]} Array of conflict objects with file, wave, tasks, and severity
 */
function detectConflicts(tasks, fileMap) {
  if (!Array.isArray(tasks) || tasks.length === 0) {
    return [];
  }

  // Build task-to-wave lookup
  const taskWaveMap = new Map();
  for (const task of tasks) {
    if (task && task.id !== undefined) {
      taskWaveMap.set(task.id, task.wave);
    }
  }

  const conflicts = [];

  // Separate wildcards from specific paths
  const wildcardPaths = [];
  const specificPaths = [];

  for (const filePath of Object.keys(fileMap)) {
    if (filePath.includes('*')) {
      wildcardPaths.push(filePath);
    } else {
      specificPaths.push(filePath);
    }
  }

  // Check specific file conflicts (exact same file, same wave)
  for (const filePath of specificPaths) {
    const taskIds = fileMap[filePath];
    if (taskIds.length < 2) continue;

    // Group tasks by wave
    const waveGroups = new Map();
    for (const taskId of taskIds) {
      const wave = taskWaveMap.get(taskId);
      if (!waveGroups.has(wave)) {
        waveGroups.set(wave, []);
      }
      waveGroups.get(wave).push(taskId);
    }

    // Report conflicts for waves with 2+ tasks
    for (const [wave, waveTasks] of waveGroups) {
      if (waveTasks.length >= 2) {
        conflicts.push({
          file: filePath,
          wave: wave !== undefined ? wave : 0,
          tasks: waveTasks.sort(),
          severity: 'HIGH'
        });
      }
    }
  }

  // Check wildcard-to-specific overlaps
  for (const wildcardPath of wildcardPaths) {
    const wildcardTaskIds = fileMap[wildcardPath];

    for (const specificPath of specificPaths) {
      if (!wildcardOverlaps(wildcardPath, specificPath)) continue;

      const specificTaskIds = fileMap[specificPath];

      // Find tasks from each set that share a wave
      for (const wTaskId of wildcardTaskIds) {
        const wWave = taskWaveMap.get(wTaskId);
        for (const sTaskId of specificTaskIds) {
          if (wTaskId === sTaskId) continue;
          const sWave = taskWaveMap.get(sTaskId);
          if (wWave === sWave) {
            // Check if this conflict is already recorded
            const existingConflict = conflicts.find(
              c => c.file === specificPath && c.wave === wWave
            );
            if (existingConflict) {
              if (!existingConflict.tasks.includes(wTaskId)) {
                existingConflict.tasks.push(wTaskId);
                existingConflict.tasks.sort();
              }
            } else {
              conflicts.push({
                file: specificPath,
                wave: wWave !== undefined ? wWave : 0,
                tasks: [wTaskId, sTaskId].sort(),
                severity: 'HIGH'
              });
            }
          }
        }
      }
    }

    // Check wildcard-to-wildcard overlaps in same wave
    for (const otherWildcard of wildcardPaths) {
      if (otherWildcard <= wildcardPath) continue; // avoid duplicates
      const otherTaskIds = fileMap[otherWildcard];

      // Simple prefix-based overlap check between two wildcards
      const prefix1 = wildcardPath.slice(0, wildcardPath.indexOf('*'));
      const prefix2 = otherWildcard.slice(0, otherWildcard.indexOf('*'));
      const overlaps = prefix1.startsWith(prefix2) || prefix2.startsWith(prefix1);
      if (!overlaps) continue;

      for (const wTaskId of wildcardTaskIds) {
        const wWave = taskWaveMap.get(wTaskId);
        for (const oTaskId of otherTaskIds) {
          if (wTaskId === oTaskId) continue;
          const oWave = taskWaveMap.get(oTaskId);
          if (wWave === oWave) {
            conflicts.push({
              file: `${wildcardPath} <> ${otherWildcard}`,
              wave: wWave !== undefined ? wWave : 0,
              tasks: [wTaskId, oTaskId].sort(),
              severity: 'HIGH'
            });
          }
        }
      }
    }
  }

  // Sort conflicts by wave, then by file for deterministic output
  conflicts.sort((a, b) => {
    if (a.wave !== b.wave) return a.wave - b.wave;
    return a.file.localeCompare(b.file);
  });

  return conflicts;
}

// ============================================================
// Conflict Resolution
// ============================================================

/**
 * Resolve file ownership conflicts by proposing wave adjustments.
 *
 * Produces two resolution strategies:
 *
 * **Serialize**: Keep the first conflicting task in its wave and move each
 * subsequent task to incrementally later waves. This provides maximum
 * parallelism for non-conflicting tasks.
 *
 * **MoveToNext**: Move all conflicting tasks (except the first) to the next
 * wave after their current one. Simpler but more conservative.
 *
 * @param {Object[]} conflicts - Detected conflicts from detectConflicts
 * @param {Object[]} tasks - Original task array
 * @returns {Object} Resolution strategies with waveAdjustments arrays
 */
function resolveConflicts(conflicts, tasks) {
  const empty = {
    serialize: { waveAdjustments: [] },
    moveToNext: { waveAdjustments: [] }
  };

  if (!Array.isArray(conflicts) || conflicts.length === 0) {
    return empty;
  }

  // Track which tasks have already been adjusted to avoid duplicates
  const serializeAdjusted = new Map(); // taskId -> toWave
  const moveAdjusted = new Map();      // taskId -> toWave

  const serializeAdjustments = [];
  const moveAdjustments = [];

  for (const conflict of conflicts) {
    const { wave, tasks: conflictTaskIds } = conflict;
    if (!Array.isArray(conflictTaskIds) || conflictTaskIds.length < 2) continue;

    const fromWave = typeof wave === 'number' ? wave : 0;

    // Keep first task, move others
    for (let i = 1; i < conflictTaskIds.length; i++) {
      const taskId = conflictTaskIds[i];

      // Serialize strategy: increment wave for each subsequent conflicting task
      if (!serializeAdjusted.has(taskId)) {
        const toWave = fromWave + i;
        serializeAdjusted.set(taskId, toWave);
        serializeAdjustments.push({
          taskId,
          fromWave,
          toWave,
          reason: `File conflict: ${conflict.file}`
        });
      }

      // MoveToNext strategy: move all conflicting to wave+1
      if (!moveAdjusted.has(taskId)) {
        const toWave = fromWave + 1;
        moveAdjusted.set(taskId, toWave);
        moveAdjustments.push({
          taskId,
          fromWave,
          toWave,
          reason: `File conflict: ${conflict.file}`
        });
      }
    }
  }

  return {
    serialize: { waveAdjustments: serializeAdjustments },
    moveToNext: { waveAdjustments: moveAdjustments }
  };
}

// ============================================================
// Main Entry Point
// ============================================================

/**
 * Analyze file ownership across tasks and detect conflicts.
 *
 * This is the primary entry point. It extracts file paths from all tasks,
 * builds a file-to-task mapping, detects same-wave conflicts, and proposes
 * resolution strategies.
 *
 * @param {Object[]} tasks - Tasks with wave assignments and file metadata
 * @returns {{
 *   fileMap: Object,
 *   conflicts: Object[],
 *   resolutions: {
 *     serialize: { waveAdjustments: Object[] },
 *     moveToNext: { waveAdjustments: Object[] }
 *   }
 * }} Analysis result with file map, conflicts, and resolution strategies
 */
function analyzeFileOwnership(tasks) {
  if (!Array.isArray(tasks) || tasks.length === 0) {
    return {
      fileMap: {},
      conflicts: [],
      resolutions: {
        serialize: { waveAdjustments: [] },
        moveToNext: { waveAdjustments: [] }
      }
    };
  }

  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);
  const resolutions = resolveConflicts(conflicts, tasks);

  return {
    fileMap,
    conflicts,
    resolutions
  };
}

// ============================================================
// Wave Splitting
// ============================================================

/**
 * Split a wave's tasks into parallel and serial groups based on file conflicts.
 *
 * When multiple tasks in a wave modify the same file, they must be serialized
 * to prevent race conditions. This function identifies which tasks can run
 * in parallel and which must be deferred to sequential execution.
 *
 * Strategy:
 * - First task in each conflict group stays in parallelTasks
 * - Subsequent tasks in conflict group move to serialTasks
 * - Tasks with no conflicts stay in parallelTasks
 *
 * @param {Object} wave - Wave object with { waveNumber, tasks: [taskIds...], estimatedDuration }
 * @param {Array<Object>} conflicts - Conflicts array from analyzeFileOwnership
 * @param {Array<Object>} tasks - Full array of task objects with { id, description, ... }
 * @returns {Object} { parallelTasks: [...], serialTasks: [...] } - Arrays of task objects
 *
 * @example
 *   const wave = { waveNumber: 1, tasks: ['T1', 'T2', 'T3'], estimatedDuration: 300 };
 *   const conflicts = [{ file: 'src/foo.js', wave: 1, tasks: ['T1', 'T2'], severity: 'HIGH' }];
 *   const tasks = [
 *     { id: 'T1', description: 'Modify foo.js' },
 *     { id: 'T2', description: 'Also modify foo.js' },
 *     { id: 'T3', description: 'Modify bar.js' }
 *   ];
 *   const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);
 *   // parallelTasks: [T1, T3]  - T1 is first in conflict, T3 has no conflict
 *   // serialTasks: [T2]        - T2 conflicts with T1
 */
function splitWaveByConflicts(wave, conflicts, tasks) {
  // Input validation
  if (!wave || !Array.isArray(wave.tasks)) {
    return { parallelTasks: [], serialTasks: [] };
  }
  if (!Array.isArray(conflicts)) {
    conflicts = [];
  }
  if (!Array.isArray(tasks)) {
    tasks = [];
  }

  // Build task ID -> task object map for quick lookup
  const taskMap = new Map();
  for (const task of tasks) {
    if (task && task.id !== undefined) {
      taskMap.set(task.id, task);
    }
  }

  // Filter conflicts to only those in this wave
  const waveConflicts = conflicts.filter(c => c.wave === wave.waveNumber);

  // Track which tasks must be serialized (all but first in each conflict group)
  const tasksMustSerialize = new Set();

  for (const conflict of waveConflicts) {
    if (!Array.isArray(conflict.tasks) || conflict.tasks.length < 2) {
      continue;
    }

    // Sort conflict tasks to get consistent first task
    const sortedConflictTasks = [...conflict.tasks].sort();

    // First task stays parallel, rest must serialize
    for (let i = 1; i < sortedConflictTasks.length; i++) {
      tasksMustSerialize.add(sortedConflictTasks[i]);
    }
  }

  // Split wave tasks based on conflict analysis
  const parallelTasks = [];
  const serialTasks = [];

  for (const taskId of wave.tasks) {
    const taskObj = taskMap.get(taskId);
    if (!taskObj) {
      // Task ID in wave but not in tasks array - skip
      continue;
    }

    if (tasksMustSerialize.has(taskId)) {
      serialTasks.push(taskObj);
    } else {
      parallelTasks.push(taskObj);
    }
  }

  return { parallelTasks, serialTasks };
}

// ============================================================
// Exports
// ============================================================

module.exports = {
  extractFilesFromTask,
  buildFileMap,
  detectConflicts,
  resolveConflicts,
  analyzeFileOwnership,
  splitWaveByConflicts
};
