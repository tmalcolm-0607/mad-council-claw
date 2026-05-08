# GitHub Copilot Instructions for {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

---

## Project Context

**Technology**: {{PRIMARY_LANGUAGE}} with {{PRIMARY_FRAMEWORK}}
**Architecture**: {{ARCHITECTURE_PATTERN}} (e.g., layered, clean architecture, microservices)
**Database**: {{DATABASE_TECHNOLOGY}}

---

## Code Style Preferences

### Naming Conventions

- **Classes/Interfaces**: {{CLASS_NAMING}} (e.g., PascalCase)
- **Methods**: {{METHOD_NAMING}} (e.g., PascalCase for public, camelCase for private)
- **Variables**: {{VARIABLE_NAMING}} (e.g., camelCase)
- **Constants**: {{CONSTANT_NAMING}} (e.g., UPPER_SNAKE_CASE or PascalCase)
- **Files**: {{FILE_NAMING}} (e.g., match class name, kebab-case)

### Language Features

**Preferred**:
```{{LANGUAGE}}
{{PREFERRED_EXAMPLE_1}}
```

**Avoid**:
```{{LANGUAGE}}
{{AVOID_EXAMPLE_1}}
```

---

## Framework-Specific Guidance

### {{FRAMEWORK_FEATURE_1}} (e.g., Dependency Injection)

```{{LANGUAGE}}
{{FRAMEWORK_EXAMPLE_1}}
```

### {{FRAMEWORK_FEATURE_2}} (e.g., Async/Await)

```{{LANGUAGE}}
{{FRAMEWORK_EXAMPLE_2}}
```

### {{FRAMEWORK_FEATURE_3}} (e.g., Error Handling)

```{{LANGUAGE}}
{{FRAMEWORK_EXAMPLE_3}}
```

---

## Testing Conventions

### Test Naming

```{{LANGUAGE}}
// Pattern: MethodName_WhenCondition_ExpectedBehavior
{{TEST_NAMING_EXAMPLE}}
```

### Test Structure

```{{LANGUAGE}}
// Use Arrange-Act-Assert pattern
{{TEST_STRUCTURE_EXAMPLE}}
```

### Mocking

```{{LANGUAGE}}
{{MOCKING_EXAMPLE}}
```

---

## File Organization Rules

**Source Files**:
- Place in `{{SOURCE_DIRECTORY}}/{{SUBDIRECTORY_PATTERN}}/`
- One class per file (unless related DTOs/models)
- File name matches primary type

**Test Files**:
- Place in `{{TEST_DIRECTORY}}/{{SUBDIRECTORY_PATTERN}}/`
- Mirror source directory structure
- Suffix: `{{TEST_FILE_SUFFIX}}` (e.g., `.test.ts`, `Tests.cs`)

**Configuration**:
- Environment-specific configs in `{{CONFIG_DIRECTORY}}/`
- Never commit secrets (use environment variables or key vault)

---

## Common Mistakes to Avoid

### Mistake 1: {{COMMON_MISTAKE_1}}

**Wrong**:
```{{LANGUAGE}}
{{MISTAKE_1_WRONG}}
```

**Correct**:
```{{LANGUAGE}}
{{MISTAKE_1_CORRECT}}
```

**Why**: {{MISTAKE_1_REASON}}

### Mistake 2: {{COMMON_MISTAKE_2}}

**Wrong**:
```{{LANGUAGE}}
{{MISTAKE_2_WRONG}}
```

**Correct**:
```{{LANGUAGE}}
{{MISTAKE_2_CORRECT}}
```

**Why**: {{MISTAKE_2_REASON}}

### Mistake 3: {{COMMON_MISTAKE_3}}

**Wrong**:
```{{LANGUAGE}}
{{MISTAKE_3_WRONG}}
```

**Correct**:
```{{LANGUAGE}}
{{MISTAKE_3_CORRECT}}
```

**Why**: {{MISTAKE_3_REASON}}

---

## Project-Specific Patterns

### {{PROJECT_PATTERN_1}} (e.g., Repository Pattern)

```{{LANGUAGE}}
{{PROJECT_PATTERN_1_EXAMPLE}}
```

### {{PROJECT_PATTERN_2}} (e.g., Result<T> Pattern)

```{{LANGUAGE}}
{{PROJECT_PATTERN_2_EXAMPLE}}
```

---

## Import/Using Conventions

```{{LANGUAGE}}
{{IMPORT_ORDER_EXAMPLE}}
```

**Order**: {{IMPORT_ORDER_RULE}} (e.g., System, third-party, project)

---

## Fill Instructions

Replace ALL placeholders in `{{DOUBLE_BRACES}}`:

1. **PROJECT_NAME**: Project name
2. **PROJECT_DESCRIPTION**: Brief description
3. **PRIMARY_LANGUAGE**: C#, TypeScript, Python, etc.
4. **PRIMARY_FRAMEWORK**: ASP.NET Core, React, etc.
5. **ARCHITECTURE_PATTERN**: Layered, clean architecture, etc.
6. **DATABASE_TECHNOLOGY**: PostgreSQL, Cosmos DB, etc.
7. **LANGUAGE**: Code block language (csharp, typescript, python)
8. Fill in naming conventions and examples
9. Add 3+ framework-specific examples
10. Add 3+ common mistakes with correct/incorrect examples
11. Add project-specific patterns (at least 2)
12. Delete this "Fill Instructions" section when done
