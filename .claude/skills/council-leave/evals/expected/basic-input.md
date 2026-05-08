# Expected output: basic input for /council-leave

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (alias is member; session_id matches) passes |
| Step 1 | check ownership: leaver is NOT owner → no transfer required |
| Step 2 | emit Completion Report → `<channel>/leave-reports/<alias>-<ts>.json` |
| Step 3 | remove member entry (atomic write) |
| Step 4 | teardown session-local CronCreate poll task |

## Output Contract

- Completion Report includes: contribution log, leave reason (optional), final state |
- If leaver is owner without prior OWNERSHIP_TRANSFER verdict: REJECT with `OWNER_LEAVING_WITHOUT_TRANSFER` |
- If leaver is last active member: consent gate (archive channel? yes/no) |

## Verdict

ACCEPT — Skeptic left service-redesign; Completion Report written.

## Skill features exercised

- Smart-default flow ✓
- Single-owner accountability rule ✓
- Dangerous-operations consent gate (last-member case) ✓
- Atomic write ✓
