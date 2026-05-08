# Expected output: basic input for /code-audit

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (target dir exists; rules dir parsable) passes |
| Step 1 | enumerate source files; categorize by language |
| Step 2 | apply convention checks per language patterns |
| Step 3 | emit findings with severity tags |
| Step 4 | write report to `.mad/reports/code-audit-<ts>.md` |

## Output Contract

- Each finding cites: file:line + matched rule + suggested fix
- Severity: BLOCKING / MUST-FIX / SHOULD-FIX / CONSIDER / PRAISE
- Confidence floor enforced
- Empty categories stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS — typical sweep surfaces SHOULD-FIX items.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE)
- Standards inheritance ✓
