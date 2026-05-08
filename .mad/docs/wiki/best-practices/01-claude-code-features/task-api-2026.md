---
category: claude-code-features
subcategory: task-api
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Task API (2026)

## Overview

Task tool usage patterns for spawning agents, selecting subagent types, managing agent lifecycle, and choosing between direct and composite agents. The Task API enables orchestrators to delegate work to specialized agents while maintaining coordination through shared task lists.

**Key capability**: Shared task list coordination (agent teams) with task states, dependencies, file locking, and self-claim workflows.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Subagent Type Selection** | Match agent capabilities to task requirements |
| **Model Selection** | Opus for reasoning, Sonnet for patterns, Haiku for cleanup |
| **Composite Efficiency** | Use composites for multi-step tasks to save context |
| **Verification Protocol** | Always verify agent claims yourself |
| **Parallel Execution** | Use teams for 3+ independent tasks |
| **File Ownership** | Disjoint file sets prevent race conditions |

## Patterns (Current)

### Subagent Type Selection

**Direct agents** (single capability):
- `code-investigator` - Analyze code, document patterns
- `code-implementer` - Write code following TDD
- `code-reviewer` - Review code against quality criteria
- `feature-verifier` - Structural verification of test results
- `research-scout` - Breadth-first research
- `test-selector` - Intelligent test tier selection

**Composite agents** (multi-step workflows):
- `investigate-and-implement` - Investigate → Implement → Verify loop
- `review-and-fix` - Review → Auto-fix cycle
- `coverage-loop` - Iterative coverage gap closure

**When to use which**:

| Scenario | Agent Type | Rationale |
|----------|------------|-----------|
| Single file analysis | Direct `code-investigator` | Simple, focused task |
| 1-2 file implementation | Direct `code-implementer` | Minimal context needed |
| 3+ file implementation | Composite `investigate-and-implement` | Each subagent gets fresh context |
| Code review only | Direct `code-reviewer` | Single capability needed |
| Review + auto-fix | Composite `review-and-fix` | Multi-step with subagent coordination |

### Direct vs Composite Agents

**Direct agent pattern**:
```javascript
Task({
  subagent_type: "code-investigator",
  prompt: "Analyze authentication patterns in src/auth/",
  model: "opus"
})
```

**Result**: Agent returns findings to orchestrator. Orchestrator context grows with results.

**Composite agent pattern**:
```javascript
Task({
  subagent_type: "general-purpose",
  prompt: `
    Read protocol: .claude/agents/investigate-and-implement.md

    Task: Implement user login feature
    Files: src/auth/login.ts, tests/auth/login.test.ts
  `,
  model: "opus"
})
```

**Result**: Composite orchestrates internal subagents (investigate → implement → verify), returns only compact summary. Saves ~90% of main orchestrator context.

### Task Parameters

**Core parameters**:
```javascript
Task({
  subagent_type: "code-implementer",  // Required
  prompt: "Clear task description",    // Required
  model: "opus",                       // Optional (defaults from agent definition)
  max_turns: 25                        // Optional (conversation length cap)
})
// NOTE: run_in_background: true is PROHIBITED by project policy (CLAUDE.md).
// Confirmed bugs: hangs (#20679), empty outputs (#21352), session freezes (#17540).
// For parallel execution, use synchronous parallel Task calls in a single message.
```

**Agent Teams parameters** (when teams enabled):
```javascript
Task({
  team_name: "implement-parallel",     // Required for teams
  name: "implementer-auth",            // Required (teammate identifier)
  subagent_type: "code-implementer",   // Required
  prompt: "Implement auth module",     // Required
  model: "opus",                       // Optional
  plan_mode_required: true             // Optional (plan approval workflow)
})
```

**Task states** (shared task list):
- `pending` - Not yet started
- `in_progress` - Currently being worked on
- `completed` - Finished

