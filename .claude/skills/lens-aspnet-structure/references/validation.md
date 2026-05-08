# Validation Layers Reference

> Three-level validation in LENS services. Each level has exactly one owner. The same thing is never validated twice.

---

## The Three Levels

| Level | Where | Tool | Validates |
|-------|-------|------|-----------|
| **1. Parameter Contracts** | Every constructor and method entry point | `ParameterContracts` (Core) | Dependencies and arguments are non-null / non-empty |
| **2. Request Validation** | API Layer — request model classes | DataAnnotations attributes | Incoming request is well-formed (shape, format, range) |
| **3. Configuration Validation** | Startup | DataAnnotations + `IValidatableObject` + `.ValidateDataAnnotations().ValidateOnStart()` | Required config values are present and valid before serving traffic |
| *(Business Violations)* | BusinessLogic Layer | `HandlerException` subclass | Operation is semantically allowed (not a "level" — throws a typed exception, never validates inline) |

**The rule:** Validate at entry points. Never validate the same thing twice. DataAccess trusts the layers above it completely and performs no validation of its own.

---

## Level 1: Parameter Contracts

Apply in every constructor and at the entry point of every public method that receives external input.

```csharp
// ✅ GOOD — every dependency checked at construction time
public sealed class FooHandler : IFooHandler
{
    private readonly IFooRepository repository;
    private readonly ILogger<FooHandler> logger;

    public FooHandler(
        IFooRepository repository,
        ILogger<FooHandler> logger)
    {
        ParameterContracts.CheckIsNotNull(repository, nameof(repository));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.repository = repository;
        this.logger = logger;
    }
}
```

| Method | Guards against |
|--------|---------------|
| `CheckIsNotNull(value, name)` | Null reference or value |
| `CheckNonWhitespace(value, name)` | Null, empty, or whitespace string |
| `CheckIsGuidEmpty(value, name)` | `Guid.Empty` |
| `Check(boolExpr, name, message)` | Any boolean assertion |

---

## Level 2: Request Validation (API Layer)

Use **DataAnnotations attributes** directly on API request model classes. ASP.NET Core validates annotated models automatically when `[ApiController]` is present — a failed model state returns HTTP 400 with field-level errors before the controller action executes. No FluentValidation.

```csharp
// ✅ GOOD — API/Models/CreateRequestModel.cs
public sealed class CreateRequestModel
{
    [Required(ErrorMessage = "ReferenceNumber is required.")]
    [MaxLength(100, ErrorMessage = "ReferenceNumber must not exceed 100 characters.")]
    [RegularExpression(@"^[A-Za-z0-9\-]+$", ErrorMessage = "ReferenceNumber may only contain letters, digits, and hyphens.")]
    public string ReferenceNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "Subject is required.")]
    [MaxLength(500, ErrorMessage = "Subject must not exceed 500 characters.")]
    public string Subject { get; set; } = string.Empty;

    [Required(ErrorMessage = "ReceivedAt is required.")]
    public DateTimeOffset ReceivedAt { get; set; }

    [Required(ErrorMessage = "At least one data category is required.")]
    [MinLength(1, ErrorMessage = "At least one data category is required.")]
    public List<string> DataCategories { get; set; } = [];
}
```

### Commonly used attributes

| Attribute | Validates |
|-----------|-----------|
| `[Required]` | Not null; strings not empty |
| `[MaxLength(n)]` | String or collection length upper bound |
| `[MinLength(n)]` | String or collection length lower bound |
| `[StringLength(max, MinimumLength = min)]` | Both bounds in one attribute |
| `[Range(min, max)]` | Numeric range |
| `[EmailAddress]` | Valid e-mail format |
| `[RegularExpression(pattern)]` | Custom regex |
| `[Url]` | Valid URL format |

Always provide `ErrorMessage` — the default messages are not user-friendly.

### Cross-property validation

For rules that span multiple fields, implement `IValidatableObject` on the request model:

```csharp
public sealed class DateRangeRequestModel : IValidatableObject
{
    [Required]
    public DateTimeOffset? StartDate { get; set; }

    public DateTimeOffset? EndDate { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (StartDate.HasValue && EndDate.HasValue && EndDate < StartDate)
            yield return new ValidationResult(
                "EndDate must be on or after StartDate.",
                [nameof(EndDate)]);
    }
}
```

`IValidatableObject.Validate` is called by ASP.NET Core after all attribute checks pass — no additional wiring needed.

### What DataAnnotations does NOT validate

