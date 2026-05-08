# Fixture: basic input for /resume-handoff (synthetic)

Synthetic input for the resume-handoff skill. The skill rehydrates session state from a `PENDING_HANDOFF` artifact written at HALT or session-end.

## Synthetic input artifact

`.claude/work-items/WI-20260430-1200-feature-foo/PENDING_HANDOFF` exists with:
- last completed task
- 1 blocker
- next-action recommendation

## Skill invocation

```
/resume-handoff
```

## Notes

This fixture exercises the smart-default flow (read handoff → restore state → continue).
