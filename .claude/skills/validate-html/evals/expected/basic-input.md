# Expected output: basic input for /validate-html

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (browser/playwright available; URL or file resolvable) passes |
| Step 1 | load page; capture console errors + network failures |
| Step 2 | run a11y rules (alt, label, role, contrast) |
| Step 3 | check for broken in-page links + 404s |
| Step 4 | screenshot for visual diff (smart-default) |
| Step 5 | write report to `.mad/reports/validate-html-<ts>.md` |

## Output Contract

- Each finding cites: DOM path / URL + WCAG rule (when a11y) + evidence snippet
- Severity: BLOCKING (broken link, missing alt on critical img) / MUST-FIX / SHOULD-FIX / CONSIDER
- Confidence floor enforced
- Empty categories stated explicitly ("No console errors captured.")

## Verdict

ACCEPT_WITH_CAVEATS if any MUST-FIX; REJECT if any BLOCKING.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
