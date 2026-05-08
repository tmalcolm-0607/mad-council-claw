# Fixture: basic input for /test-validate-loop (synthetic)

Synthetic input for the test-validate-loop skill. The skill iterates: run tests → identify failure → propose fix → re-run, until green or stop condition.

## Synthetic input artifact

Initial state: 3 failing tests in `Application.Tests`
Stop conditions: green OR no progress for 2 iterations OR max 5 iterations

## Skill invocation

```
/test-validate-loop Application.Tests
```

## Notes

This fixture exercises the smart-default flow (test → diagnose → patch → loop).
