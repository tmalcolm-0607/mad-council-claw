---
paths:
  - "**/*.cs"
  - "**/LogMessages.cs"
  - "**/LogEvents.cs"
  - "**/LogEventIds*.cs"
  - "**/spec.md"
  - "**/plan.md"
---

# .NET Logging Patterns

> **Canonical: this file documents LENS-canonical patterns from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for logging, metrics, and observability in .NET projects.

## LENS Structured Events (Geneva-Bound) — Primary Pattern

For LENS services, **structured events are the primary logging mechanism** for anything operationally meaningful. They produce queryable Geneva DGrep columns; raw `ILogger` text fields require full-text scans.

Cite: `lens-telemetry` SKILL.md v1.3.0 Standards 4-7 (lines 157-313); advanced-patterns.md:65-87.

### Step 1: Define your service-specific structured logger (Standard 4)

```csharp
// CORRECT - sealed partial; [StructuredEventLogger] triggers source-gen of LogEvent(T) overloads
[StructuredEventLogger]
public sealed partial class MyServiceStructuredLogger : LensStructuredLogger
{
    public MyServiceStructuredLogger(ILoggerFactory factory) : base(factory) { }
}
```

The generator scans the **same assembly** for `[StructuredEvent]`-decorated classes and emits one `public void LogEvent(TEvent evt)` overload per event. It also populates `CategoryTableMappings` so `AddLensTelemetry<TLogger>()` configures the Geneva exporter automatically. **Do NOT call `Register<TEvent>()`** — that pattern is `[Obsolete]` (Standard 15) and the generic `LogEvent<TEvent>()` is also `[Obsolete]`. **Do NOT redefine** `InboundQOSEvent`/`OutboundQOSEvent`/`ExceptionEvent` — they are inherited from `LensStructuredLogger` (advanced-patterns.md:65-67).

### Step 2: Define structured events (Standard 5)

```csharp
// CORRECT - sealed partial; implements IStructuredLogEvent; [StructuredEvent("TableName")]
[StructuredEvent("DocumentProcessedEvent")]
public sealed partial class DocumentProcessedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public string? ProcessorName { get; set; }
    public long ProcessingTimeMs { get; set; }
    public int PageCount { get; set; }
    // GetProperties() generated automatically
}
```

Omit `partial` -> compiler emits **LENS0001** (event) or **LENS0003** (logger) and the source generator produces nothing.

### Step 3: Inject the concrete type (Standard 4)

```csharp
// CORRECT - inject the concrete subclass; resolves to generated overloads
public sealed class DocumentProcessor(MyServiceStructuredLogger logger) { }

// WRONG - injecting LensStructuredLogger loses service-specific LogEvent overloads
public sealed class DocumentProcessor(LensStructuredLogger logger) { }
```

### Step 4: Register the table in Geneva monitoring agent XML

The `[StructuredEvent("TableName")]` value must match a `<Source>` entry in the Geneva monitoring agent XML. New tables require XML update + agent redeploy.

### Step 5: Emit events (Standard 6)

```csharp
// CORRECT - structured event; queryable Geneva columns
this.logger.LogEvent(new DocumentProcessedEvent
{
    DocumentId = documentId,
    ProcessorName = nameof(DocumentProcessor),
    ProcessingTimeMs = sw.ElapsedMilliseconds,
});
```

`TraceId` and `SpanId` are auto-enriched by the OTel pipeline on every event (advanced-patterns.md:125-131). **Do NOT add `CorrelationId`/`TraceId`/`SpanId` properties to custom events** (anti-patterns.md:32) — they will produce duplicate DGrep columns.

### When to use raw `ILogger` (rare)

`LensStructuredLogger.Logger` exposes a per-type `ILogger` for **transient diagnostic output only** — startup noise, local debugging, things that produce a message-text field of no operational value (advanced-patterns.md:73-87). For anything operationally meaningful (a domain operation, a cache miss, an authorization decision), define a structured event instead.

```csharp
// AVOID for operationally meaningful logs - "OperationAction" buried in message string
_logger.Logger.LogDebug("Operation started for {Caller}", callerName);

// CORRECT - CallerName/OperationAction become queryable Geneva columns
this.logger.LogEvent(new SomeOperationEvent { CallerName = callerName, OperationAction = "Started" });
```

---

## `[LoggerMessage]` Source Generators — Non-Geneva / Unstructured Only

`[LoggerMessage]` source generators remain the right tool for **unstructured `ILogger` output** that does NOT flow through a Geneva structured-event table — host-level diagnostics, library-internal traces, console output during development. Compile-time generation eliminates string interpolation overhead.

