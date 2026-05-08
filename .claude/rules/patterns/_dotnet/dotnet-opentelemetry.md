---
paths:
  - "**/*.cs"
  - "**/Program.cs"
---

# OpenTelemetry Tracing

> **Canonical: this file documents LENS-canonical patterns from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

.NET services use OpenTelemetry for distributed tracing.

## Rule

| Check | Status |
|-------|--------|
| OpenTelemetry configured in startup | REJECT if missing |
| Service has named ActivitySource | WARN if generic |
| OTLP exporter configured | WARN if console-only |

## Correct — LENS Services Use `AddLensTelemetry<TLogger>()`

LENS services do NOT call `services.AddOpenTelemetry().WithTracing()` directly — the LENS-Common library provides a single-call wiring that registers OTel logger/meter/tracing providers, the four telemetry middleware components, and Geneva exporters with the correct ordering already baked in.

Cite: `lens-telemetry` SKILL.md v1.3.0 Standards 2 (lines 96-129), 11 (401-427), 12 (430-457).

```csharp
// CORRECT - LENS canonical startup
// 1) Register interface OVERRIDES first (TryAdd in AddLensTelemetry means library defaults
//    win if registered after). Applies to: IRequestContextBuilder, IAuthContextBuilder,
//    ITelemetryContext, ILensAppContext, ISyntheticRequestDetector.
builder.Services.AddSingleton<ISyntheticRequestDetector, HeartbeatDetector>();

// 2) For MISE V2 services, register MiseAuthContextBuilder (REPLACE-semantics; idempotent;
//    order independent relative to AddLensTelemetry). See dotnet-auth.md.
builder.Services.AddMiseAuthContextBuilder();

// 3) The one call that wires everything: OTel providers, Geneva exporters, structured-logger
//    source-gen mappings, middleware DI.
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"),
    enableConsoleLogging: builder.Environment.IsDevelopment(),
    configureViews: b => b.AddView(   // optional - explicit buckets for custom histograms
        instrumentName: "MyLatencyMetric",
        new ExplicitBucketHistogramConfiguration { Boundaries = new double[] { 0, 50, 100, 250, 500 } }));

// 4) For services that talk to Cosmos: ALSO register Cosmos telemetry (Standard 11)
builder.Services.AddCosmosDbTelemetry(); // no-op if Cosmos isn't used

// 5) For services that talk to Azure Blob: register Blob telemetry (Standard 12)
builder.Services.AddBlobClientTelemetry(); // no-op if Blob isn't used
```

### Cosmos client setup (Standard 11)

`AddCosmosDbTelemetry()` registers a `CosmosDbActivityProcessor` that hooks the SDK's built-in OTel instrumentation. **Distributed tracing must be opted in on the `CosmosClient`** — without it the processor receives no spans and emits nothing (anti-patterns.md:52):

```csharp
// CORRECT - DisableDistributedTracing = false MUST be set
var cosmosClient = new CosmosClient(connectionString, new CosmosClientOptions
{
    CosmosClientTelemetryOptions = new CosmosClientTelemetryOptions
    {
        DisableDistributedTracing = false,
    },
});
```

This works for **both Direct mode (RNTBD/TCP) and Gateway mode (HTTPS)**. See `_dotnet/dotnet-cosmos-core.md` for the full `CosmosClient` registration site.

> **1.4.0 migration note (N18):** the handler-based variant `IHttpClientBuilder.AddCosmosDbTelemetry()` was REMOVED in 1.4.0 — it only intercepted Gateway mode and is gone. Use `services.AddCosmosDbTelemetry()` on `IServiceCollection` instead. SKILL.md Standard 11:426; anti-patterns.md:51.

## LENS Outbound Telemetry — Cosmos and Blob

LENS-Common ships two opt-in extension methods that hook into the Azure SDKs' built-in OpenTelemetry instrumentation. Call them on `IServiceCollection` after `AddLensTelemetry` — both are no-ops if the corresponding SDK isn't used by the service.

