# Expected output: basic input for /skill-refresh

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (target skill dir exists + frontmatter parses) passes |
| Step 1 | run skill-audit subset on target → score 6 dimensions |
| Step 2 | for each missing/weak dimension, propose patch from `_template/` |
| Step 3 | apply tier-exempt rules (don't propose evals for pure utilities) |
| Step 4 | user-confirm before apply |
| Step 5 | apply patches; re-audit to verify tier improvement |

## Output Contract

- Each proposed patch cites: gap dimension + reference template + expected tier delta
- Severity: BLOCKING (broken frontmatter) / MUST-FIX (missing BP/Standards for non-exempt) / SHOULD-FIX (eval scaffold) / CONSIDER (Copilot CLI mode)
- Confidence floor enforced

## Verdict

ACCEPT_WITH_CAVEATS — N patches proposed; user reviews before apply.

Expected for `mad-c4`:
- SHOULD-FIX: missing eval fixtures
- CONSIDER: missing templates dir
- CONSIDER: missing multi-pass mode

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Multi-pass: audit → propose → re-audit ✓
