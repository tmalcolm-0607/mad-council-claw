# Expected output: basic input for /mad-checklist

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (active feature dir; phase argument valid) passes |
| Step 1 | load tasks.md + plan.md for the active feature |
| Step 2 | emit phase-specific items (gate runs, blocker triage, commit hygiene, etc.) |
| Step 3 | mark each item with status: ✓ / ⏸ / ⚠ |
| Step 4 | flag `[!]` blockers as priority items |

## Output Contract

- Each item cites: source rule or plan task
- Status reflects observable state, not assumptions
- Anti-hallucination: never claim ✓ without evidence

Expected items for implement phase:
- ⚠ 1 task carries `[!]` blocker (per fixture state)
- ⏸ 4 tasks pending
- ⏸ gates not yet run for current changeset
- ⏸ no commit since last task completion

## Verdict

ACCEPT_WITH_CAVEATS — blocker present; user resolves before proceeding.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE on plan + tasks)
- Standards inheritance ✓
