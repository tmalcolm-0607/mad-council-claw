---
paths:
  - "**/DataAccess/**/*.cs"
  - "**/Cosmos*/**/*.cs"
  - "**/spec.md"
  - "**/plan.md"
---

# Cosmos DB Core Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Essential patterns for Azure Cosmos DB in .NET: partition keys, connection management, and document modeling.

---

## Partition Key Design

**CRITICAL**: Partition key choice is the most important design decision. Cannot be changed without data migration.

### Cardinality Requirements

| Cardinality | Example | Suitability |
|-------------|---------|-------------|
| **High** | `userId`, `orderId`, `tenantId` | Excellent |
| **Medium** | `category`, `region` | Acceptable with synthetic key |
| **Low** | `status`, `type`, `boolean` | Poor - creates hot partitions |

### Good Partition Key

```csharp
// High cardinality - each user gets their own partition
public class UserDocument
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("pk")]
    public string PartitionKey => UserId;

    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;
}

// Composite key for balanced distribution
public class OrderDocument
{
    [JsonPropertyName("pk")]
    public string PartitionKey => $"{TenantId}:{CustomerId}";
}
```

### Bad Partition Key

```csharp
// WRONG: Low cardinality - creates hot partitions
public string PartitionKey => Status;  // Only "Pending", "Processing", "Complete"

// WRONG: Monotonically increasing - all writes go to same partition
public string PartitionKey => CreatedDate.ToString("yyyy-MM-dd");
```

---

## CosmosEntity Base Class and IPartitioned

**Observed pattern**: `CosmosEntity` implements `IEntity` and `IVersioned` only. Each entity implements `IPartitioned` individually (not inherited from the base class). There is a TODO in some projects to evaluate moving `IPartitioned` to the base class.

```csharp
public interface IPartitioned
{
    string GetPartitionKey();
}

public interface IEntity
{
    string Id { get; }
    string Type { get; }
}

public interface IVersioned
{
    string? ETag { get; set; }
}

// Base class: implements IEntity + IVersioned, NOT IPartitioned
public abstract class CosmosEntity : IEntity, IVersioned
{
    // Default: new GUID without hyphens (not string.Empty)
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString("N");

    [JsonPropertyName("type")]
    public abstract string Type { get; }

    [JsonPropertyName("_etag")]
    public string? ETag { get; set; }
}

// Each entity implements IPartitioned individually
public class CaseEntity : CosmosEntity, IPartitioned
{
    [JsonPropertyName("caseId")]
    public string CaseId { get; set; } = string.Empty;

    public override string Type => "case";

    public string GetPartitionKey() => CaseId;
}
```

---

## Singleton CosmosClient

> **6-Reference Consensus**: Singleton CosmosClient via provider confirmed in all Cosmos-using references. MDEP/Delivery/LEAPI use `CosmosClientProvider` with `ThreadSafeInitializer` for lazy initialization.

**CRITICAL**: CosmosClient MUST be a singleton. Multiple instances cause connection exhaustion.

### Authentication Strategy

| Method | Environment | Usage |
|--------|-------------|-------|
| **Managed Identity (RBAC)** | Production, staging | **Preferred** — `disableLocalAuth: true` in Bicep |
| **Connection String** | Dev/test only | Fallback — from Key Vault |

### Credential selection

Use `ManagedIdentityCredential` in production, `ChainedTokenCredential` locally. **Never use `DefaultAzureCredential`** -- it has unpredictable credential resolution order and silently falls through to whatever token source happens to succeed first.

