# Template — tasks.md

Canonical shape for `/mad-tasks` output. Tasks are atomic units that map 1:1 to a subagent invocation.

> **EXAMPLE — replace this when authoring**

```markdown
# Tasks — <feature-name>

**Plan**: specs/<N>-<slug>/plan.md
**Date**: <ISO date>

## Conventions

- `[ ]` pending, `[x]` done, `[!]` blocked
- `[P]` parallel-eligible (disjoint files; runs concurrently with other `[P]` tasks in the same wave)
- Each task names: target file scope + acceptance criterion + estimated subagent type

## Phase 1: <name>

- [ ] T1: Implement `FooHandler.Post`
  - Files: `src/api/FooHandler.cs`, `src/domain/Foo.cs`
  - Acceptance: xUnit `FooHandlerTests.HappyPath` passes
  - Agent: `code-implementer`

- [ ] T2 [P]: Add `Foo` migration 060
  - Files: `migrations/060_m3_create_foo.sql`
  - Acceptance: migration applies + reverts cleanly on local PG
  - Agent: `code-implementer`

- [ ] T3 [P]: Wire `IFooRepository` registration
  - Files: `src/api/ServiceCollectionExtensions.cs`
  - Acceptance: DI smoke test passes; no captive-dependency warning
  - Agent: `code-implementer`

## Phase 2: <name>

(same shape)

## Blockers

(none — populate via `[!]` when discovered)

## Acceptance gates per phase

| Phase | Gate |
|-------|------|
| 1 | `dotnet test sources/test/Foo.Tests/Foo.Tests.csproj` green |
| 2 | Integration test `IntegrationTests.Foo.EndToEnd` green |
```

## Atomicity rule

A task is atomic if it can be done by one subagent invocation in one round, with one acceptance criterion. If you find yourself writing "and also" or "then", split.

## File-ownership rule

`[P]` tasks in the same wave MUST own disjoint files. The orchestrator detects overlap and falls back to sequential execution if not.

## Reference templates

- `mad-plan/templates/plan.md` — upstream input
- `mad-implement/templates/implementation-report.md` — downstream output per task
