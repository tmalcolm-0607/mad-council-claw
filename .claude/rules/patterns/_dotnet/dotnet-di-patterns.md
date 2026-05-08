---
paths:
  - "**/*.cs"
  - "**/Program.cs"
---

# Dependency Injection Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

## Single-File Flat DI Extension (canonical layout)

Per `lens-aspnet-structure` Standard 6 + `references/di-pattern.md:7-15`: the **`DependencyInjection`** project has **one file** (`{ServiceName}ServiceCollectionExtensions.cs`), **one public method** (`AddServiceNameServices(...)`), all helpers `private static`, **no subfolders**, **no internal classes**. The class is `[ExcludeFromCodeCoverage] public static class`. `Program.cs` calls exactly one method.

Helpers are grouped by phase: `AddDataAccessServices`, `AddBusinessLogicServices`, `AddAppOptions`. Adding a new helper means adding a new private static method to the same file — never a new file or subfolder.

```csharp
// DependencyInjection/{ServiceName}ServiceCollectionExtensions.cs
[ExcludeFromCodeCoverage]
public static class ServiceNameServiceCollectionExtensions
{
    /// <summary>Registers all {ServiceName} domain services.</summary>
    public static IServiceCollection AddServiceNameServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        services.AddDataAccessServices(configuration, environment);
        services.AddBusinessLogicServices();
        services.AddAppOptions(configuration);
        return services;
    }

    private static void AddDataAccessServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        services.AddHttpClient();

        // CosmosDB - Tier 2 Singleton (generic infrastructure), Tier 1 Scoped (domain interface)
        services.AddSingleton<ICosmosClientProvider, CosmosClientProvider>();
        services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();
        services.AddScoped<IFooRepository, FooRepository>();

        // Outbound LENS service clients — Repository naming per dotnet-repository-two-tier.md §6
        services.AddScoped<IBarRepository, BarRepository>();
    }

    private static void AddBusinessLogicServices(this IServiceCollection services)
    {
        services.AddScoped<IFooHandler, FooHandler>();
        services.AddScoped<IBarHandler, BarHandler>();
    }

    private static void AddAppOptions(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosDbSettingsOptions>()
            .Bind(configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<BarServiceOptions>()
            .Bind(configuration.GetSection(BarServiceOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }
}

// Program.cs - exactly ONE call into the aggregator
builder.Services.AddServiceNameServices(builder.Configuration, builder.Environment);
```

