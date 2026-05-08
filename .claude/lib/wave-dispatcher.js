#!/usr/bin/env node
/**
 * Wave Dispatcher - Parallel and Sequential Task Execution
 *
 * Coordinates parallel task execution using Claude Code Task System (Agent Teams)
 * with fallback to sequential execution when teams are unavailable.
 *
 * Features:
 * - Parallel dispatch via TaskCreate for non-conflicting tasks
 * - Sequential execution for conflicting tasks
 * - Teammate prompt generation with file ownership boundaries
 * - Result polling and aggregation
 *
 * All exported functions follow async/await patterns for execution coordination.
 *
 * Usage:
 *   const { dispatchWave } = require('./wave-dispatcher.js');
 *   const result = await dispatchWave(wave, parallelTasks, serialTasks, config);
 */

// ============================================================
// Teammate Prompt Generation
// ============================================================

/**
 * Generate a clear, actionable prompt for a teammate to execute a task.
 *
 * The prompt includes:
 * - Task description with full context
 * - Owned files that the task is allowed to modify
 * - File ownership boundaries (what NOT to touch)
 * - Expected deliverables
 *
 * @param {Object} task - Task object with { id, description, dag: { ownedFiles } }
 * @returns {string} Generated prompt for the teammate
 *
 * @example
 *   const task = {
 *     id: 'T001',
 *     description: 'Add validation to User model',
 *     dag: { ownedFiles: ['src/models/User.js'] }
 *   };
 *   const prompt = buildTeammatePrompt(task);
 */
function buildTeammatePrompt(task) {
  if (!task || !task.id) {
    throw new Error('Task must have an id');
  }

  const description = task.description || 'No description provided';
  const ownedFiles = (task.dag && Array.isArray(task.dag.ownedFiles))
    ? task.dag.ownedFiles
    : [];

  let prompt = `Execute the following task:\n\n`;
  prompt += `**Task ID**: ${task.id}\n\n`;
  prompt += `**Description**:\n${description}\n\n`;

  if (ownedFiles.length > 0) {
    prompt += `**File Ownership**:\n`;
    prompt += `You are authorized to modify these files:\n`;
    for (const file of ownedFiles) {
      prompt += `- ${file}\n`;
    }
    prompt += `\n`;
    prompt += `**IMPORTANT**: Do not modify files outside this list to prevent conflicts with other parallel tasks.\n\n`;
  }

  prompt += `**Expected Deliverables**:\n`;
  prompt += `1. Complete the task as described\n`;
  prompt += `2. Write or update tests for your changes\n`;
  prompt += `3. Ensure all tests pass\n`;
  prompt += `4. Report completion status\n`;

  return prompt;
}

// ============================================================
// Task Completion Polling with Timeout
// ============================================================

/**
 * Send shutdown request to a teammate (placeholder for future implementation).
 *
 * @param {string} taskId - Task ID of the teammate to shutdown
 * @returns {Promise<void>}
 */
async function sendShutdownRequest(taskId) {
  // TODO: Integrate with SendMessage tool in runtime adapter
  // For now, log the shutdown request
  console.warn(`[wave-dispatcher] Sending shutdown request to teammate: ${taskId}`);
}

/**
 * Poll a task's status until completion or timeout.
 *
 * Uses Promise.race pattern with exponential backoff polling:
 * - Initial poll: 100ms
 * - Max poll: 2000ms
 * - Default timeout: 300000ms (5 minutes), configurable via DAG_TEAMMATE_TIMEOUT env var
 *
 * On timeout, sends shutdown request to teammate and returns timeout error.
 *
 * @param {string} taskId - Task ID to poll (from TaskCreate)
 * @param {number} timeoutMs - Maximum time to wait (default from env or 300000ms)
 * @returns {Promise<Object>} { success: boolean, result: any, duration: number, error?: string }
 *
 * @example
 *   const result = await awaitTeammateCompletion('task-123', 60000);
 *   if (result.success) {
 *     console.log('Task completed:', result.result);
 *   } else if (result.error === 'Teammate timeout') {
 *     console.warn('Task timed out');
 *   }
 */
async function awaitTeammateCompletion(taskId, timeoutMs, adapter) {
  // Use env var or provided timeout or default 5 minutes
  const effectiveTimeout = timeoutMs !== undefined
    ? timeoutMs
    : (process.env.DAG_TEAMMATE_TIMEOUT ? parseInt(process.env.DAG_TEAMMATE_TIMEOUT, 10) : 300000);

  const startTime = Date.now();

  // Create timeout promise
  const timeoutPromise = new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        success: false,
        error: 'Teammate timeout',
        taskId: taskId,
        duration: Date.now() - startTime,
        timedOut: true
      });
    }, effectiveTimeout);
  });

  // Create polling promise
  const pollingPromise = (async () => {
    let pollDelay = 100; // Start with 100ms
    const maxPollDelay = 2000; // Cap at 2 seconds

    while (Date.now() - startTime < effectiveTimeout) {
      if (adapter && typeof adapter.getTaskStatus === 'function') {
        try {
          const status = await adapter.getTaskStatus(taskId);
          if (status && status.completed) {
            return {
              success: status.success !== false,
              result: status.result,
              error: status.error,
              taskId,
              duration: Date.now() - startTime
            };
          }
        } catch {
          // Continue polling until timeout; adapter errors are treated as transient
        }
      }

      // Fallback polling delay when no adapter is available
      await new Promise(resolve => setTimeout(resolve, pollDelay));
      pollDelay = Math.min(pollDelay * 1.5, maxPollDelay);
    }

    // Polling ended without completion (timeout via while condition)
    return {
      success: false,
      error: 'Teammate timeout',
      taskId: taskId,
      duration: Date.now() - startTime,
      timedOut: true
    };
  })();

  // Race between timeout and polling
  const result = await Promise.race([timeoutPromise, pollingPromise]);

  // If timed out, send shutdown request
  if (result.timedOut) {
    if (adapter && typeof adapter.sendShutdownRequest === 'function') {
      try {
        await adapter.sendShutdownRequest(taskId);
      } catch {
        // Ignore adapter shutdown errors; fallback logger still runs
      }
    }
    await sendShutdownRequest(taskId);
  }

  return result;
}

