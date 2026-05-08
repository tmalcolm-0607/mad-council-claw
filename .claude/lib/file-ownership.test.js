const test = require('node:test');
const assert = require('node:assert/strict');

const {
  extractFilesFromTask,
  buildFileMap,
  detectConflicts,
  resolveConflicts,
  analyzeFileOwnership,
  splitWaveByConflicts
} = require('./file-ownership.js');

// ============================================================
// extractFilesFromTask
// ============================================================

test('extractFilesFromTask returns ownedFiles from dag metadata', () => {
  const task = {
    id: 'T001',
    subject: 'Implement UserService',
    dag: {
      ownedFiles: ['src/services/user.ts', 'src/services/user.test.ts']
    }
  };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, ['src/services/user.ts', 'src/services/user.test.ts']);
});

test('extractFilesFromTask parses file paths from description as fallback', () => {
  const task = {
    id: 'T002',
    subject: 'Update authentication',
    description: 'Modify src/auth/login.ts and tests/auth.test.ts'
  };
  const files = extractFilesFromTask(task);
  assert.ok(files.includes('src/auth/login.ts'));
  assert.ok(files.includes('tests/auth.test.ts'));
});

test('extractFilesFromTask prefers dag.ownedFiles over description parsing', () => {
  const task = {
    id: 'T003',
    dag: { ownedFiles: ['src/explicit.ts'] },
    description: 'Also mentions src/from-description.ts'
  };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, ['src/explicit.ts']);
});

test('extractFilesFromTask returns empty array when no files specified', () => {
  const task = { id: 'T004', subject: 'No files here' };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, []);
});

test('extractFilesFromTask handles missing dag field', () => {
  const task = { id: 'T005' };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, []);
});

test('extractFilesFromTask handles dag without ownedFiles', () => {
  const task = { id: 'T006', dag: { priority: 5 } };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, []);
});

test('extractFilesFromTask handles null dag', () => {
  const task = { id: 'T007', dag: null };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, []);
});

test('extractFilesFromTask handles empty ownedFiles array', () => {
  const task = { id: 'T008', dag: { ownedFiles: [] } };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, []);
});

test('extractFilesFromTask normalizes relative paths', () => {
  const task = {
    id: 'T009',
    description: 'Update ./src/utils/helper.ts and ../lib/util.js'
  };
  const files = extractFilesFromTask(task);
  assert.ok(files.includes('src/utils/helper.ts'));
});

test('extractFilesFromTask extracts backtick-quoted paths from description', () => {
  const task = {
    id: 'T010',
    description: 'Modify `src/components/Button.tsx` and `tests/Button.test.tsx`'
  };
  const files = extractFilesFromTask(task);
  assert.ok(files.includes('src/components/Button.tsx'));
  assert.ok(files.includes('tests/Button.test.tsx'));
});

test('extractFilesFromTask extracts double-quoted paths from description', () => {
  const task = {
    id: 'T011',
    description: 'Update "src/config/settings.ts" for new options'
  };
  const files = extractFilesFromTask(task);
  assert.ok(files.includes('src/config/settings.ts'));
});

test('extractFilesFromTask deduplicates extracted paths', () => {
  const task = {
    id: 'T012',
    description: 'Modify src/user.ts, update `src/user.ts` again'
  };
  const files = extractFilesFromTask(task);
  const srcUserCount = files.filter(f => f === 'src/user.ts').length;
  assert.equal(srcUserCount, 1);
});

test('extractFilesFromTask handles wildcard paths in ownedFiles', () => {
  const task = {
    id: 'T013',
    dag: { ownedFiles: ['src/**/*.ts', 'tests/specific.test.ts'] }
  };
  const files = extractFilesFromTask(task);
  assert.ok(files.includes('src/**/*.ts'));
  assert.ok(files.includes('tests/specific.test.ts'));
});

test('extractFilesFromTask filters out non-source paths from description', () => {
  const task = {
    id: 'T014',
    description: 'This is version 1.2.3 and mentions http://example.com/path.html but also src/real.ts'
  };
  const files = extractFilesFromTask(task);
  assert.ok(files.includes('src/real.ts'));
  // Should not include arbitrary URLs or version numbers as paths
  assert.ok(!files.some(f => f.includes('http')));
});

test('extractFilesFromTask handles non-array ownedFiles gracefully', () => {
  const task = { id: 'T015', dag: { ownedFiles: 'src/single.ts' } };
  const files = extractFilesFromTask(task);
  assert.deepStrictEqual(files, []);
});

// ============================================================
// buildFileMap
// ============================================================

