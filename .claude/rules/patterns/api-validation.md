---
paths:
  - "**/*.cs"
---

# API Validation Patterns (LENS-canonical)

LENS services validate inbound API requests via **DataAnnotations + `[ApiController]`**. The framework auto-validates `ModelState` on every request; invalid requests never reach the action body and are returned as 400 with structured errors.

Cite: `lens-aspnet-structure/references/validation.md:54` — Level 2 (controller boundary) = DataAnnotations + `[ApiController]`. **No FluentValidation.**

> The pre-LENS FluentValidation primary path is **deprecated as of 2026-05-08** per user directive — the kit serves LENS consumers exclusively. Migration: replace `AbstractValidator<T>` classes + `validator.ValidateAsync` calls with DataAnnotation attributes on the request DTO; remove the FluentValidation packages.

---

## Rule

| Check | Status |
|-------|--------|
| Controller has `[ApiController]` (auto-validates ModelState) | **REQUIRED** |
| Request DTO uses DataAnnotation attributes (`[Required]`, `[StringLength]`, `[Range]`, `[RegularExpression]`) | **REQUIRED** |
| Manual `if (string.IsNullOrEmpty(...))` checks for fields covered by `[Required]` | **REJECT** (redundant with framework) |
| FluentValidation `AbstractValidator<T>` / `IValidator<T>` injection | **REJECT** (non-canonical for LENS) |
| Cross-field business rules that need state | Implement as `IValidatableObject` on the DTO **or** validate in the BusinessLogic handler and throw `ServiceValidationException` |

---

## Pattern: DataAnnotations on the DTO

```csharp
public sealed class CreateCaseRequest
{
    [Required(ErrorMessage = "Case title is required.")]
    [StringLength(500, MinimumLength = 1)]
    public string Title { get; init; } = string.Empty;

    [Required]
    [RegularExpression(@"^\d{3}-\d{3}-\d{3}$", ErrorMessage = "CaseId must be in format XXX-XXX-XXX.")]
    public string CaseId { get; init; } = string.Empty;

    [Required]
    [EnumDataType(typeof(RequestType))]
    public RequestType RequestType { get; init; }
}
```

The `[ApiController]` attribute on the controller (or `ApiControllerBase`) makes ModelState validation automatic — invalid requests return RFC 7807 `ValidationProblemDetails` with HTTP 400 before the action body executes.

```csharp
[ApiController]
[Route("api/v1/cases")]
public sealed class CasesController(ICaseHandler handler) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CreateAsync(CreateCaseRequest request, CancellationToken ct)
    {
        // ModelState already validated — invalid requests never reach this body.
        var domain = await handler.CreateAsync(request, ct);
        return CreatedAtAction(nameof(GetAsync), new { id = domain.Id }, domain);
    }
}
```

---

## Pattern: `IValidatableObject` for cross-field checks (no DI)

When a validation rule depends on multiple fields of the same DTO (e.g. "EndDate must be after StartDate"), implement `IValidatableObject`:

```csharp
public sealed class DateRangeRequest : IValidatableObject
{
    [Required]
    public DateTimeOffset StartDate { get; init; }

    [Required]
    public DateTimeOffset EndDate { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (this.EndDate <= this.StartDate)
        {
            yield return new ValidationResult(
                "EndDate must be after StartDate.",
                new[] { nameof(this.EndDate) });
        }
    }
}
```

`IValidatableObject.Validate` runs after attribute-level validation passes, as part of the same auto-validation pass. Still no FluentValidation, no `IValidator<T>`.

---

## Pattern: Cross-API validation belongs in the handler

If a validation rule requires a downstream service call (e.g. "verify CaseId exists in Case Management API"), that rule does **not** belong in the validation layer — it belongs in the BusinessLogic handler. The handler performs the lookup and throws a typed `HandlerException` subclass (e.g. `CaseNotFoundException`) on failure; the controller's catch-ladder maps it to the right status code.

See `_dotnet/dotnet-error-handling.md` for the canonical exception hierarchy.

```csharp
// Handler
public async Task<Case> CreateAsync(CreateCaseRequest req, CancellationToken ct)
{
    var existing = await this.caseClient.FindAsync(req.CaseId, ct);
    if (existing is not null)
    {
        this.logger.CaseAlreadyExists(req.CaseId);
        throw new CaseAlreadyExistsException(req.CaseId);
    }
    // ... create logic
}
```

This separates **request shape validation** (DataAnnotations, `IValidatableObject`) from **business rule validation** (handler + typed exception). The HTTP status code comes from the exception type, not from a validator.

---

## Anti-Patterns

| Anti-Pattern | Why | Fix |
|---|---|---|
| `AbstractValidator<T>` + `IValidator<T>` injection | Non-canonical for LENS; introduces a validation layer the framework already provides | Use DataAnnotations on the DTO + `[ApiController]` for auto-validation |
| `validator.ValidateAsync(request, ct)` in controller action | Auto-validation already ran before the body — redundant | Delete the call; trust `ModelState` |
| `if (string.IsNullOrEmpty(request.Title))` in controller for fields with `[Required]` | Duplicate of framework validation; drifts when `[Required]` changes | Delete the check; rely on `[Required]` |
| Throwing `ValidationException` from controller for shape violations | Bypasses the framework's `ValidationProblemDetails` formatting | Let `[ApiController]` return 400; for cross-field rules use `IValidatableObject` |
| Cross-API existence check in a validator | Validators run on every request, including invalid ones — wasteful + adds latency to error responses | Move to handler; throw typed `HandlerException` |
| Adding `nuget.org` or `FluentValidation.*` packages to a LENS service | Non-canonical; flagged by `lens-standards-audit` | Remove; replace with DataAnnotations |

---

## Migration from FluentValidation (legacy)

| Step | Before | After |
|---|---|---|
| 1. Replace validator class with attributes | `class CreateCaseRequestValidator : AbstractValidator<CreateCaseRequest>` with `RuleFor(x => x.Title).NotEmpty().Length(1, 500)` | `[Required] [StringLength(500, MinimumLength = 1)] public string Title { get; init; }` on the DTO |
| 2. Drop `IValidator<T>` injection | `IValidator<CreateCaseRequest> validator` constructor parameter + `validator.ValidateAsync(...)` call | Delete; rely on `[ApiController]` auto-validation |
| 3. Move cross-API rules to handler | `RuleFor(x => x.CaseId).MustAsync(async (id, ct) => await caseClient.ExistsAsync(id, ct))` | Handler call + `throw new CaseNotFoundException(id)` on miss |
| 4. Move cross-field rules to `IValidatableObject` | `RuleFor(x => x.EndDate).GreaterThan(x => x.StartDate)` | `IValidatableObject.Validate` returning `new ValidationResult(...)` |
| 5. Delete `FluentValidation.*` package references | `dotnet add package FluentValidation` + `AddValidatorsFromAssemblyContaining<...>()` | Remove the packages and the `AddValidators...` registration |

---

## See also

- `_dotnet/dotnet-mvc-controllers.md` — `[ApiController]` + `ApiControllerBase` patterns
- `_dotnet/dotnet-error-handling.md` — `HandlerException` hierarchy + controller catch-ladder for business-rule failures
- `lens-aspnet-structure/references/validation.md` — canonical 4-level validation model (DI ✓ Options validation, controller-boundary ✓ DataAnnotations, business rules ✓ handler exceptions, infra ✓ Cosmos ETag)
