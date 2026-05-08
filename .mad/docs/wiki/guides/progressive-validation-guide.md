# Progressive Validation Guide

Intelligent test selection reduces development feedback time from minutes to seconds while maintaining comprehensive PR gate validation.

## Validation Tiers

| Tier | Scope | When to Use | Time | Command |
|------|-------|-------------|------|---------|
| **0** | TDD Red/Green | Single test during TDD | <1s | `dotnet test --filter FullyQualifiedName~Class.Method` |
| **1** | Fast Unit | After small changes | 1-5s | `dotnet test --filter "Category=Unit&Speed=Fast"` |
| **2** | Full Unit | After business logic changes | 1-2m | `dotnet test --filter "Category=Unit\|Category=DatabaseUnit"` |
| **3** | Core + Integration | After API/integration changes | 2-5m | `dotnet test --filter "Category!=E2E"` |
| **4** | Full Suite | **PR gate only** | 5-10m | `dotnet test` (all tests) |
| **5a** | E2E Smoke (@p0) | **Every UI feature phase gate** | 30s-1min | `npm run test:e2e -- --grep @p0` |
| **5b** | E2E Critical | **Pre-merge (PR gate)** | 2-5min | `npm run test:e2e -- --grep "@p0\|@p1"` |
| **5c** | E2E Full Suite | **Pre-release only** | 5-10min | `npm run test:e2e` |

## Backend Workflow

`/mad-implement` Phase 5.5 invokes `test-selector` agent to determine tier (0-4) based on changed files.

## Frontend Workflow

- **During implementation**: Tier 5a (smoke tests only) - 100% pass required
- **During `/mad-validate`**: Tier 5c (full E2E suite) - >=90% pass rate required
- **Never during development**: Full E2E suite too slow

## Override Flags

- `--mad-full-suite`: Bypass test selection, run Tier 4 (backend)
- `--mad-skip-e2e`: Skip E2E smoke tests (non-UI changes only)

## Prerequisites

- Backend: Tests annotated with `[Trait("Category", "Unit")]`, `[Trait("Speed", "Fast")]`
- Frontend: E2E tests annotated with `@p0` smoke, `@p1` critical, `@p2` regression
- See `.claude/rules/patterns/quality-gates-dotnet.md` and `.claude/rules/e2e-testing-patterns.md`

## References

- `.claude/rules/quality-gates.md` - Full quality gates specification with enforcement rules
- `.claude/agents/test-selector.md` - Test selector agent definition
