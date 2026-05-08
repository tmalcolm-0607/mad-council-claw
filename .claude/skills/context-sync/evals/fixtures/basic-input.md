# Fixture: basic input for /context-sync (synthetic)

Synthetic input for the context-sync skill. The skill keeps in-session context aligned with persisted state (work item ACTIVE pointer, plan checkboxes, blockers) after long-running work or compaction.

## Synthetic input artifact

State drift indicators:
- ACTIVE pointer says `WI-20260430-1200-feature-foo`
- Plan claims 4/8 tasks complete; in-session memory says 3/8.
- One `[!]` blocker in tasks.md not yet acknowledged in conversation.

## Skill invocation

```
/context-sync
```

## Notes

This fixture exercises the smart-default flow (read persisted → reconcile → report drift).
