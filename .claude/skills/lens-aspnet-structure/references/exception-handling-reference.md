# Exception Handling — Ground Truth Reference

> Authoritative reference for exception handling patterns in LENS ASP.NET Core services.

---

## The Flow

```
Infrastructure exception (CosmosException, ServiceException, HttpRequestException, RequestFailedException)
  ↓  DataAccess catches, wraps → DataStoreException or domain-specific DA exception
  ↓  Handler catches, wraps   → HandlerException subclass (preserves StatusCode, RetryAfter, Message)
  ↓  Controller catches       → maps HandlerException.StatusCode to IActionResult
  ↓  (if unhandled)           → bubbles to GlobalErrorHandlingMiddleware → 500
```

No layer swallows silently. Every catch either rethrows a wrapped exception or returns a mapped HTTP result.

---

## Exception Hierarchy

### Base Types

**`SanitizedMessageException : Exception`**
- The single marker that a message is safe to surface to the caller
- Constructor: `SanitizedMessageException(string message)` and `(string message, Exception inner)`
- Used by: middleware to decide whether to include the exception message in the HTTP response
- If an unhandled exception reaches middleware AND it is a `SanitizedMessageException`, its `.Message` is included in the 500 response body. All other exception messages are suppressed.

**`HandlerException : Exception`**
- Base for all business-layer exceptions
- Property: `TimeSpan? RetryAfter` (only needed for rate-limited scenarios — carries the back-off interval for the `Retry-After` response header)
- No `HttpStatusCode` — HTTP status codes are protocol-layer concerns; the controller decides them from the exception type
- Constructor: `(string message)`, `(string message, Exception? inner)`, and `(string message, TimeSpan? retryAfter, Exception? inner)`

**`DataStoreException : Exception`**
- Used in DataAccess to wrap CosmosDB failures
- Properties: `HttpStatusCode? StatusCode`, `TimeSpan? RetryAfter`
- `StatusCode` and `RetryAfter` are DataAccess-internal; handlers must not read `StatusCode`; handlers pass `RetryAfter` through as a neutral duration

**`ExternalServiceCallException : SanitizedMessageException`**
- Wraps any exception from outbound HTTP or SDK calls
- Property: `HttpStatusCode? StatusCode` — extracted recursively from the inner exception chain
- The message passed to the constructor must be a safe, generic string — never forward the raw exception message

### Handler-Specific Exceptions (all extend `HandlerException`)

Each `HandlerException` subclass is a sentinel for a **unique failure scenario** — one type per distinct controller routing outcome, not one per domain. The type name should describe the failure, not just the handler. The controller reads the exception type to decide the HTTP response; the exception itself carries no status code.

| Exception | Thrown by | When |
|-----------|-----------|------|
| `FooNotFoundException` | `FooHandler` | Foo entity not found; controller returns 404 |
| `FooLockedForDeletionException` | `FooHandler` | Business rule prevents deletion; controller returns 422 |
| `FooDataAccessException` | `FooHandler` | Any data tier failure; carries `RetryAfter` when the data tier signalled a back-off interval; controller returns 429 + `Retry-After` header when `RetryAfter` is set, 503 otherwise |

`RetryAfter` is a neutral `TimeSpan` — a "wait this long" signal that does not carry HTTP semantics. All other subclasses carry only a message.

### DataAccess-Specific Exceptions

| Exception | Base | Thrown by | When |
|-----------|------|-----------|------|
| `DataStoreException` | `Exception` | CosmosDB `{Domain}Repository` implementations | Any non-404 Cosmos failure; carries `StatusCode` and `RetryAfter` from `CosmosException` |
| `ExternalServiceCallException` | `SanitizedMessageException` | External HTTP and SDK service repositories | Any outbound call failure; carries `StatusCode` extracted from the inner exception chain; message must be explicitly safe |

Repositories that call Graph API, ARM, or other external HTTP services may define domain-specific retrieval exceptions that extend `SanitizedMessageException` when the failure message is safe to surface to the caller.

---

## Layer-by-Layer Catch Patterns

### DataAccess Layer

**CosmosDB:**
```csharp
catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
{
    return null; // 404 absorbed — caller checks for null
}
catch (CosmosException ex)
{
    // All other Cosmos failures: preserve RetryAfter so it can flow up as a neutral back-off signal
    throw new DataStoreException("Cosmos DB exception", ex, ex.StatusCode, ex.RetryAfter);
}
```

