---
category: claude-code-features
subcategory: hooks
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Hooks (2026)

## Overview

User-defined commands, prompts, or agents that execute automatically at specific points in Claude Code's lifecycle. Released in early 2026, hooks transform best-practice guidelines into enforced rules that run every time Claude touches your codebase.

**Key insight**: Hooks enable enforcement of project-specific conventions without manual review, shifting quality control from reactive (code review) to proactive (automated enforcement).

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Non-Blocking Default** | Hooks warn, don't block (unless critical) |
| **Fast Execution** | Hooks must complete in <100ms |
| **Fail-Safe** | Hook errors never crash Claude |
| **Idempotent** | Safe to retry/re-run |
| **Observable** | Log all actions to `.claude/logs/` |
| **Exit Code Protocol** | Exit 0 (pass), Exit 1 (warn), Exit 2 (block/prevent) |

## Patterns (Current)

### Hook Types

| Hook Type | Purpose | When Triggered |
|-----------|---------|----------------|
| **TeammateIdle** | Keep teammates working or gracefully shutdown | Teammate about to go idle after task completion |
| **TaskCompleted** | Validate task completeness before marking done | Task about to transition to `completed` status |
| **SubagentStop** | Validate agent deliverables | Subagent finishes execution |
| **PermissionRequest** | Auto-approve or deny tool calls | Before tool execution requiring user permission |
| **Pre-commit** | Quality gates before commit | Before git commit executes |
| **Post-commit** | Record metadata, trigger CI | After git commit succeeds |

### Event Triggers

**Lifecycle hooks**:
- Session start: Detect pending handoffs, restore state
- Session end: Generate session summaries, cleanup temp files
- Tool call: Validate parameters, enforce conventions
- Agent spawn: Context budget checks, orchestration blocking
- Agent stop: Deliverable validation, findings persistence

**CI/CD integration**:
- Pre-commit: Build, test, lint enforcement
- Post-commit: Update traceability, notify team
- Pre-push: Final gate before remote

### Blocking vs Warning

**Exit code 0** (pass): Hook completed successfully, allow operation.

**Exit code 1** (warn): Hook detected issue but operation proceeds. Logs warning to user.

**Exit code 2** (block): Hook prevents operation. Examples:
- `TeammateIdle`: Exit 2 keeps teammate active (returns to work queue)
- `TaskCompleted`: Exit 2 prevents marking task complete (must fix issues first)
- `context-warning.js`: Exit 2 hard-blocks at 85% context threshold

**When to block**:
- Quality gates failed (tests, build, lint)
- Context capacity critically low (>85%)
- Deliverables missing or invalid
- Security patterns violated

**When to warn**:
- Context approaching limits (50-70%)
- Anomalous behavior detected (excessive spawns, rapid prompts)
- Best practices not followed (mocking in integration tests)
- Documentation incomplete

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Hooks availability | Conceptual guidance only | Production-ready feature (Q1 2026) | Implement hooks in `.claude/hooks/` |
| Enforcement mechanism | Manual review | Automated hook execution | Convert review checklists to hooks |
| TeammateIdle handling | Teammates auto-idle | Hook can prevent idle (exit 2) | Implement idle logic in hook |
| TaskCompleted validation | Manual checklist | Hook validates before transition | Add validation logic to hook |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Blocking for non-critical issues | Interrupts flow, reduces productivity | Warn and log, block only for critical violations |
| Slow hook execution (>500ms) | Delays every tool call/lifecycle event | Optimize performance, cache results |
| Hook crashes on error | Breaks Claude Code workflow | Fail-safe error handling, graceful degradation |
| Duplicate validation logic | Maintenance burden, inconsistency | Centralize validation in single hook |
| Hardcoded thresholds | Inflexible, requires code changes | Read config from `.claude/rules/*.md` |

## Examples

### Example 1: Validation Hook (Warning)

**Hook**: `detect-anomaly.js` (tracks agent spawns per hour)

```javascript
// .claude/hooks/detect-anomaly.js
const { readThresholds } = require('../lib/threshold-reader.js');

module.exports = async function (event) {
  const thresholds = readThresholds('.claude/rules/anomaly-thresholds.md');
  const spawnsPerHour = countSpawnsInWindow(event, 3600);

  if (spawnsPerHour > thresholds.spawns_per_hour) {
    console.warn(`[ANOMALY] ${spawnsPerHour} agent spawns in past hour (threshold: ${thresholds.spawns_per_hour})`);
    return 1; // Warn but allow
  }

  return 0; // Pass
};
```

