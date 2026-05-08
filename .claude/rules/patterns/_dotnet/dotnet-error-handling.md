---
paths:
  - "**/*.cs"
  - "**/Middleware/**"
---

# .NET Error Handling — LENS Canonical

> **Canonical: this file documents LENS-canonical patterns from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins. This file specifies the LENS-canonical error handling pattern using the `GlobalErrorHandlingMiddleware` provided by the `Microsoft.LENS.Common.Telemetry` package. Non-LENS alternatives (custom dual-middleware patterns, `SanitizedException` hierarchies, in-middleware status mapping, `IExceptionHandler` with Azure-SDK type leakage) are **deprecated as of 2026-05-08** per user directive — the kit serves LENS consumers exclusively. See § "Migration from non-LENS dual-middleware" for the migration path.

---

## Architecture

LENS services do **not** implement custom exception middleware. The `Microsoft.LENS.Common.Telemetry` package ships:

| Library middleware | Responsibility |
|---|---|
| `GlobalErrorHandlingMiddleware` | Catches unhandled exceptions, returns 500, sanitizes the message, and tags `RequestContextItems.ExceptionType` for QOS dimensions. Includes the `OperationCanceledException` exclusion + `Response.HasStarted` guard internally. |
| `LoggingAndMetricsMiddleware` | Times the request, records `InboundQOSEvent` + `InboundRequestQoSMetric`, reads the per-request error code set by controller catch-ladders. |

Both middlewares are registered automatically — and in the correct order — by `AddLensTelemetry<TLogger>()`. **Do not register them by hand and do not write replacements.**

Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 3 (lines 132-153); LENS-Common CLAUDE.md "Middleware pipeline order"; `_dotnet/dotnet-opentelemetry.md`; `lens-aspnet-structure/references/program-startup.md`; `lens-aspnet-structure/references/error-handling.md`.

```csharp
// Program.cs — canonical LENS bootstrap
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(builder.Configuration);
// ...
var app = builder.Build();
// AddLensTelemetry registers both middlewares in the correct order; no UseMiddleware calls here.
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

---

## Exception hierarchy

LENS services define typed `HandlerException` subclasses (in `Common/Exceptions/`) and rely on a controller catch-ladder mapping each typed exception to a status + error code. Unhandled exceptions reach `GlobalErrorHandlingMiddleware` and return 500.

```
Exception
├── HandlerException (abstract base; carries domain meaning, NOT HttpStatusCode)
│   ├── FooNotFoundException             → controller maps to 404
│   ├── FooValidationException           → controller maps to 400
│   ├── FooLockedForDeletionException    → controller maps to 409
│   ├── FooEtagMismatchException         → controller maps to 412
│   ├── FooPreconditionRequiredException → controller maps to 428
│   └── …other scenario-named subclasses
│
├── DataStoreException                   (DataAccess boundary — wraps Cosmos / SQL infra exceptions)
├── ExternalServiceCallException         (HTTP / SDK calls to other services)
│
└── [Framework / unexpected exceptions]  → GlobalErrorHandlingMiddleware → 500
```

### Rules

- `HandlerException` is the **abstract base** in `Common/Exceptions/HandlerException.cs`. Subclasses are **scenario-named** (e.g. `CaseNotFoundException`, `CaseLockedForDeletionException`), not generic with embedded codes.
- `HandlerException` subclasses **MUST NOT** carry an `HttpStatusCode` property. Status mapping is the controller's job at the catch site, not the exception's job (per `implementation-checklist.md` Rule 65).
- `DataStoreException` is thrown only at the DataAccess boundary (Tier-1 / Tier-2 repositories). Cosmos / SQL infrastructure exceptions are caught and re-thrown as `DataStoreException` with the original as the inner exception.
- `ExternalServiceCallException` wraps HTTP / SDK failures from outbound calls to other services.
- Controllers catch only the **specific** typed `HandlerException` subclasses they map. They do **not** catch the abstract `HandlerException` base. Anything unmatched propagates to `GlobalErrorHandlingMiddleware`.

Cite: `lens-aspnet-structure/references/handler-pattern.md`; `_dotnet/dotnet-mvc-controllers.md`; `_dotnet/dotnet-architecture.md`; `implementation-checklist.md` Rules 58 & 65.

---

## Controller catch-ladder pattern

Controllers map each typed `HandlerException` subclass to a specific HTTP status code AND set a QOS error code on the request context (see § "QOS Error-Code Wiring" below). Domain entities are mapped to DTOs via `IPresentationModelFactory` — they are never returned directly.

```csharp
// 1. Define a typed handler exception (in Common/Exceptions/)
//    NOTE: HandlerException carries domain meaning ONLY. NO HttpStatusCode property.
public sealed class CaseNotFoundException : HandlerException
{
    public string CaseId { get; }