**Outbound HTTP / SDK (external service repository):**
```csharp
catch (Exception ex)
{
    // Broad catch: outbound calls throw beyond HttpRequestException (TaskCanceledException,
    // socket errors, SDK-specific exceptions). Message is explicitly safe — do not forward ex.Message.
    var callException = new ExternalServiceCallException("Bar service call failed.", ex);
    ExceptionEvent evt = new ExceptionEvent();
    evt.Populate(this.appServices, nameof(ExternalServiceCallException), ex);
    this.appServices.StructuredLogger.LogEvent(evt);
    throw callException;
}
```

**Key rules:**
- DataAccess never returns error signals — it either returns data or throws
- 404 on a point-read GET is the one exception: absorbed as `null`; the handler checks for null and throws the appropriate typed `HandlerException` subclass (e.g. `FooNotFoundException`)
- 404 on delete/update: throw `DataStoreException(NotFound)` — the resource was expected to exist

---

### BusinessLogic (Handler) Layer

**Pattern A — Wrap DataStoreException; pass `RetryAfter` through as a neutral duration:**
```csharp
catch (DataStoreException ex)
{
    // RetryAfter is a TimeSpan — a neutral "wait this long" signal, not an HTTP concept
    throw new FooDataAccessException("Data access failed.", ex.RetryAfter, ex);
}
```

**Pattern B — Wrap ExternalServiceCallException:**
```csharp
catch (ExternalServiceCallException ex)
{
    // StatusCode from ExternalServiceCallException is informational; map to the right domain type
    throw new FooDataAccessException("External service call failed.", ex);
}
```

**Pattern C — Direct business logic throw (no wrapping):**
```csharp
// Entity not found
throw new FooNotFoundException("Foo not found.");

// Business rule violation
throw new FooLockedForDeletionException("Cannot delete a locked foo.");
```

**Key rule:** Handlers do not catch-all. They catch only the specific exception types they know how to wrap. Anything else propagates naturally to the controller.

---

### API (Controller) Layer

**Pattern — typed exception catches; controller decides HTTP response from exception type:**
```csharp
catch (FooNotFoundException ex)
{
    RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooNotFound);
    return NotFound(new { error = ex.Message });
}
catch (FooLockedForDeletionException ex)
{
    RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooLocked);
    return UnprocessableEntity(new { error = ex.Message });
}
catch (FooDataAccessException ex) when (ex.RetryAfter.HasValue)
{
    // RetryAfter present means the data tier signalled a back-off interval — map to 429
    Response.Headers[HeaderNames.RetryAfter] = DateTime.UtcNow.Add(ex.RetryAfter.Value).ToString("R");
    RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooRateLimited);
    return StatusCode(429);
}
catch (FooDataAccessException)
{
    RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooDataAccessError);
    return StatusCode(503);
}
// Anything not caught here bubbles naturally to GlobalErrorHandlingMiddleware → 500
```

**Key rules:**
- Controllers catch only the typed exception subclasses they explicitly handle — nothing else
- The exception type determines the HTTP response — there is no `StatusCode` property to read
- Unexpected exceptions are not caught by the controller — they bubble naturally to `GlobalErrorHandlingMiddleware` which handles logging and returns 500
- `RequestContextItems.ErrorCode.SetItem(...)` is called at every catch site to feed QOS metrics

---

### Middleware (GlobalErrorHandlingMiddleware)

```csharp
catch (Exception exception)
{
    // 1. Log to ILogger
    this.logger.Log(LogLevel.Error, exception, context.TraceIdentifier);

    // 2. Log structured ExceptionEvent (includes request ID, tenant ID, stack trace)
    ExceptionEvent evt = new ExceptionEvent();
    evt.Populate(appServices, nameof(UnhandledExceptionDetails), exception);
    appServices.StructuredLogger.LogEvent(evt);

    // 3. Always 500 — no status code from the exception
    context.Response.StatusCode = 500;

    // 4. Response message depends on exception type
    string message = exception is SanitizedMessageException
        ? $"{exception.Message} Status: 500, CorrelationId: {context.TraceIdentifier}"
        : $"An error has occurred, Status: 500, CorrelationId: {context.TraceIdentifier}";

    await context.Response.WriteAsync(JsonSerializer.Serialize(new { message }));
}
```

