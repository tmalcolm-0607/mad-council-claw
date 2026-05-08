# Expected output: basic input for /documentation-engineer

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (docs dir exists; codebase reachable) passes |
| Step 1 | enumerate docs + last-touched timestamps |
| Step 2 | grep code for symbols cited in docs; flag unresolved |
| Step 3 | propose patches per doc |
| Step 4 | propose new docs where conventions exist (CONTRIBUTING) |
| Step 5 | write report to `.mad/reports/docs-audit-<ts>.md` |

## Output Contract

- Each patch cites: doc file:line + matching code state
- Severity: BLOCKING (broken example) / MUST-FIX (stale) / SHOULD-FIX (drift) / CONSIDER
- Anti-hallucination: every code reference verified

## Verdict

ACCEPT_WITH_CAVEATS — patches proposed; user reviews + applies.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE)
- Standards inheritance ✓
