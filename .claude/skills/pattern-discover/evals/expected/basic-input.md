# Expected output: basic input for /pattern-discover

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (target tree readable) passes |
| Step 1 | enumerate source files; categorize by language |
| Step 2 | cluster repeating shapes (registrations, validations, error mapping) |
| Step 3 | de-dup against existing `rules/patterns/_dotnet/*.md` |
| Step 4 | propose new pattern files with severity |
| Step 5 | write report to `.mad/learning/patterns-discovered-<ts>.md` |

## Output Contract

- Each pattern cites: example files (≥3 instances) + frequency
- New patterns flagged for /apply-learnings review
- Anti-hallucination: never claim a pattern with <3 instances
- Empty discoveries stated explicitly

## Verdict

ACCEPT — N candidate patterns surfaced for user review.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
