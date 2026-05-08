# Fixture: basic input for /testplan (synthetic)

Synthetic input for the testplan skill. The skill emits a structured test plan (unit + integration + e2e + non-functional) for a feature spec.

## Synthetic input artifact

Source: `specs/3-feature-foo/spec.md` (8 FRs)
Mode: `--source spec auto`

## Skill invocation

```
/testplan --source spec auto
```

## Notes

This fixture exercises the smart-default flow (parse FRs → derive scenarios → emit plan).
