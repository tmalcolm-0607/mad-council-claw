# Fixture: basic input for /mad-checklist (synthetic)

Synthetic input for the mad-checklist skill. The skill emits a checklist for a MAD phase (spec, plan, tasks, implement, validate) with phase-specific items.

## Synthetic input artifact

Phase: `implement`
Active feature: `specs/3-feature-foo/`
Plan progress: 4/8 tasks complete; 1 task with `[!]` blocker

## Skill invocation

```
/mad-checklist implement
```

## Notes

This fixture exercises the smart-default flow (load phase → emit checklist → status per item). For mode-specific fixtures (other phases, --strict), add additional fixtures.