    public CaseNotFoundException(string caseId)
        : base($"Case '{caseId}' was not found.")
    {
        CaseId = caseId;
    }
}

// 2. Handler throws the typed exception (BusinessLogic layer)
public sealed class GetCaseHandler(ICaseRepository repo, MyServiceStructuredLogger logger)
{
    public async Task<Case> HandleAsync(string caseId, CancellationToken ct)
    {
        var c = await repo.FindAsync(caseId, ct);
        if (c is null)
        {
            logger.LogEvent(new CaseNotFoundEvent { CaseId = caseId });   // Log BEFORE throw
            throw new CaseNotFoundException(caseId);
        }
        return c;
    }
}

// 3. Controller catch-ladder maps typed exception → HTTP code + ErrorCode
[ApiController]
[Route("api/v1/[controller]")]
public sealed class CasesController(
    GetCaseHandler handler,
    ILensAppContext appContext,
    IPresentationModelFactory pmFactory) : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<ActionResult> GetById(string id, CancellationToken ct)
    {
        try
        {
            var c = await handler.HandleAsync(id, ct);
            return Ok(pmFactory.From(c));
        }
        catch (CaseNotFoundException ex)
        {
            RequestContextItems.ErrorCode.SetItem(
                appContext.RequestContext,
                ErrorCodes.CaseNotFound);
            return NotFound(new { error = ex.Message });
        }
        catch (CaseValidationException ex)
        {
            RequestContextItems.ErrorCode.SetItem(
                appContext.RequestContext,
                ErrorCodes.CaseValidation);
            return BadRequest(new { error = ex.Message, errors = ex.Errors });
        }
        // Unhandled exceptions propagate to GlobalErrorHandlingMiddleware → 500.
    }
}
```

> **Per-request telemetry context.** `IRequestTelemetryContext` is `[Obsolete]`. Inject `ITelemetryContext<TLogger>` (typed metrics + structured logging) and `ILensAppContext` (request + auth context) per LENS-Common CLAUDE.md. See `_dotnet/dotnet-di-patterns.md` § "Per-request telemetry context (LENS services)".

> **Presentation models.** Map domain entities to DTOs through `IPresentationModelFactory` rather than returning domain types directly from controllers. See `_dotnet/dotnet-mvc-controllers.md`.

---

## Log-Before-Throw

Always log BEFORE throwing. If you throw without logging, the business context that led to the exception is lost — middleware sees only the exception, not the state that caused it.

```csharp
// GOOD
if (user is null)
{
    logger.UserNotFound(userId);          // Log FIRST (LoggerMessage source generator)
    throw new UserNotFoundException(userId);
}

// BAD — no business context if the exception bubbles
if (user is null)
    throw new UserNotFoundException(userId);

