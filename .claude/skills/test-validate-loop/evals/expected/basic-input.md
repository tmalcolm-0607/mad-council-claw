# Expected output: basic input for /test-validate-loop

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (test project builds; runner available) passes |
| Step 1 | run tests; capture failures |
| Step 2 | classify: regression / pre-existing / infra |
| Step 3 | propose targeted fix per failure |
| Step 4 | apply fix; re-run only failing tests (`--filter`) |
| Step 5 | loop until green or stop condition |

## Output Contract

- Each iteration cites: failures fixed, failures remaining, files touched
- Bounded iteration cap enforced
- Anti-hallucination: never claim green without test runner output
- Pre-existing failures tracked separately (not dismissed)

## Verdict

ACCEPT — green achieved (or REJECT with retained failure list if stop condition hit).

## Skill features exercised

- Smart-default flow ✓
- Bounded loop ✓
- test-failure-protocol applied ✓
- Standards inheritance ✓
