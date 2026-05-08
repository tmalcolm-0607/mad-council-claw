# Fixture: basic input for /pr-pattern-extract (synthetic)

Synthetic input for the pr-pattern-extract skill. The skill ingests PR review threads and extracts recurring reviewer concerns as patterns.

## Synthetic input artifact

PRs sampled: 8 recent
Comments analyzed: 47
Recurring topics: validator-wiring (5×), ETag propagation (4×), enum-serialization breakage (3×)

## Skill invocation

```
/pr-pattern-extract --since 30d
```

## Notes

This fixture exercises the smart-default flow (collect → cluster → emit pattern candidates).