// BAD — logging after throw is unreachable code
throw new ForbiddenException("User inactive.");
logger.UserInactive(userId);              // Never executes
```

---

## QOS Error-Code Wiring

Every controller catch site **MUST** set an error code on the request context so it flows into the QOS `InboundQOSEvent` and Geneva dashboards. This is the dimension that lets dashboards segment failure rates by error category — not setting it produces unattributed 4xx/5xx with no actionable signal.

```csharp
catch (FooNotFoundException ex)
{
    RequestContextItems.ErrorCode.SetItem(
        this.appContext.RequestContext,
        ErrorCodes.FooNotFound);          // domain error code constant
    return NotFound(new { error = ex.Message });
}
```

| Catch site | Error-code source |
|---|---|
| Controller catching a typed `HandlerException` subclass | The domain error-code constant matching the exception (e.g. `ErrorCodes.FooNotFound`) |
| Controller catching `*DataAccessException` / `DataStoreException` | `ErrorCodes.OutboundRequestException` or a domain-specific data-store code |
| Middleware (unhandled) | `RequestContextItems.ExceptionType.SetItem(...)` is set automatically by `GlobalErrorHandlingMiddleware` |

**REJECT trigger.** Any controller `catch` block that returns a non-2xx response without a preceding `RequestContextItems.ErrorCode.SetItem(...)` call. Pairs with Lane A (telemetry) — full QOS / `InboundQOSEvent` / metric-dimension wiring details live in the `lens-telemetry` skill (Standard 10); this rule covers only the controller-side discipline.

---

## OperationCanceledException + Response.HasStarted guards

`GlobalErrorHandlingMiddleware` enforces both guards internally — you do **not** write a replacement middleware to add them. They are documented here so you can reason about the host's behavior:

| Guard | What it prevents |
|---|---|
| `when (ex is not OperationCanceledException)` on the catch | Client cancellations being converted into 500s and noise alerts. The host handles `OperationCanceledException` / `TaskCanceledException` cleanly when they propagate. |
| `if (Response.HasStarted) throw;` early re-throw | Corrupt responses where partial data was already flushed and a 500 JSON body gets appended on top — clients would otherwise see invalid JSON. |

If you find yourself writing a custom middleware to add these guards, **stop** — `GlobalErrorHandlingMiddleware` already has them. Cite: `lens-aspnet-structure/references/error-handling.md:55, 64-67, 82`.

In the rare case where a handler catches a downstream exception and explicitly does NOT want it to convert to a 500, exclude `OperationCanceledException` at the handler level too:

```csharp
catch (Exception ex) when (ex is not OperationCanceledException)
{
    logger.UnexpectedDownstreamFailure(ex);
    throw new ExternalServiceCallException("Downstream service failed.", ex);
}
```

---

## Silent Fallback Prohibition

Fallback values for identity/auth context (actor, tenant, app ID) MUST emit a Warning-level log. Silent fallbacks create mystery data in production.

```csharp
// BAD: silent fallback
var actor = context.CurrentAppId ?? "unknown";

