# Fixture: basic input for /workflow-checklist (synthetic)

Synthetic input for the workflow-checklist skill. The skill produces a phase-aware checklist (e.g., pre-PR, pre-deploy, pre-merge) by reading the active work item state + applicable rules.

## Synthetic input artifact

Active work item: `WI-20260430-1200-feature-foo`
Phase: pre-PR (implementation done, gates green, ready to push)

Applicable rules:
- `rules/non-negotiable-rules.md` — full gate suite before PR push
- `rules/git-workflow.md` — commit format
- `rules/quality-gates.md` — preflight gate

## Skill invocation

```
/workflow-checklist pre-pr
```

## Notes

This fixture exercises the smart-default flow (load WI → derive phase → emit checklist). For mode-specific fixtures (other phases), add additional fixtures.
