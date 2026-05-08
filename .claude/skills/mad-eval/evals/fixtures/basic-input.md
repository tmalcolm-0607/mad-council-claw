# Fixture: basic input for /mad-eval (synthetic)

Synthetic input for the mad-eval skill. The skill runs an eval suite (skill-level fixtures, scenario tests, behavioral checks) against a target skill or workflow.

## Synthetic input artifact

Target: skill `pr-review`
Eval set: 3 fixtures (clean-dep-bump, auth-policy-change, basic-input)
Mode: `structural` (presence + shape, not LLM-driven)

## Skill invocation

```
/mad-eval pr-review
```

## Notes

This fixture exercises the smart-default flow (discover → run → aggregate). For mode-specific fixtures (--llm, --copilot for cross-model agreement), add additional fixtures.
