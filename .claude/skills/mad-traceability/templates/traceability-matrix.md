# Template — traceability matrix

Canonical shape for `/mad-traceability` output. FR → phase → task → test mapping.

> **EXAMPLE — replace this when authoring**

```markdown
# Traceability Matrix — <feature-name>

**Spec**: specs/<N>-<slug>/spec.md
**Plan**: specs/<N>-<slug>/plan.md
**Tasks**: specs/<N>-<slug>/tasks.md
**Test plan**: specs/<N>-<slug>/test-plan.md
**Date**: <ISO date>

## FR coverage

| FR | Description (excerpt) | Phase | Task(s) | Test(s) | Verified? |
|----|----------------------|-------|---------|---------|-----------|
| FR-1 | <excerpt> | P1 | T1, T3 | UT-1, IT-1 | ✓ |
| FR-2 | <excerpt> | P1 | T2 | UT-2 | ✓ |
| FR-3 | <excerpt> | (none) ⚠ | (none) ⚠ | (none) ⚠ | ✗ orphan |

## Orphans

| Type | ID | Issue |
|------|----|----|
| FR | FR-3 | not addressed in any phase |
| Task | T7 | not mapped to any FR |

## Severity

- BLOCKING: orphan FRs (won't be implemented)
- BLOCKING: orphan FRs without tests (silent regression risk)
- MUST-FIX: orphan tasks (waste of effort)

## Anti-hallucination

- Each cell value comes from Read of source artifacts; never inferred
- Empty cells (per FR) stated explicitly

## Verdict

ACCEPT_WITH_CAVEATS or REJECT depending on orphan count + severity.
```

## Reference

- `mad-analyze/templates/analysis-report.md` — same input set, narrative format
