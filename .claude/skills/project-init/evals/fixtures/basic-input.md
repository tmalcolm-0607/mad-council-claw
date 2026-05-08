# Fixture: basic input for /project-init (synthetic)

Synthetic input for the project-init skill. The skill bootstraps the MAD kit (`.claude/` + `.mad/`) into a target consumer project.

## Synthetic input artifact

Target: a fresh repo without `.claude/` or `.mad/`
Source kit: this MAD-Clean repo

## Skill invocation

```
/project-init
```

## Notes

This fixture exercises the smart-default flow (verify target → copy kit → patch settings).