**Result**: Logs warning to user, operation proceeds.

### Example 2: Blocking Hook (Critical)

**Hook**: `context-warning.js` (prevents work past 85% context threshold)

```javascript
// .claude/hooks/context-warning.js
module.exports = async function (event) {
  const contextRatio = estimateContextUsage(event);
  const haltThreshold = process.env.CONTEXT_GUARDIAN_HALT_THRESHOLD || 0.85;

  if (contextRatio >= haltThreshold) {
    console.error(`[CONTEXT HALT] Context at ${(contextRatio * 100).toFixed(0)}% - generate handoff and start new session`);
    return 2; // Block operation
  }

  return 0; // Pass
};
```

**Result**: Operation blocked, user must generate handoff before continuing.

### Example 3: TeammateIdle Hook

**Hook**: Keep teammate active until all tasks complete

```javascript
// .claude/hooks/teammate-idle.js
module.exports = async function (event) {
  const { teammateId, taskListStatus } = event;

  // Check if unassigned tasks remain
  const unclaimedTasks = taskListStatus.filter(t =>
    t.status === 'pending' && !t.owner && t.blockedBy.length === 0
  );

  if (unclaimedTasks.length > 0) {
    console.log(`[TeammateIdle] ${unclaimedTasks.length} tasks remain - keeping ${teammateId} active`);
    return 2; // Prevent idle, return to work queue
  }

  return 0; // Allow idle/shutdown
};
```

### Stop Guard (Session Exit Advisor)

The Stop Guard hook (`.claude/hooks/stop-guard.js`) fires when a Claude Code session ends. It reads the active work item, checks `plan.md` for unchecked items (`- [ ]`), and emits an advisory warning if incomplete work exists without a `PENDING_HANDOFF`.

**Never blocking** -- always exits 0 (advisory only).

| Condition | Behavior |
|-----------|----------|
| No active work item | Silent (nothing to check) |
| All plan items checked | Silent (work complete) |
| `PENDING_HANDOFF` exists | Silent (handoff already generated) |
| Unchecked items remain | Advisory warning with item list |

**Feature flag**: `STOP_GUARD_ENABLED` (default: `true`)

```json
{
  "env": {
    "STOP_GUARD_ENABLED": "false"
  }
}
```

**Relationship to Context Guardian**: Context Guardian fires during a session (at ~85% capacity) and generates a handoff. Stop Guard fires at session end and recommends generating a handoff if work is incomplete but no handoff exists.

### Knowledge Extraction

The knowledge extraction hook (`.claude/hooks/on-subagent-stop.js`) automatically detects valuable investigation sessions. When a `code-investigator` or `researcher`-type agent completes after a configurable minimum duration, it creates a knowledge extraction prompt in `.claude/scratch/knowledge-prompts/`.

**Qualifying agent types**: `code-investigator`, `research-scout`, `research-curator`, `research-reviewer`, `parallel-researcher`

**Review extracted knowledge** with: `/apply-learnings --knowledge`

**Feature flag**: `KNOWLEDGE_EXTRACTION_MIN_DURATION_MS` (default: `600000` = 10 minutes, range: 1-60 min)

```json
{
  "env": {
    "KNOWLEDGE_EXTRACTION_MIN_DURATION_MS": "900000"
  }
}
```

**Tuning guidance**:
- If too many low-value candidates appear, increase the threshold
- If valuable investigations are missed, decrease the threshold
- Run `/apply-learnings --stats` to see candidate counts

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hook not firing | Check file permissions (must be executable), verify hook registered in config |
| Hook blocking incorrectly | Check exit code logic, verify thresholds in config files |
| Hook timeout | Optimize performance, reduce I/O, cache results |
| Hook errors crash workflow | Add try-catch, return exit 0 on error (fail-safe) |
| Duplicate warnings | Implement cooldown (suppress within time window) |

## See Also

- `context-management-2026.md` - Context guardian hooks
- `.claude/hooks/` - Hook implementations
- `.claude/rules/anomaly-thresholds.md` - Hook configuration
- `.claude/rules/context-guardian.md` - Context threshold behaviors
- `.claude/docs/agent-teams-guide.md` - TeammateIdle hook patterns

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (hooks lifecycle section)
- DHSTSP codebase `.claude/hooks/` implementations
- `.claude/rules/context-guardian.md` (threshold enforcement)
- `.claude/rules/anomaly-thresholds.md` (configuration patterns)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + production codebase)
**Frequency validation**: 100% (all patterns from official sources or production use)
