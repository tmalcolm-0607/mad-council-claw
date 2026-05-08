# .NET-specific pattern rules

These patterns apply to .NET / C# / ASP.NET plugins. Keep if your consumer is .NET-heavy; skip otherwise.

Originally ported from a large-enterprise consumer project's `.claude/rules/patterns/` (production-proven in that ecosystem).

## Contents

- `csharp-coding-patterns.md` — C# standards: usings, naming, null handling
- `dotnet-api-versioning.md` — Route versioning (`/api/v1/`)
- `dotnet-appservices-pattern.md` — AppServices request-scoped container pattern
- `dotnet-architecture.md` — 5-layer architecture (API, DI, BusinessLogic, DataAccess, Common)
- `dotnet-auth.md` — MISE v2 authentication and authorization
- `dotnet-configuration.md` — IConfigOptions pattern, options binding
- `dotnet-cosmos-advanced.md` — Cosmos DB: batching, change feed, indexing
- `dotnet-cosmos-core.md` — Cosmos DB: partition keys, client, modeling, credential selection
- `dotnet-cosmos-queries.md` — Cosmos DB: queries, pagination, errors, virtual seam pattern
- `dotnet-di-patterns.md` — DI patterns, service registration, lifetimes
- `dotnet-domain-models.md` — Domain entity, DTO, model design
- `dotnet-error-handling.md` — LENS-canonical `HandlerException` hierarchy + controller catch-ladder + library-provided `GlobalErrorHandlingMiddleware` + QOS error-code wiring
- `dotnet-feature-flags.md` — Kit-policy supplement: feature flag patterns (canonical LENS silent)
- `dotnet-logging.md` — Structured logging, source generators
- `dotnet-mvc-controllers.md` — MVC Controller patterns, [ApiController]
- `dotnet-opentelemetry.md` — OpenTelemetry distributed tracing
- `dotnet-quick-reference.md` — Checklists for Cosmos, Endpoints, Services, Logging
- `dotnet-repository-two-tier.md` — Two-tier Cosmos repository pattern (Tier 1 entity-typed Scoped + Tier 2 generic Singleton)
- `dotnet-resilience.md` — `Microsoft.Extensions.Http.Resilience` (HTTP, MS-blessed) + Polly 8.x package (non-HTTP)
- `dotnet-security.md` — Managed Identity, validation, CORS
- `dotnet-testing.md` — Unit testing: structure, naming, builders, mocking
- `dotnet-testing-integration.md` — Integration testing: fixtures, API tests, WireMock
- `iac-security-checklist.md` — IaC / Bicep security review checklist
- `quality-gates-dotnet.md` — .NET-specific gate commands
