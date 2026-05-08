# Template — implementation-report.md

Canonical shape for per-task implementation reports written by `/mad-implement`. One report per completed task; aggregated into the work-item directory.

> **EXAMPLE — replace this when authoring**

```markdown
# Implementation Report — T<N>

**Task**: <verbatim task line from tasks.md>
**Phase**: <phase name>
**Date**: <ISO date>
**Agent**: <subagent type used>
**Duration**: <minutes>

## What changed

| File | Action | Lines |
|------|--------|-------|
| src/api/FooHandler.cs | new | +84 |
| src/domain/Foo.cs | modified | +12/-3 |
| sources/test/Foo.Tests/FooHandlerTests.cs | new | +57 |

## Acceptance criterion

> <verbatim acceptance line from the task>

**Verified**: ✓ | ✗
**Evidence**: <test runner output excerpt OR behavioural probe response>

## Quality gates

- [ ] Build green (`dotnet build`)
- [ ] Test project green (`dotnet test --filter`)
- [ ] Bicep lint (if .bicep changed)
- [ ] No new pre-existing failures introduced

## Issues encountered

<Brief notes on anything non-trivial. Cite the rule or pattern that resolved it.>

## Follow-ups

- [ ] Coverage gap on error path (FU-1)
- [ ] Address SHOULD-FIX from /code-reviewer (FU-2)
```

## Anti-hallucination requirement

If acceptance is `✗`, do NOT mark the parent task `[x]` in tasks.md. Mark `[!]` and surface as blocker.

## Reference templates

- `mad-tasks/templates/tasks.md` — upstream input
- `mad-validate/templates/validation-report.md` — downstream input
