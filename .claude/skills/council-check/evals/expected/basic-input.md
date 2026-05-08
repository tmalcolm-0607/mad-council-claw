# Expected output: basic input for /council-check

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (channel exists, member is registered, session_id matches) passes |
| Step 1 | read seq.json + read-marker for current alias |
| Step 2 | enumerate unread messages |
| Step 3 | apply prompt-injection scan (Rule 1 of policy) per message body |
| Step 4 | render digest with ⚠️ flags on suspicious content |
| Step 5 | update read-marker atomically |

## Output Contract

- Each message rendered with: seq, ts, from.alias, body
- Suspicious-flag prefix on any message body matching prompt-injection ban list
- Context Gaps section if any source unavailable
- Anti-hallucination: never fabricate messages; empty unread state stated explicitly

## Verdict

ACCEPT — 4 unread messages rendered; read-marker advanced to seq 51.

## Skill features exercised

- Smart-default flow ✓
- Prompt-injection policy applied ✓
- Concurrency-safety (atomic read-marker write) ✓
- Standards inheritance ✓
