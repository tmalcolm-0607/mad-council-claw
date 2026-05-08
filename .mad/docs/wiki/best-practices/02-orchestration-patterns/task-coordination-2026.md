---
category: orchestration-patterns
subcategory: task-coordination
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Task Coordination (2026)

## Overview

Task creation, assignment, dependency management, and DAG-based execution patterns for coordinating multi-agent workflows.

**Key capabilities**:
- Shared task list visible to all teammates
- Dependency tracking (`blockedBy` field)
- Self-claim workflow (teammates pick up next unblocked task)
- File locking prevents race conditions

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Explicit Dependencies** | Use `blockedBy` to define task order |
| **Wave Execution** | Parallelize independent tasks in same wave |
| **Owner Assignment** | Use TaskUpdate to assign tasks to teammates |
| **Status Tracking** | pending → in_progress → completed lifecycle |
| **DAG Execution** | Opt-in DAG mode for automatic wave computation |

## Patterns (Current)

### TaskCreate

Create tasks before spawning teammates to provide clear work backlog.

**Required fields**:
- `subject`: Brief, actionable title in imperative form (e.g., "Fix authentication bug")
- `description`: Detailed description with context and acceptance criteria
- `activeForm`: Present continuous form shown in spinner (e.g., "Fixing authentication bug")

**All tasks created with status `pending`**.

**Example**:
```javascript
TaskCreate({
  subject: "Implement OAuth2 login flow",
  description: "Add OAuth2 authentication with Google provider. Include token refresh logic and error handling.",
  activeForm: "Implementing OAuth2 login flow"
})
```

### TaskUpdate

Update task status, ownership, dependencies, and metadata.

**Common operations**:

| Operation | Fields | Example |
|-----------|--------|---------|
| **Claim task** | `taskId`, `status: "in_progress"`, `owner` | `{taskId: "1", status: "in_progress", owner: "researcher-auth"}` |
| **Complete task** | `taskId`, `status: "completed"` | `{taskId: "1", status: "completed"}` |
| **Add dependency** | `taskId`, `addBlockedBy: ["task-id"]` | `{taskId: "2", addBlockedBy: ["1"]}` (task 2 blocked by task 1) |
| **Update description** | `taskId`, `description` | `{taskId: "1", description: "Updated requirements..."}` |

**Status workflow**: `pending` → `in_progress` → `completed`

**Delete task**: Set `status: "deleted"` to permanently remove.

### Dependencies and Waves

**Dependencies**:
- Task can depend on other tasks via `blockedBy` field
- Pending task with unresolved dependencies cannot be claimed
- When dependency completes, blocked tasks unblock automatically

**Wave execution** (DAG mode):
- Wave 1: All tasks with no dependencies (can run in parallel)
- Wave 2: Tasks blocked only by Wave 1 tasks
- Wave N: Tasks blocked only by Wave 1...N-1 tasks

**Self-claim workflow**:
1. Teammate finishes task → marks as completed
2. Checks shared task list for next unassigned, unblocked task
3. Claims task via TaskUpdate (sets owner + status: "in_progress")
4. Repeats until no unblocked tasks remain

### Permissions

- Teammates start with lead's permission settings
- If lead runs `--dangerously-skip-permissions`, all teammates do too
- Can change individual teammate modes after spawning
- Cannot set per-teammate modes at spawn time

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Task dependencies | Manual task ordering | Explicit `blockedBy` field with automatic unblocking | Add `addBlockedBy` array to TaskUpdate |
| Wave computation | Manual | Automatic (DAG mode) or manual | Enable DAG mode via feature flags (see `.claude/docs/dag-feature-flags.md`) |
| Task ownership | Implicit | Explicit `owner` field | Use TaskUpdate to set owner when claiming |
| Self-claim workflow | N/A | Automatic (teammates pick next unblocked) | No migration needed (automatic) |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Spawning teammates without tasks | No clear work backlog | Create tasks via TaskCreate first |
| Overlapping file ownership | Race conditions, conflicts | Disjoint file sets per teammate |
| Manually assigning all tasks | Coordination overhead | Self-claim workflow (teammates pick next) |
| Missing dependencies | Tasks run out of order | Explicit `blockedBy` dependencies |
| Forgetting to mark completed | Blocks downstream tasks | Always TaskUpdate status to "completed" |

## Examples

### Example 1: Sequential Dependencies

**Scenario**: 3 tasks where each depends on previous

```javascript
// Task 1: No dependencies (Wave 1)
TaskCreate({
  subject: "Design database schema",
  description: "Design tables for auth module",
  activeForm: "Designing database schema"
})

// Task 2: Depends on Task 1 (Wave 2)
TaskCreate({
  subject: "Implement database migrations",
  description: "Create migrations based on schema design",
  activeForm: "Implementing database migrations"
})
TaskUpdate({taskId: "2", addBlockedBy: ["1"]})

// Task 3: Depends on Task 2 (Wave 3)
TaskCreate({
  subject: "Test migrations",
  description: "Verify migrations run cleanly",
  activeForm: "Testing migrations"
})
TaskUpdate({taskId: "3", addBlockedBy: ["2"]})
```

**Execution**: Sequential (Wave 1 → Wave 2 → Wave 3)

### Example 2: Parallel Execution (Wave 1)

**Scenario**: 4 independent research tasks

```javascript
// All tasks have no dependencies → all in Wave 1
TaskCreate({subject: "Research OAuth2 patterns", description: "...", activeForm: "Researching OAuth2 patterns"})
TaskCreate({subject: "Research JWT best practices", description: "...", activeForm: "Researching JWT best practices"})
TaskCreate({subject: "Research rate limiting", description: "...", activeForm: "Researching rate limiting"})
TaskCreate({subject: "Research session management", description: "...", activeForm: "Researching session management"})

// Spawn 4 teammates → each claims one task → all execute in parallel
```

**Execution**: Parallel (all in Wave 1, no dependencies)

### Example 3: Mixed Dependencies (Waves 1-3)

**Scenario**: 6 tasks with mixed dependencies

```
Wave 1 (parallel): T1, T2, T3 (no dependencies)
Wave 2 (parallel): T4 (blocked by T1), T5 (blocked by T2)
Wave 3 (sequential): T6 (blocked by T4, T5)
```

**Expected parallelism**: 3 tasks in Wave 1, 2 tasks in Wave 2, 1 task in Wave 3

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Task stuck in pending | Check `blockedBy` dependencies - ensure blocking tasks completed |
| Teammate claims blocked task | Bug - should not happen (file locking prevents this) |
| Duplicate work | Verify only one teammate assigned per task (check `owner` field) |
| Tasks not unblocking | Verify blocking task marked `status: "completed"` (not just implemented) |
| Wave computation wrong | Check DAG execution mode setting (`.claude/settings.local.json` under `env.DAG_EXECUTION_MODE`) |

## See Also

- `agent-teams-2026.md` - Multi-agent coordination
- `.claude/docs/dag-execution-guide.md` - DAG patterns
- `.mad/lib/dag-engine.js` - Wave computation
- `.claude/docs/dag-feature-flags.md` - DAG feature flags

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/agent-teams (official)
- https://code.claude.com/docs/en/best-practices (official)
- Project internal: `.mad/docs/dag-execution-guide.md`, `.mad/lib/dag-engine.js`

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + internal implementation)
**Frequency validation**: 90%+ (patterns appear in official docs + internal codebase)