Cite: `lens-telemetry` SKILL.md v1.3.0 Standards 11 (lines 401-427), 12 (430-457), 18 (514-525).

| Extension | What it registers | Required client config |
|-----------|------------------|-----------------------|
| `services.AddCosmosDbTelemetry()` | `CosmosDbActivityProcessor` (subscribes to `Azure.Cosmos.Operation`); RU charge metric; QOS event + metrics; `CosmosDbDiagnosticsEvent` | `CosmosClientOptions.CosmosClientTelemetryOptions.DisableDistributedTracing = false` (REQUIRED — default `true` produces zero spans) |
| `services.AddBlobClientTelemetry()` | `BlobClientActivityProcessor` (subscribes to `Azure.Storage.Blobs.*`); QOS event + metrics; `BlobClientDiagnosticsEvent` | None — distributed tracing is enabled by default in the Azure.Storage.Blobs SDK |

### 1.4.0 migration

The handler-based variant `IHttpClientBuilder.AddCosmosDbTelemetry()` was REMOVED in 1.4.0 of `Microsoft.LENS.Common.Telemetry`. It only intercepted Gateway-mode (HTTPS) requests and is gone. Migrate to `services.AddCosmosDbTelemetry()` on `IServiceCollection` — the `CosmosDbActivityProcessor` covers BOTH Direct mode (RNTBD/TCP) and Gateway mode (HTTPS).

### Filter knobs

Both processors emit a diagnostics event by default only on errors (`ErrorsOnly = true`). To also log slow or expensive successful calls, set per-processor options under `GenevaTelemetry`:

| Section | Property | Purpose |
|---------|----------|---------|
| `GenevaTelemetry:CosmosDbDiagnostics` | `MinLatencyMs`, `MinRequestChargeRu`, `ErrorsOnly`, `AlwaysLogExceptions` | OR-combined; hot-reloadable |
| `GenevaTelemetry:BlobClientDiagnostics` | `MinLatencyMs`, `ErrorsOnly`, `AlwaysLogExceptions`, `MinSuccessStatusCode`, `MaxSuccessStatusCode` | OR-combined; hot-reloadable |

QOS metrics + RU charge metric are unconditional — only the *event* log entries are filtered.

### Anti-pattern: handler-based wiring or missing client opt-in

```csharp
// WRONG — IHttpClientBuilder.AddCosmosDbTelemetry() removed in 1.4.0
builder.Services.AddHttpClient("cosmos").AddCosmosDbTelemetry();

// WRONG — services.AddCosmosDbTelemetry() registered but DisableDistributedTracing left at default true
var cosmosClient = new CosmosClient(connectionString);  // processor receives nothing
```

Use the canonical pair from the AddLensTelemetry example above.

### Blob path truncation note

Blob URIs in QOS events are normalized to keep at most 3 path segments after the container name; deeper segments are excluded from the event. Plan dimension cardinality and DGrep filters with that truncation in mind. See `logging-security.md` for the data-handling rationale.

## Custom histogram views

Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 13 (lines 460-465).

When a service defines a custom `[Histogram]` instrument, register an `ExplicitBucketHistogramConfiguration` view via the `configureViews` callback on `AddLensTelemetry`. Without explicit buckets, OTel's default coarse boundaries produce inaccurate P95/P99 percentiles in Jarvis dashboards.

```csharp
// CORRECT - per-instrument explicit buckets
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"),
    configureViews: b => b
        .AddView(
            instrumentName: "MyServiceLatencyMetric",
            new ExplicitBucketHistogramConfiguration
            {
                Boundaries = new double[] { 0, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 },
            })
        .AddView(
            instrumentName: "MyServiceWriteSizeMetric",
            new ExplicitBucketHistogramConfiguration
            {
                Boundaries = new double[] { 0, 1024, 4096, 16384, 65536, 262144 },
            }));
```

