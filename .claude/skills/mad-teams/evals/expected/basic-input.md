# Expected output: basic input for /mad-teams

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (`agent-teams-config.json:enabled=true`; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) passes |
| Step 1 | apply decision rule: ≥3 independent tasks + disjoint files + ≥30 min total + no inter-step judgment? → team |
| Step 2 | assign file ownership per teammate (no overlap) |
| Step 3 | spawn lead + 3 teammates |
| Step 4 | lead reviews each teammate's plan before modifications |
| Step 5 | lead runs gates after all teammates complete |
| Step 6 | revert to subagents on kill conditions (<1.5x speedup, file conflict, hang) |

## Output Contract

- Each teammate cites: scope, files owned, model, estimated duration
- Cost multiplier reported ahead of spawn
- Kill conditions documented per `rules/agent-teams.md`
- Anti-hallucination: never claim team success without lead's gates pass

## Verdict

ACCEPT — team dispatched; lead synthesizes.

## Skill features exercised

- Smart-default flow ✓
- agent-teams rule applied ✓
- File ownership protocol ✓
- Standards inheritance ✓
