# Expected output: basic input for /pr-pattern-extract

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (PR API reachable; auth valid) passes |
| Step 1 | enumerate PRs in window |
| Step 2 | extract review threads + comments |
| Step 3 | cluster by topic (≥3 instances threshold) |
| Step 4 | emit pattern candidates to `.mad/learning/pr-patterns-<ts>.md` |

## Output Contract

- Each candidate cites: PR URLs + comment excerpts (verbatim)
- Frequency + author diversity per cluster
- Anti-hallucination: never fabricate reviewer concerns
- Empty clusters stated explicitly

## Verdict

ACCEPT — N pattern candidates surfaced; user reviews via /apply-learnings.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE, anti-hallucination)
- Standards inheritance ✓
