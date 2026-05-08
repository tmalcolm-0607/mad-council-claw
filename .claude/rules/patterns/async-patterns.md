---
paths:
  - "**/*.cs"
---

# Async Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

## CancellationToken Propagation

### Pattern: Always Propagate CancellationToken

**Critical**: All async methods should accept and propagate `CancellationToken` to enable graceful cancellation.

```csharp
// ✓ CORRECT: Accept and propagate CancellationToken
public async Task<Foo> CreateFooAsync(
    CreateFooRequest request,
    CancellationToken cancellationToken)
{
    var existing = await this.repository.GetByNameAsync(request.Name, cancellationToken);
    if (existing is not null)
        throw new FooAlreadyExistsException("A foo with that name already exists.");

    var foo = new Foo { Name = request.Name };
    return await this.repository.CreateAsync(foo, cancellationToken);
}
```

```csharp
// ✗ WRONG: Not accepting CancellationToken
public async Task<Result> ProcessAsync(string campaignId)
{
    // No way to cancel this operation!
}

// ✗ WRONG: Accepting but not propagating
public async Task<Result> ProcessAsync(string fooId, CancellationToken cancellationToken)
{
    await this.repository.SaveAsync(); // Missing cancellationToken parameter
}
```

### Linked Tokens for Timeouts

**Pattern**: Combine cancellation token with timeout.

```csharp
public async Task<Result> ProcessWithTimeoutAsync(
    string campaignId,
    CancellationToken cancellationToken)
{
    using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    cts.CancelAfter(TimeSpan.FromSeconds(30));

    try
    {
        var result = await this.service.ProcessAsync(campaignId, cts.Token);
        return result;
    }
    catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
    {
        // LENS-canonical: throw a typed HandlerException; controller catch-ladder maps to HTTP.
        // (Result<T> is non-canonical for LENS — see dotnet-error-handling.md.)
        throw new OperationTimeoutException("Operation timed out after 30 seconds");
    }
}
```

## Async Method Naming

```csharp
// ✓ CORRECT: Async suffix; handlers return the domain type directly + throw on failure
public async Task<Campaign> CreateCampaignAsync(...)
public async Task<bool> ExistsAsync(...)
public async Task SaveAsync(...)

// ✗ WRONG: Missing Async suffix
public async Task<Campaign> CreateCampaign(...)
```

## ConfigureAwait(false) — NOT Required

**Modern ASP.NET Core does NOT require `ConfigureAwait(false)`**. The framework doesn't use `SynchronizationContext`.

```csharp
// ✓ CORRECT: No ConfigureAwait needed in ASP.NET Core
public async Task<ProcessedData> ProcessAsync(CancellationToken cancellationToken)
{
    var data = await this.repository.GetDataAsync(cancellationToken);
    return await this.service.ProcessAsync(data, cancellationToken);
}

// ✗ UNNECESSARY: ConfigureAwait(false) in ASP.NET Core
var data = await this.repository.GetDataAsync(cancellationToken).ConfigureAwait(false);
```

## Avoid Async Void

**Rule**: Never use `async void` except for event handlers.

```csharp
// ✗ WRONG: async void (exceptions are unobservable)
public async void ProcessDataAsync() { ... }

// ✓ CORRECT: async Task
public async Task ProcessDataAsync() { ... }
```

## Task.WhenAll for Parallel Operations

```csharp
// ✓ CORRECT: Parallel independent operations
// LENS-canonical: validation throws a typed HandlerException (e.g. CharacterValidationException)
// on first failure; the controller catch-ladder maps it to 400. No Result<T>.
public async Task ValidateMultipleAsync(
    string[] characterIds,
    CancellationToken cancellationToken)
{
    var tasks = characterIds.Select(id =>
        this.characterService.ValidateAsync(id, cancellationToken));

    await Task.WhenAll(tasks);   // any individual failure throws; aggregate via Task.WhenAll exception flattening if needed
}

// ✗ WRONG: Sequential when parallel is possible
foreach (var id in characterIds)
{
    await this.characterService.ValidateAsync(id, cancellationToken);
}
```

## ValueTask vs Task

**Use `Task<T>` by default**. Only use `ValueTask<T>` when profiling shows benefit (caching scenarios, hot paths).

```csharp
// ✓ GOOD USE: Caching scenario
public ValueTask<Character> GetCachedCharacterAsync(Guid id, CancellationToken ct)
{
    if (this.cache.TryGetValue(id, out var character))
        return new ValueTask<Character>(character); // No allocation

    return new ValueTask<Character>(LoadCharacterAsync(id, ct));
}
```

## OperationCanceledException Handling

```csharp
try
{
    var result = await service.ProcessAsync(request, cancellationToken);
    return Results.Ok(result);
}
catch (OperationCanceledException)
{
    return Results.Problem(
        statusCode: 499,
        title: "Request Cancelled",
        detail: "The request was cancelled by the client");
}
```

## Async Anti-Patterns

```csharp
// ✗ WRONG: Blocking on async code
var result = service.GetDataAsync(CancellationToken.None).Result; // Deadlock risk!
service.SaveAsync(CancellationToken.None).Wait(); // Deadlock risk!

// ✗ WRONG: async method without await
public async Task<int> GetCountAsync()
{
    return this.list.Count; // Warning: no await, should not be async
}

// ✓ CORRECT: Remove async if no await
public Task<int> GetCountAsync()
{
    return Task.FromResult(this.list.Count);
}

// ✗ WRONG: Creating unnecessary tasks
return Task.Run(() => DoWork()); // Adds overhead

// ✓ CORRECT: Directly return result
return DoWork();
```

## Testing Async Code

```csharp
// ✓ CORRECT: Test async methods with async tests
// LENS-canonical: handler returns the domain type directly; assert concrete shape.
// Failures throw typed exceptions — assert via Should().ThrowAsync<TException>().
[Fact]
public async Task CreateCampaignAsync_ShouldSucceed()
{
    var result = await sut.CreateCampaignAsync(request, CancellationToken.None);
    result.Should().NotBeNull();
    result.Name.Should().Be(request.Name);
}

// ✓ CORRECT: Test cancellation
[Fact]
public async Task ProcessAsync_ShouldThrow_WhenCancelled()
{
    var cts = new CancellationTokenSource();
    cts.Cancel();

    var act = async () => await sut.ProcessAsync(request, cts.Token);

    await act.Should().ThrowAsync<OperationCanceledException>();
}

// ✗ WRONG: Using .Result in tests
[Fact]
public void ProcessAsync_ShouldSucceed()
{
    var result = sut.ProcessAsync(request, CancellationToken.None).Result; // Don't do this
}
```

## Project-Specific Guidelines

1. **Always accept `CancellationToken`** in public async methods
2. **Propagate `CancellationToken`** to all async calls (repositories, Cosmos, Redis, HTTP)
3. **Don't use `ConfigureAwait(false)`** — not needed in ASP.NET Core
4. **Use `Task<T>` by default** — only `ValueTask<T>` when profiling justifies it
5. **Never use `async void`**
6. **Use `Task.WhenAll`** for parallel independent operations

## Sources

- [Recommended patterns for CancellationToken](https://devblogs.microsoft.com/premier-developer/recommended-patterns-for-cancellationtoken/)
- [Async/Await Best Practices](https://learn.microsoft.com/en-us/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- [ConfigureAwait FAQ](https://devblogs.microsoft.com/dotnet/configureawait-faq/)
