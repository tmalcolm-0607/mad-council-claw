# Handler Pattern Reference

> Complete implementation reference for the BusinessLogic Handler pattern used in all LENS services.

---

## Overview

All business logic lives in **handlers** — never in controllers, never in repositories. Each distinct operation area is expressed as an interface + a single `sealed` implementation. Handlers:

- Receive strongly typed parameters (individual arguments or typed request objects)
- Orchestrate one or more repository calls
- Apply business rules by inspecting results
- Throw typed `HandlerException` subclasses for business rule violations and "not found" conditions
- Catch `DataStoreException` from DataAccess and wrap it into the appropriate domain exception before rethrowing
- Return the result value directly on success — no discriminated union wrapper

---

## Exception Hierarchy

Domain exceptions belong in `Common/Exceptions/`. Every layer catches and rethrows only the specific types it is responsible for.

```
SanitizedMessageException : Exception
  ↑ message is safe to include in HTTP responses
  ↑ used by GlobalErrorHandlingMiddleware to decide response content

HandlerException : Exception
  ↑ base for all business-layer exceptions
  ↑ Properties: TimeSpan? RetryAfter (only for rate-limited scenarios)

  FooNotFoundException : HandlerException          ← entity not found
  FooLockedForDeletionException : HandlerException ← business rule violation
  FooDataAccessException : HandlerException        ← data tier failure; RetryAfter set when back-off was signalled
  ...

DataStoreException : Exception
  ↑ DataAccess only — wraps CosmosException
  ↑ Properties: HttpStatusCode? StatusCode, TimeSpan? RetryAfter
  ↑ RetryAfter flows through to FooDataAccessException as a neutral back-off duration
```

**Key types:**

| Type | Where defined | Purpose |
|------|--------------|---------|
| `SanitizedMessageException` | `Common/Exceptions/` | Marker: its `.Message` is safe to surface to the HTTP caller |
| `HandlerException` | `Common/Exceptions/` | Base for all business-layer exceptions; carries only `RetryAfter` (no status code) |
| `DataStoreException` | `Common/Exceptions/` | DataAccess wraps non-404 `CosmosException` here; `RetryAfter` is set when the Cosmos layer signalled a back-off interval |
| `ExternalServiceCallException` | `Common/Exceptions/` | Extends `SanitizedMessageException`; wraps any outbound call failure; message must be explicitly safe |

### Typed exceptions as sentinels

Each `HandlerException` subclass represents a **unique failure scenario** — not just a domain grouping. The exception type is the sentinel: the controller's catch ladder reads it as a logic gate and routes the request to a deterministic HTTP response. The controller — not the handler — decides the HTTP status code.

```
throw FooNotFoundException          →  catch (FooNotFoundException)                         →  404 NotFound
throw FooLockedForDeletionException →  catch (FooLockedForDeletionException)                →  422 UnprocessableEntity
throw FooDataAccessException        →  catch (FooDataAccessException) when RetryAfter set   →  429 + Retry-After
throw FooDataAccessException        →  catch (FooDataAccessException) when no RetryAfter    →  503
(anything else)                     →  not caught by controller                             →  GlobalErrorHandlingMiddleware → 500
```

**This is what makes system behaviour deterministic.** Every known failure scenario has one explicit type, one explicit catch clause, and one explicit HTTP response. Nothing is inferred. Nothing is ambiguous.

**When to create a new exception type:** when the controller needs a new row in its routing table — i.e., when a failure scenario produces a response that differs from all existing types (different status code, different headers, different body shape). If two scenarios produce identical controller behaviour, one type covering both is correct.

**HTTP status codes belong in the API layer.** `HandlerException` subclasses carry only business-layer meaning. A controller should `catch (FooNotFoundException)` and call `NotFound(...)` — not inspect a `StatusCode` property. Inspecting a property collapses all domain failures into one undifferentiated catch and loses the sentinel property.

---

## Handler Interface

