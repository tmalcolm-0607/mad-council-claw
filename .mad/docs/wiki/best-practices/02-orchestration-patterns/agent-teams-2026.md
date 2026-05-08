---
category: orchestration-patterns
subcategory: agent-teams
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Agent Teams (2026)

## Overview

Multi-agent team coordination using Claude Code Agent Teams. Covers team creation, teammate spawning, task assignment, file ownership, and cost optimization.

**Key capabilities**:
- Each teammate is full Claude Code instance with 1M token context
- Shared task list with dependency tracking
- Inbox-based automatic message delivery
- Parallel execution with file locking

## Core Principles

| Principle | Description |
|-----------|-------------|
| **≥3 Tasks = Teams** | Use teams for 3+ independent tasks (mandatory unless exception applies) |
| **File Ownership** | Disjoint file sets prevent conflicts |
| **Cost Awareness** | 2 teammates ~3x cost, 5 teammates ~6x cost |
| **Plan Approval** | Review teammate plans before implementation |
| **Graceful Shutdown** | Send shutdown_request before cleanup |

## Patterns (Current)

### Team Creation

**Prerequisites**:
1. Enable agent teams: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` under `env`
2. Verify ≥3 independent tasks (no `blockedBy` dependencies)
3. Check for file ownership conflicts (disjoint file sets required)
4. Estimate time savings (target ≥2x faster or ≥30% more findings)

**When to use teams vs subagents**:

| Use Agent Teams When | Use Subagents When |
|----------------------|-------------------|
| Teammates need to share findings | Only result matters, not discussion |
| Challenge each other's conclusions | Sequential tasks with dependencies |
| Coordinate autonomously | Quick, focused workers report back |
| Multiple perspectives add value | Single perspective sufficient |

**Best use cases**:
- Research and review (multi-perspective analysis)
- New modules/features (each teammate owns separate piece)
- Debugging with competing hypotheses (test theories in parallel)
- Cross-layer coordination (frontend, backend, tests owned separately)

### Teammate Coordination

**Messaging**:
- `message`: Send to one specific teammate (1:1)
- `broadcast`: Send to all teammates (use sparingly, costs scale with team size)

**Automatic delivery**:
- Messages delivered automatically to recipients (no polling)
- Idle notifications when teammates finish
- Lead receives completion notifications

**Display modes**:

| Mode | Requirements | Interaction |
|------|-------------|-------------|
| **In-process** (default) | Any terminal | Shift+Up/Down to select teammate |
| **Split panes** | tmux or iTerm2 | Click into pane to interact directly |

**Delegate mode**:
- Press Shift+Tab after team created
- Lead restricted to coordination tools only (spawn, message, shutdown, task management)
- Prevents lead from implementing instead of waiting for teammates

### File Ownership Protocol

For parallel implementation teams:

1. **Explicit ownership**: Each teammate gets list of files it may modify
2. **No overlap**: File lists must be disjoint (same file cannot appear in two lists)
3. **Conflict detection**: Verify no file ownership overlaps before spawning
4. **Sequential fallback**: If files overlap, execute task groups sequentially
5. **Plan approval**: Lead reviews each teammate's plan before file modifications
6. **Gate after merge**: Lead runs quality gates across all changes after teammates complete

### Plan Approval Pattern

For complex or risky tasks:

1. Teammate works in read-only plan mode
2. Sends plan approval request to lead via SendMessage
3. Lead reviews and approves/rejects with feedback
4. If rejected, teammate revises and resubmits
5. Once approved, teammate exits plan mode and implements

**Note**: Lead makes approval decisions autonomously - give criteria in spawn prompt to influence judgment.

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Agent teams | Not available | Experimental (enable with flag) | Add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to `.claude/settings.local.json` under `env` |
| Teammate messaging | N/A | Automatic delivery, no polling | Use `message` (1:1) or `broadcast` (all) |
| Plan approval | N/A | Optional for risky tasks | Add "require plan approval" to spawn prompt |
| Delegate mode | N/A | Lead coordinates only | Press Shift+Tab after team created |
| Session resumption | N/A | Limited (in-process teammates NOT restored) | Spawn new teammates after `/resume` |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Agent teams for sequential work | Overhead without parallelism | Use subagents instead |
| Shared files across teammates | File conflicts | Disjoint file ownership |
| Unattended teams | Orphan processes | Lead monitors and cleans up |
| Teams for single topic/check | Overhead exceeds benefit | Fall back to subagent |
| Skipping plan approval for impl | Unreviewed code changes | Require plan approval for risky tasks |
| Nested teams | API limitation | One team per session |

## Examples

### Example 1: Research Swarm (Parallel Researchers)

**Scenario**: Research 3 independent OAuth2 topics simultaneously

**Team composition**: 1 lead + 3 parallel-researcher teammates

**Cost**: ~4x baseline (3 teammates + lead coordination overhead)

**Expected savings**: 60-70% wall-clock time (3 topics in parallel vs sequential)

**File ownership**: None (read-only research)

### Example 2: Parallel Implementation Team

**Scenario**: Implement 4 feature tasks with disjoint file sets

**Team composition**: 1 lead + 4 code-implementer teammates

**File ownership**:
- Teammate A: `src/auth/*.ts` (no overlap)
- Teammate B: `src/api/*.ts` (no overlap)
- Teammate C: `src/db/*.ts` (no overlap)
- Teammate D: `tests/*.spec.ts` (no overlap)

**Plan approval**: Required (lead reviews each teammate's plan before implementation)

**Gates**: Lead runs full quality gates after all teammates complete

**Cost**: ~5x baseline (4 teammates + lead)

**Expected savings**: 70% wall-clock time (4 tasks in parallel vs sequential)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Teammates not spawning | Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` under `env` |
| File conflicts | Verify disjoint file ownership before spawning |
| Cost exceeds benefit | Kill condition: cost >5x with no quality gain → revert to subagents |
| Orphan teammates after `/resume` | Spawn new teammates (in-process teammates not restored) |
| Duplicate findings (review board) | Kill condition: no unique value added → revert to subagents |
| Coordination overhead >30% | Kill condition: lead spends too much time coordinating → revert to subagents |

## See Also

- `task-coordination-2026.md` - Task assignment and dependencies
- `.claude/rules/agent-teams.md` - Team decision rules
- `.claude/docs/agent-teams-guide.md` - Team patterns
- `.claude/docs/parallel-execution-guide.md` - Parallel execution decision tree

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/agent-teams (official)
- https://code.claude.com/docs/en/best-practices (official)
- VentureBeat Opus 4.6 announcement
- https://addyosmani.com/blog/claude-code-agent-teams/
- https://www.sitepoint.com/anthropic-claude-code-agent-teams/

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 90%+ (patterns appear in official docs + 2+ community sources)