| Credential | When to use | When to avoid |
|---|---|---|
| `ManagedIdentityCredential` | Production / staging on Azure-hosted compute (App Service, AKS, ACI, VM). Pass the user-assigned client ID explicitly. | Local dev — there is no managed identity available. |
| `WorkloadIdentityCredential` | AKS pods using federated workload identity. | App Service, ACI, or non-AKS workloads. |
| `AzureCliCredential` | Local dev when the developer is signed in via `az login`. | Production — no `az` CLI installed; will fail. |
| `VisualStudioCredential` | Local dev inside Visual Studio with the developer signed in. | Production / CI. |
| `ChainedTokenCredential` | Local dev to compose multiple dev-time sources (`AzureCliCredential` + `VisualStudioCredential`). | Production — be explicit about which identity is in use. |
| `DefaultAzureCredential` | **Never.** Resolution order varies by environment and SDK version; debugging auth failures becomes guesswork. | Always — pick a specific credential or use `ChainedTokenCredential` with an explicit chain. |

```csharp
// PREFERRED: Managed Identity with RBAC (credential per the table above)
services.AddSingleton(sp =>
{
    var cosmosOptions = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
    var environment = sp.GetRequiredService<IHostEnvironment>();

    var credential = environment.IsProduction()
        ? new ManagedIdentityCredential(cosmosOptions.ManagedIdentityClientId)
        : new ChainedTokenCredential(
            new AzureCliCredential(),
            new VisualStudioCredential());

    var clientOptions = new CosmosClientOptions
    {
        ApplicationName = "MyApplication",                        // Required: identifies caller in Cosmos logs
        ConnectionMode = ConnectionMode.Direct,
        EnableContentResponseOnWrite = false,                     // Recommended: saves bandwidth on write-heavy paths
        MaxRetryAttemptsOnRateLimitedRequests = 9,
        MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(30)
    };

    return new CosmosClient(cosmosOptions.Endpoint, credential, clientOptions);
});

// WRONG: DefaultAzureCredential - unpredictable resolution order!
return new CosmosClient(endpoint, new DefaultAzureCredential(), options);

// WRONG: Creating new client per request
using var client = new CosmosClient(connectionString);  // Socket leak!
```

### RBAC Role Assignment

Cosmos DB RBAC uses built-in SQL role definitions:

| Role | ID | Grants |
|------|----|--------|
| Built-in Data Reader | `00000000-0000-0000-0000-000000000001` | Read all data |
| Built-in Data Contributor | `00000000-0000-0000-0000-000000000002` | Read + write all data |

### Bicep RBAC assignment

Cosmos DB Built-in Data Contributor (`00000000-0000-0000-0000-000000000002`) gives the assigned managed identity read + write on all data:

```bicep
// Assign Cosmos DB Built-in Data Contributor to a user-assigned managed identity
resource cosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, managedIdentity.id, 'data-contributor')
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: managedIdentity.properties.principalId
    scope: cosmosAccount.id
  }
}
```

Pair the assignment with `disableLocalAuthentication: true` on the account so connection strings can't bypass the RBAC enforcement.

```bicep
// Disable local auth (connection strings) in production
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  properties: {
    disableLocalAuthentication: true  // Forces RBAC-only access
    // ...
  }
}
```

### Connection Mode

| Mode | Use Case | Performance |
|------|----------|-------------|
| **Direct** | Production | Best - direct TCP |
| **Gateway** | Firewall restrictions | Good - HTTPS only |

### Private Endpoints

Production deployments use private endpoints — no public network access:

- Private DNS zone: `privatelink.documents.azure.com`
- VNet integration required for App Service / AKS
- See `.claude/rules/patterns/cicd-deployment.md` for Bicep private endpoint patterns

---

## Document ID Prefixes

A consumer project may use prefixed IDs for type discrimination. Example:

| Type | Prefix | Example |
|------|--------|---------|
| Case | `case:` | `case:1738540800-A1B2C3` |
| DFT | `dft:` | `dft:a1b2c3d4-e5f6-7890` |
| Note | `note:` | `note:a1b2c3d4-e5f6-7890` |
| Attachment | `att:` | `att:a1b2c3d4-e5f6-7890` |

```csharp
public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type, string id) => $"{type}:{id}";
}
```

### Document Type Constants in Queries

Never use magic strings for document types in WHERE clauses. Always reference `DocumentTypes` constants.