DataAnnotations validates **shape and format** only — field presence, length, pattern, and range. It does not validate business rules (whether the operation is allowed). Business rule violations belong in BusinessLogic as typed `HandlerException` throws.

---

## Level 3: Configuration Validation (Startup)

Config classes use DataAnnotations attributes and are registered with `.ValidateDataAnnotations().ValidateOnStart()` so the application throws at startup with a clear message if any value is missing or out of range.

```csharp
// ✅ GOOD — Common/Configuration/CosmosDbSettingsOptions.cs
public sealed class CosmosDbSettingsOptions
{
    public const string ConfigSectionKey = "ExternalServices:CosmosDb";

    [Required(ErrorMessage = "ExternalServices:CosmosDb:AccountEndpoint is required.")]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required(ErrorMessage = "ExternalServices:CosmosDb:DatabaseName is required.")]
    public string DatabaseName { get; set; } = string.Empty;

    [Required(ErrorMessage = "ExternalServices:CosmosDb:ContainerName is required.")]
    public string ContainerName { get; set; } = string.Empty;
}
```

**Registration in DependencyInjection layer:**

```csharp
// ✅ GOOD — fail fast with a clear message before serving traffic
services.AddOptions<CosmosDbSettingsOptions>()
    .Bind(configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart();

// ❌ BAD — silently binds; missing values go undetected until first use
services.Configure<CosmosDbSettingsOptions>(
    configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey));
```

### Complex configuration validation

When validation rules span multiple properties or cannot be expressed with attributes, implement `IValidatableObject`:

```csharp
public sealed class AccountCreationOptions : IValidatableObject
{
    public const string SectionName = "AccountCreation";

    [Range(1, 60, ErrorMessage = "AccountCreation:CodeTTLMinutes must be between 1 and 60.")]
    public int CodeTTLMinutes { get; set; } = 5;

    [Range(1, 300, ErrorMessage = "AccountCreation:CosmosContainerTTLSeconds must be between 1 and 300.")]
    public int CosmosContainerTTLSeconds { get; set; } = 300;

    public bool RequireOfficialDomain { get; set; } = true;
    public List<string> AllowedEmailDomains { get; set; } = [".gov"];

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (CosmosContainerTTLSeconds < CodeTTLMinutes * 60)
            yield return new ValidationResult(
                "AccountCreation:CosmosContainerTTLSeconds must be >= CodeTTLMinutes × 60.",
                [nameof(CosmosContainerTTLSeconds)]);

        if (RequireOfficialDomain && AllowedEmailDomains.Count == 0)
            yield return new ValidationResult(
                "AccountCreation:AllowedEmailDomains must contain at least one domain when RequireOfficialDomain is true.",
                [nameof(AllowedEmailDomains)]);
    }
}
```

`.ValidateDataAnnotations()` invokes both attribute checks and `IValidatableObject.Validate` at startup — no separate registration needed.

---

## Business Validation (BusinessLogic Layer — Not a Level)

Business rule violations are expressed as scenario-named `HandlerException` subclasses thrown by the handler. The controller catches these by type and decides the HTTP response — there is no `HttpStatusCode` on the exception.

```csharp
// ✅ GOOD — throw a scenario-named HandlerException subclass
public async Task<Foo> CreateFooAsync(Guid partitionId, Foo foo)
{
    var existing = await this.dataStore.GetFooByNameAsync(partitionId, foo.Name);
    if (existing is not null)
        throw new FooDuplicateNameException($"A foo named '{foo.Name}' already exists.");

    // ... proceed
}

// ❌ BAD — wrong exception type; controller cannot route it to a known HTTP response
if (existing is not null)
    throw new InvalidOperationException("Duplicate foo name.");

// ❌ BAD — HttpStatusCode on HandlerException leaks protocol concerns into BusinessLogic
if (existing is not null)
    throw new FooHandlerException("Duplicate foo name.", HttpStatusCode.BadRequest);
```

Business validation is distinct from the three levels above: it is not about shape or format, but about whether the operation is semantically allowed given the current system state. It belongs exclusively in BusinessLogic handlers and is never re-checked in DataAccess.

> Exception hierarchy, wrapping patterns, and controller catch examples:
> [handler-pattern.md](handler-pattern.md) | [exception-handling-reference.md](exception-handling-reference.md)

---

## What Each Layer Does NOT Validate

| Layer | Does NOT validate |
|-------|-----------------|
| `API` | Business rules — whether the operation is semantically allowed |
| `BusinessLogic` | Input shape — null/format checks on request fields belong in Level 2 (DataAnnotations) |
| `DataAccess` | Anything — it trusts the layers above it completely |
