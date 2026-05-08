---
paths:
  - "**/*.cs"
  - "**/spec.md"
  - "**/plan.md"
---

# Implementation Checklist

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Distilled REJECT rules from all C# pattern files. Code-implementer MUST verify every changed file against this checklist before reporting completion.

## How to Use

- Scan each category before writing code
- After completing changes, re-scan each REJECT item against your diff
- Fix any violations before returning results

## C# Coding Standards

Source: `csharp-coding-patterns.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 1 | `using` directives inside namespace declaration | `using` statements above `namespace` line |
| 2 | File-scoped namespaces in new files | Block-scoped `namespace X { }` in any new file |
| 3 | Explicit enum numbering on all members | Any enum member without `= N` assignment |
| 4 | `[JsonPropertyName]` uses `PropertyNames` constants | Hardcoded string literal in `[JsonPropertyName("...")]` |
| 5 | 100% diff coverage on all changed lines | PR with any changed line uncovered by tests |

## Async Patterns

Source: `async-patterns.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 6 | Linked `CancellationTokenSource` must pass `cts.Token` downstream | Creating CTS but passing original `cancellationToken` to calls |
| 7 | Check `cts.IsCancellationRequested`, not original token | Checking `cancellationToken.IsCancellationRequested` when CTS exists |

## Architecture

Source: `dotnet-architecture.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 8 | Dependencies flow downward only | Upward project reference (e.g., DataAccess referencing BusinessLogic) |
| 9 | No duplicate constant categories across files | Same constant type (error codes, doc types) in multiple files |
| 10 | Common layer has zero ASP.NET package refs | `Microsoft.AspNetCore.*` in Common `.csproj` or `using` directive |

## Controllers

Source: `dotnet-mvc-controllers.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 11 | Controllers have `[ApiController]` attribute | Controller class missing `[ApiController]` |
| 12 | Controllers inherit `ControllerBase` | Inheriting `Controller` instead of `ControllerBase` |

## Security

Source: `dotnet-security.md`, `dotnet-auth.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 13 | No connection strings with passwords | Hardcoded password/secret in connection string |
| 14 | Rate limiter before authentication in pipeline | `UseAuthentication()` before `UseRateLimiter()` |
| 15 | Never expose internal exception details | `exception.ToString()` or `ex.Message` in HTTP response body |
| 16 | All user input validated | Endpoint accepting unvalidated input |
| 17 | No hardcoded secrets | Secret/key/password literals in source |
| 18 | No `AllowAnyOrigin()` in CORS | `AllowAnyOrigin()` in CORS policy |
| 19 | No `[AllowAnonymous]` on health endpoints in prod | Unauthenticated health endpoint in production |
| 20 | Use `CryptographicOperations.FixedTimeEquals()` for tokens | `string.Equals` for auth token comparison |
| 21 | Use MISE, not custom JWT validation | Custom `AddJwtBearer` with manual `TokenValidationParameters` |
| 22 | Protected endpoints require `[Authorize]` | Sensitive endpoint missing `[Authorize]` attribute |
| 23 | `PostAuthMiddleware` after `UseAuthentication()` | PostAuth placed before authentication step |
| 24 | `UseMise()` after `UseAuthorization()` (v2.x) | `UseMise()` before `UseAuthorization()` |
| 25 | No null-forgiving `!` on auth claims | `authContext.TenantId!` or `authContext.AppId!` |
| 26 | No `DefaultAzureCredential` in production paths | `DefaultAzureCredential` in unconditional prod code |
| 27 | MISE v2 migration must include explicit AuthZ policies | Removing legacy auth without adding MISE v2 scope/tenant policies |
| 28 | No assuming Bicep deploys Entra app roles | App role assignment without post-provisioning script |

## Testing

Source: `_dotnet/dotnet-testing.md` and `_dotnet/dotnet-cosmos-queries.md` (virtual seam pattern)

| # | Rule | REJECT trigger |
|---|------|---------------|
| 29 | Wrap LINQ `ToFeedIterator()` in virtual method | Inline `GetItemLinqQueryable().Where().ToFeedIterator()` |
| 30 | Wrap `GetItemQueryIterator<T>()` in virtual method | Inline `GetItemQueryIterator<T>()` in repository |
| 31 | `[ExcludeFromCodeCoverage]` must have `Justification` | `[ExcludeFromCodeCoverage]` without `Justification = "..."` |
| 32 | Never exclude business logic from coverage | `[ExcludeFromCodeCoverage]` on handlers, validators, or exception paths |
| 33 | No `Task.Delay` / `Thread.Sleep` in tests for sync | `Task.Delay` or `Thread.Sleep` to wait for background work in tests |

## Cosmos DB

Source: `dotnet-cosmos-core.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 34 | `CosmosClientOptions` must set `ApplicationName` | `CosmosClientOptions` without `ApplicationName` |
| 35 | Use `DocumentTypes` constants in queries | Hardcoded string literal for document type in WHERE clause |
| 36 | Default delete SHOULD be soft delete (project policy, not LENS-canonical) | `DeleteAsync` without soft delete path **AND** the service has compliance / legal-hold / audit-retention requirements (REJECT for those services). Other services SHOULD evaluate against data lifecycle (e.g. hard-delete-by-default may be appropriate for GDPR Right-to-Erasure flows). See `dotnet-cosmos-core.md:316`. |
| 37 | Enums in Cosmos use `[JsonStringEnumConverter]` | Integer-backed enum stored in Cosmos document |
| 38 | Connection string auth forbidden in prod Bicep | Connection string in production deployment template |
| 39 | Patch allow-list from DTO, not entity | `typeof(Entity).GetProperties` for patch field list |
| 40 | `PatchItemAsync` must use `IfMatchEtag` | `PatchItemAsync` without `IfMatchEtag` on mutable endpoint |
| 41 | `ReplaceItemAsync` must use `IfMatchEtag` | `ReplaceItemAsync` without `IfMatchEtag` on mutable endpoint |
| 42 | No `UpsertItemAsync` for updates | `UpsertItemAsync` where Replace + ETag should be used |
| 43 | No client-side-only ETag comparison | Read-compare-patch without server-side `IfMatchEtag` |

