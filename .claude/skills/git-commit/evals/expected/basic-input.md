# Expected output: basic input for /git-commit

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (in repo; working tree dirty) passes |
| Step 1 | enumerate targeted files; warn on potential secrets |
| Step 2 | stage explicitly named files (NOT `git add .`) |
| Step 3 | format message via HEREDOC per `rules/commit-conventions.md` |
| Step 4 | create NEW commit (never `--amend` after pre-commit failure) |
| Step 5 | report commit hash |

## Output Contract

- Confirmation includes: hash, files staged, type/scope/subject
- `.env.local` rejected from staging with clear note
- Anti-hallucination: never claim "committed" until git returns success
- No `--no-verify` unless explicitly requested

## Verdict

ACCEPT — commit created.

## Skill features exercised

- Smart-default flow ✓
- commit-conventions rule ✓
- Standards inheritance ✓