Handler interfaces live in `BusinessLogic/Interfaces/`. Group by domain, not by operation — one interface per handler class, with one method per verb.

```csharp
// BusinessLogic/Interfaces/IFooHandler.cs
// partitionId is a generic placeholder — name it after your entity's partition key (e.g. tenantId, customerId)
public interface IFooHandler
{
    Task<Foo> GetFooAsync(Guid partitionId, Guid fooId);
    Task<Foo> CreateFooAsync(Foo foo);  // entity carries its own partition key value
    Task DeleteFooAsync(Guid partitionId, Guid fooId);
}
```

---

## Handler Implementation

```csharp
// BusinessLogic/Handlers/FooHandler.cs
public sealed class FooHandler : IFooHandler
{
    private readonly IFooRepository repository;
    private readonly ILogger<FooHandler> logger;

    public FooHandler(
        IFooRepository repository,
        ILogger<FooHandler> logger)
    {
        ParameterContracts.CheckIsNotNull(repository, nameof(repository));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.repository = repository;
        this.logger = logger;
    }

    // Pattern A — "not found" check after repository call (returns null for 404)
    public async Task<Foo> GetFooAsync(Guid partitionId, Guid fooId)
    {
        var foo = await this.repository.GetFooAsync(partitionId, fooId); // null for 404
        if (foo is null)
            throw new FooNotFoundException("Foo not found.");

        return foo;
    }

    // Pattern B — wrap DataStoreException; pass RetryAfter through as a neutral duration
    public async Task<Foo> CreateFooAsync(Foo foo)
    {
        try
        {
            return await this.repository.CreateFooAsync(foo);
        }
        catch (DataStoreException ex)
        {
            // RetryAfter is a TimeSpan — a neutral "wait this long" signal, not an HTTP concept
            throw new FooDataAccessException("Data access failed.", ex.RetryAfter, ex);
        }
    }

    // Pattern C — direct business rule throw (no wrapping needed)
    public async Task DeleteFooAsync(Guid partitionId, Guid fooId)
    {
        var foo = await this.repository.GetFooAsync(partitionId, fooId);
        if (foo is null)
            throw new FooNotFoundException("Foo not found.");

        if (foo.IsLocked)
            throw new FooLockedForDeletionException("Cannot delete a locked foo.");

        await this.repository.DeleteFooAsync(partitionId, fooId);
    }
}
```

---

## HandlerException Base Class

Define one `HandlerException` subclass per unique failure scenario, in `Common/Exceptions/`. The type name should describe the failure — it is the sentinel the controller catches. The controller decides the HTTP status code; the exception type decides the routing.

```csharp
// Common/Exceptions/HandlerException.cs
public abstract class HandlerException : Exception
{
    public TimeSpan? RetryAfter { get; }

    protected HandlerException(string message)
        : base(message) { }

    protected HandlerException(string message, Exception? inner)
        : base(message, inner) { }

    protected HandlerException(string message, TimeSpan? retryAfter, Exception? inner)
        : base(message, inner)
    {
        this.RetryAfter = retryAfter;
    }
}

// Common/Exceptions/FooNotFoundException.cs  — entity not found
public sealed class FooNotFoundException : HandlerException
{
    public FooNotFoundException(string message) : base(message) { }
}

// Common/Exceptions/FooLockedForDeletionException.cs  — business rule violation
public sealed class FooLockedForDeletionException : HandlerException
{
    public FooLockedForDeletionException(string message) : base(message) { }
}

// Common/Exceptions/FooDataAccessException.cs  — data tier failure; RetryAfter set when back-off was signalled
public sealed class FooDataAccessException : HandlerException
{
    public FooDataAccessException(string message, TimeSpan? retryAfter, Exception? inner)
        : base(message, retryAfter, inner) { }
}
```

**One type per routing outcome.** Two failure scenarios that produce the same controller response (same status code, same headers, same body shape) may share one type. If they diverge — different status code, different header, different body — each needs its own type.

