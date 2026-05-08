# Expected output: basic input for /council-post

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (channel + thread exist; alias is member; session_id matches) passes |
| Step 1 | scan body against prompt-injection ban list → tag `suspicious: true` if matched |
| Step 2 | enforce body ≤32 KB cap |
| Step 3 | claim next seq (read-modify-write with retry, max 3) |
| Step 4 | write message file `<seq>-<ts>-<alias>.json` (append-only, atomic) |
| Step 5 | update thread.json (last-write-wins on counters) |

## Output Contract

- Confirmation includes: seq, file path, suspicious flag (if any)
- Concurrency: retry on seq collision (up to 3); fail rc=4 on exhaustion
- Body cap enforced; oversized rejected with clear error
- Cross-org A2A consent gate (when transport is a2a-http)

## Verdict

ACCEPT — message seq 52 posted to pivot-rationale.

## Skill features exercised

- Smart-default flow ✓
- Prompt-injection policy (Rule 1) ✓
- Atomic write + retry-on-collision ✓
- Append-only (Rule 1 of concurrency-safety) ✓
- Standards inheritance ✓
