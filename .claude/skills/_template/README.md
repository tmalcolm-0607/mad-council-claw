# Skill Template

Use this template to create new Claude Code skills.

## Quick Start

1. Copy this directory to `.claude/skills/<your-skill-name>/`
2. Rename files and update content
3. Run `/skill-lint <your-skill-name>` to validate
4. Run `/registry-sync` to add to registry

## Files

| File | Required | Purpose |
|------|----------|---------|
| `SKILL.md` | Yes | Skill definition with frontmatter and documentation |
| `README.md` | No | Additional documentation |
| `CHANGELOG.md` | No | Detailed version history |
| `examples/` | No | Usage examples |
| `tests/` | No | Test specifications |

## Checklist

Before publishing:

- [ ] Updated `name` field to unique identifier
- [ ] Updated `description` to reflect purpose
- [ ] Set appropriate `version` (start at 1.0.0)
- [ ] Added relevant `tags`
- [ ] Specified `allowed-tools` if using tools
- [ ] Written clear usage instructions
- [ ] Added at least one example
- [ ] Tested locally

## Naming Conventions

- Use `kebab-case` for skill names
- Keep names short but descriptive
- Avoid generic names (use `git-commit` not `commit`)
- Prefix related skills (use `mad-spec`, `mad-plan`, etc.)

## Directory Structure

```
your-skill-name/
├── SKILL.md           # Required - skill definition
├── README.md          # Optional - detailed documentation
├── CHANGELOG.md       # Optional - version history
├── examples/          # Optional - usage examples
│   └── basic-usage.md
├── tests/             # Optional - test specifications
│   └── test-spec.md
└── assets/            # Optional - supporting files
    └── templates/
```

## Frontmatter Reference

### Required Fields

```yaml
---
name: your-skill-name
description: Brief description of what this skill does
version: 1.0.0
---
```

### Full Example

```yaml
---
name: your-skill-name
description: Brief description of what this skill does
version: 1.0.0
user_invocable: true
author: your-name
license: MIT
tags: [tag1, tag2]
category: utility
allowed-tools:
  - Read
  - Write
  - Bash
requires:
  - skill: dependency-name
    version: ">=1.0.0"
model: sonnet
changelog:
  - version: 1.0.0
    date: 2026-01-01
    changes:
      - Initial release
---
```

## Best Practices

### Description

A good description explains WHAT the skill does and WHEN to use it:

```yaml
# Bad
description: Helps with code

# Good
description: Analyze code for security vulnerabilities. Use when reviewing sensitive code or before deployment.
```

### Tech-Agnostic

Skills should work across different projects. Avoid project-specific paths or commands:

```markdown
# Bad
Run `npm run test` to verify changes.

# Good
Run project test commands as specified in CLAUDE.md.
```

### Examples

Always include at least one usage example:

```markdown
## Examples

/your-skill-name

Output: Description of expected result
```

## Validation

Run `/skill-lint your-skill-name` to validate your skill against:

| Rule | Description |
|------|-------------|
| FRONT-001 | Frontmatter must exist |
| FRONT-002 | `name` field required and valid |
| FRONT-003 | `name` must match directory |
| FRONT-004 | `description` required |
| CONTENT-002 | Must have Usage section |

## See Also

- `.claude/docs/skill-packaging.md` - Full packaging standard
- `/skill-lint` - Validate skill structure
- `/registry-list` - View installed skills
- `/registry-sync` - Sync with registry
