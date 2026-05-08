# Expected output: basic input for /testplan

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (spec.md exists + parses; FRs enumerated) passes |
| Step 1 | derive scenarios from each FR (happy path + edge + error) |
| Step 2 | classify: unit / integration / e2e / non-functional |
| Step 3 | flag NFRs (latency targets, throughput, availability) |
| Step 4 | emit `specs/<N>-feature/test-plan.md` |

## Output Contract

- Each scenario cites: source FR + level + acceptance criteria
- Coverage: every FR has ≥1 happy path scenario + ≥1 error scenario
- Anti-hallucination: never invent FRs not in spec
- Empty scenarios stated explicitly per FR (gap signal)

## Verdict

ACCEPT — test plan emitted; ready for /mad-plan.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Templates applied ✓
