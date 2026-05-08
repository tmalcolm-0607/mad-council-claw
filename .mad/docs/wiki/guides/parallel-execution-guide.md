# Parallel Execution Guide

Detailed patterns for team-based parallel execution in the MAD workflow.

## Pre-Execution Decision Tree

```
1. Count tasks in current work item
   -> 1-2 tasks? -> Sequential OK

2. Check task dependencies (any blockedBy fields?)
   -> Dependency chain? -> Sequential (respect order)

3. Count independent tasks (no blockedBy, no shared files)
   -> >=3 independent tasks? -> CREATE TEAM (mandatory)

Exception: Skip teams only if:
  - Orchestrator needs judgment between steps
  - Total estimated time < 30 minutes
  - Tasks modify the same files (conflict risk)
```

## Team Creation Pattern

```javascript
// 1. Create team
TeamCreate({
  team_name: "feature-implementation",
  description: "Parallel implementation of [feature]"
})

// 2. Spawn teammates in parallel (single message with multiple Task calls)
Task({
  team_name: "feature-implementation",
  name: "backend-impl",
  subagent_type: "code-implementer",
  prompt: "..."
})
Task({
  team_name: "feature-implementation",
  name: "frontend-impl",
  subagent_type: "code-implementer",
  prompt: "..."
})
Task({
  team_name: "feature-implementation",
  name: "test-impl",
  subagent_type: "code-implementer",
  prompt: "..."
})

// 3. Monitor and coordinate
// 4. Shutdown gracefully when complete
```

## Cost-Benefit Model

Parallelization is justified when:
- **Time savings**: Estimated wall-clock time >=2x faster than sequential
- **Quality gains**: Multi-perspective review catches >=30% more issues
- **File safety**: No ownership conflicts (disjoint file sets)

**Typical time savings**:
- 3 independent tasks: 50% faster (max of 3 durations vs sum)
- 5 independent tasks: 60-70% faster

**When NOT to parallelize**:
- Tasks share files -> ownership conflicts
- Tasks have dependencies -> respect order
- Total time < 30 min -> overhead not justified
- Orchestrator judgment needed between steps -> use composite agents

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Sequential for 3+ independent tasks | Wastes time, context capacity | Create team |
| Teams for sequential dependent tasks | Overhead without benefit | Use subagents |
| Ignoring file ownership conflicts | Merge conflicts, wasted work | Disjoint file sets or sequential |
| Creating team without clear task boundaries | Coordination chaos | Define explicit deliverables per teammate |

## References

- `.claude/rules/agent-teams.md` - Agent Teams decision rules and phase guidelines
- `.claude/docs/agent-teams-guide.md` - Full Agent Teams integration guide
- `.claude/rules/parallel-opportunity-thresholds.md` - Hook configuration
