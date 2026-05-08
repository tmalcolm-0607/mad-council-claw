# Expected output: basic input for /workiq-scan

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (WorkIQ MCP reachable; auth valid) passes |
| Step 1 | issue query with target topic |
| Step 2 | on 429/transport-dropped, back off (10m → 30m → 60m cap) |
| Step 3 | persist results per query to disk; survive session restarts |
| Step 4 | render summary with citations |

## Output Contract

- Each citation cites: WorkIQ message ID + author + ts
- On WorkIQ unreachable: emit Context Gaps section per `degradation-fallback-policy.md`
- Anti-hallucination: never fabricate WorkIQ content
- Empty result stated explicitly

## Verdict

ACCEPT — context gathered (or ACCEPT_WITH_CAVEATS with Context Gaps when WorkIQ degraded).

## Skill features exercised

- Smart-default flow ✓
- Throttle-aware backoff ✓
- Degradation-fallback policy ✓
- Standards inheritance ✓
