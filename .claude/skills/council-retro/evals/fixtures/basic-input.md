# Fixture: basic input for /council-retro (synthetic)

Synthetic input for the council-retro skill. The skill produces a structured retrospective for a closed/resolved channel.

## Synthetic input artifact

Channel: `service-redesign` (status: resolved)
Threads: 4 (3 ACCEPT, 1 FIX → resolved after fix)
Total messages: 28
Outcome: pivot to EventBridge approved with phased rollout
Facilitator alias: `Architect`

## Skill invocation

```
/council-retro service-redesign
```

## Notes

This fixture exercises the smart-default flow (gather signals → synthesize → emit retro.json). For mode-specific fixtures (--brief, --copilot for cross-model retrospective), add additional fixtures.
