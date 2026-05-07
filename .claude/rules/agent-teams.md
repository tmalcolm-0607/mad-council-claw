# Agent Teams

## Decision Rule

**Use TEAMS when:** >=3 independent tasks, disjoint file sets, >=30min total, no inter-step judgment needed.

**Use SUBAGENTS when:** <3 tasks, sequential dependencies, file conflicts, <30min, or non-decomposable task.

## Dispatch Pattern

Every skill uses this 3-condition check before spawning a team:

```
1. Read .claude/agent-teams-config.json
   → config.enabled == true AND config.phases[current-phase] == "teams"

2. Read .claude/settings.local.json
   → env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1"
   → If missing: WARN user with setup instructions, fall back to subagents

3. IF both pass → Execute team variant
   ELSE → Execute existing subagent variant (UNCHANGED)

ON FAILURE (team creation):
  → Log warning
  → Fall back to subagent variant
```

**Note**: The env setting in `settings.local.json` is read directly by Claude Code — it does NOT need to be set as a shell environment variable.

## Phase Guidelines

| MAD Phase | When to Use Teams |
|-----------|-------------------|
| Spec/Plan research | >=2 independent topics |
| Spec/Plan/PR review | Multi-domain review board |
| Implementation `[P]` tasks | **>=3 parallel groups with disjoint files (MANDATORY)** |
| Validation | Parallel read-only checks |

## Cost Awareness

| Team Size | Approximate Token Cost Multiplier |
|-----------|-----------------------------------|
| 1 teammate | ~2x (lead + 1 teammate) |
| 2 teammates | ~3x |
| 5 teammates | ~6x |

All teammates inherit the lead's model. **Cost is justified when** parallel execution saves >=2x wall-clock time or multi-perspective review catches >=30% more findings.

## File Ownership Protocol

1. Each teammate gets explicit, disjoint file list
2. No file overlap allowed - sequential fallback if overlap detected
3. Lead reviews plans before modifications
4. Lead runs gates after all teammates complete

## Kill Conditions

Revert to subagents if: <1.5x speedup, >5x cost with no quality gain, file conflicts, teammate hangs, or >30% coordination overhead.

See `.claude/rules/worktree-runtime-isolation.md` for runtime isolation (ports, Docker, DB).
