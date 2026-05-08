# Expected output: basic input for /council-resolve

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (verdict.json exists + parses; thread.json exists) passes |
| Step 1 | read verdict; verify issuer authorization (per role) |
| Step 2 | apply state change per verdict.type:
   - ACCEPT: thread.status = resolved
   - FIX: thread.status = fix-pending; surface findings list
   - ESCALATE: thread.status = escalated; emit user-facing prompt
   - OWNERSHIP_TRANSFER: rewrite channel.json:owner_alias atomically + log resolution |
| Step 3 | record `resolved_utc` + `resolution_outcome` on verdict |
| Step 4 | atomic write of thread.json + (if OWNERSHIP_TRANSFER) channel.json |

## Output Contract

- Confirmation includes: verdict type applied, new thread.status, optional follow-up
- For OWNERSHIP_TRANSFER: resolution preserves verdict history; channel.json:owner_alias updated atomically
- For FIX: findings surfaced as a punch list
- Concurrency-safety: atomic writes throughout

## Verdict

ACCEPT — pivot-rationale resolved as ACCEPT; SHOULD-FIX finding surfaced for follow-up.

## Skill features exercised

- Smart-default flow ✓
- Single-owner-accountability (OWNERSHIP_TRANSFER path) ✓
- Last-write-wins on thread.json (per concurrency-safety §4) ✓
- Atomic write ✓
- Standards inheritance ✓