## Logging

Source: `dotnet-logging.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 44 | Logging path uses one of the canonical patterns | Neither `[StructuredEvent]` (Geneva) nor `[LoggerMessage]` (unstructured) — string-interpolated `logger.Log*($"...")` everywhere |
| 44a | Unstructured `ILogger` calls use `[LoggerMessage]` source generators with an `EventId` | `logger.Log*($"interpolated {value}")` or `[LoggerMessage]` missing `EventId` parameter |
| 44b | Geneva-table events use `[StructuredEvent("TableName")]` on `sealed partial class : IStructuredLogEvent` AND a `sealed partial class : LensStructuredLogger` decorated with `[StructuredEventLogger]` | Custom event class missing `partial` (LENS0001), missing `IStructuredLogEvent`, or wrong base type; logger class missing `partial` (LENS0003) or missing `[StructuredEventLogger]`; injecting `LensStructuredLogger` instead of the concrete service-specific subclass |
| 44c | New event table name is registered in the Geneva monitoring agent XML and the agent is redeployed | New `[StructuredEvent("TableName")]` introduced without matching XML `<Source>` entry — records silently dropped |
| 45 | Every log message has an Event ID (unstructured path) or a unique table name (structured path) | `[LoggerMessage]` without `EventId` parameter; duplicate `[StructuredEvent("TableName")]` collisions |
| 46 | Log before throw | `throw` without preceding log statement |
| 47 | No sensitive data in logs | PII, secrets, tokens, or credentials in log output |
| 48 | No EventId collisions (unstructured `[LoggerMessage]` path) | Same EventId integer used in two different `[LoggerMessage]` definitions in the same project. EventId numbering for raw `[LoggerMessage]` is a per-project policy decision; LENS Geneva structured events use `[StructuredEvent("TableName")]` per `lens-telemetry` SKILL.md Standards 4-7 — no layer-range scheme applies. |
| 48a | Custom structured events do NOT redefine `InboundQOSEvent` / `OutboundQOSEvent` / `ExceptionEvent` | Service logger or event class redefines a name inherited from `LensStructuredLogger` |
| 48b | Custom structured events do NOT carry `CorrelationId`/`TraceId`/`SpanId` properties | Custom event class declares any of these as a property — auto-enriched by OTel pipeline; explicit properties create duplicate DGrep columns |
| 48c | Old `Register<TEvent>()` and generic `LogEvent<TEvent>()` calls are removed in new code | `Register<TEvent>()` or `LogEvent<TEvent>()` used in new code — both are `[Obsolete]` per LENS-Telemetry SKILL.md Standard 15 |

## Dependency Injection

Source: `dotnet-di-patterns.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 49 | No `.GetAwaiter().GetResult()` in constructors | Blocking async call in constructor causing deadlock risk |

## Error Handling

Source: `dotnet-error-handling.md`

| # | Rule | REJECT trigger |
|---|------|---------------|
| 50 | Retry `when` filter must not swallow final attempt | `catch (DomainException) when (attempt < max)` without letting final attempt surface correct HTTP status |

## LENS ASP.NET Structure (canonical layered architecture)

Source: `.claude/skills/lens-aspnet-structure/SKILL.md` Standards 1-7; `dotnet-architecture.md`, `dotnet-mvc-controllers.md`, `dotnet-error-handling.md`, `dotnet-repository-two-tier.md`.

