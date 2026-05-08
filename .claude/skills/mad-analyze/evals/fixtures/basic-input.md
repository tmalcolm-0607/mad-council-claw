# Fixture: basic input for /mad-analyze (synthetic)

Synthetic input for the mad-analyze skill. The skill performs cross-artifact consistency analysis on spec/plan/tasks/research for a feature.

## Synthetic input artifact

Feature dir: `specs/3-feature-foo/`
- `spec.md` — 8 FRs
- `plan.md` — 6 phases
- `tasks.md` — 14 tasks
- `research.md` — 2 decisions

## Skill invocation

```
/mad-analyze
```

## Notes

This fixture exercises the smart-default flow (load all → cross-reference → flag drift). For mode-specific fixtures (--council, --strict), add additional fixtures.
