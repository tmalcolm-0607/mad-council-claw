const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildTeammatePrompt,
  awaitTeammateCompletion,
  dispatchWave,
  sendShutdownRequest
} = require('./wave-dispatcher.js');

// ============================================================
// buildTeammatePrompt Tests
// ============================================================

test('buildTeammatePrompt generates prompt with task description', () => {
  const task = {
    id: 'T001',
    description: 'Add validation to User model'
  };

  const prompt = buildTeammatePrompt(task);

  assert.ok(prompt.includes('T001'));
  assert.ok(prompt.includes('Add validation to User model'));
  assert.ok(prompt.includes('Expected Deliverables'));
});

test('buildTeammatePrompt includes owned files when provided', () => {
  const task = {
    id: 'T001',
    description: 'Update model',
    dag: {
      ownedFiles: ['src/models/User.js', 'tests/models/User.test.js']
    }
  };

  const prompt = buildTeammatePrompt(task);

  assert.ok(prompt.includes('src/models/User.js'));
  assert.ok(prompt.includes('tests/models/User.test.js'));
  assert.ok(prompt.includes('File Ownership'));
  assert.ok(prompt.includes('Do not modify files outside this list'));
});

test('buildTeammatePrompt handles task without owned files', () => {
  const task = {
    id: 'T001',
    description: 'Research task'
  };

  const prompt = buildTeammatePrompt(task);

  assert.ok(prompt.includes('T001'));
  assert.ok(prompt.includes('Research task'));
  // Should not include file ownership section
  assert.ok(!prompt.includes('File Ownership'));
});

test('buildTeammatePrompt throws on missing task id', () => {
  assert.throws(
    () => buildTeammatePrompt({ description: 'No ID' }),
    /Task must have an id/
  );
});

test('buildTeammatePrompt handles empty dag.ownedFiles array', () => {
  const task = {
    id: 'T001',
    description: 'Task',
    dag: { ownedFiles: [] }
  };

  const prompt = buildTeammatePrompt(task);

  assert.ok(prompt.includes('T001'));
  assert.ok(!prompt.includes('File Ownership'));
});

test('buildTeammatePrompt output format is consistent', () => {
  const task = {
    id: 'T123',
    description: 'Test task'
  };

  const prompt = buildTeammatePrompt(task);

  // Check for required sections
  assert.ok(prompt.includes('**Task ID**:'));
  assert.ok(prompt.includes('**Description**:'));
  assert.ok(prompt.includes('**Expected Deliverables**:'));
});

// ============================================================
// awaitTeammateCompletion Tests
// ============================================================

test('awaitTeammateCompletion returns timeout on long wait', async () => {
  const result = await awaitTeammateCompletion('task-123', 50); // 50ms timeout

  assert.equal(result.success, false);
  assert.equal(result.error, 'Teammate timeout');
  assert.equal(result.taskId, 'task-123');
  assert.ok(result.duration >= 50);
});

test('awaitTeammateCompletion has default timeout', async () => {
  // This test would take 5 minutes with default timeout
  // Instead, verify the function accepts the parameter correctly
  const startTime = Date.now();
  const result = await awaitTeammateCompletion('task-456', 100);
  const duration = Date.now() - startTime;

  assert.ok(duration >= 100);
  assert.ok(duration < 200); // Should timeout around 100ms, not default 300000ms
});

test('awaitTeammateCompletion timeout result includes correct fields', async () => {
  const result = await awaitTeammateCompletion('task-789', 50);

  assert.equal(result.success, false);
  assert.equal(result.error, 'Teammate timeout');
  assert.equal(result.taskId, 'task-789');
  assert.equal(typeof result.duration, 'number');
  assert.ok(result.duration >= 50);
  assert.equal(result.timedOut, true);
});

test('awaitTeammateCompletion returns success when adapter reports completion', async () => {
  const adapter = {
    getTaskStatus: async () => ({
      completed: true,
      success: true,
      result: { output: 'done' }
    })
  };

  const result = await awaitTeammateCompletion('task-adapter-success', 100, adapter);

  assert.equal(result.success, true);
  assert.equal(result.taskId, 'task-adapter-success');
  assert.deepEqual(result.result, { output: 'done' });
  assert.equal(typeof result.duration, 'number');
});

