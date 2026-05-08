# Expected output: basic input for /brainstorm

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (prompt non-empty, constraints captured) passes |
| Step 1 | expand into 5-10 distinct angles |
| Step 2 | evaluate each angle: feasibility, blast radius, expected lift |
| Step 3 | rank by composite score |
| Step 4 | flag top 3 + cite tradeoffs |
| Step 5 | write report to `.mad/reports/brainstorm-<ts>.md` |

## Output Contract

- Each angle cites: rationale + evidence basis (research, prior art, intuition)
- Ranking uses explicit rubric (not vibes)
- Confidence per angle (0-100)
- Anti-hallucination: when an angle requires unverified assumptions, flag inline
- Empty assumptions stated explicitly

## Verdict

ACCEPT — N angles ranked; user picks one or asks for more.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
