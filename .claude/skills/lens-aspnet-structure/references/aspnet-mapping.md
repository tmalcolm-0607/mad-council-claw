# ASP.NET Core → LENS Pattern Mapping

> For engineers familiar with standard ASP.NET Core conventions. Maps the terminology and patterns you already know to their LENS equivalents, and explains what each LENS pattern adds.

---

## Quick Reference

| ASP.NET Core | LENS equivalent | Key difference |
|---|---|---|
| `XxxService` (business logic) | `XxxHandler` | Typed exception contract; `sealed`; throws — never returns `null` or `Result<T>` |
| `ILogger<T>` injection | `ITelemetryContext<MyServiceStructuredLogger>` (+ `ILensAppContext`) | Typed `LogEvent(TEvent)` for Geneva-bound structured events; carries auth + request context; Scoped lifetime mandatory |
| `XxxRepository` / `XxxService` (data access) | `IXxxRepository` + `XxxRepository` | Tier 1: entity-typed; handler's direct dependency; wraps infrastructure exceptions |
| Generic repository / Unit of Work | `ICosmosDbResourceRepository` | Tier 2: type-parameterised CRUD, no domain knowledge, `CosmosException` propagates up to Tier 1 |
| Typed `HttpClient` wrapper | `IXxxRepository` + `XxxRepository` | Interface speaks in local domain types; DataModels mapping and `IHttpClientFactory` usage stay inside the implementation |
| `Program.cs` DI registration | `{ServiceName}DependencyInjection` project | Separated so it's the only place that knows all concretions simultaneously |
| `IHostedService` / `BackgroundService` | Same, but delegates to a Handler | Background job = infrastructure; business logic still lives in a handler it injects |
| `IOptions<T>.Bind(...)` | `AddOptions<T>().Bind(...).ValidateDataAnnotations().ValidateOnStart()` | Startup validation — bad config fails at boot, not at first request |
| `UseExceptionHandler` / custom middleware | `GlobalErrorHandlingMiddleware` | Always returns 500; `SanitizedMessageException` is the only escape hatch for surfacing a message |

---

## Business Logic: `Service` → `Handler`

In standard ASP.NET Core it's common to put business logic in a class named `OrderService`. LENS names these classes **Handlers** — the name signals a specific contract that plain "Service" does not:

- The implementation is `sealed` — handlers are not meant to be subclassed
- Business rule failures **throw** a scenario-named `HandlerException` subclass — they never return `null`, an empty object, or a `Result<T>` discriminated union; no `HttpStatusCode` on the exception
- Each `HandlerException` subclass is a sentinel: the controller catches it by type and decides the HTTP response

```csharp
// ✅ LENS — Handler
public sealed class OrderHandler : IOrderHandler
{
    public async Task<Order> GetOrderAsync(Guid tenantId, Guid orderId)
    {
        var order = await this.dataStore.GetOrderAsync(tenantId, orderId);
        if (order is null)
            throw new OrderNotFoundException("Order not found.");
        return order;
    }
}

// ⚠️ Standard ASP.NET Core — Service (familiar, but loses the typed exception contract)
public class OrderService : IOrderService
{
    public async Task<Order?> GetOrderAsync(Guid tenantId, Guid orderId)
    {
        return await this.repository.GetOrderAsync(tenantId, orderId); // null if not found
        // caller must check null — behaviour is not deterministic
    }
}
```

The controller's catch ladder becomes a routing table: `catch (OrderNotFoundException)` → `NotFound(...)`. Anything uncaught → `GlobalErrorHandlingMiddleware` → 500. No ambiguity.

---

## Data Access: `Repository` → Two-Tier Repository

Standard ASP.NET Core repositories are typically a single tier. LENS splits DataAccess into two:

- **Tier 1 — `IXxxRepository`**: entity-typed (`GetOrderAsync`, `CreateOrderAsync`). Catches `CosmosException` here and wraps it into `DataStoreException`. Returns domain models. This is what the handler injects. Scoped.
- **Tier 2 — `ICosmosDbResourceRepository`**: generic `CreateAsync<T>`, `GetByIdAsync<T>`, etc. No domain knowledge. `CosmosException` propagates up to Tier 1. Singleton.

```csharp
// Standard repository (single tier — familiar)
public interface IOrderRepository
{
    Task<Order?> GetOrderAsync(Guid tenantId, Guid orderId);
}

// LENS Tier 1 (what the handler injects — same shape, but CosmosException is wrapped inside)
public interface IOrderRepository
{
    Task<Order?> GetOrderAsync(Guid tenantId, Guid orderId);
}
// Tier 2 (ICosmosDbResourceRepository) is an implementation detail the handler never sees
```

The split means `CosmosException` can never reach BusinessLogic — it is caught and converted to `DataStoreException` inside `OrderRepository` and goes no further.

---

## Outbound HTTP: Typed `HttpClient` → `IXxxRepository`