The built-in `InboundRequestLatencyMetric`, `OutboundRequestLatencyMetric`, and `CosmosDbRequestChargeMetric` already have explicit views registered by the library — no work needed for those. Choose buckets that match the percentile precision the alerts care about; doubling-step (10/25/50/100/250…) is a reasonable default.

### Anti-pattern: omit the view

```csharp
// WRONG - custom histogram registered but no view; default OTel coarse boundaries (0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000)
[Histogram(TelemetryConstants.ServiceInstanceDimension, "Operation")]
public static partial MyServiceLatencyMetric CreateMyServiceLatencyMetric(Meter meter);
// → P95/P99 percentiles align to coarse boundaries; alerts wobble across redeploys
```

## Synthetic traffic — `ISyntheticRequestDetector`

Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 9 (lines 351-374); anti-patterns.md:57.

To mark inbound traffic as synthetic (health checks, load test traffic, internal tooling) WITHOUT subclassing, register an `ISyntheticRequestDetector`. The detector receives the full inbound `HttpContext` and can inspect any aspect of the request.

```csharp
// CORRECT - DI-registered detector; no controller code involvement
public sealed class HeartbeatDetector : ISyntheticRequestDetector
{
    public bool IsSynthetic(HttpContext httpContext)
        => httpContext.GetRouteValue("action") is "Heartbeat" or "HealthCheck";
}

// In Program.cs, BEFORE AddLensTelemetry (TryAdd semantics)
builder.Services.AddSingleton<ISyntheticRequestDetector, HeartbeatDetector>();
```

Built-in detection covers `AlwaysOn`, `AppInsights`, `MSFT URSA-WebScanning`, and `jndi:ldap` via `KnownSyntheticUserAgents` — no detector code is needed for those. Any number of detectors can be registered; if any one returns `true`, the request is marked synthetic. All registered detectors run **in addition to** the built-in `User-Agent` checks.

Synthetic-marked requests have `MetAvailabilityBar` and `MetReliabilityBar` forced to `"True"` and `IsSynthetic = "True"` emitted as a metric dimension, enabling `IsSynthetic = "False"` Jarvis filters that show real-traffic-only views.

### Anti-pattern (N10): set `IsSynthetic` from controller code

```csharp
// AVOID - works at runtime but scatters detection logic
//          - hard to find all synthetic conditions
//          - untestable as a unit
//          - some code paths get missed (escape-hatch ONLY)
RequestContextItems.IsSynthetic.SetItem(appContext.RequestContext, true);
```

The `RequestContextItems.IsSynthetic` accessor is an escape hatch for narrow scenarios where the detector cannot be expressed against `HttpContext` alone (e.g. business-rule-gated synthetic routing). For the common case — health checks, load tests, scanners — implement an `ISyntheticRequestDetector` and register it. Centralized, testable, covers all code paths.

## Non-LENS / Standalone — Raw OpenTelemetry Setup

For services that do NOT take a dependency on `Microsoft.LENS.Common.Telemetry` (e.g. samples, non-LENS standalone services), the raw OTel registration is acceptable:

```csharp
// Non-LENS startup only - LENS services use AddLensTelemetry<TLogger>() above
services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSource("MyApp.ServiceName")
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter());

public class CaseService
{
    private static readonly ActivitySource ActivitySource = new("MyApp.ServiceName");

    public async Task<Case> GetCaseAsync(string caseId, CancellationToken ct)
    {
        using var activity = ActivitySource.StartActivity("GetCase");
        activity?.SetTag("caseId", caseId);
        // ...
    }
}
```

## Wrong

```csharp
// LENS service calls raw .AddOpenTelemetry().WithTracing(...) instead of AddLensTelemetry<TLogger>()
//   - bypasses Geneva exporter wiring, structured-logger source-gen registration,
//     middleware DI, and InboundQOS/OutboundQOS metric registration
// Cosmos client created with DisableDistributedTracing = true (the default)
//   - CosmosDbActivityProcessor receives nothing
// No tracing configured at all / no activity source defined / manual logging instead of spans
```

