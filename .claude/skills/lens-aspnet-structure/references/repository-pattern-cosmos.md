# CosmosDB Repository Pattern Reference

> Two-tier CosmosDB DataAccess pattern used in LENS services. Tier 1 is the domain interface handlers inject; Tier 2 is the generic infrastructure layer beneath it.
> For outbound HTTP and SDK client patterns, see [repository-pattern-external.md](repository-pattern-external.md).

---

## Architecture

```
BusinessLogic Handler
  ↓ injects
I{Domain}Repository               — Tier 1: entity-typed; catches CosmosException → DataStoreException; Scoped
  ↓ injects
ICosmosDbResourceRepository       — Tier 2: generic CRUD; calls Cosmos SDK; lets CosmosException propagate; Singleton
  ↓ injects
ICosmosClientProvider             — lazy-initialises CosmosClient via DefaultAzureCredential; Singleton
  ↓
CosmosClient  →  Container
```

---

## Tier 2: Generic CosmosDB Repository

`ICosmosDbResourceRepository` handles raw Cosmos SDK operations. It is type-parameterized — no domain knowledge, no exception wrapping.

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

**Key rules:**
- Generic type parameter `<T>` on every method — no entity type awareness
- `CosmosException` propagates up; this tier does not catch it
- Registered as `Singleton` in DI — `CosmosClient` is thread-safe and expensive to construct

### Context Objects

```csharp
// ContainerContext — identifies which Cosmos container to target; built from configuration in the Tier 1 constructor
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
    public int? SoftDeleteTtlInSeconds { get; }  // null = hard delete; set = TTL applied when soft-deleting documents
}

// CosmosDbDataStoreSettings — configuration for a single container; defined in Common/Configuration/
public class CosmosDbDataStoreSettings
{
    [Required] public string CosmosDbDatabase { get; set; } = string.Empty;
    [Required] public string CosmosDbCollection { get; set; } = string.Empty;
    [Range(0, 365)] public int? SoftDeleteTtlInDays { get; set; }
}

// CosmosDbQuery — wraps a QueryDefinition for GetAllAsync
public sealed class CosmosDbQuery
{
    public static readonly CosmosDbQuery DefaultGetAll =
        new CosmosDbQuery(new QueryDefinition("SELECT * FROM c"), null);

    public CosmosDbQuery(QueryDefinition query, QueryRequestOptions queryOptions) { ... }
    public QueryDefinition Query { get; }
    public QueryRequestOptions QueryOptions { get; }
}
```

---

## Tier 1: Domain-Specific Repositories

Each domain entity has its own interface and `internal sealed` implementation. This tier:
- Holds the `ContainerContext` for its container(s)
- Exposes entity-typed methods (returns domain models, accepts domain parameters)
- Catches `CosmosException` and wraps it into `DataStoreException`
- 404 handling is contextual: point-read GET returns `null`; delete/update operations throw `DataStoreException(NotFound)`

```csharp
// DataAccess/Interfaces/IFooRepository.cs
// partitionId is a generic placeholder — name it after your entity's partition key (e.g. tenantId, customerId)
public interface IFooRepository
{
    Task<Foo?> GetFooAsync(Guid partitionId, Guid fooId);
    Task<List<Foo>> GetFoosAsync(Guid partitionId);
    Task<Foo> CreateFooAsync(Foo foo);  // entity carries its own partition key value
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
            return null; // 404 on point-read GET absorbed — handler checks for null
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

**Key rules:**
- `internal sealed` — the implementation is a detail; callers depend on the interface
- `CosmosException` is caught here and nowhere else in the call chain above
- 404 on a point-read GET → `null` — the handler checks for null and throws a typed `HandlerException` subclass (e.g. `FooNotFoundException`); 404 on a delete or update operation, or when accessing a logically soft-deleted document → throw `DataStoreException(HttpStatusCode.NotFound)`
- All other `CosmosException` → `DataStoreException` with `StatusCode` and `RetryAfter` preserved
- Registered as `Scoped` in DI (matches handler lifetime)

---

## Query Builder: `ICosmosDbQueryBuilder<TFilter>`

Cross-partition queries require a `QueryDefinition` — rather than constructing SQL inline inside the repository, LENS services inject a dedicated query builder. This separates SQL construction from data retrieval and makes the query independently testable.

```csharp
// DataAccess/Interfaces/ICosmosDbQueryBuilder.cs
public interface ICosmosDbQueryBuilder<TFilter>
{
    CosmosDbQuery BuildQuery(TFilter filter);
}

