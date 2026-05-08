# Expected output: basic input for /coverage-fix

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (gates have run; coverage XML present) passes |
| Step 1 | parse coverage; enumerate uncovered lines |
| Step 2 | author targeted tests for each gap |
| Step 3 | run gates; re-measure |
| Step 4 | iterate until target met or no further progress |
| Step 5 | exclude lines with explicit justification (e.g. exception-only paths) |

## Output Contract

- Each new test cites: file:line covered + scenario asserted
- Anti-hallucination: never claim 100% without ADO coverage check (per CLAUDE.md note)
- Bounded iteration cap (kill condition if no improvement after 2 rounds)

## Verdict

ACCEPT — coverage improved 78% → 100%; tests added; gates green.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (ACTUAL BEFORE PRESENT, bounded loop)
- Standards inheritance ✓
- Multi-pass: write → measure → iterate ✓
