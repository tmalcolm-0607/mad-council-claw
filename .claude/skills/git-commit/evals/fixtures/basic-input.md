# Fixture: basic input for /git-commit (synthetic)

Synthetic input for the git-commit skill. The skill stages targeted files and creates a conventional commit per `rules/commit-conventions.md`.

## Synthetic input artifact

Working tree:
- modified: `src/services/foo.ts`
- modified: `tests/foo.test.ts`
- untracked: `.env.local` (must NOT be staged)
Conventional type: `feat(foo)`

## Skill invocation

```
/git-commit "feat(foo): add bar handler"
```

## Notes

This fixture exercises the smart-default flow (stage targeted → format message → create commit).
