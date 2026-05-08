# Fixture: basic input for /pattern-generate (synthetic)

Synthetic input for the pattern-generate skill. The skill takes a discovered pattern and emits a formal `rules/patterns/...md` file with examples + anti-patterns.

## Synthetic input artifact

Pattern candidate (from /pattern-discover):
- Name: "Validator wiring on request DTOs"
- Examples: 3 handler classes
- Frequency: occurs in 12 of 14 handler classes

## Skill invocation

```
/pattern-generate "validator-wiring"
```

## Notes

This fixture exercises the smart-default flow (read candidate → scaffold → cite examples).
