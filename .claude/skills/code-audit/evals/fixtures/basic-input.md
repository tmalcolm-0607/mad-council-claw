# Fixture: basic input for /code-audit (synthetic)

Synthetic input for the code-audit skill. The skill performs a broad sweep of a directory tree against project conventions (DI, error handling, logging, security patterns) without modifying anything.

## Synthetic input artifact

Target: `src/services/`
Conventions: per `rules/patterns/_dotnet/*.md`

## Skill invocation

```
/code-audit src/services/
```

## Notes

This fixture exercises the smart-default flow (sweep → categorize → report). For mode-specific fixtures (--council, --filter <pattern>), add additional fixtures.
