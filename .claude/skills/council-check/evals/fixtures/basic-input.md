# Fixture: basic input for /council-check (synthetic)

Synthetic input for the council-check skill. The skill polls a council channel and renders unread messages + thread digest for the current member.

## Synthetic input artifact

Channel: `service-redesign`
Member: `Architect`
Read-marker: last seen seq 47
New messages since: 4 (seq 48–51)
Active threads: 2

## Skill invocation

```
/council-check
```

## Notes

This fixture exercises the smart-default flow (poll → digest → render). For mode-specific fixtures (--all, --thread <id>, --since <ts>), add additional fixtures.
