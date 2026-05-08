---
paths:
  - "**/*Identity*.cs"
  - "**/*Credential*.cs"
  - "**/*Auth*.cs"
  - "**/Program.cs"
---

# CMS Azure Identity Patterns

## Single Service Identity Model

**CMS uses a single Managed Identity** for all Azure service access. Unlike SMS (which uses per-caller delegation identities for SAS token signing), CMS uses one identity for its own operations.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CMS Service                                  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │           CMS Managed Identity (UAMI)                         │   │
│  │                                                               │   │
│  │  - Authenticates CMS to Azure services                        │   │
│  │  - No per-caller delegation (CMS authorizes operations)       │   │
│  │  - Single identity simplifies RBAC management                 │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              |                                       │
│              +---------------+---------------+                       │
│              |               |               |                       │
│              v               v               v                       │
│      ┌───────────┐   ┌───────────┐   ┌───────────────┐             │
│      │ Cosmos DB │   │   Blob    │   │   Key Vault   │             │
│      │  (Data)   │   │ (Attach)  │   │  (Secrets)    │             │
│      └───────────┘   └───────────┘   └───────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Single Identity for CMS?

| Aspect | CMS (Single Identity) | SMS (Delegation Identities) |
|--------|----------------------|----------------------------|
| Use case | Case management with user auth | Storage token vending for partners |
| Identity per | Service | Caller/partner |
| RBAC scope | All CMS resources | Per-partner storage accounts |
| Revocation | Revoke CMS identity | Revoke specific partner identity |
| Complexity | Simple | Higher (many identities to manage) |

CMS authenticates users via MISE v2 and authorizes operations based on user claims. The CMS Managed Identity is used only for CMS-to-Azure service authentication.

## Cosmos DB Access with Managed Identity

### Singleton CosmosClient Registration

```csharp
// Program.cs - Register CosmosClient as singleton with Managed Identity
services.AddSingleton(sp =>
{
    var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
    var environment = sp.GetRequiredService<IHostEnvironment>();

    // Select credential based on environment
    var credential = environment.IsProduction()
        ? new ManagedIdentityCredential(options.ManagedIdentityClientId)
        : new ChainedTokenCredential(
            new AzureCliCredential(),
            new VisualStudioCredential());

    var clientOptions = new CosmosClientOptions
    {
        ApplicationName = "consumer-project",
        ConnectionMode = ConnectionMode.Direct,
        MaxRetryAttemptsOnRateLimitedRequests = 9,
        MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(30),
        SerializerOptions = new CosmosSerializationOptions
        {
            PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
        }
    };

    return new CosmosClient(options.Endpoint, credential, clientOptions);
});

// Register Database and Containers
services.AddSingleton(sp =>
{
    var client = sp.GetRequiredService<CosmosClient>();
    var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
    return client.GetDatabase(options.DatabaseId);
});

services.AddSingleton<ICasesContainer>(sp =>
{
    var database = sp.GetRequiredService<Database>();
    return new CasesContainer(database.GetContainer("cases"));
});
```

### CosmosOptions Configuration

```csharp
public class CosmosOptions : IConfigOptions
{
    public const string ConfigSectionKey = "Cosmos";

    [Required]
    public string Endpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    public string? ManagedIdentityClientId { get; set; }

    [Range(1, 100)]
    public int MaxRetryAttempts { get; set; } = 9;

    [Range(1, 300)]
    public int MaxRetryWaitTimeSeconds { get; set; } = 30;
}

// Registration with fail-fast validation
services.AddOptions<CosmosOptions>()
    .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

## RBAC Requirements for CMS

CMS Managed Identity needs roles on multiple Azure resources.

| Resource | Role | GUID | Purpose |
|----------|------|------|---------|
| **Cosmos DB** | `Cosmos DB Built-in Data Contributor` | `00000000-0000-0000-0000-000000000002` | Read/write documents |
| **Blob Storage** | `Storage Blob Data Contributor` | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` | Upload/download attachments |
| **Key Vault** | `Key Vault Secrets User` | `4633458b-17de-408a-b874-0445c86b69e6` | Read secrets |
| **App Configuration** | `App Configuration Data Reader` | `516239f1-63e1-4d78-a4de-a74fb236a071` | Read configuration |

### Bicep Role Assignments

