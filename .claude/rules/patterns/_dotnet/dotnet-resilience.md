---
paths:
  - "**/*.cs"
---

# Resilience Patterns for .NET

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for implementing resilience in LENS .NET services. Two backends are canonical, picked by transport:

| Transport | Canonical mechanism | Package | Reference service |
|-----------|--------------------|---------|------|
| **Outbound HTTP** (named/typed `HttpClient`, downstream LENS services, partner APIs) | `Microsoft.Extensions.Http.Resilience` `AddStandardResilienceHandler()` | `Microsoft.Extensions.Http.Resilience` >= 10.1.0 | LENS-DCS `ServiceCollectionExtensions.cs:211-249` |
| **Non-HTTP** (Cosmos SDK, Service Bus SDK, arbitrary delegates) | Polly 8.x package — uses Polly v7 API surface (`Policy.WrapAsync` + `AsyncRetryPolicy` + `AsyncCircuitBreakerPolicy`) for now | `Polly` >= 8.5.2 | LENS-CMS `DataAccess/Resilience/CosmosResiliencePolicies.cs` |

`Microsoft.Extensions.Http.Resilience` is the **MS-blessed forward direction** for HTTP. It builds on Polly v8 internally but exposes a strongly-typed builder (`HttpStandardResilienceOptions`) tailored to HTTP — retry / circuit-breaker / per-attempt timeout / total-request timeout in one wired pipeline. Use it as the default for every named or typed `HttpClient`.

`Microsoft.Extensions.Http.Resilience` is HTTP-only — it cannot wrap arbitrary delegates (Cosmos SDK calls, Service Bus calls, file I/O). For non-HTTP scenarios, use the Polly **8.x package** with the **v7 API surface** that works via the package's legacy compat layer. The `ResiliencePipelineBuilder<T>` (Polly v8 native API) is the eventual forward direction for non-HTTP, but LENS services have not yet migrated. Either API is acceptable for new non-HTTP code; match the surrounding codebase.

> **Version pin**: LENS-CMS pins `Polly 8.5.2`; LENS-DCS pins `Microsoft.Extensions.Http.Resilience 10.1.0`. Polly **7.x** is NOT acceptable — security-fixes and runtime improvements live in 8.x. The v7 API surface is preserved on the 8.x package for backwards compatibility.

---

## Default for outbound HTTP — `AddStandardResilienceHandler`

Every named or typed `HttpClient` registers `AddStandardResilienceHandler()`. This is the canonical LENS pattern; do NOT hand-roll Polly policies for HTTP.

### Minimum viable wiring (per LENS-DCS reference)

```csharp
// DependencyInjection/ServiceCollectionExtensions.cs
private static void AddDownstreamHttpClients(this IServiceCollection services)
{
    services
        .AddHttpClient(HttpClientNames.ExchangeApi)
        .AddOutboundQOSTelemetry()              // LENS-Common QOS instrumentation
        .AddStandardResilienceHandler()
        .Configure(ConfigureLensResiliencePolicy);

    services
        .AddHttpClient(HttpClientNames.TeamsApi)
        .AddOutboundQOSTelemetry()
        .AddStandardResilienceHandler()
        .Configure(ConfigureLensResiliencePolicy);
}

private static void ConfigureLensResiliencePolicy(HttpStandardResilienceOptions options)
{
    options.Retry.MaxRetryAttempts = ResilienceConstants.RetryCount;       // e.g. 3
    options.Retry.Delay = TimeSpan.FromSeconds(ResilienceConstants.ExponentialBackoffBase);
    options.Retry.BackoffType = DelayBackoffType.Exponential;
    options.Retry.UseJitter = true;             // jitter on by default - prevents thundering herd

    options.Retry.ShouldHandle = args =>
    {
        // Network/socket/TLS - always transient
        if (args.Outcome.Exception is HttpRequestException)
        {
            return PredicateResult.True();
        }

        var status = args.Outcome.Result?.StatusCode;

        // 408 RequestTimeout / 429 TooManyRequests / 5xx all transient.
        // 429 is critical for Microsoft Graph (Teams/Exchange/ODSP/Class) and any throttled backend;
        // omitting it makes calls fail on first throttle.
        if (status == HttpStatusCode.RequestTimeout) return PredicateResult.True();
        if (status == HttpStatusCode.TooManyRequests) return PredicateResult.True();
        if (status.HasValue && (int)status.Value >= 500) return PredicateResult.True();

        return PredicateResult.False();
    };
}
```

### `HttpStandardResilienceOptions` — what you get for free