// GOOD: logged fallback
var actor = context.CurrentAppId;
if (actor is null)
{
    this.logger.MissingActorIdentity(operationName);
    actor = "unknown";
}
```

On write paths (audit-relevant), throw a typed `HandlerException` instead of falling back — an unidentified actor on a write is a real failure, not a missing-data condition.

---

## Anti-patterns

| Anti-pattern | Problem | Correct approach |
|---|---|---|
| `catch (Exception) { return StatusCode(500); }` in a controller | Loses correlation ID; bypasses `GlobalErrorHandlingMiddleware` and its QOS tagging | Let unhandled exceptions propagate; the middleware returns 500 with sanitized body |
| `catch (HandlerException ex)` (base class) in a controller | Catches subclasses the controller doesn't know how to map; produces wrong HTTP status | Catch only the **specific** typed subclasses you map (Rule 58) |
| Adding `HttpStatusCode StatusCode { get; }` to a `HandlerException` subclass | Couples domain meaning to protocol layer; breaks catch-ladder discipline | Status mapping happens at the controller catch site; the exception type IS the routing gate (Rule 65) |
| Custom `GlobalExceptionMiddleware` / `ApplicationExceptionMiddleware` registrations | Reimplements `GlobalErrorHandlingMiddleware`; duplicates guards; misses QOS tagging | Use `AddLensTelemetry<TLogger>()` — it registers the canonical middleware automatically |
| `MapExceptionToStatus` switch in middleware | Status mapping in middleware breaks the controller catch-ladder model | Map at the controller; middleware is for unhandled exceptions only |
| `SanitizedException` / `UserMessage` / `TechnicalDetails` hierarchy | Pre-LENS pattern; conflicts with `HandlerException` + scenario-named subclasses | Use `HandlerException` base; subclass per scenario; the message itself is the user message |
| Generic `BusinessRuleException("RULE_CODE", ...)` with embedded code string | Stringly-typed; loses compile-time exhaustiveness; doesn't pair with `ErrorCodes` constant | Define a scenario-named subclass per business rule; pair with a typed `ErrorCodes.*` constant |
| `IExceptionHandler` registration that switches on `Azure.RequestFailedException` | Leaks Azure SDK types into the global handler; ties middleware to a specific data store | Wrap Azure exceptions as `DataStoreException` at the DataAccess boundary; let `GlobalErrorHandlingMiddleware` handle the rest |
| `throw new Exception(ex.Message)` | Loses stack trace | `throw;` (rethrow) or `throw new HandlerException(..., innerException: ex)` |
| Logging after throw | Code is unreachable | Log before throw |
| `ex.Message` in a public 500 response | May leak sensitive info | `GlobalErrorHandlingMiddleware` returns a sanitized message — don't bypass it |
| `catch { }` (empty catch) | Swallows errors silently | At minimum, log; usually rethrow as a typed `HandlerException` / `DataStoreException` |
| Controllers returning domain entities directly | Couples API contract to domain shape | Use `IPresentationModelFactory` (Rule 64) |

---

## Migration from non-LENS dual-middleware

Services moving from a custom dual-middleware pattern to the canonical LENS pattern: the canonical end-state is documented above (§ Architecture, § Exception hierarchy, § Controller catch-ladder pattern, § QOS Error-Code Wiring). Adopt those sections in full; the legacy patterns being replaced are no longer documented here.

For services with significant migration scope, file an issue or use git history (`git log --diff-filter=D` on this file) to recover the prior step-by-step table — the kit has retired the prose to keep this file LENS-canonical only.

---

## Code Review Checklist

```
+===========================================================================+
|  ERROR HANDLING REVIEW (LENS)                                             |
|                                                                           |
|  Bootstrap:                                                               |
|  [ ] AddLensTelemetry<TLogger>() registers GlobalErrorHandlingMiddleware  |
|      (no custom GlobalExceptionMiddleware / ApplicationExceptionMiddleware|
|       registrations; no IExceptionHandler competitors)                    |
|                                                                           |
|  Exception hierarchy:                                                     |
|  [ ] Custom exceptions extend HandlerException (no HttpStatusCode prop)   |
|  [ ] Subclasses scenario-named, not generic-with-string-code              |
|  [ ] DataAccess wraps Cosmos/SQL infra exceptions as DataStoreException   |
|  [ ] HTTP/SDK failures wrapped as ExternalServiceCallException            |
|                                                                           |
|  Controllers:                                                             |
|  [ ] Catch only specific HandlerException subclasses (Rule 58)            |
|  [ ] Each catch site sets RequestContextItems.ErrorCode (QOS wiring)      |
|  [ ] Domain entities mapped through IPresentationModelFactory (Rule 64)   |
|                                                                           |
|  Logging:                                                                 |
|  [ ] Log BEFORE throw in all cases                                        |
|  [ ] Identity/tenant fallbacks emit a Warning-level log (no silent ??)    |
|  [ ] Appropriate log levels (Warning for 4xx, Error for 5xx)              |
+===========================================================================+
```
