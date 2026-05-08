---
paths:
  - "**/*.cs"
  - "**/Models/**"
  - "**/DTOs/**"
  - "**/Entities/**"
  - "**/Contracts/**"
  - "**/DataModels/**"
---

# .NET Domain Model Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for domain entities, DTOs, and model design.

## Entity Base Classes

```csharp
public abstract class CosmosEntity : IEntity, IVersioned
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("type")] public abstract string Type { get; }
    [JsonPropertyName("_etag")] public string? ETag { get; set; }
}

public abstract class AuditableEntity : CosmosEntity, IAuditable
{
    [JsonPropertyName("createdAt")] public DateTimeOffset CreatedAt { get; set; }
    [JsonPropertyName("modifiedAt")] public DateTimeOffset ModifiedAt { get; set; }
    [JsonPropertyName("createdBy")] public string? CreatedBy { get; set; }
    [JsonPropertyName("modifiedBy")] public string? ModifiedBy { get; set; }
}
```

---

## DTO Requirements

| Rule | Requirement |
|------|-------------|
| **Sealed** | All DTOs must be `sealed` |
| **Required** | Mandatory fields use `required` modifier |
| **Init-only** | Use `init` over `set` for immutability |

```csharp
public sealed class CreateCaseRequest
{
    required public CaseKind CaseKind { get; init; }
    required public string Jurisdiction { get; init; }
    public Dictionary<string, string>? Metadata { get; init; }  // Optional
}
```

---

## LENS Structured Events (Geneva-Bound)

LENS services emit Geneva-bound structured events via the `[StructuredEvent]` source-generator pattern. Event classes are domain models — they live alongside DTOs and entities — and follow specific shape rules so the resulting Geneva tables are DGrep-queryable.

Cite: `lens-telemetry` SKILL.md v1.3.0 Standards 5 (lines 202-241), 16 (498-503).

### Event class shape

```csharp
// ✓ CORRECT — Geneva-bound event class
[StructuredEvent("FooLookupCompletedEvent")]   // table name in Geneva
public sealed partial class FooLookupCompletedEvent : IStructuredLogEvent
{
    // Every value you need to filter on in DGrep MUST be its own property.
    public required string CaseId { get; init; }
    public required string LookupType { get; init; }
    public required string Outcome { get; init; }   // "Success" | "NotFound" | "RateLimited" | ...
    public required DateTimeOffset OccurredAt { get; init; }
    public int? ResultCount { get; init; }
    public long? DurationMs { get; init; }

    // Optional: short human-readable summary (Detail) is fine as a SECONDARY field —
    // never the primary carrier of filterable data.
    public string? Detail { get; init; }
}
```

| Rule | Requirement |
|------|-------------|
| **Sealed + partial** | `sealed partial class` — generator emits `GetProperties()`; missing `partial` = LENS0001 |
| **Marker interface** | Implements `IStructuredLogEvent` |
| **Table name unique** | `[StructuredEvent("...")]` table name unique across the service AND not colliding with shared tables (`InboundQOSEvent`, `OutboundQOSEvent`, `ExceptionEvent`) |
| **Init-only required props** | Use `required` + `init` for mandatory fields; nullable for optional |
| **No catch-all `Detail`** | A short prose `Detail` is fine; pipe-delimited `Key=value\|Key2=value2` strings are NOT. Each filterable key is its own property. |
| **No CorrelationId/TraceId/SpanId** | Auto-enriched by the OTel pipeline — explicit properties duplicate columns in DGrep |

### No catch-all Detail strings

DGrep cannot filter on substrings within a column — only on full column values. `$"Key={value}|Key2={value2}"` as a single field is unfilterable.

```csharp
// ✗ WRONG — pipe-delimited Detail; cannot filter on individual keys in DGrep
[StructuredEvent("FooLookupCompletedEvent")]
public sealed partial class FooLookupCompletedEvent : IStructuredLogEvent
{
    public required string Detail { get; init; }   // "CaseId=ABC|LookupType=Subpoena|Outcome=Success"
}

// ✓ CORRECT — every filterable value is its own property
[StructuredEvent("FooLookupCompletedEvent")]
public sealed partial class FooLookupCompletedEvent : IStructuredLogEvent
{
    public required string CaseId { get; init; }
    public required string LookupType { get; init; }
    public required string Outcome { get; init; }
}
```

### Logger pairing

Event classes pair with the service-specific `[StructuredEventLogger]` class — both must live in the **same assembly** so the source generator emits the matching `LogEvent(T)` overload. See `lens-aspnet-structure/references/handler-pattern.md` for emission patterns and `_dotnet/dotnet-logging.md` for the generator requirements.

