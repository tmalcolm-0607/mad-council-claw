# Expected output: basic input for /repo-sync

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (both repos exist, both writable, git clean) passes |
| Step 1 | enumerate source + target file sets |
| Step 2 | diff: missing, modified, conflicting |
| Step 3 | propose patch list with severity per file |
| Step 4 | user-confirm before write (smart-default consent gate) |
| Step 5 | apply, write report to `.mad/reports/repo-sync-<ts>.md` |

## Output Contract

- Each file cites: source hash + target hash + size delta
- Severity: BLOCKING (conflict) / MUST-FIX (missing) / SHOULD-FIX (modified) / CONSIDER (cosmetic)
- Empty categories stated explicitly
- Confidence floor enforced

## Verdict

ACCEPT_WITH_CAVEATS — patches proposed; user must approve before write.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
