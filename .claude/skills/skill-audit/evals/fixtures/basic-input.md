# Fixture: basic input for /skill-audit (synthetic)

Synthetic input for the skill-audit skill. The skill audits all skills under `.claude/skills/` against `rules/skill-standards.md` 6-dimension scorecard.

## Synthetic input artifact

`.claude/skills/` contains 67 skills with mixed maturity:
- 56 have BP + Standards
- 23 have real eval fixtures
- 8 have templates
- 28 are pure-utility (tier-exempt from evals/templates)

## Skill invocation

```
/skill-audit
```

## Notes

This fixture exercises the smart-default flow (enumerate → score → tier → report). For mode-specific fixtures (--copilot for cross-model audit, --council, --filter <tier>), add additional fixtures.
