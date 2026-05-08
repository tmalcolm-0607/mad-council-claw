# Expected output: basic input for /mad-parallel

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (tasks.md exists; `[P]` markers parsed) passes |
| Step 1 | enumerate parallel groups; check file ownership disjoint per `rules/agent-teams.md` |
| Step 2 | dispatch wave: 3 concurrent code-implementer subagents (T1, T2, T3) |
| Step 3 | join: wait for all 3; aggregate results |
| Step 4 | proceed to T4 only after all parallel members report success |
| Step 5 | update plan.md checkboxes |

## Output Contract

- Each wave cites: task IDs + file ownership + duration
- File-ownership conflict detection: sequential fallback if overlap
- Anti-hallucination: never claim wave success without subagent results
- Concurrency-safety on plan.md updates

## Verdict

ACCEPT — wave 1 (3 tasks) succeeded; T4 dispatched sequentially.

## Skill features exercised

- Smart-default flow ✓
- agent-teams rule applied (file ownership protocol) ✓
- Concurrency-safety on plan.md ✓
- Standards inheritance ✓
