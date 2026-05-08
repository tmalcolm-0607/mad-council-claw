# Fixture: basic input for /mad-full (synthetic)

Synthetic input for the mad-full skill. The skill runs the full MAD workflow end-to-end: spec → plan → tasks → analyze → implement → validate.

## Synthetic input artifact

Idea: `specs/ideas/feature-bar.md` (vision document)
Target output: `specs/4-feature-bar/` (contract spec + plan + tasks + analyze + implement)

## Skill invocation

```
/mad-full
```

## Notes

This fixture exercises the smart-default flow (chained MAD pipeline). For mode-specific fixtures (--from <phase>, --until <phase>, --skip-review), add additional fixtures.
