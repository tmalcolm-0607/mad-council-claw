---
paths:
  - "**/DataAccess/**/*.cs"
  - "**/*Repository.cs"
  - "**/*RepositoryTests.cs"
  - "**/spec.md"
  - "**/plan.md"
---

# Two-Tier DataAccess Pattern

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

The canonical LENS DataAccess pattern is **two-tier** for every backing technology — CosmosDB, outbound HTTP, and SDK clients (Graph, ARM, Key Vault). Tier 1 is the domain-typed interface that handlers inject; Tier 2 is the generic infrastructure layer beneath it. The split exists because the underlying client (CosmosClient, GraphServiceClient, ARM client) is expensive to initialise and must be Singleton — but the domain repository must be Scoped to match handler lifetime.

> **Authoritative source:** `.claude/skills/lens-aspnet-structure/references/repository-pattern-cosmos.md` and `references/repository-pattern-external.md`.

---

## 1. Overview

```
BusinessLogic Handler
  │ injects
  ▼
I{Domain}Repository               ← Tier 1: entity-typed; Scoped
  │ • returns local Common domain types
  │ • catches infra exceptions and wraps into DataStoreException / ExternalServiceCallException
  │ injects
  ▼
ICosmosDbResourceRepository       ← Tier 2: generic CRUD; Singleton
IHttpClientFactory                ← Tier 2: framework-provided
I{Service}ClientProvider          ← Tier 2: SDK client; Singleton
```

**Why two tiers:**
- Tier 2 wraps an expensive-to-initialise client. Initialising it per request is wasted work. Singleton.
- Tier 1 holds entity-typed methods, container/endpoint context, and exception-wrapping. It must match handler lifetime. Scoped.
- The handler depends on `I{Domain}Repository` only — the existence of Tier 2 is invisible above DataAccess.

**Layer placement:**
- Tier 1 interface → `DataAccess/Interfaces/` (handlers reference DataAccess directly; canonical per `references/repository-pattern-cosmos.md:29` and `references/layer-responsibilities.md:39-46`)
- Tier 1 implementation → `DataAccess/CosmosDB/` or `DataAccess/ExternalServices/`
- Tier 2 interface → `DataAccess/Interfaces/` (Tier 1 references it within DataAccess)
- Tier 2 implementation → `DataAccess/CosmosDB/` (or equivalent provider folder)

> **Why DataAccess/Interfaces/ (not Common/Interfaces/)**: two reasons, applied at different tiers.
>
> - **Tier 2 (strongest reason)**: Tier 2 interfaces expose Cosmos SDK types directly — `PartitionKey`, `ItemRequestOptions`, `ItemResponse<T>`. Putting a Tier 2 interface in `Common` would force `Common.csproj` to reference the Cosmos SDK, which violates `lens-aspnet-structure` Standard 5 (Common stays infrastructure-free).
> - **Tier 1 (canonical-ownership reason)**: Tier 1 domain interfaces SHOULD NOT expose SDK types — they take/return domain entities and primitives. So the SDK-leak argument doesn't apply directly. They still belong in `DataAccess/Interfaces/` because repository interfaces canonically live with the technology that implements them; the canonical layer-responsibility model puts data-access contracts under DataAccess regardless of whether they happen to leak SDK types (`references/layer-responsibilities.md:39-46`).

---

## 2. Tier 1: `I{Domain}Repository` (CosmosDB)

The domain repository is the only DataAccess type the handler sees. It is **`internal sealed`**, registered **Scoped**, and the **only place that catches `CosmosException`**. 404 handling is contextual: point-read GET returns `null`; delete/update operations throw `DataStoreException(NotFound)`.

