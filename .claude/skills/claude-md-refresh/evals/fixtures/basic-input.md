# Fixture: basic input for /claude-md-refresh (synthetic)

Synthetic input for the claude-md-refresh skill. The skill audits the project's `CLAUDE.md` against current codebase state, recent rules drift, and team standards, then proposes targeted updates.

## Synthetic input artifact

`CLAUDE.md` (excerpt):
```
## Quality Gates
Run all gates before commit. (last touched 2025-12)

## Orchestration
Main coordinates. Agents work. (matches current rule)

## Some Stale Section
References old script paths under .claude/scripts/...
```

Recent rule drift:
- `rules/orchestration.md` updated 2026-04 — mentions composite agents
- `rules/quality-gates.md` updated 2026-03 — adds preflight gate
- Scripts moved from `.claude/scripts/` to `.mad/scripts/` (2026-02)

## Skill invocation

```
/claude-md-refresh
```

## Notes

This fixture exercises the smart-default flow (audit → diff → propose patches with severity tags). For mode-specific fixtures (--dry-run, --council, --apply), add additional fixtures.
