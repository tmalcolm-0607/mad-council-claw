# [PROJECT_NAME]

[PROJECT_DESCRIPTION — 1-2 sentences]

<!-- For personal overrides (gitignored), create CLAUDE.local.md next to this file -->

---

## Commands

### Build
```bash
[BUILD_COMMAND]
# e.g., dotnet build --configuration Release
```

### Test
```bash
[TEST_COMMAND]
# e.g., dotnet test --no-build
```

### Lint/Format
```bash
[LINT_COMMAND]
# e.g., dotnet format --verify-no-changes
```

### Run Locally
```bash
[RUN_COMMAND]
# e.g., dotnet run --project src/MyApp
```

---

## Architecture Overview

**Tech Stack**: [PRIMARY_LANGUAGE] / [PRIMARY_FRAMEWORK] / [DATABASE]

**Directory Structure**:
```
[PROJECT_ROOT]/
  src/
    [MAIN_PROJECT]/
    [SHARED_PROJECT]/
  tests/
    [TEST_PROJECT]/
  .claude/
```

---

## Quality Gates

After EACH user story or phase, run these gates and paste actual output.

| Gate | Command | Success Criteria |
|------|---------|------------------|
| Build | `[BUILD_GATE_COMMAND]` | Exit 0, no errors |
| Test | `[TEST_GATE_COMMAND]` | All pass, 0 failed |
| Lint | `[LINT_GATE_COMMAND]` | Exit 0, no errors |
| Coverage | `[COVERAGE_GATE_COMMAND]` | >= [COVERAGE_THRESHOLD]% |

**No skipping. Paste output. Fix before proceeding.**

---

## Test Strategy

- **Framework**: [TEST_FRAMEWORK — e.g., xUnit, Jest, pytest]
- **Test location**: [TEST_DIRECTORY — e.g., tests/MyApp.Tests/]
- **Naming convention**: [TEST_NAMING — e.g., MethodName_Scenario_ExpectedBehavior]
- **Mocking library**: [MOCK_LIBRARY — e.g., Moq, jest.mock, unittest.mock]
- **Arrange/Act/Assert** pattern required — no single-step tests without clear sections

---

## Code Conventions

See `.claude/rules/code-conventions.md` for full naming and pattern rules.

### Key Rules

| Anti-Pattern | Correct Approach |
|--------------|-----------------|
| [ANTI_PATTERN_1] | [FIX_1] |
| [ANTI_PATTERN_2] | [FIX_2] |

---

## Security

Claude must never read or write these paths without explicit user approval:

```json
{
  "permissions": {
    "deny": [
      "Read(.env*)",
      "Read(*.key)",
      "Read(*.pem)",
      "Read(credentials.json)",
      "Read(**/secrets/**)"
    ]
  }
}
```

> Copy the above into `.claude/settings.local.json` to enforce locally,
> or `.claude/settings.json` to enforce for all team members.

---

## Agent Guidance

### Do
- Follow existing patterns in the codebase
- Run quality gates after each change
- Write tests before implementation (TDD)
- Use project-specific conventions from this file

### Do NOT
- Create new architectural patterns without approval
- Skip quality gates
- Modify infrastructure manually (use IaC)
- Commit secrets or credentials
- Push without explicit user request

---

## Project-Specific Notes

[PROJECT_SPECIFIC_NOTES]
