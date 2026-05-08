# Skill Packaging Standard

Standardized format for packaging and distributing Claude Code skills.

---

## Overview

This document defines the official packaging standard for Claude Code skills. Following this standard ensures:
- Consistent structure across all skills
- Easy discovery and installation
- Proper dependency management
- Version compatibility

---

## Directory Structure

A skill package MUST follow this structure:

```
<skill-name>/
├── SKILL.md          # Required: Skill definition
├── README.md         # Optional: User documentation
├── CHANGELOG.md      # Optional: Version history
├── examples/         # Optional: Usage examples
│   └── example-1.md
├── tests/            # Optional: Skill tests
│   └── test-spec.md
└── assets/           # Optional: Supporting files
    └── templates/
```

---

## Required File: SKILL.md

### YAML Frontmatter (Required)

```yaml
---
# Required Fields
name: skill-name                    # Unique identifier (kebab-case)
description: Brief description      # One-line summary (max 100 chars)
version: 1.0.0                      # Semantic version (required)

# Recommended Fields
user_invocable: true|false          # Can users invoke via /skill-name?
author: author-name                 # Creator or organization
license: MIT                        # SPDX license identifier
allowed-tools:                      # Tools the skill can use
  - Read
  - Write
  - Bash
changelog:                          # Version history
  - version: 1.0.0
    date: 2026-01-01
    changes:
      - Initial release

# Optional Fields
tags: [tag1, tag2]                  # Discovery tags
category: workflow                  # Category for organization
requires:                           # Dependencies
  - skill: memory
    version: ">=1.0.0"
model: sonnet                       # Preferred model (opus|sonnet|haiku)
min_context_tokens: 5000            # Minimum context needed
---
```

### Body Content (Required)

The SKILL.md body MUST include:

1. **Title** (H1): `# <Skill Name> Skill`
2. **Usage Section**: How to invoke the skill
3. **Behavior Section**: What the skill does step-by-step
4. **Examples**: At least one usage example

---

## Field Specifications

### name (Required)
- Format: `kebab-case`
- Length: 2-50 characters
- Characters: lowercase letters, numbers, hyphens
- Must not start/end with hyphen
- Must be unique within registry

### version (Required)
- Format: Semantic versioning (MAJOR.MINOR.PATCH)
- Examples: `1.0.0`, `2.1.3`, `0.1.0-beta`

### description (Required)
- Format: Plain text, single sentence
- Length: 10-100 characters
- Should be imperative voice ("Create...", "Validate...", "Generate...")

### allowed-tools (Recommended)
Valid tool names:
- `Read` - Read files
- `Write` - Create files
- `Edit` - Modify files
- `Bash` - Execute commands
- `Glob` - Find files by pattern
- `Grep` - Search file contents
- `WebFetch` - HTTP requests
- `WebSearch` - Web searches
- `Task` - Spawn subagents
- `TodoWrite` - Task management
- `NotebookEdit` - Jupyter notebooks
- `AskUserQuestion` - User prompts
- `KillShell` - Terminate processes
- `TaskOutput` - Agent output

### requires (Optional)
Dependency format:
```yaml
requires:
  - skill: dependency-name
    version: ">=1.0.0"      # Semver range
  - agent: code-investigator
    version: ">=1.0.0"
```

---

## Validation Rules

### MUST (Required)
- [ ] SKILL.md exists at package root
- [ ] name field is unique and valid format
- [ ] version field is valid semver
- [ ] description field is present
- [ ] Body includes Usage section

### SHOULD (Recommended)
- [ ] Has at least one tag
- [ ] Has allowed-tools if skill uses tools
- [ ] Has changelog with at least initial entry
- [ ] Has examples in body or examples/ directory
- [ ] Description explains WHAT and WHEN to use

### MAY (Optional)
- [ ] Has README.md for detailed documentation
- [ ] Has tests/ directory with test specifications
- [ ] Has assets/ for templates or supporting files

---

## Versioning Guidelines

