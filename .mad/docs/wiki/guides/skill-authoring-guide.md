# Skill Authoring Guide

Comprehensive guide for creating and maintaining Claude Code skills with proper frontmatter configuration.

---

## Official Frontmatter Fields

Claude Code skills use YAML frontmatter for metadata and configuration. Use only the official fields documented below.

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | Unique skill identifier (lowercase, hyphens) | `mad-spec` |
| `description` | string | Brief skill purpose (shown in skill list) | `Create feature specifications` |

### Recommended Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `user_invocable` | boolean | Whether skill appears in `/` command list | `true` |
| `allowed-tools` | array | Tools skill may use | `[Read, Write, Bash]` |
| `model` | string | Preferred model (opus, sonnet, haiku) | `sonnet` |
| `context` | string | Context inheritance (`inherit` or `fork`) | `fork` |

### Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `argument-hint` | string | Hint shown when user invokes skill | `<feature-description>` |
| `disable-model-invocation` | boolean | Optimization hint for read-only skills | `true` |
| `agent` | string | Agent type if skill wraps an agent | `code-investigator` |
| `hooks` | object | Event hooks configuration | See Hooks section |

---

## Deprecated Fields (DO NOT USE)

These fields are **not recognized** by Claude Code and should be removed:

| Deprecated Field | Why Deprecated | Migration Path |
|------------------|----------------|----------------|
| `version` | Duplicates CHANGELOG.md | Move to `CHANGELOG.md` (Keep a Changelog format) |
| `changelog` | Duplicates CHANGELOG.md | Extract version history → `CHANGELOG.md` |
| `author` | Not used by Claude Code | Move to `README.md` or remove if generic |
| `license` | Not used by Claude Code | Move to `README.md` or remove if generic |
| `tags` | No official support | Remove (use description instead) |
| `category` | No official support | Remove (use directory structure instead) |

---

## Field Usage Guidelines

### `context: fork` vs `context: inherit`

**Use `context: fork` when**:
- Skill processes large data (>100KB input/output)
- Skill executes parallel operations with verbose output
- Skill expands templates with extensive content
- You want to prevent polluting main conversation context

**Use `context: inherit` (default) when**:
- Skill needs full conversation history
- Skill coordinates with main conversation
- Output is concise and relevant to ongoing work

**Examples**:
```yaml
# Fork context for large data processing
context: fork  # mad-tasks (150KB+ template), mad-validate (4 parallel lenses)

# Inherit context for coordination
context: inherit  # mad-full (orchestrates pipeline)
```

### `disable-model-invocation: true`

**Use for read-only skills/agents** that analyze/discover but never modify code:

**Examples**:
- `mad-checklist` - Generates checklists (read plan.md, output markdown)
- `mad-adr` - Creates ADR files (templates only, no code modification)
- `code-investigator` - Analyzes code (reads files, writes reports)
- `research-scout` - Web research (reads sources, writes findings)

**Do NOT use for**:
- `mad-implement` - Writes code
- `code-implementer` - Modifies files
- `mad-spec` - Writes spec.md

### `model` Selection

| Model | Use For |
|-------|---------|
| `opus` | Complex reasoning, architecture, security (default for most skills) |
| `sonnet` | Implementation, testing, documentation, research |
| `haiku` | Cleanup, formatting, batch operations |

**See**: `.claude/rules/model-selection.md` for comprehensive model selection guidance.

---

## Migration Examples

### Example 1: Remove `version` and `changelog`

**Before** (deprecated):
```yaml
---
name: mad-spec
description: Create feature specifications
version: 2.0.0
changelog:
  - version: 2.0.0
    date: 2026-02-09
    changes:
      - Added Agent Teams support
  - version: 1.0.0
    date: 2024-01-01
    changes:
      - Initial release
---
```

**After** (correct):
```yaml
---
name: mad-spec
description: Create feature specifications
allowed-tools: [Read, Write, Bash]
---
```