```csharp
// DataAccess/Interfaces/IFooRepository.cs
// partitionId is a generic placeholder — name it after your entity's actual partition key (e.g. tenantId, customerId)
public interface IFooRepository
{
    Task<Foo?> GetFooAsync(Guid partitionId, Guid fooId);
    Task<List<Foo>> GetFoosAsync(Guid partitionId);
    Task<Foo> CreateFooAsync(Foo foo);
    Task<Foo> UpdateFooAsync(Guid partitionId, Guid fooId, Foo foo);
}

// DataAccess/CosmosDB/FooRepository.cs
internal sealed class FooRepository : IFooRepository
{
    private readonly ContainerContext containerContext;
    private readonly ICosmosDbResourceRepository cosmosRepository;

    public FooRepository(
        ICosmosDbResourceRepository cosmosRepository,
        IOptions<CosmosDbSettingsOptions> cosmosDbOptions)
    {
        ParameterContracts.CheckIsNotNull(cosmosRepository, nameof(cosmosRepository));
        ParameterContracts.CheckIsNotNull(cosmosDbOptions, nameof(cosmosDbOptions));
        this.cosmosRepository = cosmosRepository;
        this.containerContext = new ContainerContext(
            cosmosDbOptions.Value.DataStoreSettings.FoosDataStoreSettings);
    }

    public async Task<Foo?> GetFooAsync(Guid partitionId, Guid fooId)
    {
        try
        {
            return await this.cosmosRepository.GetByIdAsync<Foo>(
                this.containerContext,
                fooId.ToString(),
                new PartitionKey(partitionId.ToString()));
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return null;  // 404 on point-read GET absorbed — handler checks for null
        }
        catch (CosmosException ex)
        {
            throw new DataStoreException("Cosmos DB exception", ex, ex.StatusCode, ex.RetryAfter);
        }
    }

    public async Task<Foo> CreateFooAsync(Foo foo)
    {
        try
        {
            return await this.cosmosRepository.CreateAsync(this.containerContext, foo);
        }
        catch (CosmosException ex)
        {
            throw new DataStoreException("Cosmos DB exception", ex, ex.StatusCode, ex.RetryAfter);
        }
    }
}
```

**Tier 1 rules:**
- `internal sealed` — implementation is a detail; callers depend on the interface
- Interface uses only local Common domain types — never SDK types, never `Microsoft.LENS.Common.DataModels` types
- Catches `CosmosException` and wraps into `DataStoreException` (preserving `StatusCode` and `RetryAfter`)
- 404 on point-read GET → `null`; the handler decides whether `null` means "not found" and throws a typed `HandlerException`
- 404 on delete or update → `DataStoreException(HttpStatusCode.NotFound)` (the operation expected the document to exist)
- Registered **Scoped** in DI (matches handler lifetime)

---

## 3. Tier 2: `ICosmosDbResourceRepository` (Generic CRUD)

The generic CRUD layer is a thin, type-parameterised wrapper over the Cosmos SDK. It has **no domain knowledge** and **does not catch `CosmosException`** — Tier 1 above wraps it.

```csharp
// DataAccess/Interfaces/ICosmosDbResourceRepository.cs
public interface ICosmosDbResourceRepository
{
    Task<T> CreateAsync<T>(ContainerContext containerContext, T document, ItemRequestOptions requestOptions = null);
    Task<T> GetByIdAsync<T>(ContainerContext containerContext, string documentId, PartitionKey partitionKey, ItemRequestOptions requestOptions = null);
    Task<T[]> GetAllAsync<T>(ContainerContext containerContext, CosmosDbQuery query = null);
    Task<T> ReplaceItemAsync<T>(ContainerContext containerContext, string documentId, T document, ItemRequestOptions requestOptions = null);
    Task<T> DeleteAsync<T>(ContainerContext containerContext, string documentId, PartitionKey partitionKey, ItemRequestOptions requestOptions = null);
    Task ExecuteTransactionalBatchAsync(ContainerContext containerContext, PartitionKey partitionKey, Action<TransactionalBatch> batchBuilder);
}
```

**Tier 2 rules:**
- Generic on `<T>` — no entity awareness
- Lets `CosmosException` propagate (Tier 1 wraps)
- Registered **Singleton** in DI — `CosmosClient` is thread-safe and expensive to construct

---

## 4. `ICosmosClientProvider` (Lazy SDK Client)

Owns lazy construction of the `CosmosClient` (typically via `DefaultAzureCredential`). Singleton.

```csharp
public interface ICosmosClientProvider
{
    Task<CosmosClient> GetCosmosClientAsync();
}
```

---

## 5. `ContainerContext` / `CosmosDbQuery` / `ICosmosDbQueryBuilder<TFilter>`

