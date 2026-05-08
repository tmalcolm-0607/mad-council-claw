# Template — parallel-wave report

Canonical shape for `/mad-parallel` output. One report per wave dispatched.

> **EXAMPLE — replace this when authoring**

```markdown
# Parallel Wave — <feature-name>

**Date**: <ISO date>
**Wave**: <N of M>
**Tasks dispatched**: T1, T2 [P], T3 [P]

## File ownership map

| Task | Files (owned exclusively) | Agent |
|------|---------------------------|-------|
| T1 | src/api/FooHandler.cs | code-implementer |
| T2 | src/domain/Foo.cs, sources/test/Foo.Tests/FooTests.cs | code-implementer |
| T3 | migrations/060_m3_create_foo.sql | code-implementer |

## File-overlap pre-check

| Pair | Overlap | Decision |
|------|---------|----------|
| T1 ∩ T2 | none | parallel OK |
| T1 ∩ T3 | none | parallel OK |
| T2 ∩ T3 | none | parallel OK |

## Wave outcomes

| Task | Status | Duration | Artifact |
|------|--------|----------|----------|
| T1 | success | 4 min | implementation-report-T1.md |
| T2 | success | 6 min | implementation-report-T2.md |
| T3 | success | 2 min | implementation-report-T3.md |

## Anti-hallucination

- Wave success requires all member subagent successes; never claim wave-success without verifying each
- File ownership conflict triggers sequential fallback per `rules/agent-teams.md`

## Verdict

ACCEPT — wave complete; proceed to next wave (or sequential T4).
```
