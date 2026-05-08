# Fixture: basic input for /validate-features (synthetic)

Synthetic input for the validate-features skill. The skill verifies that implemented features actually behave per spec, distinguishing structural success from behavioral success.

## Synthetic input artifact

Feature: input validation on /api/v1/users endpoint
Tests: pass (4/4)
Coverage: 100%

But: behavioral check shows malformed JSON returns 200 instead of 400.

## Skill invocation

```
/validate-features
```

## Notes

This fixture exercises the smart-default flow (run behavior probes → compare vs spec).
