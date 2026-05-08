---
name: lens-telemetry
description: >
  Use this skill when implementing or reviewing telemetry in a LENS service. Covers
  Program.cs registration (AddLensTelemetry, AddMiseAuthContextBuilder, AddCosmosDbTelemetry, AddBlobClientTelemetry),
  middleware pipeline ordering, structured events ([StructuredEvent], [StructuredEventLogger]),
  custom metrics ([Counter]/[Histogram]), ITelemetryContext/ITelemetryContext&lt;TLogger&gt;, ILensAppContext,
  ISyntheticRequestDetector, RequestContextItems, CosmosDbActivityProcessor, BlobClientActivityProcessor, and
  PostAuthTelemetryMiddleware. Also apply when reviewing QOS metric accuracy, event
  property design, metric dimension choices, security event identity fields, or
  Geneva/OpenTelemetry wiring in an ASP.NET Core service.
license: private
compatibility: Requires C# LSP and .NET toolchain for in-editor navigation.
metadata:
  version: "1.3.0"
  author: jacote@microsoft.com
  release_date: "2026-04-10"
allowed-tools: Read Edit Write Glob Grep Bash
user-invocable: true
---

# LENS Telemetry Coding Skill

Enforce correct patterns for `Microsoft.LENS.Common.Telemetry`: structured logging, inbound/outbound QOS metrics, and distributed tracing via OpenTelemetry to Geneva.

## Prerequisites

- `<PackageReference Include="Microsoft.LENS.Common.Telemetry" Version="..." />` from the Enzyme NuGet feed (`o365exchange.pkgs.visualstudio.com`)
- A Geneva logs account and metrics account/namespace provisioned for the service
- ASP.NET Core 8+ service

---

## Standard 1: Configuration — Use the `GenevaTelemetry` Section

**Rule:** All telemetry configuration lives under the `GenevaTelemetry` key in `appsettings.json`. Never read `BUILD_VERSION` or `WEBSITE_INSTANCE_ID` directly from `IConfiguration` in service code — the library resolves these automatically.

```jsonc
// ✅ GOOD — appsettings.json
{
  "GenevaTelemetry": {
    "MetricsAccount": "MyMetricsAccount",
    "MetricsNamespace": "MyMetricsNamespace",
    "Telemetry": {
      "LongRequestThresholdMs": 1000,
      "BuildVersion": "1.0.0.0"
    }
  }
}
```

On Azure App Service, `MonitoringRole` and `MdsRoleInstance` default to `WEBSITE_SITE_NAME` and `WEBSITE_INSTANCE_ID` respectively — omit them unless you need to override. Set them explicitly only when deploying outside App Service (AKS, on-premises) or when the App Service resource name differs from the desired service name in Geneva:

```jsonc
// ✅ GOOD — non-App-Service or name override
{
  "GenevaTelemetry": {
    "MonitoringRole": "MyService",
    "MdsRoleInstance": "pod-eastus-7d9f4b",
    "MetricsAccount": "MyMetricsAccount",
    "MetricsNamespace": "MyMetricsNamespace",
    "Telemetry": {
      "LongRequestThresholdMs": 1000,
      "BuildVersion": "1.0.0.0"
    }
  }
}
```

