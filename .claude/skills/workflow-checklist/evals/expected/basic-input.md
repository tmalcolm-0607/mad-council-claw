# Expected output: basic input for /workflow-checklist

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (active WI exists; phase argument valid) passes |
| Step 1 | load WI state + read applicable rules |
| Step 2 | derive checklist items from rule citations |
| Step 3 | check current state vs each item; mark satisfied/pending |
| Step 4 | emit checklist with status per item + cited rule |

## Output Contract

- Each checklist item cites: rule file + section
- Status per item: ✓ (verified) / ⏸ (pending action) / ⚠ (uncertain — needs verification)
- Anti-hallucination: never claim ✓ without an actual probe
- Empty rule sets stated explicitly

Expected items for pre-pr:
- ✓ branch on personal namespace (`users/<alias>/...`)
- ✓ commits follow conventional format
- ⏸ full gate suite passing (run `Run-DotnetGates.ps1` to verify)
- ⏸ user explicit approval for push
- ⏸ no `--no-verify` or `--amend` shortcuts taken

## Verdict

ACCEPT_WITH_CAVEATS — N items pending user action before PR is safe.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓ (FETCH BEFORE CITE on rules)
- Standards inheritance ✓