test('buildFileMap creates file to task ID mapping', () => {
  const tasks = [
    { id: 'T001', dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', dag: { ownedFiles: ['src/auth.ts', 'src/user.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);

  assert.deepStrictEqual(fileMap['src/user.ts'].sort(), ['T001', 'T002']);
  assert.deepStrictEqual(fileMap['src/auth.ts'], ['T002']);
});

test('buildFileMap handles tasks with no files', () => {
  const tasks = [
    { id: 'T001', subject: 'No files' },
    { id: 'T002', dag: { ownedFiles: ['src/file.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);

  assert.deepStrictEqual(fileMap['src/file.ts'], ['T002']);
  assert.equal(Object.keys(fileMap).length, 1);
});

test('buildFileMap handles empty task array', () => {
  const fileMap = buildFileMap([]);
  assert.deepStrictEqual(fileMap, {});
});

test('buildFileMap combines explicit and description-parsed files', () => {
  const tasks = [
    { id: 'T001', dag: { ownedFiles: ['src/explicit.ts'] } },
    { id: 'T002', description: 'Modify src/explicit.ts for updates' }
  ];
  const fileMap = buildFileMap(tasks);

  assert.deepStrictEqual(fileMap['src/explicit.ts'].sort(), ['T001', 'T002']);
});

// ============================================================
// detectConflicts
// ============================================================

test('detectConflicts finds same-wave file conflicts', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  assert.equal(conflicts.length, 1);
  assert.equal(conflicts[0].file, 'src/user.ts');
  assert.equal(conflicts[0].wave, 1);
  assert.deepStrictEqual(conflicts[0].tasks.sort(), ['T001', 'T002']);
  assert.equal(conflicts[0].severity, 'HIGH');
});

test('detectConflicts ignores cross-wave file sharing', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 2, dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  assert.equal(conflicts.length, 0);
});

test('detectConflicts returns empty array when no conflicts', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/auth.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  assert.equal(conflicts.length, 0);
});

test('detectConflicts handles three tasks conflicting on same file', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } },
    { id: 'T003', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  assert.equal(conflicts.length, 1);
  assert.deepStrictEqual(conflicts[0].tasks.sort(), ['T001', 'T002', 'T003']);
});

test('detectConflicts handles multiple files with conflicts in same wave', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/a.ts', 'src/b.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/a.ts', 'src/b.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  assert.equal(conflicts.length, 2);
  const conflictFiles = conflicts.map(c => c.file).sort();
  assert.deepStrictEqual(conflictFiles, ['src/a.ts', 'src/b.ts']);
});

test('detectConflicts handles tasks without wave field (defaults to undefined)', () => {
  const tasks = [
    { id: 'T001', dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  // Tasks without wave are treated as same wave (undefined === undefined)
  assert.equal(conflicts.length, 1);
});

test('detectConflicts handles wildcard overlap with specific file', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/**/*.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const fileMap = buildFileMap(tasks);
  const conflicts = detectConflicts(tasks, fileMap);

  // Wildcard patterns are flagged as potential conflicts with overlapping specific paths
  assert.ok(conflicts.length > 0);
});

test('detectConflicts handles empty task array', () => {
  const conflicts = detectConflicts([], {});
  assert.deepStrictEqual(conflicts, []);
});

// ============================================================
// resolveConflicts
// ============================================================

test('resolveConflicts provides serialize strategy', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const conflicts = [
    { file: 'src/user.ts', wave: 1, tasks: ['T001', 'T002'], severity: 'HIGH' }
  ];
  const resolutions = resolveConflicts(conflicts, tasks);

  assert.ok(resolutions.serialize);
  assert.ok(Array.isArray(resolutions.serialize.waveAdjustments));
  assert.equal(resolutions.serialize.waveAdjustments.length, 1);

  const adj = resolutions.serialize.waveAdjustments[0];
  assert.equal(adj.taskId, 'T002');
  assert.equal(adj.fromWave, 1);
  assert.equal(adj.toWave, 2);
  assert.ok(adj.reason.includes('src/user.ts'));
});

test('resolveConflicts provides moveToNext strategy', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const conflicts = [
    { file: 'src/user.ts', wave: 1, tasks: ['T001', 'T002'], severity: 'HIGH' }
  ];
  const resolutions = resolveConflicts(conflicts, tasks);

  assert.ok(resolutions.moveToNext);
  assert.ok(Array.isArray(resolutions.moveToNext.waveAdjustments));
  assert.equal(resolutions.moveToNext.waveAdjustments.length, 1);

  const adj = resolutions.moveToNext.waveAdjustments[0];
  assert.equal(adj.taskId, 'T002');
  assert.equal(adj.fromWave, 1);
  assert.equal(adj.toWave, 2);
});