| Property | Section | Default | Purpose |
|---|---|---|---|
| `MonitoringRole` | `GenevaTelemetry` | `WEBSITE_SITE_NAME` | `cloud.role` on all logs and traces |
| `MdsRoleInstance` | `GenevaTelemetry` | `WEBSITE_INSTANCE_ID` | `cloud.roleInstance` + `ServiceInstance` metric dimension |
| `MetricsAccount` | `GenevaTelemetry` | — | **Required** for Geneva metrics export |
| `MetricsNamespace` | `GenevaTelemetry` | — | **Required** for Geneva metrics export |
| `LongRequestThresholdMs` | `GenevaTelemetry:Telemetry` | no default (0 if omitted — see note) | Latency threshold for `InboundQOSEvent` emission; hot-reloadable |
| `BuildVersion` | `GenevaTelemetry:Telemetry` | — | Written to every `InboundQOSEvent` |
| `MinLatencyMs` | `GenevaTelemetry:CosmosDbDiagnostics` | `null` (log all) | Log only Cosmos DB calls at or above this latency (ms); hot-reloadable |
| `MinRequestChargeRu` | `GenevaTelemetry:CosmosDbDiagnostics` | `null` (log all) | Log only Cosmos DB calls at or above this RU charge; hot-reloadable |
| `ErrorsOnly` | `GenevaTelemetry:CosmosDbDiagnostics` | `true` | Log only non-2xx Cosmos DB responses; hot-reloadable |
| `AlwaysLogExceptions` | `GenevaTelemetry:CosmosDbDiagnostics` | `true` | Always log when a Cosmos DB call throws; overrides other filters |
| `MinSuccessStatusCode` | `GenevaTelemetry:CosmosDbDiagnostics` | `200` | Minimum HTTP status code considered successful; hot-reloadable |
| `MaxSuccessStatusCode` | `GenevaTelemetry:CosmosDbDiagnostics` | `299` | Maximum HTTP status code considered successful; hot-reloadable |
| `MinLatencyMs` | `GenevaTelemetry:BlobClientDiagnostics` | `null` (log all) | Log only Blob Storage calls at or above this latency (ms); hot-reloadable |
| `ErrorsOnly` | `GenevaTelemetry:BlobClientDiagnostics` | `true` | Log only non-2xx Blob Storage responses; hot-reloadable |
| `AlwaysLogExceptions` | `GenevaTelemetry:BlobClientDiagnostics` | `true` | Always log when a Blob Storage call throws; overrides other filters |
| `MinSuccessStatusCode` | `GenevaTelemetry:BlobClientDiagnostics` | `200` | Minimum HTTP status code considered successful; hot-reloadable |
| `MaxSuccessStatusCode` | `GenevaTelemetry:BlobClientDiagnostics` | `299` | Maximum HTTP status code considered successful; hot-reloadable |

> **`LongRequestThresholdMs` footgun:** If omitted, the property defaults to `0`. The middleware emits `InboundQOSEvent` when `latency > LongRequestThresholdMs`, so a value of 0 means every request emits the event (any measurable latency is > 0 ms). Always set this to a meaningful threshold — 1000 ms is a common starting point. The `[Range(1, int.MaxValue)]` validation applies only when the key is present; it does not enforce that the key is set.

