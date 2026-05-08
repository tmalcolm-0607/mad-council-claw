# Expected output: basic input for /resume-handoff

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (`PENDING_HANDOFF` artifact present + parses) passes |
| Step 1 | read handoff: last task, blockers, next-action |
| Step 2 | re-read plan.md / tasks.md to verify state hasn't drifted |
| Step 3 | acknowledge blockers explicitly |
| Step 4 | resume from next-action recommendation (or ask user if state unclear) |
| Step 5 | clear `PENDING_HANDOFF` only after resume confirmed |

## Output Contract

- Confirmation includes: prior task, blocker list, next action
- Anti-hallucination: never claim resumed without re-reading source-of-truth files
- If state is incoherent: report drift and ask before proceeding

## Verdict

ACCEPT — session resumed from handoff.

## Skill features exercised

- Smart-default flow ✓
- Resume protocol applied ✓
- Standards inheritance ✓