**Task dependencies**:
- `blockedBy: ["T010", "T020"]` - Cannot claim until dependencies resolved
- Self-claim workflow: Teammates pick next unblocked, unassigned task

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Composite agents | Not available | Production-ready (`investigate-and-implement`, `review-and-fix`, `coverage-loop`) | Use composites for 3+ file tasks |
| Agent Teams | Not available | Experimental (enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | Use teams for 3+ independent tasks |
| File ownership | No coordination | Explicit disjoint file sets prevent conflicts | Assign `Owned Files` per task |
| Task dependencies | Not tracked | `blockedBy` array enables DAG execution | Add dependencies in tasks.md |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Using direct agent for 5+ file task | Context bloat in orchestrator | Use composite agent with fresh context per subagent |
| Spawning 10+ concurrent agents | Completion notifications bloat orchestrator context | Cap at 8 agents, prefer synchronous parallel or teams |
| Using `run_in_background: true` on Task spawns | Confirmed bugs: hangs, empty outputs, session freezes | Use synchronous parallel Task calls (single message, multiple tool blocks) |
| No file ownership (teams) | Race conditions, merge conflicts | Assign disjoint file sets to teammates |
| Trusting agent claims without verification | False confidence, bugs slip through | Always verify agent claims yourself (Read/Grep/Build) |
| Teams for sequential tasks | Overhead without parallelism | Use teams only for 3+ independent tasks |

## Examples

### Example 1: Direct Agent Call

**Scenario**: Single file analysis

```javascript
Task({
  subagent_type: "code-investigator",
  prompt: `
    Analyze authentication patterns in src/auth/AuthService.ts

    Focus on:
    - Token validation logic
    - Error handling patterns
    - Security best practices

    Output: Pattern summary (<200 lines)
  `,
  model: "opus"
})
```

**Result**: Agent reads file, returns findings to orchestrator. Orchestrator uses findings to plan implementation.

### Example 2: Composite Agent for Multi-Step Task

**Scenario**: 4 file implementation (auth feature)

```javascript
Task({
  subagent_type: "general-purpose",
  prompt: `
    Read protocol: .claude/agents/investigate-and-implement.md

    Implement user authentication feature:
    - src/auth/AuthService.ts
    - src/auth/TokenValidator.ts
    - tests/auth/AuthService.test.ts
    - tests/auth/TokenValidator.test.ts

    Requirements:
    - JWT token validation
    - Refresh token flow
    - Unit + integration tests (no mocks)

    Quality gates:
    - All tests pass
    - Build succeeds
    - Coverage >= 90%
  `,
  model: "opus"
})
```

**Result**: Composite agent internally:
1. Spawns `code-investigator` to analyze existing patterns
2. Spawns `code-implementer` for each file (TDD workflow)
3. Spawns `feature-verifier` to validate tests
4. Returns compact summary: "Feature complete, 8 tests passing, coverage 94%"

**Context savings**: Orchestrator receives ~300 token summary instead of ~15k tokens of raw code/test output.

### Example 3: Agent Teams with File Ownership

**Scenario**: Parallel implementation of 3 independent modules

```javascript
// Step 1: Create the team (TeamCreate only accepts: team_name, description, agent_type)
TeamCreate({
  team_name: "implement-parallel",
  description: "Parallel implementation of auth, game, and UI modules",
  agent_type: "code-implementer"
})

// Step 2: Spawn teammates with file ownership enforced via task prompt
Task({
  team_name: "implement-parallel",
  name: "implementer-auth",
  subagent_type: "code-implementer",
  prompt: "Implement auth module per plan.md Task T010. You may ONLY modify these files: src/auth/**, tests/auth/**. Do not touch any other files."
})

Task({
  team_name: "implement-parallel",
  name: "implementer-game",
  subagent_type: "code-implementer",
  prompt: "Implement game logic per plan.md Task T020. You may ONLY modify these files: src/game/**, tests/game/**. Do not touch any other files."
})

Task({
  team_name: "implement-parallel",
  name: "implementer-ui",
  subagent_type: "code-implementer",
  prompt: "Implement UI components per plan.md Task T030. You may ONLY modify these files: src/ui/**, tests/ui/**. Do not touch any other files."
})
```

> **Note**: File ownership is enforced via task prompt instructions, not TeamCreate parameters.
> TeamCreate only accepts `team_name`, `description`, and `agent_type`.
> The File Ownership Protocol in `.claude/rules/agent-teams.md` describes the full coordination pattern.

**Result**:
- All 3 teammates work in parallel (no file conflicts due to prompt-enforced disjoint ownership)
- Lead monitors via shared task list
- Each teammate auto-claims next task after finishing current one
- ~3x faster than sequential execution

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Agent claims task complete but tests fail | Always verify with `dotnet test` or `npm test` yourself |
| File conflicts in team execution | Ensure disjoint file sets in task prompts before spawning (see `.claude/rules/agent-teams.md`) |
| Background agent hangs | Cap at 8 background agents, check context budget |
| Composite agent exceeds context | Split task further or use direct agents with file-based handoff |
| Task stuck in `in_progress` | Check `blockedBy` dependencies, verify teammate not crashed |

## See Also

- `agents-orchestration-2026.md` - Agent lifecycle, subagents vs teams
- `model-selection-2026.md` - Model selection criteria (Opus/Sonnet/Haiku)
- `.claude/rules/model-selection.md` - Per-agent model mappings
- `.claude/agents/investigate-and-implement.md` - Composite agent protocol
- `.claude/docs/agent-teams-guide.md` - Team creation and coordination

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/agent-teams (official agent teams docs)
- DHSTSP codebase `.claude/agents/` (composite agent protocols)
- `.claude/rules/agent-teams.md` (file ownership, decision rules)
- `.claude/rules/model-selection.md` (direct vs composite heuristics)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + production use)
**Frequency validation**: 100% (task states, dependencies from official docs)
