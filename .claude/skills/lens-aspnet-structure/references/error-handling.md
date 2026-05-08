# Error Handling Reference

> Consistent, secure error handling across all LENS ASP.NET Core services.
> See [exception-handling-reference.md](exception-handling-reference.md) for the full exception hierarchy and layer-by-layer catch patterns.

---

## Core Rules

- Never catch `Exception` generically unless immediately rethrowing with `throw;`
- Never swallow exceptions silently — every catch either rethrows a wrapped exception or returns a mapped HTTP response
- The exception **type** is the routing gate — controllers catch typed `HandlerException` subclasses and decide the HTTP status code; there is no `StatusCode` property on `HandlerException`
- Never expose raw exception messages to HTTP callers — the middleware always returns a generic error message; exception content never appears in HTTP responses
- Never log PII, secrets, or tokens — `TelemetryUtils.SanitizeValue` is applied to all structured log fields
- DataAccess never swallows errors — 404 from Cosmos is the one exception absorbed as `null`; everything else throws

---

## Exception Flow

```
CosmosException / HttpRequestException / ServiceException
  ↓  DataAccess catches → DataStoreException (preserves StatusCode + RetryAfter from infrastructure)
  ↓  Handler catches → typed HandlerException subclass (e.g. FooNotFoundException, FooDataAccessException)
  ↓  Controller catches → maps exception type to IActionResult; controller decides HTTP status code
  ↓  (if unhandled) → GlobalErrorHandlingMiddleware → always 500
```

---

## HTTP Status Code Mapping

| What happened | Exception type | Status code | Who decides |
|---------------|---------------|------------|-------------|
| Entity not found | `FooNotFoundException` | 404 | Controller catches `FooNotFoundException`, calls `NotFound()` |
| Business rule violation | `FooLockedForDeletionException` (or domain-specific) | 422 | Controller catches typed exception, calls `UnprocessableEntity()` |
| Data tier failure, back-off signalled | `FooDataAccessException` with `RetryAfter` set | 429 | Controller catches `FooDataAccessException when (ex.RetryAfter.HasValue)`, adds `Retry-After` header |
| Data tier failure, no back-off | `FooDataAccessException`, no `RetryAfter` | 503 | Controller catches `FooDataAccessException`, calls `StatusCode(503)` |
| Anything reaching middleware | (any) | 500 | Middleware hardcodes — exception type does not affect this |

---

## GlobalErrorHandlingMiddleware

`GlobalErrorHandlingMiddleware` from `Microsoft.LENS.Common.Telemetry` catches all unhandled exceptions. Controllers do not need try/catch for general failures — only for their own domain's `HandlerException` subclasses.

```csharp
// Microsoft.LENS.Common.Telemetry.Middleware.GlobalErrorHandlingMiddleware
public async Task InvokeAsync(HttpContext httpContext, IRequestTelemetryContext telemetryContext)
{
    try
    {
        await this.next.Invoke(httpContext).ConfigureAwait(false);
    }
    catch (Exception ex) when (ex is not OperationCanceledException)
    {
        // Record exception type on request context for QOS metric dimensions
        if (telemetryContext.RequestContext != null)
            RequestContextItems.ExceptionType.SetItem(telemetryContext.RequestContext, ex.GetType().FullName);

        // Emit structured ExceptionEvent — caller location auto-populated via [CallerX] attributes
        telemetryContext.StructuredLogger?.LogEvent(new ExceptionEvent(ex));

        // If headers already sent, log and re-throw — cannot write a new response body
        if (httpContext.Response.HasStarted)
            throw;

        httpContext.Response.Clear();
        httpContext.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
        httpContext.Response.ContentType = "application/json";

        await httpContext.Response.WriteAsync(JsonSerializer.Serialize(
            new { error = "An unexpected error occurred.", correlationId = telemetryContext.RequestContext?.RequestId },
            new JsonSerializerOptions { DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull }))
            .ConfigureAwait(false);
    }
}
```

**Key facts:**
- Middleware **always** returns 500 — if an exception reached here, it was not caught by the controller and is therefore unexpected
- `OperationCanceledException` (and `TaskCanceledException`) is **not caught** — it propagates so the host can handle client disconnections cleanly
- The response body is always the generic `"An unexpected error occurred."` message — exception content is never surfaced to callers
- The correlation ID (`RequestContext.RequestId`) is always included in the response so callers can report it for investigation
- If `httpContext.Response.HasStarted` the middleware logs the event and re-throws — it cannot write a new response body once headers are flushed

---

## Structured Logging at Catch Sites

Every catch site logs two things:

**1. A structured `ExceptionEvent`** (DataAccess, BusinessLogic, and Middleware):

```csharp
// ExceptionEvent constructor — caller file, member, and line are auto-populated
telemetryContext.StructuredLogger?.LogEvent(new ExceptionEvent(caughtException));
```

`ExceptionEvent` captures: `ExceptionType` (fully qualified type name), `ExceptionMessage`, `CallerFilePath`, `CallerMemberName`, `CallerLineNumber`. It routes to the Geneva DGrep `ExceptionEvent` table at `LogLevel.Error`. Caller location fields are populated automatically via `[CallerFilePath]`, `[CallerMemberName]`, and `[CallerLineNumber]` attributes — no manual population needed. See `lens-telemetry` skill for usage from handlers and repositories via `ILogger<T>`.

**2. An error code on the request context** (controller catch sites only):

```csharp
RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ServiceErrorCodes.OutboundRequestExceptionErrorCode);
```

This feeds the QOS `InboundQOSEvent` and metric dimensions — essential for Jarvis dashboards showing failure rates by error category. See `lens-telemetry` skill for QOS wiring details.

---

## Middleware Pipeline Order

`GlobalErrorHandlingMiddleware` must be positioned after `LoggingAndMetricsMiddleware` so the QOS outer wrapper records the 500 status code produced by the error handler.

```csharp
app.UseRouting();
app.UseMiddleware<InitializeTelemetryContextMiddleware>();
app.UseMiddleware<LoggingAndMetricsMiddleware>();         // QOS outer wrapper
app.UseMiddleware<GlobalErrorHandlingMiddleware>();       // catches all unhandled exceptions
app.UseAuthentication();
app.UseMiddleware<PostAuthTelemetryMiddleware>();
app.UseAuthorization();
app.MapControllers();
```

See `lens-telemetry` skill for the full middleware ordering reference.