### Don't redefine inherited events

The `LensStructuredLogger` base ships `InboundQOSEvent`, `OutboundQOSEvent`, `ExceptionEvent`, `CosmosDbDiagnosticsEvent`, `OAuthSecurityEvent`. Don't redefine these in your service — the source generator throws or the records collide in Geneva.

---

## Case ID Format

Format: `LNS-{epochSeconds}-{suffix}` (21 chars)

```csharp
public static string Generate()
{
    var epochSeconds = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    var suffix = GenerateRandomSuffix(6);  // Alphanumeric
    return $"LNS-{epochSeconds}-{suffix}";  // e.g., LNS-1738540800-A1B2C3
}
```

---

## Pagination Pattern

```csharp
public sealed class PagedRequest
{
    public int PageSize { get; init; } = 100;
    public string? ContinuationToken { get; init; }
}

public sealed class PagedResult<T>
{
    required public IReadOnlyList<T> Items { get; init; }
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults { get; init; }
}
```

---

## JSON Serialization

```csharp
// Always use explicit JsonPropertyName
[JsonPropertyName("caseId")] public string CaseId { get; init; }

// String enum serialization for Cosmos compatibility
[JsonConverter(typeof(JsonStringEnumConverter<WorkflowStage>))]
public enum WorkflowStage { Intake = 0, Triage = 1, Fulfillment = 2 }
```

---

## Cosmos Document Requirements

```csharp
public class Case : AuditableEntity, IPartitioned
{
    public override string Type => "case";

    [JsonPropertyName("caseId")] public string CaseId { get; set; }

    [JsonIgnore] public string PartitionKey => CaseId;
}
```

---

## Error Codes

```csharp
public static class ErrorCodes
{
    public const string BadRequest = "BadRequest";
    public const string NotFound = "NotFound";
    public const string CaseNotFound = "CaseNotFound";
    public const string InvalidCaseIdFormat = "InvalidCaseIdFormat";
}
```

---

## Enforcement

| Pattern | Status |
|---------|--------|
| Non-sealed DTO | WARN |
| Missing `[JsonPropertyName]` | WARN |
| Integer enum in Cosmos | REJECT |
| Entity without `Type` | REJECT |
| Hard-coded error string | REJECT |

---

## Enum Serialization Breaking Changes

Adding `[JsonConverter(typeof(JsonStringEnumConverter))]` to an existing enum is a BREAKING CHANGE -- wire format changes from integer to string.

Rules:
- Before adding `JsonStringEnumConverter`, verify ALL downstream consumers accept string format
- When renaming enum members, ALWAYS add `[JsonStringEnumMemberName("oldName")]` for backward compatibility with existing Cosmos documents
- When a shared contract enum needs both formats, implement `FlexibleEnumConverter<T>` that accepts both integer and string

Anti-pattern: Adding `JsonStringEnumConverter` to `ProcessingStatus` while DCS sends integers. Runtime 400 Bad Request.

---

## Domain vs Presentation Boundary

LENS services have three distinct model families. Each lives in exactly one layer; cross-boundary flow is mediated by an explicit factory.

| Family | Lives in | Visible to | Purpose |
|--------|----------|-----------|---------|
| **Common domain types** (`Foo`, `Case`) | `Common/` | All four data-flow layers | Internal representation; the lingua franca between handler and repository |
| **Presentation types** (`FooResponse`, `CaseRecord`) | `API/Presentation/` | API layer ONLY | External HTTP contract; external clients deserialize these |
| **Inter-service contract types** (`Microsoft.LENS.Common.DataModels.*`) | NuGet package | API layer (inbound) + DataAccess layer (outbound) | Cross-service boundary; handler must NEVER see these (see `dotnet-architecture.md` § DataModels Boundary Rule) |

**Mapping discipline:** the API layer uses **`IPresentationModelFactory`** (see `dotnet-mvc-controllers.md` § IPresentationModelFactory Pattern) to convert domain → presentation. Handlers and repositories work in domain types only; a presentation type appearing in `BusinessLogic/` or `DataAccess/` is a Phase-2 boundary violation per `lens-aspnet-structure` Standard 7.

---

## Shared Contract DTO Restrictions

Shared contract DTOs (in `DataModels`, `Contracts`, or packages consumed by other services) MUST NOT include:
- `[JsonExtensionData]` -- leaks Cosmos internals (`_ts`, `_self`, `_rid`) into API responses
- Cosmos metadata properties (`_etag`, `partitionKey`, `id` as Cosmos doc ID)
- `init` accessors when existing contracts use `set` (breaks downstream deserialization)

When modifying serialization attributes on shared DTOs, verify with ALL downstream consumers.
