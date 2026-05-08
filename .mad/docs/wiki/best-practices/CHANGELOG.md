# Changelog

All notable changes to the best-practices documentation are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-02-20

### Added
- Initial creation of `.mad/docs/best-practices/` directory with 6 category files
- `claude-code-features.md`: ~15 patterns covering skills, hooks, MCP, memory, Task API, plugins
- `orchestration-patterns.md`: ~12 patterns covering agent teams, task coordination, handoff
- `workflow-patterns.md`: ~12 patterns covering MAD lifecycle, TDD, git workflow, quality gates
- `ai-llm-patterns.md`: ~10 patterns covering model selection, prompting, token optimization
- `integration-patterns.md`: ~10 patterns covering Git, ADO, testing frameworks, CI/CD
- `emerging-patterns.md`: ~9 patterns covering cross-surface, plugins, new hooks, experimental features
- `README.md` index with staleness metadata and category table
- `CHANGELOG.md` (this file)

### Research
- Sources consulted: code.claude.com (57 pages), anthropics/skills repo, wshobson/agents repo (72 plugins, 153 agents)
- Confidence levels: 90% HIGH, 10% MEDIUM
- Total patterns catalogued: ~68 across 6 categories

### Fixed
- Path references in `refresh-best-practices/SKILL.md`: `.claude/docs/best-practices/` changed to `.mad/docs/best-practices/`
- Path references in `claude-md-refresh/SKILL.md`: `00-index.md` changed to `README.md`, subdirectory paths changed to flat files
- Numbered category prefixes removed (e.g., `01-claude-code-features` changed to `claude-code-features`)
- Added cross-references in `CLAUDE.md` and `patterns-index.md`
