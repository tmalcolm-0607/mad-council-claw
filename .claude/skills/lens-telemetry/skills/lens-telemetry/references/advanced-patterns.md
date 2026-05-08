# Advanced Patterns Reference

Supplemental detail for the standards defined in `SKILL.md`. Load this file when you need
deeper context on a specific standard.

---

## Standard 1 — Configuration

**Startup-time resolution.** `MonitoringRole` and `MdsRoleInstance` are resolved once inside
`AddLensTelemetry` and baked into the OTel provider — they are not hot-reloadable and env var
changes after startup have no effect. On local development (no App Service env vars),
`WEBSITE_SITE_NAME` and `WEBSITE_INSTANCE_ID` are not set, so `MonitoringRole` falls back to
`""` and `MdsRoleInstance` to `null`. To avoid blank role names locally, set them explicitly in
`appsettings.Development.json`.

**`MetricsAccount` and `MetricsNamespace` are effectively required.** The library starts without
them but Geneva metrics will not be exported — `InboundRequestQoSMetric` and
`InboundRequestLatencyMetric` will produce no data in dashboards. Omit them only when
intentionally running without metrics (e.g. in tests).

---

## Standard 2 — Service Registration

**`ArgumentNullException` at startup.** If middleware throws at startup or on the first request,
the most likely cause is a missing or incorrectly ordered DI registration.
`InitializeTelemetryContextMiddleware` and the default builders validate all injected
dependencies at construction time and throw immediately if any are null — this is always a DI
misconfiguration, not a runtime data problem. Check that `AddLensTelemetry` was called, that no
custom builders were registered with a null result, and that the middleware is added after
`builder.Build()`.

---

## Standard 3 — Middleware Ordering

**Status code thresholds.** `LoggingAndMetricsMiddleware` defines availability as status ≤ 499
and reliability as status ≤ 399. These values are fixed and cannot be configured.

- **Reliability escape hatch:** set `RequestContextItems.ReliabilityScenario` to a non-empty
  string on the request and the request counts as reliable regardless of status code.
- **Availability:** there is no per-request escape hatch for the availability bar. To exclude a
  request from both bars entirely, mark it synthetic via `ISyntheticRequestDetector` or
  `RequestContextItems.IsSynthetic`.

---

## Standard 4 — Structured Logger

**Testing with `OnEventLogged`.** The generated `LogEvent(T)` overloads all call
`protected virtual void OnEventLogged(IStructuredLogEvent evt)` before writing to the logger.
Override this once in a test double to capture every event without hitting real logging
infrastructure:

```csharp
internal sealed class RecordingStructuredLogger : MyServiceStructuredLogger
{
    public RecordingStructuredLogger() : base(NullLoggerFactory.Instance) { }
    public List<IStructuredLogEvent> RecordedEvents { get; } = new();
    protected override void OnEventLogged(IStructuredLogEvent evt) => RecordedEvents.Add(evt);
}
```

**Inherited events.** `LensStructuredLogger` is itself decorated with `[StructuredEventLogger]`
and the generator emits `LogEvent` overloads for `InboundQOSEvent`, `OutboundQOSEvent`, and
`ExceptionEvent` there. Your service subclass inherits all three — do not redefine them.

**Same-assembly filtering.** The generator only emits `LogEvent` overloads for event types
declared in the **same assembly** as the logger class. Events defined in a referenced library
are not included — they are expected to appear on that library's own logger.

**Prefer structured events over `Logger`.** `LensStructuredLogger` exposes a `Logger` property
(`ILogger`) for unstructured log calls. Avoid it for anything operationally meaningful — an
unstructured line produces a message field that requires text parsing in DGrep, while a
structured event produces queryable columns:

```csharp
// ❌ BAD — "OperationAction" is buried in a message string
_logger.Logger.LogDebug("Operation started for {Caller}", callerName);

// ✅ GOOD — CallerName and OperationAction are queryable Geneva columns
_logger.LogEvent(new SomeOperationEvent { CallerName = callerName, OperationAction = "Started" });
```

Reserve `Logger` for transient diagnostic output (startup noise, local debugging) where a
structured event would be excessive.

---

## Standard 5 — Custom Structured Events

