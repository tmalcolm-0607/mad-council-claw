# Expected output: basic input for /mad-decompose

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight passes |
| Step 1.5 WorkIQ | auto-trigger if input references work item |
| Step 1.6 risk score | computed; mode auto-selected |
| Workflow | each step in skill body executed |

## Output Contract

- Severity tags on every finding
- Confidence floor applied (BLOCKING ≥80, MUST-FIX ≥70, SHOULD-FIX ≥60)
- Cited rule per finding
- Anti-hallucination: empty categories stated explicitly

## Verdict

ACCEPT (or whatever the skill's natural completion state is)

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
