# Expected output: basic input for /pr-split

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (explicit user request present; branch up-to-date) passes |
| Step 1 | enumerate commits + file ownership graph |
| Step 2 | propose N coherent groups with dependency order |
| Step 3 | user-confirm split plan |
| Step 4 | create N sub-branches via cherry-pick (no force-push to original) |
| Step 5 | open N draft PRs (only if user explicitly approved) |

## Output Contract

- Each proposed sub-PR cites: branch name, commits included, file scope, dependency on prior PRs
- NEVER auto-execute without confirmation
- Anti-hallucination: never claim a split is clean without verifying cherry-picks

## Verdict

ACCEPT_WITH_CAVEATS — split plan proposed; user must approve before execute.

## Skill features exercised

- Smart-default flow ✓
- Dangerous-operations consent gate ✓
- Standards inheritance ✓