**Property design:** Use typed primitives (`string?`, `long`, `int`, `bool`, `double`) — they serialize cleanly as structured fields. Sanitize PII before assigning. Use constructors when the event should be initialized from a structured input object — avoids partially-populated events at call sites. Avoid full stack traces (use `ExceptionEvent`), raw URLs, JSON blobs, collections, or complex objects — only primitives and strings serialize as queryable Geneva columns.

**Design one event type per scenario.** Each `IStructuredLogEvent` subclass models a specific,
named scenario. `ExceptionEvent` captures exceptions — it is not a general-purpose marker. Use
constructors when callers should provide structured inputs. The class must be `sealed partial` —
`partial` is required for the generator to emit `GetProperties()`:

```csharp
// ✅ GOOD — sealed partial; constructor takes structured inputs; sensitive key sanitized before storage
[StructuredEvent("CacheOperationEvent")]
public sealed partial class CacheOperationEvent : IStructuredLogEvent
{
    public CacheOperationEvent(CacheOperationScenario scenario, string keyId)
    {
        CacheName     = scenario.CacheName;
        OperationName = scenario.SubName;
        Details       = scenario.Details;
        Key           = keyId?.ToLowerInvariant(); // normalize; replace with a service-defined sanitizer if keyId may carry PII
    }

    public string? CacheName { get; }
    public string? OperationName { get; }
    public string? Details { get; }
    public string? Key { get; }
    // GetProperties() generated automatically
}
```

---

## Standard 6 — Logging Events

**TraceId and SpanId are stamped automatically.** Every structured event log record — built-in or custom — is automatically enriched with `TraceId` and `SpanId` by the OpenTelemetry pipeline. No additional code is needed. `AddAspNetCoreInstrumentation()` (registered in `ConfigureTracingProvider`) starts a span for each inbound request; the OTel logger provider captures `Activity.Current` at every `logger.Log()` call and writes those values onto the `LogRecord`. The Geneva exporter serializes them as columns in every DGrep table.

**Correlating events across a request.** The same `TraceId` appears on every structured event emitted during a request — `InboundQOSEvent`, `ExceptionEvent`, `OAuthSecurityEvent`, and any custom events your code emits. Filter on `TraceId` in DGrep to see everything that happened during a single request.

**Correlating `ExceptionEvent` in DGrep.** The `correlationId` in a 500 response from
`GlobalErrorHandlingMiddleware` is the `RequestId` (the W3C trace ID) — use it to find the corresponding
`ExceptionEvent` and all other structured events from that request by filtering on `TraceId`.

---

## Standard 7 — Custom Metrics

**Fast Metering pattern.** The library uses `Microsoft.Extensions.Diagnostics.Metrics` source
generators that produce strongly-typed wrapper classes at compile time, eliminating boxing and
per-call allocation. Each dimension is a typed parameter — incorrect call signatures are a
compile error.

**Cardinality.** Each unique combination of dimension values creates a separate time series in
Geneva. The total series count is the product of all dimension cardinalities.

| Verdict | Examples |
|---|---|
| ✅ Good — low cardinality | `"Success"`/`"Failure"`, `nameof(MyProcessor)`, HTTP status codes, `ServiceInstance` |
| ⚠ Context-dependent | `TenantId` — acceptable in LENS (bounded enterprise tenant population), high-cardinality in consumer services |
| ❌ Never — unbounded | `DocumentId`, `RequestId`, `CorrelationId`, `ErrorMessage`, `UserId` |

High-cardinality data belongs in structured events (append-only rows, no cardinality constraint),
not metrics (time-series aggregates).

**Meter naming.** Use `"MyService.Domain"` format (e.g. `"MyService.Documents"`). The source
generator derives the instrument type name from the factory method name:
`CreateDocumentsProcessedMetric` → `DocumentsProcessedMetric`.

**Dimension name case-sensitivity.** Dimension names are case-sensitive in Jarvis. Define a
shared constants class so every metric that records a `ProcessorName` uses exactly the same
string — a casing inconsistency across metrics breaks cross-metric Jarvis queries silently.

---

## Standard 8 — Recording Metrics

**Singleton services** — create instruments once in the constructor via `IMeterFactory` directly:

