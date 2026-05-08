# Fixture: basic input for /council-open (synthetic)

Synthetic input for the council-open skill. The skill creates a new council channel with the opener as owner.

## Synthetic input artifact

Channel name: `service-redesign`
Purpose: "Review the proposed pivot from Service Bus to EventBridge."
Opener alias: `Architect`
Tier: `local` (developer-driven channel)
Acceptance criteria: omitted (not opened with `--triage`)

## Skill invocation

```
/council-open service-redesign --as "Architect" --purpose "Review the proposed pivot from Service Bus to EventBridge."
```

## Notes

This fixture exercises the smart-default flow (validate name → create channel.json → set owner → seq.json bootstrap). For mode-specific fixtures (--triage, --owner <alias>, --tier prod), add additional fixtures.
