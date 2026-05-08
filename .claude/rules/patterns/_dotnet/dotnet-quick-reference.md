---
paths:
  - "**/*.cs"
---

# Quick Reference Checklists

> **Kit-policy supplement; canonical LENS does not prescribe.** This file aggregates kit-internal checklists drawn from the per-domain `_dotnet/*.md` files. Where a row cites a LENS-canonical pattern (e.g. EventId / Geneva / structured events), the authoritative source is the LENS-Common SKILL.md (PR 5158460); the row here is a quick-reference summary, not a separate prescription.

Standard checklists for .NET development.

## Cosmos Query Checklist

| Check | Status |
|-------|--------|
| Partition key in WHERE clause | REJECT |
| PartitionKey in QueryRequestOptions | REJECT |
| Parameterized query (no concat) | REJECT |
| Specific fields (no SELECT *) | WARN |
| MaxItemCount for pagination | WARN |
| Continuation token handled | WARN |

## Endpoint Checklist

| Check | Status |
|-------|--------|
| MVC Controller with [ApiController] | REJECT if missing |
| Versioned route (v1/...) | REJECT if missing |
| DataAnnotations on request DTO (LENS-canonical; relies on `[ApiController]` auto-validation) | REJECT if missing — see `api-validation.md` |
| FluentValidation `AbstractValidator<T>` / `IValidator<T>` injection | REJECT — non-canonical for LENS |
| Typed `HandlerException` subclasses + controller catch-ladder | REJECT if missing — see `dotnet-error-handling.md` |
| `Result<T>` for business errors | REJECT — non-canonical for LENS; throw typed exceptions |
| RequireAuthorization() applied | REJECT for protected |
| Proper HTTP status codes | WARN |
| CancellationToken propagated | WARN |

## Service Registration Checklist

| Check | Status |
|-------|--------|
| IConfigOptions with ValidateOnStart() | REJECT |
| CosmosClient as Singleton | REJECT |
| Repositories as Scoped | WARN |
| Validators as Transient | WARN |
| HttpClient via IHttpClientFactory | REJECT |
| `AddMiseAuthContextBuilder()` called for MISE V2 services (order relative to `AddLensTelemetry` does not matter — REPLACE-semantics, idempotent) | REJECT for MISE V2 service without it |
| `AddCosmosDbTelemetry()` called when service uses Cosmos | REJECT for Cosmos consumer without it |
| `AddBlobClientTelemetry()` called when service uses Blob Storage | WARN for Blob consumer without it |

## Logging Checklist

| Check | Status |
|-------|--------|
| Service-specific `[StructuredEventLogger] sealed partial` logger extending `LensStructuredLogger` (LENS services) | REJECT for LENS service without it |
| Event classes are `[StructuredEvent("Table")] sealed partial : IStructuredLogEvent` (LENS services) | REJECT for service event class missing pattern |
| New event table names registered in the Geneva monitoring agent XML and agent redeployed | REJECT for new `[StructuredEvent("...")]` without matching XML `<Source>` entry |
| `[LoggerMessage]` source generators used for unstructured / non-Geneva logging | WARN |
| Each `[LoggerMessage]` declares a unique integer EventId (unstructured path only — Geneva structured events use `[StructuredEvent("TableName")]`, no EventId scheme) | WARN |
| Structured properties (not $"") | REJECT |
| Correlation ID included (auto-enriched by OTel — never as a custom event property) | WARN |
| Log-before-throw pattern | WARN |
| No PII/secrets logged | REJECT |

## Anti-Patterns

| Category | Anti-Pattern | Fix |
|----------|--------------|-----|
| Cosmos | Cross-partition query | Include partition key |
| Endpoint | Missing authorization | Add [Authorize] |
| DI | Wrong lifetime | Follow checklist |
| Logging | String interpolation | Use structured logging |
