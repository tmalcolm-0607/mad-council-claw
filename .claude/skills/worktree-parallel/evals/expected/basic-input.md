# Expected output: basic input for /worktree-parallel

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (git worktree available; ports free) passes |
| Step 1 | allocate worktree per task |
| Step 2 | assign disjoint port ranges per `rules/worktree-runtime-isolation.md` |
| Step 3 | scaffold per-worktree DB schema + Docker container names |
| Step 4 | spawn parallel work |
| Step 5 | report cleanup commands |

## Output Contract

- Each worktree cites: branch, port range, Docker container names, file scope
- File-ownership conflict detection (sequential fallback if overlap)
- Anti-hallucination: never claim worktrees ready without verifying paths

## Verdict

ACCEPT — 3 worktrees allocated; ports + Docker isolated.

## Skill features exercised

- Smart-default flow ✓
- worktree-runtime-isolation rule ✓
- Standards inheritance ✓
