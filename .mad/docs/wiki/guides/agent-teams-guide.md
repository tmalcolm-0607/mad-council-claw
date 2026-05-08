# Agent Teams Integration Guide

Comprehensive guide for enabling and using Claude Code Agent Teams with the MAD workflow.

## Prerequisites

- Claude Code with experimental Agent Teams support
- Environment variable: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Configuration file: `.claude/agent-teams-config.json`

## Enabling Agent Teams

### 1. Set Environment Variable

Already configured in `.claude/settings.local.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Configure Per-Phase

Edit `.claude/agent-teams-config.json`:

```json
{
  "enabled": true,
  "mode": "hybrid",
  "teammateMode": "in-process",
  "maxTeammates": 5,
  "requirePlanApproval": true,
  "phases": {
    "spec-research": "teams",
    "spec-review": "teams",
    "plan-research": "teams",
    "plan-review": "teams",
    "implement-parallel": "teams",
    "validate": "teams",
    "pr-review": "teams"
  }
}
```

To disable teams for a specific phase, set its value to `"subagents"`.

### 3. Disable Entirely

Set `"enabled": false` in config, or remove the env var from settings.

## Phase-by-Phase Reference

### Parallel Validation (`/mad-validate`)

**Phase key**: `validate`
**Team template**: Parallel Validation
**Teammates**: Up to 6 validators (contract, spec-lint, test-trace, living-doc, verification-spec, pattern-audit)
**Risk**: Low (all read-only)
**Expected speedup**: 3-5x wall-clock time

All 6 validation checks run simultaneously instead of sequentially. Lead compiles unified report.

### Research Swarm (`/mad-spec --deep-research`, `/mad-plan`)

**Phase keys**: `spec-research`, `plan-research`
**Team template**: Research Swarm
**Teammates**: 1 parallel-researcher per topic/question
**Risk**: Low (read-only research)
**Expected speedup**: 2-4x for 3+ topics

Each parallel-researcher runs the full scout/curator/reviewer pipeline internally. Lead synthesizes findings across all topics.

**Skip when**: Only 1 research topic (overhead not justified).

### Review Board (`/mad-spec`, `/mad-plan`)

**Phase keys**: `spec-review`, `plan-review`
**Team template**: Review Board
**Teammates**: 3 domain-reviewers (security, performance, architecture)
**Risk**: Low (read-only review)
**Expected quality gain**: 30%+ more unique findings

Each reviewer applies their domain lens independently, then challenges other reviewers' findings. Lead deduplicates and synthesizes.

### Parallel Implementation (`/mad-implement`)

**Phase key**: `implement-parallel`
**Team template**: Parallel Implementation
**Teammates**: 1 code-implementer per file-ownership group
**Risk**: Medium (writes code)
**Expected speedup**: 2-3x for 3+ [P] tasks

File ownership protocol ensures no two teammates modify the same file. Plan approval required before any code changes. Lead runs quality gates across all changes.

**Skip when**: No [P]-marked tasks, or file ownership conflicts detected.

### PR Review Board (`/mad-full` Phase 7)

**Phase key**: `pr-review`
**Team template**: PR Review Board
**Teammates**: 3 reviewers (security, code-quality, test-coverage)
**Risk**: Low (read-only review)
**Expected quality gain**: 30%+ more findings with severity classification

Multi-lens review of PR diff. Reviewers challenge each other's severity ratings. Lead synthesizes unified review with APPROVE/REQUEST_CHANGES/COMMENT recommendation.

## Cost Analysis

| Template | Teammates | Cost Multiplier | Justified By |
|----------|-----------|-----------------|--------------|
| Research Swarm (3 topics) | 3 | ~4x | Wall-clock speedup |
| Review Board | 3 | ~4x | Quality improvement |
| Parallel Validation | 5-6 | ~6x | Wall-clock speedup |
| Parallel Implementation | 2-3 | ~3-4x | Wall-clock speedup |
| PR Review Board | 3 | ~4x | Quality improvement |

**Rule of thumb**: Teams are cost-effective when they deliver >= 2x speedup OR >= 30% more unique findings.

## Kill Conditions

Stop using teams for a phase if:

| Condition | Action |
|-----------|--------|
| Speed < 1.5x sequential | Revert phase to subagents |
| Cost > 5x without quality gain | Revert phase to subagents |
| File ownership conflicts frequent | Revert implement-parallel |
| Teammate hangs > 2 minutes | requestShutdown, use partial results |
| Duplicate-only findings (no unique) | Revert review board |

## Troubleshooting

### Teams Not Activating

1. Check settings file: `.claude/settings.local.json` must have `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"` in the `env` block
2. Check config: `.claude/agent-teams-config.json` → `"enabled": true`
3. Check phase: Specific phase must be set to `"teams"` (not `"subagents"`)
4. All 3 conditions must be true simultaneously

**Note**: The env var in `settings.local.json` is read by Claude Code's process directly. It does NOT appear in bash subshells (`echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` will return empty — this is normal). The dispatch logic reads the settings file, not the shell environment.

### How to Enable

Add to `.claude/settings.local.json`:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

If the file already has an `env` block, merge the key into it. If the key is missing, skills will WARN with setup instructions and fall back to sequential execution.

### Fallback to Sequential

If you see `WARN: Agent Teams unavailable for <phase>` in output:
- The setting may be missing from `.claude/settings.local.json`
- The Agent Teams API may not be available in your Claude Code version
- This is expected — the skill falls back to sequential execution with identical results

### Teammate Failures

