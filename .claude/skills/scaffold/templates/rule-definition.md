---
# Optional: Path-scoped rules (delete this section if rule applies globally)
paths:
  - "{{PATH_PATTERN_1}}"
  - "{{PATH_PATTERN_2}}"
# Examples:
#   - "**/*.cs"
#   - "src/**/*.ts"
#   - "tests/**/*"
---

# {{RULE_TITLE}}

{{RULE_PURPOSE}}

## Rules

| You MUST | You MUST NOT |
|----------|--------------|
| {{MUST_DO_1}} | {{MUST_NOT_1}} |
| {{MUST_DO_2}} | {{MUST_NOT_2}} |
| {{MUST_DO_3}} | {{MUST_NOT_3}} |
| {{MUST_DO_4}} | {{MUST_NOT_4}} |

## Enforcement Level

**{{ENFORCEMENT_LEVEL}}**

| Level | Meaning |
|-------|---------|
| REJECT | Hard failure - operation blocked |
| WARN | Soft warning - operation proceeds |
| INFO | Informational - no action required |

This rule is enforced at level **{{ENFORCEMENT_LEVEL}}**.

## When This Rule Applies

{{WHEN_RULE_APPLIES}}

## Configuration

Set in `.claude/settings.local.json` under `env`:

```json
{
  "env": {
    "{{CONFIG_FLAG_1}}": "{{CONFIG_VALUE_1}}",
    "{{CONFIG_FLAG_2}}": "{{CONFIG_VALUE_2}}"
  }
}
```

**Configuration Options**:

| Variable | Default | Description |
|----------|---------|-------------|
| `{{CONFIG_FLAG_1}}` | `{{CONFIG_VALUE_1}}` | {{CONFIG_DESCRIPTION_1}} |
| `{{CONFIG_FLAG_2}}` | `{{CONFIG_VALUE_2}}` | {{CONFIG_DESCRIPTION_2}} |

Set any option to `"false"` or `"0"` to disable.

## Examples

### Example 1: {{EXAMPLE_1_NAME}}

**Correct**:
```{{LANGUAGE}}
{{EXAMPLE_1_CORRECT}}
```

**Incorrect**:
```{{LANGUAGE}}
{{EXAMPLE_1_INCORRECT}}
```

**Why**: {{EXAMPLE_1_REASON}}

### Example 2: {{EXAMPLE_2_NAME}}

**Correct**:
```{{LANGUAGE}}
{{EXAMPLE_2_CORRECT}}
```

**Incorrect**:
```{{LANGUAGE}}
{{EXAMPLE_2_INCORRECT}}
```

**Why**: {{EXAMPLE_2_REASON}}

### Example 3: {{EXAMPLE_3_NAME}}

**Correct**:
```{{LANGUAGE}}
{{EXAMPLE_3_CORRECT}}
```

**Incorrect**:
```{{LANGUAGE}}
{{EXAMPLE_3_INCORRECT}}
```

**Why**: {{EXAMPLE_3_REASON}}

## Integration with Quality Gates

This rule integrates with:

- [ ] **Build Gate**: {{BUILD_GATE_INTEGRATION}}
- [ ] **Test Gate**: {{TEST_GATE_INTEGRATION}}
- [ ] **Lint Gate**: {{LINT_GATE_INTEGRATION}}
- [ ] **Pre-commit Hook**: {{PRECOMMIT_INTEGRATION}}

**Gate Command**:
```bash
{{GATE_COMMAND}}
```

## Exceptions

Exceptions to this rule are allowed when:

1. {{EXCEPTION_1}}
2. {{EXCEPTION_2}}
3. {{EXCEPTION_3}}

In these cases, document the exception in a comment:

```{{LANGUAGE}}
// EXCEPTION: {{EXCEPTION_COMMENT_EXAMPLE}}
{{EXCEPTION_CODE_EXAMPLE}}
```

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| {{ANTI_PATTERN_1}} | {{ANTI_PROBLEM_1}} | {{ANTI_FIX_1}} |
| {{ANTI_PATTERN_2}} | {{ANTI_PROBLEM_2}} | {{ANTI_FIX_2}} |
| {{ANTI_PATTERN_3}} | {{ANTI_PROBLEM_3}} | {{ANTI_FIX_3}} |

## See Also

- [{{RELATED_RULE_1}}]({{RELATED_RULE_1_PATH}})
- [{{RELATED_RULE_2}}]({{RELATED_RULE_2_PATH}})
- [{{EXTERNAL_DOC_1}}]({{EXTERNAL_DOC_1_URL}})

---

## Fill Instructions

Replace ALL placeholders in `{{DOUBLE_BRACES}}`:

### YAML Frontmatter (optional)
1. **PATH_PATTERN_1, PATH_PATTERN_2**: Glob patterns for path-scoped rules (or delete section)

### Main Content
2. **RULE_TITLE**: Descriptive title (e.g., "Quality Gates", "Test Discipline")
3. **RULE_PURPOSE**: 1-2 sentence explanation of why this rule exists
4. Fill 4 MUST/MUST NOT pairs
5. **ENFORCEMENT_LEVEL**: REJECT, WARN, or INFO
6. **WHEN_RULE_APPLIES**: Description of when this rule is checked
7. **CONFIG_FLAG_1, CONFIG_FLAG_2**: Environment variable names
8. **CONFIG_VALUE_1, CONFIG_VALUE_2**: Default values
9. **CONFIG_DESCRIPTION_1, CONFIG_DESCRIPTION_2**: What each flag does
10. Fill 3 examples with correct/incorrect code and reasons
11. **LANGUAGE**: Code block language (csharp, typescript, bash, etc.)
12. **BUILD_GATE_INTEGRATION**: How this integrates with build gate
13. **TEST_GATE_INTEGRATION**: How this integrates with test gate
14. **LINT_GATE_INTEGRATION**: How this integrates with lint gate
15. **PRECOMMIT_INTEGRATION**: How this integrates with pre-commit hooks
16. **GATE_COMMAND**: Command to run the gate
17. Fill 3 exception scenarios
18. **EXCEPTION_COMMENT_EXAMPLE**: Example comment for documenting exceptions
19. **EXCEPTION_CODE_EXAMPLE**: Example code for exception case
20. Fill 3 anti-patterns with problems and fixes
21. **RELATED_RULE_1, RELATED_RULE_2**: Related rule names and paths
22. **EXTERNAL_DOC_1**: External documentation title and URL
23. Delete this "Fill Instructions" section when done

### Example Values
- RULE_TITLE: Test Discipline
- RULE_PURPOSE: Ensure TDD workflow and test quality
- ENFORCEMENT_LEVEL: WARN
- WHEN_RULE_APPLIES: During code implementation and commit
- CONFIG_FLAG_1: TDD_ADVISORY_ENABLED
- CONFIG_VALUE_1: true
- LANGUAGE: csharp
- EXAMPLE_1_NAME: TDD Red-Green-Refactor
- EXCEPTION_1: Fixing typos in comments
