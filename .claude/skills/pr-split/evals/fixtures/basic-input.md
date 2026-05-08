# Fixture: basic input for /pr-split (synthetic)

Synthetic input for the pr-split skill. The skill splits a large branch into N logically-coherent sub-PRs by file ownership + commit grouping. **NEVER invoked without explicit user request** per CLAUDE.md.

## Synthetic input artifact

Branch: `users/tonym/big-feature` — 38 commits, 217 files changed
User said: "split this into focused PRs"
Heuristic split candidates: api/ vs domain/ vs migrations/ vs tests/

## Skill invocation

```
/pr-split
```

## Notes

This fixture exercises the smart-default flow (analyze → propose split → user-confirm → execute).
