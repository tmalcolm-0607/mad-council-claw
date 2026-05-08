# Fixture: basic input for /debate (synthetic)

Synthetic input for the debate skill. The skill runs a structured N-round debate between two or more positions, optionally with a devil's-advocate role, and produces a synthesized verdict.

## Synthetic input artifact

Topic:
> "Should we standardize on EventBridge for inter-service messaging, or keep using Service Bus per-service queues?"

Positions:
- Pro-EventBridge: lower ops, fan-out, schema registry
- Pro-Service Bus: existing investment, dead-letter handling, RBAC

Format: 3 rounds, devil's-advocate enabled, synthesis at end.

## Skill invocation

```
/debate
```

## Notes

This fixture exercises the smart-default flow (open → N rounds → synthesize). For mode-specific fixtures (--rounds 5, --copilot for cross-model debate, --council for 3-role panel), add additional fixtures.
