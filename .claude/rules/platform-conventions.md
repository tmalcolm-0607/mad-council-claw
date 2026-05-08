# Platform & Environment Conventions

Cross-platform gotchas, especially for Windows + Git Bash + PowerShell mixed environments.

| Rule | Detail |
|------|--------|
| Python on Windows | `py` not `python` |
| Git stderr | PowerShell treats stderr as error — check `$LASTEXITCODE` instead |
| MSYS path mangling | `MSYS_NO_PATHCONV=1` for `az` CLI route params on Git Bash |
| Git paths | Forward slashes always (`C:/source/...`) |
| Background agents | Never use `run_in_background: true` on Task tool (confirmed bugs: hangs, empty outputs) |
| Line endings | `tr -d "\r"` after base64 decode on Windows |
| `CLAUDE.local.md` | Use for personal per-project preferences (auto-gitignored by Claude Code) |
| Git Bash glob expansion | Quote glob args; Git Bash expands `*` before the command sees it |
| `Join-Path` 2-arg limit | Chain: `Join-Path (Join-Path $a $b) $c` |
| PowerShell explicit params | Always pass named parameters; never rely on positional defaults |
| `.env` auto-loading | Claude Code loads project `.env` into bash env. Never put `ANTHROPIC_API_KEY` in `.env` — it overrides Claude Code auth (affects Max, Pro, and API key sessions) |

## PowerShell Conventions

- Never use `$args` (reserved) — use `$Arguments` or named params
- Single-quoted strings for patterns with `#`, `$`, or special chars
- `$ErrorActionPreference='Stop'` breaks native stderr — use `$LASTEXITCODE` instead

See `rules/patterns/powershell-conventions.md` for full rules.

## Git Conventions

See `rules/git-workflow.md`.

- Commit messages via HEREDOC to preserve formatting
- Include `Co-Authored-By:` trailer for AI-assisted commits
- Never `git rebase -i` / `git add -i` (interactive flags unsupported in this environment)
- Never `git rebase --no-edit` (not a valid option)
- Always create NEW commits, not `--amend` (amend after pre-commit-hook failure can destroy work)

## Destructive Operation Fence

Never run without explicit user request:

- `git push --force` (warn especially on `main`/`master`)
- `git reset --hard`
- `git checkout .` / `git restore .`
- `git clean -f`
- `git branch -D`
- `rm -rf`
- Skipping hooks: `--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`

Enforced by `hooks/pre-bash-validate.js`.