test('resolveConflicts returns empty adjustments when no conflicts', () => {
  const resolutions = resolveConflicts([], []);

  assert.deepStrictEqual(resolutions.serialize.waveAdjustments, []);
  assert.deepStrictEqual(resolutions.moveToNext.waveAdjustments, []);
});

test('resolveConflicts handles three-task conflict by keeping first, moving others', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } },
    { id: 'T003', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } }
  ];
  const conflicts = [
    { file: 'src/shared.ts', wave: 1, tasks: ['T001', 'T002', 'T003'], severity: 'HIGH' }
  ];
  const resolutions = resolveConflicts(conflicts, tasks);

  // Serialize: keep T001, serialize T002 to wave 2, T003 to wave 3
  const serializeAdjs = resolutions.serialize.waveAdjustments;
  assert.equal(serializeAdjs.length, 2);
  assert.equal(serializeAdjs[0].taskId, 'T002');
  assert.equal(serializeAdjs[0].toWave, 2);
  assert.equal(serializeAdjs[1].taskId, 'T003');
  assert.equal(serializeAdjs[1].toWave, 3);

  // MoveToNext: move all conflicting tasks except first to wave+1
  const moveAdjs = resolutions.moveToNext.waveAdjustments;
  assert.equal(moveAdjs.length, 2);
});

test('resolveConflicts handles multiple conflicts in different waves', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/a.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/a.ts'] } },
    { id: 'T003', wave: 2, dag: { ownedFiles: ['src/b.ts'] } },
    { id: 'T004', wave: 2, dag: { ownedFiles: ['src/b.ts'] } }
  ];
  const conflicts = [
    { file: 'src/a.ts', wave: 1, tasks: ['T001', 'T002'], severity: 'HIGH' },
    { file: 'src/b.ts', wave: 2, tasks: ['T003', 'T004'], severity: 'HIGH' }
  ];
  const resolutions = resolveConflicts(conflicts, tasks);

  // Should have adjustments for both conflicts
  assert.ok(resolutions.serialize.waveAdjustments.length >= 2);
});

test('resolveConflicts deduplicates task adjustments across multiple file conflicts', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/a.ts', 'src/b.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/a.ts', 'src/b.ts'] } }
  ];
  const conflicts = [
    { file: 'src/a.ts', wave: 1, tasks: ['T001', 'T002'], severity: 'HIGH' },
    { file: 'src/b.ts', wave: 1, tasks: ['T001', 'T002'], severity: 'HIGH' }
  ];
  const resolutions = resolveConflicts(conflicts, tasks);

  // T002 should only be moved once even though it conflicts on two files
  const serializeTaskIds = resolutions.serialize.waveAdjustments.map(a => a.taskId);
  const uniqueIds = [...new Set(serializeTaskIds)];
  assert.deepStrictEqual(serializeTaskIds, uniqueIds);
});

// ============================================================
// analyzeFileOwnership (integration)
// ============================================================

test('analyzeFileOwnership returns complete result structure', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/auth.ts'] } }
  ];
  const result = analyzeFileOwnership(tasks);

  assert.ok(result.fileMap);
  assert.ok(Array.isArray(result.conflicts));
  assert.ok(result.resolutions);
  assert.ok(result.resolutions.serialize);
  assert.ok(result.resolutions.moveToNext);
});

test('analyzeFileOwnership detects and resolves conflicts end-to-end', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, description: 'Modify src/user.ts and tests/user.test.ts' }
  ];
  const result = analyzeFileOwnership(tasks);

  assert.deepStrictEqual(result.fileMap['src/user.ts'].sort(), ['T001', 'T002']);
  assert.equal(result.conflicts.length, 1);
  assert.equal(result.conflicts[0].file, 'src/user.ts');
  assert.ok(result.resolutions.serialize.waveAdjustments.length > 0);
});

test('analyzeFileOwnership handles no conflicts', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/auth.ts'] } },
    { id: 'T003', wave: 2, dag: { ownedFiles: ['src/user.ts'] } }
  ];
  const result = analyzeFileOwnership(tasks);

  assert.equal(result.conflicts.length, 0);
  assert.deepStrictEqual(result.resolutions.serialize.waveAdjustments, []);
  assert.deepStrictEqual(result.resolutions.moveToNext.waveAdjustments, []);
});

test('analyzeFileOwnership handles empty task array', () => {
  const result = analyzeFileOwnership([]);

  assert.deepStrictEqual(result.fileMap, {});
  assert.deepStrictEqual(result.conflicts, []);
  assert.deepStrictEqual(result.resolutions.serialize.waveAdjustments, []);
  assert.deepStrictEqual(result.resolutions.moveToNext.waveAdjustments, []);
});

