# Expected output: basic input for /refresh-references

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (`references/` exists, git present) passes |
| Step 1 | auto-enumerate every immediate-child repo in `references/` |
| Step 2 | parallel `git fetch --all --prune` per repo |
| Step 3 | per-repo summary: ahead/behind, new branches, last commit |
| Step 4 | aggregate report written to `.mad/reports/references-refresh-<ts>.md` |

## Output Contract

- One line per repo with status (UP-TO-DATE / UPDATED / FETCH-FAILED)
- Failed repos cited explicitly with error
- Empty `references/` stated explicitly, not silently passed

## Verdict

ACCEPT — references refreshed; report path returned to caller.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (parallel fetch, summary, anti-hallucination)
- Standards inheritance ✓
