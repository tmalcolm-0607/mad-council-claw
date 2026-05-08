---
paths:
  - "**/*Storage*.cs"
  - "**/*Blob*.cs"
  - "**/*Attachment*.cs"
---

# CMS Attachment Storage Patterns

## Identity-Based Streaming (CMS Approach)

### Pattern: CMS as Streaming Proxy

**Critical**: CMS uses **Identity-Based Streaming** for attachment access. Unlike SMS (which uses Valet Key/SAS tokens), CMS acts as a streaming proxy with its own Managed Identity.

```
Client                          CMS Service                    Blob Storage
   |                                 |                              |
   |  POST /cases/{id}/attachments   |                              |
   +-------------------------------->|                              |
   |                                 |  Upload using Managed ID     |
   |                                 +----------------------------->|
   |                                 |                              |
   |  201 Created                    |<-----------------------------+
   |<--------------------------------+                              |
   |                                 |                              |
   |  GET /cases/{id}/attachments/x  |                              |
   +-------------------------------->|                              |
   |                                 |  Download using Managed ID   |
   |                                 +----------------------------->|
   |                                 |                              |
   |  Stream content to client       |<-----------------------------+
   |<--------------------------------+                              |
```

### Why Identity-Based Streaming for CMS?

| Benefit | Description |
|---------|-------------|
| **Case ownership validation** | CMS validates user has access to the case before streaming |
| **Business rule enforcement** | CMS can enforce status checks, permissions, audit logging |
| **Simpler client experience** | No token management; standard REST calls |
| **Centralized access control** | All blob access flows through CMS authorization |

**Trade-off**: CMS bears the bandwidth cost of proxying content. For large files, consider evaluating file size limits and bandwidth capacity.

### Comparison: CMS vs SMS Storage Access

| Aspect | CMS (Identity-Based Streaming) | SMS (Valet Key) |
|--------|-------------------------------|-----------------|
| Client interaction | CMS proxies content | Client accesses blob directly |
| Token management | None (client perspective) | Client manages SAS tokens |
| Bandwidth | CMS bears cost | Storage account bears cost |
| Access validation | Per-request by CMS | At token issuance only |
| Use case | Case attachments with authorization | High-volume data collection |

## Attachment Container Structure

### Container Naming

```
cms-attachments-{env}
```

| Environment | Container Name |
|-------------|----------------|
| Development | `cms-attachments-dev` |
| Integration | `cms-attachments-int` |
| PPE/SDF | `cms-attachments-ppe` |
| Production | `cms-attachments-prod` |

### Blob Naming Convention

```
{caseId}/{attachmentId}/{filename}
```

**Example:**
```
case-12345/att-67890/evidence-document.pdf
```

| Component | Description |
|-----------|-------------|
| `{caseId}` | Case identifier (virtual folder for organization) |
| `{attachmentId}` | Unique attachment ID (enables multiple versions) |
| `{filename}` | Original filename with extension |

## Upload/Download Proxy Patterns

### Upload Endpoint (Proxy Pattern)

```csharp
// CORRECT: CMS proxies uploads using its Managed Identity
public async Task<IResult> UploadAttachmentAsync(
    string caseId,
    string attachmentId,
    IFormFile file,
    ICaseService caseService,
    BlobContainerClient container,
    ILogger<AttachmentEndpoints> logger,
    CancellationToken ct)
{
    // 1. Validate case exists and user has access
    var caseResult = await caseService.GetByIdAsync(caseId, ct);
    if (!caseResult.IsSuccess)
    {
        return Results.NotFound(new { message = $"Case {caseId} not found" });
    }

    // 2. Validate file (size, type, etc.)
    if (file.Length > MaxFileSizeBytes)
    {
        return Results.BadRequest(new { message = "File exceeds maximum size" });
    }

    // 3. Build blob path: {caseId}/{attachmentId}/{filename}
    var blobPath = $"{caseId}/{attachmentId}/{file.FileName}";
    var blobClient = container.GetBlobClient(blobPath);

    // 4. Upload using CMS Managed Identity
    var blobHttpHeaders = new BlobHttpHeaders
    {
        ContentType = file.ContentType
    };

    await using var stream = file.OpenReadStream();
    await blobClient.UploadAsync(
        stream,
        new BlobUploadOptions
        {
            HttpHeaders = blobHttpHeaders,
            Metadata = new Dictionary<string, string>
            {
                ["caseId"] = caseId,
                ["attachmentId"] = attachmentId,
                ["originalFileName"] = file.FileName,
                ["uploadedAt"] = DateTimeOffset.UtcNow.ToString("O")
            }
        },
        ct);

    logger.AttachmentUploaded(caseId, attachmentId, file.FileName, file.Length);

    return Results.Created(
        $"/api/v1/cases/{caseId}/attachments/{attachmentId}",
        new { caseId, attachmentId, fileName = file.FileName });
}
```

### Download Endpoint (Streaming Proxy Pattern)