ASP.NET Core typed `HttpClient` wrappers are the direct analogue. The LENS addition: if the outbound service speaks `Microsoft.LENS.Common.DataModels` types, those types are **mapped inside the implementation** — the interface the handler depends on uses local Common domain types only.

```csharp
// ✅ LENS — interface uses local domain types; named with Repository suffix
public interface IBarRepository
{
    Task<BarResult> PostBarAsync(BarRequest request, CancellationToken ct);
}

// ✅ DataModels mapping and IHttpClientFactory usage are implementation details
internal sealed class BarRepository : IBarRepository
{
    private readonly IHttpClientFactory httpClientFactory;

    public BarRepository(IHttpClientFactory httpClientFactory) { ... }

    public async Task<BarResult> PostBarAsync(BarRequest request, CancellationToken ct)
    {
        var dataModelsRequest = new DataPipelineRequest<BarData> { /* map from request */ };
        using var client = this.httpClientFactory.CreateClient();
        // ... call, deserialise, map DataModels response → BarResult
    }
}
```

A breaking change to the `DataPipelineRequest<T>` contract only touches `BarRepository` — the handler and interface are unaffected.

For SDK clients (Graph, ARM, Key Vault) that are expensive to construct, the pattern extends to two tiers: `I{Service}ClientProvider` (Singleton, manages SDK client lifecycle) + `I{Service}Repository` (Scoped, calls the provider and maps responses). See [repository-pattern-external.md](repository-pattern-external.md) for the full SDK provider pattern.

---

## DI Registration: `Program.cs` → `DependencyInjection` Project

Standard ASP.NET Core wires everything in `Program.cs`. LENS separates this into a dedicated project:

```csharp
// Standard ASP.NET Core — everything in Program.cs
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();

// ✅ LENS — Program.cs calls one method
builder.Services.AddOrderServices(builder.Configuration);

// The DependencyInjection project owns the details
public static class OrderServiceCollectionExtensions
{
    public static void AddOrderServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddBusinessLogicServices();
        services.AddDataAccessServices(configuration);
        services.AddAppOptions(configuration);
    }
    // private static helpers below...
}
```

`DependencyInjection` is the only project that references all layers simultaneously — which is exactly why it is its own project. API never gets a reference to DataAccess through it; the project references enforce this.

> Canonical `Program.cs` structure, startup sequence, and middleware pipeline ordering rules: [program-startup.md](program-startup.md)

---

## Background Services: `BackgroundService` → delegates to a Handler

A `BackgroundService` is infrastructure — it pumps messages off a queue or timer. Business logic still lives in a Handler. The background service injects the handler and delegates.

```csharp
// ✅ LENS — background service is thin infrastructure
public sealed class OrderQueueProcessor : BackgroundService
{
    private readonly IOrderHandler orderHandler;

    public OrderQueueProcessor(IOrderHandler orderHandler)
    {
        ParameterContracts.CheckIsNotNull(orderHandler, nameof(orderHandler));
        this.orderHandler = orderHandler;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // receive message, then:
        await this.orderHandler.ProcessOrderAsync(message.OrderId);
    }
}

// ❌ Business logic inline in BackgroundService — bypasses the handler layer
protected override async Task ExecuteAsync(CancellationToken stoppingToken)
{
    var order = await this.cosmosDbService.GetOrderAsync(...); // DataAccess skipped
    if (order.Status == ...) { /* business rule */ }
}
```

---

## Configuration: `IConfiguration` → `IOptions<T>` with Startup Validation

Injecting `IConfiguration` directly into services is common in standard ASP.NET Core but LENS treats it as a violation — it defers configuration errors to runtime rather than startup.

```csharp
// ❌ Common in ASP.NET Core — IConfiguration injected directly
public class OrderService(IConfiguration config)
{
    private readonly string endpoint = config["ExternalApi:Endpoint"]
        ?? throw new InvalidOperationException("Missing config"); // fails at first use
}

// ✅ LENS — typed options validated at startup
public sealed class OrderHandler(IOptions<ExternalApiOptions> options) { }

// In DependencyInjection:
services.AddOptions<ExternalApiOptions>()
    .Bind(configuration.GetSection(ExternalApiOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart(); // fails at boot — never reaches a request
```

---

## What LENS Deliberately Omits

| Common ASP.NET Core pattern | Why LENS does not use it |
|---|---|
| `Result<T>` / `OneOf<T>` discriminated union | Handlers throw; controllers catch. Typed exceptions give deterministic routing without wrapping every return type |
| Returning `null` from a service for "not found" | Handlers throw a typed `HandlerException` subclass (e.g. `OrderNotFoundException`); only DataAccess returns `null` (for Cosmos 404) |
| `catch (Exception ex)` without rethrowing | Every catch either wraps into a domain exception or rethrows — silent swallowing is always a bug |
| `IConfiguration` in services or handlers | Replaced by `IOptions<T>` with startup validation |
| Business logic in `BackgroundService` | Background jobs delegate to handlers — the handler layer owns all business rules |
