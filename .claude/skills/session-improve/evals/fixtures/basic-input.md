# Fixture: basic input for /session-improve (synthetic)

Synthetic input for the session-improve skill. The skill reviews recent session signals (anomalies, friction, gates failures) and proposes improvements (rules, hooks, skills).

## Synthetic input artifact

Recent signals:
- 3 hook fail-open events
- 2 PR-review false convergence claims
- 1 token-budget exhaustion at 90%

## Skill invocation

```
/session-improve apply
```

## Notes

This fixture exercises the smart-default flow (gather signals → categorize → propose patches).
