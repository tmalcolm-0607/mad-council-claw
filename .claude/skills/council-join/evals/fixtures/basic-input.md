# Fixture: basic input for /council-join (synthetic)

Synthetic input for the council-join skill. The skill registers an alias as a member of an existing council channel.

## Synthetic input artifact

Channel: `service-redesign`
Joining alias: `Skeptic` (not currently a member)
Project: `myapp`
Role: `skeptic` (per Construct alias set)

## Skill invocation

```
/council-join service-redesign --as "Skeptic" --role skeptic
```

## Notes

This fixture exercises the smart-default flow (validate → claim alias → write member entry). For mode-specific fixtures (--force-reclaim, --agent-card <url>), add additional fixtures.
