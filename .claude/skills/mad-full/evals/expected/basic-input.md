# Expected output: basic input for /mad-full

## Smart-default flow

| Step | Result |
|------|--------|
| Step 0 | preflight (idea.md exists; review-gate config readable) passes |
| Step 1 | run /mad-spec → contract spec.md |
| Step 2 | run /testplan --source spec auto → test-plan.md |
| Step 3 | run /mad-plan → plan.md |
| Step 4 | run /mad-tasks → tasks.md |
| Step 5 | run /mad-analyze → analysis-report.md |
| Step 6 | run /mad-implement → execution + commits per task |
| Step 7 | run /mad-validate → validation report |
| Step 8 | run /apply-learnings → patterns captured |

## Output Contract

- Each phase cites: input/output artifacts + review-gate verdict
- Halts on first BLOCKING finding from any review gate
- Anti-hallucination: never claim a phase complete without checking for `[!]` blockers
- Multi-pass: each phase has its own self-check

## Verdict

ACCEPT_WITH_CAVEATS or REJECT depending on gate findings; never auto-ACCEPT without explicit review-gate passes.

## Skill features exercised

- Smart-default flow ✓
- Multi-pass: 8 chained phases ✓
- Standards inheritance ✓
- Review gate protocol applied at each phase boundary ✓
