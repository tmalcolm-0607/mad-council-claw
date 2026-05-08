# Fixture: basic input for /documentation-engineer (synthetic)

Synthetic input for the documentation-engineer skill. The skill audits/updates project documentation (README, ARCHITECTURE, CONTRIBUTING, ADRs) for accuracy against the current codebase.

## Synthetic input artifact

Docs:
- `README.md` (last touched 2 months ago; references old CLI flags)
- `docs/ARCHITECTURE.md` (mentions service deprecated last sprint)
- No `CONTRIBUTING.md`

Codebase: current.

## Skill invocation

```
/documentation-engineer
```

## Notes

This fixture exercises the smart-default flow (audit → diff → propose patches).
