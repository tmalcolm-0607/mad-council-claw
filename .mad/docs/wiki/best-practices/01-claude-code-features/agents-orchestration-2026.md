---
category: claude-code-features
subcategory: agents-orchestration
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Agents & Orchestration (2026)

## Overview

Agent orchestration in Claude Code provides two distinct models: subagents (focused workers) and agent teams (collaborative instances). Understanding when to use each is critical for effective workflows and cost management.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Subagents for focused work** | Use when only result matters, not the discussion |
| **Teams for collaboration** | Use when teammates need to share findings and challenge each other |
| **Context isolation** | Each agent/teammate gets own context window |
| **Task-based coordination** | Use shared task lists for dependency tracking |
| **Cost awareness** | Teams scale linearly with size (2 teammates ≈ 3x cost) |

## Patterns (Current)

### Subagents vs Agent Teams

**Key distinction from official docs**:

| Feature | Subagents | Agent Teams |
|---------|-----------|-------------|
| Context | Own window, results return to caller | Own window, fully independent |
| Communication | Report to main agent only | Message each other directly |
| Coordination | Main agent manages all work | Shared task list with self-coordination |
| Best for | Focused tasks where only result matters | Complex work requiring discussion/collaboration |
| Token cost | Lower (results summarized) | Higher (each teammate is separate instance) |

**Rule**: Use subagents for quick workers that report back. Use agent teams when teammates need to share findings, challenge each other, coordinate on their own.

### When to Use Agent Teams

**Enable**: Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json or environment

**Best use cases** (from official docs):
1. **Research and review**: Multiple perspectives simultaneously
2. **New modules/features**: Teammates own separate pieces
3. **Debugging with competing hypotheses**: Test theories in parallel
4. **Cross-layer coordination**: Frontend, backend, tests

**Architecture components**:
- Team lead (main session)
- Teammates (separate Claude Code instances, 1M token context each)
- Task list (shared work items with dependency tracking)
- Mailbox (messaging system with automatic delivery)

### Display Modes

**In-process** (default):
- All teammates in main terminal
- Shift+Up/Down to select teammate
- Works in any terminal

**Split panes**:
- Each teammate gets own pane
- Requires tmux or iTerm2
- Click into pane to interact directly

### Coordination Patterns

**Delegate mode**:
- Lead focuses entirely on coordination, not implementation
- Enable by pressing Shift+Tab after team created
- Prevents lead from starting implementation instead of waiting for teammates

**Plan approval pattern** (for complex/risky tasks):
1. Teammate works in read-only plan mode
2. Sends plan approval request to lead
3. Lead reviews and approves/rejects with feedback
4. If rejected, teammate revises and resubmits
5. Once approved, teammate exits plan mode and implements

**Lead makes approval decisions autonomously** - give criteria in prompt to influence judgment.

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Agent teams | Not available | Experimental feature | Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Teammate messaging | N/A | Automatic delivery, no polling | Use `message` (1:1) or `broadcast` (all) |
| Plan approval | N/A | Optional for risky tasks | Add "require plan approval" to spawn prompt |
| Delegate mode | N/A | Lead coordinates only | Press Shift+Tab after team created |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Agent teams for sequential work | Overhead without parallelism | Use subagents instead |
| Shared files across teammates | File conflicts | Disjoint file ownership |
| Unattended teams | Orphan processes | Lead monitors and cleans up |
| Teams for single topic/check | Overhead exceeds benefit | Fall back to subagent |
| Skipping plan approval for impl | Unreviewed code changes | Require plan approval for risky tasks |
| Nested teams | API limitation | One team per session |

## Examples

### Example 1: Subagent for Focused Investigation

```markdown
User: "Investigate how the auth module works"

Claude spawns: code-investigator subagent
- Reads auth files
- Traces flow
- Returns summary to main session

Main session receives: Concise investigation report
```

### Example 2: Agent Team for Multi-Domain Review

```markdown
User: "Review this PR from security, performance, and testing perspectives"

Claude creates: review-board team
- domain-reviewer (security) - checks auth boundaries
- domain-reviewer (performance) - analyzes query patterns
- domain-reviewer (testing) - verifies test coverage

Teammates share findings, challenge each other's severity ratings
Lead synthesizes final review
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Teammates not shutting down | Send `shutdown_request`, wait 30s, or restart session |
| Task status lag | Teammates fail to mark complete - manually update via TaskUpdate |
| High token costs | Verify team justified (≥2x speed gain), switch to subagents if not |
| File conflicts | Ensure disjoint file ownership before spawning |

## See Also

- `agent-teams-2026.md` - Detailed team orchestration patterns
- `task-api-2026.md` - Shared task list coordination
- `hooks-2026.md` - TeammateIdle and TaskCompleted enforcement
- `skills-2026.md` - Agent spawning from skills

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/agent-teams
- https://code.claude.com/docs/en/best-practices
- https://github.com/wshobson/agents
- https://github.com/VoltAgent/awesome-claude-code-subagents

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 100% (patterns from official sources)