```csharp
// CORRECT for non-Geneva diagnostic output - compile-time, high performance
public static partial class LogMessages
{
    // EventId is consumer-defined; no LENS-canonical layer-range scheme applies (see L120 disclaimer below).
    [LoggerMessage(EventId = /* <consumer-defined> */ 0, Level = LogLevel.Information,
        Message = "Processing request {RequestId} for user {UserId}")]
    public static partial void ProcessingRequest(this ILogger logger, string requestId, string userId);
}

// WRONG: Runtime interpolation - allocations + no structured fields
logger.LogInformation($"Processing request {requestId}");
```

For **Geneva-bound** logs (LENS services, anything operationally meaningful), use the structured-event pattern above instead — `[LoggerMessage]` produces a single message string, while `[StructuredEvent]` produces queryable per-property columns.

---

## EventId numbering (non-Geneva `[LoggerMessage]` only)

`[LoggerMessage]` requires an `EventId` integer. For LENS services, the Geneva-bound primary path (`[StructuredEvent("TableName")]`) is the canonical mechanism — it is keyed by table name, not numeric EventId. EventId numbering only applies to non-Geneva diagnostic `[LoggerMessage]` output (host traces, library-internal noise).

When a service does need numeric EventIds for `[LoggerMessage]`, layer-keyed ranges are a useful local convention but are **NOT a LENS-canonical standard** — adopt or skip per service. Cite: `lens-telemetry` SKILL.md Standards 4-7 (`[StructuredEvent]` for Geneva-bound; `[LoggerMessage]` for non-Geneva diagnostic only).

---

## Correlation — Use OTel TraceId, not Serilog `LogContext`

LENS services correlate via the **W3C TraceId** (`Activity.Current.TraceId`), automatically captured on every structured-event log record by the OTel pipeline (Standard 6; advanced-patterns.md:125-131). There is no `LogContext.PushProperty` step — correlation is free.

```csharp
// CORRECT - TraceId is auto-enriched on InboundQOSEvent, ExceptionEvent, OAuthSecurityEvent,
// and every custom structured event. Filter on TraceId in DGrep to reconstruct a request.
catch (Exception ex)
{
    this.logger.LogEvent(new ExceptionEvent(ex)); // CallerMemberName + TraceId already captured
}
```

The `correlationId` returned in the JSON body of a 500 response from `GlobalErrorHandlingMiddleware`
is the same `TraceId` (W3C trace ID) — paste it into a DGrep `TraceId =` filter to find every event from that request (advanced-patterns.md:130-131).

**Do NOT add `CorrelationId`, `TraceId`, or `SpanId` properties to custom structured events** — they are auto-enriched on every event; explicit properties create duplicate DGrep columns (anti-patterns.md:32).

`Serilog.Context.LogContext.PushProperty` is a Serilog API. LENS uses OTel + Geneva (not Serilog) — the API is unavailable and the pattern is unnecessary.

---

## Log-Before-Throw Pattern

```csharp
// CORRECT: Log before throw
if (user is null)
{
    this.logger.UserNotFound(userId);  // Log first
    throw new EntityNotFoundException($"User {userId} not found");
}
```

---

## QoS Metrics

> **QoS metrics**: provided automatically by `LoggingAndMetricsMiddleware` (part of `AddLensTelemetry<TLogger>()`). See `lens-telemetry` SKILL.md Standards 9 + 10 + advanced-patterns.md:38-39 for fixed availability/reliability thresholds (status ≤ 499 / ≤ 399). Do NOT define custom availability/reliability formulas locally — those are framework-owned.

---

## Log Level Guidelines

| Level | When to Use |
|-------|-------------|
| Information | Normal operations |
| Warning | Unexpected but handled |
| Error | Failures requiring attention |
| Critical | System-wide failures |

### Delete Operation Logging

Delete operations are operationally meaningful (audit trail, compliance signal, irreversibility) and therefore belong in the **LENS Structured Events (Geneva-bound)** primary pattern, NOT `[LoggerMessage]`. They require specific log levels based on reversibility:

| Operation | Log Level | Rationale |
|-----------|-----------|-----------|
| Soft delete | `Information` | Reversible, normal operation |
| Hard delete | `Warning` | Irreversible, needs audit trail |
| Bulk delete | `Warning` | High impact, needs visibility |

> **Critical: `[StructuredEvent]` log level is class-level AND POSITIONAL.** The `LogLevel` argument on `[StructuredEvent("TableName", LogLevel.Warning)]` is a POSITIONAL constructor argument, NOT a named property. `StructuredEventAttribute.LogLevel` is `{ get; }` get-only — verified at `references/LENS-Common/sources/dev/Telemetry/Logging/StructuredEventAttribute.cs:35-49` (constructor: `public StructuredEventAttribute(string tableName, LogLevel logLevel = LogLevel.Information)`; property: `public LogLevel LogLevel { get; }`). Named-property syntax `LogLevel = LogLevel.Warning` fails compilation with CS0200 (cannot assign to a read-only property). The level is ALSO set at the class level — ONE event class produces ONE log level. To honor the per-operation level table above, you MUST split into THREE event classes (one per `LogLevel`). This matches the canonical `ExceptionEvent.cs:17` form (`[StructuredEvent("ExceptionEvent", LogLevel.Error)]`).
>
> **Style note — prefer `nameof()` for the table-name argument.** `[StructuredEvent(nameof(MyEvent), LogLevel.Warning)]` keeps the table name in lock-step with the class name across renames; a plain string literal silently drifts when the class is renamed. The DCS local convention uses `nameof()` consistently; the kit recommends it for any new event classes. Both forms compile equivalently — the choice is rename-resilience, not semantics.

