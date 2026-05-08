# AI Slop Detection Heuristics

14 heuristics for detecting AI-generated code quality issues ("slop"). Each heuristic includes detection patterns, language-specific guidance, severity defaults, and false positive notes.

---

## S1: Phantom Imports

**Description**: `using`/`import` statements referencing packages or modules that do not exist in the project's dependency graph (NuGet, npm, pip, go.mod).

**Severity**: CRITICAL

**Detection approach**:
1. Extract all import/using statements from target files
2. Cross-reference against project dependency manifests (`.csproj`, `package.json`, `requirements.txt`, `go.mod`)
3. For standard library imports, check against known stdlib lists
4. Flag imports where the package is neither a project dependency nor a known stdlib module

**Language patterns**:

| Language | Import Pattern | Manifest |
|----------|---------------|----------|
| C# | `using <Namespace>;` or `global using` | `.csproj` PackageReference, project references |
| TypeScript | `import ... from '<pkg>'` or `require('<pkg>')` | `package.json` dependencies/devDependencies |
| Python | `import <pkg>` or `from <pkg> import` | `requirements.txt`, `pyproject.toml`, `setup.py` |
| Go | `import "<module>"` | `go.mod` require blocks |

**False positives**:
- Internal project namespaces (C# namespace != NuGet package)
- Aliased re-exports (`@company/utils` -> local package)
- Auto-generated imports from code generators (`.g.cs`)
- Conditional compilation imports (`#if DEBUG`)

**Example**:

```csharp
// SLOP: Package does not exist in any referenced .csproj
using Microsoft.Azure.CognitiveServices.Vision;

// CORRECT: Package referenced in .csproj
using Microsoft.Azure.Cosmos;
```

---

## S2: Phantom Methods

**Description**: Calls to methods that do not exist on the target type, in the project, or in known library APIs.

**Severity**: CRITICAL

**Detection approach**:
1. Extract method calls (especially chained calls and extension methods)
2. Verify the method exists on the declared type or as an extension method
3. Check against known library API surfaces
4. Flag calls where no matching definition can be found

**Language patterns**:

| Language | Call Pattern | Check Against |
|----------|-------------|---------------|
| C# | `obj.MethodName()` or `ClassName.StaticMethod()` | Type definitions, extension methods, NuGet public API |
| TypeScript | `obj.methodName()` or `ClassName.staticMethod()` | Type declarations, `.d.ts` files, npm type packages |
| Python | `obj.method_name()` or `ClassName.static_method()` | Class definitions, `__init__.py` exports |
| Go | `obj.MethodName()` or `pkg.FunctionName()` | Exported function/method declarations |

**False positives**:
- Dynamic dispatch (`dynamic` in C#, `any` in TypeScript)
- Reflection-based invocations
- Methods added via code generation (e.g., EF Core navigation properties)
- Extension methods from transitive dependencies

**Example**:

```typescript
// SLOP: Array.prototype has no .flatten() with depth argument in older targets
const flat = nested.flatten(Infinity);

// CORRECT: Use flat() (ES2019+)
const flat = nested.flat(Infinity);
```

---

## S3: Signature Mismatch

**Description**: Method called with the wrong number of arguments, wrong argument types, or wrong argument order compared to its definition.

**Severity**: CRITICAL

**Detection approach**:
1. Find method definitions (parameter count, types, optional params)
2. Find all call sites for those methods
3. Compare argument count and types at each call site
4. Flag mismatches (accounting for optional parameters, params/rest args, overloads)

**Language patterns**:

| Language | Definition Grep | Call Site Grep |
|----------|----------------|----------------|
| C# | `(public\|protected\|internal\|private).*\s+\w+\s*\(` | `\.\w+\s*\(` or `\w+\s*\(` |
| TypeScript | `function\s+\w+\s*\(` or `\w+\s*:\s*\(` | `\w+\s*\(` |
| Python | `def\s+\w+\s*\(` | `\w+\s*\(` |
| Go | `func\s+(\(\w+\s+\*?\w+\)\s+)?\w+\s*\(` | `\w+\.\w+\(` or `\w+\(` |

**False positives**:
- Method overloads (C#, TypeScript)
- Default parameter values
- `params`/spread operator for variadic args
- Builder pattern methods returning `this`

**Example**:

```csharp
// Definition: 2 required params
public async Task<Case> GetCaseAsync(string caseId, CancellationToken ct)

// SLOP: 3 args passed
var result = await service.GetCaseAsync(caseId, tenantId, ct);

// CORRECT: 2 args
var result = await service.GetCaseAsync(caseId, ct);
```

---

## S4: Empty Implementations

**Description**: Methods whose body only throws `NotImplementedException`, contains only `TODO`/`FIXME` comments, calls `pass` (Python), or returns a hardcoded default with no logic.

**Severity**: MAJOR

**Detection approach**:
1. Find method bodies that are trivially empty
2. Check for `throw new NotImplementedException()`, `pass`, `return default`, `return null`, `TODO`/`FIXME` as the sole body content
3. Allow legitimate uses: abstract method stubs in test doubles, interface adapter patterns

**Language patterns**:

| Language | Grep Pattern |
|----------|-------------|
| C# | `throw new NotImplementedException\(\)` or `=> throw new` |
| TypeScript | `throw new Error\(['"]not implemented['"]\)` (case-insensitive) |
| Python | `pass` as sole body, or `raise NotImplementedError` |
| Go | `panic\("not implemented"\)` or empty function body `\{\s*\}` |

**False positives**:
- Test stubs that intentionally throw (part of test setup)
- Interface implementations in adapter/wrapper classes where some methods are intentionally unsupported
- Template code meant to be filled in (if clearly marked)

**Example**:

```csharp
// SLOP: Shipped stub
public async Task<IEnumerable<Case>> SearchAsync(SearchRequest request)
{
    // TODO: implement search
    throw new NotImplementedException();
}

// CORRECT: Actual implementation
public async Task<IEnumerable<Case>> SearchAsync(SearchRequest request)
{
    var query = BuildQuery(request);
    return await _container.QueryAsync<Case>(query, request.CancellationToken);
}
```

---

## S5: Inflated Docs

**Description**: XML doc / JSDoc / docstring is longer than the method implementation it documents (ratio > 2:1 lines).

**Severity**: MINOR

**Detection approach**:
1. For each method, measure lines of documentation (XML doc, JSDoc, docstring)
2. Measure lines of implementation (between opening and closing braces/indent)
3. Flag when doc_lines > 2 * impl_lines
4. Exclude: interface/abstract method declarations (docs are expected to be longer than signature)

**Language patterns**:

| Language | Doc Pattern | Implementation Boundary |
|----------|------------|------------------------|
| C# | `/// <summary>` to first non-`///` line | `{` to matching `}` |
| TypeScript | `/**` to `*/` | `{` to matching `}` |
| Python | `"""` or `'''` triple-quote blocks | Next `def`/`class` or dedent |
| Go | `// FuncName ...` consecutive comment lines | `{` to matching `}` |

**False positives**:
- Public API documentation (genuinely needs detailed docs)
- Methods with complex parameter contracts
- One-liner methods that delegate (docs explain why, not what)

**Example**:

```csharp
// SLOP: 8 lines of docs for a 2-line method
/// <summary>
/// Gets the case by its unique identifier from the underlying
/// data store using the configured Cosmos DB container with
/// proper partition key routing and error handling.
/// </summary>
/// <param name="caseId">The unique identifier of the case to retrieve</param>
/// <param name="ct">Cancellation token for async operation</param>
/// <returns>The case if found, null otherwise</returns>
public async Task<Case?> GetAsync(string caseId, CancellationToken ct)
{
    return await _container.ReadItemAsync<Case>(caseId, new PartitionKey(caseId), ct);
}

// CORRECT: Proportional documentation
/// <summary>Gets a case by ID.</summary>
public async Task<Case?> GetAsync(string caseId, CancellationToken ct)
{
    return await _container.ReadItemAsync<Case>(caseId, new PartitionKey(caseId), ct);
}
```

---

## S6: Dead Parameters

**Description**: Parameters declared in a method signature but never referenced in the method body.

**Severity**: MAJOR

**Detection approach**:
1. Extract parameter names from method signatures
2. Search method body for any reference to each parameter name
3. Flag parameters that appear only in the signature
4. Exclude: interface implementations (must match signature), event handlers, `_` discard parameters

**Language patterns**:

| Language | Parameter Extraction | Body Search |
|----------|---------------------|-------------|
| C# | Parameters between `(` and `)` in method declaration | Word-boundary match in method body |
| TypeScript | Parameters between `(` and `)` | Word-boundary match in function body |
| Python | Parameters after `def name(` | Word-boundary match in function body (respecting indent) |
| Go | Parameters in func declaration | Word-boundary match in function body |

**False positives**:
- Interface contract compliance (C# explicit interface implementation)
- Event handler signatures (`object sender, EventArgs e`)
- Parameters used only in attributes or decorators
- Discard parameters (`_`, `__`) in Python/Go
- `CancellationToken` passed to middleware/framework implicitly

**Example**:

```python
# SLOP: 'logger' is never used in the body
def process_request(request, logger, config):
    result = validate(request)
    return transform(result, config)

# CORRECT: All parameters used
def process_request(request, config):
    result = validate(request)
    return transform(result, config)
```

---

## S7: Copy-Paste Artifacts

**Description**: Two or more method bodies that are structurally identical or near-identical, differing only in names/identifiers.

**Severity**: MAJOR

**Detection approach**:
1. Normalize method bodies (strip names, collapse whitespace)
2. Compare normalized bodies across methods in the same file or directory
3. Flag groups of 2+ methods with >80% structural similarity
4. Measure similarity by line-level diff after normalization

**Language patterns**:

This heuristic is language-agnostic. The detection is structural:
1. Extract method body text
2. Replace all identifiers with a placeholder token
3. Compare resulting templates
4. Methods with identical templates (after normalization) are copy-paste artifacts

**False positives**:
- Overloaded methods that legitimately share structure
- CRUD operations that follow the same pattern by design
- Generated code (check for `auto-generated` markers)
- Test methods that follow Arrange-Act-Assert with minimal variation

**Example**:

```csharp
// SLOP: Copy-paste with only the type name changed
public async Task<Case> GetCaseAsync(string id, CancellationToken ct)
{
    var response = await _container.ReadItemAsync<Case>(id, new PartitionKey(id), cancellationToken: ct);
    return response.Resource;
}

public async Task<Document> GetDocumentAsync(string id, CancellationToken ct)
{
    var response = await _container.ReadItemAsync<Document>(id, new PartitionKey(id), cancellationToken: ct);
    return response.Resource;
}

// CORRECT: Generic method or shared pattern
public async Task<T> GetItemAsync<T>(string id, CancellationToken ct)
{
    var response = await _container.ReadItemAsync<T>(id, new PartitionKey(id), cancellationToken: ct);
    return response.Resource;
}
```

---

## S8: Hallucinated Constants

**Description**: Magic strings or numbers used in code with no corresponding constant definition, enum value, or configuration entry.

**Severity**: MAJOR

**Detection approach**:
1. Find string literals and numeric constants in non-test code
2. Check if each is defined as a `const`, `static readonly`, enum value, or config key
3. Flag literals that appear to be domain values but have no definition
4. Exclude: common patterns like `""`, `0`, `1`, `-1`, `null`, log message templates

**Language patterns**:

| Language | Literal Pattern | Definition Check |
|----------|----------------|------------------|
| C# | `"[A-Z][a-zA-Z]+"` (PascalCase strings) | `const string`, `static readonly`, enum members |
| TypeScript | `'[A-Z_]+'` or `"[A-Z_]+"` | `const`, `enum`, `as const` objects |
| Python | `"[A-Z_]+"` | Module-level constants (ALL_CAPS), enum members |
| Go | `"[A-Z][a-zA-Z]+"` | `const` declarations |

**False positives**:
- Log messages and error descriptions
- Configuration section names (validated at startup)
- Test data strings
- URL paths and API routes
- JSON property names in serialization attributes

**Example**:

```csharp
// SLOP: Magic string with no definition anywhere
if (request.Status == "PendingApproval")

// CORRECT: Defined constant
if (request.Status == CaseStatus.PendingApproval)
```

---

## S9: Mismatched Return Types

**Description**: Method signature declares return type X but the implementation returns type Y (or returns nothing for non-void methods).

**Severity**: CRITICAL

**Detection approach**:
1. Extract declared return type from method signature
2. Find all `return` statements in the method body
3. Check if returned values are compatible with the declared type
4. Flag type mismatches, missing returns on some code paths, and `return null` for non-nullable types

**Language patterns**:

| Language | Return Type Location | Return Statement |
|----------|---------------------|-----------------|
| C# | Before method name in declaration | `return <expr>;` |
| TypeScript | After `:` in function signature, or inferred | `return <expr>;` |
| Python | Type hint after `->` | `return <expr>` |
| Go | After parameter list | `return <expr>` |

**False positives**:
- Implicit conversions (numeric widening, interface implementations)
- Generic type inference
- Nullable annotations (`?`) allowing null returns
- `Task<T>` vs `T` (async unwrapping)
- TypeScript type narrowing

**Example**:

```typescript
// SLOP: Declares string return but returns number
function getStatus(code: number): string {
    return code * 100;  // Returns number, not string
}

// CORRECT: Returns matching type
function getStatus(code: number): string {
    return `Status-${code}`;
}
```

---

## S10: Buzzword Claims

**Description**: Comments or documentation claiming "production-ready", "enterprise-grade", "battle-tested", "industry-standard", "best practice", or similar without supporting evidence in the code.

**Severity**: MINOR

**Detection approach**:
1. Search comments and documentation for buzzword patterns
2. Flag claims that are unsubstantiated by the surrounding code
3. Focus on comments, not marketing docs or READMEs

**Grep patterns** (case-insensitive):

```
production.ready
enterprise.grade
battle.tested
industry.standard
best.practice
world.class
state.of.the.art
highly.scalable
blazing.fast
rock.solid
bullet.proof
```

**False positives**:
- README/marketing documentation (audience is different)
- Comments quoting external documentation or requirements
- Comments that cite specific benchmarks or test results alongside the claim

**Example**:

```csharp
// SLOP: Unsubstantiated claim
/// <summary>
/// Production-ready, enterprise-grade case management service
/// with industry-standard security patterns.
/// </summary>
public class CaseService { /* 20 lines of basic CRUD */ }

// CORRECT: Factual description
/// <summary>
/// Case management service handling create, read, update, and delete operations
/// against Cosmos DB with managed identity authentication.
/// </summary>
public class CaseService { /* same 20 lines */ }
```

---

## S11: Orphaned Test Helpers

**Description**: Test utility classes, mock factories, or helper methods in test projects that no test actually references.

**Severity**: MINOR

**Detection approach**:
1. Find classes/methods in test projects that match helper patterns (names containing `Factory`, `Builder`, `Helper`, `Mock`, `Fake`, `Stub`, `Fixture`)
2. Search all test files for references to each helper
3. Flag helpers with zero references

**Language patterns**:

| Language | Helper Pattern | Search Scope |
|----------|---------------|-------------|
| C# | Classes in `*.Tests` projects matching `*Factory`, `*Builder`, `*Helper`, `*Mock` | All `.cs` files in test projects |
| TypeScript | Exports in `__tests__/helpers/`, `test/utils/`, `*.test-utils.*` | All `.test.ts`, `.spec.ts` files |
| Python | Functions/classes in `conftest.py`, `test_helpers.py`, `fixtures.py` | All `test_*.py` files |
| Go | Functions in `*_test.go` starting with lowercase (unexported helpers) | Same `*_test.go` file |

**False positives**:
- Helpers used via reflection or dynamic import
- Shared test infrastructure referenced by test projects not in the current scope
- Helpers used only in skipped/disabled tests
- Base test classes (inherited, not directly called)

**Example**:

```csharp
// SLOP: No test references CaseTestBuilder
public class CaseTestBuilder
{
    public Case Build() => new Case { Id = "test-1", Status = "Active" };
    public CaseTestBuilder WithStatus(string s) { _status = s; return this; }
}

// CORRECT: Builder is actually used in tests
[Fact]
public async Task GetCase_ReturnsCase()
{
    var testCase = new CaseTestBuilder().WithStatus("Active").Build();
    // ... test using testCase
}
```

---

## S12: Fake Error Handling

**Description**: Catch blocks that swallow exceptions (empty catch, log-only catch without rethrow, or catch that returns a default value hiding the error).

**Severity**: MAJOR

**Detection approach**:
1. Find all catch/except blocks
2. Check if the block: (a) is empty, (b) only logs, (c) returns a default without any recovery logic
3. Flag blocks that swallow errors without recovery or rethrow
4. Allow: catch blocks that genuinely handle the error (retry, fallback with business logic, circuit breaker)

**Language patterns**:

| Language | Catch Pattern | Swallow Indicators |
|----------|--------------|-------------------|
| C# | `catch\s*(\(\w+(\s+\w+)?\))?\s*\{` | Empty body, `_logger.Log` only, `return default` |
| TypeScript | `catch\s*(\(\w+\))?\s*\{` | Empty body, `console.log` only, `return null` |
| Python | `except(\s+\w+(\s+as\s+\w+)?)?\s*:` | `pass`, `print()` only, `return None` |
| Go | `if err != nil \{` | `_ = err`, empty block, `log.Print` only |

**False positives**:
- Intentional suppression with explicit comment explaining why
- Catch-and-wrap patterns (`throw new CustomException("msg", ex)`)
- Retry logic that catches and retries before eventually rethrowing
- Top-level error boundaries in middleware (designed to catch all)

**Example**:

```csharp
// SLOP: Swallows the exception
try
{
    await _cosmosClient.CreateItemAsync(item);
}
catch (CosmosException ex)
{
    _logger.LogError(ex, "Failed to create item");
    // Error is silently swallowed - caller never knows
}

// CORRECT: Log and rethrow (let middleware handle)
try
{
    await _cosmosClient.CreateItemAsync(item);
}
catch (CosmosException ex)
{
    _logger.LogError(ex, "Failed to create item");
    throw;
}
```

---

## S13: Inconsistent Naming

**Description**: The same domain concept referred to by 3 or more different names across files (e.g., `case`, `legalCase`, `caseRecord`, `caseItem`).

**Severity**: MAJOR

**Detection approach**:
1. Build a glossary of domain terms from class names, property names, and variable names
2. Cluster similar terms that refer to the same concept (e.g., `UserId`, `userId`, `user_id`, `userIdentifier`)
3. Flag clusters where 3+ distinct names appear for the same concept
4. Weight by proximity - same file is worse than across distant modules

**Detection heuristics**:
- Normalize to lowercase, strip common suffixes (`Id`, `Name`, `Type`, `Status`, `Response`, `Request`, `Dto`, `Model`, `Entity`)
- Group by normalized stem
- Flag groups with 3+ distinct pre-normalization forms used in non-trivial ways (not just type aliases)

**False positives**:
- Different layers using different names by convention (e.g., `CaseEntity` in data layer, `CaseResponse` in API layer)
- Generic parameter names (`T`, `TResult`)
- Language-mandated differences (`case` is a keyword in many languages)

**Example**:

```
// SLOP: 4 names for the same concept across files
CaseController.cs:    var legalCase = await _service.GetCase(id);
CaseService.cs:       var caseRecord = await _repo.FindAsync(id);
CaseRepository.cs:    var caseItem = await _container.ReadItemAsync(id);
CaseMapper.cs:        var caseEntity = MapToEntity(dto);

// CORRECT: Consistent naming
CaseController.cs:    var caseResponse = _mapper.ToResponse(case);   // API layer: Response suffix
CaseService.cs:       var case = await _repo.GetAsync(id);            // Business layer: domain name
CaseRepository.cs:    var case = await _container.ReadItemAsync(id);  // Data layer: domain name
```

---

## S14: Stale References

**Description**: Import/using statements or type references that point to types that have been renamed or removed in the current changeset.

**Severity**: CRITICAL

**Detection approach**:
1. From the diff/changeset, identify deleted or renamed files/types
2. Search remaining code for references to the old names
3. Flag references that point to names no longer defined

**Language patterns**:

| Language | Reference Pattern | Deletion Indicators |
|----------|------------------|---------------------|
| C# | `using <Namespace>.<OldType>;` or `new OldType()` | File deleted, class renamed, namespace changed |
| TypeScript | `import { OldType } from` or `import OldType from` | File deleted, export renamed |
| Python | `from module import OldName` or `import old_module` | File deleted, name changed |
| Go | `import "pkg/old"` or `old.Function()` | Package moved or renamed |

**False positives**:
- Types that exist in referenced NuGet/npm packages (not project-local)
- Conditional compilation (`#if`) referencing types in other configurations
- Types generated at build time (EF migrations, gRPC stubs)

**Example**:

```csharp
// SLOP: CaseKind was renamed to RequestType but old reference remains
using CMS.Common.Enums; // Still references CaseKind

public CaseKind Kind { get; set; } // Type no longer exists

// CORRECT: Updated to new name
using CMS.Common.Enums;

public RequestType RequestType { get; set; }
```

---

## Severity Summary

| ID | Name | Default Severity |
|----|------|-----------------|
| S1 | Phantom Imports | CRITICAL |
| S2 | Phantom Methods | CRITICAL |
| S3 | Signature Mismatch | CRITICAL |
| S4 | Empty Implementations | MAJOR |
| S5 | Inflated Docs | MINOR |
| S6 | Dead Parameters | MAJOR |
| S7 | Copy-Paste Artifacts | MAJOR |
| S8 | Hallucinated Constants | MAJOR |
| S9 | Mismatched Return Types | CRITICAL |
| S10 | Buzzword Claims | MINOR |
| S11 | Orphaned Test Helpers | MINOR |
| S12 | Fake Error Handling | MAJOR |
| S13 | Inconsistent Naming | MAJOR |
| S14 | Stale References | CRITICAL |