**CHANGELOG.md** (extract version history):
```markdown
# Changelog: mad-spec

## [2.0.0] - 2026-02-09
### Added
- Added Agent Teams support

## [1.0.0] - 2024-01-01
### Added
- Initial release
```

### Example 2: Remove `author`, `license`, `tags`, `category`

**Before** (deprecated):
```yaml
---
name: pr-pattern-extract
description: Extract patterns from PR reviews
version: 3.0.0
author: Claude Code
license: MIT
tags: [patterns, pr-review, continuous-improvement]
category: research
---
```

**After** (correct):
```yaml
---
name: pr-pattern-extract
description: Extract patterns from PR reviews
user_invocable: true
context: fork  # Isolate 150KB+ PR comment data
---
```

### Example 3: Add `disable-model-invocation` for read-only

**Before** (missing optimization hint):
```yaml
---
name: code-investigator
description: Deep code analysis agent
allowed-tools: [Read, Grep, Glob]
---
```

**After** (with optimization):
```yaml
---
name: code-investigator
description: Deep code analysis agent
allowed-tools: [Read, Grep, Glob]
disable-model-invocation: true  # Read-only analysis
---
```

---

## Complete Example: Well-Formed Skill

```yaml
---
name: mad-validate
description: Run automated MAD validation tools and fix issues
allowed-tools: [Read, Edit, Write, Bash, Glob, Grep]
user_invocable: true
model: sonnet
context: fork  # Isolate 4 parallel lens outputs
argument-hint: "[--lens <contract|spec-lint|coverage|living-docs>]"
---

# MAD: Validation

Run automated validation suite across 4 lenses...

## Usage

/mad-validate              # Run all lenses
/mad-validate --lens contract    # Run specific lens
```

---

## Directory Structure

```
.claude/skills/my-skill/
├── SKILL.md              # Main skill file with frontmatter
├── CHANGELOG.md          # Version history (Keep a Changelog format)
├── README.md             # Optional: detailed docs, author, license
├── references/           # Optional: extracted content
│   └── patterns.md
└── templates/            # Optional: file templates
    └── output-template.md
```

---

## Versioning Best Practices

### Semantic Versioning

Follow [SemVer](https://semver.org/) for skill versions:

- **MAJOR** (X.0.0): Breaking changes (incompatible API/behavior changes)
- **MINOR** (0.X.0): New features (backward-compatible additions)
- **PATCH** (0.0.X): Bug fixes, documentation (backward-compatible fixes)

### CHANGELOG.md Format

Use [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog: skill-name

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-02-09

### Added
- New feature X
- New feature Y

### Changed
- Modified behavior Z

### Fixed
- Bug fix A

## [1.1.0] - 2026-01-15

### Added
- Initial feature set
```

---

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Using `version` in frontmatter | Not recognized by Claude Code | Move to CHANGELOG.md |
| Using `tags` array | No official support | Use descriptive `description` field |
| Forgetting `user_invocable` | Skill won't appear in `/` list | Add `user_invocable: true` |
| Not using `context: fork` for large data | Pollutes main conversation | Add `context: fork` for >100KB processing |
| Using `model: opus` for all skills | Unnecessary cost | Use `model: sonnet` for most skills |

---

## Testing Your Skill

After creating/modifying a skill:

1. **Syntax validation**: Verify YAML frontmatter parses correctly
2. **Invocation test**: Try invoking the skill: `/my-skill "test input"`
3. **Tool access**: Verify skill can use declared `allowed-tools`
4. **Context isolation**: If using `context: fork`, verify output doesn't pollute main conversation
5. **Model selection**: Verify correct model is used (check logs)

---

## See Also

- `.claude/rules/model-selection.md` - Model selection guidance
- `.claude/docs/agent-teams-guide.md` - Agent Teams integration
- `.claude/skills/mad-teams/SKILL.md` - Team composition templates
- [Claude Code Documentation](https://docs.anthropic.com/claude-code) - Official docs
