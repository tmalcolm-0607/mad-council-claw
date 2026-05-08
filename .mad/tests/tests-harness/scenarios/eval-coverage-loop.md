# Eval: coverage-loop

## Scenario: Close-Coverage-Gap

### Setup
Create a C# project with source code and partial test coverage:

```csharp
// OrderService.cs - has untested branches
public class OrderService
{
    private readonly IOrderRepository _repo;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repo, ILogger<OrderService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public async Task<Order> CreateOrder(CreateOrderRequest request)
    {
        if (request == null) throw new ArgumentNullException(nameof(request));

        if (request.Items.Count == 0)
        {
            _logger.LogWarning("Empty order attempted");
            throw new ValidationException("Order must have at least one item");
        }

        var total = request.Items.Sum(i => i.Price * i.Quantity);

        if (total > 10000)
        {
            _logger.LogInformation("High-value order: {Total}", total);
        }

        var order = new Order
        {
            Id = Guid.NewGuid().ToString(),
            Items = request.Items,
            Total = total,
            Status = OrderStatus.Created
        };

        await _repo.SaveAsync(order);
        return order;
    }

    public async Task<Order> CancelOrder(string orderId)
    {
        var order = await _repo.GetAsync(orderId);
        if (order == null) throw new NotFoundException($"Order {orderId} not found");

        if (order.Status == OrderStatus.Shipped)
            throw new InvalidOperationException("Cannot cancel shipped order");

        order.Status = OrderStatus.Cancelled;
        await _repo.SaveAsync(order);
        return order;
    }
}
```

Existing tests only cover `CreateOrder` happy path. Missing:
- `CreateOrder` with null request
- `CreateOrder` with empty items
- `CreateOrder` with high-value order
- `CancelOrder` happy path
- `CancelOrder` with non-existent order
- `CancelOrder` with shipped order

### Task Prompt
```
Close the coverage gap for OrderService.cs. Current diff coverage is ~40%.
Target: 100%. Worktree path: [temp project path].
```

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| Gap identified | Missing test cases listed | Required |
| Tests written | At least 5 new test methods | Required |
| Null request test | ArgumentNullException assertion | Required |
| Empty items test | ValidationException assertion | Required |
| Cancel shipped test | InvalidOperationException assertion | Required |
| Tests pass | 0 failures | Required |
| Coverage improved | From ~40% toward 100% | Required |
| No exclusions | No ExcludeFromCodeCoverage on testable code | Quality |
| Pattern followed | Uses existing mock/assert patterns | Quality |

### Assertions

```bash
# 1. Test file exists
ls **/OrderService*Test*.cs

# 2. Multiple test methods
grep -c '\[TestMethod\]\|\[Fact\]\|\[Test\]' **/OrderService*Test*.cs
# Expected: >= 5

# 3. Exception tests present
grep -E 'ArgumentNullException|ValidationException|InvalidOperationException|NotFoundException' **/OrderService*Test*.cs

# 4. Build passes
dotnet build --no-restore 2>&1 | tail -1 | grep -q "succeeded"

# 5. Tests pass
dotnet test --no-build 2>&1 | grep "Passed"
```

---

## Metrics to Collect

| Metric | How to Measure |
|--------|---------------|
| Coverage before | Diff coverage % at start |
| Coverage after | Diff coverage % at end |
| Tests written | Count of new test methods |
| Exclusions applied | Count of ExcludeFromCodeCoverage |
| Iterations | Number of coverage-loop cycles |
| Token usage | Agent metadata |
| Wall-clock time | Timestamps |