| # | Rule | REJECT trigger |
|---|------|---------------|
| 56 | Handler implementations are `sealed` | Concrete `*Handler` class declared without the `sealed` modifier (e.g. `public class FooHandler : IFooHandler`) |
| 57 | Repository implementations are `internal sealed` | Concrete `*Repository` class declared without `internal sealed` (interface stays `public`; concrete impl is internal-only) |
| 58 | Controllers catch only domain-specific typed `HandlerException` subclasses | `catch (Exception ex)` or `catch (HandlerException ex)` (base class) inside any controller action — controllers must catch the specific subclasses they map to HTTP responses; everything else propagates to `GlobalErrorHandlingMiddleware` |
| 59 | API layer never references `DataAccess` directly | `<ProjectReference>` from `API.csproj` to `DataAccess.csproj`, OR an `IRepository`-typed dependency in any `Controllers/` constructor — the missing piece is a handler, create one |
| 60 | DataModels boundary | `Microsoft.LENS.Common.DataModels.*` (or any cross-service contract type) referenced inside any `BusinessLogic/` file — DataModels appear at API and DataAccess only (see `dotnet-architecture.md` § DataModels Boundary Rule) |
| 61 | Handlers never return `null` for "not found" | `return null` (or `return default`) inside a handler method — handlers throw a typed `HandlerException` subclass (e.g. `FooNotFoundException`); only the Tier-1 repository may return `null` for a Cosmos point-read 404 |
| 62 | Handlers throw typed exceptions, not `Result<T>` | Handler method signature returns `Result<T>` / `Result<,>` / discriminated-union OR handler body returns a `Failure(...)` value — LENS handlers throw and the controller catch-ladder routes (canonical Standard 7) |
| 63 | Use `IOptions<TOptions>` not `IConfiguration` in services | A service / handler / repository constructor injects `IConfiguration` directly — bind to a strongly-typed `*Options` class with `AddOptions<T>().ValidateDataAnnotations().ValidateOnStart()` instead |
| 64 | Domain types never returned as HTTP responses without `IPresentationModelFactory` | Controller action returns `Ok(domainEntity)` / `CreatedAtAction(..., domainEntity)` directly — must thread through `this.presentationFactory.Get*Response(...)` first |
| 65 | `HandlerException` subclasses carry no `HttpStatusCode` | Any `HandlerException` subclass declaring an `HttpStatusCode StatusCode { get; }` property (or constructor-set field) — HTTP codes are protocol-layer concerns the controller decides; the exception type is the routing gate (canonical Standard 7) |
| 66 | Common project references only `Microsoft.LENS.Common.*` packages | A `<PackageReference>` in `Common.csproj` whose Include is not under the `Microsoft.LENS.Common.*` family (e.g. `Microsoft.Azure.Cosmos`, `Azure.Identity`, `Microsoft.Identity.Client`, third-party libs) — move infrastructure deps to the layer that owns the contract |
| 67 | Two-tier DataAccess is mandatory | Handler injects `CosmosClient` / `Container` / `IHttpClientFactory` / SDK client directly, OR a Tier-1 `I{Domain}Repository` is missing entirely — handler must depend only on a domain-typed `I{Domain}Repository` (Scoped); infrastructure clients live behind a Tier-2 abstraction (Singleton; e.g. `ICosmosDbResourceRepository`) injected into the Tier-1 implementation |

## Telemetry (LENS Services)

Source: `_dotnet/dotnet-opentelemetry.md`, `_dotnet/dotnet-auth.md`, `_dotnet/dotnet-domain-models.md`, `lens-telemetry` SKILL.md v1.3.0

| # | Rule | REJECT trigger |
|---|------|---------------|
| 68 | Custom `[Histogram]` instrument has matching `ExplicitBucketHistogramConfiguration` view registered via `configureViews:` on `AddLensTelemetry` (S13) | Service defines a `[Histogram]` partial method but `AddLensTelemetry(...)` call has no matching `AddView(instrumentName: "...")` for it — P95/P99 align to default OTel coarse buckets |
| 69 | Cosmos-consuming service registers `services.AddCosmosDbTelemetry()` AND sets `CosmosClientOptions.CosmosClientTelemetryOptions.DisableDistributedTracing = false` (S11) | Service uses `CosmosClient` but `AddCosmosDbTelemetry()` not called, OR `AddCosmosDbTelemetry()` called but `DisableDistributedTracing` left at default `true` — `CosmosDbActivityProcessor` receives nothing |
| 70 | MISE V2 service registers `services.AddMiseAuthContextBuilder()` (S14) | Service runs MISE V2 (`AddMiseWithDefaultModules`) without `AddMiseAuthContextBuilder()` — `DefaultAuthContextBuilder` reads projected `HttpContext.User` and most caller-identity claims become `"Undefined"` |
| 71 | Security-significant structured event includes all 3 caller-identity fields on BOTH success AND failure paths (S18) | Event class records token issuance, SAS issuance, authorization decision, role grant/revoke, or sensitive data access but `CallerAppId` / `CallerTenantId` / `CallerObjectId` are absent on failure path (compliance gap), or absent entirely |

## React/TypeScript frontend project specifics

Source: frontend coding-conventions doc (project-specific).

| # | Rule | REJECT trigger |
|---|------|---------------|
| 51 | Space after `new` keyword (SA1000) | `new()` instead of `new ()` |
| 52 | No collection expressions (SA1010) | `= []` instead of `new List<T>()` |
| 53 | Methods must be `static` if no instance access (CA1822) | Non-static method that never uses `this` |
| 54 | `global::` prefix for `Azure.Identity` in `Microsoft.*` NS | `using Azure.Identity;` inside `namespace Microsoft.*` |
| 55 | Use `https://placeholder.local` for optional URI configs | Empty string for URI configuration value |