```csharp
public class DocumentProcessor
{
    private readonly DocumentsProcessedMetric _counter;
    private readonly DocumentProcessingLatencyMetric _latency;
    private readonly string _serviceInstance;

    public DocumentProcessor(IMeterFactory meterFactory, IOptions<GenevaTelemetryOptions> genevaOptions)
    {
        _serviceInstance = genevaOptions.Value.MdsRoleInstance
            ?? Environment.GetEnvironmentVariable("WEBSITE_INSTANCE_ID")
            ?? "local";
        var meter = meterFactory.Create("MyService.Documents");
        _counter = MyServiceMetrics.CreateDocumentsProcessedMetric(meter);
        _latency = MyServiceMetrics.CreateDocumentProcessingLatencyMetric(meter);
    }

    public async Task ProcessAsync(string tenantId)
    {
        var sw = Stopwatch.StartNew();
        // ... process ...
        sw.Stop();
        _counter.Add(1, _serviceInstance, tenantId, nameof(DocumentProcessor), "Success");
        _latency.Record(sw.ElapsedMilliseconds, _serviceInstance, nameof(DocumentProcessor), "Success");
    }
}
```

**Scoped services and controllers** — inject `ITelemetryContext<TLogger>` (typed, for service-specific `LogEvent(T)` overloads) or the non-generic `ITelemetryContext` (when only `IMeterFactory`/`ILogger` is needed). Create metric instruments in the constructor:

```csharp
// ✅ GOOD — typed injection: LogEvent(T) overloads available without casting
public class DocumentController : ControllerBase
{
    private readonly ITelemetryContext<MyServiceStructuredLogger> _telemetryContext;
    private readonly ILensAppContext _appContext;
    private readonly DocumentsProcessedMetric _counter;

    public DocumentController(
        ITelemetryContext<MyServiceStructuredLogger> telemetryContext,
        ILensAppContext appContext)
    {
        _telemetryContext = telemetryContext;
        _appContext = appContext;
        var meter = telemetryContext.MeterFactory.Create("MyService.Documents");
        _counter = MyServiceMetrics.CreateDocumentsProcessedMetric(meter);
    }

    [HttpPost]
    public async Task<IActionResult> Process(string tenantId)
    {
        _counter.Add(1, _appContext.RequestContext.ServiceInstance, tenantId, nameof(DocumentController), "Success");
        _telemetryContext.StructuredLogger.LogEvent(new DocumentProcessedEvent { TenantId = tenantId });
        return Ok();
    }
}
```

---

## Standard 9 — Synthetic Detection

**Case-sensitivity.** `AlwaysOn`, `AppInsights`, and `jndi:ldap` are matched
case-insensitively. `URSA` (in `MSFT URSA-WebScanning`) uses `StringComparison.Ordinal` — it
must be uppercase.

**Replacing vs supplementing.** Override `IsSyntheticRequest` on a `DefaultRequestContextBuilder`
subclass to replace the built-in `User-Agent` checks entirely. Register an
`ISyntheticRequestDetector` to supplement them. The two mechanisms are independent and coexist.

---

## Standard 10 — Per-Request Context Items

**Sentinel values in Geneva.** When `ILensAppContext` is not yet populated (e.g. in
background workers or early in the pipeline), `ServiceInstance` resolves to `"Undefined"` and
outbound QOS properties default to `"None"`. If you see these in dashboards, the request context
was unavailable at the time the metric was recorded — check middleware ordering.

**Custom context items.** Services can define their own `RequestContextItemAccessor<T>` instances
following the same pattern as `RequestContextItems`. The optional `valueFactory` parameter
(`Func<T, T>`) normalizes values before storage:

```csharp
// ✅ GOOD — custom accessor with normalization
public static class MyRequestContextItems
{
    public static readonly RequestContextItemAccessor<string?> TenantId =
        new RequestContextItemAccessor<string?>("TenantId", null, v => v?.ToLowerInvariant());
}

// In a controller:
MyRequestContextItems.TenantId.SetItem(appContext.RequestContext, tenantId);
```

No registration step is needed; the accessor reads and writes directly to `IRequestContext.Items`.

---

## Standard 14 — MISE V2 Authentication

**MISE V2 projection boundary.** MISE V2 introduced a projection step after token validation: the
MISE host stores the complete `AuthenticationTicket` in
`HttpContext.Items["Microsoft.Identity.ServiceEssentials.MiseResult"]`, then a normalization step
projects a *reduced* `ClaimsPrincipal` into `HttpContext.User`, stripping most Entra ID claims.
`DefaultAuthContextBuilder` reads from `HttpContext.User` and produces an `AuthContext` where
`TenantId`, `ObjectId`, `IdentityType`, `CurrentAppId`, and most other fields are `"Undefined"`
on MISE V2 services. This is never correct behavior in production.

