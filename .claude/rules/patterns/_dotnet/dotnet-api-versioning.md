---
paths:
  - "**/*.cs"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# API Versioning Patterns

All endpoints use explicit version prefixes in routes.

## Rule

| Check | Status |
|-------|--------|
| Endpoints use `v1/` version prefix | REJECT if missing |
| Version in route attribute | REJECT if hardcoded without prefix |
| Consistent versioning across controllers | WARN if mixed |

## Correct

```csharp
// Controller with versioned route
[ApiController]
[Route("v1/cases")]
public class CasesController : ControllerBase { }

// Route groups for Minimal APIs (if needed)
var v1 = app.MapGroup("v1");
v1.MapGet("/health", () => Results.Ok());
```

## Wrong

```csharp
// Missing version prefix
[Route("cases")]
public class CasesController : ControllerBase { }

// Inconsistent versions
[Route("v1/cases")]  // v1
[Route("users")]     // no version
```

## Version Matrix

| Version | Path | Status |
|---------|------|--------|
| v1 | `v1/*` | Current |
| v2 | `v2/*` | Future (when breaking changes needed) |

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| No version prefix | Add `v1/` |
| Query string versioning | Use URL path versioning |
| Header versioning | Use URL path versioning |