```csharp
// CORRECT: Use constants
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.type = @type AND c.pk = @pk")
    .WithParameter("@type", DocumentTypes.Case)
    .WithParameter("@pk", partitionKey);

// WRONG: Hardcoded string
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.type = 'case' AND c.pk = @pk");
```

---

## Enum Serialization

All enums stored in Cosmos documents MUST use string serialization with `[JsonStringEnumConverter]`. Use `[JsonStringEnumMemberName]` (System.Text.Json) for custom string representations. Do NOT use `[EnumMember]` (Newtonsoft/`System.Runtime.Serialization`) -- that attribute is ignored by System.Text.Json.

```csharp
// CORRECT: String-backed enum with System.Text.Json custom values
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CaseStatus
{
    [JsonStringEnumMemberName("unknown")]
    Unknown = 0,

    [JsonStringEnumMemberName("open")]
    Open = 1,

    [JsonStringEnumMemberName("closed")]
    Closed = 2,

    [JsonStringEnumMemberName("pendingReview")]
    PendingReview = 3
}

// WRONG: Integer-backed enum in Cosmos (opaque in queries/portal)
public enum CaseStatus { Unknown, Open, Closed }
```

---

## Case ID Generation

Time-sortable format for partition keys:

| Component | Format | Example |
|-----------|--------|---------|
| Prefix | `LNS-` | `LNS-` |
| Epoch | 10 digits | `1738540800` |
| Suffix | 6 alphanumeric | `A1B2C3` |
| **Total** | 21 chars | `LNS-1738540800-A1B2C3` |

```csharp
public static string Generate()
{
    var epoch = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    var suffix = GenerateRandomSuffix(6);
    return $"LNS-{epoch}-{suffix}";
}
```

---

## Soft Delete Pattern

<!-- Provenance: no canonical LENS-Common, LENS-Docs, lens-aspnet-structure, or cosmos-provisioning skill prescribes soft-delete-by-default. Independently verified across the canonical reference repos. -->

> **Project policy, not LENS-canonical.** Default delete behavior SHOULD be soft delete; hard delete SHOULD require an explicit flag to prevent accidental data loss. **Services with compliance / legal-hold / audit-retention requirements MUST default to soft delete**; other services SHOULD evaluate based on data lifecycle (e.g., hard-delete-by-default may be appropriate for GDPR Right-to-Erasure flows or services that retain PII transiently). Document the choice in the consumer project's `CLAUDE.md`.

```csharp
public async Task DeleteAsync(
    string id,
    string partitionKey,
    bool hardDelete = false,
    CancellationToken ct = default)
{
    if (hardDelete)
    {
        this.logger.HardDeleteRequested(id);
        await this.container.DeleteItemAsync<CosmosEntity>(
            id, new PartitionKey(partitionKey), cancellationToken: ct);
        return;
    }

    // Soft delete: mark as deleted, retain document
    var patch = new List<PatchOperation>
    {
        PatchOperation.Set("/isDeleted", true),
        PatchOperation.Set("/deletedAt", DateTimeOffset.UtcNow)
    };

    await this.container.PatchItemAsync<CosmosEntity>(
        id, new PartitionKey(partitionKey), patch, cancellationToken: ct);
}
```

**Query filtering**: Services that adopt the soft-delete pattern MUST filter `WHERE c.isDeleted != true` over soft-deletable containers/entities (within those services, the rule is unconditional). Services that hard-delete-by-default do not have an `isDeleted` field to filter on. Document the choice in the consumer project's `CLAUDE.md` and apply the filter scope accordingly. (SHOULD — project policy, not LENS-canonical; see line 316.)

---

## Container Strategy

When to use separate containers vs a shared container with type discriminators.

### Decision Criteria

| Factor | Shared Container | Separate Containers |
|--------|-----------------|---------------------|
| Access pattern | Entities queried together | Entities queried independently |
| Partition key | Same natural key (e.g., `caseId`) | Different natural keys |
| RU isolation | Shared throughput acceptable | Need independent scaling |
| Change feed | Single feed for all types OK | Need per-type change feed processing |

