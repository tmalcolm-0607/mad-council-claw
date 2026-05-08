# Expected output: basic input for /check-environment-health

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (az CLI present, subscription accessible) passes |
| Step 1 | enumerate expected resources from environment name |
| Step 2 | parallel probe: existence, RBAC, runtime health |
| Step 3 | categorize each: GREEN / YELLOW / RED |
| Step 4 | for RED, query App Insights for recent errors (last 1h) |
| Step 5 | write report to `.mad/reports/env-health-<env>-<ts>.md` |

## Output Contract

- Each resource cites: status + last-checked time + evidence URL
- Severity: BLOCKING (RED) / MUST-FIX (YELLOW) / SHOULD-FIX (perf drift) / CONSIDER
- Anti-hallucination: never claim "healthy" without an actual probe response
- Empty categories stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS if any YELLOW; REJECT if any RED.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (ACTUAL BEFORE PRESENT, FETCH BEFORE CITE)
- Standards inheritance ✓
