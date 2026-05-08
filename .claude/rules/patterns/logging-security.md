---
paths:
  - "**/*.cs"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# Logging Security

## What to Log vs What NOT to Log

### NEVER Log These (Credentials & Secrets)

| Data Type | Example | Why Prohibited |
|-----------|---------|----------------|
| **Connection strings** | `Host=...;Password=...` | Contains database credentials |
| **JWT/Bearer tokens** | `eyJhbGciOiJIUzI1NiIs...` | Authentication bypass risk |
| **OAuth secrets** | Client secrets, refresh tokens | Credential theft |
| **API keys** | Azure, OpenAI, external service keys | Unauthorized service access |
| **Participant PII** | Real names, SSNs, contact details | Privacy violation |
| **Encryption keys** | DPAPI keys, signing keys | Decryption of protected data |

### SAFE to Log (Operational Data)

| Data Type | Example | Why Safe |
|-----------|---------|----------|
| **Case IDs** | `Guid` case/request IDs | Operational identifier |
| **User IDs** | Internal user GUIDs | Not PII by itself |
| **Request types** | `SubpoenaSummons`, `CourtOrder` | Case classification data |
| **Case events** | Status changes, workflow transitions, audit entries | Operational data |
| **Correlation IDs** | Trace identifiers | Required for debugging |
| **Request metadata** | HTTP method, path, status code | Standard telemetry |
| **Feature flags** | Flag names and values | Operational visibility |

### Sealed/Restricted Case Data -- Special Handling

Sealed, restricted, or privileged case data must NEVER appear in general logs:

| Never in General Logs | OK in Admin/Audit Logs |
|----------------------|------------------------|
| Sealed case content (court orders, juvenile records) | Case status change events |
| Legal hold details | Legal hold applied/removed events |
| Subpoena/warrant content | Subpoena served/acknowledged events |
| Attorney-client privileged communications | Communication event timestamps |
| Case participant SSNs or contact details | Participant role assignments |
| Agency internal investigation details | Agency interaction events |

## Logging Patterns

> **For structured logging patterns** (message templates, parameter naming, destructuring), see [patterns/dotnet-logging.md](patterns/dotnet-logging.md).

> **Security events — required identity fields**: any LENS structured event that records a security-significant action MUST include `CallerAppId`, `CallerTenantId`, `CallerObjectId` on BOTH success AND failure paths. Source these from `appContext.AuthContext.SubjectClaims.CurrentAppId` / `TenantId` / `GetClaim(OAuthClaimTypes.ObjectId)`. See `_dotnet/dotnet-auth.md` § "Security event identity requirements" for the full pattern + anti-pattern. Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 18.

### Safe Logging Examples

> Examples below show structured-event SHAPES; for the API see `_dotnet/dotnet-logging.md`. Data-selection rules apply to BOTH structured events (LENS-canonical) and raw `ILogger` paths (non-LENS / diagnostic). LENS services inject `MyServiceStructuredLogger` (the `[StructuredEventLogger]`-generated subclass), not `ILogger<T>` directly. See `lens-telemetry` skill Standards 4-7.

```csharp
// CORRECT: Case operational data — structured event (Geneva DGrep columns)
[StructuredEvent("CaseTransitionEvent")]
public sealed partial class CaseTransitionEvent : IStructuredLogEvent
{
    public string? CaseId { get; init; }
    public string? FromStage { get; init; }
    public string? ToStage { get; init; }
}

logger.LogEvent(new CaseTransitionEvent
{
    CaseId = caseId,
    FromStage = fromStage,
    ToStage = toStage,
});

// CORRECT: Operational update with actor — structured event
[StructuredEvent("DataCategoryUpdatedEvent")]
public sealed partial class DataCategoryUpdatedEvent : IStructuredLogEvent
{
    public string? DataCategoryId { get; init; }
    public string? CaseId { get; init; }
    public string? UserId { get; init; }
}

logger.LogEvent(new DataCategoryUpdatedEvent
{
    DataCategoryId = dataCategoryId,
    CaseId = caseId,
    UserId = userId,
});

// CORRECT: Auth metadata (NOT the token) — structured event
// For security-significant events, also include CallerAppId / CallerTenantId / CallerObjectId
// per `_dotnet/dotnet-auth.md` § "Security event identity requirements".
[StructuredEvent("RequestAuthenticatedEvent")]
public sealed partial class RequestAuthenticatedEvent : IStructuredLogEvent
{
    public string? UserId { get; init; }
    public string? Provider { get; init; }
}

logger.LogEvent(new RequestAuthenticatedEvent
{
    UserId = userId,
    Provider = authProvider,
});
```

### Dangerous Logging (NEVER Do This)

```csharp
// WRONG: Logging bearer token
logger.LogDebug("Auth header: {AuthHeader}", request.Headers.Authorization);

// WRONG: Logging connection string
logger.LogDebug("Database: {ConnectionString}", connectionString);

// WRONG: Logging participant contact information
logger.LogInformation("Participant {Email} added to case", participant.Email);

// WRONG: Logging entire objects that may contain secrets
logger.LogInformation("Configuration: {@Config}", configuration);

// WRONG: Sealed case data in general logs
logger.LogInformation("Sealed order content: {Content}", sealedOrder.Content);
```

## Response DTOs with Sensitive Fields

Mark sensitive properties to prevent accidental logging:

```csharp
using Destructurama.Attributed;

public record AuthResponse
{
    public required string UserId { get; init; }

    [NotLogged]  // NEVER log tokens
    public required string AccessToken { get; init; }

    public required DateTimeOffset ExpiresAt { get; init; }
}
```

## Exception Logging

```csharp
// WRONG: Exception message may contain connection strings
catch (Exception ex)
{
    logger.LogError(ex, "Database operation failed");
    // If ex.Message contains connection string, it's now in logs
}

// CORRECT (LENS-canonical): inherited ExceptionEvent — sanitized type + TraceId auto-correlation
catch (CosmosException ex)
{
    logger.LogEvent(new ExceptionEvent(ex)
    {
        // Add operationally meaningful context (NOT ex.Message)
        StatusCode = (int)ex.StatusCode,
        CaseId = caseId,
    });
}

// CORRECT (non-LENS / diagnostic): log exception type + sanitized context, NOT ex.Message
catch (CosmosException ex)
{
    logger.LogError(
        "Database operation failed: {StatusCode} for case {CaseId}",
        ex.StatusCode, caseId);
}
```

## Anti-Patterns

```csharp
// WRONG: Debug logging secrets even in development
#if DEBUG
logger.LogDebug("Token: {Token}", token);  // Still wrong!
#endif

// WRONG: Structured logging entire objects without [NotLogged]
logger.LogInformation("Request: {@Request}", request);
// Fine IF all sensitive properties have [NotLogged]
```

## Summary

| Data Type | Log It? |
|-----------|---------|
| Bearer/JWT tokens | NEVER |
| Connection strings | NEVER |
| OAuth secrets/API keys | NEVER |
| Participant PII (SSN, email, contact info) | NEVER |
| Sealed/restricted case data (in general logs) | NEVER |
| Case/Request IDs | YES |
| User IDs (GUIDs) | YES |
| Case events (status changes, audit entries) | YES |
| Correlation IDs | YES |
| Request metadata | YES |
