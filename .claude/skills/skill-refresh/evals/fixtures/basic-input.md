# Fixture: basic input for /skill-refresh (synthetic)

Synthetic input for the skill-refresh skill. The skill takes a single skill (or a tier) and brings it up to current standards: BP, Standards, evals, templates, multi-pass + Copilot CLI.

## Synthetic input artifact

Target skill: `mad-c4` (currently Tier C — has frontmatter + standards but no eval fixtures, no templates, no multi-pass mode).

## Skill invocation

```
/skill-refresh mad-c4
```

## Notes

This fixture exercises the smart-default flow (audit → propose patches → user-confirm → apply). For mode-specific fixtures (--tier <C>, --council, --copilot), add additional fixtures.