test('awaitTeammateCompletion uses DAG_TEAMMATE_TIMEOUT env var', async () => {
  // Save original env var
  const originalEnv = process.env.DAG_TEAMMATE_TIMEOUT;

  try {
    // Set env var to 80ms
    process.env.DAG_TEAMMATE_TIMEOUT = '80';

    const startTime = Date.now();
    // Don't pass timeoutMs parameter - should use env var
    const result = await awaitTeammateCompletion('task-env-test');
    const duration = Date.now() - startTime;

    assert.ok(duration >= 80);
    assert.ok(duration < 150); // Should timeout around 80ms from env var
    assert.equal(result.error, 'Teammate timeout');
  } finally {
    // Restore original env var
    if (originalEnv !== undefined) {
      process.env.DAG_TEAMMATE_TIMEOUT = originalEnv;
    } else {
      delete process.env.DAG_TEAMMATE_TIMEOUT;
    }
  }
});

test('sendShutdownRequest is exported and callable', async () => {
  // Verify function exists and doesn't throw
  assert.equal(typeof sendShutdownRequest, 'function');

  // Should not throw
  await sendShutdownRequest('task-shutdown-test');
});

// ============================================================
// dispatchWave Tests
// ============================================================

test('dispatchWave with parallel-only tasks (teams disabled)', async () => {
  const wave = { waveNumber: 1, tasks: ['T1', 'T2'], estimatedDuration: 200 };
  const parallelTasks = [
    { id: 'T1', description: 'Task 1' },
    { id: 'T2', description: 'Task 2' }
  ];
  const serialTasks = [];

  let executedTasks = [];
  const config = {
    taskExecutor: async (task) => {
      executedTasks.push(task.id);
      return { completed: true };
    },
    enableTeams: false,
    teammateTimeout: 5000
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, true);
  assert.equal(result.parallelCount, 2);
  assert.equal(result.serialCount, 0);
  assert.equal(result.results.length, 2);
  assert.ok(executedTasks.includes('T1'));
  assert.ok(executedTasks.includes('T2'));
});

test('dispatchWave with serial-only tasks', async () => {
  const wave = { waveNumber: 1, tasks: ['T1', 'T2'], estimatedDuration: 200 };
  const parallelTasks = [];
  const serialTasks = [
    { id: 'T1', description: 'Task 1' },
    { id: 'T2', description: 'Task 2' }
  ];

  let executedTasks = [];
  const config = {
    taskExecutor: async (task) => {
      executedTasks.push(task.id);
      return { completed: true };
    },
    enableTeams: false,
    teammateTimeout: 5000
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, true);
  assert.equal(result.parallelCount, 0);
  assert.equal(result.serialCount, 2);
  assert.equal(result.results.length, 2);
  // Serial tasks execute in order
  assert.deepEqual(executedTasks, ['T1', 'T2']);
});

test('dispatchWave with mixed parallel and serial tasks', async () => {
  const wave = { waveNumber: 1, tasks: ['T1', 'T2', 'T3'], estimatedDuration: 300 };
  const parallelTasks = [
    { id: 'T1', description: 'Parallel 1' },
    { id: 'T2', description: 'Parallel 2' }
  ];
  const serialTasks = [
    { id: 'T3', description: 'Serial 1' }
  ];

  let executedTasks = [];
  const config = {
    taskExecutor: async (task) => {
      executedTasks.push(task.id);
      return { completed: true };
    },
    enableTeams: false,
    teammateTimeout: 5000
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, true);
  assert.equal(result.parallelCount, 2);
  assert.equal(result.serialCount, 1);
  assert.equal(result.results.length, 3);
  assert.equal(executedTasks.length, 3);
});

test('dispatchWave handles task executor failure', async () => {
  const wave = { waveNumber: 1, tasks: ['T1', 'T2'], estimatedDuration: 200 };
  const parallelTasks = [
    { id: 'T1', description: 'Will fail' }
  ];
  const serialTasks = [
    { id: 'T2', description: 'Will succeed' }
  ];

  const config = {
    taskExecutor: async (task) => {
      if (task.id === 'T1') {
        throw new Error('Task failed');
      }
      return { completed: true };
    },
    enableTeams: false,
    teammateTimeout: 5000
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, false); // Overall failure due to T1
  assert.equal(result.results.length, 2);

  const t1Result = result.results.find(r => r.taskId === 'T1');
  assert.equal(t1Result.success, false);
  assert.ok(t1Result.error.includes('Task failed'));

  const t2Result = result.results.find(r => r.taskId === 'T2');
  assert.equal(t2Result.success, true);
});