test('analyzeFileOwnership handles tasks with no files', () => {
  const tasks = [
    { id: 'T001', wave: 1, subject: 'Planning task' },
    { id: 'T002', wave: 1, subject: 'Research task' }
  ];
  const result = analyzeFileOwnership(tasks);

  assert.deepStrictEqual(result.fileMap, {});
  assert.equal(result.conflicts.length, 0);
});

test('analyzeFileOwnership complex scenario with multiple waves and conflicts', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/shared.ts', 'src/user.ts'] } },
    { id: 'T002', wave: 1, dag: { ownedFiles: ['src/shared.ts'] } },
    { id: 'T003', wave: 1, dag: { ownedFiles: ['src/auth.ts'] } },
    { id: 'T004', wave: 2, dag: { ownedFiles: ['src/shared.ts', 'src/auth.ts'] } },
    { id: 'T005', wave: 2, dag: { ownedFiles: ['src/shared.ts'] } }
  ];
  const result = analyzeFileOwnership(tasks);

  // Wave 1 conflict: src/shared.ts (T001, T002)
  // Wave 2 conflict: src/shared.ts (T004, T005)
  assert.equal(result.conflicts.length, 2);

  const wave1Conflict = result.conflicts.find(c => c.wave === 1);
  assert.ok(wave1Conflict);
  assert.equal(wave1Conflict.file, 'src/shared.ts');
  assert.deepStrictEqual(wave1Conflict.tasks.sort(), ['T001', 'T002']);

  const wave2Conflict = result.conflicts.find(c => c.wave === 2);
  assert.ok(wave2Conflict);
  assert.equal(wave2Conflict.file, 'src/shared.ts');
  assert.deepStrictEqual(wave2Conflict.tasks.sort(), ['T004', 'T005']);
});

test('analyzeFileOwnership matches the documented output structure', () => {
  const tasks = [
    { id: 'T001', wave: 1, dag: { ownedFiles: ['src/user.ts'] } },
    { id: 'T002', wave: 1, description: 'Modify src/user.ts and tests/user.test.ts' }
  ];
  const result = analyzeFileOwnership(tasks);

  // Verify structure matches spec
  assert.equal(typeof result.fileMap, 'object');
  assert.ok(Array.isArray(result.conflicts));
  assert.equal(typeof result.resolutions, 'object');
  assert.equal(typeof result.resolutions.serialize, 'object');
  assert.ok(Array.isArray(result.resolutions.serialize.waveAdjustments));
  assert.equal(typeof result.resolutions.moveToNext, 'object');
  assert.ok(Array.isArray(result.resolutions.moveToNext.waveAdjustments));

  // Verify conflict shape
  if (result.conflicts.length > 0) {
    const conflict = result.conflicts[0];
    assert.equal(typeof conflict.file, 'string');
    assert.equal(typeof conflict.wave, 'number');
    assert.ok(Array.isArray(conflict.tasks));
    assert.equal(typeof conflict.severity, 'string');
  }

  // Verify adjustment shape
  if (result.resolutions.serialize.waveAdjustments.length > 0) {
    const adj = result.resolutions.serialize.waveAdjustments[0];
    assert.equal(typeof adj.taskId, 'string');
    assert.equal(typeof adj.fromWave, 'number');
    assert.equal(typeof adj.toWave, 'number');
    assert.equal(typeof adj.reason, 'string');
  }
});

// ============================================================
// splitWaveByConflicts Tests
// ============================================================

test('splitWaveByConflicts with no conflicts returns all tasks parallel', () => {
  const wave = {
    waveNumber: 1,
    tasks: ['T1', 'T2', 'T3'],
    estimatedDuration: 300
  };
  const conflicts = [];
  const tasks = [
    { id: 'T1', description: 'Task 1' },
    { id: 'T2', description: 'Task 2' },
    { id: 'T3', description: 'Task 3' }
  ];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  assert.equal(parallelTasks.length, 3);
  assert.equal(serialTasks.length, 0);
  assert.ok(parallelTasks.some(t => t.id === 'T1'));
  assert.ok(parallelTasks.some(t => t.id === 'T2'));
  assert.ok(parallelTasks.some(t => t.id === 'T3'));
});

