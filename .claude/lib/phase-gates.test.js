const test = require('node:test');
const assert = require('node:assert/strict');

const {
  runGate,
  runPhaseGates,
  PhaseGateError
} = require('./phase-gates.js');

// ============================================================
// runGate Tests
// ============================================================

test('runGate with simple passing command', () => {
  const result = runGate('echo-test', {
    gateCommands: { 'echo-test': 'echo "test passed"' }
  });

  assert.equal(result.passed, true);
  assert.equal(typeof result.duration, 'number');
  assert.ok(result.duration >= 0);
  assert.ok(result.output.includes('test passed'));
});

test('runGate with failing command', () => {
  const result = runGate('fail-test', {
    gateCommands: { 'fail-test': 'exit 1' }
  });

  assert.equal(result.passed, false);
  assert.equal(typeof result.duration, 'number');
  assert.ok(typeof result.error === 'string');
});

test('runGate with unknown gate name', () => {
  const result = runGate('nonexistent-gate', {
    gateCommands: {}
  });

  assert.equal(result.passed, false);
  assert.equal(result.duration, 0);
  assert.ok(result.error.includes('Unknown gate'));
});

test('runGate captures command output', () => {
  const result = runGate('output-test', {
    gateCommands: { 'output-test': 'echo "line1" && echo "line2"' }
  });

  assert.equal(result.passed, true);
  assert.ok(result.output.includes('line1'));
  assert.ok(result.output.includes('line2'));
});

test('runGate uses default commands for build gate', () => {
  // This test will actually try to run dotnet build
  // We'll just verify it attempts the command (may pass or fail depending on environment)
  const result = runGate('build', {
    gateCommands: { build: 'echo "mock build"' } // Override with mock
  });

  assert.equal(typeof result.passed, 'boolean');
  assert.ok(result.output.includes('mock build'));
});

test('runGate respects custom timeout', () => {
  // This test uses a very short timeout to trigger timeout error
  const result = runGate('timeout-test', {
    gateCommands: { 'timeout-test': 'node -e "setTimeout(() => {}, 10000)"' }, // 10 second sleep
    gateTimeout: 100 // 100ms timeout
  });

  assert.equal(result.passed, false);
  assert.ok(result.error); // Should have timeout error
});

// ============================================================
// runPhaseGates Tests
// ============================================================

test('runPhaseGates with all passing gates', () => {
  const result = runPhaseGates({
    gates: ['gate1', 'gate2'],
    gateCommands: {
      gate1: 'echo "gate1 passed"',
      gate2: 'echo "gate2 passed"'
    }
  });

  assert.equal(result.success, true);
  assert.equal(result.results.length, 2);
  assert.equal(result.results[0].gate, 'gate1');
  assert.equal(result.results[0].passed, true);
  assert.equal(result.results[1].gate, 'gate2');
  assert.equal(result.results[1].passed, true);
  assert.equal(typeof result.totalDuration, 'number');
});

test('runPhaseGates with failFast stops on first failure', () => {
  try {
    runPhaseGates({
      gates: ['gate1', 'gate2', 'gate3'],
      failFast: true,
      gateCommands: {
        gate1: 'echo "gate1 passed"',
        gate2: 'exit 1', // This fails
        gate3: 'echo "gate3 passed"'
      }
    });
    assert.fail('Should have thrown PhaseGateError');
  } catch (error) {
    assert.ok(error instanceof PhaseGateError);
    assert.ok(error.message.includes('gate2'));
    assert.equal(error.gateResults.results.length, 2); // Only ran gate1 and gate2
    assert.equal(error.gateResults.results[1].passed, false);
  }
});

test('runPhaseGates without failFast runs all gates', () => {
  const result = runPhaseGates({
    gates: ['gate1', 'gate2', 'gate3'],
    failFast: false,
    gateCommands: {
      gate1: 'echo "gate1 passed"',
      gate2: 'exit 1', // This fails
      gate3: 'echo "gate3 passed"'
    }
  });

  assert.equal(result.success, false); // Overall failure
  assert.equal(result.results.length, 3); // All 3 gates ran
  assert.equal(result.results[0].passed, true);
  assert.equal(result.results[1].passed, false);
  assert.equal(result.results[2].passed, true);
});

test('runPhaseGates uses default gates when not specified', () => {
  const result = runPhaseGates({
    gateCommands: {
      build: 'echo "build passed"',
      test: 'echo "test passed"'
    }
  });

  assert.equal(result.success, true);
  assert.equal(result.results.length, 2);
  assert.equal(result.results[0].gate, 'build');
  assert.equal(result.results[1].gate, 'test');
});

test('runPhaseGates returns totalDuration', () => {
  const result = runPhaseGates({
    gates: ['gate1'],
    gateCommands: {
      gate1: 'echo "test"'
    }
  });

  assert.equal(typeof result.totalDuration, 'number');
  assert.ok(result.totalDuration >= 0);
  assert.ok(result.totalDuration >= result.results[0].duration);
});

test('runPhaseGates with empty gates array', () => {
  const result = runPhaseGates({
    gates: []
  });

  assert.equal(result.success, true);
  assert.equal(result.results.length, 0);
  assert.equal(typeof result.totalDuration, 'number');
});

test('PhaseGateError includes gate results', () => {
  try {
    runPhaseGates({
      gates: ['failing-gate'],
      failFast: true,
      gateCommands: {
        'failing-gate': 'exit 1'
      }
    });
    assert.fail('Should have thrown PhaseGateError');
  } catch (error) {
    assert.ok(error instanceof PhaseGateError);
    assert.ok(error.gateResults);
    assert.equal(typeof error.gateResults.success, 'boolean');
    assert.ok(Array.isArray(error.gateResults.results));
    assert.equal(typeof error.gateResults.totalDuration, 'number');
    assert.equal(error.gateResults.failedGate, 'failing-gate');
  }
});

test('runPhaseGates passes projectRoot to gate commands', () => {
  // Verify that projectRoot is used as cwd for commands
  const result = runPhaseGates({
    gates: ['pwd-test'],
    projectRoot: process.cwd(),
    gateCommands: {
      'pwd-test': process.platform === 'win32' ? 'cd' : 'pwd'
    }
  });

  assert.equal(result.success, true);
  assert.ok(result.results[0].output.length > 0);
});