### Shared Container (with type discriminator)

Use when entities share a partition key and are frequently queried together:

```csharp
// Same container, different types - discriminated by "type" field
var caseDoc = new { id = "case:123", type = "case", pk = "CASE-123", ... };
var noteDoc = new { id = "note:456", type = "note", pk = "CASE-123", ... };

// Query all documents for a case in one call
var query = new QueryDefinition(
    "SELECT * FROM c WHERE c.pk = @pk")
    .WithParameter("@pk", caseId);
```

### Separate Containers

Use when entities have different access patterns, partition keys, or need RU isolation:

```csharp
// Agencies container - partition key is agencyId, rarely written
// Cases container - partition key is caseId, high write volume
// Separate containers enable independent throughput provisioning
```

### Container Separation Decision Checklist

**Source**: recurring reviewer pattern across ecosystem services (Feb 2026).

When reviewers see a new entity type added to an existing container, they ask: "Should this be a separate container?" Use this checklist:

| Question | If Yes → | If No → |
|----------|----------|---------|
| Does the entity share a natural partition key with existing entities? | Shared container | Separate container |
| Are entities frequently queried together in the same request? | Shared container | Separate container |
| Does the entity have drastically different throughput needs? | Separate container | Shared container |
| Do you need an independent change feed for this entity type? | Separate container | Shared container |
| Is the entity queried by a completely different set of callers? | Separate container | Shared container |

**Example** (from cross-repo PR review):
> "Shouldn't delivery endpoints be a separate entity in a separate container (for faster searches)?"

**Rationale**: Delivery endpoints are queried by a different access pattern than delivery jobs. Separate containers enable independent throughput scaling and faster point reads.

### Partition Key Redundancy

**Source**: cross-repo PR review (Feb 2026).

Avoid using a field as partition key when it duplicates another field (e.g., `taskId` == `Id`). Use the canonical field directly.

```csharp
// CORRECT: Use the canonical ID field as partition key
public override string GetPartitionKey() => Id;

// WRONG: Redundant field that mirrors Id
[JsonPropertyName("taskId")]
public string TaskId { get; set; }  // Same value as Id -- unnecessary
public override string GetPartitionKey() => TaskId;
```

| Pattern | Status |
|---------|--------|
| Shared container without type discriminator | **WARN** |
| Redundant partition key field that mirrors document Id | **WARN** |
| New entity type added to container without separation analysis | **WARN** |

---

## Patch Operation Allow-Lists

Patchable field sets MUST derive from the **Patch DTO model**, never from the domain entity. Reflecting over the entity exposes internal/system fields (e.g., `ETag`, `IsDeleted`, `CreatedAt`) to client-controlled patch operations.

### Correct: Reflect Over Patch DTO

```csharp
// Patch DTO defines ONLY the fields clients may update
public class CasePatchModel
{
    public string? Title { get; set; }
    public string? Description { get; set; }
    public CaseStatus? Status { get; set; }
}

// Allow-list derived from DTO properties
var allowedFields = typeof(CasePatchModel)
    .GetProperties(BindingFlags.Public | BindingFlags.Instance)
    .Select(p => p.Name)
    .ToHashSet(StringComparer.OrdinalIgnoreCase);
```

### Wrong: Reflect Over Entity

```csharp
// WRONG: Entity has ETag, IsDeleted, CreatedAt, etc. — all exposed to patch
var allowedFields = typeof(CaseEntity)
    .GetProperties(BindingFlags.Public | BindingFlags.Instance)
    .Select(p => p.Name)
    .ToHashSet(StringComparer.OrdinalIgnoreCase);
```

---

## ETag HTTP Response Header

> **Cross-reference consensus**: ETag HTTP response header propagation (Cosmos ETag → HTTP ETag header) is not common across the audited ecosystem services. It is a useful pattern where a service needs conditional GET (`If-None-Match`) and optimistic concurrency on PATCH (`If-Match`).

