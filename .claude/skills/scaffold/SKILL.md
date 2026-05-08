---
name: scaffold
description: Generate new Claude Code plugin components from templates. Creates properly-structured agents, skills, hooks, rules, patterns, CLAUDE.md, and copilot-instructions files.
allowed-tools: Read, Write, Edit, Glob, Grep
user-invocable: true
---

<!-- TODO: source — LENS-Common plugins/LENS/Common/Project Patterns/lens-scaffold v1.0.0 (2026-02-20); refresh after upstream changes -->

# Scaffold Skill

Generate new Claude Code plugin components from templates with proper structure and conventions.

## Usage

```
/scaffold                          # Interactive: ask what to create
/scaffold pattern <name>           # Create new pattern rule
/scaffold agent <name>             # Create new agent definition
/scaffold skill <name>             # Create new skill definition
/scaffold hook <name>              # Create new hook script
/scaffold rule <name>              # Create new rule file
/scaffold claude-md                # Create project CLAUDE.md
/scaffold copilot-instructions     # Create .github/copilot-instructions.md
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `component-type` | No | What to scaffold: `pattern`, `agent`, `skill`, `hook`, `rule`, `claude-md`, `copilot-instructions` |
| `name` | No | Component name (required for pattern/agent/skill/hook/rule) |

## Component Types

| Type | Description | Output Location |
|------|-------------|-----------------|
| `pattern` | Technology-specific coding patterns | `.claude/rules/patterns/<name>.md` |
| `agent` | Agent definition with role and tools | `.claude/agents/<name>.md` |
| `skill` | Skill definition with slash command | `.claude/skills/<name>/SKILL.md` |
| `hook` | Hook script with event handler | `.claude/hooks/<name>.js` + `hooks.json` |
| `rule` | Rule file (path-scoped or always-loaded) | `.claude/rules/<name>.md` |
| `claude-md` | Project-level instructions | `CLAUDE.md` |
| `copilot-instructions` | GitHub Copilot instructions | `.github/copilot-instructions.md` |

## Execution Flow

### 1. Determine Component Type

Parse `$ARGUMENTS` to extract component type and name:

```
/scaffold                    → Interactive mode
/scaffold pattern dotnet-foo → pattern, name="dotnet-foo"
/scaffold agent researcher   → agent, name="researcher"
/scaffold claude-md          → claude-md, no name needed
```

If no arguments provided, ask the user what they want to create.

### 2. Gather Context

For each component type, gather context via targeted questions:

#### Pattern
- **Technology**: What technology? (e.g., dotnet, typescript, react)
- **Topic**: What aspect? (e.g., testing, error-handling, api-design)
- **Paths**: Which file patterns should trigger this? (e.g., `**/*.cs`, `src/**/*.tsx`)
- **Guidance**: What are the key rules/conventions?
- **Examples**: Provide good and bad examples

#### Agent
- **Role**: What is the agent's primary responsibility?
- **Specialization**: What domain/task does it specialize in?
- **Model**: Which model? (opus for complex reasoning, sonnet for implementation, haiku for cleanup)
- **Tools**: Which tools needed? (Read/Grep/Glob for read-only, add Write/Edit/Bash for full access)
- **Do/Don't**: What should it do vs avoid?

#### Skill
- **Purpose**: What task does this skill automate?
- **Command**: What slash command name? (lowercase, hyphens)
- **Parameters**: What parameters/flags does it accept?
- **Workflow**: What are the execution steps?
- **Tools**: Which tools are needed?

#### Hook
- **Event**: Which event? (PreToolUse, PostToolUse, PermissionRequest, UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStop, PreCompact, Notification)
- **Matcher**: What to match? (tool name, regex pattern, or none for session events)
- **Action**: What should the hook do?
- **Timeout**: How long can it run? (default 30000ms)

#### Rule
- **Type**: Path-scoped or always-loaded?
- **Paths**: If path-scoped, which file patterns?
- **Topic**: What does this rule govern?
- **Enforcement**: What's the severity model? (REJECT/WARN/INFO)

#### CLAUDE.md
Scan the project to auto-detect:
- **Tech stack**: Look for `.csproj`, `package.json`, `requirements.txt`
- **Directory structure**: Key directories (src, tests, docs)
- **Build/test commands**: Scripts in `package.json`, project scripts
- **Conventions**: Check for existing patterns in `.claude/rules/`

#### Copilot Instructions
Scan the project to auto-detect:
- **Coding conventions**: Check existing code for naming, structure
- **Testing patterns**: Check test directories for patterns
- **Architecture**: Check for layers, modules, patterns
- **Build/deploy**: Check for CI/CD configs

### 3. Read Template

Read the appropriate template from the plugin's `templates/` directory:

| Component | Template File |
|-----------|---------------|
| pattern | `pattern-rule.md` |
| agent | `agent-definition.md` |
| skill | `skill-definition.md` |
| hook | `hook-template.js` |
| rule | `rule-definition.md` |
| claude-md | `claude-md.md` |
| copilot-instructions | `copilot-instructions.md` |

Templates use placeholder syntax: `{{PLACEHOLDER_NAME}}`

### 4. Replace Placeholders

Replace all `{{...}}` placeholders with gathered context:

#### Common Placeholders
- `{{NAME}}` - Component name (lowercase-hyphenated)
- `{{NAME_UPPER}}` - Component name (UPPERCASE)
- `{{NAME_PASCAL}}` - Component name (PascalCase)
- `{{DESCRIPTION}}` - Brief description
- `{{DATE}}` - Today's date (YYYY-MM-DD)

#### Component-Specific Placeholders

**Pattern**:
- `{{TECHNOLOGY}}` - Technology name
- `{{TOPIC}}` - Topic/aspect
- `{{PATHS}}` - YAML array of file patterns
- `{{RULES}}` - Rule content
- `{{EXAMPLES_GOOD}}` - Good examples
- `{{EXAMPLES_BAD}}` - Bad examples

**Agent**:
- `{{ROLE}}` - Agent role/responsibility
- `{{MODEL}}` - Recommended model
- `{{TOOLS}}` - Comma-separated tool list
- `{{DO_TABLE}}` - What agent should do
- `{{DONT_TABLE}}` - What agent should avoid

**Skill**:
- `{{COMMAND}}` - Slash command name
- `{{PARAMETERS}}` - Parameter table
- `{{WORKFLOW}}` - Numbered execution steps
- `{{TOOLS}}` - Comma-separated tool list

**Hook**:
- `{{EVENT}}` - Hook event name
- `{{MATCHER}}` - Matcher pattern (or "N/A" for session events)
- `{{ACTION_CODE}}` - JavaScript action logic
- `{{TIMEOUT}}` - Timeout in milliseconds

**Rule**:
- `{{SCOPE}}` - "Path-scoped" or "Always-loaded"
- `{{PATHS}}` - YAML paths array (if path-scoped)
- `{{TOPIC}}` - Rule topic
- `{{ENFORCEMENT_TABLE}}` - Severity table

### 5. Write Component

Write the generated content to the appropriate location:

```
Pattern:   .claude/rules/patterns/{name}.md
Agent:     .claude/agents/{name}.md
Skill:     .claude/skills/{name}/SKILL.md
Hook:      .claude/hooks/{name}.js
Rule:      .claude/rules/{name}.md
CLAUDE.md: CLAUDE.md
Copilot:   .github/copilot-instructions.md
```

**Special handling for hooks**:
1. Write hook script to `.claude/hooks/{name}.js`
2. Read existing `.claude/hooks/hooks.json`
3. Add hook registration entry
4. Write updated `hooks.json`

### 6. Verify Generated Output

After writing, perform validation:

#### All Markdown Files
- YAML frontmatter is valid (if present)
- No placeholder markers remain (`{{...}}`)
- File follows naming conventions
- File exists at expected path

#### Hook Scripts
- JavaScript is syntactically valid
- Has stdin/stdout handling
- Has error handling (fail-closed)
- Has feature flag pattern
- Registered in `hooks.json`

#### CLAUDE.md / Copilot
- No secrets or credentials
- Commands are accurate
- Imports reference existing files (if `@path` syntax used)

### 7. Post-Generation Guidance

Tell the user:

#### What was created
```
Created {component-type}: {path}
```

#### How to customize
- **Pattern**: Add more examples, refine path matchers
- **Agent**: Adjust model, fine-tune tools, expand Do/Don't
- **Skill**: Add more parameters, refine workflow steps
- **Hook**: Test with sample input, adjust timeout
- **Rule**: Add enforcement details, refine paths

#### How to test
- **Pattern**: Edit a file matching the paths to verify it loads
- **Agent**: Spawn the agent with a test prompt
- **Skill**: Run the slash command (e.g., `/my-skill`)
- **Hook**: Use the hook testing feature (e.g., `hooks.json` with `test: true`)
- **Rule**: Read the file to verify it loads
- **CLAUDE.md**: Start new session and verify instructions apply
- **Copilot**: Open Copilot chat and ask for code suggestions

#### Next steps
- Run `/config-lint {component-type}` to validate structure
- Add to version control
- Update documentation index (e.g., `.claude/skills/README.md`)

## Component Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Pattern | `{technology}-{topic}.md` | `dotnet-testing.md`, `react-hooks.md` |
| Agent | `{role}-{specialization}.md` | `code-investigator.md`, `research-scout.md` |
| Skill | `{verb}-{noun}` or descriptive | `git-commit`, `config-lint`, `scaffold` |
| Hook | `{action}-{target}.js` | `validate-quality-gates.js`, `detect-anomaly.js` |
| Rule | `{topic}.md` | `quality-gates.md`, `git-workflow.md` |

## Template Placeholder Reference

### Common
```
{{NAME}}            - Component name (lowercase-hyphenated)
{{NAME_UPPER}}      - Component name (UPPERCASE_UNDERSCORED)
{{NAME_PASCAL}}     - Component name (PascalCase)
{{DESCRIPTION}}     - Brief description
{{DATE}}            - ISO date (YYYY-MM-DD)
{{VERSION}}         - Version number (default: 1.0.0)
```

### Pattern-Specific
```
{{TECHNOLOGY}}      - Technology name (dotnet, typescript, etc.)
{{TOPIC}}           - Topic/aspect (testing, error-handling, etc.)
{{PATHS}}           - YAML array of file patterns
{{RULES}}           - Rule/convention content
{{EXAMPLES_GOOD}}   - Good code examples
{{EXAMPLES_BAD}}    - Bad code examples (anti-patterns)
{{REFERENCES}}      - External documentation links
```

### Agent-Specific
```
{{ROLE}}            - Primary responsibility
{{MODEL}}           - Recommended model (opus/sonnet/haiku)
{{TOOLS}}           - Comma-separated tool list
{{DO_TABLE}}        - What to do (markdown table)
{{DONT_TABLE}}      - What not to do (markdown table)
{{OUTPUT_FORMAT}}   - Expected output format
```

### Skill-Specific
```
{{COMMAND}}         - Slash command name
{{PARAMETERS}}      - Parameter table (markdown)
{{WORKFLOW}}        - Numbered workflow steps
{{TOOLS}}           - Comma-separated allowed tools
{{EXAMPLES}}        - Usage examples
{{ERROR_TABLE}}     - Error handling table
```

### Hook-Specific
```
{{EVENT}}           - Hook event name
{{MATCHER}}         - Matcher pattern/tool name
{{ACTION_CODE}}     - JavaScript action logic
{{TIMEOUT}}         - Timeout (milliseconds)
{{FEATURE_FLAG}}    - Feature flag name (auto-generated)
```

### Rule-Specific
```
{{SCOPE}}           - "Path-scoped" or "Always-loaded"
{{PATHS}}           - YAML paths array (if path-scoped)
{{TOPIC}}           - Rule topic/subject
{{ENFORCEMENT_TABLE}} - Severity/enforcement table
{{EXAMPLES}}        - Rule examples
```

## Safety Rules

- NEVER overwrite existing files without confirmation
- ALWAYS validate generated output before writing
- ALWAYS use absolute paths for file operations
- ALWAYS verify templates exist before reading
- NEVER include secrets or credentials in generated files
- NEVER create components outside `.claude/`, `.github/`, or project root

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Template not found | Plugin templates/ directory missing | Verify plugin installation |
| Invalid component type | Unknown type in command | Use valid type: pattern/agent/skill/hook/rule/claude-md/copilot-instructions |
| Missing required context | User didn't provide needed info | Re-prompt for missing context |
| File already exists | Component with same name exists | Ask user to confirm overwrite or choose different name |
| Invalid placeholder | Template has unknown `{{VAR}}` | Report to plugin maintainer (template bug) |
| Hooks.json update failed | JSON parse error or write failure | Manually add hook to hooks.json |

## Output

After successful scaffolding:

```markdown
## Scaffold Complete

**Component**: {type}
**Location**: {absolute-path}
**Status**: Created

### Next Steps

1. Customize the generated file:
   - {customization guidance}

2. Test the component:
   - {testing instructions}

3. Validate structure:
   - Run: /config-lint {type}

4. Add to version control:
   - git add {path}
```

## Integration

This skill is used by:
- Developers creating new plugin components
- Plugin authors scaffolding initial structure
- Teams standardizing configuration across projects

## Notes

- Templates are read from the plugin's `templates/` directory
- All generated files follow official Anthropic and GitHub best practices
- Hook scripts include feature flag pattern for easy enable/disable
- Pattern files use path-scoped loading for efficiency
- CLAUDE.md generation scans project for auto-detection
- Copilot instructions generation analyzes existing code patterns
