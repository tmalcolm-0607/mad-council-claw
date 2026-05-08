---
paths:
  - "**/DataAccess/**/*.cs"
  - "**/Cosmos*/**/*.cs"
  - "**/spec.md"
---

# Cosmos DB Advanced Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Batching, change feed, indexing, and hierarchical partition keys.

---

## TransactionalBatch

Atomic operations within a single partition:

```csharp
public async Task<bool> CreateOrderWithItemsAsync(
    Order order, IEnumerable<OrderItem> items, CancellationToken ct)
{
    var batch = this.container.CreateTransactionalBatch(
        new PartitionKey(order.PartitionKey));

    batch.CreateItem(order);
    foreach (var item in items)
    {
        batch.CreateItem(item);
    }

    using var response = await batch.ExecuteAsync(ct);

    if (!response.IsSuccessStatusCode)
    {
        this.logger.LogError("Batch failed. StatusCode: {StatusCode}", response.StatusCode);
        return false;
    }
    return true;
}
```

### Batch Limits

| Limit | Value |
|-------|-------|
| Operations per batch | 100 |
| Total batch size | 2 MB |
| Individual item | 2 MB |

```csharp
// Chunk large batches
const int batchSize = 100;
var groups = items
    .GroupBy(partitionKeySelector)
    .SelectMany(g => g.Chunk(batchSize).Select(chunk => (g.Key, chunk)));

foreach (var (pk, chunk) in groups)
{
    var batch = this.container.CreateTransactionalBatch(new PartitionKey(pk));
    foreach (var item in chunk) batch.CreateItem(item);
    await batch.ExecuteAsync(ct);
}
```

---

## Bulk Execution

For high-throughput ingestion:

```csharp
var options = new CosmosClientOptions
{
    AllowBulkExecution = true,
    MaxRetryAttemptsOnRateLimitedRequests = 9,
    MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(30)
};

var client = new CosmosClient(connectionString, options);

// Bulk upsert
var tasks = items.Select(item =>
    this.container.UpsertItemAsync(item, new PartitionKey(item.GetPartitionKey()), ct));
await Task.WhenAll(tasks);
```

---

## Change Feed Processor

Reliable, scalable change processing:

```csharp
public class ChangeFeedService : IHostedService
{
    private ChangeFeedProcessor? processor;

    public async Task StartAsync(CancellationToken ct)
    {
        this.processor = this.monitoredContainer
            .GetChangeFeedProcessorBuilder<Order>("OrderProcessor", HandleChangesAsync)
            .WithInstanceName(Environment.MachineName)
            .WithLeaseContainer(this.leaseContainer)
            .WithStartTime(DateTime.UtcNow.AddHours(-1))
            .WithMaxItems(100)
            .WithPollInterval(TimeSpan.FromSeconds(5))
            .Build();

        await this.processor.StartAsync();
    }

    private async Task HandleChangesAsync(
        ChangeFeedProcessorContext context,
        IReadOnlyCollection<Order> changes,
        CancellationToken ct)
    {
        foreach (var order in changes)
        {
            // Handle idempotency (at-least-once delivery)
            var existing = await this.processedRepo.GetAsync(order.Id, ct);
            if (existing?.Version >= order.Version) continue;

            await ProcessOrderAsync(order, ct);
            await this.processedRepo.UpsertAsync(new ProcessedEvent
            {
                Id = order.Id, Version = order.Version
            }, ct);
        }
    }
}
```

### Change Feed Guarantees

| Guarantee | Description |
|-----------|-------------|
| At-least-once | May be delivered multiple times |
| Ordered within partition | Within logical partition only |
| No cross-partition ordering | Different partitions = no order |

---

## Dual-Write with Embedded Summaries

For read-heavy scenarios, maintain authoritative data in a dedicated container and an embedded summary in a parent document.

### Pattern

```csharp
// Authoritative: Full note in Notes container (partition key: caseId)
var fullNote = new NoteEntity { Id = noteId, CaseId = caseId, Body = "..." };
await this.notesContainer.CreateItemAsync(fullNote, new PartitionKey(caseId), cancellationToken: ct);

// Summary: Last N notes embedded in Case document (Cases container)
var patchOps = new List<PatchOperation>
{
    PatchOperation.Add("/recentNotes/-", new NoteSummary
    {
        NoteId = noteId,
        Preview = body.Substring(0, Math.Min(100, body.Length)),
        CreatedAt = DateTimeOffset.UtcNow
    })
};

// ETag protection on the parent document
var options = new PatchItemRequestOptions { IfMatchEtag = caseEtag };
await this.casesContainer.PatchItemAsync<CaseEntity>(
    caseId, new PartitionKey(caseId), patchOps, options, ct);
```

### Consistency Model

| Approach | Consistency | Complexity |
|----------|-------------|------------|
| Synchronous dual-write | Strong (within request) | Medium - must handle partial failure |
| Change Feed projection | Eventual | Low - decoupled, idempotent |

**Rule**: Use ETag protection on both containers. If the embedded summary write fails, the authoritative write should still succeed - the Change Feed can reconcile later.

---

## Hierarchical Partition Keys

**SDK v3.33.0+**: For multi-tenant scenarios.

```csharp
// Create container with hierarchical keys
var containerProperties = new ContainerProperties
{
    Id = "orders",
    PartitionKeyPaths = new Collection<string> { "/tenantId", "/customerId", "/orderId" }
};

// Query at tenant level
var options = new QueryRequestOptions
{
    PartitionKey = new PartitionKeyBuilder()
        .Add("tenant-123")
        .Build()
};

// Point read with full key
var fullKey = new PartitionKeyBuilder()
    .Add("tenant-123")
    .Add("customer-456")
    .Add("order-789")
    .Build();
var response = await container.ReadItemAsync<Order>("order-789", fullKey);
```

