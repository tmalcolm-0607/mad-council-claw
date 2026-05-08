---
paths:
  - "**/DataAccess/**/*.cs"
  - "**/Cosmos*/**/*.cs"
  - "**/spec.md"
---

# Cosmos DB Query Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Query optimization, pagination, and error handling for Azure Cosmos DB.

---

## Query Best Practices

### Always Include Partition Key

```csharp
// CORRECT: Query within single partition
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.pk = @pk AND c.status = @status")
    .WithParameter("@pk", partitionKey)
    .WithParameter("@status", "Active");

var options = new QueryRequestOptions
{
    PartitionKey = new PartitionKey(partitionKey),
    MaxItemCount = 100
};

// WRONG: Missing partition key - causes fan-out
var query = new QueryDefinition("SELECT * FROM c WHERE c.status = @status");
// No PartitionKey = cross-partition query (expensive!)
```

### Query Cost Comparison

| Query Type | RU Cost | Latency | When to Use |
|------------|---------|---------|-------------|
| Single partition | Low | Low | Default - always prefer |
| Cross-partition | High | High | Analytics, rare operations |
| Cross-partition + ORDER BY | Very High | Very High | Avoid in production |

### Use Parameterized Queries

```csharp
// CORRECT: Parameterized - safe and cacheable
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.pk = @pk AND c.createdAt > @startDate")
    .WithParameter("@pk", partitionKey)
    .WithParameter("@startDate", startDate);

// WRONG: String concatenation - SQL injection risk
var query = new QueryDefinition(
    $"SELECT * FROM c WHERE c.pk = '{partitionKey}'");  // NEVER!
```

### Project Specific Fields

```csharp
// CORRECT: Only needed fields - reduces RU cost
var query = new QueryDefinition(@"
    SELECT c.id, c.name, c.status
    FROM c WHERE c.pk = @pk");

// WRONG: SELECT * wastes bandwidth and RUs
var query = new QueryDefinition("SELECT * FROM c");
```

---

## Pagination with Continuation Tokens

```csharp
public async Task<PagedResult<T>> GetPagedAsync<T>(
    QueryDefinition query,
    string partitionKey,
    int pageSize,
    string? continuationToken = null,
    CancellationToken ct = default)
{
    var options = new QueryRequestOptions
    {
        PartitionKey = new PartitionKey(partitionKey),
        MaxItemCount = pageSize
    };

    var items = new List<T>();
    string? nextToken = null;

    using var iterator = this.container.GetItemQueryIterator<T>(
        query,
        continuationToken: continuationToken,
        requestOptions: options);

    if (iterator.HasMoreResults)
    {
        var response = await iterator.ReadNextAsync(ct);
        items.AddRange(response);
        nextToken = response.ContinuationToken;
    }

    return new PagedResult<T>
    {
        Items = items,
        ContinuationToken = nextToken,
        HasMoreResults = !string.IsNullOrEmpty(nextToken)
    };
}
```

---

## Repository Method Signatures

All repository query methods MUST return `PagedResult<T>`. Never return bare `List<T>` or `IEnumerable<T>` from queries  - this forces unbounded result sets and prevents pagination.

**Exception**: Single-item lookups return `T?`.

```csharp
// CORRECT: PagedResult<T> for all queries
public interface ICaseRepository
{
    Task<CaseEntity?> GetByIdAsync(string id, string pk, CancellationToken ct);
    Task<PagedResult<CaseEntity>> GetByCaseIdAsync(string caseId, int pageSize, string? continuationToken, CancellationToken ct);
    Task<PagedResult<CaseEntity>> SearchAsync(SearchCriteria criteria, int pageSize, string? continuationToken, CancellationToken ct);
}

// WRONG: Bare collections  - no pagination, unbounded results
public interface ICaseRepository
{
    Task<List<CaseEntity>> GetByCaseIdAsync(string caseId);
    Task<IEnumerable<CaseEntity>> SearchAsync(SearchCriteria criteria);
}
```

| Pattern | Status |
|---------|--------|
| Repository query returning `List<T>` or `IEnumerable<T>` | **REJECT** |
| Query method without `pageSize` + `continuationToken` parameters | **WARN** |

---

## Collection Envelope Pattern

For hybrid embedded+referenced collections with pagination:

```json
{
  "items": {
    "mode": "summary",
    "includedCount": 25,
    "totalCount": 312,
    "hasMore": true,
    "next": { "href": "/api/cases/{id}/dfts?after=...", "cursor": "..." },
    "items": { "id-1": { /* summary */ }, "id-2": { /* summary */ } }
  }
}
```

