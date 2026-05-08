# Expected output: basic input for /debate

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (positions enumerable, rubric defined) passes |
| Step 1 | open: each position's strongest claim |
| Step 2 | rounds: rebut, defend, advance — N rounds |
| Step 3 | devil's-advocate pass (if enabled): challenge consensus |
| Step 4 | synthesize: where positions agree, where they diverge, recommended path |
| Step 5 | write transcript + synthesis to `.mad/reports/debate-<ts>.md` |

## Output Contract

- Each round cites prior round's claim being addressed (no straw-manning)
- Synthesis includes: agreed-on facts, unresolved questions, recommended next step
- Anti-hallucination: factual claims (latency, cost, throughput) flagged if unsupported
- Empty rebuttals stated explicitly ("Pro-Service Bus had no rebuttal to claim X.")

## Verdict

ACCEPT — debate complete; synthesis returned for user decision.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Multi-pass: rounds + devil's-advocate ✓
