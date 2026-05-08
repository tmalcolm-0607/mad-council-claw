---
paths:
  - "**/*.cs"
  - "**/Program.cs"
  - "**/Startup.cs"
  - "**/appsettings*.json"
  - "**/spec.md"
  - "**/plan.md"
---

# .NET Security Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical security patterns (Managed Identity, security headers, input validation, exception sanitization via `GlobalErrorHandlingMiddleware`). The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for security implementation in .NET projects.

## Managed Identity Over Connection Strings

```csharp
// CORRECT: Managed Identity
services.AddSingleton(_ => new BlobServiceClient(
    new Uri("https://account.blob.core.windows.net"),
    new DefaultAzureCredential()));

// WRONG: Connection string with password
options.UseSqlServer("Server=...;Password=SECRET;");
```

---

## Middleware Order (Critical)

```csharp
app.UseExceptionHandler("/error");  // 1. Outermost
app.UseHttpsRedirection();          // 3. HTTPS
app.UseSecurityHeaders();           // 4. Security headers
app.UseCors("AllowedOrigins");      // 5. CORS
app.UseRateLimiter();               // 6. Rate limit BEFORE auth
app.UseAuthentication();            // 7. Establish identity
app.UseAuthorization();             // 8. Enforce access
app.MapControllers();               // 9. Endpoints
```

**Key**: Rate limit before auth (protect auth endpoints), authentication before authorization.

---

## Health Endpoints

LENS health endpoint conventions (route, auth posture, status mapping) are defined by the `lens-aspnet-structure` skill — they are not duplicated here. Consult that skill's SKILL.md before adding or modifying a health endpoint. Consumer-specific authentication patterns for health probes (e.g., header-validation filters tied to the hosting platform) are kit-extras, not LENS-canonical; this file documents only the LENS-canonical surface.

---

## Rate Limiting

```csharp
services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            ctx.User?.Identity?.Name ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 100, Window = TimeSpan.FromMinutes(1) }));
});
```

---

## Sanitized Error Responses

LENS services do NOT implement a `SanitizedException` hierarchy. Sanitized error responses are produced by `GlobalErrorHandlingMiddleware`, which is registered automatically by `AddLensTelemetry<TLogger>()`. Throw typed `HandlerException` subclasses from handlers; the middleware maps them to the correct HTTP status and emits a sanitized `ProblemDetails` body — stack traces and internal exception messages are never exposed to callers. See `dotnet-error-handling.md` for the canonical exception hierarchy and middleware behaviour.

---

## Security Headers

```csharp
headers["X-Frame-Options"] = "DENY";
headers["X-Content-Type-Options"] = "nosniff";
headers["X-XSS-Protection"] = "1; mode=block";
headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
headers["Content-Security-Policy"] = "default-src 'self';";
```

---

## Input Validation

```csharp
public class CreateUserRequest
{
    [Required, StringLength(100, MinimumLength = 1)]
    public required string Name { get; init; }

    [Required, EmailAddress, StringLength(256)]
    public required string Email { get; init; }
}
```

---

## Enforcement

| Rule | Severity |
|------|----------|
| Connection string with password | **REJECT** |
| Auth before rate limiter | **REJECT** |
| Internal exception exposed | **REJECT** |
| Missing input validation | **REJECT** |
| Hardcoded secrets | **REJECT** |
| CORS `AllowAnyOrigin()` | **REJECT** |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| UseAuthorization() before UseAuthentication() | Auth context not available |
| Returning `exception.ToString()` | Throw a typed `HandlerException` subclass — `GlobalErrorHandlingMiddleware` (registered by `AddLensTelemetry`) sanitizes the 500 response automatically. See `dotnet-error-handling.md`. |
| `[AllowAnonymous]` on sensitive endpoints | Remove or justify |
| No rate limiting on auth | Brute force protection |