```csharp
public sealed class CollectionEnvelope<T>
{
    [JsonPropertyName("mode")]
    public string Mode { get; init; } = "summary";

    [JsonPropertyName("includedCount")]
    public int IncludedCount { get; init; }

    [JsonPropertyName("hasMore")]
    public bool HasMore { get; init; }

    [JsonPropertyName("items")]
    public IReadOnlyDictionary<string, T> Items { get; init; } = new();
}
```

---

## Error Handling

```csharp
public async Task<T?> GetItemAsync<T>(string id, string pk, CancellationToken ct)
{
    try
    {
        var response = await this.container.ReadItemAsync<T>(
            id, new PartitionKey(pk), cancellationToken: ct);
        return response.Resource;
    }
    catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
    {
        return null;  // Expected - item not found
    }
    catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
    {
        this.logger.LogWarning("Rate limited. RetryAfter: {RetryAfter}", ex.RetryAfter);
        throw;
    }
    catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
    {
        throw new ConcurrencyException($"Item {id} modified concurrently", ex);
    }
}
```

### Optimistic Concurrency with ETags

```csharp
public async Task<T> UpdateItemAsync<T>(T item, string id, string pk, string etag, CancellationToken ct)
{
    var options = new ItemRequestOptions { IfMatchEtag = etag };

    try
    {
        var response = await this.container.ReplaceItemAsync(
            item, id, new PartitionKey(pk), options, ct);
        return response.Resource;
    }
    catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
    {
        throw new ConcurrencyException("Refresh and retry.", ex);
    }
}
```

---

## Document Type Constants Enforcement

All Cosmos queries that filter by document type MUST use centralized `DocumentTypes` constants. Never use magic strings.

```csharp
// CORRECT: Use DocumentTypes constant
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.type = @type AND c.pk = @pk")
    .WithParameter("@type", DocumentTypes.Case)
    .WithParameter("@pk", partitionKey);

// WRONG: Magic string  - typo-prone, no compile-time safety
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.type = 'case' AND c.pk = @pk");
```

| Pattern | Status |
|---------|--------|
| Hardcoded document type string in WHERE clause | **REJECT** |
| Document type not defined in `DocumentTypes` | **REJECT** |

See `dotnet-cosmos-core.md` for the full `DocumentTypes` class definition.

---

## Pagination - Implementation Note

Check ecosystem reference repos under `references/` for existing pagination patterns before finalizing a new design. ContinuationToken from Cosmos SDK must NOT be exposed directly in API response DTOs. Use an opaque cursor (hashed or base64-encoded) to hide implementation details from API consumers.

| Pattern | Status |
|---------|--------|
| Raw Cosmos `ContinuationToken` in API response DTO | **REJECT** |
| Opaque cursor wrapping continuation token | **CORRECT** |

---

## PagedResult vs IAsyncEnumerable

`PagedResult<T>` and `IAsyncEnumerable<T>` serve different purposes. Do not conflate them.

| Return Type | Use Case | Caller Pattern |
|-------------|----------|----------------|
| `PagedResult<T>` | Caller-driven pagination (API endpoints) | Caller passes `pageSize` + `continuationToken` |
| `IAsyncEnumerable<T>` | Producer-driven streaming (internal batch jobs) | Caller consumes via `await foreach` |

Both are valid repository return types. `PagedResult<T>` is required for API-facing queries. `IAsyncEnumerable<T>` is appropriate for background processing of large result sets.

---

## Query Testability (Virtual Method Seam)

LINQ queries using `container.GetItemLinqQueryable<T>().Where().ToFeedIterator()` are **unmockable** because `ToFeedIterator()` is a static extension method. All repository query paths MUST use the virtual method seam pattern.

```csharp
// CORRECT: Virtual method seam  - testable
protected virtual FeedIterator<T> CreateQueryFeedIterator(
    Container container,
    Expression<Func<T, bool>> predicate,
    QueryRequestOptions requestOptions,
    string? continuationToken = null)
{
    return container.GetItemLinqQueryable<T>(
        continuationToken: continuationToken,
        requestOptions: requestOptions)
        .Where(predicate)
        .ToFeedIterator();
}

// Then call it:
var iterator = this.CreateQueryFeedIterator(container, predicate, options);

// WRONG: Inline LINQ  - cannot be mocked in unit tests
var iterator = container.GetItemLinqQueryable<T>(requestOptions: options)
    .Where(predicate)
    .ToFeedIterator();  // Static extension  - unmockable!
```

| Pattern | Status |
|---------|--------|
| Inline `ToFeedIterator()` in repository method body | **REJECT** |
| Inline `GetItemQueryIterator<T>()` without virtual wrapper | **REJECT** |
| Cross-entity query without its own virtual seam | **REJECT** |