**`MiseAuthContextBuilder` implementation.** `MiseAuthContextBuilder` subclasses
`BaseAuthContextBuilder` and overrides two protected methods:

- `GetClaimsIdentity()` — returns `authResult.AuthenticationTicket?.SubjectIdentity` (the
  complete pre-projection identity from the MISE result)
- `GetTokenProtocol()` — returns
  `miseContext.GetMiseAuthenticationResult().Result?.AggregateTokenType`

All claim extraction (`tid`, `oid`, `idtyp`, `scp`, `roles`, etc.), sanitization, and `AuthContext`
construction is inherited from `BaseAuthContextBuilder` — no claim logic lives in
`MiseAuthContextBuilder` itself.

**CDT identity source.** For Constrained Delegation Tokens (CDT), `SubjectIdentity` on the
`AuthenticationTicket` comes from the **app/actor token** (not the constraint token). The
constraint token carries only `xms_ds_nonce`, `constraints`, and `tid`. As a result,
`IAuthContext.TenantId` on a CDT request reflects the actor app's tenant.

**`AggregateTokenType` is MISE V2 only.** `GetMiseAuthenticationResult()` and `AggregateTokenType`
are MISE V2 APIs. On a MISE V1 service, `GetTokenProtocol()` returns `null`, and `TokenProtocol`
surfaces as `"Undefined"` in `OAuthSecurityEvent`. `MiseAuthContextBuilder` handles this
gracefully — no special configuration is needed.

**`AddMiseAuthContextBuilder()` internals.** The extension method calls
`services.RemoveAll<IAuthContextBuilder>()` before `AddSingleton<IAuthContextBuilder, MiseAuthContextBuilder>()`.
This is what makes it order-independent relative to `AddLensTelemetry` (which uses `TryAdd`). It
is also idempotent — calling it twice replaces the previous registration cleanly.

**`TokenProtocol` values.** `MiseAuthContextBuilder` populates `IAuthContext.TokenProtocol` with
the MISE `AggregateTokenType` string. This field is `null` on non-MISE services and appears as
`"Undefined"` in `OAuthSecurityEvent` when null.

| `TokenProtocol` | Meaning |
|---|---|
| `User` | Standard bearer user-delegated token |
| `AppOnly` | Standard bearer app-only token |
| `Pft` | Protected Forwarded Token wrapping a user token |
| `Cdt` | Constrained Delegation Token |
| `AppOnly;Pft` | PFT wrapping an app-only token (PFAT) |

`TokenProtocol` is distinct from the `IdentityType` (`idtyp`) claim: a PFT-wrapped user token
and a plain bearer user token both have `idtyp = "user"` but different `TokenProtocol` values.

---

## Standard 15 — Migration from `Register<TEvent>()`

**Logger class changes:**

```csharp
// Before
public sealed class MyServiceStructuredLogger : LensStructuredLogger
{
    public MyServiceStructuredLogger(ILoggerFactory factory) : base(factory)
    {
        Register<DocumentProcessedEvent>();
        Register<QuotaExceededEvent>();
    }
}

// After
[StructuredEventLogger]
public sealed partial class MyServiceStructuredLogger : LensStructuredLogger
{
    public MyServiceStructuredLogger(ILoggerFactory factory) : base(factory) { }
}
```

**Event class changes:**

```csharp
// Before
public sealed class DocumentProcessedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public IReadOnlyList<KeyValuePair<string, object?>> GetProperties() =>
        [new("DocumentId", DocumentId)];
}

// After — generator emits GetProperties()
public sealed partial class DocumentProcessedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
}
```

After rebuild the generator emits `LogEvent(DocumentProcessedEvent)`, `LogEvent(QuotaExceededEvent)`,
and a `RegisterServiceEvents()` override that populates `CategoryTableMappings`. Call sites do not
change — `_logger.LogEvent(new DocumentProcessedEvent { ... })` resolves to the generated overload.

---

## Standard 11 — Cosmos DB Activity Processor

**What `CosmosDbActivityProcessor` emits per call:**

