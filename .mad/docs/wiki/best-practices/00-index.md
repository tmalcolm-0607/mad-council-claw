# Best Practices Index

Last updated: 2026-02-18

## Overview

This directory contains consolidated best practices for Claude Code, AI-assisted development, and workflow patterns. Each category is researched quarterly from official Anthropic documentation and high-quality community sources.

## Categories

| Category | Files | Last Updated | Status | Next Refresh |
|----------|-------|--------------|--------|--------------|
| **01-claude-code-features** | 6 | 2026-02-18 | ✓ Current | 2026-05-16 |
| **02-orchestration-patterns** | 4 | 2026-02-16 | ✓ Current | 2026-05-16 |
| **03-workflow-patterns** | 4 | 2026-02-18 | ✓ Current | 2026-05-16 |
| **04-ai-llm-patterns** | 4 | 2026-02-18 | ✓ Current | 2026-05-16 |
| **05-integration-patterns** | 3 | 2026-02-16 | ✓ Current | 2026-05-16 |
| **06-emerging-patterns** | 3 | 2026-02-18 | ✓ Current | 2026-05-16 |

**Total**: 24 category files

## Category Details

### 01-claude-code-features

Core Claude Code capabilities and APIs.

| File | Description |
|------|-------------|
| `skills-2026.md` | Skill creation, registration, invocation patterns |
| `agents-orchestration-2026.md` | Agent spawning, lifecycle, communication |
| `hooks-2026.md` | Event-driven automation, hook patterns |
| `mcp-servers-2026.md` | Model Context Protocol server integration |
| `context-management-2026.md` | Context window management, compaction, handoff |
| `task-api-2026.md` | Task tool usage, subagent types, composite agents |

### 02-orchestration-patterns

Multi-agent coordination and workflow orchestration.

| File | Description |
|------|-------------|
| `agent-teams-2026.md` | Team creation, coordination, file ownership |
| `task-coordination-2026.md` | TaskCreate, TaskUpdate, dependencies, DAG execution |
| `handoff-protocol-2026.md` | Session handoff, context preservation, resume protocol |
| `verification-patterns-2026.md` | Feature verification, quality gates, progressive validation |

### 03-workflow-patterns

Development workflow and process patterns.

| File | Description |
|------|-------------|
| `mad-workflow-2026.md` | MAD (spec/plan/tasks/implement/validate) workflow |
| `testing-strategies-2026.md` | Test pyramid, progressive validation, test selection |
| `git-workflow-2026.md` | Branch naming, commit format, worktree usage |
| `quality-gates-2026.md` | Gate execution, profile selection, enforcement rules |

### 04-ai-llm-patterns

AI model interaction and optimization patterns.

| File | Description |
|------|-------------|
| `prompting-2026.md` | Effective prompting, context-driven references, instruction hierarchy |
| `model-selection-2026.md` | Opus/Sonnet/Haiku selection criteria, cost optimization |
| `token-optimization-2026.md` | Context management, artifact patterns, compression strategies |
| `error-recovery-2026.md` | Failure handling, retry logic, graceful degradation |

### 05-integration-patterns

External tool and service integration patterns.

| File | Description |
|------|-------------|
| `git-github-2026.md` | Git operations, GitHub CLI, PR workflows |
| `testing-frameworks-2026.md` | xUnit, Vitest, Playwright integration |
| `ci-cd-2026.md` | Continuous integration, deployment pipelines |

### 06-emerging-patterns

Experimental features and recent changes.

| File | Description |
|------|-------------|
| `whats-new-q1-2026.md` | New features, API changes, tool updates (Q1 2026) |
| `deprecations-2026.md` | Deprecated patterns, migration guides |
| `experimental-features.md` | Beta features, feature flags, opt-in functionality |

## Refresh Schedule

**Frequency**: Quarterly (every 90 days)

**Next scheduled refresh**: 2026-05-16

**Trigger conditions**:
- 90+ days since last update (staleness threshold)
- Major Claude Code version release
- Significant community pattern changes
- Manual invocation via `/refresh-best-practices`

## Confidence Levels

Each category file includes a `confidence` field in its frontmatter:

| Level | Meaning | Source Requirements |
|-------|---------|-------------------|
| **HIGH** | Validated across 3+ authoritative sources, 80%+ frequency | Official docs + 2+ community implementations |
| **MEDIUM** | Found in 2+ sources, 50%+ frequency | Official docs OR 2+ community implementations |
| **LOW** | Emerging pattern, <50% frequency, single source | Experimental or niche pattern |

## Research Sources

### Tier 1 (Official)
- https://docs.anthropic.com/en/docs/claude-code
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/hooks
- https://github.com/anthropics/skills

### Tier 2 (Community)
- https://github.com/wshobson/agents (agent orchestration)
- https://github.com/VoltAgent/awesome-claude-code-subagents (subagent catalog)
- https://github.com/ruvnet/claude-flow (hook patterns)

### Tier 3 (Adjacent)
- OpenAI Agent SDK patterns (cross-platform insights)
- LangChain orchestration patterns
- Swarm multi-agent patterns

## Maintenance

**Primary skill**: `/refresh-best-practices`
- Research latest patterns from Tier 1-3 sources
- Compare against current documentation
- Generate change proposals with confidence levels
- Update category files with user approval
- Append changes to CHANGELOG.md

**Related skill**: `/claude-md-refresh`
- Uses best-practices findings to update CLAUDE.md files
- Detects outdated patterns and deprecated APIs
- Applies evidence-based proposals

## See Also

- `.claude/skills/refresh-best-practices/SKILL.md` - Skill documentation
- `.mad/docs/best-practices/CHANGELOG.md` - Change history
- `CLAUDE.md` - Project-specific guidance
