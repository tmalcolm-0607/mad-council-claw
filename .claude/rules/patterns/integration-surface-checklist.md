---
paths:
  - "**/*.cs"
  - "**/spec.md"
  - "**/plan.md"
  - "**/tasks.md"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# Integration Surface Checklist

Ensures integration points are complete — not stubbed, not orphaned, not missing wiring.

## Stub Patterns to Watch

These patterns indicate incomplete integration surfaces. Flag during review:

| Pattern | Language | Severity |
|---------|----------|----------|
| `throw new NotImplementedException()` | C# | REJECT in non-test code |
| `TODO: implement`, `TODO: wire up`, `TODO: real API` | Any | WARN (integration gap) |
| `FIXME: stub`, `HACK: placeholder` | Any | WARN (integration gap) |
| `throw new Error("not implemented")` | TypeScript | REJECT in non-test code |
| `pass  # TODO` | Python | WARN |
| `panic("not implemented")` | Go | REJECT in non-test code |

## DI Registration Completeness

When a new interface is defined, verify:

1. **Implementation exists**: At least one concrete class implements the interface
2. **Registration exists**: The implementation is registered in the DI container (e.g., `AddScoped<IFoo, Foo>()`)
3. **Lifetime is correct**: Matches the project convention (check `dotnet-di-patterns.md`)

| Check | Detection | Action |
|-------|-----------|--------|
| Interface without implementation | Grep for `class.*: I{Name}` returns 0 | REJECT |
| Implementation without registration | No `Add(Scoped|Transient|Singleton)<I{Name}>` found | WARN |
| Registration without interface | Direct class registration for services | `nit:` suggest interface extraction |

## Contract-to-Handler Mapping

When API contracts define endpoints:

1. **Route handler exists**: Each contract endpoint has a corresponding controller action or minimal API handler
2. **HTTP method matches**: Contract `POST /api/v1/foo` maps to `[HttpPost]` on the correct route
3. **Response types match**: Contract response DTO matches handler return type

| Check | Detection | Action |
|-------|-----------|--------|
| Contract endpoint without handler | No `[Http{Method}("{route}")]` found | REJECT |
| Handler without contract | Controller action not in contracts/ | WARN (may be infrastructure endpoint) |
| Response type mismatch | Handler returns different DTO than contract | REJECT |

## When Stubs Are Acceptable

Not all stubs are bugs. These are acceptable:

- **Phased implementation**: Stub with `[!SURFACE]` marker in tasks.md and a follow-up task
- **Test doubles**: Stubs in test projects (`*.Tests/`)
- **Interface-first design**: Interface defined in Phase N, implementation planned for Phase N+1
- **Feature flags**: Stub behind a disabled feature flag with implementation tracked

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Stub without tracking | Silent incompleteness | Add `[!SURFACE]` task or TODO with issue reference |
| Mock in production code | Hidden stub | Move to test project or implement |
| Empty method body | Silent no-op | Throw NotImplementedException or implement |
| Catch-all returning defaults | Masks missing logic | Implement or fail explicitly |
