# Anti-Patterns — What NOT to Do

Common mistakes when using `Microsoft.LENS.Common.Telemetry`. Each item here corresponds to
a correctness or data-quality failure — not just a style preference.

---

## Registration

- ❌ Register `AddLensTelemetry` before your `IRequestContextBuilder`, `IAuthContextBuilder`, `ITelemetryContext`, `ILensAppContext`, or `ISyntheticRequestDetector` overrides — `TryAdd` means the library wins for all five
- ❌ Call `.AddMeter(...)` or `.WithTracing(...)` manually in `Program.cs` — `AddLensTelemetry` registers `.AddMeter("*")` and configures the tracing provider; manual calls are redundant and can conflict
- ❌ Create wrapper classes that delegate to fast-metered instruments — the generated types are strongly typed and injected directly via `IMeterFactory`; a wrapper adds indirection with no benefit

## Middleware Ordering

- ❌ Place `GlobalErrorHandlingMiddleware` before `LoggingAndMetricsMiddleware` — QOS will not see the 500 response; a thrown exception produces no QOS metric
- ❌ Place `InitializeTelemetryContextMiddleware` after other telemetry middleware — `ITelemetryContext` and `ILensAppContext` won't be populated
- ❌ Place `PostAuthTelemetryMiddleware` before `UseAuthentication()` — claims are not yet available; `IAuthContextBuilder` will see an unauthenticated principal
- ❌ Implement a service-local `LoggingAndMetricsMiddleware` or `GlobalErrorHandlingMiddleware` — the library provides both; a duplicate will double-record QOS metrics and produce inconsistent error response shapes

## Structured Events

- ❌ Omit `partial` from an event class — the generator emits **LENS0001** and `GetProperties()` is not generated; the class fails to compile as `IStructuredLogEvent` is not fully implemented
- ❌ Omit `partial` from a logger class — the generator emits **LENS0003** and no `LogEvent` overloads are produced
- ❌ Implement `GetProperties()` manually — the generator owns that method; a manual implementation produces a duplicate-member compile error. If CS0535 appears in Visual Studio after generator changes, rebuild the solution — VS design-time builds can show stale diagnostics that a real build clears
- ❌ Use a non-`sealed` event class — inheritance can silently add properties that appear in `GetProperties()` unexpectedly
- ❌ Use `Register<TEvent>()` in new code — it is `[Obsolete]`; apply `[StructuredEventLogger]` instead (see Standard 14)
- ❌ Inject `LensStructuredLogger` instead of your concrete subclass — you lose your service-specific `LogEvent` overloads
- ❌ Bundle multiple structured values into a single free-text field (e.g. `Detail = $"Processor={name}|Pages={count}"`) — each value you need to filter on in DGrep must be its own property; text fields can only be queried by full scan (see Standard 15)
- ❌ Add entry/exit log events in controllers or handlers for data `LoggingAndMetricsMiddleware` already captures automatically (route, method, status code, latency, caller ID, exception type) — this generates high-volume noise with no diagnostic benefit; see [inbound-qos.md](../../../docs/inbound-qos.md) for the complete list of auto-captured fields
- ❌ Emit a context event before `ExceptionEvent` just to repeat `CallerMemberName` or tenant data — `ExceptionEvent` already captures the call site; `TraceId` correlates to `InboundQOSEvent` for caller/tenant; only add a context event when entity-specific data (document ID, partition key, etc.) won't be captured elsewhere (see Standard 6)
- ❌ Add a `CorrelationId`, `TraceId`, or `SpanId` property to a custom structured event — these are auto-enriched on every event by the OTel pipeline at no cost; explicit properties are redundant and will produce duplicate columns in DGrep
- ❌ Forget to register new event table names in the Geneva monitoring agent XML configuration
- ❌ Define security events (token issuance, permission decisions, auth failures) without all three caller identity fields (`CallerAppId`, `CallerTenantId`, `CallerObjectId`) on both success and failure paths — asymmetric events create investigation blind spots (see Standard 17)

## Metrics

- ❌ Create metric instruments inside singleton method bodies — create them once in the constructor
- ❌ Add a custom `[Histogram]` without registering an `ExplicitBucketHistogramConfiguration` view — OTel's default buckets produce inaccurate P95/P99 percentiles (see Standard 12)
- ❌ Create separate metric instruments for success and failure paths — success/failure is a dimension (`Outcome` or `bool Success`) on a single instrument (see Standard 16)
- ❌ Create one metric instrument per action type — action type is a `Scenario` dimension on a single instrument (see Standard 16)
- ❌ Specify `Name=` on a `[Counter]` or `[Histogram]` attribute — Fast Metering derives the instrument name from the factory method name (`CreateSasOperationMetric` → `SasOperationMetric`); an explicit `Name=` overrides this WYSIWYG contract
- ❌ Prefix metric instrument names with the service or Geneva account namespace (e.g. `lens.cms.sas.operation`) — the metrics account already scopes all instruments; use the operation name only (e.g. `SasOperationMetric`)

## Scoped Services

- ❌ Register a scoped service that takes `ITelemetryContext` or `ILensAppContext` as `Singleton` or `Transient` — these are scoped per-request; a singleton that holds them will share state across requests (see Standard 8)

## Cosmos DB

- ❌ Use `IHttpClientBuilder.AddCosmosDbTelemetry()` — this was removed in 1.4.0; it only worked with Gateway mode (HTTPS). Use `services.AddCosmosDbTelemetry()` on `IServiceCollection` instead
- ❌ Leave `DisableDistributedTracing = true` on `CosmosClientOptions` when using `AddCosmosDbTelemetry()` — the processor receives no spans and emits nothing
- ❌ Set `AlwaysLogExceptions = false` without understanding the consequence — transport-level Cosmos DB failures will be invisible in DGrep

## Per-Request Context

- ❌ Set `IsSynthetic` via `RequestContextItems` in controller code — it works but is an escape hatch; `ISyntheticRequestDetector` is the standard pattern (centralized, testable, covers all code paths)
- ❌ Call `SetItem("")` to clear an error code — empty strings are silently ignored; the value is immutable once set on a request

## Configuration

- ❌ Read `BUILD_VERSION` or `WEBSITE_INSTANCE_ID` from `IConfiguration` in service code — they're in `TelemetryOptions` and `GenevaTelemetryOptions` respectively

## Distributed Tracing

- ❌ Create a custom `ActivitySource` or call `activity.SetTag()` to record per-request data — use structured events instead; OTel trace and span IDs are already available on every event for free (see [distributed-tracing.md](../../../docs/distributed-tracing.md))

## MISE V2

- ❌ Use `DefaultAuthContextBuilder` on a MISE V2 service — MISE V2 projects a reduced identity into `HttpContext.User` that strips most Entra ID claims; use `MiseAuthContextBuilder` from `Microsoft.LENS.Common.Telemetry.MISE` instead (see Standard 13)