> For startup-time resolution behaviour and local development setup, see [Advanced patterns](references/advanced-patterns.md#standard-1--configuration).

---

## Standard 2: Service Registration — Register Before Your Own Services

**Rule:** Call `AddLensTelemetry<TLogger>` passing your service-specific logger subclass. All internal registrations use `TryAdd`, so any type you register **before** this call takes precedence. This applies to the overridable interfaces: `IRequestContextBuilder`, `IAuthContextBuilder`, `ITelemetryContext`, `ILensAppContext`, and `ISyntheticRequestDetector`.

```csharp
// ✅ GOOD — Program.cs
builder.Services.AddSingleton<IRequestContextBuilder, MyRequestContextBuilder>(); // overrides default — BEFORE AddLensTelemetry
builder.Services.AddSingleton<IAuthContextBuilder, MyAuthContextBuilder>();       // overrides default — BEFORE AddLensTelemetry
builder.Services.AddSingleton<ISyntheticRequestDetector, HeartbeatDetector>();    // supplements built-in detection
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"),
    enableConsoleLogging: builder.Environment.IsDevelopment(),
    configureViews: b => b.AddView(              // optional: override histogram views
        instrumentName: "MyLatencyMetric",
        new ExplicitBucketHistogramConfiguration { Boundaries = new double[] { 0, 50, 100, 250, 500 } }));
```

```csharp
// ❌ BAD — registering override AFTER AddLensTelemetry; TryAdd means the library's default wins
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(...);
builder.Services.AddSingleton<IRequestContextBuilder, MyRequestContextBuilder>(); // ← ignored
builder.Services.AddSingleton<IAuthContextBuilder, MyAuthContextBuilder>();       // ← also ignored
```

> **Exception — `AddMiseAuthContextBuilder()` is order-independent.** Unlike the four `TryAdd`-governed interfaces above, `AddMiseAuthContextBuilder()` from `Microsoft.LENS.Common.Telemetry.MISE` uses replace semantics — it removes any existing `IAuthContextBuilder` registration and installs `MiseAuthContextBuilder` as a singleton. Call it before or after `AddLensTelemetry`; either order works:
>
> ```csharp
> // ✅ GOOD — either order is safe for AddMiseAuthContextBuilder
> builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(...);
> builder.Services.AddMiseAuthContextBuilder(); // ← replaces the default registered above
> ```
>
> See [Standard 13](#standard-13-mise-v2-authentication--use-miseauthcontextbuilder) for the complete MISE V2 setup.

---

## Standard 3: Middleware Ordering

**Rule:** The three telemetry middleware components must appear in this exact order after `UseRouting()`:

```csharp
// ✅ GOOD
app.UseRouting();
app.UseMiddleware<InitializeTelemetryContextMiddleware>(); // 1 — populates ITelemetryContext, ILensAppContext
app.UseMiddleware<LoggingAndMetricsMiddleware>();          // 2 — times the request; QOS recorded in finally
app.UseMiddleware<GlobalErrorHandlingMiddleware>();        // 3 — catches exceptions; returns 500 JSON
app.UseAuthentication();                                  // JWT decoded; HttpContext.User populated
app.UseMiddleware<PostAuthTelemetryMiddleware>();          // 4 — builds IAuthContext; emits OAuthSecurityEvent
app.UseAuthorization();
app.MapControllers();
```

- **`InitializeTelemetryContextMiddleware`** must be first — everything else reads from `ITelemetryContext` and `ILensAppContext`.
- **`LoggingAndMetricsMiddleware`** wraps `GlobalErrorHandlingMiddleware` so the QOS `finally` block sees the 500 response written by the error handler, not an unhandled exception status.
- **`GlobalErrorHandlingMiddleware`** is optional but recommended — omit only if your host already provides equivalent behaviour.
- **`PostAuthTelemetryMiddleware`** must be placed after `UseAuthentication()` so the JWT is fully decoded and `HttpContext.User` is populated before `IAuthContextBuilder` runs. It is also optional — omit it if your service does not use authentication. When an unauthenticated request arrives (`IAuthContextBuilder` returns `null`), the middleware skips event emission and calls next normally.

All four middleware components are provided by the library — do not implement service-local equivalents. See [Anti-patterns](references/anti-patterns.md#middleware-ordering) for common ordering mistakes.

---

## Standard 4: Service-Specific Structured Logger

**Rule:** Create a `sealed partial` subclass of `LensStructuredLogger`, apply `[StructuredEventLogger]`, and write only a pass-through constructor. The source generator automatically emits a strongly-typed `LogEvent(T)` overload for every `[StructuredEvent]`-decorated class in the same assembly and populates `CategoryTableMappings` — no `Register<TEvent>()` calls needed.

```csharp
// ✅ GOOD — [StructuredEventLogger] + partial; generator does the rest
[StructuredEventLogger]
public sealed partial class MyServiceStructuredLogger : LensStructuredLogger
{
    public MyServiceStructuredLogger(ILoggerFactory factory) : base(factory) { }
}

// In Program.cs:
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(/* ... */);
```

```csharp
// ❌ BAD — old Register<TEvent>() pattern; still compiles but [Obsolete]
public sealed class MyServiceStructuredLogger : LensStructuredLogger
{
    public MyServiceStructuredLogger(ILoggerFactory factory) : base(factory)
    {
        Register<DocumentProcessedEvent>(); // [Obsolete] — remove and use [StructuredEventLogger] instead
        Register<QuotaExceededEvent>();
    }
}
```

If the class is not declared `partial`, the compiler emits **LENS0003** and no `LogEvent` overloads are generated.

Inject the concrete logger type (not `LensStructuredLogger`) so call sites resolve to the generated overloads and IntelliSense is accurate:

```csharp
// ✅ GOOD
public class DocumentProcessor(MyServiceStructuredLogger logger) { }

// ❌ BAD — loses service-specific LogEvent overloads; inject the concrete type
public class DocumentProcessor(LensStructuredLogger logger) { }
```

> For `OnEventLogged` test hook usage and structured-vs-unstructured guidance, see [Advanced patterns](references/advanced-patterns.md#standard-4--structured-logger).

---

## Standard 5: Defining Custom Structured Events

**End-to-end recipe:**
1. Define a `sealed partial` class implementing `IStructuredLogEvent` with `[StructuredEvent("TableName")]`
2. The source generator emits `GetProperties()` and a `LogEvent(T)` overload on your logger — no registration call needed
3. Add the table name to the Geneva monitoring agent XML and redeploy the agent (see [Geneva agent configuration](references/geneva-agent-config.md))
4. Inject your concrete logger and call `_logger.LogEvent(new MyEvent { ... })`

**Rule:** Event classes must be `sealed partial`, implement `IStructuredLogEvent`, and be decorated with `[StructuredEvent("TableName")]`. The `partial` keyword is required so the generator can emit `GetProperties()`. Every `public` instance property is automatically captured as a structured field. The table name in `[StructuredEvent]` must match the Geneva monitoring agent table configuration.

```csharp
// ✅ GOOD — informational event
[StructuredEvent("DocumentProcessedEvent")]
public sealed partial class DocumentProcessedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public string? ProcessorName { get; set; }
    public long ProcessingTimeMs { get; set; }
    public int PageCount { get; set; }
    // GetProperties() generated automatically
}

// ✅ GOOD — warning-level event with explicit log level
[StructuredEvent("QuotaExceededEvent", LogLevel.Warning)]
public sealed partial class QuotaExceededEvent : IStructuredLogEvent
{
    public string? TenantId { get; set; }
    public long CurrentUsage { get; set; }
    public long Limit { get; set; }
}
```

```csharp
// ❌ BAD — missing partial (LENS0001 error); not sealed; wrong base type
public class DocumentProcessedEvent : EventBase { }  // ← wrong
```

After creating the event class, register its table in the Geneva monitoring agent configuration for your logs account. See [Geneva agent configuration](references/geneva-agent-config.md) for the full XML setup and redeployment steps.

> For property design guidelines and constructor-based event examples, see [Advanced patterns](references/advanced-patterns.md#standard-5--custom-structured-events).

---

## Standard 6: Logging Events and Using ExceptionEvent

**Rule:** Call `LogEvent(new MyEvent { ... })` on the injected logger. For unhandled exceptions, `GlobalErrorHandlingMiddleware` logs `ExceptionEvent` automatically. Use `ExceptionEvent` explicitly in catch blocks or to mark degraded state without an exception.

```csharp
// ✅ GOOD — informational event
_logger.LogEvent(new DocumentProcessedEvent
{
    DocumentId = documentId,
    ProcessorName = nameof(DocumentProcessor),
    ProcessingTimeMs = sw.ElapsedMilliseconds,
});
```

**In catch blocks, `ExceptionEvent` already captures `CallerMemberName` (the method), `CallerFilePath`, and `CallerLineNumber` via compiler attributes, and `TraceId` is auto-enriched for correlation back to `InboundQOSEvent`.** The gap is entity-level context: if the catch block has a document ID, partition key, batch ID, or similar that won't appear in `InboundQOSEvent` and isn't worth a trace join to find, emit a context event before `ExceptionEvent`.

```csharp
// ✅ GOOD — ExceptionEvent alone is sufficient when CallerMemberName + TraceId provide enough context
catch (Exception ex)
{
    _logger.LogEvent(new ExceptionEvent(ex));
    return StatusCode(503);
}

// ✅ GOOD — context event adds entity-level data (documentId) not available via trace correlation
catch (Exception ex)
{
    _logger.LogEvent(new DocumentOperationEvent
    {
        DocumentId = documentId,
        Status = "Failed",
    });
    _logger.LogEvent(new ExceptionEvent(ex));
    return StatusCode(503);
}
```

---

## Standard 7: Defining Custom Metrics

**Counter vs Histogram:**

| Instrument | Use when | Jarvis aggregation |
|---|---|---|
| `[Counter]` | Counting discrete occurrences — items processed, quota violations, cache hits | Sum / rate |
| `[Histogram]` | Continuous measurements needing distribution — latency (ms), payload size (bytes) | P50 / P95 / P99 |

Rule of thumb: **"how many?"** → Counter. **"how fast / how large?"** → Histogram.

> **Histogram bucketing:** The library pre-configures explicit 25 ms-interval buckets (0–120,000 ms) for the built-in `InboundRequestLatencyMetric` and `OutboundRequestLatencyMetric` — this is what makes accurate P50/P95/P99 percentiles possible in Jarvis. Custom histograms do **not** inherit this configuration. They use OTel's default coarse buckets unless an explicit `ExplicitBucketHistogramConfiguration` view is registered. When adding a custom latency histogram, register a matching view or the percentile data will be inaccurate.

> For cardinality guidelines, meter naming, and the Fast Metering pattern details, see [Advanced patterns](references/advanced-patterns.md#standard-7--custom-metrics).

**Rule:** Use the `[Counter]` and `[Histogram]` source-generator attributes on a `static partial` class. Dimension names are passed as string arguments to the attribute. Reuse constants from `TelemetryConstants` for shared dimensions and define a parallel constants class for service-specific dimension names — casing inconsistencies across metrics silently break cross-metric Jarvis queries.

```csharp
// ✅ GOOD
public static partial class MyServiceMetrics
{
    [Counter(TelemetryConstants.ServiceInstanceDimension, "ProcessorName", "Outcome")]
    public static partial DocumentsProcessedMetric CreateDocumentsProcessedMetric(Meter meter);
}

// ❌ BAD — string literals; "ProcessorName" vs "processorName" breaks queries
[Counter("ServiceInstance", "TenantId", "ProcessorName")]
```

> For the service-constants pattern (recommended for multi-metric classes) and the Fast Metering pattern, see [Advanced patterns](references/advanced-patterns.md#standard-7--custom-metrics).

---

## Standard 8: Recording Metrics and Scoped Service Wiring

**Rule:** Create metric instruments once and reuse them — in the constructor for singletons, via `IMeterFactory` from `ITelemetryContext` for scoped services. Scoped services should inject `ITelemetryContext<TLogger>` (typed metrics/logging — gives `LogEvent(T)` overloads without casting; use non-generic `ITelemetryContext` when only `IMeterFactory`/`ILogger` is needed) and `ILensAppContext` (request/auth context) rather than individual `ILogger` + `IMeterFactory`. Any service that depends on either must be registered as **Scoped**.

```csharp
// ❌ BAD — individual deps miss auth context; forces extra params when security events are needed later
public class SasRequestPipeline(ILogger<SasRequestPipeline> logger, IMeterFactory meterFactory) { }

// ✅ GOOD — typed ITelemetryContext gives direct LogEvent(T) overloads; ILensAppContext provides auth/request context
public class SasRequestPipeline(
    ITelemetryContext<MyServiceStructuredLogger> telemetryContext,
    ILensAppContext appContext)
{
    private readonly SasOperationMetric _metric =
        SasMetrics.CreateSasOperationMetric(telemetryContext.MeterFactory.Create("MyService.Sas"));

    public void Process()
    {
        telemetryContext.StructuredLogger.LogEvent(new SasRequestEvent { ... }); // no cast needed
    }
}
```

```csharp
// ❌ BAD — ITelemetryContext is scoped per-request; singleton cannot safely hold it
services.AddSingleton<SasRequestPipeline>();

// ✅ GOOD — lifetime must match ITelemetryContext
services.AddScoped<SasRequestPipeline>();
```

Never call `meterFactory.Create()` inside a request handler method body — create instruments once in the constructor. No additional meter registration is needed — `AddLensTelemetry` configures `.AddMeter("*")`. See [Advanced patterns](references/advanced-patterns.md#standard-8--recording-metrics) for singleton examples.

---

## Standard 9: Custom Synthetic Traffic Detection

**Rule:** To mark additional inbound traffic as synthetic (health checks, load test traffic, internal tooling) without subclassing, register an `ISyntheticRequestDetector`. The detector receives the full inbound `HttpContext` and can inspect any aspect of the request.

```csharp
// ✅ GOOD — DI registration, no subclassing required
public sealed class HeartbeatDetector : ISyntheticRequestDetector
{
    public bool IsSynthetic(HttpContext httpContext)
        => httpContext.GetRouteValue("action") is "Heartbeat" or "HealthCheck";
}

// In Program.cs, before AddLensTelemetry:
builder.Services.AddSingleton<ISyntheticRequestDetector, HeartbeatDetector>();
```

Any number of detectors can be registered. If any one returns `true`, the request is marked synthetic. All registered detectors run **in addition to** the built-in `User-Agent` checks.

Requests marked synthetic have `MetAvailabilityBar` and `MetReliabilityBar` forced to `"True"` and `IsSynthetic = "True"` emitted as a metric dimension, enabling `IsSynthetic = "False"` Jarvis filters that show real-traffic-only views in Geneva dashboards.

The built-in detection (via `KnownSyntheticUserAgents` constants) already handles `AlwaysOn`, `AppInsights`, `MSFT URSA-WebScanning`, and `jndi:ldap` — no code needed for those.

> For case-sensitivity caveats and replacing vs supplementing built-in detection, see [Advanced patterns](references/advanced-patterns.md#standard-9--synthetic-detection).

---

## Standard 10: Per-Request Context Items

**Rule:** Use `RequestContextItems` (from `Microsoft.LENS.Common.Core`) to set error codes and reliability scenario escape hatches on the current request. These are read by `LoggingAndMetricsMiddleware` at request end and written to QOS metrics and events.

```csharp
// ✅ GOOD — accumulate error codes (pipe-delimited automatically if called multiple times)
RequestContextItems.ErrorCode.SetItem(appContext.RequestContext, "RATE_LIMIT_EXCEEDED");
RequestContextItems.ErrorCode.SetItem(appContext.RequestContext, "QUOTA_EXCEEDED"); // results in "RATE_LIMIT_EXCEEDED|QUOTA_EXCEEDED"

// ✅ GOOD — reliability escape hatch: count this non-2xx as meeting the reliability bar
// Use for known challenge-response flows (e.g. OAuth 401, expected 404)
RequestContextItems.ReliabilityScenario.SetItem(appContext.RequestContext, "OAuth2Challenge");

// ⚠ AVOID — works at runtime but scatters detection logic; use ISyntheticRequestDetector instead
// (centralized, testable, covers all code paths — see Standard 9)
RequestContextItems.IsSynthetic.SetItem(appContext.RequestContext, true);
```

> **`SetItem` with an empty string is a no-op** — the accessor silently ignores empty values and does not clear or reset an existing error code. There is no way to clear `ErrorCode` once set on a request.

> For sentinel values in Geneva dashboards and defining custom context item accessors, see [Advanced patterns](references/advanced-patterns.md#standard-10--per-request-context-items).

---

## Standard 11: Cosmos DB Telemetry — `AddCosmosDbTelemetry()`

**Rule:** Call `services.AddCosmosDbTelemetry()` (on `IServiceCollection`) after `AddLensTelemetry` in any service that uses Cosmos DB. Also enable distributed tracing on the `CosmosClient`. This registers `CosmosDbActivityProcessor`, which hooks into the Cosmos DB SDK's built-in OpenTelemetry instrumentation and works with both **Direct mode (RNTBD/TCP)** and **Gateway mode (HTTPS)**.

```csharp
// ✅ GOOD — Program.cs
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"));

builder.Services.AddCosmosDbTelemetry(); // opt-in; no-op if Cosmos DB is not used
```

```csharp
// ✅ GOOD — CosmosClient setup; distributed tracing must be enabled
var cosmosClient = new CosmosClient(connectionString, new CosmosClientOptions
{
    CosmosClientTelemetryOptions = new CosmosClientTelemetryOptions
    {
        DisableDistributedTracing = false,
    },
});
```

**Filtering `CosmosDbDiagnosticsEvent`** — by default only error responses emit a log entry (`ErrorsOnly = true`). To also log slow or expensive successful calls, set `MinLatencyMs` or `MinRequestChargeRu` under `GenevaTelemetry:CosmosDbDiagnostics`. All other signals (RU charge metric, QOS event, QOS metrics) are unconditional. Filters combine with OR logic. See Standard 1 config table for all options.

**Handler-based approach (removed in 1.4.0):** `IHttpClientBuilder.AddCosmosDbTelemetry()` registered `CosmosDbTelemetryHandler`, which only intercepted Gateway mode (HTTPS) requests. It was removed in 1.4.0 — migrate to `services.AddCosmosDbTelemetry()` on `IServiceCollection` instead. See the [outbound telemetry migration guide](../../../docs/outbound-telemetry.md) for step-by-step instructions.

---

## Standard 12: Azure Blob Storage Telemetry — `AddBlobClientTelemetry()`

**Rule:** Call `services.AddBlobClientTelemetry()` (on `IServiceCollection`) after `AddLensTelemetry` in any service that uses Azure Blob Storage. This registers `BlobClientActivityProcessor`, which hooks into the Azure.Storage.Blobs SDK's built-in OpenTelemetry instrumentation. **Distributed tracing is enabled by default** in the Azure SDK — no additional client configuration is required.

```csharp
// ✅ GOOD — Program.cs
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"));

builder.Services.AddBlobClientTelemetry(); // opt-in; no-op if Blob Storage is not used
```

```csharp
// ✅ GOOD — BlobServiceClient setup; distributed tracing is enabled by default
var blobServiceClient = new BlobServiceClient(connectionString);
// No additional configuration needed — Azure SDK emits activities automatically
```

**Filtering `BlobClientDiagnosticsEvent`** — by default only error responses emit a log entry (`ErrorsOnly = true`). To also log slow successful calls, set `MinLatencyMs` under `GenevaTelemetry:BlobClientDiagnostics`. All other signals (QOS event, QOS metrics) are unconditional. Filters combine with OR logic.

| Property | Section | Default | Purpose |
|---|---|---|---|
| `MinLatencyMs` | `GenevaTelemetry:BlobClientDiagnostics` | `null` (log all) | Log only Blob Storage calls at or above this latency (ms); hot-reloadable |
| `ErrorsOnly` | `GenevaTelemetry:BlobClientDiagnostics` | `true` | Log only non-2xx Blob Storage responses; hot-reloadable |
| `AlwaysLogExceptions` | `GenevaTelemetry:BlobClientDiagnostics` | `true` | Always log when a Blob Storage call throws; overrides other filters |
| `MinSuccessStatusCode` | `GenevaTelemetry:BlobClientDiagnostics` | `200` | Minimum HTTP status code considered successful; hot-reloadable |
| `MaxSuccessStatusCode` | `GenevaTelemetry:BlobClientDiagnostics` | `299` | Maximum HTTP status code considered successful; hot-reloadable |

---

## Standard 13: Custom Histogram Views via `configureViews`

**Rule:** When a service defines a custom `[Histogram]` metric, register an `ExplicitBucketHistogramConfiguration` view using the `configureViews` callback on `AddLensTelemetry`. Without explicit buckets, OTel's default coarse boundaries produce inaccurate P95/P99 percentiles in Jarvis. The built-in `InboundRequestLatencyMetric`, `OutboundRequestLatencyMetric`, and `CosmosDbRequestChargeMetric` already have explicit views — no work needed for those.

> For code examples, see [Advanced patterns](references/advanced-patterns.md#standard-13--custom-histogram-views).

---

## Standard 14: MISE V2 Authentication — Use `MiseAuthContextBuilder`

**Rule:** On all LENS services running MISE V2, register `MiseAuthContextBuilder` from `Microsoft.LENS.Common.Telemetry.MISE`. Never use the built-in `DefaultAuthContextBuilder` on a MISE V2 service — it reads `HttpContext.User`, which on MISE V2 is a projected/reduced identity that strips most Entra ID claims (`tid`, `oid`, `idtyp`, `appid`/`azp`, etc.). `MiseAuthContextBuilder` calls `httpContext.GetMiseResult()` to read the complete pre-projection identity from `MiseResult.AuthenticationTicket.SubjectIdentity`.

```csharp
// ✅ GOOD — MISE V2 registration; order relative to AddLensTelemetry does not matter
builder.Services.AddMiseAuthContextBuilder();
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"));
```

```csharp
// ❌ BAD — DefaultAuthContextBuilder reads the projected HttpContext.User on MISE V2;
//          most IAuthContext fields will be "Undefined" in production
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(...);
// AddMiseAuthContextBuilder() never called
```

> For `TokenProtocol` field values, the MISE V2 projection boundary mechanism, and CDT identity source details, see [Advanced patterns](references/advanced-patterns.md#standard-14--mise-v2-authentication).

---

## Standard 15: Migrating from `Register<TEvent>()` to `[StructuredEventLogger]`

The old `Register<TEvent>()` pattern is `[Obsolete]` and will be removed. Three steps: (1) add `[StructuredEventLogger]` and `partial` to the logger class, remove all `Register<TEvent>()` calls; (2) add `partial` to each event class and delete any manual `GetProperties()` implementations; (3) rebuild — the generator emits all `LogEvent` overloads. Call sites do not change.

> For before/after code examples, see [Advanced patterns](references/advanced-patterns.md#standard-15--migration-from-registertevents).

---

## Standard 16: Structured Event Property Design — No Catch-All Fields

**Rule:** Every value you need to filter on in DGrep must be its own property. DGrep cannot filter on substrings within a column — only on full column values. If you find yourself writing `$"Key={value}|Key2={value2}"` as a field value, each key belongs as a separate property. A short human-readable `Detail` string is fine, but it must never be the primary carrier of filterable data.

> For before/after code examples, see [Advanced patterns](references/advanced-patterns.md#standard-16--no-catch-all-fields).

---

## Standard 17: Custom Metric Design — Consolidate with Dimensions

**Rule:** Design metrics to be multi-dimensional rather than creating many narrow instruments. Before adding a metric, ask: is this variation a dimension of an existing one? Success/failure belongs as an `Outcome` dimension — not two instruments. Multiple action types belong as a `Scenario` dimension. A well-designed counter has 3–6 dimensions: `ServiceInstance`, the action, and the outcome.

> For before/after code examples, see [Advanced patterns](references/advanced-patterns.md#standard-17--consolidate-with-dimensions).

---

## Standard 18: Security Events — Required Caller Identity Fields

**Rule:** Any event that records a security-significant action must include all three caller identity fields on **both** success and failure paths. Failure events are frequently more valuable for security investigations — asymmetric definitions are a compliance gap.

| Property on event | Source | How to populate |
|---|---|---|
| `CallerAppId` | Entra ID `appid`/`azp` | `appContext.AuthContext.SubjectClaims.CurrentAppId` |
| `CallerTenantId` | Entra ID `tid` | `appContext.AuthContext.SubjectClaims.TenantId` |
| `CallerObjectId` | Entra ID `oid` | `appContext.AuthContext.SubjectClaims.GetClaim(OAuthClaimTypes.ObjectId)` |

> **`OAuthSecurityEvent` is not a substitute** — it records authentication, not authorization decisions. For events that record token or SAS issuance, also capture permissions granted and target resource. For code examples, see [Advanced patterns](references/advanced-patterns.md#standard-18--security-events).

---

## What NOT to Do

See [Anti-patterns](references/anti-patterns.md) for the full categorized list. The most frequently hit:

- ❌ Omit `partial` from an event class → **LENS0001**, `GetProperties()` not generated
- ❌ Omit `partial` from a logger class → **LENS0003**, no `LogEvent` overloads produced
- ❌ Place `GlobalErrorHandlingMiddleware` before `LoggingAndMetricsMiddleware` → QOS misses the 500
- ❌ Register an override after `AddLensTelemetry` → `TryAdd` means the library's default wins
- ❌ Forget to add new event table names to the Geneva monitoring agent XML

<!-- TODO: source — LENS-Common plugins/LENS/Common/Telemetry/lens-telemetry (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. -->