---

## Controller — Mapping and Exception Handling

Controllers catch typed handler exceptions using `when` guards to map status codes to HTTP responses. On the success path, the domain type returned by the handler is mapped to a presentation type by `IPresentationModelFactory` before being serialised to HTTP. Anything not caught propagates to `GlobalErrorHandlingMiddleware` and becomes a 500.

```csharp
// API/Controllers/FooController.cs
[ApiController]
[Route("api/v1/[controller]")]
[Authorize(Policy = "ApplicationAuthorizationPolicy")]
public sealed class FooController : ControllerBase
{
    private readonly IFooHandler fooHandler;
    private readonly IPresentationModelFactory presentationFactory;
    private readonly ILogger<FooController> logger;

    public FooController(
        IFooHandler fooHandler,
        IPresentationModelFactory presentationFactory,
        ILogger<FooController> logger)
    {
        ParameterContracts.CheckIsNotNull(fooHandler, nameof(fooHandler));
        ParameterContracts.CheckIsNotNull(presentationFactory, nameof(presentationFactory));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.fooHandler = fooHandler;
        this.presentationFactory = presentationFactory;
        this.logger = logger;
    }

    [HttpGet("{fooId}")]
    public async Task<IActionResult> GetFooAsync(Guid fooId)
    {
        try
        {
            // tenantId extracted from auth claims — this is the partition key for this service
            var foo = await this.fooHandler.GetFooAsync(this.tenantId, fooId);
            return Ok(this.presentationFactory.GetFooResponse(foo));
        }
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
            // RetryAfter present means the data tier signalled a back-off interval
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
    }
}
```

**The presentation boundary:**

`IPresentationModelFactory` lives in `API/Presentation/` and owns all mappings from internal domain types to external HTTP contract types. It knows about Common domain types (allowed — API references Common) but its output types (`FooResponse`, etc.) never flow into BusinessLogic or DataAccess.

```csharp
// API/Presentation/IPresentationModelFactory.cs
public interface IPresentationModelFactory
{
    FooResponse GetFooResponse(Foo foo);
    FooListResponse GetFooListResponse(IList<Foo> foos);
}
```

**Key rules:**
- Controllers only catch their own domain's typed exception subclasses — nothing else
- The exception type determines the HTTP response — the controller decides the status code, not the handler
- Rate-limited responses (429) set the `Retry-After` header from `ex.RetryAfter`
- Unexpected exceptions are never caught in the controller — they bubble naturally to `GlobalErrorHandlingMiddleware`
- `RequestContextItems.ErrorCode.SetItem(...)` is called at every catch site (see `lens-telemetry` skill for QOS metric wiring)

---

## ParameterContracts

`ParameterContracts` is from `Microsoft.LENS.Common.Core`. Use it in every constructor and at the entry point of every public method receiving external input. Never use `ArgumentNullException.ThrowIfNull` — it bypasses the centralised check.

| Method | Guards against |
|--------|---------------|
| `CheckIsNotNull(value, name)` | Null reference |
| `CheckNonWhitespace(value, name)` | Null, empty, or whitespace string |
| `CheckIsGuidEmpty(value, name)` | `Guid.Empty` |
| `Check(boolExpr, name, message)` | Any boolean assertion |

```csharp
// ✅ GOOD
public FooHandler(IFooRepository dataStore, ILogger<FooHandler> logger)
{
    ParameterContracts.CheckIsNotNull(dataStore, nameof(dataStore));
    ParameterContracts.CheckIsNotNull(logger, nameof(logger));
    this.dataStore = dataStore;
    this.logger = logger;
}

// ❌ BAD
public FooHandler(IFooRepository dataStore, ILogger<FooHandler> logger)
{
    ArgumentNullException.ThrowIfNull(dataStore);   // wrong utility
    this.dataStore = dataStore ?? throw new ArgumentNullException(nameof(dataStore)); // also wrong
    this.logger = logger;                           // missing check entirely
}
```

