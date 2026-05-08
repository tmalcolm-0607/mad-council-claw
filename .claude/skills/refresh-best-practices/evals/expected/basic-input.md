# Expected output: basic input for /refresh-best-practices

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight passes (rules dir + best-practices dir exist) |
| Step 1 | enumerate current rules + last-updated dates |
| Step 2 | gather external signals (marketplace, web, citations) |
| Step 3 | diff: stale rules vs new patterns |
| Step 4 | propose patches with severity tags |
| Step 5 | write report to `.mad/reports/best-practices-refresh-<ts>.md` |

## Output Contract

- Severity tags: BLOCKING / MUST-FIX / SHOULD-FIX / CONSIDER / PRAISE
- Each proposed patch cites: source URL or marketplace plugin path
- Confidence floor: SHOULD-FIX ≥60, MUST-FIX ≥70
- Empty categories stated explicitly ("No CRITICAL drift detected.")

## Verdict

ACCEPT_WITH_CAVEATS — N proposed patches awaiting user approval before apply.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE on every external source)
- Standards inheritance ✓
- Anti-hallucination check ✓
