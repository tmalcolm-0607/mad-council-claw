---
paths:
  - "**/*.cs"
---

# C# Coding Patterns

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal C# coding conventions. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

This document defines mandatory C# coding patterns for the .NET codebase.

## 1. Using Statements Before Namespace

**Rule:** All `using` directives MUST be placed before the namespace declaration.

**Rationale:**
- Standard C# convention for file-scoped namespaces
- Enforced by project linters and hooks
- Consistent across entire codebase

**Correct:**
```csharp
using System;
using System.Text.Json.Serialization;

namespace MyApp.Common;

public class Example { }
```

**Incorrect:**
```csharp
namespace MyApp.Common;

using System;
using System.Text.Json.Serialization;

public class Example { }
```

## 2. Explicit Enum Numbering

**Rule:** All enum members MUST have explicit numeric values assigned.

**Rationale:**
- Prevents reordering bugs when enum members are added or removed
- Makes serialized values stable across code changes
- Ensures database/API compatibility when enum values are persisted

**Correct:**
```csharp
public enum Status
{
    Active = 0,
    Inactive = 1,
    Pending = 2
}
```

**Incorrect:**
```csharp
public enum Status
{
    Active,      // Implicitly 0
    Inactive,    // Implicitly 1
    Pending      // Implicitly 2
}
```

## 3. Centralized Property Name Constants

**Rule:** JSON property names used in `[JsonPropertyName]` attributes SHOULD be defined as constants in the `PropertyNames` class.

**Rationale:**
- Avoids string duplication and typos
- Enables compile-time checking of property names
- Makes property name changes easier to track

**Correct:**
```csharp
[JsonPropertyName(PropertyNames.Common.Id)]
public string Id { get; init; }
```

**Incorrect:**
```csharp
[JsonPropertyName("id")]
public string Id { get; init; }
```

## 4. Code Coverage Requirements

**Rule:** All code changes MUST maintain at least 90% code coverage before PR approval.

**Rationale:**
- High coverage ensures comprehensive testing
- Reduces regression risk when code changes
- Required gate for all PRs in the .NET codebase

**Commands:**
```bash
# Run tests with coverage collection
dotnet test src/MyApp.sln --collect:"XPlat Code Coverage"

# Generate coverage report (requires reportgenerator tool)
reportgenerator -reports:**/coverage.cobertura.xml -targetdir:coveragereport
```

**Enforcement:**
- PRs with coverage below 90% will be rejected
- New code must have corresponding unit tests
- Critical paths (error handling, validation) require explicit test coverage

## Enforcement

| Pattern | Status |
|---------|--------|
| Using statements outside namespace | REJECT |
| Enum without explicit values | REJECT |
| Hardcoded JsonPropertyName strings | WARN |
| Code coverage below 90% | REJECT |
| Global `<NoWarn>` for security analyzers | REJECT |

---

## Global Warning Suppression Prohibition

NEVER add warning codes to `<NoWarn>` in `.csproj` or `Directory.Build.props` globally. Use `#pragma warning disable` at the specific callsite with a justifying comment instead.

Security-critical analyzer codes that MUST NEVER appear in global `<NoWarn>`:
- `CA5359` / `CA5360` - Certificate validation disabled
- `CA2100` - SQL injection
- `CA5394` - Weak random number generator
- `CA3075` - DTD processing
- `CA5350` / `CA5351` - Weak cryptographic algorithm

```csharp
// BAD: global suppression hides all occurrences
<NoWarn>$(NoWarn);CA5359</NoWarn>

// GOOD: scoped suppression at the specific callsite
#pragma warning disable CA5359 // Do not disable certificate validation - test environment only
httpClientHandler.ServerCertificateCustomValidationCallback = (_, _, _, _) => true;
#pragma warning restore CA5359
```

Anti-pattern: Adding `CS1574` and `CS1570` to global `<NoWarn>` to paper over broken `<see cref>` references instead of fixing the references.

---

## Project Build Strictness

**Rule:** All LENS service projects MUST enable `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` in `Directory.Build.props`.

```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
</PropertyGroup>
```

This is the enforcement complement to the `<NoWarn>` prohibition above: don't suppress warnings silently — make them break the build.

**Local-only NU1900 exemption** (per project root `CLAUDE.md`): the Enzyme NuGet feed requires ADO auth, producing NU1900 vulnerability-data warnings on local builds. Allow via:
```xml
<PropertyGroup>
  <NoWarn>NU1900</NoWarn>
  <WarningsNotAsErrors>NU1900</WarningsNotAsErrors>
  <NuGetAudit>false</NuGetAudit>
</PropertyGroup>
```
This is the documented exception to the global no-NoWarn rule.

**Enforcement:**

| Pattern | Status |
|---------|--------|
| Missing `TreatWarningsAsErrors` in build | **WARN** |
| `TreatWarningsAsErrors=false` | **REJECT** |
| Global `<NoWarn>` covering codes other than NU1900 | **REJECT** |
