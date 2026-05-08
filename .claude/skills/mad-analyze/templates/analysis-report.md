# Template — analysis-report.md

Canonical shape for `/mad-analyze` output. Cross-artifact consistency analysis between spec, plan, tasks, research; produces a punch list of gaps and orphans before implementation begins.

> **EXAMPLE — replace this when authoring**

```markdown
# Analysis Report — <feature-name>

**Spec**: specs/<N>-<slug>/spec.md
**Plan**: specs/<N>-<slug>/plan.md
**Tasks**: specs/<N>-<slug>/tasks.md
**Research**: specs/<N>-<slug>/research.md
**Date**: <ISO date>

## Summary

| Category | Count |
|----------|-------|
| FRs | N |
| Phases | M |
| Tasks | T |
| FRs without phase coverage | A |
| Phases without task coverage | B |
| Tasks orphaned (no FR mapped) | C |
| Research decisions not in plan | D |

## Cross-reference matrix

| FR | Phase(s) | Task(s) | Test(s) |
|----|----------|---------|---------|
| FR-1 | P1, P2 | T1, T3 | TEST-1 |
| FR-2 | P1 | T2 | (none) ⚠ |
| FR-3 | (none) ⚠ | (none) ⚠ | (none) ⚠ |

## Findings

### BLOCKING: FRs without coverage

- FR-3: not addressed in any phase. Either add coverage or move to deferred.

### MUST-FIX: orphan tasks

- T7: not mapped to any FR. Either add the missing FR or remove the task.

### SHOULD-FIX: research decisions not reflected

- research.md notes "we picked Foo over Bar because of throughput", but plan.md doesn't mention Foo. Update plan.

### CONSIDER: ordering

- Phase 3 lists T9 before T8 but T8 produces input for T9. Reorder.

## Verdict

ACCEPT | ACCEPT_WITH_CAVEATS | REJECT

If REJECT, return to /mad-spec or /mad-plan to address gaps before /mad-implement begins.
```

## Anti-hallucination

Every cited line in the cross-reference matrix must come from a Read of the source artifact. Don't infer FR coverage from plan-phase names alone.

## Reference templates

- `mad-spec/templates/spec.md` — input
- `mad-plan/templates/plan.md` — input
- `mad-tasks/templates/tasks.md` — input
