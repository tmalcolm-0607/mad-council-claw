---
name: {{SKILL_NAME}}
description: {{SKILL_DESCRIPTION}}
allowed-tools: {{TOOL_1}}, {{TOOL_2}}, {{TOOL_3}}
version: 1.0.0
changelog:
  - "1.0.0: Initial version"
---

# {{SKILL_DISPLAY_NAME}}

{{SKILL_OVERVIEW}}

## Usage

```
/{{SKILL_COMMAND}}                    # {{USAGE_EXAMPLE_1_DESCRIPTION}}
/{{SKILL_COMMAND}} {{ARG_1}}          # {{USAGE_EXAMPLE_2_DESCRIPTION}}
/{{SKILL_COMMAND}} {{ARG_1}} {{ARG_2}}  # {{USAGE_EXAMPLE_3_DESCRIPTION}}
```

## Overview

{{DETAILED_OVERVIEW}}

## Execution Flow

### 1. {{PHASE_1_NAME}}

{{PHASE_1_DESCRIPTION}}

{{PHASE_1_ACTIONS}}

### 2. {{PHASE_2_NAME}}

{{PHASE_2_DESCRIPTION}}

{{PHASE_2_ACTIONS}}

### 3. {{PHASE_3_NAME}}

{{PHASE_3_DESCRIPTION}}

{{PHASE_3_ACTIONS}}

### 4. {{PHASE_4_NAME}}

{{PHASE_4_DESCRIPTION}}

{{PHASE_4_ACTIONS}}

## Output Artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| {{ARTIFACT_1}} | `{{ARTIFACT_1_PATH}}` | {{ARTIFACT_1_PURPOSE}} |
| {{ARTIFACT_2}} | `{{ARTIFACT_2_PATH}}` | {{ARTIFACT_2_PURPOSE}} |
| {{ARTIFACT_3}} | `{{ARTIFACT_3_PATH}}` | {{ARTIFACT_3_PURPOSE}} |

## Integration Points

**Spawns**: {{SPAWNED_AGENTS}} (if any)

**Reads**:
- `{{READ_FILE_1}}`
- `{{READ_FILE_2}}`

**Writes**:
- `{{WRITE_FILE_1}}`
- `{{WRITE_FILE_2}}`

**Updates**:
- `{{UPDATE_FILE_1}}` ({{UPDATE_DESCRIPTION_1}})

## Success Criteria

- [ ] {{SUCCESS_CRITERION_1}}
- [ ] {{SUCCESS_CRITERION_2}}
- [ ] {{SUCCESS_CRITERION_3}}
- [ ] {{SUCCESS_CRITERION_4}}

## Safety Rules

- {{SAFETY_RULE_1}}
- {{SAFETY_RULE_2}}
- {{SAFETY_RULE_3}}

## Configuration

Set in `.claude/settings.local.json` under `env`:

```json
{
  "env": {
    "{{CONFIG_VAR_1}}": "{{CONFIG_VALUE_1}}",
    "{{CONFIG_VAR_2}}": "{{CONFIG_VALUE_2}}"
  }
}
```

---

## Fill Instructions

Replace ALL placeholders in `{{DOUBLE_BRACES}}`:

### YAML Frontmatter
1. **SKILL_NAME**: Lowercase kebab-case (e.g., git-commit)
2. **SKILL_DESCRIPTION**: One-line description
3. **TOOL_1, TOOL_2, TOOL_3**: Allowed tools (Bash, Read, Write, Grep, Glob, Edit, TodoWrite)

### Main Content
4. **SKILL_DISPLAY_NAME**: Human-readable name (e.g., "Git Commit Skill")
5. **SKILL_OVERVIEW**: 1-2 sentence overview
6. **SKILL_COMMAND**: CLI command (e.g., commit, my-skill)
7. **USAGE_EXAMPLE_1_DESCRIPTION**: What first usage example does
8. **ARG_1, ARG_2**: Argument placeholders or descriptions
9. Fill remaining usage examples
10. **DETAILED_OVERVIEW**: Longer description of what the skill does and why
11. Fill 4 execution phases with names, descriptions, and actions
12. Fill 3 output artifacts with paths and purposes
13. **SPAWNED_AGENTS**: List of agents this skill spawns (or "None")
14. Fill read/write/update file lists
15. Fill 4 success criteria
16. Fill 3 safety rules
17. Fill configuration variables (if applicable, or remove section)
18. Delete this "Fill Instructions" section when done

### Example Values
- name: git-commit
- description: Create well-structured git commits with conventional commit format
- allowed-tools: Bash, Read, Glob, Grep, TodoWrite
- SKILL_DISPLAY_NAME: Git Commit Skill
- SKILL_COMMAND: my-skill
- ARG_1: optional commit message
- PHASE_1_NAME: Gather Context
- ARTIFACT_1: Commit hash, Artifact_1_PATH: N/A (git log), ARTIFACT_1_PURPOSE: Record of changes
- SPAWNED_AGENTS: None
- SUCCESS_CRITERION_1: Commit created successfully
- SAFETY_RULE_1: NEVER amend commits unless explicitly requested