```csharp
// CORRECT: CMS streams content to client using its Managed Identity
public async Task<IResult> DownloadAttachmentAsync(
    string caseId,
    string attachmentId,
    ICaseService caseService,
    IAttachmentRepository attachmentRepo,
    BlobContainerClient container,
    ILogger<AttachmentEndpoints> logger,
    CancellationToken ct)
{
    // 1. Validate case exists and user has access
    var caseResult = await caseService.GetByIdAsync(caseId, ct);
    if (!caseResult.IsSuccess)
    {
        return Results.NotFound(new { message = $"Case {caseId} not found" });
    }

    // 2. Get attachment metadata from Cosmos
    var attachment = await attachmentRepo.GetByIdAsync(caseId, attachmentId, ct);
    if (attachment is null)
    {
        return Results.NotFound(new { message = $"Attachment {attachmentId} not found" });
    }

    // 3. Build blob path and get client
    var blobPath = $"{caseId}/{attachmentId}/{attachment.FileName}";
    var blobClient = container.GetBlobClient(blobPath);

    // 4. Check blob exists
    var exists = await blobClient.ExistsAsync(ct);
    if (!exists.Value)
    {
        logger.AttachmentBlobNotFound(caseId, attachmentId, blobPath);
        return Results.NotFound(new { message = "Attachment content not found" });
    }

    // 5. Stream content to client
    var download = await blobClient.DownloadStreamingAsync(cancellationToken: ct);

    logger.AttachmentDownloaded(caseId, attachmentId, attachment.FileName);

    return Results.Stream(
        download.Value.Content,
        contentType: download.Value.Details.ContentType ?? "application/octet-stream",
        fileDownloadName: attachment.FileName);
}
```

### Delete Endpoint

```csharp
public async Task<IResult> DeleteAttachmentAsync(
    string caseId,
    string attachmentId,
    ICaseService caseService,
    IAttachmentRepository attachmentRepo,
    BlobContainerClient container,
    ILogger<AttachmentEndpoints> logger,
    CancellationToken ct)
{
    // 1. Validate case and permissions
    var caseResult = await caseService.GetByIdAsync(caseId, ct);
    if (!caseResult.IsSuccess)
    {
        return Results.NotFound(new { message = $"Case {caseId} not found" });
    }

    // 2. Get attachment metadata
    var attachment = await attachmentRepo.GetByIdAsync(caseId, attachmentId, ct);
    if (attachment is null)
    {
        return Results.NotFound(new { message = $"Attachment {attachmentId} not found" });
    }

    // 3. Delete blob
    var blobPath = $"{caseId}/{attachmentId}/{attachment.FileName}";
    var blobClient = container.GetBlobClient(blobPath);
    await blobClient.DeleteIfExistsAsync(cancellationToken: ct);

    // 4. Delete metadata from Cosmos
    await attachmentRepo.DeleteAsync(caseId, attachmentId, ct);

    logger.AttachmentDeleted(caseId, attachmentId);

    return Results.NoContent();
}
```

## Storage Client Registration

### Singleton BlobServiceClient with Managed Identity

> **Credentials**: See [azure-identity.md](azure-identity.md) for credential selection, RBAC assignments, and local development patterns.

```csharp
// Program.cs - Register BlobServiceClient as singleton
services.AddSingleton(sp =>
{
    var options = sp.GetRequiredService<IOptions<StorageOptions>>().Value;
    var credential = sp.GetRequiredService<TokenCredential>(); // Registered per azure-identity.md

    return new BlobServiceClient(new Uri(options.BlobServiceUri), credential);
});

// Register BlobContainerClient for attachments container
services.AddSingleton(sp =>
{
    var blobServiceClient = sp.GetRequiredService<BlobServiceClient>();
    var options = sp.GetRequiredService<IOptions<StorageOptions>>().Value;
    return blobServiceClient.GetBlobContainerClient(options.AttachmentsContainer);
});
```

### StorageOptions Configuration

```csharp
public class StorageOptions : IConfigOptions
{
    public const string ConfigSectionKey = "Storage";

    [Required]
    public string BlobServiceUri { get; set; } = string.Empty;

    [Required]
    public string AttachmentsContainer { get; set; } = string.Empty;

    public string? ManagedIdentityClientId { get; set; }

    [Range(1, 1073741824)] // 1 byte to 1 GB
    public long MaxFileSizeBytes { get; set; } = 104857600; // 100 MB default
}

// Registration with fail-fast validation
services.AddOptions<StorageOptions>()
    .Bind(configuration.GetSection(StorageOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

### Configuration Example

```json
// appsettings.json
{
  "Storage": {
    "BlobServiceUri": "https://stlenscms{env}{region}.blob.core.windows.net",
    "AttachmentsContainer": "cms-attachments-{env}",
    "MaxFileSizeBytes": 104857600
  }
}

