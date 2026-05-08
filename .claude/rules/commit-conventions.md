# Commit Conventions

Only create commits when requested by the user. If unclear, ask first.

## Git Safety Protocol

- **NEVER** update the git config.
- **NEVER** run destructive git commands (`push --force`, `reset --hard`, `checkout .`, `restore .`, `clean -f`, `branch -D`) unless the user explicitly requests.
- **NEVER** skip hooks (`--no-verify`, `--no-gpg-sign`, etc.) unless the user explicitly requests.
- **NEVER** force-push to `main`/`master`; warn the user if they request it.
- **CRITICAL**: Always create NEW commits, NOT amendments. When a pre-commit hook fails, the commit did NOT happen — so `--amend` would modify the PREVIOUS commit and may destroy work. Instead: fix, re-stage, NEW commit.
- Stage specific files by name; avoid `git add -A` / `git add .` (risks sensitive files).

## Commit-message HEREDOC template

Always pass commit messages via a HEREDOC to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
Short subject line.

Longer description explaining the *why*, not the *what*.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## What to write

1. Summarize the *nature* of the change: feat / fix / refactor / docs / test / chore.
2. Focus on *why*, not *what* (the diff shows *what*).
3. Keep subject ≤70 chars; use body for detail.
4. Include `Co-Authored-By:` for AI-assisted commits.

## Never

- `git rebase -i` / `git add -i` — interactive mode unsupported in this environment.
- `git rebase --no-edit` — not a valid option.
- `git commit --amend` after a failed pre-commit hook (destroys work).
- Committing `.env`, `credentials.json`, or anything that might hold secrets — warn the user if they ask.

## Pre-commit hook failure

1. Fix the underlying issue (don't bypass with `--no-verify`).
2. Re-stage.
3. Create a NEW commit (never `--amend`).

Enforced by `hooks/pre-commit-validate.js`.