- Individual teammate failure does not fail the whole team
- Lead notes incomplete checks in report
- Partial results are used where available

## Architecture

```
.claude/
├── agent-teams-config.json     # Per-phase enable/disable
├── rules/agent-teams.md        # Decision guidance (universal rule)
├── agents/
│   ├── parallel-researcher.md  # Combined 3-tier researcher
│   └── domain-reviewer.md      # Multi-domain review agent
└── skills/
    └── mad-teams/SKILL.md      # Team composition templates (5 templates)
```

## Task System API Examples

### Overview

Claude Code 2.1.16+ provides native Task System APIs for coordinating Agent Teams. These replace custom coordination files with atomic operations.

**Shared Task List**: `~/.claude/tasks/{team-name}/`

### Example 1: TaskCreate with Dependencies

```javascript
// Create 3 research tasks
const task1 = TaskCreate({
  subject: "Research OAuth2 patterns",
  description: "Investigate OAuth2 authorization code flow for Node.js. Include security best practices.",
  activeForm: "Researching OAuth2 patterns"
});

const task2 = TaskCreate({
  subject: "Research session management",
  description: "Investigate session storage options (Redis, database, in-memory). Include trade-offs.",
  activeForm: "Researching session management"
});

const task3 = TaskCreate({
  subject: "Synthesize authentication architecture",
  description: "Combine findings from OAuth2 and session research into unified architecture recommendation.",
  activeForm: "Synthesizing authentication architecture"
});

// Task 3 depends on tasks 1 and 2
TaskUpdate({
  taskId: task3,
  addBlockedBy: [task1, task2]
});
```

### Example 2: Teammate Claiming Tasks

```javascript
// Lead spawns 2 researchers
Task({
  team_name: "research-auth",
  name: "researcher-1",
  subagent_type: "parallel-researcher",
  prompt: `Claim the first pending task from TaskList().
           Execute research using scout→curator→reviewer pipeline.
           Mark task completed when done.`
});

Task({
  team_name: "research-auth",
  name: "researcher-2",
  subagent_type: "parallel-researcher",
  prompt: `Claim the second pending task from TaskList().
           Execute research using scout→curator→reviewer pipeline.
           Mark task completed when done.`
});

// Teammate workflow:
// 1. const tasks = TaskList()
// 2. const myTask = tasks.find(t => t.status === "pending" && !t.owner)
// 3. TaskUpdate({ taskId: myTask.id, status: "in_progress", owner: "researcher-1" })
// 4. // Do research work
// 5. TaskUpdate({ taskId: myTask.id, status: "completed" })
```

### Example 3: Lead Monitoring Completion

```javascript
// Lead waits for all tasks to complete
function waitForCompletion() {
  while (true) {
    const tasks = TaskList();
    const pending = tasks.filter(t => t.status !== "completed");

    if (pending.length === 0) {
      console.log("All tasks complete!");
      break;
    }

    console.log(`Waiting for ${pending.length} tasks: ${pending.map(t => t.subject).join(", ")}`);
    sleep(5000); // Poll every 5 seconds
  }
}

waitForCompletion();

// Synthesize results from completed tasks
const results = TaskList().map(t => t.output);
synthesizeReport(results);
```

### Example 4: Parallel Validation

```javascript
// mad-validate uses Task System APIs for 4 parallel lenses
const lenses = ["contract", "spec-lint", "coverage", "living-docs"];

for (const lens of lenses) {
  const taskId = TaskCreate({
    subject: `Validate ${lens}`,
    description: `Run ${lens} validation on feature. Output: pass/fail with details to validation-results.json.`,
    activeForm: `Validating ${lens}`
  });

  // Spawn validator teammate
  Task({
    team_name: "validators",
    name: `validator-${lens}`,
    subagent_type: "general-purpose",
    prompt: `You are validating ${lens}. Follow validation protocol in .claude/skills/mad-validate/SKILL.md. Claim task ${taskId}, run validation, write results, mark complete.`,
    run_in_background: true
  });
}

// Wait for all validations to complete
const allTasks = TaskList();
const failed = allTasks.filter(t => t.status === "completed" && t.result === "fail");

if (failed.length > 0) {
  console.error(`Validation failed: ${failed.map(t => t.subject).join(", ")}`);
  process.exit(2); // Trigger TaskCompleted hook with exit code 2
}
```

### Fallback for Claude Code < 2.1.16

```javascript
// Version detection
const hasTaskAPIs = typeof TaskCreate !== 'undefined';

if (hasTaskAPIs) {
  // Use Task System APIs (Claude Code 2.1.16+)
  const taskId = TaskCreate({ subject, description, activeForm });
  TaskUpdate({ taskId, status: "in_progress" });
} else {
  // Fall back to custom coordination (older versions)
  console.warn("Task System APIs unavailable, using custom coordination");

  // Write coordination state to file
  const coordFile = ".mad/scratch/coordination.json";
  const state = JSON.parse(fs.readFileSync(coordFile));
  state.tasks.push({ id: uuid(), subject, status: "pending" });
  fs.writeFileSync(coordFile, JSON.stringify(state));
}
```

**Graceful Degradation**: If Task System APIs are unavailable, skills automatically fall back to custom coordination with no functionality loss.

## See Also

- `.claude/rules/agent-teams.md` — Full decision guide and dispatch protocol
- `.claude/skills/mad-teams/SKILL.md` — Team composition templates
- `specs/agent-teams-integration/quickstart.md` — Hands-on testing guide
- `specs/agent-teams-integration/spec.md` — Feature specification