```bicep
// Cosmos DB Built-in Data Contributor
resource cosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  name: guid(cosmosAccount.id, cmsIdentity.id, 'Cosmos DB Built-in Data Contributor')
  parent: cosmosAccount
  properties: {
    roleDefinitionId: '/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosAccount.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: cmsIdentity.properties.principalId
    scope: cosmosAccount.id
  }
}

// Storage Blob Data Contributor
resource blobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, cmsIdentity.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: cmsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets User
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, cmsIdentity.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: cmsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// App Configuration Data Reader
resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appConfig.id, cmsIdentity.id, 'App Configuration Data Reader')
  scope: appConfig
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '516239f1-63e1-4d78-a4de-a74fb236a071')
    principalId: cmsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

## Credential Selection Pattern

### Production: Explicit ManagedIdentityCredential

**Never use `DefaultAzureCredential` in production** - it has unpredictable credential resolution order.

```csharp
// CORRECT: Explicit credential selection based on environment
public static TokenCredential CreateCredential(
    IHostEnvironment environment,
    string? managedIdentityClientId)
{
    if (environment.IsProduction() || environment.IsStaging())
    {
        // Production/PPE: Explicit User-Assigned Managed Identity
        if (string.IsNullOrEmpty(managedIdentityClientId))
        {
            throw new InvalidOperationException(
                "ManagedIdentityClientId is required in production environments");
        }

        return new ManagedIdentityCredential(managedIdentityClientId);
    }

    // Development/Integration: Chain developer credentials
    return new ChainedTokenCredential(
        new AzureCliCredential(),
        new VisualStudioCredential()
    );
}
```

```csharp
// WRONG: DefaultAzureCredential in any environment
var credential = new DefaultAzureCredential(); // Unpredictable resolution!
```

### Why User-Assigned over System-Assigned

| Aspect | User-Assigned (UAMI) | System-Assigned |
|--------|---------------------|-----------------|
| Lifecycle | Independent of compute | Tied to compute resource |
| Pre-creation | Can create and assign RBAC first | Only exists after deployment |
| Multi-slot | Same identity across slots | Different identity per slot |
| Deletion | Preserved if compute deleted | Deleted with compute |

Per common large-enterprise standards, **User-Assigned Managed Identity (UAMI) is mandatory** for production workloads. The lesson: bind identity to a durable, explicitly-named resource so lifecycle events (slot swap, compute recreation, zero-downtime redeploys) don't surprise you with a fresh identity.

### UAMI Naming Convention

```
id-<svc>-{env}-{region}
```

| Environment | Example |
|-------------|---------|
| Development | `id-myservice-dev-westus2` |
| Integration | `id-myservice-int-westus2` |
| PPE | `id-myservice-ppe-westus2` |
| Production | `id-myservice-prod-westus2` |

## Local Development Credentials

### ChainedTokenCredential for Developers

```csharp
// Development credential chain
var devCredential = new ChainedTokenCredential(
    new AzureCliCredential(),       // Primary: az login
    new VisualStudioCredential()    // Fallback: VS authentication
);
```

### One-Time Setup

```bash
# Login to Azure CLI
az login

# Set subscription (if multiple)
az account set --subscription "Your-Dev-Subscription"

# Verify access
az account show
```

### Visual Studio Configuration

In Visual Studio:
1. Tools > Options > Azure Service Authentication
2. Select account with access to your dev subscription

## Token Caching

`TokenCredential` implementations **cache tokens internally** until near expiry. You should:

1. **Reuse credential instances** - Do not create new credentials per request
2. **Register as singleton** - Credentials are thread-safe
3. **Trust automatic refresh** - SDK handles token refresh

```csharp
// CORRECT: Singleton credential reused across requests
services.AddSingleton(sp =>
{
    var options = sp.GetRequiredService<IOptions<AzureOptions>>().Value;
    return CreateCredential(sp.GetRequiredService<IHostEnvironment>(),
                           options.ManagedIdentityClientId);
});

// WRONG: Creating credential per request
public async Task ProcessAsync()
{
    var credential = new ManagedIdentityCredential(clientId); // Expensive!
    var client = new CosmosClient(endpoint, credential);
    // ...
}
```

## Azure App Configuration Integration

Use Azure App Configuration with Key Vault references for configuration management.

```csharp
// Program.cs
var credential = CreateCredential(
    builder.Environment,
    builder.Configuration["Azure:ManagedIdentityClientId"]);

