---
paths:
  - "**/*.cs"
  - "**/spec.md"
  - "**/plan.md"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# Code Review Criteria

Any of these issues = automatic rejection.

## Code Quality

- Functions exceeding 300 lines
- Nesting deeper than 3 levels
- Missing error handling on database/Cosmos calls
- Unbounded queries (missing pagination or `.Take()`)
- Missing null checks on external inputs
- `catch (Exception)` without re-throw or specific handling
- Suppressing warnings without justification comment
- Mock/hardcoded data in non-test files

## Test Quality

- Missing tests for new public methods
- Test names that don't describe the scenario
- Mocking repository/database in integration tests
- Missing edge case coverage (null, empty, boundary values)

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| "Tests are optional" | Quality gaps | Tests are required |
| Build passes = verified | False confidence | Only test pass = verified |
| Defer testing to "later" | Bugs compound | Test inline |
| Unit tests only | Integration bugs missed | Add integration tests |
| Unrelated changes bundled in single PR | Scope creep, harder to review | Split into focused PRs/commits |

## Consistency Enforcement

Pattern drift triggers automatic rejection when unjustified:

| Drift Type | Baseline Source | Action |
|------------|----------------|--------|
| DI registration mismatch (singleton vs scoped) | `dotnet-di-patterns.md` + master baseline | Flag with baseline citation |
| Error handling approach change (Result<T> vs exceptions) | `dotnet-error-handling.md` + master baseline | Flag as blocking |
| Logging pattern change (string interpolation vs source gen) | `dotnet-logging.md` + master baseline | Flag with baseline citation |
| Config access change (direct IConfiguration vs Options) | `dotnet-configuration.md` + master baseline | Flag with baseline citation |
| Test pattern change (framework, naming, builders) | `dotnet-testing-*.md` + master baseline | `nit:` unless breaking existing patterns |

### When Divergence Is Acceptable

- PR description explicitly justifies the divergence
- Community research confirms a 2026 ecosystem shift (triggers `needs_research`)
- The divergence follows a pattern documented in `.claude/rules/patterns/` but not yet in the project baseline

In these cases, the finding is downgraded to `nit (non-blocking):` with a citation.

### Consistency Label

Use the `consistency:` Conventional Comments label for drift findings:

```
consistency: New service uses AddSingleton<> but project convention is AddScoped<>

The master baseline shows services in AddBusinessLogicServices() use AddScoped<>.
This service is stateless, so singleton may be intentional - worth confirming.
```

## Integration Surface Completeness

| Pattern | Action |
|---------|--------|
| Integration methods that only throw `NotImplementedException` | REJECT |
| Public interfaces without implementations in merged code | REJECT |
| Unresolved TODO/FIXME in integration layer (Service, DataAccess, API) | WARN |
| Interface definitions without DI registration | WARN |