**Key rules:**
- Middleware **always** returns 500 — any exception that reaches it was not caught by the controller
- This means any exception that reaches middleware was **not caught** by the controller and is therefore treated as unexpected
- `SanitizedMessageException` is the escape hatch: its message is included verbatim; all other messages are suppressed
- The correlation ID is always included so callers can report it for investigation

---

## HTTP Status Code Mapping

| What happened | Status code | Who decides |
|---------------|------------|-------------|
| Entity not found (`FooNotFoundException`) | 404 | Controller catches `FooNotFoundException`, calls `NotFound()` |
| Business rule violation (`FooLockedForDeletionException`) | 422 | Controller catches `FooLockedForDeletionException`, calls `UnprocessableEntity()` |
| Data tier failure, back-off signalled (`FooDataAccessException` with `RetryAfter`) | 429 | Controller catches `FooDataAccessException when (ex.RetryAfter.HasValue)`; adds `Retry-After` header; `RetryAfter` is a neutral `TimeSpan` — not an HTTP concept |
| Data tier failure, no back-off (`FooDataAccessException` without `RetryAfter`) | 503 | Controller catches `FooDataAccessException`, calls `StatusCode(503)` |
| Exception not caught by controller | 500 | Middleware hardcodes 500; exception type does not affect this |

---

## Error Response Shapes

**Handled exception (returned by controller):**
```json
{
  "error": {
    "message": "Foo not found.",
    "errorCode": "FOO_NOT_FOUND",
    "statusCode": "NotFound"
  }
}
```

**Rate-limited response (429) — also sets HTTP header:**
```
Retry-After: Wed, 21 Oct 2026 07:28:00 GMT
```

**Middleware-caught exception (SanitizedMessageException):**
```json
{
  "message": "An error occurred while processing the request. Status: 500, CorrelationId: abc-123"
}
```

**Middleware-caught exception (any other type):**
```json
{
  "message": "An error has occurred, Status: 500, CorrelationId: abc-123"
}
```

---

## Logging at Catch Sites

Every catch site does two things:

**1. Log a structured `ExceptionEvent`:**
```csharp
ExceptionEvent evt = new ExceptionEvent();
evt.Populate(
    appServices,
    nameof(WrappedException),  // HandledExceptionType — what we're about to throw
    caughtException);          // ExceptionType — what we actually caught
appServices.StructuredLogger.LogEvent(evt);
```

`ExceptionEvent` captures: `RequestId`, `TenantId`, `CurrentAppId`, `HandledExceptionType`, `ExceptionType`, `Message`, `Description` (stack trace), `Scenario` (file path), `SubScenario` (method name), `SourceLineNumber` — all sanitized via `TelemetryUtils.SanitizeValue`.

**2. Set an error code on the request context (controller catch sites):**
```csharp
RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ServiceErrorCodes.OutboundRequestExceptionErrorCode);
```
This feeds the QOS `InboundQOSEvent` and metric dimensions — essential for Jarvis dashboards showing failure rates by error category.

---

## What This Pattern Explicitly Rejects

| Rejected pattern | Why |
|-----------------|-----|
| `Result<T>` discriminated union | Not used in LENS services — handlers throw, controllers catch |
| `catch (Exception ex)` in a controller | Controllers catch only their own typed exception subclasses — unexpected exceptions must bubble naturally to middleware |
| `HttpStatusCode` on `HandlerException` | HTTP status codes are protocol-layer concerns; `HandlerException` subclasses carry only domain-layer meaning; the controller maps exception types to HTTP responses |
| Generic `FooHandlerException` for all failures with `StatusCode` discrimination | Collapses all domain failures into one catch clause and loses the sentinel property; each distinct routing outcome needs its own type |
| Returning error signals from DataAccess (null for errors) | `null` is only valid for a 404 on a point-read GET — the handler checks for null and throws. A 404 on delete/update throws `DataStoreException(NotFound)`; everything else throws |
| Middleware reading exception properties to decide status code | Middleware always returns 500; if it reached middleware, the controller did not handle it |
| Logging PII or secrets | `TelemetryUtils.SanitizeValue` applied to all logged fields |
| Exposing internal exception messages to callers | Only `SanitizedMessageException.Message` is exposed; all others suppressed |
