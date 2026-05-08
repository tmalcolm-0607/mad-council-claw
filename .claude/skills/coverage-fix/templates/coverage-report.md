# Template — coverage-fix report

Canonical shape for `/coverage-fix` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Coverage Fix — <feature-name>

**Date**: <ISO date>
**Initial diff coverage**: 78% (target 100%)
**Final diff coverage**: 100%

## Per-iteration

| Iter | Tests added | Lines covered | Remaining | Verdict |
|------|-------------|----------------|-----------|---------|
| 1 | 4 | 6 | 6 | progress |
| 2 | 3 | 4 | 2 | progress |
| 3 | 2 | 2 | 0 | green |

## Tests added

| File | Test | Lines covered |
|------|------|---------------|
| sources/test/Foo.Tests/FooHandlerTests.cs | NullInput_ReturnsBadRequest | 42-44 |
| sources/test/Foo.Tests/FooHandlerTests.cs | InvalidPayload_Returns422 | 47-50 |

## Excluded with justification

| File:Line | Reason |
|-----------|--------|
| FooHandler.cs:88 | exception-only guard for impossible state; covered by integration test path implicitly |

## Anti-hallucination

- Coverage % verified against ADO Update tab, not local Measure-DiffCoverage (per CLAUDE.md note)
- Bounded loop: kill at 5 iterations or no-progress-for-2

## Verdict

ACCEPT — 100% diff coverage achieved.
```