```csharp
// ContainerContext — built from configuration in the Tier 1 constructor; identifies which Cosmos container to target.
// Note: SoftDeleteTtlInSeconds is shown here for soft-deletable entities/containers. If your entity does not use
// soft delete (per `_dotnet/dotnet-cosmos-core.md` Soft Delete Pattern — project policy, not LENS-canonical),
// drop the SoftDeleteTtl* members from your ContainerContext.
public class ContainerContext
{
    public ContainerContext(CosmosDbDataStoreSettings settings)
    {
        this.DatabaseName = settings.CosmosDbDatabase;
        this.ContainerName = settings.CosmosDbCollection;
        this.SoftDeleteTtlInSeconds = settings.SoftDeleteTtlInDays.HasValue
            ? settings.SoftDeleteTtlInDays.Value * 86400
            : null;
    }

    public string DatabaseName { get; }
    public string ContainerName { get; }
    public int? SoftDeleteTtlInSeconds { get; }
}

// CosmosDbQuery — wraps QueryDefinition for GetAllAsync
public sealed class CosmosDbQuery
{
    public static readonly CosmosDbQuery DefaultGetAll =
        new CosmosDbQuery(new QueryDefinition("SELECT * FROM c"), null);
    public CosmosDbQuery(QueryDefinition query, QueryRequestOptions queryOptions) { ... }
    public QueryDefinition Query { get; }
    public QueryRequestOptions QueryOptions { get; }
}

// ICosmosDbQueryBuilder<TFilter> — separates SQL construction from data retrieval
public interface ICosmosDbQueryBuilder<TFilter>
{
    CosmosDbQuery BuildQuery(TFilter filter);
}

// One query builder per entity type; injected into Tier 1; Singleton (stateless)
// Note: the `c.isDeleted != true` clause assumes the entity uses soft delete. For containers without soft delete,
// drop the clause entirely. The `!= true` form (rather than `= false`) tolerates documents written before the
// `isDeleted` field existed (where `c.isDeleted` is undefined) — Cosmos treats undefined as not-equal-to-true,
// so older documents are still returned. The `= false` form silently drops them.
internal sealed class FooCosmosDbQueryBuilder : ICosmosDbQueryBuilder<FooFilter>
{
    public CosmosDbQuery BuildQuery(FooFilter filter)
    {
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.partitionId = @partitionId AND c.isDeleted != true")
            .WithParameter("@partitionId", filter.PartitionId.ToString());

        return new CosmosDbQuery(query, new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(filter.PartitionId.ToString())
        });
    }
}
```

**Query builder rules:**
- One builder per entity type — generic on the **filter**, not the entity
- SQL parameters use `WithParameter` — never string interpolation (prevents injection)
- Registered **Singleton** in DI (stateless, no dependencies)
- Filter type is a plain `sealed class` or record — no business logic

---

## 6. Outbound `IBarRepository` (HTTP-backed external services)

