# Fixture: basic input for /council-leave (synthetic)

Synthetic input for the council-leave skill. The skill removes the current alias from a channel and emits a Completion Report.

## Synthetic input artifact

Channel: `service-redesign`
Leaving alias: `Skeptic`
Members remaining if leave: 2 (not last member)
Owner alias: `Architect` (not the leaver)

## Skill invocation

```
/council-leave service-redesign
```

## Notes

This fixture exercises the smart-default flow (validate ownership → emit completion report → atomic remove). For mode-specific fixtures (last-member archive consent, owner-leaving rejection), add additional fixtures.