`AddStandardResilienceHandler()` registers FIVE strategies in one pipeline:

| Strategy | Default | Override via |
|----------|---------|--------------|
| **Rate limiter** | 1000 concurrent + 1000 queue | `options.RateLimiter.DefaultRateLimiterOptions` |
| **Total request timeout** | 30s | `options.TotalRequestTimeout.Timeout` |
| **Retry** | 3 attempts, exponential, jitter on | `options.Retry.*` |
| **Circuit breaker** | 50% failure ratio over 30s sampling, min 100 throughput, 5s break | `options.CircuitBreaker.*` |
| **Per-attempt timeout** | 10s | `options.AttemptTimeout.Timeout` |

Order is fixed by the framework: `Total Timeout > Retry > Circuit Breaker > Per-Attempt Timeout > Rate Limiter > HTTP call`. This is the **correct order** — you cannot get it wrong by composition.

### Configuration via IOptions

```csharp
public class HttpResilienceOptions : IConfigOptions
{
    public const string ConfigSectionKey = "HttpResilience";

    [Range(1, 10)]
    public int MaxRetryAttempts { get; set; } = 3;

    [Range(1, 60)]
    public int RetryDelaySeconds { get; set; } = 1;

    [Range(1, 60)]
    public int AttemptTimeoutSeconds { get; set; } = 10;

    [Range(1, 300)]
    public int TotalRequestTimeoutSeconds { get; set; } = 30;

    [Range(1, 100)]
    public int CircuitBreakerMinThroughput { get; set; } = 100;

    [Range(0.0, 1.0)]
    public double CircuitBreakerFailureRatio { get; set; } = 0.5;
}
```

### Hedging (parallel attempts) for critical reads

```csharp
builder.Services
    .AddHttpClient("CriticalLookup")
    .AddOutboundQOSTelemetry()
    .AddStandardHedgingHandler(options =>
    {
        options.Hedging.MaxHedgedAttempts = 2;
        options.Hedging.Delay = TimeSpan.FromMilliseconds(200);
    });
```

Use only when (a) the operation is idempotent (read-only or has a dedupe key on the server) and (b) latency tail-cutting matters more than total RU/cost cost.

---

## Non-HTTP — Polly v7 API on Polly 8.x package

For wrapping non-HTTP calls (`CosmosClient.ReadItemAsync`, `ServiceBusReceiver.ReceiveMessageAsync`, arbitrary delegates), use the Polly **8.x package** with the **v7 API surface**. This is the documented LENS-CMS pattern (`DataAccess/Resilience/CosmosResiliencePolicies.cs`) and is acceptable because `Microsoft.Extensions.Http.Resilience` is HTTP-only.

### Canonical Cosmos resilience class (LENS-CMS reference)

