# Template — worktree allocation

Canonical shape for `/worktree-parallel` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Worktree Allocation — <ISO date>

**Tasks**: <task-A>, <task-B>, <task-C>

## Per-task

| Task | Branch | Worktree path | Port range | Docker container | DB schema |
|------|--------|----------------|------------|-------------------|-----------|
| feature-foo | users/<alias>/feature-foo | C:/source/repo-foo | 5000-5099 | repo-foo-cosmos | repo_foo |
| feature-bar | users/<alias>/feature-bar | C:/source/repo-bar | 5100-5199 | repo-bar-cosmos | repo_bar |
| feature-baz | users/<alias>/feature-baz | C:/source/repo-baz | 5200-5299 | repo-baz-cosmos | repo_baz |

## File-overlap pre-check

Confirmed disjoint (per `rules/agent-teams.md` File Ownership Protocol).

## Cleanup commands

```bash
git worktree remove C:/source/repo-foo
git worktree remove C:/source/repo-bar
git worktree remove C:/source/repo-baz
docker rm -f repo-foo-cosmos repo-bar-cosmos repo-baz-cosmos
```

## Anti-hallucination

- Each port range cited from `appsettings.json` + offset, not assumed
- Docker container names worktree-prefixed for isolation
- File-overlap check is FETCH BEFORE CITE on each task's planned file list

## Verdict

ACCEPT — 3 worktrees allocated; ports + Docker isolated. Cleanup commands provided.
```

## Reference

- `rules/worktree-runtime-isolation.md` — full isolation protocol
