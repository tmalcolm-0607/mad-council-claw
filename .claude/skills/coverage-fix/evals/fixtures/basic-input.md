# Fixture: basic input for /coverage-fix (synthetic)

Synthetic input for the coverage-fix skill. The skill closes coverage gaps surfaced by the gates: writes targeted tests until diff-coverage hits target.

## Synthetic input artifact

Diff coverage: 78% (target 100%)
Uncovered files (4): SessionValidator.cs, RetryPolicy.cs, ErrorHandler.cs, RouteRegistration.cs
Uncovered lines: 12 across the 4 files

## Skill invocation

```
/coverage-fix
```

## Notes

This fixture exercises the smart-default flow (analyze gaps → write tests → re-run → iterate). For mode-specific fixtures (--target <pct>, --files <list>), add additional fixtures.