```csharp
using Polly;
using Polly.CircuitBreaker;
using Polly.Retry;
using Polly.Wrap;

public sealed class CosmosResiliencePolicies
{
    private readonly AsyncRetryPolicy retryPolicy;
    private readonly AsyncCircuitBreakerPolicy circuitBreakerPolicy;
    private readonly AsyncPolicyWrap wrappedPolicy;
    private readonly ILogger logger;

    public CosmosResiliencePolicies(IOptions<CosmosOptions> options, ILogger<CosmosResiliencePolicies> logger)
    {
        ArgumentNullException.ThrowIfNull(options);
        this.logger = logger ?? throw new ArgumentNullException(nameof(logger));

        var config = options.Value;
        this.retryPolicy = BuildRetryPolicy(config, logger);
        this.circuitBreakerPolicy = BuildCircuitBreakerPolicy(config, logger);

        // Compose: CircuitBreaker WRAPS Retry WRAPS [Operation].
        // If circuit is open, reject immediately - don't retry.
        // If circuit is closed/half-open, retry transient failures within the breaker.
        this.wrappedPolicy = Policy.WrapAsync(this.circuitBreakerPolicy, this.retryPolicy);
    }

    public Task<T> ExecuteAsync<T>(Func<CancellationToken, Task<T>> operation, CancellationToken ct = default)
        => this.wrappedPolicy.ExecuteAsync(operation, ct);

    private static AsyncRetryPolicy BuildRetryPolicy(CosmosOptions config, ILogger logger) =>
        Policy
            .Handle<CosmosException>(IsTransientCosmosException)
            .WaitAndRetryAsync(
                retryCount: config.RetryMaxAttempts,
                sleepDurationProvider: retryAttempt =>
                    TimeSpan.FromMilliseconds(config.RetryBaseDelayMs * Math.Pow(2, retryAttempt - 1))
                    + TimeSpan.FromMilliseconds(Random.Shared.Next(0, config.RetryMaxJitterMs)),
                onRetry: (exception, timeSpan, retryAttempt, _) =>
                {
                    var statusCode = exception is CosmosException cx ? (int)cx.StatusCode : 0;
                    logger.ResilienceRetry(retryAttempt, timeSpan.TotalMilliseconds, statusCode);
                });

    private static AsyncCircuitBreakerPolicy BuildCircuitBreakerPolicy(CosmosOptions config, ILogger logger) =>
        Policy
            .Handle<CosmosException>(IsTransientCosmosException)
            .AdvancedCircuitBreakerAsync(
                failureThreshold: config.CircuitBreakerFailureThreshold,
                samplingDuration: TimeSpan.FromSeconds(config.CircuitBreakerSamplingDurationSeconds),
                minimumThroughput: config.CircuitBreakerMinimumThroughput,
                durationOfBreak: TimeSpan.FromSeconds(config.CircuitBreakerBreakDurationSeconds),
                onBreak: (ex, breakDuration) => logger.CircuitBreakerOpened(breakDuration.TotalSeconds),
                onReset: () => logger.CircuitBreakerReset(),
                onHalfOpen: () => logger.CircuitBreakerHalfOpen());

    // Cosmos transient errors: ServiceUnavailable (503) and RequestTimeout (408) only.
    // 429 (TooManyRequests) is handled by the Cosmos SDK's built-in retry - DO NOT layer a Polly retry on top.
    // 401/403/404/409/412 are non-transient application-level errors.
    internal static bool IsTransientCosmosException(CosmosException ex) =>
        ex.StatusCode == HttpStatusCode.ServiceUnavailable
        || ex.StatusCode == HttpStatusCode.RequestTimeout;
}
```

### Why the Cosmos SDK's built-in retry is enough for 429

The Cosmos SDK already retries on `429 TooManyRequests` per `CosmosClientOptions.MaxRetryAttemptsOnRateLimitedRequests` (default 9, max wait 30s). The Polly wrapper above ONLY handles 503 (server unavailable) and 408 (request timeout) — wrapping 429 in Polly on top of the SDK's own 429 handling produces double-retry behavior, doubling the latency under throttling.

| Failure | Handled by | Polly should also handle? |
|---------|-----------|--------------------------|
| 429 TooManyRequests | Cosmos SDK built-in | NO - SDK handles it |
| 408 RequestTimeout | Cosmos SDK gives up after first - YES Polly retries | YES (transient) |
| 503 ServiceUnavailable | Cosmos SDK gives up after first - YES Polly retries | YES (transient) |
| 401/403/404/409/412 | Application-level | NO - non-transient |

### Configuration class for the Cosmos resilience policy

```csharp
public sealed class CosmosOptions : IConfigOptions
{
    public const string ConfigSectionKey = "Cosmos";

    [Required]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    [Range(1, 10)]
    public int RetryMaxAttempts { get; set; } = 3;

    [Range(50, 5000)]
    public int RetryBaseDelayMs { get; set; } = 200;

    [Range(0, 1000)]
    public int RetryMaxJitterMs { get; set; } = 100;

    [Range(0.1, 1.0)]
    public double CircuitBreakerFailureThreshold { get; set; } = 0.5;

    [Range(5, 300)]
    public int CircuitBreakerSamplingDurationSeconds { get; set; } = 30;

    [Range(2, 100)]
    public int CircuitBreakerMinimumThroughput { get; set; } = 10;

    [Range(5, 300)]
    public int CircuitBreakerBreakDurationSeconds { get; set; } = 30;
}
```

### Polly v8 native API (`ResiliencePipelineBuilder`) — eventual direction

Polly 8 ships a new strongly-typed builder. LENS services have NOT migrated to it yet — both LENS-CMS and LENS-DCS use either v7-API-on-v8-package (Cosmos) or `Microsoft.Extensions.Http.Resilience` (HTTP). Either API works on the 8.x package; new non-HTTP code MAY use `ResiliencePipelineBuilder<T>` if the surrounding codebase doesn't already standardize on the v7 API:

