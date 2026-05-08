# Expected output: basic input for /mad-adr

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (`docs/adr/` writable; ADR id derivable) passes |
| Step 1 | derive ADR id (next monotonic) + slug |
| Step 2 | populate template: status, context, decision, consequences, alternatives |
| Step 3 | flag every assumption as `[NEEDS CLARIFICATION]` |
| Step 4 | write to `docs/adr/<id>-<slug>.md` |
| Step 5 | if `--supersede`: update prior ADR to "Superseded by <id>" |

## Output Contract

- ADR fully populated; no skipped sections
- status defaults to `Proposed` (not Accepted) until user changes it
- Anti-hallucination: assumptions explicit
- Empty alternatives stated explicitly

## Verdict

ACCEPT — ADR drafted as `Proposed`; user reviews + changes status.

## Skill features exercised

- Smart-default flow ✓
- Best Practices applied ✓
- Standards inheritance ✓
- Templates applied (ADR template) ✓
