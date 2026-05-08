# Expected output: basic input for /mad-analyze

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (all expected artifacts present + parse) passes |
| Step 1 | enumerate FRs in spec, phases in plan, tasks in tasks |
| Step 2 | cross-reference: every FR maps to ≥1 phase + ≥1 task |
| Step 3 | flag drift: orphan tasks, unaddressed FRs, decisions in research not reflected in plan |
| Step 4 | emit findings with severity tags |
| Step 5 | write analysis to `specs/<N>-feature/analysis-report.md` |

## Output Contract

- Each finding cites: source artifact + line + cross-ref target
- Severity: BLOCKING (FR with no plan coverage) / MUST-FIX (orphan task) / SHOULD-FIX (incomplete cross-ref) / CONSIDER
- Confidence floor enforced
- Anti-hallucination: empty drift categories stated explicitly

## Verdict

ACCEPT or ACCEPT_WITH_CAVEATS depending on findings; REJECT only on BLOCKING.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE on every artifact)
- Standards inheritance ✓
