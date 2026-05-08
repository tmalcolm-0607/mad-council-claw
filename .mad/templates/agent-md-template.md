# [PROJECT_NAME] - AGENT.md

[Brief description of what this project/module does and its role in the system]

## Purpose

[Detailed explanation of the project's responsibilities and how it fits into the overall architecture]

## Project Structure

```text
[PROJECT_NAME]/
├── folder1/       # [Description]
├── folder2/       # [Description]
└── file.ext       # [Description]
```

## Key Components

### [Component Category 1]

- `ComponentName` - [Brief description]
- `AnotherComponent` - [Brief description]

### [Component Category 2]

- `InterfaceName` - [Brief description]

## Commands

```bash
# Build this project
[build command]

# Run tests
[test command]

# Additional commands
[other commands as needed]
```

## Code Patterns

### [Pattern Name 1]

```[language]
// Example code showing the preferred pattern
```

### [Pattern Name 2]

```[language]
// Another example
```

## Configuration

### Key Settings

```json
{
  "setting1": "description",
  "setting2": "description"
}
```

### Environment Variables

- `ENV_VAR_1` - [Description]
- `ENV_VAR_2` - [Description]

## Boundaries

### Always Do

- [Rule 1: What you must always do]
- [Rule 2: Required practices]
- [Rule 3: Mandatory patterns]

### Never Do

- [Rule 1: Prohibited actions]
- [Rule 2: Anti-patterns to avoid]
- [Rule 3: Security constraints]

## LLM Trust Boundary (If Applicable)

<!--
Include this section ONLY if this project contains code that processes LLM output
(e.g., agents, orchestrators, execution services). Delete if not applicable.
-->

### Logical Gates (C# enforces)

- `File.Exists()` after claiming to write files
- `count > 0` after LLM claims output
- `gitService.IsDirty()` after file writes
- Injected reviewers MUST be called

### Semantic Decisions (LLM handles)

- Content quality and completeness
- Whether output is "good enough"

### Anti-Patterns

- Graceful degradation on empty work
- Trusting file lists without verification
- Injecting but not calling reviewers
- Hardcoding content quality thresholds in C#

## Dependencies

### Project References

- `Project.Name` - [Why this dependency exists]

### NuGet/NPM Packages

- `package-name` - [Purpose]

## Testing

### Test Location

Tests are located in: `[test project path]`

### Test Patterns

- [Testing guideline 1]
- [Testing guideline 2]

### Mocking Guidelines

- [What to mock]
- [What not to mock]

## Related Documentation

- [Link to related docs]
- [Link to API specs]

---

<!--
AGENT.md Template Instructions:
1. Replace all [PLACEHOLDERS] with actual content
2. Remove sections that don't apply to your project
3. Add project-specific sections as needed
4. Keep examples concise but complete
5. Update boundaries based on project constraints
-->