builder.Configuration.AddAzureAppConfiguration(options =>
{
    var endpoint = builder.Configuration["AppConfiguration:Endpoint"]
        ?? throw new InvalidOperationException("AppConfiguration:Endpoint not configured");

    options.Connect(new Uri(endpoint), credential)
        .ConfigureKeyVault(kv => kv.SetCredential(credential))
        .ConfigureRefresh(refresh =>
        {
            refresh.Register("Sentinel", refreshAll: true)
                   .SetCacheExpiration(TimeSpan.FromMinutes(5));
        });
});
```

**Important**: Do not use Key Vault directly as a configuration store. Use App Configuration with Key Vault references.

```
# App Configuration keys (example)
Cosmos:Endpoint = https://cosmos-lens-cms-prod.documents.azure.com:443/
Cosmos:DatabaseId = cms-db
Cosmos:ManagedIdentityClientId = <Key Vault Reference>
Sentinel = "1"  # Change to trigger config refresh
```

## Local Development with Emulators

### Cosmos DB Emulator

```csharp
// Development: Use Cosmos Emulator with connection string
if (builder.Environment.IsDevelopment())
{
    var emulatorEndpoint = "https://localhost:8081";
    var emulatorKey = "<COSMOS_EMULATOR_WELL_KNOWN_KEY>"; // See https://learn.microsoft.com/azure/cosmos-db/emulator

    builder.Services.AddSingleton(_ =>
        new CosmosClient(emulatorEndpoint, emulatorKey, new CosmosClientOptions
        {
            ApplicationName = "consumer-project-Dev",
            ConnectionMode = ConnectionMode.Gateway, // Emulator requires Gateway mode
            HttpClientFactory = () =>
            {
                // Accept self-signed certificate
                var handler = new HttpClientHandler
                {
                    ServerCertificateCustomValidationCallback =
                        HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
                };
                return new HttpClient(handler);
            }
        }));
}
```

### Azurite (Blob Storage Emulator)

```csharp
// Development: Use Azurite with connection string
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddSingleton(_ =>
        new BlobServiceClient("UseDevelopmentStorage=true"));
}
```

## Testing with Mock Credentials

### Unit Tests

```csharp
public class CaseServiceTests
{
    [TestMethod]
    public async Task GetCaseById_WhenCaseExists_ReturnsCase()
    {
        // Arrange
        var mockCredential = Substitute.For<TokenCredential>();
        mockCredential.GetTokenAsync(
            Arg.Any<TokenRequestContext>(),
            Arg.Any<CancellationToken>())
            .Returns(new AccessToken("mock-token", DateTimeOffset.UtcNow.AddHours(1)));

        // Use mockCredential in client setup...
    }
}
```

### Integration Tests

For integration tests, use the Cosmos Emulator and Azurite with connection strings (not Managed Identity).

## Health Checks

### Credential Health Check

```csharp
public class AzureIdentityHealthCheck : IHealthCheck
{
    private readonly TokenCredential _credential;
    private readonly string _scope;

    public AzureIdentityHealthCheck(TokenCredential credential, string scope)
    {
        _credential = credential;
        _scope = scope;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken ct = default)
    {
        try
        {
            var token = await _credential.GetTokenAsync(
                new TokenRequestContext(new[] { _scope }),
                ct);

            return HealthCheckResult.Healthy(
                $"Token acquired, expires {token.ExpiresOn}");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(
                "Failed to acquire token", ex);
        }
    }
}

// Registration
services.AddHealthChecks()
    .AddCheck<AzureIdentityHealthCheck>(
        "azure-identity",
        tags: new[] { "ready" });
```

## Anti-Patterns

```csharp
// WRONG: DefaultAzureCredential in production
var credential = new DefaultAzureCredential();

// WRONG: Hardcoded credentials or secrets
var credential = new ClientSecretCredential(tenantId, clientId, "secret-in-code");

// WRONG: Creating credential per request (expensive)
public async Task ProcessAsync()
{
    var credential = new ManagedIdentityCredential(clientId); // Don't do this!
}

// WRONG: Direct Key Vault access for configuration
builder.Configuration.AddAzureKeyVault(vaultUri, credential);
// Use App Configuration with KV references instead

// WRONG: Connection strings in production (for services that support MI)
new CosmosClient("AccountEndpoint=...;AccountKey=SECRET;");

// WRONG: Missing client ID for UAMI in production
new ManagedIdentityCredential(); // Will try system-assigned, may fail

// CORRECT: Explicit client ID for UAMI
new ManagedIdentityCredential(options.ManagedIdentityClientId);
```

## CMS Identity Guidelines Summary

1. **Single identity**: CMS uses one Managed Identity for all Azure service access
2. **RBAC roles**: Cosmos Data Contributor, Blob Data Contributor, KV Secrets User, App Config Reader
3. **Production**: Explicit `ManagedIdentityCredential` with UAMI client ID
4. **Development**: `ChainedTokenCredential` with Azure CLI + Visual Studio
5. **Configuration**: Azure App Configuration with Key Vault references
6. **Singletons**: Credential and client instances should be singletons
7. **Token caching**: `TokenCredential` caches tokens internally - reuse instances

## Sources

- [Azure Identity best practices](https://learn.microsoft.com/en-us/dotnet/azure/sdk/authentication/best-practices)
- [Managed Identity overview](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Cosmos DB RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-rbac)
- [ChainedTokenCredential](https://learn.microsoft.com/en-us/dotnet/api/azure.identity.chainedtokencredential)