---

## Indexing Policies

```csharp
var containerProperties = new ContainerProperties
{
    Id = "Orders",
    PartitionKeyPath = "/pk",
    IndexingPolicy = new IndexingPolicy
    {
        IndexingMode = IndexingMode.Consistent,
        IncludedPaths = {
            new IncludedPath { Path = "/status/?" },
            new IncludedPath { Path = "/createdAt/?" }
        },
        ExcludedPaths = {
            new ExcludedPath { Path = "/*" }  // Exclude all by default
        },
        CompositeIndexes = {
            new Collection<CompositePath> {
                new() { Path = "/status", Order = CompositePathSortOrder.Ascending },
                new() { Path = "/createdAt", Order = CompositePathSortOrder.Descending }
            }
        }
    }
};
```

### Indexing Recommendations

| Scenario | Recommendation |
|----------|----------------|
| Write-heavy | Exclude unused paths |
| Read-heavy | Default (index all) OK |
| ORDER BY | Add composite indexes |
| Large documents | Exclude unused paths |

---

## ContainerContext Index Definitions

Define composite indexes in `ContainerContext` classes so index requirements are co-located with container configuration.

### Pattern

```csharp
public class CasesContainerContext : IContainerContext
{
    private readonly CosmosOptions options;

    public CasesContainerContext(IOptions<CosmosOptions> options)
    {
        this.options = options?.Value ?? throw new ArgumentNullException(nameof(options));
    }

    public string DatabaseId => this.options.DatabaseId ?? string.Empty;
    public string ContainerId => ContainerNames.Cases;
    public string PartitionKeyPath => PartitionKeyPaths.CaseId;
    public int? DefaultTimeToLiveSeconds => null;

    public IndexingPolicy? IndexingPolicy => new IndexingPolicy
    {
        CompositeIndexes =
        {
            new Collection<CompositePath>
            {
                new() { Path = "/workflowStage", Order = CompositePathSortOrder.Ascending },
                new() { Path = "/createdAt", Order = CompositePathSortOrder.Descending },
            },
            new Collection<CompositePath>
            {
                new() { Path = "/type", Order = CompositePathSortOrder.Ascending },
                new() { Path = "/createdAt", Order = CompositePathSortOrder.Descending },
            },
        },
    };
}
```

### Index Selection Guidelines

| Query Pattern | Composite Index Needed |
|---------------|----------------------|
| `ORDER BY status ASC, createdAt DESC` | `(/status ASC, /createdAt DESC)` |
| `WHERE type = @t ORDER BY createdAt DESC` | `(/type ASC, /createdAt DESC)` |
| `WHERE status = @s` (single filter, no ORDER BY) | No composite needed — single-property index suffices |
| Reference/lookup containers (agencies, config) | Typically none — low query volume |

### Testing Composite Indexes

```csharp
[Fact]
public void CasesContainerContext_IndexingPolicy_HasExpectedCompositeIndexes()
{
    var context = new CasesContainerContext(Options.Create(cosmosOptions));

    context.IndexingPolicy.Should().NotBeNull();
    context.IndexingPolicy!.CompositeIndexes.Should().HaveCount(2);

    var firstIndex = context.IndexingPolicy.CompositeIndexes[0];
    firstIndex.Should().HaveCount(2);
    firstIndex[0].Path.Should().Be("/workflowStage");
    firstIndex[1].Path.Should().Be("/createdAt");
}
```

### Enforcement

| Pattern | Status |
|---------|--------|
| Container with ORDER BY queries but no composite index | **WARN** |
| Composite index paths not matching JSON property names | **REJECT** — use camelCase paths matching serialization |
| Composite index on reference/lookup container with no ORDER BY queries | **WARN** — unnecessary overhead |

---

## Zone Redundancy and Region Pairing

**Source**: cross-repo PR review (Feb 2026).

Production Cosmos DB accounts MUST enable zone redundancy and multi-region writes for high availability. Include this in Bicep templates.

```bicep
// CORRECT: Zone redundancy + multi-region in Bicep
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  properties: {
    enableMultipleWriteLocations: true
    locations: [
      {
        locationName: primaryLocation
        failoverPriority: 0
        isZoneRedundant: true   // Required for production
      }
      {
        locationName: secondaryLocation
        failoverPriority: 1
        isZoneRedundant: true   // Both regions must be zone redundant
      }
    ]
    // ...
  }
}

// WRONG: Single region, no zone redundancy
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  properties: {
    locations: [
      {
        locationName: primaryLocation
        failoverPriority: 0
        // isZoneRedundant defaults to false -- single AZ = outage risk
      }
    ]
  }
}
```

| Environment | Zone Redundancy | Multi-Region |
|-------------|-----------------|--------------|
| Dev/Test | Optional | Not required |
| PPE/SDF | Recommended | Recommended |
| Production | **Required** | **Required** |

| Pattern | Status |
|---------|--------|
| Production Cosmos account without `isZoneRedundant: true` | **REJECT** |
| Production Cosmos account with single region | **WARN** |

---

## Review Checklist

**Connection**: Singleton CosmosClient, Direct mode, retry policy configured.

**Partition Key**: High cardinality, included in all queries.

**Queries**: Parameterized, specific fields projected, continuation tokens.

**Batching**: Chunked to 100 items, TransactionalBatch for atomic ops.

**Change Feed**: Lease container, idempotency handling, error handling.

**Indexing**: Composite indexes defined in ContainerContext for multi-property ORDER BY queries.

**Availability**: Zone redundancy and multi-region writes enabled for production.
