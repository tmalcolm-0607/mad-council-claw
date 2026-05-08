# Worktree Runtime Isolation

## Isolated per worktree
Git state, `.claude/` directory, source files, `.env` files.

## Shared (NOT isolated)
Ports, Docker daemon, PostgreSQL, `/tmp`, global config, env vars.

## Port Conflict Prevention

Source of truth for ports: `appsettings.json` (and `appsettings.Development.json`). Do NOT hardcode port numbers in task descriptions or agent prompts.

Before running a parallel workstream:
1. Check `appsettings.json` for current port assignments
2. Assign a distinct port range per worktree (e.g., worktree 1 = +0 offset, worktree 2 = +100 offset)
3. Pass port via `--urls` flag: `dotnet run --urls http://localhost:{PORT}`

## Pre-Parallel Checklist
- Unique port assignments per worktree (check `appsettings.json`, use `--urls` flag)
- Separate DB schema/container per worktree
- Disjoint file ownership across teammates
- Unique Docker container names (worktree-prefixed)
