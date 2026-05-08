---
name: {{AGENT_NAME}}
version: 1.0.0
tags: [{{TAG_1}}, {{TAG_2}}, {{TAG_3}}]
category: {{CATEGORY}}
model: {{MODEL}}
model_rationale: {{MODEL_RATIONALE}}
estimated_tokens: {{ESTIMATED_TOKENS}}
description: "{{AGENT_DESCRIPTION}}

Examples:

<example>
Context: {{EXAMPLE_1_CONTEXT}}
user: \"{{EXAMPLE_1_USER_PROMPT}}\"
assistant: \"{{EXAMPLE_1_ASSISTANT_RESPONSE}}\"
<Task tool invocation to {{AGENT_NAME}} agent>
Agent returns: {{EXAMPLE_1_RESULT}}
</example>

<example>
Context: {{EXAMPLE_2_CONTEXT}}
assistant: \"{{EXAMPLE_2_ASSISTANT_RESPONSE}}\"
<Task tool invocation to {{AGENT_NAME}} agent>
Agent returns: {{EXAMPLE_2_RESULT}}
</example>"
tools: [{{TOOL_1}}, {{TOOL_2}}, {{TOOL_3}}]
constraint: {{CONSTRAINT}}
color: {{COLOR}}
---

# {{AGENT_DISPLAY_NAME}}

{{AGENT_ROLE_DESCRIPTION}}

## Pipeline Role

```
{{UPSTREAM_AGENT}} → YOU → {{DOWNSTREAM_AGENT}}
   {{UPSTREAM_ACTION}}       {{YOUR_ACTION}}      {{DOWNSTREAM_ACTION}}
```

## Responsibilities

| Do | Don't |
|----|-------|
| {{RESPONSIBILITY_DO_1}} | {{RESPONSIBILITY_DONT_1}} |
| {{RESPONSIBILITY_DO_2}} | {{RESPONSIBILITY_DONT_2}} |
| {{RESPONSIBILITY_DO_3}} | {{RESPONSIBILITY_DONT_3}} |
| {{RESPONSIBILITY_DO_4}} | {{RESPONSIBILITY_DONT_4}} |

## Workflow

1. **{{STEP_1_NAME}}** - {{STEP_1_DESCRIPTION}}
2. **{{STEP_2_NAME}}** - {{STEP_2_DESCRIPTION}}
3. **{{STEP_3_NAME}}** - {{STEP_3_DESCRIPTION}}
4. **{{STEP_4_NAME}}** - {{STEP_4_DESCRIPTION}}

## Report Format

```markdown
# {{REPORT_TITLE}}: [Topic]

**Date**: [YYYY-MM-DD]
**Scope**: {{REPORT_SCOPE_DESCRIPTION}}

## {{REPORT_SECTION_1}}
{{REPORT_SECTION_1_DESCRIPTION}}

## {{REPORT_SECTION_2}}
{{REPORT_SECTION_2_DESCRIPTION}}

## {{REPORT_SECTION_3}}
{{REPORT_SECTION_3_DESCRIPTION}}

## {{REPORT_SECTION_4}}
{{REPORT_SECTION_4_DESCRIPTION}}
```

## Output Location

| Output Location |
|-----------------|
| `{{OUTPUT_PATH}}` |

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| {{ANTI_PATTERN_1}} | {{ANTI_PATTERN_1_FIX}} |
| {{ANTI_PATTERN_2}} | {{ANTI_PATTERN_2_FIX}} |
| {{ANTI_PATTERN_3}} | {{ANTI_PATTERN_3_FIX}} |

---

## Fill Instructions

Replace ALL placeholders in `{{DOUBLE_BRACES}}`:

### YAML Frontmatter
1. **AGENT_NAME**: Lowercase kebab-case name (e.g., code-investigator)
2. **TAG_1, TAG_2, TAG_3**: Descriptive tags (e.g., read-only, analysis, tdd)
3. **CATEGORY**: core-workflow, specialized, utility
4. **MODEL**: opus, sonnet, haiku
5. **MODEL_RATIONALE**: Why this model? (1 sentence)
6. **ESTIMATED_TOKENS**: Rough token budget (e.g., 20000)
7. **AGENT_DESCRIPTION**: Brief description (1-2 sentences)
8. **EXAMPLE_1_CONTEXT**: Context for first example
9. **EXAMPLE_1_USER_PROMPT**: User prompt text
10. **EXAMPLE_1_ASSISTANT_RESPONSE**: Assistant response text
11. **EXAMPLE_1_RESULT**: What the agent returns
12. Fill second example similarly
13. **TOOL_1, TOOL_2, TOOL_3**: Tools allowed (Read, Write, Edit, Bash, Grep, Glob)
14. **CONSTRAINT**: read-only, full-access, or specific constraints
15. **COLOR**: blue, green, yellow, red (for UI differentiation)

### Main Content
16. **AGENT_DISPLAY_NAME**: Human-readable name (e.g., "Code Investigator Agent")
17. **AGENT_ROLE_DESCRIPTION**: 1-2 sentence role summary
18. **UPSTREAM_AGENT**: Who sends work to this agent
19. **DOWNSTREAM_AGENT**: Who receives output from this agent
20. **UPSTREAM_ACTION**: What upstream does
21. **YOUR_ACTION**: What this agent does
22. **DOWNSTREAM_ACTION**: What downstream does
23. Fill 4 Do/Don't responsibility pairs
24. Fill 4 workflow steps with names and descriptions
25. **REPORT_TITLE**: Title pattern for reports
26. **REPORT_SCOPE_DESCRIPTION**: What the scope should describe
27. Fill 4 report sections with names and descriptions
28. **OUTPUT_PATH**: Where reports go (e.g., .claude/scratch/agent-name-<date>.md)
29. Fill 3 anti-patterns with fixes
30. Delete this "Fill Instructions" section when done

### Example Values
- name: test-selector
- tags: [testing, selection, optimization]
- category: specialized
- model: sonnet
- model_rationale: File diff analysis is pattern matching, not complex reasoning
- estimated_tokens: 5000
- tools: [Read, Grep, Glob, Bash]
- constraint: read-only with test execution
- color: yellow
