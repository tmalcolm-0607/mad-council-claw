# External Service Repository Pattern Reference

> Outbound HTTP and SDK client patterns used in LENS DataAccess. Covers LENS-to-LENS service calls and expensive SDK clients (Graph, ARM, Key Vault).
> For CosmosDB two-tier repository pattern, see [repository-pattern-cosmos.md](repository-pattern-cosmos.md).

---

## Outbound HTTP: LENS Service Calls

Outbound calls to other LENS services follow the same two-tier principle as CosmosDB: the **interface** (`I{ServiceName}Repository`) speaks exclusively in local Common domain types; `Microsoft.LENS.Common.DataModels` types are an implementation detail of the concrete class and must not appear in the interface.

This means a breaking change to an upstream DataModels contract requires a change only to the repository implementation — the handler and the interface are unaffected.

```csharp
// DataAccess/Interfaces/IBarRepository.cs
// ✅ Interface uses local Common domain types only — no DataModels types
public interface IBarRepository
{
    Task<BarResult?> GetBarAsync(Guid barId, CancellationToken ct);
    Task<BarResult> PostBarAsync(BarRequest request, CancellationToken ct);
}

// DataAccess/ExternalServices/BarRepository.cs
// ✅ DataModels mapping is confined to the implementation body
internal sealed class BarRepository : IBarRepository
{
    private readonly IHttpClientFactory httpClientFactory;

    public BarRepository(IHttpClientFactory httpClientFactory)
    {
        ParameterContracts.CheckIsNotNull(httpClientFactory, nameof(httpClientFactory));
        this.httpClientFactory = httpClientFactory;
    }

    public async Task<BarResult> PostBarAsync(BarRequest request, CancellationToken ct)
    {
        // Map local domain type → DataModels request — stays inside this implementation
        var dataModelsRequest = new DataPipelineRequest<BarData>
        {
            TenantId = request.TenantId,
            Payload = new BarData { /* ... */ }
        };

        try
        {
            using var client = this.httpClientFactory.CreateClient();
            var response = await client.PostAsJsonAsync("/api/bar", dataModelsRequest, ct);
            response.EnsureSuccessStatusCode();
            var dataModelsResponse = await response.Content
                .ReadFromJsonAsync<DataPipelineResponse<BarData>>(cancellationToken: ct);

            return MapToBarResult(dataModelsResponse);
        }
        catch (Exception ex)
        {
            // Broad catch: outbound calls throw beyond HttpRequestException (TaskCanceledException,
            // socket errors, SDK exceptions). All wrapped into a single safe exception type.
            throw new ExternalServiceCallException("Bar service call failed.", ex);
        }
    }
}
```

**Key rules:**
- The interface (`IBarRepository`) uses only local Common domain types — no `DataPipelineRequest<T>`, no `DataPipelineResponse`
- DataModels mapping (local → DataModels for the request, DataModels → local for the response) lives entirely inside the concrete implementation
- Inject `IHttpClientFactory` and call `CreateClient()` per request — never inject `HttpClient` directly (avoids socket exhaustion and stale DNS)
- `catch (Exception ex)` at this boundary — outbound calls can throw beyond `HttpRequestException`; wrap everything into `ExternalServiceCallException`
- The message passed to `ExternalServiceCallException` must be a safe, generic string — never forward the raw exception message to callers
- Registered as `Scoped` in DI
- For services that require retry, register `AddStandardResilienceHandler()` on the named `HttpClient` in the DI extension — see `_dotnet/dotnet-resilience.md` for the canonical wiring (LENS-DCS reference). Retry only on transient failures (503, network errors, 408 RequestTimeout, 429 TooManyRequests for Graph + LENS partners); never on 4xx other than 408/429.

`ExternalServiceCallException` (from `Common/Exceptions/`) extends `SanitizedMessageException` — its message is safe to surface to callers if the exception reaches middleware. It carries the HTTP status code extracted from the inner exception chain.

---

## SDK Client Providers

For SDK clients that are expensive to initialise (Microsoft Graph, Azure ARM, Key Vault), apply the same two-tier split used for CosmosDB:

- **`I{Service}ClientProvider` / `{Service}ClientProvider`** — Singleton; wraps SDK client construction and lazy initialisation. Analogous to `ICosmosClientProvider`.
- **`I{Service}Repository` / `{Service}Repository`** — Scoped; injects the provider, calls the SDK, maps the response to local domain types, handles exceptions.

```csharp
// DataAccess/Interfaces/IGraphClientProvider.cs
public interface IGraphClientProvider
{
    Task<GraphServiceClient> GetGraphServiceClientAsync();
}

// DataAccess/Interfaces/IOrganizationRepository.cs
public interface IOrganizationRepository
{
    Task<OrgInfo?> GetOrganizationInfoAsync(string orgId, CancellationToken ct);
}

// DataAccess/ExternalServices/OrganizationRepository.cs
internal sealed class OrganizationRepository : IOrganizationRepository
{
    private readonly IGraphClientProvider graphClientProvider;

    public OrganizationRepository(IGraphClientProvider graphClientProvider)
    {
        ParameterContracts.CheckIsNotNull(graphClientProvider, nameof(graphClientProvider));
        this.graphClientProvider = graphClientProvider;
    }

    public async Task<OrgInfo?> GetOrganizationInfoAsync(string orgId, CancellationToken ct)
    {
        try
        {
            var client = await this.graphClientProvider.GetGraphServiceClientAsync();
            var org = await client.Organizations[orgId].GetAsync(cancellationToken: ct);
            return org is null ? null : MapToOrgInfo(org);
        }
        catch (Exception ex)
        {
            throw new OrganizationRetrievalException("Organization lookup failed.", ex);
        }
    }
}
```

Service-specific exception types (e.g. `OrganizationRetrievalException`) extend `SanitizedMessageException` — the constructor takes an explicitly safe message string, never the raw SDK exception message. Define one per external service where callers need to distinguish the failure source.

---

## DI Registration

```csharp
// HTTP service repos — Scoped; AddHttpClient() registers IHttpClientFactory
services.AddHttpClient();
services.AddScoped<IBarRepository, BarRepository>();

// SDK client providers — Singleton: expensive SDK client; manages lazy initialisation
services.AddSingleton<IGraphClientProvider, GraphClientProvider>();
// SDK service repos — Scoped: inject the Singleton provider, stays request-scoped
services.AddScoped<IOrganizationRepository, OrganizationRepository>();
```

---

## Naming Conventions

| Component | Interface name | Implementation name |
|-----------|---------------|---------------------|
| HTTP service repo | `I{ServiceName}Repository` | `{ServiceName}Repository` |
| SDK client provider | `I{Service}ClientProvider` | `{Service}ClientProvider` |
| SDK service repo | `I{Service}Repository` | `{Service}Repository` |