---

## Emitting structured events from a handler

Handlers emit Geneva-bound structured events via the typed `ITelemetryContext<TLogger>.StructuredLogger.LogEvent(TEvent)` overload — never via `ILogger<T>` string-templated calls. The event class lives in `Common/Events/` (see `layer-responsibilities.md` "Logger and event types MUST live in the same assembly"); the handler injects `ITelemetryContext<MyServiceStructuredLogger>` (and `ILensAppContext` if it needs caller identity). Cite: `lens-telemetry` SKILL.md v1.3.0 Standards 5, 8.

```csharp
// Common/Events/FooLookupCompletedEvent.cs
[StructuredEvent("FooLookupCompletedEvent")]
public sealed partial class FooLookupCompletedEvent : IStructuredLogEvent
{
    public required string PartitionId { get; init; }
    public required string FooId { get; init; }
    public required string Outcome { get; init; }
    public required DateTimeOffset OccurredAt { get; init; }
    public long? DurationMs { get; init; }
}

// BusinessLogic/Handlers/FooHandler.cs
public sealed class FooHandler : IFooHandler
{
    private readonly IFooRepository dataStore;
    private readonly ITelemetryContext<MyServiceStructuredLogger> telemetryContext;

    public FooHandler(
        IFooRepository dataStore,
        ITelemetryContext<MyServiceStructuredLogger> telemetryContext)
    {
        ParameterContracts.CheckIsNotNull(dataStore, nameof(dataStore));
        ParameterContracts.CheckIsNotNull(telemetryContext, nameof(telemetryContext));
        this.dataStore = dataStore;
        this.telemetryContext = telemetryContext;
    }

    public async Task<Foo> GetFooAsync(string partitionId, string fooId, CancellationToken ct)
    {
        var sw = Stopwatch.StartNew();
        var foo = await this.dataStore.GetFooAsync(partitionId, fooId, ct);
        if (foo is null)
        {
            this.telemetryContext.StructuredLogger.LogEvent(new FooLookupCompletedEvent
            {
                PartitionId = partitionId,
                FooId = fooId,
                Outcome = "NotFound",
                DurationMs = sw.ElapsedMilliseconds,
                OccurredAt = DateTimeOffset.UtcNow,
            });
            throw new FooNotFoundException("Foo not found.");
        }

        this.telemetryContext.StructuredLogger.LogEvent(new FooLookupCompletedEvent
        {
            PartitionId = partitionId,
            FooId = fooId,
            Outcome = "Success",
            DurationMs = sw.ElapsedMilliseconds,
            OccurredAt = DateTimeOffset.UtcNow,
        });
        return foo;
    }
}
```

**Don't emit entry/exit events.** `LoggingAndMetricsMiddleware` already records `InboundQOSEvent` per request — adding handler-entry / handler-exit log lines duplicates that signal. Emit a structured event when the handler reaches a meaningful business outcome (lookup completed, validation rejected, write succeeded), not at routine execution boundaries.

---

## What This Pattern Explicitly Rejects

| Rejected pattern | Why |
|-----------------|-----|
| `Result<T>` discriminated union | Not used in LENS services — handlers throw, controllers catch |
| `catch (Exception ex)` in a controller | Controllers catch only their own typed exception subclasses — unexpected exceptions must bubble naturally to middleware |
| Returning `null` from a handler for "not found" | Handlers throw a typed `HandlerException` subclass; DataAccess returns `null` only at the Cosmos boundary |
| `HttpStatusCode` on `HandlerException` | HTTP status codes are protocol-layer concerns; `HandlerException` subclasses carry only domain-layer meaning; the controller maps exception types to HTTP responses |
| Generic `FooHandlerException` for all failures | Each distinct controller routing outcome needs its own type — the exception type is the routing gate |

> Full exception flow diagram, middleware behaviour, and error response shapes:
> [exception-handling-reference.md](exception-handling-reference.md)
