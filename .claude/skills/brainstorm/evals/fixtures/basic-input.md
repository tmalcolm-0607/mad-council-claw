# Fixture: basic input for /brainstorm (synthetic)

Synthetic input for the brainstorm skill. The skill expands a user prompt into N candidate angles, evaluates each against a quality rubric, and returns ranked options.

## Synthetic input artifact

User prompt:
> "How could we reduce flakiness in our integration test suite? It's currently running ~30 tests with about 8% intermittent failure rate."

Constraints:
- .NET 10 + Cosmos emulator
- CI runs in ADO pipelines
- Cannot pay for parallel test runners

## Skill invocation

```
/brainstorm
```

## Notes

This fixture exercises the smart-default flow (expand → evaluate → rank). For mode-specific fixtures (--n 10, --council, --copilot for cross-model angles), add additional fixtures alongside this one.