| Layout rule | REJECT trigger |
|---|---|
| Single file in DependencyInjection project | Multiple `*.cs` files under `DependencyInjection/` (subfolder OR co-located) |
| One public entry point | More than one `public static IServiceCollection Add*` method |
| All helpers `private static` | Any `internal` / `public` helper class or method |
| `[ExcludeFromCodeCoverage]` on the static class | Class missing the attribute (DI wiring is exempt by convention; tests don't cover this layer) |
| `Program.cs` calls exactly one method | `Program.cs` calling `.AddDataAccess(...).AddBusinessLogic(...)` directly — that fragments wiring |

See `dotnet-architecture.md` § Service Registration for the same pattern in architectural context.

---

## Core Principles

Follow official .NET dependency injection guidelines for clean, maintainable service design.

### Constructor Injection (Preferred)

```csharp
// ✓ CORRECT: Constructor injection — sealed Handler, camelCase fields
// Lives in BusinessLogic/Handlers/CampaignHandler.cs
public sealed class CampaignHandler : ICampaignHandler
{
    private readonly ICampaignRepository repository;
    private readonly ILogger<CampaignHandler> logger;

    public CampaignHandler(
        ICampaignRepository repository,
        ILogger<CampaignHandler> logger)
    {
        ParameterContracts.CheckIsNotNull(repository, nameof(repository));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.repository = repository;
        this.logger = logger;
    }
}
```

### Avoid Service Locator Anti-Pattern

```csharp
// ✗ WRONG: Service locator pattern
public sealed class CampaignHandler
{
    private readonly IServiceProvider serviceProvider;

    public CampaignHandler(IServiceProvider serviceProvider)
    {
        this.serviceProvider = serviceProvider;
    }

    public async Task Process()
    {
        var repository = this.serviceProvider.GetRequiredService<ICampaignRepository>();
    }
}

// ✓ CORRECT: Explicit dependency
public sealed class CampaignHandler
{
    private readonly ICampaignRepository repository;

    public CampaignHandler(ICampaignRepository repository)
    {
        this.repository = repository;
    }
}
```

### Service Lifetime Selection

| Lifetime | When to Use | Example |
|----------|-------------|----------------|
| **Singleton** | Stateless, thread-safe, expensive to create | `CosmosClient`, `ICosmosDbResourceRepository` (Tier 2 generic — see `dotnet-repository-two-tier.md`), rules engine |
| **Scoped** | Request-specific state, dispose per request | Tier 1 entity-typed repositories (`ICampaignRepository`, `I{Domain}Repository`); business handlers (`ICampaignHandler`, `I{Feature}Handler`) |
| **Transient** | Lightweight, stateful per operation | Validators, request processors |

```csharp
// Tier 2 generic repository + CosmosClient are singletons (expensive to create, thread-safe)
builder.Services.AddSingleton<CosmosClient>(...);
builder.Services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();

// Tier 1 entity-typed repositories are scoped (per-request unit-of-work isolation)
builder.Services.AddScoped<ICampaignRepository, CampaignRepository>();

// Application handlers (BusinessLogic) — Scoped to match request lifetime
builder.Services.AddScoped<ICampaignHandler, CampaignHandler>();

// Per-operation lightweight collaborators — Transient
builder.Services.AddTransient<ICampaignRequestMapper, CampaignRequestMapper>();
```

> **Validation note.** LENS-canonical request validation uses DataAnnotations + `[ApiController]` automatic 400-response — **no DI registration** is required for validators. See `api-validation.md` for the canonical pattern. `IValidator<T>` (FluentValidation) is non-canonical; avoid registering FluentValidation validators on new code.

### Scoped Service Injection in Middleware

**Pattern**: Scoped services cannot be injected in middleware constructors (middleware is singleton). Use `InvokeAsync` parameter injection.

```csharp
// ✗ WRONG: Scoped service in middleware constructor
public sealed class CorrelationIdMiddleware
{
    private readonly RequestDelegate next;
    private readonly ICampaignRepository repository; // Scoped!

    public CorrelationIdMiddleware(
        RequestDelegate next,
        ICampaignRepository repository) // Will throw at runtime
    { }
}

// ✓ CORRECT: Inject scoped service in InvokeAsync
public sealed class CorrelationIdMiddleware
{
    private readonly RequestDelegate next;

    public CorrelationIdMiddleware(RequestDelegate next)
    {
        this.next = next;
    }

    public async Task InvokeAsync(
        HttpContext context,
        ICampaignRepository repository) // Resolved per request
    {
        await this.next(context);
    }
}
```

### Background Services and Scoped Dependencies

**Pattern**: Hosted services/background services are singletons. Use `IServiceScopeFactory` to create scopes for scoped dependencies.

```csharp
public sealed class EventProcessingService : BackgroundService
{
    private readonly IServiceScopeFactory scopeFactory;
    private readonly ILogger<EventProcessingService> logger;

    public EventProcessingService(
        IServiceScopeFactory scopeFactory,
        ILogger<EventProcessingService> logger)
    {
        this.scopeFactory = scopeFactory;
        this.logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = this.scopeFactory.CreateScope();
            var repository = scope.ServiceProvider
                .GetRequiredService<ICampaignRepository>();

            // Process events with scoped repository
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }
    }
}
```

### Validate Service Registrations at Startup

```csharp
builder.Services.AddOptions<RepositoryOptions>()
    .BindConfiguration("Repository")
    .ValidateDataAnnotations()
    .ValidateOnStart(); // Validates at startup, not first use
```

### Project-Specific Guidelines

| Service | Lifetime | Rationale |
|---------|----------|-----------|
| `I{Domain}Repository` (Tier 1 entity-typed) | Scoped | Per-request unit-of-work isolation; see `dotnet-repository-two-tier.md` |
| `ICosmosDbResourceRepository` (Tier 2 generic) | Singleton | Thread-safe, expensive to create; see `dotnet-repository-two-tier.md` |
| `CosmosClient` | Singleton | Connection pooling, expensive to create |
| `IConnectionMultiplexer` | Singleton | Redis connection pooling |
| Rules Engine | Singleton | Stateless rule evaluation |
| Request validation | n/a (no DI) | Use DataAnnotations + `[ApiController]` auto-validation; for cross-field rules implement `IValidatableObject` on the DTO. See `api-validation.md`. |
| AI/LLM services | Scoped | Per-request context |
| Hub connections | Transient | SignalR handles lifecycle |

### Common Mistakes

1. **Captive dependencies**: Singleton capturing scoped service (throws in development mode)
2. **Service locator**: Injecting `IServiceProvider` to manually resolve
3. **Stateful singletons**: Storing request state in singleton services (thread safety issues)
4. **Missing disposal**: Not disposing scoped services in background services
5. **Over-specification**: Registering interfaces not consumed by any code

### Sources

- [Dependency injection guidelines - .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/guidelines)
- [Dependency injection in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection)

---

## Per-request telemetry context (LENS services)

LENS services do NOT inject `ILogger<T>` + `IMeterFactory` directly into scoped services. Inject `ITelemetryContext<TLogger>` (typed metrics + structured logging) and `ILensAppContext` (request + auth context) instead. Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 8 (lines 316-348); LENS-Common CLAUDE.md "Inject `ITelemetryContext` for metrics/logging, `ILensAppContext` for request/auth context."

### Why typed `ITelemetryContext<TLogger>`?

Typed `ITelemetryContext<TLogger>` exposes `StructuredLogger` as the concrete `[StructuredEventLogger]`-generated subclass for the service, giving direct `LogEvent(T)` overloads without casting. The non-generic `ITelemetryContext` works when the consumer only needs `IMeterFactory` / `ILogger`, but the typed variant is the default for any scoped service that emits structured events.

```csharp
// ✗ WRONG — individual deps miss auth context; cannot emit security events without rewiring
public sealed class SasRequestPipeline(
    ILogger<SasRequestPipeline> logger,
    IMeterFactory meterFactory)
{
    // ...
}

// ✓ CORRECT — typed ITelemetryContext gives direct LogEvent(T); ILensAppContext provides auth/request context
public sealed class SasRequestPipeline(
    ITelemetryContext<MyServiceStructuredLogger> telemetryContext,
    ILensAppContext appContext)
{
    private readonly SasOperationMetric metric =
        SasMetrics.CreateSasOperationMetric(telemetryContext.MeterFactory.Create("MyService.Sas"));

    public void Process()
    {
        // No cast needed — the typed StructuredLogger has the LogEvent(SasRequestEvent) overload
        telemetryContext.StructuredLogger.LogEvent(new SasRequestEvent
        {
            CallerAppId = appContext.AuthContext.SubjectClaims.CurrentAppId,
            CaseId = currentCaseId,
            OccurredAt = DateTimeOffset.UtcNow,
        });
    }
}
```

### Lifetime: Scoped (always)

`ITelemetryContext` is scoped per-request — populated by `InitializeTelemetryContextMiddleware`. A singleton that captures `ITelemetryContext` is a captive-dependency bug that throws in development mode. **Any service that depends on `ITelemetryContext` or `ILensAppContext` MUST be registered as Scoped.**

```csharp
// ✗ WRONG — captive dependency
services.AddSingleton<SasRequestPipeline>();

// ✓ CORRECT — lifetime matches ITelemetryContext
services.AddScoped<SasRequestPipeline>();
```

For singletons that need metrics, inject `IMeterFactory` directly and create instruments once in the constructor — never call `meterFactory.Create()` per-request. For background services (singletons), use `IServiceScopeFactory` to resolve `ITelemetryContext`/`ILensAppContext` per work unit (see "Background Services and Scoped Dependencies" above).

### Anti-pattern: per-request `meterFactory.Create()`

```csharp
// ✗ WRONG — creates a new Meter per call; instrument cardinality explodes
public void Process()
{
    var meter = telemetryContext.MeterFactory.Create("MyService.Sas");
    var metric = SasMetrics.CreateSasOperationMetric(meter);  // every call!
    metric.Add(1, ...);
}

// ✓ CORRECT — instrument lifetime = service lifetime
private readonly SasOperationMetric metric;

public SasRequestPipeline(ITelemetryContext<MyServiceStructuredLogger> telemetryContext, ...)
{
    this.metric = SasMetrics.CreateSasOperationMetric(
        telemetryContext.MeterFactory.Create("MyService.Sas"));
}
```

`AddLensTelemetry` configures `.AddMeter("*")`; no per-meter registration is needed. `IRequestTelemetryContext` is `[Obsolete]` — migrate to `ITelemetryContext` + `ILensAppContext`.

---

## Request Validation (Canonical: DataAnnotations + `[ApiController]`)

LENS request validation does NOT go through DI-registered `IValidator<T>` services. The canonical pattern is:

1. Decorate request DTOs with DataAnnotations (`[Required]`, `[StringLength]`, `[EmailAddress]`, etc.).
2. Decorate the controller with `[ApiController]` — ASP.NET Core auto-validates `[FromBody]` parameters and returns `400 Bad Request` with a `ProblemDetails` payload BEFORE the action method runs.
3. For cross-field rules, implement `IValidatableObject.Validate(ValidationContext)` directly on the DTO.
4. For business-rule violations discovered after model binding (e.g., entity not found, state-transition denied), throw a typed `HandlerException` subclass from the handler — `GlobalErrorHandlingMiddleware` (registered by `AddLensTelemetry`) maps the exception to the appropriate HTTP status.

No `IValidator<T>` DI registration is required, and no per-handler `validator.ValidateAsync(...)` call is needed. See `api-validation.md` for the canonical examples and `dotnet-error-handling.md` for the typed-exception hierarchy.

> **Avoid FluentValidation for new LENS services.** It introduces DI-lifecycle hazards (singleton time-trap with `DateTimeOffset.UtcNow`, captive-dependency bugs, validator-without-caller dead code) and duplicates the responsibility ASP.NET Core's model-validation layer already owns. If you inherit a service that uses FluentValidation, treat it as legacy and migrate to DataAnnotations on schema changes.
