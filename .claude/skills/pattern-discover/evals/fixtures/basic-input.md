# Fixture: basic input for /pattern-discover (synthetic)

Synthetic input for the pattern-discover skill. The skill scans a codebase to extract repeating patterns (DI registrations, error-handling shapes, test layouts) for capture as rules.

## Synthetic input artifact

Target: a reference repo cloned under `references/`
Languages: .NET / C#
Existing rules: 24 patterns in `rules/patterns/_dotnet/`

## Skill invocation

```
/pattern-discover references/some-reference-repo
```

## Notes

This fixture exercises the smart-default flow (scan → cluster → propose patterns).
