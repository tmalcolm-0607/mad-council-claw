---
category: emerging-patterns
subcategory: whats-new
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# What's New (Q1 2026)

## Overview

New features, API changes, and tool updates released in Q1 2026 (January-March). This file is refreshed quarterly with latest Claude Code releases.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Version Tracking** | Track Claude Code version releases |
| **API Stability** | Note breaking vs non-breaking changes |
| **Migration Guides** | Link to migration documentation |
| **Feature Flags** | Document opt-in experimental features |
| **Deprecation Notices** | Track deprecation timelines |

## New Features (Q1 2026)

### Agent Teams (Experimental)

**Status**: Research preview, disabled by default

**Capability**: Multi-agent collaboration with autonomous coordination. Spin up multiple agents working in parallel as a team. Best for independent, read-heavy work like comprehensive codebase reviews.

**Architecture**:
- Expanded context window per teammate *(exact token limits vary by model tier -- check current Claude documentation for confirmed figures)*
- Each teammate is full Claude Code instance
- Shared task list with dependency tracking
- Inbox-based messaging

**Enable**: Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` under `env` or as environment variable

**Cost**: Token-intensive feature - 2 teammates ~3x cost, 5 teammates ~6x cost (all teammates inherit lead's model)

**Limitations**:
- No session resumption with in-process teammates (`/resume`, `/rewind` don't restore teammates)
- Task status can lag (teammates may fail to mark tasks complete, blocking dependencies)
- Shutdown can be slow (teammates finish current request before shutting down)
- One team per session (lead can only manage one team at a time)
- No nested teams (teammates can't spawn their own teams)
- Lead is fixed (can't promote teammate to lead or transfer leadership)

See: `.claude/rules/agent-teams.md`, `.claude/docs/agent-teams-guide.md`

### Hooks (Production-Ready)

**Status**: Released Q1 2026, production-ready

**Capability**: User-defined commands, prompts, or agents that execute automatically at specific points in Claude Code's lifecycle. Transform guidelines into enforced rules that run every time Claude touches the codebase.

**Available hooks**:
- `TeammateIdle` - when teammate about to go idle
- `TaskCompleted` - when task marked complete
- `Pre-commit`, `Post-commit` - CI/CD integration
- `SubagentStop` - when subagent finishes
- `PermissionRequest` - when user approval needed

**Exit codes**:
- Exit 0: Continue normally
- Exit 2: Send feedback and keep working (TeammateIdle) or prevent completion (TaskCompleted)

**Configuration**: `.claude/hooks/` directory with executable scripts

See: `.claude/hooks/` for examples, `.claude/rules/context-guardian.md` for integration patterns

### GitHub Action

**Status**: Released early 2026

**Trigger**: `@claude` mention in PR or Issue

**Capabilities**:
- Pull request reviews
- Fixing issues automatically
- Updating documentation
- Running quality checks

**Alternative**: GitHub MCP server for manual `gh` CLI workflows

### Claude Opus 4.6

**Released**: Q1 2026 alongside agent teams feature

**Improvements**:
- Significantly expanded context window *(exact token limits vary by model tier -- verify current limits in official Claude documentation)*
- Agent teams support
- Improved reasoning capability

**Model Lineup** (current as of 2026-02-16):
- **Claude Opus 4.6** - Most capable, highest cost ($5 input / $25 output per MTok)
- **Claude Sonnet 4.5** - 90% of Opus capability, 2x speed, recommended default ($3 input / $15 output per MTok)
- **Claude Haiku 4.5** - Fastest, lowest cost, good for high-volume tasks

### Prompt Caching (Automatic)

**Status**: Automatic optimization (no manual configuration needed)

**Savings**: 90% cost reduction on repeated content after 2 requests

**Impact**: Significant cost savings for long-running sessions with stable context (project rules, large files)

## API Changes

### Headless Mode Enhancements

**New output formats**:
- JSON output format
- Streaming JSON output

**Built-in cost tracking**: `/cost` command shows token usage and estimated costs

### Automatic Context Compaction

**Behavior**: Claude Code automatically compacts conversation history when approaching context limits

**Manual control**: Still available via `/compact` command

**Handoff protocol**: Context guardian hooks (`context-warning.js`, `pre-compact.js`) generate handoff documents before compaction

See: `.claude/rules/context-guardian.md` for threshold behaviors

## Tool Updates

### GitHub CLI Integration

**Official GitHub Action**: `@claude` mention triggers (early 2026)

**Manual workflows**: `gh` CLI commands continue to work

**MCP server**: GitHub MCP server provides authenticated access to private repos

## Breaking Changes

### Model Deprecations

**Deprecated and removed**:
- Claude Opus 4 and 4.1 (removed from model selector and Claude Code)

**Migration**: Update agent definitions and skill configurations to use Opus 4.5/4.6, Sonnet 4.5, or Haiku 4.5

See: `deprecations-2026.md` for detailed migration paths

### Legacy SDK Entrypoint

**Deprecated**: Legacy SDK entrypoint

**Migration**: Use `@anthropic-ai/claude-agent-sdk` instead

## Migration Guides

### Migrating to Opus 4.6 / Sonnet 4.5

**For agent definitions** (`.claude/agents/*.md`):
```yaml
---
model: opus  # Valid: opus, sonnet, haiku (maps to 4.5/4.6 series)
---
```

**For composite agents** (`subagent_type="general-purpose"`):
- No changes needed - agents default to Opus 4.6
- For cost optimization, specify `model: "sonnet"` in Task calls

**For model selection rules** (`.claude/rules/model-selection.md`):
- Opus 4.6 for complex reasoning, architecture, security, code review
- Sonnet 4.5 for implementation, testing, documentation (90% of Opus capability, 40% cost savings)
- Haiku 4.5 for cleanup, formatting, batch operations

### Enabling Agent Teams

**Step 1**: Add to `.claude/settings.local.json`:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Step 2**: Configure team templates in `.claude/agent-teams-config.json`

**Step 3**: Use skills that support team dispatch (`mad-implement`, `mad-validate`, `pr-review`)

**Pre-flight checklist**:
- Verify ≥3 independent tasks (no `blockedBy` dependencies)
- Check for file ownership conflicts (disjoint file sets)
- Estimate cost multiplier (2 teammates ~3x, 5 teammates ~6x)
- Ensure split pane support (tmux/iTerm2 on macOS, unsupported on Windows Terminal/VS Code terminal)

See: `.claude/rules/agent-teams.md` for decision rules, `.claude/docs/parallel-execution-guide.md` for cost-benefit model

## Examples

### Example 1: Using Agent Teams for Parallel Implementation

**Scenario**: 4 independent tasks modifying disjoint file sets

**Before (sequential)**:
```bash
# Time: 60 minutes (15 min × 4 tasks)
# Cost: 4x Opus baseline
```

**After (parallel with teams)**:
```bash
# Time: 20 minutes (longest task + coordination overhead)
# Cost: ~5x Opus baseline (lead + 4 teammates)
# Wall-clock savings: 67% faster
```

**When justified**: Savings ≥ 30 minutes, cost multiplier ≤ 5x, no file conflicts

### Example 2: Using Hooks for Quality Gates

**Hook**: `.claude/hooks/pre-commit.sh`
```bash
#!/bin/bash
# Run quality gates before allowing commit
powershell -File scripts/run-quality-gates.ps1
exit $?  # Exit 0 = allow commit, Exit 2 = block commit
```

**Effect**: Enforces quality gates automatically - no manual check needed

## See Also

- `deprecations-2026.md` - Deprecated features and migration paths
- `experimental-features.md` - Beta features and feature flags
- `.claude/rules/agent-teams.md` - Agent teams decision rules
- `.claude/docs/agent-teams-guide.md` - Comprehensive agent teams guide
- https://docs.anthropic.com/en/docs/claude-code/changelog - Official changelog

## Research Metadata

**Sources consulted**:
- https://support.claude.com/en/articles/12138966-release-notes
- https://docs.claude.com/en/docs/about-claude/model-deprecations
- https://code.claude.com/docs/en/agent-teams
- https://www.gradually.ai/en/changelogs/claude-code/
- VentureBeat Opus 4.6 announcement
- https://releasebot.io/updates/anthropic
- https://hackceleration.com/claude-code-review/
- https://max-productive.ai/ai-tools/claude/
- https://claudefa.st/blog/guide/changelog

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official release documentation)
**Frequency validation**: 100% (all patterns from official releases)
**Next quarterly update**: 2026-05-16 (Q2 2026 features)
