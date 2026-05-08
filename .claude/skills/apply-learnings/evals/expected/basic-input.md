# Expected output: basic input for /apply-learnings

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (`.mad/learning/patterns.json` parses; mode flag valid) passes |
| Step 1 | enumerate pending candidates by type (knowledge / pattern / validation) |
| Step 2 | for each candidate, propose: skill / rule / doc update + draft body |
| Step 3 | classify quality: reusable, one-off, inconclusive |
| Step 4 | present user-reviewable list with approve/reject/skip per candidate |
| Step 5 | on approve: write artifact (skill, rule, doc) + update status to applied |

## Output Contract

- Each candidate cites: source session/PR + duration/scope
- Reject candidates with reason ("not reusable" / "inconclusive" / "duplicates existing")
- Confidence per proposed artifact (0-100)
- Anti-hallucination: never claim a candidate is reusable without naming the future scenarios

## Verdict

ACCEPT — N candidates surfaced; user pages through approve/reject decisions.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Multi-pass: per-candidate review ✓
