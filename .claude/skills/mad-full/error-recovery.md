# mad-full: Error Recovery & PR Review

## Recoverable Errors

| Error | Action |
|-------|--------|
| Test failures | Parse failing test name → fix → re-run ONLY that test with `--filter` → when GREEN, run affected project → then full suite |
| Build errors | Same as above |
| Coverage gap | Generate additional tests |
| Contract mismatch | Update routes or contracts |

## Blocking Errors

| Error | Action |
|-------|--------|
| Spec unclear | Pause, ask user for clarification |
| Constitution violation | Cannot proceed, requires design change |
| >10 implement iterations | Pause, report blocking issue |
| Auth/permission failure | Exit with error |

## Multi-Agent PR Review (Phase 7)

### Option A: Headless Claude Reviewer

```bash
claude -p "/pr-review $(gh pr view --json number -q .number) --fix" \
  --allowedTools "Read,Grep,Glob,Bash(git:*),Edit,Write" \
  --output-format json \
  --append-system-prompt "You are a code reviewer. Be critical. Find bugs."
```

Fresh context (no implementation bias), separate API session.

### Option B: GitHub Copilot Review

```bash
gh pr edit $(gh pr view --json number -q .number) --add-label "copilot-review"
# Wait for Copilot review comment
while ! gh pr view --json reviews -q '.reviews[] | select(.author.login == "github-actions[bot]")' 2>/dev/null; do
  sleep 30
done
```

### Review Loop

1. Create PR
2. Spawn reviewer (headless Claude / Copilot)
3. Reviewer analyzes, posts comments
4. Parse feedback → No issues? Merge. Has issues? Continue.
5. Fix issues in worktree, run gates, commit, push
6. Re-trigger review (max 3 cycles before escalating to human)
7. Approved → Merge PR → Cleanup worktree
