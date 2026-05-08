# Fixture: basic input for /worktree-parallel (synthetic)

Synthetic input for the worktree-parallel skill. The skill spawns parallel work in dedicated git worktrees with disjoint port + Docker isolation per `rules/worktree-runtime-isolation.md`.

## Synthetic input artifact

Tasks: 3 independent feature branches needing concurrent dev
Port assignment offsets: 0, +100, +200
Disjoint files confirmed.

## Skill invocation

```
/worktree-parallel "feature-foo,feature-bar,feature-baz"
```

## Notes

This fixture exercises the smart-default flow (allocate worktrees → assign ports → spawn).