// runtimesettings.json (environment-specific)
{
  "Storage": {
    "ManagedIdentityClientId": "<from-key-vault-reference>"
  }
}
```

## RBAC Requirements

CMS Managed Identity needs `Storage Blob Data Contributor` to read and write blob content.

| Role | Purpose | Scope |
|------|---------|-------|
| `Storage Blob Data Contributor` | Upload, download, delete blobs | Attachments container |

> **Bicep role assignment**: See [azure-identity.md](azure-identity.md) for the `Storage Blob Data Contributor` Bicep template and all CMS RBAC assignments.

## Logging Patterns

```csharp
public static partial class AttachmentLogMessages
{
    [LoggerMessage(
        EventId = 5001,
        Level = LogLevel.Information,
        Message = "Attachment uploaded: CaseId={CaseId}, AttachmentId={AttachmentId}, FileName={FileName}, Size={Size}")]
    public static partial void AttachmentUploaded(
        this ILogger logger,
        string caseId,
        string attachmentId,
        string fileName,
        long size);

    [LoggerMessage(
        EventId = 5002,
        Level = LogLevel.Information,
        Message = "Attachment downloaded: CaseId={CaseId}, AttachmentId={AttachmentId}, FileName={FileName}")]
    public static partial void AttachmentDownloaded(
        this ILogger logger,
        string caseId,
        string attachmentId,
        string fileName);

    [LoggerMessage(
        EventId = 5003,
        Level = LogLevel.Information,
        Message = "Attachment deleted: CaseId={CaseId}, AttachmentId={AttachmentId}")]
    public static partial void AttachmentDeleted(
        this ILogger logger,
        string caseId,
        string attachmentId);

    [LoggerMessage(
        EventId = 5010,
        Level = LogLevel.Warning,
        Message = "Attachment blob not found: CaseId={CaseId}, AttachmentId={AttachmentId}, BlobPath={BlobPath}")]
    public static partial void AttachmentBlobNotFound(
        this ILogger logger,
        string caseId,
        string attachmentId,
        string blobPath);
}
```

## Attachment Metadata (Cosmos DB)

Attachment metadata is stored in Cosmos DB for querying; blob storage holds the actual content.

```csharp
public class AttachmentDocument
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("pk")]
    public string PartitionKey => CaseId;

    [JsonPropertyName("caseId")]
    public string CaseId { get; set; } = string.Empty;

    [JsonPropertyName("attachmentId")]
    public string AttachmentId { get; set; } = string.Empty;

    [JsonPropertyName("fileName")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("contentType")]
    public string ContentType { get; set; } = string.Empty;

    [JsonPropertyName("sizeBytes")]
    public long SizeBytes { get; set; }

    [JsonPropertyName("uploadedAt")]
    public DateTimeOffset UploadedAt { get; set; }

    [JsonPropertyName("uploadedBy")]
    public string UploadedBy { get; set; } = string.Empty;

    [JsonPropertyName("blobPath")]
    public string BlobPath { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type => "Attachment";
}
```

## Local Development with Azurite

> **Emulator setup**: See [azure-identity.md](azure-identity.md) for Azurite connection string patterns and Cosmos Emulator configuration.

```bash
# Start Azurite
azurite --silent --location ./azurite-data --blobHost 127.0.0.1

# Or via Docker
docker run -p 10000:10000 -p 10001:10001 -p 10002:10002 \
  mcr.microsoft.com/azure-storage/azurite
```

## Anti-Patterns

```csharp
// WRONG: Issuing SAS tokens (this is the SMS pattern, not CMS)
public async Task<string> GetAttachmentSasUri(string caseId, string attachmentId)
{
    var sasBuilder = new BlobSasBuilder { ... };
    return blobClient.GenerateSasUri(sasBuilder).ToString();
}

// WRONG: Creating BlobServiceClient per request (use singleton)
public async Task<IResult> DownloadAsync(string caseId)
{
    var client = new BlobServiceClient(uri, credential); // Creates connection each time!
    // ...
}

// WRONG: DefaultAzureCredential in production (see azure-identity.md for correct pattern)

// WRONG: Not validating case ownership before streaming
public async Task<IResult> DownloadAsync(string caseId, string attachmentId)
{
    // Missing case validation - anyone could download!
    var blobClient = container.GetBlobClient($"{caseId}/{attachmentId}");
    return Results.Stream(await blobClient.DownloadStreamingAsync());
}

// WRONG: Logging blob content or sensitive metadata
logger.LogInformation("Downloaded content: {Content}", stream); // Never log content!

// WRONG: No file size limits
await blobClient.UploadAsync(file.OpenReadStream()); // Could upload massive files!
```

## Performance Considerations

| Consideration | Recommendation |
|---------------|----------------|
| Large files | Consider chunked upload/download for files > 100MB |
| Concurrent downloads | Use `BlobDownloadOptions.Range` for partial downloads |
| Connection pooling | `BlobServiceClient` singleton handles this automatically |
| Memory pressure | Use streaming (`DownloadStreamingAsync`) not buffering (`DownloadContentAsync`) |

## Sources

- [Azure Blob Storage .NET SDK](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-dotnet)
- [Managed Identity for Azure Resources](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [BlobServiceClient Best Practices](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-client-management)