test('splitWaveByConflicts with one conflict pair: first stays parallel, second serializes', () => {
  const wave = {
    waveNumber: 1,
    tasks: ['T1', 'T2', 'T3'],
    estimatedDuration: 300
  };
  const conflicts = [
    { file: 'src/foo.js', wave: 1, tasks: ['T1', 'T2'], severity: 'HIGH' }
  ];
  const tasks = [
    { id: 'T1', description: 'Modify foo.js' },
    { id: 'T2', description: 'Also modify foo.js' },
    { id: 'T3', description: 'Modify bar.js' }
  ];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  assert.equal(parallelTasks.length, 2);
  assert.equal(serialTasks.length, 1);
  assert.ok(parallelTasks.some(t => t.id === 'T1')); // First in conflict stays parallel
  assert.ok(parallelTasks.some(t => t.id === 'T3')); // No conflict stays parallel
  assert.equal(serialTasks[0].id, 'T2'); // Second in conflict serializes
});

test('splitWaveByConflicts with multiple conflicts on same file: only first parallel', () => {
  const wave = {
    waveNumber: 1,
    tasks: ['T1', 'T2', 'T3', 'T4'],
    estimatedDuration: 400
  };
  const conflicts = [
    { file: 'src/foo.js', wave: 1, tasks: ['T1', 'T2', 'T3'], severity: 'HIGH' }
  ];
  const tasks = [
    { id: 'T1', description: 'Modify foo.js' },
    { id: 'T2', description: 'Also modify foo.js' },
    { id: 'T3', description: 'Also also modify foo.js' },
    { id: 'T4', description: 'Modify bar.js' }
  ];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  assert.equal(parallelTasks.length, 2);
  assert.equal(serialTasks.length, 2);
  assert.ok(parallelTasks.some(t => t.id === 'T1')); // First in conflict
  assert.ok(parallelTasks.some(t => t.id === 'T4')); // No conflict
  assert.ok(serialTasks.some(t => t.id === 'T2')); // Second in conflict
  assert.ok(serialTasks.some(t => t.id === 'T3')); // Third in conflict
});

test('splitWaveByConflicts does not mutate task objects', () => {
  const wave = {
    waveNumber: 1,
    tasks: ['T1', 'T2'],
    estimatedDuration: 200
  };
  const conflicts = [
    { file: 'src/foo.js', wave: 1, tasks: ['T1', 'T2'], severity: 'HIGH' }
  ];
  const tasks = [
    { id: 'T1', description: 'Task 1', extra: 'data' },
    { id: 'T2', description: 'Task 2', extra: 'data' }
  ];

  // Store original references
  const originalT1 = tasks[0];
  const originalT2 = tasks[1];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  // Check that returned objects are same references (not clones)
  assert.strictEqual(parallelTasks[0], originalT1);
  assert.strictEqual(serialTasks[0], originalT2);

  // Check that objects weren't modified
  assert.equal(originalT1.extra, 'data');
  assert.equal(originalT2.extra, 'data');
});

test('splitWaveByConflicts filters out conflicts from other waves', () => {
  const wave = {
    waveNumber: 2,
    tasks: ['T3', 'T4'],
    estimatedDuration: 200
  };
  const conflicts = [
    { file: 'src/foo.js', wave: 1, tasks: ['T1', 'T2'], severity: 'HIGH' }, // Different wave
    { file: 'src/bar.js', wave: 2, tasks: ['T3', 'T4'], severity: 'HIGH' }  // Same wave
  ];
  const tasks = [
    { id: 'T1', description: 'Task 1' },
    { id: 'T2', description: 'Task 2' },
    { id: 'T3', description: 'Task 3' },
    { id: 'T4', description: 'Task 4' }
  ];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  // Only wave 2 conflict should apply
  assert.equal(parallelTasks.length, 1);
  assert.equal(serialTasks.length, 1);
  assert.equal(parallelTasks[0].id, 'T3');
  assert.equal(serialTasks[0].id, 'T4');
});

test('splitWaveByConflicts handles empty wave', () => {
  const wave = {
    waveNumber: 1,
    tasks: [],
    estimatedDuration: 0
  };
  const conflicts = [];
  const tasks = [];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  assert.equal(parallelTasks.length, 0);
  assert.equal(serialTasks.length, 0);
});

test('splitWaveByConflicts handles missing task objects gracefully', () => {
  const wave = {
    waveNumber: 1,
    tasks: ['T1', 'T2', 'T999'], // T999 doesn't exist in tasks array
    estimatedDuration: 200
  };
  const conflicts = [];
  const tasks = [
    { id: 'T1', description: 'Task 1' },
    { id: 'T2', description: 'Task 2' }
  ];

  const { parallelTasks, serialTasks } = splitWaveByConflicts(wave, conflicts, tasks);

  // Should only return tasks that exist in tasks array
  assert.equal(parallelTasks.length, 2);
  assert.equal(serialTasks.length, 0);
});
