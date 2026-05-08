# Expected output: basic input for /mad-traceability

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (feature dir contains spec.md, plan.md, tasks.md) passes |
| Step 1 | enumerate FRs from spec.md |
| Step 2 | enumerate phases from plan.md |
| Step 3 | enumerate tasks from tasks.md |
| Step 4 | enumerate tests from test-plan.md |
| Step 5 | cross-reference; flag orphans (FR with no plan / task / test) |
| Step 6 | write matrix to `specs/3-feature-foo/traceability-matrix.md` |

## Output Contract

- Each FR row cites: matching plan phases, tasks, tests
- Orphan FRs flagged BLOCKING (won't be implemented or won't be tested)
- Anti-hallucination: empty test column stated explicitly per FR
- Confidence floor enforced

## Verdict

ACCEPT_WITH_CAVEATS — 2 newly-added FRs lack plan coverage; user must address.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE)
- Standards inheritance ✓
