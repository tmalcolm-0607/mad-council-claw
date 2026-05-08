# API Contracts: [FEATURE NAME]

**Purpose**: Define explicit interfaces between modules to ensure consistency across implementation.
**Input**: Entities from `data-model.md`, user stories from `spec.md`

---

## Module Interfaces

> **IMPORTANT**: These interfaces are the source of truth. All generated code MUST match these signatures exactly. Tests and mocks MUST target these exact method names and return types.

### [Module Name 1]

**File**: `src/[path]/I[ModuleName].cs`
**Purpose**: [Brief description of what this module does]

```csharp
public interface I[ModuleName]
{
    ReturnType [MethodName](Type1 param1, Type2? param2 = null);
    Task<ReturnType> [AnotherMethodAsync](Type param, CancellationToken cancellationToken = default);
}
```

**Method Details**:

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `[MethodName]` | `Type1 param1, Type2? param2 = null` | `ReturnType` | [What it does] |
| `[AnotherMethodAsync]` | `Type param, CancellationToken ct` | `Task<ReturnType>` | [What it does] |

---

### [Module Name 2] (e.g. Adapter / Fake)

**File**: `src/[path]/I[AdapterName].cs`
**Purpose**: [Brief description]

```csharp
public interface I[AdapterName]
{
    Task<ResponseType> [RequiredMethodAsync](PayloadType payload, CancellationToken cancellationToken = default);
}
// Fake/mock implementation location (example): tests/[path]/[AdapterName]Fake.cs — MUST implement the same interface.
```

**Contract Notes**:

- Real and fake implementations MUST implement these exact methods
- Method names are case-sensitive; signatures must remain stable

---

## REST API Endpoints

> For web APIs, define endpoints here. Generated route handlers MUST match these paths and methods.

### [Resource] Endpoints

| Method | Path | Request Body | Response | Description |
|--------|------|--------------|----------|-------------|
| GET | `/api/[resource]` | - | `[Resource][]` | List all |
| GET | `/api/[resource]/{id}` | - | `[Resource]` | Get by ID |
| POST | `/api/[resource]` | `Create[Resource]Dto` | `[Resource]` | Create new |
| PUT | `/api/[resource]/{id}` | `Update[Resource]Dto` | `[Resource]` | Update |
| DELETE | `/api/[resource]/{id}` | - | `void` | Delete |

---

## Event Contracts

> For event-driven systems, define events and their payloads.

### [Event Name]

```csharp
public sealed record [EventName]Event(
    string Type,
    [EventPayloadType] Payload,
    DateTimeOffset Timestamp);
```

---

## Schema Validation

> Reference JSON schemas that validate API responses.

| Schema | Location | Validates |
|--------|----------|-----------|
| `[response].schema.json` | `schemas/` | [What it validates] |

---

## Cross-Module Dependencies

> Shows which modules depend on which interfaces. Use this to understand the impact of changes.

```text
[Module A] --calls--> I[ModuleB].[MethodName]()
[Test] --injects--> [ModuleBFake] : I[ModuleB]   (MUST match real interface)
```

---

## Implementation Checklist

When implementing these contracts:

- [ ] Each public interface method is listed above (no missing methods)
- [ ] Method signatures match (parameter types, return types)
- [ ] Fake/mock implementations implement the same interface
- [ ] Tests reference the correct module paths / types

---

<!--
TEMPLATE INSTRUCTIONS:
1. Fill in one section per module that needs a defined interface.
2. Be explicit about method names - they are case-sensitive.
3. Include fake/mock modules if tests rely on them.
4. Remove sections that don't apply (REST, Events, Schemas, etc.) for your stack.
5. Use ONE fenced code block per example (triple backticks only). Do NOT nest fences.
-->
