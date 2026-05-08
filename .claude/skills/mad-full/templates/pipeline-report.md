# Template — full-pipeline report

Canonical shape for `/mad-full` output. End-to-end MAD chain summary with per-phase verdicts.

> **EXAMPLE — replace this when authoring**

```markdown
# Full MAD Pipeline — <feature-name>

**Idea source**: specs/ideas/<slug>.md
**Final feature dir**: specs/<N>-<slug>/
**Date**: <ISO date>

## Per-phase verdicts

| Phase | Verdict | Artifact | Review gate |
|-------|---------|----------|-------------|
| spec | ACCEPT | spec.md | passed (3 reviewers) |
| testplan | ACCEPT | test-plan.md | passed |
| plan | ACCEPT_WITH_CAVEATS | plan.md | 1 SHOULD-FIX (deferred) |
| tasks | ACCEPT | tasks.md | passed |
| analyze | ACCEPT | analysis-report.md | 0 orphan FRs |
| implement | ACCEPT | per-task reports | gates green |
| validate | ACCEPT | validation-report.md | all FRs verified |
| apply-learnings | ACCEPT | patterns.json | 1 candidate captured |

## Halts

(empty — full pipeline ran clean)

OR:

- **HALT after analyze**: 2 BLOCKING orphan FRs. Returned to /mad-spec.

## Anti-hallucination

- Each phase verdict cites: review-gate output + artifact path
- Never auto-ACCEPT without explicit gate passes
- HALT is a first-class outcome, not a failure mode

## Verdict

ACCEPT — full pipeline complete; ready for PR.
```