```csharp
// Forward direction for non-HTTP - acceptable for new code
var pipeline = new ResiliencePipelineBuilder<MyResult>()
    .AddRetry(new RetryStrategyOptions<MyResult>
    {
        MaxRetryAttempts = 3,
        BackoffType = DelayBackoffType.Exponential,
        UseJitter = true,
        ShouldHandle = new PredicateBuilder<MyResult>().Handle<TransientException>(),
    })
    .AddCircuitBreaker(new CircuitBreakerStrategyOptions<MyResult>
    {
        FailureRatio = 0.5,
        SamplingDuration = TimeSpan.FromSeconds(30),
        MinimumThroughput = 10,
        BreakDuration = TimeSpan.FromSeconds(30),
    })
    .Build();
```

**Match the surrounding codebase.** If the existing service uses `Policy.WrapAsync(...)`, keep that style. If you're starting a new resilience class, either API is fine.

---

## Azure SDK built-in resilience — DO NOT layer Polly on top

All Azure SDKs ship retry built in. Wrapping them in Polly produces double-retry (longer tail latency, more RU consumption, harder debugging).

| SDK | Built-in retry behavior |
|-----|------------------------|
| `CosmosClient` | 429: `MaxRetryAttemptsOnRateLimitedRequests` (default 9, max wait 30s); some SDK versions also retry on 503 |
| `BlobServiceClient` / `BlobClient` | 3 retries, exponential, max delay 60s |
| `ServiceBusClient` | Configurable per `ServiceBusRetryOptions` (default 3 retries, exponential) |
| `KeyClient` / `SecretClient` | Default retry policy in `Azure.Core.RetryOptions` |

```csharp
// CORRECT: trust SDK built-in retry
await this.blobServiceClient.GetUserDelegationKeyAsync(startsOn, expiresOn, cancellationToken);

// WRONG: double-retry (SDK retries 3x, Polly retries 3x = 9 attempts total)
var policy = Policy.Handle<Azure.RequestFailedException>()
    .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)));

await policy.ExecuteAsync(() =>
    this.blobServiceClient.GetUserDelegationKeyAsync(startsOn, expiresOn, cancellationToken));
```

Polly is appropriate ONLY for non-transient recovery scenarios the SDK doesn't handle — e.g. wrapping a `CosmosClient.ReadItemAsync` call so a circuit breaker can open after enough 503s to trip a global fallback. For straight retry, the SDK's own configuration (`MaxRetryAttemptsOnRateLimitedRequests`, `ServiceBusRetryOptions.MaxRetries`) is the right knob.

---

## Cosmos retry configuration on `CosmosClientOptions`

For 429 throttling, configure the SDK directly. **Do NOT wrap Cosmos in Polly to handle 429.**

```csharp
new CosmosClientOptions
{
    ApplicationName = "MyService",
    ConnectionMode = ConnectionMode.Direct,
    EnableContentResponseOnWrite = false,
    MaxRetryAttemptsOnRateLimitedRequests = 9,
    MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(30),
    CosmosClientTelemetryOptions = new CosmosClientTelemetryOptions
    {
        DisableDistributedTracing = false,    // required for AddCosmosDbTelemetry()
    },
}
```

The Polly wrapper (above) ONLY handles 503 / 408 — non-throttling transient errors the SDK doesn't retry on its own.

---

## Enforcement Table

