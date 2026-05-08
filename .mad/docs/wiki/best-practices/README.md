# Best Practices Research

Research-backed patterns for Claude Code development, extracted from official Anthropic documentation, the `anthropics/skills` repository, and the `wshobson/agents` community repository. Updated quarterly via the `/refresh-best-practices` skill.

## Scope

This directory contains **platform and external** best practices -- Claude Code features, orchestration patterns, AI/LLM patterns, and emerging capabilities. For **operational** best practices (MAD workflow procedures, agent spawning templates, session hygiene, troubleshooting), see `.mad/docs/workflow-best-practices.md`.

## Categories

| File | Research Focus | Last Updated | Confidence | Status |
|------|---------------|--------------|------------|--------|
| `claude-code-features.md` | Skills, hooks, MCP, memory, context, Task API, plugins | 2026-02-20 | HIGH | Current |
| `orchestration-patterns.md` | Agent teams, task coordination, handoff, verification | 2026-02-20 | HIGH | Current |
| `workflow-patterns.md` | MAD lifecycle, TDD, git workflow, quality gates | 2026-02-20 | HIGH | Current |
| `ai-llm-patterns.md` | Prompting, model selection, token optimization | 2026-02-20 | HIGH | Current |
| `integration-patterns.md` | Git/GitHub, ADO, testing frameworks, CI/CD | 2026-02-20 | HIGH | Current |
| `emerging-patterns.md` | Cross-surface, plugins, new hooks, experimental | 2026-02-20 | MEDIUM | Current |

## Staleness Metadata

- **Last full refresh**: 2026-02-20
- **Sources checked**: code.claude.com (57 pages), anthropics/skills repo, wshobson/agents repo (72 plugins, 153 agents)
- **Patterns catalogued**: ~68 across 6 categories (~61 new, ~7 changed)
- **Confidence distribution**: 90% HIGH, 10% MEDIUM, 0% LOW
- **Next refresh due**: 2026-05-20 (90-day cycle)

## How to Refresh

```bash
# Full refresh (all stale categories)
/refresh-best-practices

# Force refresh all categories regardless of staleness
/refresh-best-practices --force-full

# Refresh specific category
/refresh-best-practices --category claude-code-features

# Preview changes without applying
/refresh-best-practices --dry-run
```

The `/claude-md-refresh` skill reuses these findings if refreshed within 7 days, avoiding duplicate research.

## See Also

- `.mad/docs/workflow-best-practices.md` -- Operational best practices (orchestration principles, agent spawning, session hygiene)
- `.mad/docs/patterns-index.md` -- Technology-specific pattern rules index
- `.mad/docs/skill-authoring-guide.md` -- Skill development guide
- `.claude/rules/` -- Enforceable rules (non-negotiable, hook-validated)
- `CHANGELOG.md` -- Change history for this directory
