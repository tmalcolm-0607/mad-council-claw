# Fixture: basic input for /mad-traceability (synthetic)

Synthetic input for the mad-traceability skill. The skill builds (or refreshes) a traceability matrix from feature → spec FRs → plan phases → tasks → tests.

## Synthetic input artifact

Feature dir: `specs/3-feature-foo/`
Existing matrix: stale (last refresh 2 weeks ago); 2 FRs added since.

## Skill invocation

```
/mad-traceability
```

## Notes

This fixture exercises the smart-default flow (gather → cross-reference → emit matrix). For mode-specific fixtures (--strict, --feature <id>), add additional fixtures.