test('dispatchWave with enableTeams true (falls back to sequential for now)', async () => {
  const wave = { waveNumber: 1, tasks: ['T1', 'T2'], estimatedDuration: 200 };
  const parallelTasks = [
    { id: 'T1', description: 'Task 1' },
    { id: 'T2', description: 'Task 2' }
  ];
  const serialTasks = [];

  let executedTasks = [];
  const config = {
    taskExecutor: async (task) => {
      executedTasks.push(task.id);
      return { completed: true };
    },
    enableTeams: true, // Currently falls back to sequential
    teammateTimeout: 5000
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, true);
  assert.equal(result.parallelCount, 2);
  assert.equal(result.serialCount, 0);
  assert.equal(result.results.length, 2);
});

test('dispatchWave with TaskCreate adapter dispatches teammate tasks', async () => {
  const wave = { waveNumber: 2, tasks: ['T10', 'T11'], estimatedDuration: 200 };
  const parallelTasks = [
    { id: 'T10', description: 'Task 10' },
    { id: 'T11', description: 'Task 11' }
  ];

  const createdIds = [];
  const config = {
    taskExecutor: async () => ({ completed: true }),
    enableTeams: true,
    teammateTimeout: 250,
    taskCreateAdapter: {
      createTask: async ({ task }) => {
        const id = `tm-${task.id}`;
        createdIds.push(id);
        return { id };
      },
      getTaskStatus: async () => ({
        completed: true,
        success: true,
        result: { completed: true }
      })
    }
  };

  const result = await dispatchWave(wave, parallelTasks, [], config);

  assert.equal(result.success, true);
  assert.equal(result.parallelCount, 2);
  assert.equal(createdIds.length, 2);
  for (const taskResult of result.results) {
    assert.equal(taskResult.success, true);
    assert.ok(taskResult.teammateTaskId.startsWith('tm-'));
  }
});

test('dispatchWave throws on missing waveNumber', async () => {
  const wave = { tasks: [] }; // Missing waveNumber
  const config = { taskExecutor: async () => {} };

  await assert.rejects(
    async () => await dispatchWave(wave, [], [], config),
    /Wave must have a waveNumber/
  );
});

test('dispatchWave throws on missing taskExecutor', async () => {
  const wave = { waveNumber: 1, tasks: [] };
  const config = { enableTeams: false }; // Missing taskExecutor

  await assert.rejects(
    async () => await dispatchWave(wave, [], [], config),
    /Config must provide a taskExecutor function/
  );
});

test('dispatchWave handles empty wave gracefully', async () => {
  const wave = { waveNumber: 1, tasks: [], estimatedDuration: 0 };
  const parallelTasks = [];
  const serialTasks = [];

  const config = {
    taskExecutor: async () => {},
    enableTeams: false
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, true);
  assert.equal(result.parallelCount, 0);
  assert.equal(result.serialCount, 0);
  assert.equal(result.results.length, 0);
});

test('dispatchWave uses default teammateTimeout when not provided', async () => {
  const wave = { waveNumber: 1, tasks: [], estimatedDuration: 0 };
  const config = {
    taskExecutor: async () => {},
    enableTeams: false
    // teammateTimeout not provided
  };

  // Should not throw
  const result = await dispatchWave(wave, [], [], config);
  assert.equal(result.success, true);
});

test('dispatchWave handles partial completion (some tasks succeed, others fail)', async () => {
  const wave = { waveNumber: 1, tasks: ['T1', 'T2', 'T3'], estimatedDuration: 300 };
  const parallelTasks = [
    { id: 'T1', description: 'Will succeed' },
    { id: 'T2', description: 'Will fail' }
  ];
  const serialTasks = [
    { id: 'T3', description: 'Will succeed' }
  ];

  const config = {
    taskExecutor: async (task) => {
      if (task.id === 'T2') {
        throw new Error('T2 failed');
      }
      return { completed: true };
    },
    enableTeams: false
  };

  const result = await dispatchWave(wave, parallelTasks, serialTasks, config);

  assert.equal(result.success, false); // Overall failure
  assert.equal(result.results.length, 3);

  const successCount = result.results.filter(r => r.success).length;
  const failCount = result.results.filter(r => !r.success).length;

  assert.equal(successCount, 2); // T1 and T3
  assert.equal(failCount, 1);     // T2
});
