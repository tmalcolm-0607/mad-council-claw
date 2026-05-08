# mad-full: Internal Mechanics

> Reference material for understanding mad-full's internal implementation. The "Execution Flow (MANDATORY)" section in SKILL.md takes precedence.

## Parse Input and Initialize

```javascript
const description = parseDescription(input);

const mode = {
  autonomous: args.includes('--autonomous'),
  headless: args.includes('--headless'),
  maxIterations: parseInt(args['--max-iterations']) || 30
};

const progress = {
  phase: 0,
  totalPhases: 6,
  artifacts: [],
  gates: []
};
```

## Phase Execution with Gates

For each phase, the skill:

1. **Invokes the skill** using the Skill tool
2. **Verifies gate conditions** before proceeding
3. **Records checkpoint** for resume capability
4. **On failure**:
   - Interactive: Ask user how to proceed
   - Autonomous: Retry up to max-iterations
   - Headless: Fail with error JSON

## Implementation Phase (Special Handling)

```javascript
async function executeImplementation(tasksFile, mode) {
  const tasks = parseTasksFile(tasksFile);
  const phases = groupByPhase(tasks);

  for (const phase of phases) {
    let attempts = 0;
    let passed = false;

    while (!passed && attempts < mode.maxIterations) {
      await invokeSkill('mad-implement', `--phase ${phase.number}`);
      const gateResult = await runGates(['build', 'test', 'coverage']);

      if (gateResult.passed) {
        passed = true;
        saveCheckpoint(phase, gateResult);
      } else {
        attempts++;
      }
    }

    if (!passed) return { success: false, blockedAt: phase, attempts };
  }
  return { success: true };
}
```

## Checkpoint System

Checkpoints enable resume after interruption:

```json
{
  "feature": "user-authentication",
  "branch": "2-user-authentication",
  "started": "2026-01-19T06:00:00Z",
  "currentPhase": 4,
  "completedPhases": [
    { "phase": 1, "artifact": "spec.md", "gate": "PASS" },
    { "phase": 2, "artifact": "plan.md", "gate": "PASS" },
    { "phase": 3, "artifact": "tasks.md", "gate": "PASS" }
  ],
  "implementationProgress": {
    "totalPhases": 6,
    "completedPhases": 3,
    "currentPhase": 4,
    "attempts": 2
  }
}
```

Resume with: `/mad-full --resume`