# Expected output: basic input for /council-join

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (channel exists; alias not already taken or `--force-reclaim` set) passes |
| Step 1 | bind session_id to alias |
| Step 2 | append member entry to channel.json (atomic write) |
| Step 3 | initialize read-marker for alias |
| Step 4 | optional: register CronCreate poll task |

## Output Contract

- Confirmation includes: channel name, alias, role, session_id |
- If alias collision (without --force-reclaim): rc=2 + clear message + held-by info |
- Concurrency-safety: atomic write on channel.json |
- Standards inheritance ✓

## Verdict

ACCEPT — Skeptic joined service-redesign.

## Skill features exercised

- Smart-default flow ✓
- session_id binding ✓
- Force-reclaim consent gate (when triggered) ✓
- Atomic write ✓
