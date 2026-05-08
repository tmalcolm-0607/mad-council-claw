# Technology-Specific Patterns

Path-scoped rules loaded automatically when editing matching files. Use `{technology}-{pattern}.md` naming with YAML `globs:` frontmatter (the canonical Claude Code convention; `paths:` is also accepted for backward compatibility).

## Authoritative LENS skills

The `_dotnet/*.md` patterns below are project-best-practice **supplements**. The authoritative sources for LENS layered architecture, pipeline structure, telemetry, and standards are the LENS gate skills:

| Concern | Authoritative skill |
|---|---|
| Layered architecture (5-layer model, handler/repository/DI patterns, validation, error handling) | `lens-aspnet-structure` |
| Build / release pipeline structure | `lens-pipeline-audit` |
| Telemetry onboarding (`AddLensTelemetry`, structured events, QOS metrics) | `lens-telemetry` |
| Cross-cutting LENS standards (extracted from `LENS-Docs`) | `lens-standards-audit` |

When a `_dotnet/*.md` pattern conflicts with one of the gate skills, the gate skill wins.

## Naming convention for placeholder types

Pattern docs use `Service*` as a generic placeholder for consumer-project type names:
- `ServiceValidationException` — the consumer's app-specific validation exception (LENS-CMS calls it `CmsValidationException`, LENS-LRMS calls it `LrmsValidationException`, etc.)
- `ServiceActivitySource` — the consumer's `ActivitySource` singleton for OpenTelemetry spans

When adopting a pattern, the consumer project's CLAUDE.md documents the actual type names. Don't ship `Service*` literally — substitute your project's names.

## .NET / C# Patterns (under `_dotnet/`)

See `_dotnet/README.md` for the per-file index. All files below live at `.claude/rules/patterns/_dotnet/<file>`.

| File | Description |
|------|-------------|
| `_dotnet/csharp-coding-patterns.md` | C# standards: usings, naming, null handling |
| `_dotnet/dotnet-api-versioning.md` | Route versioning (`/api/v1/`) |
| `_dotnet/dotnet-appservices-pattern.md` | AppServices request-scoped container pattern |
| `_dotnet/dotnet-architecture.md` | 5-layer architecture (API, DI, BusinessLogic, DataAccess, Common) |
| `_dotnet/dotnet-auth.md` | MISE v2 authentication and authorization |
| `_dotnet/dotnet-configuration.md` | IConfigOptions pattern, options binding |
| `_dotnet/dotnet-cosmos-advanced.md` | Cosmos DB: batching, change feed, indexing |
| `_dotnet/dotnet-cosmos-core.md` | Cosmos DB: partition keys, client, modeling, credential selection |
| `_dotnet/dotnet-cosmos-queries.md` | Cosmos DB: queries, pagination, errors, virtual seam pattern |
| `_dotnet/dotnet-di-patterns.md` | DI patterns, service registration, lifetimes |
| `_dotnet/dotnet-domain-models.md` | Domain entity, DTO, model design |
| `_dotnet/dotnet-error-handling.md` | LENS-canonical: `HandlerException` hierarchy, controller catch-ladder, library `GlobalErrorHandlingMiddleware`, QOS error-code wiring |
| `_dotnet/dotnet-feature-flags.md` | Kit-policy supplement: feature flag patterns (canonical LENS silent) |
| `_dotnet/dotnet-logging.md` | LoggerMessage source generators, structured logging |
| `_dotnet/dotnet-mvc-controllers.md` | MVC Controller patterns, [ApiController] |
| `_dotnet/dotnet-opentelemetry.md` | OpenTelemetry distributed tracing |
| `_dotnet/dotnet-quick-reference.md` | Checklists for Cosmos, Endpoints, Services, Logging |
| `_dotnet/dotnet-repository-two-tier.md` | Two-tier Cosmos repository pattern (Tier 1 entity-typed Scoped + Tier 2 generic Singleton) |
| `_dotnet/dotnet-resilience.md` | `Microsoft.Extensions.Http.Resilience` (HTTP, MS-blessed) + Polly 8.x package (non-HTTP) |
| `_dotnet/dotnet-security.md` | Managed Identity, validation, CORS |
| `_dotnet/dotnet-testing.md` | Unit testing: structure, naming, builders, mocking |
| `_dotnet/dotnet-testing-integration.md` | Integration testing: fixtures, API tests, WireMock |
| `_dotnet/iac-security-checklist.md` | IaC / Bicep security review checklist |
| `_dotnet/quality-gates-dotnet.md` | .NET-specific gate commands |

> Marten/PostgreSQL event sourcing patterns were removed: orthogonal to the LENS Cosmos stack, and the `paths:` frontmatter false-triggered on `Aggregates/` directories used by the Cosmos handlers.

## API & Validation Patterns

| File | Description |
|------|-------------|
| `api-validation.md` | LENS-canonical DataAnnotations + `[ApiController]` request validation; FluentValidation deprecated |
| `naming-conventions.md` | Consistent naming standards across the codebase |

## Cross-cutting Patterns

| File | Description |
|------|-------------|
| `async-patterns.md` | Async/await, Task management, cancellation |

## Infrastructure & Deployment Patterns

| File | Description |
|------|-------------|
| `cicd-deployment.md` | CI/CD deployment and environment promotion patterns |
| `cicd-pipeline-structure.md` | CI/CD pipeline organization and structure |
| `cicd-quality-gates.md` | CI/CD quality gate hierarchy and enforcement |
| `deployment-troubleshooting.md` | Azure deployment and App Service failure diagnosis |

## Security Patterns

| File | Description |
|------|-------------|
| `bicep-waf-conventions.md` | AFD WAF rule conventions for Bicep deployment templates (cross-reference: `/lens-waf-audit:waf-audit` skill) |
| `logging-security.md` | Secure logging, PII redaction |

## Quality & Process Patterns

| File | Description |
|------|-------------|
| `ado-workflow.md` | Azure DevOps branch naming and workflow patterns |
| `behavioral-testing.md` | Stub: archived to `.mad/docs/non-lens-extras/behavioral-testing.md` (kit-extra; canonical LENS testing in `_dotnet/dotnet-testing*.md`) |
| `code-review.md` | Code review criteria and quality standards |
| `implementation-checklist.md` | Pre/post implementation verification checklist |
| `integration-surface-checklist.md` | Stub patterns and integration surface audit |

## Platform & Scripting Patterns

| File | Description |
|------|-------------|
| `powershell-conventions.md` | PowerShell reserved variables, string quoting, error handling |
| `windows-git-bash.md` | Windows Git Bash command differences and workarounds |