| Rule | Severity | Check |
|------|----------|-------|
| Outbound HTTP without `AddStandardResilienceHandler()` | **REJECT** | Every named/typed `HttpClient` must register `AddStandardResilienceHandler()` |
| Hand-rolled `Policy.WrapAsync(...)` for HTTP transport | **REJECT** | Use `AddStandardResilienceHandler()` for HTTP |
| `Microsoft.Extensions.Http.Resilience` < 10.1.0 | **WARN** | Pin to >= 10.1.0 |
| `Polly` package version < 8.5.2 | **WARN** | Pin to >= 8.5.2; v7.x package is forbidden |
| `Polly` package version 7.x | **REJECT** | Use 8.x package; v7 API surface still works on 8.x via compat layer |
| Polly retry wrapping `CosmosClient.ReadItemAsync` for 429 | **REJECT** | Configure `MaxRetryAttemptsOnRateLimitedRequests` on `CosmosClientOptions` instead |
| Polly retry wrapping any Azure SDK call for built-in transient handling | **REJECT** | SDK retries are the canonical knob; Polly only for cases the SDK doesn't handle |
| Catch-all retry (`Policy.Handle<Exception>()`) | **REJECT** | Specify transient exception types only |
| Fixed retry delay (no exponential backoff or jitter) | **REJECT** | Always exponential + jitter |
| Hardcoded retry/timeout values | **WARN** | Use `IConfigOptions` with `[Range]` |
| Missing resilience logging on retry/break | **WARN** | Log retry attempt + circuit-state changes |

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Hand-rolled `Policy.WrapAsync(retry, circuitBreaker, timeout)` for `HttpClient` | Reinvents what `AddStandardResilienceHandler()` provides; gets composition order wrong; misses jitter | `AddStandardResilienceHandler().Configure(opts => ...)` |
| `Policy.Handle<Exception>()` | Retries `ValidationException`, `ArgumentException`, etc. | Specify transient types only (`HttpRequestException`, `CosmosException` filtered to 503/408) |
| Fixed retry delay | Thundering herd | Exponential + `UseJitter = true` |
| Polly retry layered over Cosmos 429 retry | Double-retry doubles latency under throttling | Configure SDK's `MaxRetryAttemptsOnRateLimitedRequests` |
| Polly retry layered over Azure Blob/Service Bus SDK built-in retry | Same double-retry pattern | Trust SDK retries; reach for Polly only for cases SDK doesn't cover |
| Per-request `Policy.Wrap(...)` allocation | GC pressure under load | Build once in DI / repository constructor; `private readonly AsyncPolicyWrap` |
| Retry outside Circuit Breaker | Retries while circuit open = wasted attempts | Circuit Breaker WRAPS Retry (`Policy.WrapAsync(circuitBreakerPolicy, retryPolicy)`) |
| `BrokenCircuitException` unhandled | No fallback when circuit open | `try { ... } catch (BrokenCircuitException) { return cached; }` |
| 429 marked transient in Polly retry for Cosmos | Cosmos SDK already handles it; double-retry | 429 OUT of Polly predicate (only 503/408 transient) |
| 429 NOT marked transient in HTTP `ShouldHandle` | Microsoft Graph / generic backends throttle on 429; first-attempt failures cascade | 429 IN `ShouldHandle` for `AddStandardResilienceHandler` (Graph + most LENS partners require it) |

---

## Code Review Checklist

```
+===========================================================================+
|  RESILIENCE REVIEW                                                        |
|                                                                           |
|  Outbound HTTP (named or typed HttpClient):                               |
|  [ ] AddStandardResilienceHandler() registered                            |
|  [ ] ShouldHandle includes 429 TooManyRequests (Graph + LENS partners)    |
|  [ ] AddOutboundQOSTelemetry registered before resilience handler         |
|  [ ] Retry attempts/delay/timeout from IConfigOptions, not literals       |
|  [ ] Hedging used only for idempotent reads                               |
|                                                                           |
|  Non-HTTP (Cosmos, Service Bus, arbitrary delegates):                     |
|  [ ] Polly 8.x package (>= 8.5.2); v7.x package forbidden                 |
|  [ ] Composed via Policy.WrapAsync(circuitBreaker, retry) (CB wraps Retry)|
|  [ ] Cosmos retry for 503/408 only - 429 handled by SDK                  |
|  [ ] Polly NOT layered over Azure SDK built-in retry                      |
|  [ ] Exponential backoff + jitter                                         |
|  [ ] AsyncPolicyWrap built ONCE in constructor (not per request)          |
|                                                                           |
|  Cosmos SDK config:                                                       |
|  [ ] MaxRetryAttemptsOnRateLimitedRequests configured (default 9)         |
|  [ ] MaxRetryWaitTimeOnRateLimitedRequests configured (default 30s)       |
|  [ ] DisableDistributedTracing = false (for telemetry)                    |
|                                                                           |
|  Logging / Observability:                                                 |
|  [ ] Retry attempts logged (correlation ID + status code)                 |
|  [ ] Circuit breaker open/half-open/reset events logged                   |
|  [ ] BrokenCircuitException paths log + emit fallback metric              |
+===========================================================================+
```

---

## References

- LENS-DCS canonical HTTP resilience: `references/LENS-DCS/sources/dev/DataCollector/DataCollector.DependencyInjection/Extensions/ServiceCollectionExtensions.cs:211-249, 429-463`
- LENS-CMS canonical Cosmos resilience: `references/LENS-CMS/sources/dev/CMS/src/DataAccess/Resilience/CosmosResiliencePolicies.cs`
- LENS-CMS canonical Lookup resilience (HTTP-shaped Polly v7 API): `references/LENS-CMS/sources/dev/CMS/src/DataAccess/Resilience/LookupResiliencePolicies.cs`
- Package pins: LENS-CMS `Polly 8.5.2`, LENS-DCS `Microsoft.Extensions.Http.Resilience 10.1.0` + `Microsoft.Extensions.Http.Polly 10.0.1`
