# Expected output: basic input for /council-list

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (channels root readable) passes |
| Step 1 | enumerate channels where current session is a registered member |
| Step 2 | per channel: alias, role, unread count, last activity, status |
| Step 3 | render compact table |

## Output Contract

- Each channel row cites: name, alias-as-which, role, unread, last_seq, status
- Empty result stated explicitly ("Not a member of any council channel.")
- Anti-hallucination: never list channels you didn't enumerate from disk

## Verdict

ACCEPT — 2 channels listed.

## Skill features exercised

- Smart-default flow ✓
- Invite-only discovery (only show channels where session is a member) ✓
- Standards inheritance ✓