The same two-tier principle applies to outbound LENS service calls. The Tier 1 interface speaks exclusively in **local Common domain types**; `Microsoft.LENS.Common.DataModels` types are an implementation detail of the concrete class and must not appear in the interface.

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
        // local domain → DataModels — stays inside this implementation
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
            // Broad catch at outbound boundary: TaskCanceledException, sockets, SDK exceptions
            // are all wrapped into a single safe exception type.
            throw new ExternalServiceCallException("Bar service call failed.", ex);
        }
    }
}
```

**Outbound HTTP rules:**
- Inject `IHttpClientFactory` — never inject `HttpClient` directly (avoids socket exhaustion + stale DNS)
- DataModels mapping (local → DataModels for request, DataModels → local for response) lives entirely inside the concrete implementation
- `catch (Exception ex)` at this boundary — outbound calls throw beyond `HttpRequestException` (`TaskCanceledException`, socket errors, SDK exceptions)
- Wrap into `ExternalServiceCallException` (extends `SanitizedMessageException`) — message must be a safe, generic string (never the raw inner message)
- Registered **Scoped** in DI

---

## 7. `IGraphClientProvider` (SDK two-tier extension)

For SDK clients that are expensive to initialise (Microsoft Graph, Azure ARM, Key Vault), apply the same two-tier split as CosmosDB:

- **`I{Service}ClientProvider` / `{Service}ClientProvider`** — Singleton; wraps SDK client construction and lazy initialisation. Analogous to `ICosmosClientProvider`.
- **`I{Service}Repository` / `{Service}Repository`** — Scoped; injects the provider, calls the SDK, maps to local domain types, handles exceptions.

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

Service-specific exception types (e.g. `OrganizationRetrievalException`) extend `SanitizedMessageException` — the constructor takes an explicitly safe message string, never the raw SDK exception message. Define one per external service where callers need to distinguish failure source.

---

## 8. Layer Placement Summary

| Type | Tier | Project | Folder |
|------|------|---------|--------|
| `I{Domain}Repository` | 1 | `DataAccess` | `Interfaces/` |
| `{Domain}Repository` | 1 | `DataAccess` | `CosmosDB/` or `ExternalServices/` |
| `ICosmosDbResourceRepository` | 2 | `DataAccess` | `Interfaces/` |
| `CosmosDbResourceRepository` | 2 | `DataAccess` | `CosmosDB/` |
| `ICosmosClientProvider` | 2 | `DataAccess` | `Interfaces/` |
| `CosmosClientProvider` | 2 | `DataAccess` | `CosmosDB/` |
| `ICosmosDbQueryBuilder<TFilter>` | helper | `DataAccess` | `Interfaces/` |
| `{Entity}CosmosDbQueryBuilder` | helper | `DataAccess` | `CosmosDB/` |
| `IGraphClientProvider` | 2 | `DataAccess` | `Interfaces/` |
| `GraphClientProvider` | 2 | `DataAccess` | `ExternalServices/` |
| `IBarRepository` (outbound HTTP) | 1 | `DataAccess` | `Interfaces/` |
| `BarRepository` (outbound HTTP) | 1 | `DataAccess` | `ExternalServices/` |

---

## 9. DI Registration

```csharp
// Tier 2 — Singleton (expensive client; thread-safe)
services.AddSingleton<ICosmosClientProvider, CosmosClientProvider>();
services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();

// Query builders — Singleton (stateless)
services.AddSingleton<ICosmosDbQueryBuilder<FooFilter>, FooCosmosDbQueryBuilder>();

// Tier 1 (CosmosDB-backed) — Scoped (matches handler lifetime)
services.AddScoped<IFooRepository, FooRepository>();

// Outbound HTTP — Scoped; AddHttpClient registers IHttpClientFactory
services.AddHttpClient();
services.AddScoped<IBarRepository, BarRepository>();

// SDK client provider — Singleton
services.AddSingleton<IGraphClientProvider, GraphClientProvider>();
// SDK Tier 1 — Scoped
services.AddScoped<IOrganizationRepository, OrganizationRepository>();
```

---

## 10. Anti-Patterns

| Anti-Pattern | Symptom | Correct Fix |
|--------------|---------|-------------|
| Single-tier `IFooRepository` calling `_container.ReadItemAsync(...)` directly | Domain repository constructs / holds `Container` itself; no Tier 2 abstraction | Inject `ICosmosDbResourceRepository`; let Tier 2 own the SDK call |
| `CosmosException` reaching the handler | Handler catches `CosmosException` (or, worse, `Exception`) | Tier 1 catches `CosmosException` and wraps into `DataStoreException` |
| `Microsoft.LENS.Common.DataModels` types in `IBarRepository` interface | Outbound DataModels leaking out of the implementation | Interface uses local Common types only; mapping lives inside the implementation body |
| Tier 1 registered as Singleton | `services.AddSingleton<IFooRepository, FooRepository>()` | Tier 1 is **Scoped** (matches handler) |
| Tier 2 registered as Scoped | `services.AddScoped<ICosmosDbResourceRepository, CosmosDbResourceRepository>()` | Tier 2 is **Singleton** (CosmosClient is thread-safe + expensive) |
| 404 on point-read GET throwing `DataStoreException(NotFound)` | Handler can't distinguish "entity does not exist" from a genuine error | Point-read GET 404 → return `null`; handler throws a typed `HandlerException` |
| 404 on delete/update returning `null` | Caller expected the document to exist; silent absorption hides the problem | Delete/update 404 → throw `DataStoreException(HttpStatusCode.NotFound)` |
| SQL string interpolation in query builder | `$"SELECT * FROM c WHERE c.id = '{id}'"` | Use `QueryDefinition.WithParameter("@id", id)` — prevents injection |