## Standard Sources

| Source Name | Description |
|-------------|-------------|
| `Microsoft.LENS.Common.Telemetry` | LENS middleware spans (registered automatically by `AddLensTelemetry`) |
| `MyApp.ServiceName` | Application-defined service operations |
| `Azure.Cosmos.Operation` | Cosmos DB SDK (subscribed by `CosmosDbActivityProcessor`) |
| `Azure.Storage.Blobs.*` | Azure Blob Storage SDK (subscribed by `BlobClientActivityProcessor`) |
| `System.Net.Http` | HTTP client calls |

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| No tracing | Add OpenTelemetry |
| Generic source names | Use `MyApp.ServiceName` |
| Console exporter in prod | Use OTLP exporter |

---

## Handler Activity Spans — Optional, for High-Visibility Operations

Per-handler activity spans are **optional, additive detail** for tracing — not a MUST. The LENS-Common `LoggingAndMetricsMiddleware` (registered by `AddLensTelemetry<TLogger>()`) already creates a request-scope activity per inbound request and `AddAspNetCoreInstrumentation()` produces the inbound-request span automatically. Adding a per-handler span is appropriate when:

- The handler does substantial work that benefits from a sub-span in DGrep traces (e.g. a multi-step orchestration).
- You want entity-ID tags surfaced as span attributes (not just on the structured event).
- Cross-service distributed-trace stitching needs an explicit hop tagged at this layer.

For routine handler methods that delegate to a single service call, the request-scope activity from middleware + a structured event is usually sufficient.

```csharp
// OPTIONAL - high-visibility operation; adds a sub-span and entity tags
using var activity = ServiceActivitySource.Instance.StartActivity("EntityType.OperationName");
activity?.SetTag("cms.caseId", caseId);
try
{
    // ... handler logic
}
catch (Exception ex)
{
    activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
    throw;
}
```

If you DO add per-handler spans, do it consistently within a class — half-instrumented classes produce confusing trace topologies.

Note: do NOT call `activity?.SetTag()` to record per-request data that belongs in a structured event (anti-patterns.md:66). `TraceId`/`SpanId` are auto-correlated to events; entity IDs that need DGrep filtering should be event properties, not span tags.

---

## Best-Effort Operation Metrics

Every best-effort/fail-open pattern MUST include a counter metric alongside the log call. For LENS services, define the counter via the canonical `[Counter]` source-generated pattern (cite: `lens-telemetry` SKILL.md Standard 7, lines 283-313):

```csharp
// 1. Declare the counter via source-gen partial (one per service, in Telemetry/Metrics/)
public static partial class MyServiceMetrics
{
    [Counter(TelemetryConstants.ServiceInstanceDimension, "Operation", "EntityType", "Outcome")]
    public static partial OperationFailureCount CreateOperationFailureCount(Meter meter);
}

// 2. Inject and emit at the catch site — typed Add() generated; positional dimension args
catch (Exception ex)
{
    this.operationFailureCount.Add(1, "upsert", "lookup", "Failure");
    this.logger.LogEvent(new OperationFailedEvent { EntityId = entityId });
}
```

Constraints:
- Do NOT specify `Name=` on `[Counter]`; the generator derives the instrument name from the partial method (anti-patterns.md:42).
- Do NOT prefix instrument names with the service / account namespace; that prefix is applied automatically (anti-patterns.md:43).
- Outcome dimension uses `"Failure"` / `"Success"` (PascalCase) so dashboards segment cleanly.

Operators need dashboards, not just log queries. Silent drift between primary and secondary stores is invisible without counters.

Anti-pattern: Best-effort writes log warnings on failure but provide no metric counter. Cosmos throttling causes silent data drift.