For unit-test examples that mock the virtual seam, see `dotnet-testing.md` (Arrange-Act-Assert with mocked repository methods) — the seam pattern documented above is the contract those tests rely on.

---

## Server-Side Ordering and Pagination

**Source**: cross-repo PR review (Feb 2026).

**CRITICAL**: Always use Cosmos `ORDER BY` and `OFFSET/LIMIT` instead of client-side sorting and in-memory pagination. Client-side approaches miss data and waste RUs.

### ORDER BY Over Client-Side Sort

```csharp
// CORRECT: Server-side ordering -- returns correct results regardless of count
var query = new QueryDefinition(@"
    SELECT * FROM c
    WHERE c.pk = @pk AND c.type = @type
    ORDER BY c.timestamp DESC")
    .WithParameter("@pk", caseId)
    .WithParameter("@type", DocumentTypes.CaseEvent);

// WRONG: Fetch 2x buffer, sort in memory -- misses events when > 2*count exist
var query = new QueryDefinition(@"
    SELECT TOP @limit * FROM c
    WHERE c.pk = @pk AND c.type = @type")
    .WithParameter("@pk", caseId)
    .WithParameter("@limit", count * 2);  // Buffer can miss data!

var items = results.OrderByDescending(e => e.Timestamp).Take(count);  // Client-side sort
```

**Reviewer comment** (PR #4911473):
> "The count*2 fetch-then-sort approach can miss events if there are more than count*2 for a case. Add ORDER BY to the Cosmos query instead of sorting client-side."

### OFFSET/LIMIT Over In-Memory Pagination

```csharp
// CORRECT: Server-side pagination -- constant memory, pay only for needed RUs
var query = new QueryDefinition(@"
    SELECT * FROM c
    WHERE c.pk = @pk AND c.type = @type
    ORDER BY c.createdAt DESC
    OFFSET @offset LIMIT @limit")
    .WithParameter("@pk", partitionKey)
    .WithParameter("@type", DocumentTypes.Dft)
    .WithParameter("@offset", (page - 1) * pageSize)
    .WithParameter("@limit", pageSize);

// WRONG: Load all, map all, then paginate in memory -- memory spike + wasted RUs
var allDfts = await _repository.GetAllByPartitionKeyAsync(partitionKey, ct);
var page = allDfts
    .Select(d => _mapper.ToResponse(d))  // Maps ALL documents
    .Skip((page - 1) * pageSize)
    .Take(pageSize);  // Throws away most of the work
```

**Reviewer comment** (PR #4911479):
> "If a case somehow ended up with 500 DFTs, this loads them all into memory, maps them all, then throws away everything outside the page window."

### Indexing Requirement

`ORDER BY` requires a composite index on the ordered field. Add to your indexing policy:

```json
{
  "compositeIndexes": [
    [
      { "path": "/pk", "order": "ascending" },
      { "path": "/timestamp", "order": "descending" }
    ]
  ]
}
```

| Pattern | Status |
|---------|--------|
| Client-side sort after Cosmos query | **REJECT** (use `ORDER BY`) |
| Fetching N*multiplier rows as pagination buffer | **REJECT** (use `OFFSET/LIMIT` or continuation tokens) |
| Loading all documents then paginating in memory | **WARN** (use server-side pagination) |
| `ORDER BY` without matching composite index | **WARN** |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| SELECT * in queries | Project specific fields |
| Missing partition key | Always include partition key |
| String concatenation | Parameterized queries |
| Ignoring continuation tokens | Page through results |
| Not handling 429 | Configure retry policy |
| Magic strings for document types | Use `DocumentTypes` constants |
| Inline `ToFeedIterator()` | Virtual method seam for testability |
| Client-side sort after query | Use `ORDER BY` in Cosmos query |
| Fetch N*2 buffer and sort | Use `ORDER BY` + proper pagination |
| Load all documents, paginate in memory | Use `OFFSET/LIMIT` or continuation tokens |

---

## Cosmos SQL Injection Prevention

NEVER interpolate dictionary keys, field paths, or user-derived strings directly into Cosmos SQL queries. Even if current callers pass compile-time constants, the method signature accepts arbitrary strings.

Rules:
- Use a static `HashSet<string>` allowlist of valid field paths
- Validate all interpolated paths against the allowlist before SQL construction
- Throw `ArgumentException` for paths not in the allowlist
- Prefer strongly-typed enums or dedicated filter objects over `IReadOnlyDictionary<string, object>`

Anti-pattern: `sql += $" AND c.{path} = @sf{i}"` where `path` comes from dictionary keys.
