# Fixture: basic input for /memory (synthetic)

Synthetic input for the memory skill. The skill reads/writes auto-memory files in `~/.claude/projects/<repo>/memory/` per the auto-memory protocol.

## Synthetic input artifact

User just said: "remember that prod deploys go through pipeline 52320, not Ev2 directly"
Existing memory: no entry on this topic.

## Skill invocation

```
/memory remember "prod deploys via pipeline 52320 not Ev2"
```

## Notes

This fixture exercises the smart-default flow (categorize → write file → update MEMORY.md index).
