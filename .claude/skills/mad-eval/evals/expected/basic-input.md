# Expected output: basic input for /mad-eval

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (target skill exists; evals/ dir present) passes |
| Step 1 | discover fixtures + matching expected files |
| Step 2 | run structural runner (test.ps1) |
| Step 3 | for each fixture: pass / fail with reason |
| Step 4 | aggregate to pass/fail summary |
| Step 5 | write report to `.mad/reports/mad-eval-<skill>-<ts>.md` |

## Output Contract

- Each fixture row cites: name + status + reason if failing
- Anti-hallucination: never claim PASS without test runner output
- Empty fixtures dir stated explicitly

## Verdict

ACCEPT — all fixtures pass.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (ACTUAL BEFORE PRESENT)
- Standards inheritance ✓
- Multi-pass: discover → run → aggregate ✓