### MAJOR version (X.0.0)
Increment for:
- Breaking changes to invocation syntax
- Removing features
- Changing default behavior

### MINOR version (0.X.0)
Increment for:
- New features
- New optional parameters
- Backward-compatible changes

### PATCH version (0.0.X)
Increment for:
- Bug fixes
- Documentation updates
- Performance improvements

---

## Publishing Checklist

Before publishing a skill:

- [ ] Follows directory structure
- [ ] SKILL.md has all required fields
- [ ] Version is updated
- [ ] Changelog reflects changes
- [ ] No hardcoded paths (use relative)
- [ ] No secrets or credentials
- [ ] Tested locally
- [ ] README.md describes usage (if complex)

---

## Examples

### Minimal Valid Skill

```yaml
---
name: hello-world
description: Print a greeting message
version: 1.0.0
---

# Hello World Skill

## Usage

/hello-world [name]

## Behavior

1. Accept optional name parameter
2. Output greeting: "Hello, {name}!"
3. Default name is "World"

## Examples

/hello-world
Output: Hello, World!

/hello-world Claude
Output: Hello, Claude!
```

### Full-Featured Skill

```yaml
---
name: code-quality-check
description: Run comprehensive code quality analysis
version: 2.1.0
user_invocable: true
author: team-devops
license: MIT
tags: [quality, lint, testing, ci]
category: code-quality
allowed-tools:
  - Read
  - Bash
  - Glob
requires:
  - skill: test-runner
    version: ">=1.0.0"
model: sonnet
changelog:
  - version: 2.1.0
    date: 2026-02-01
    changes:
      - Added TypeScript support
      - Fixed false positives in lint rules
  - version: 2.0.0
    date: 2026-01-15
    changes:
      - Breaking: Changed output format to JSON
  - version: 1.0.0
    date: 2026-01-01
    changes:
      - Initial release
---

# Code Quality Check Skill

Comprehensive code quality analysis for projects.

## Usage

/code-quality-check                    # Check all files
/code-quality-check src/               # Check specific directory
/code-quality-check --fix              # Auto-fix issues
/code-quality-check --format json      # Output as JSON

## Behavior

1. Detect project type (Node.js, Python, .NET, etc.)
2. Run appropriate linters
3. Check test coverage
4. Validate dependencies
5. Generate report

## Examples

See examples/ directory for detailed usage scenarios.
```

---

## Skill Categories

Skills are organized into categories for discovery:

| Category | Description | Examples |
|----------|-------------|----------|
| `workflow` | Development workflow automation | mad-spec, mad-plan, mad-tasks |
| `code-quality` | Linting, testing, review | skill-lint, code-reviewer |
| `documentation` | Docs generation and maintenance | documentation-engineer |
| `git` | Version control operations | git-commit, pr-review |
| `utility` | General-purpose helpers | memory, context-sync |
| `analysis` | Code investigation and research | session-improve |

---

## Tech-Agnostic Requirement

Skills MUST remain portable across projects. Avoid:

| Pattern | Problem | Alternative |
|---------|---------|-------------|
| `npm run test` | Project-specific | "run project test commands" |
| `frontend/src/` | Project-specific path | "see project CLAUDE.md" |
| `React`, `Express` | Technology-specific | Generic description |
| `localhost:3001` | Project-specific port | "see project configuration" |

### Correct Pattern

```markdown
## Verification

Run project test commands as specified in CLAUDE.md.
Consult directory-specific CLAUDE.md for implementation patterns.
```

---

## Registry Integration

Skills following this standard can be:

1. **Listed** via `/registry-list`
2. **Installed** via `/registry-install`
3. **Synced** via `/registry-sync`

### Installation Sources

| Source | Command |
|--------|---------|
| Local | `/registry-install ./path/to/skill` |
| GitHub | `/registry-install github:user/repo/skill-name` |
| Registry | `/registry-install skill-name` |

---

## Related

- `/registry-list` - View installed skills
- `/registry-install` - Install skills
- `/skill-lint` - Validate skill packages
- `.claude/skills/README.md` - Skills index
