# Expected output: basic input for /cosmos-provisioning

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (bicep CLI present, target subscription accessible) passes |
| Step 1 | parse YAML spec; validate required fields |
| Step 2 | emit bicep template with parameter file |
| Step 3 | run bicep lint on emitted template |
| Step 4 | propose deployment commands (no auto-deploy) |
| Step 5 | write artifact to `infra/cosmos/<env>.bicep` |

## Output Contract

- Each container cites: partition-key choice rationale + TTL implication
- Severity: BLOCKING (invalid bicep) / MUST-FIX (missing required field) / SHOULD-FIX
- Anti-hallucination: never claim "deployment succeeded" — emit + lint only
- Empty categories stated explicitly

## Verdict

ACCEPT — bicep emitted + linted clean; user runs deploy.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (ACTUAL BEFORE PRESENT — does not claim deploy)
- Standards inheritance ✓