// DataAccess/CosmosDB/FooCosmosDbQueryBuilder.cs
// Replace partitionId / @partitionId with your entity's actual partition key field name
internal sealed class FooCosmosDbQueryBuilder : ICosmosDbQueryBuilder<FooFilter>
{
    public CosmosDbQuery BuildQuery(FooFilter filter)
    {
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.partitionId = @partitionId AND c.isDeleted = false")
            .WithParameter("@partitionId", filter.PartitionId.ToString());

        return new CosmosDbQuery(query, new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(filter.PartitionId.ToString())
        });
    }
}

// Filter type — a lightweight value object carrying query parameters
public sealed class FooFilter
{
    public Guid PartitionId { get; init; }  // the entity's partition key value — rename to match your schema
    // add additional filter fields as needed
}
```

The repository injects `ICosmosDbQueryBuilder<FooFilter>` and calls `BuildQuery` before passing the result to `GetAllAsync`:

```csharp
internal sealed class FooRepository : IFooRepository
{
    private readonly ContainerContext containerContext;
    private readonly ICosmosDbResourceRepository repository;
    private readonly ICosmosDbQueryBuilder<FooFilter> queryBuilder;

    public FooRepository(
        ICosmosDbResourceRepository repository,
        IOptions<CosmosDbSettingsOptions> cosmosDbOptions,
        ICosmosDbQueryBuilder<FooFilter> queryBuilder)
    {
        ParameterContracts.CheckIsNotNull(repository, nameof(repository));
        ParameterContracts.CheckIsNotNull(cosmosDbOptions, nameof(cosmosDbOptions));
        ParameterContracts.CheckIsNotNull(queryBuilder, nameof(queryBuilder));
        this.cosmosRepository = cosmosRepository;
        this.containerContext = new ContainerContext(
            cosmosDbOptions.Value.DataStoreSettings.FoosDataStoreSettings);
        this.queryBuilder = queryBuilder;
    }

    public async Task<List<Foo>> GetFoosAsync(Guid partitionId)
    {
        var query = this.queryBuilder.BuildQuery(new FooFilter { PartitionId = partitionId });
        try
        {
            var results = await this.repository.GetAllAsync<Foo>(this.containerContext, query);
            return [.. results];
        }
        catch (CosmosException ex)
        {
            throw new DataStoreException("Cosmos DB exception", ex, ex.StatusCode, ex.RetryAfter);
        }
    }
}
```

**Key rules:**
- One query builder per entity type — `ICosmosDbQueryBuilder<TFilter>` is generic on the filter, not the entity
- Query builders are `Singleton` in DI — they are stateless and have no dependencies
- SQL parameters use `WithParameter` — never string interpolation (prevents injection)
- The filter type is a plain sealed class or record — no business logic

---

## DataStoreException

Defined in `Common/Exceptions/`. Carries the HTTP status code and retry-after interval from the underlying `CosmosException` so that handlers can preserve them when wrapping into `HandlerException`.

```csharp
// Common/Exceptions/DataStoreException.cs
public class DataStoreException(
    string message,
    Exception? innerException,
    HttpStatusCode? statusCode = null,
    TimeSpan? retryAfter = null) : Exception(message, innerException)
{
    public HttpStatusCode? StatusCode { get; } = statusCode;
    public TimeSpan? RetryAfter { get; } = retryAfter;
}
```

---

## DI Registration

```csharp
// CosmosDB Tier 2 — Singleton: CosmosClient is thread-safe and expensive to initialise
services.AddSingleton<ICosmosClientProvider, CosmosClientProvider>();
services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();

// Query builders — Singleton: stateless, no dependencies
services.AddSingleton<ICosmosDbQueryBuilder<FooFilter>, FooCosmosDbQueryBuilder>();
services.AddSingleton<ICosmosDbQueryBuilder<BarFilter>, BarCosmosDbQueryBuilder>();

// CosmosDB Tier 1 — Scoped: matches handler lifetime; this is what handlers inject
services.AddScoped<IFooRepository, FooRepository>();
services.AddScoped<IBazRepository, BazRepository>();
```

---

## Naming Conventions

| Component | Interface name | Implementation name |
|-----------|---------------|---------------------|
| Generic Cosmos repo | `ICosmosDbResourceRepository` | `CosmosDbResourceRepository` |
| Cosmos client provider | `ICosmosClientProvider` | `CosmosClientProvider` |
| Domain repository | `I{Domain}Repository` | `{Domain}Repository` |
| Query builder | `ICosmosDbQueryBuilder<TFilter>` | `{Entity}CosmosDbQueryBuilder` |
