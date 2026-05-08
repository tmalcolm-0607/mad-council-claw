# Expected output: basic input for /validate-features

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (feature endpoints reachable) passes |
| Step 1 | enumerate behavioral expectations from spec |
| Step 2 | run probes against deployed feature |
| Step 3 | compare actual vs expected |
| Step 4 | classify failures: structural / behavioral / wiring |
| Step 5 | emit verdict with evidence |

## Output Contract

- Each probe cites: spec section + actual response + expected response
- Severity: BLOCKING (silent feature) / MUST-FIX (wrong behavior) / SHOULD-FIX
- Anti-hallucination: NEVER claim feature works without probe response evidence
- "Tests pass" is not equivalent to "feature works"

## Verdict

REJECT — behavioral defect detected (200 instead of 400 on malformed JSON); structural tests passing is not sufficient.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (ACTUAL BEFORE PRESENT)
- Standards inheritance ✓
