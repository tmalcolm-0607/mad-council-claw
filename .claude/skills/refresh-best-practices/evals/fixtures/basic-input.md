# Fixture: basic input for /refresh-best-practices (synthetic)

Synthetic input for the refresh-best-practices skill. The skill audits `.claude/rules/` and `.mad/docs/best-practices/` against external sources (LENS-Common, marketplace plugins, web docs from 2026) and proposes updates.

## Synthetic input artifact

Current rules:
- `.claude/rules/quality-gates.md` (last updated 2025-12)
- `.claude/rules/orchestration.md` (last updated 2026-01)

External signal:
- New marketplace pattern released 2026-04 (multi-model verification)
- Updated OWASP LLM Top 10 (2026-Q2)

## Skill invocation

```
/refresh-best-practices
```

## Notes

This fixture exercises the smart-default flow (audit → diff vs external → propose patches). For mode-specific fixtures (--source <url>, --council, --copilot), add additional fixtures alongside this one.
