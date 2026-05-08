# Git Workflow

Standards for branches, commits, worktrees, and PRs.

---

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<desc>` | `feature/user-auth` |
| Bug fix | `bugfix/<desc>` | `bugfix/login-timeout` |
| Refactor | `refactor/<desc>` | `refactor/auth-module` |

---

## When to Commit

| Trigger | Commit? |
|---------|---------|
| Phase completed | Yes |
| Gate passed | Yes |
| Build failing | **No** |
| Tests failing | **No** |

---

## Push Guard

The `pre-bash-validate.js` hook warns on unsolicited `git push` commands.

| Command | Behavior |
|---------|----------|
| `git push --dry-run` | Passes silently (not intercepted) |
| `git push origin main` | Prompts for confirmation (`permissionDecision: 'ask'`) in warn mode; denied (`permissionDecision: 'deny'`) in block mode |
| `git push --force` | Prompts for confirmation (`permissionDecision: 'ask'`) in all modes — not hard-blocked |

Feature flag: `PUSH_GUARD_MODE` (set in `.claude/settings.local.json` under `env`)
- `warn` (default): plain pushes prompt for confirmation before proceeding
- `block`: plain pushes are denied outright; `--force` still prompts (use with caution on personal branches)

```json
{
  "env": {
    "PUSH_GUARD_MODE": "block"
  }
}
```

---

## Commit Format

```
<type>(<scope>): <description>

[body]

Work Item: WI-YYYYMMDD-HHMM-slug
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

---

## Worktree Usage

For features requiring commits, use worktrees:

```bash
# Create worktree
git worktree add ../project-feature -b feature/name

# All commands use worktree path
cd ../project-feature && npm test

# Cleanup after merge
git worktree remove ../project-feature
```

**Benefits**: Isolation, parallel work, clean state, easy cleanup.

---

## Files to Commit

| Always | Never |
|--------|-------|
| manifest.json, plan.md | ACTIVE |
| CHANGELOG.md | .mad/scratch/* |
| Agent/rule files | node_modules, .env |

---

## PR Checklist

- [ ] All gates pass
- [ ] Plan checkboxes complete
- [ ] Work item status updated
- [ ] Commits are logical and atomic

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Committing failing tests | Fix before commit |
| Giant commits | Small, logical commits |
| Force push to shared | Only to personal branches |
| Committing secrets | Use .gitignore |