```csharp
// CORRECT - three event classes, one per log level (matches canonical ExceptionEvent pattern)

[StructuredEvent(nameof(DocumentSoftDeletedEvent), LogLevel.Information)]
public sealed partial class DocumentSoftDeletedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public string? ContainerName { get; set; }
    public string? ActorAlias { get; set; }
    public DateTimeOffset DeletedAt { get; set; }
}

[StructuredEvent(nameof(DocumentHardDeletedEvent), LogLevel.Warning)]
public sealed partial class DocumentHardDeletedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public string? ContainerName { get; set; }
    public string? ActorAlias { get; set; }
    public string? Reason { get; set; }              // why hard-delete was chosen (compliance, etc.)
    public DateTimeOffset DeletedAt { get; set; }
}

[StructuredEvent(nameof(DocumentBulkDeletedEvent), LogLevel.Warning)]
public sealed partial class DocumentBulkDeletedEvent : IStructuredLogEvent
{
    public string? ContainerName { get; set; }
    public int DocumentCount { get; set; }
    public string? ActorAlias { get; set; }
    public string? Reason { get; set; }
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset CompletedAt { get; set; }
}

// Emit — dispatch to the right event class based on the delete kind
switch (deleteKind)
{
    case DeleteKind.Soft:
        this.logger.LogEvent(new DocumentSoftDeletedEvent
        {
            DocumentId = documentId,
            ContainerName = containerName,
            ActorAlias = actorAlias,
            DeletedAt = DateTimeOffset.UtcNow,
        });
        break;
    case DeleteKind.Hard:
        this.logger.LogEvent(new DocumentHardDeletedEvent
        {
            DocumentId = documentId,
            ContainerName = containerName,
            ActorAlias = actorAlias,
            Reason = reason,
            DeletedAt = DateTimeOffset.UtcNow,
        });
        break;
    case DeleteKind.Bulk:
        this.logger.LogEvent(new DocumentBulkDeletedEvent
        {
            ContainerName = containerName,
            DocumentCount = affectedCount,
            ActorAlias = actorAlias,
            Reason = reason,
            StartedAt = startedAt,
            CompletedAt = DateTimeOffset.UtcNow,
        });
        break;
}
```

> **Why three event classes (not one with a `DeleteKind` discriminator)**: `[StructuredEvent]` sets `LogLevel` at the class level (the attribute is class-targeted; a single class produces a single `<Source>` table at a single fixed level). One class with three intended levels cannot vary level by instance — Geneva would write all three at whichever level the attribute declared. Splitting into three classes also gives you three distinct Geneva DGrep tables (`DocumentSoftDeletedEvent`, `DocumentHardDeletedEvent`, `DocumentBulkDeletedEvent`), so an auditor can query "all hard deletes in the last 30 days" with a single `where Source == 'DocumentHardDeletedEvent'` predicate instead of `where Source == 'DocumentDeletedEvent' and DeleteKind == 'hard'`. This matches the canonical `ExceptionEvent` / `OAuthSecurityEvent` / `InboundQOSEvent` shape (one class = one table = one level).

> **Don't forget Geneva agent XML registration**: each new `[StructuredEvent("TableName")]` requires a matching `<Source>` entry in the Geneva monitoring agent XML and an agent redeploy — three event classes = three `<Source>` entries.

`[LoggerMessage]` remains acceptable for **non-Geneva diagnostic output** during development (host-level traces, library-internal noise), but operationally meaningful events — including every delete — flow through `[StructuredEvent]`.

---

## Enforcement

| Rule | Severity |
|------|----------|
| String interpolation in log | **REJECT** |
| Missing Event ID | **REJECT** |
| Throw without logging | **REJECT** |
| Sensitive data in logs | **REJECT** |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| `logger.Log*($"...")` for any log line | `[StructuredEvent]` for Geneva-bound / operationally meaningful events; `[LoggerMessage]` for non-Geneva diagnostic output (host traces, library-internal noise) |
| `[LoggerMessage]` for operationally meaningful events (delete, auth decision, domain transition) | `[StructuredEvent]` per the LENS Structured Events primary pattern (queryable Geneva DGrep columns) |
| Catch-log-throw | Log at handling point only |
| Generic "An error occurred" | Include context and IDs |
| Logging in tight loops | Log aggregates or sample |
