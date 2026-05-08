# Expected output: basic input for /claude-md-refresh

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (CLAUDE.md present, rules dir exists) passes |
| Step 1 | enumerate sections in CLAUDE.md + last-touched timestamps |
| Step 2 | enumerate rules drift since last CLAUDE.md update |
| Step 3 | identify stale references (paths, script names, deprecated commands) |
| Step 4 | propose targeted patches per section |
| Step 5 | write patch report to `.mad/reports/claude-md-refresh-<ts>.md` |

## Output Contract

- Severity tags: BLOCKING (broken paths) / MUST-FIX (drift) / SHOULD-FIX (clarity) / CONSIDER (polish)
- Each patch cites: matching rule file + line, or current code state
- Confidence floor enforced
- Empty categories stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS — patches proposed; user must approve before apply.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE, MATCH EXISTING STYLE)
- Standards inheritance ✓
- Anti-hallucination check ✓