| Signal | Always? | Notes |
|---|---|---|
| `CosmosDbRequestChargeMetric` histogram | Yes | Dimensions include `SubStatusCode`, `ContactedRegions`, `CorrelatedActivityId` |
| `CosmosDbDiagnosticsEvent` structured log | Filtered | Gated by `CosmosDbDiagnosticsOptions` |
| `OutboundQOSEvent` structured log | Yes | `Method = "Undefined"` — Direct mode has no HTTP verb |
| `OutboundRequestQOSMetric` / `OutboundRequestLatencyMetric` | Yes | `Scenario = "CosmosDB"`, `TargetUri = server.address` |

**Service-constants pattern for Standard 7:**

```csharp
// Define a constants class for service-specific dimension names
public static class MyServiceMetricConstants
{
    public const string ProcessorNameDimension = "ProcessorName";
    public const string OutcomeDimension       = "Outcome";
}

// Reference both TelemetryConstants and your own constants
public static partial class MyServiceMetrics
{
    [Counter(
        TelemetryConstants.ServiceInstanceDimension,
        TelemetryConstants.TenantIdDimension,
        MyServiceMetricConstants.ProcessorNameDimension,
        MyServiceMetricConstants.OutcomeDimension)]
    public static partial DocumentsProcessedMetric CreateDocumentsProcessedMetric(Meter meter);

    [Histogram(
        TelemetryConstants.ServiceInstanceDimension,
        MyServiceMetricConstants.ProcessorNameDimension,
        MyServiceMetricConstants.OutcomeDimension)]
    public static partial DocumentProcessingLatencyMetric CreateDocumentProcessingLatencyMetric(Meter meter);
}
```

---

## Standard 12 — Blob Client Activity Processor

**What `BlobClientActivityProcessor` emits per call:**

| Signal | Always? | Notes |
|---|---|---|
| `BlobClientDiagnosticsEvent` structured log | Filtered | Gated by `BlobClientDiagnosticsOptions` |
| `OutboundQOSEvent` structured log | Yes | `Method = "Undefined"`, `TargetUri = server.address` |
| `OutboundRequestQOSMetric` / `OutboundRequestLatencyMetric` | Yes | `Scenario = "BlobStorage"`, `SubScenario = OperationName`, `TargetUri = server.address` |

**Activity hierarchy:** The Azure SDK emits two activities per call — a parent operation-level activity (e.g., `BlobClient.Download`) and a child HTTP-level activity. `BlobClientActivityProcessor` filters on the HTTP activity (`Source.Name == "Azure.Core.Http"`) and reads operation metadata from the parent.

**Blob name truncation:** The processor extracts the container name and blob name from the request URL. The blob name is truncated to the first 3 path segments after the container to prevent logging sensitive information. This follows the LENS storage pattern of `LensTaskId/type/DpsJobId`. Deeper path segments (partition, shard, filename) are excluded from telemetry.

**Example URL processing:**
- `/lns1/12345/evidence/job-abc-123/partition001/shard5/data.json`
  - Container: `lns1`
  - Blob: `12345/evidence/job-abc-123` (truncated to 3 segments)

**Azure attribute fallback:** The processor reads both new `azure.client.request.id` / `azure.service.request.id` attributes (current OpenTelemetry semantic conventions in development) and deprecated `az.client_request_id` / `az.service_request_id` for backward compatibility with older Azure SDK versions. The new `azure.*` attributes take precedence when both are present.

---

## Standard 13 — Custom Histogram Views

```csharp
// ✅ GOOD — custom latency histogram with explicit buckets
builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
    builder.Configuration.GetSection("GenevaTelemetry"),
    configureViews: b => b.AddView(
        instrumentName: "DocumentProcessingLatencyMetric",
        new ExplicitBucketHistogramConfiguration
        {
            Boundaries = new double[] { 0, 25, 50, 100, 250, 500, 1000, 2500, 5000 },
        }));
```

```csharp
// ❌ BAD — no explicit buckets; P95/P99 will be quantized to OTel's default coarse boundaries
[Histogram(TelemetryConstants.ServiceInstanceDimension, "Outcome")]
public static partial DocumentProcessingLatencyMetric CreateDocumentProcessingLatencyMetric(Meter meter);
// registered without a matching AddView → inaccurate percentiles in dashboards
```

The `configureViews` callback receives a `LensMeterViewBuilder` — only `AddView` operations are exposed; callers cannot alter meters, exporters, or other provider settings.

---

## Standard 16 — No Catch-All Fields

