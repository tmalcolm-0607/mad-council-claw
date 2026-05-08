# Fixture: basic input for /repo-sync (synthetic)

Synthetic input for the repo-sync skill. The skill mirrors a curated subset of files between two repos (kit consumer ↔ kit author) with conflict detection.

## Synthetic input artifact

- Source: `C:/Users/tonym/Repos/MAD/.claude/rules/`
- Target: `C:/Users/tonym/Repos/MAD - Clean/.claude/rules/`
- Files in source: 47
- Files in target: 45 (2 missing, 3 modified vs source, 0 conflicting)

## Skill invocation

```
/repo-sync
```

## Notes

This fixture exercises the smart-default flow (enumerate → diff → propose → user-confirm → apply). For mode-specific fixtures (--dry-run, --bidirectional, --council), add additional fixtures.