### Server-Side ETag Concurrency (PatchItemAsync)

**CRITICAL**: Always use server-side ETag enforcement via `IfMatchEtag`. Client-side ETag comparison (read-compare-patch) is a TOCTOU race condition — another writer can modify the document between your read and patch.

```csharp
// CORRECT: Server-side ETag enforcement
var options = new PatchItemRequestOptions
{
    IfMatchEtag = etag  // Server rejects if document changed since read
};

try
{
    await container.PatchItemAsync<CaseEntity>(
        id, new PartitionKey(partitionKey), patchOperations, options, ct);
}
catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
{
    // 412: Document was modified — surface as 409 Conflict to caller
    throw new ConcurrencyConflictException($"Document {id} was modified by another request");
}

// WRONG: Client-side comparison (TOCTOU race)
var current = await container.ReadItemAsync<CaseEntity>(id, pk);
if (current.ETag != expectedEtag)
    throw new ConcurrencyException("Stale");  // Another write can happen HERE
await container.PatchItemAsync<CaseEntity>(id, pk, ops);  // No server-side check!
```

---

## Enforcement

| Pattern | Status |
|---------|--------|
| `CosmosClientOptions` without `ApplicationName` | **REJECT** |
| Hardcoded document type string in query | **REJECT** |
| `DeleteAsync` without soft delete option (compliance/legal-hold services) | **REJECT** |
| `DeleteAsync` without soft delete option (other services) | **WARN** — evaluate against data lifecycle; document choice in consumer CLAUDE.md |
| Integer-backed enum in Cosmos document | **REJECT** |
| Missing `IPartitioned` on a new Cosmos entity | **WARN** |
| `init` accessor on `Id` preventing composite assignment | **WARN** |
| Connection string auth in production Bicep | **REJECT** |
| Missing `disableLocalAuthentication` in prod | **WARN** |
| `typeof(Entity).GetProperties` for patch allow-list | **REJECT** |
| `PatchItemAsync` without `IfMatchEtag` on mutable endpoints | **REJECT** |
| `ReplaceItemAsync` without `IfMatchEtag` on mutable endpoints | **REJECT** |
| `UpsertItemAsync` for update operations (use Replace + ETag) | **REJECT** |
| Client-side ETag comparison without server-side `IfMatchEtag` | **REJECT** |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Multiple CosmosClient instances | Singleton per app |
| Low cardinality partition key | High cardinality keys |
| Creating container per request | Cache Container reference |
| Synchronous SDK calls | Always async/await |
| Hard delete as default (compliance/legal-hold/audit-retention services) | Soft delete by default, hard delete with explicit flag |
| Magic strings in WHERE clauses | Use `DocumentTypes` constants |
| Integer enums in documents | `[JsonStringEnumConverter]` with `[JsonStringEnumMemberName]` |
| Connection string in production | Managed Identity with RBAC |
| Public network access in production | Private endpoints + VNet |
| Client-side ETag check + write without server-side guard | Use `PatchItemRequestOptions { IfMatchEtag = etag }` + catch 412 (two writers pass check, last writer wins silently) |

> **Soft-delete-by-default applicability**: the Soft Delete row above is MUST for compliance / legal-hold / audit-retention services and SHOULD for other services. See the Soft Delete Pattern section above for the full policy — it is project policy, not LENS-canonical.

---

## ETag Propagation (TOCTOU Prevention)

Three rules for optimistic concurrency:
1. Pass the CLIENT-sent ETag (from `If-Match` header) to `UpdateAsync`/`ReplaceAsync` for atomic Cosmos enforcement. Never compare ETags in application code.
2. Always capture the return value of `UpdateAsync` -- it contains the fresh ETag. Never discard it with `(response, _)` or assign to `_`.
3. Return the fresh ETag from step 2 to the caller so the client receives it in the response `ETag` header.

Anti-pattern: Read entity, compare ETags in C#, write with server-side ETag. Between read and write, another request can succeed (TOCTOU race).