```csharp
// ❌ BAD — ProcessorName, PageCount, and TenantId are buried in Detail;
//          querying any individual value requires a full text scan in DGrep
[StructuredEvent("DocumentProcessedEvent")]
public sealed partial class DocumentProcessedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public string? Detail { get; set; }  // "Processor=PdfProcessor, Pages=12, Tenant=contoso"
}

// ✅ GOOD — each value is a queryable DGrep column
[StructuredEvent("DocumentProcessedEvent")]
public sealed partial class DocumentProcessedEvent : IStructuredLogEvent
{
    public string? DocumentId { get; set; }
    public string? ProcessorName { get; set; }
    public int PageCount { get; set; }
    public string? TenantId { get; set; }
}
```

For the full list of supported property types, see [structured-logging.md](../../../docs/structured-logging.md#defining-custom-events).

---

## Standard 17 — Consolidate with Dimensions

**Success/failure as separate instruments** — a single `Outcome` dimension covers both paths and keeps Jarvis queries unified:

```csharp
// ❌ BAD — two instruments; computing success rate requires dividing two separate metric series
public static partial class DocumentMetrics
{
    [Counter(TelemetryConstants.ServiceInstanceDimension)]
    public static partial DocumentProcessedMetric CreateDocumentProcessedMetric(Meter meter);

    [Counter(TelemetryConstants.ServiceInstanceDimension)]
    public static partial DocumentFailedMetric CreateDocumentFailedMetric(Meter meter);
}

// ✅ GOOD — one instrument; filter by Outcome in a single Jarvis query
public static partial class DocumentMetrics
{
    [Counter(TelemetryConstants.ServiceInstanceDimension, MyServiceMetricConstants.OutcomeDimension)]
    public static partial DocumentOperationMetric CreateDocumentOperationMetric(Meter meter);
}
```

**One instrument per action type** — use `Scenario` + `Success` dimensions instead:

```csharp
// ❌ BAD — three instruments for what are really three values of the same dimension
[Counter(TelemetryConstants.ServiceInstanceDimension)]
public static partial BatchDocumentsMetric CreateBatchDocumentsMetric(Meter meter);
[Counter(TelemetryConstants.ServiceInstanceDimension)]
public static partial BatchFlushMetric CreateBatchFlushMetric(Meter meter);
[Counter(TelemetryConstants.ServiceInstanceDimension)]
public static partial BatchErrorMetric CreateBatchErrorMetric(Meter meter);

// ✅ GOOD — one instrument; group by Scenario in Jarvis to compare actions on one chart
[Counter(TelemetryConstants.ServiceInstanceDimension,
         MyServiceMetricConstants.ScenarioDimension,
         MyServiceMetricConstants.SuccessDimension)]
public static partial BatchOperationMetric CreateBatchOperationMetric(Meter meter);
```

For cardinality constraints see [custom-metrics.md](../../../docs/custom-metrics.md#dimension-design).

---

## Standard 18 — Security Events

```csharp
// ❌ BAD — failure event has only CallerAppId; tenant and principal unknown from failure logs alone
[StructuredEvent("ResourceAccessEvent")]
public sealed partial class ResourceAccessEvent : IStructuredLogEvent
{
    public string? ResourceId { get; set; }
    public string? Action { get; set; }
    public string? FailureReason { get; set; }
    public string? CallerAppId { get; set; }
}

// ✅ GOOD — full identity on both paths; success and failure events are symmetric
[StructuredEvent("ResourceAccessEvent")]
public sealed partial class ResourceAccessEvent : IStructuredLogEvent
{
    public string? ResourceId { get; set; }
    public string? Action { get; set; }
    public string? FailureReason { get; set; }
    public string? CallerAppId { get; set; }
    public string? CallerTenantId { get; set; }
    public string? CallerObjectId { get; set; }
}

// Populate from ILensAppContext (available in any scoped service):
var claims = appContext.AuthContext.SubjectClaims;
_logger.LogEvent(new ResourceAccessEvent
{
    ResourceId     = resourceId,
    Action         = action,
    FailureReason  = reason,
    CallerAppId    = claims.CurrentAppId,
    CallerTenantId = claims.TenantId,
    CallerObjectId = claims.GetClaim(OAuthClaimTypes.ObjectId),
});
```

For events that record token or SAS issuance, also capture the **permissions granted** and **target resource** — these are the fields most needed when investigating whether a caller received more access than intended.