// ============================================================
// Wave Dispatch Coordinator
// ============================================================

/**
 * Dispatch parallel and sequential tasks within a wave.
 *
 * Execution strategy:
 * 1. Dispatch all parallel tasks simultaneously (if Agent Teams enabled)
 * 2. Await parallel task completion
 * 3. Execute serial tasks sequentially
 * 4. Aggregate results
 *
 * @param {Object} wave - Wave object with { waveNumber, tasks, estimatedDuration }
 * @param {Array<Object>} parallelTasks - Tasks that can run in parallel
 * @param {Array<Object>} serialTasks - Tasks that must run sequentially
 * @param {Object} config - Configuration object
 * @param {Function} config.taskExecutor - Sequential task executor callback (task) => Promise<result>
 * @param {boolean} config.enableTeams - Whether Agent Teams are available
 * @param {number} config.teammateTimeout - Timeout for each teammate (ms)
 * @returns {Promise<Object>} { success: boolean, results: [], parallelCount: number, serialCount: number }
 *
 * @example
 *   const config = {
 *     taskExecutor: async (task) => { ... },
 *     enableTeams: true,
 *     teammateTimeout: 300000
 *   };
 *   const result = await dispatchWave(wave, parallelTasks, serialTasks, config);
 */
async function dispatchWave(wave, parallelTasks, serialTasks, config) {
  if (!wave || !wave.waveNumber) {
    throw new Error('Wave must have a waveNumber');
  }
  if (!Array.isArray(parallelTasks)) {
    parallelTasks = [];
  }
  if (!Array.isArray(serialTasks)) {
    serialTasks = [];
  }
  if (!config || typeof config.taskExecutor !== 'function') {
    throw new Error('Config must provide a taskExecutor function');
  }

  const enableTeams = config.enableTeams === true;
  const teammateTimeout = config.teammateTimeout || 300000; // 5 minutes default
  const taskCreateAdapter = config.taskCreateAdapter;
  const hasTaskCreateAdapter = taskCreateAdapter &&
    typeof taskCreateAdapter.createTask === 'function' &&
    typeof taskCreateAdapter.getTaskStatus === 'function';

  const results = [];
  let overallSuccess = true;

  // ============================================================
  // Phase 1: Parallel Execution (if Agent Teams enabled)
  // ============================================================

  if (enableTeams && parallelTasks.length > 0) {
    // Dispatch all parallel tasks simultaneously
    const parallelPromises = parallelTasks.map(async (task) => {
      try {
        if (hasTaskCreateAdapter) {
          const prompt = buildTeammatePrompt(task);
          const created = await taskCreateAdapter.createTask({
            prompt,
            description: `Wave ${wave.waveNumber} teammate for ${task.id}`,
            task
          });

          const teammateTaskId = typeof created === 'string'
            ? created
            : (created && (created.id || created.taskId || created.task_id));

          if (!teammateTaskId) {
            throw new Error('TaskCreate adapter returned no task id');
          }

          const completion = await awaitTeammateCompletion(teammateTaskId, teammateTimeout, taskCreateAdapter);
          return {
            success: completion.success,
            taskId: task.id,
            teammateTaskId,
            result: completion.result,
            error: completion.error,
            duration: completion.duration
          };
        }

        // Fallback: Execute via local taskExecutor
        const result = await config.taskExecutor(task);
        return { success: true, taskId: task.id, result };
      } catch (error) {
        return { success: false, taskId: task.id, error: error.message };
      }
    });

    // Await all parallel tasks
    const parallelResults = await Promise.allSettled(parallelPromises);

    for (const settled of parallelResults) {
      if (settled.status === 'fulfilled') {
        results.push(settled.value);
        if (!settled.value.success) {
          overallSuccess = false;
        }
      } else {
        results.push({
          success: false,
          error: settled.reason?.message || 'Unknown error',
          taskId: 'unknown'
        });
        overallSuccess = false;
      }
    }
  } else if (!enableTeams && parallelTasks.length > 0) {
    // Agent Teams not available: Execute parallel tasks sequentially
    for (const task of parallelTasks) {
      try {
        const result = await config.taskExecutor(task);
        results.push({ success: true, taskId: task.id, result });
      } catch (error) {
        results.push({ success: false, taskId: task.id, error: error.message });
        overallSuccess = false;
      }
    }
  }

  // ============================================================
  // Phase 2: Sequential Execution (conflicting tasks)
  // ============================================================

  for (const task of serialTasks) {
    try {
      const result = await config.taskExecutor(task);
      results.push({ success: true, taskId: task.id, result });
    } catch (error) {
      results.push({ success: false, taskId: task.id, error: error.message });
      overallSuccess = false;
    }
  }

  return {
    success: overallSuccess,
    results: results,
    parallelCount: parallelTasks.length,
    serialCount: serialTasks.length
  };
}

// ============================================================
// Exports
// ============================================================

module.exports = {
  buildTeammatePrompt,
  awaitTeammateCompletion,
  dispatchWave,
  sendShutdownRequest
};
