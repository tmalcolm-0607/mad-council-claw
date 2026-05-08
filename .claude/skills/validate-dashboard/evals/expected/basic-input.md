# Expected output: basic input for /validate-dashboard

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (dashboard JSON parses; schema reference resolvable) passes |
| Step 1 | enumerate tiles + their queries |
| Step 2 | bind each query to schema; flag unresolved fields |
| Step 3 | check coverage vs expected tile set |
| Step 4 | flag stale queries (last_used > 30d if dashboard exposes it) |
| Step 5 | write report to `.mad/reports/validate-dashboard-<ts>.md` |

## Output Contract

- Each tile cites: tile name + query line + binding error if any
- Severity: BLOCKING (query won't run) / MUST-FIX (missing critical tile) / SHOULD-FIX / CONSIDER
- Anti-hallucination: never claim a query "works" without test-binding it
- Empty categories stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS — proposed dashboard fixes; user reviews before apply.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
