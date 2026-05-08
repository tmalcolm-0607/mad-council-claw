# Eval: review-and-fix

## Scenario: Fix-Security-Issue

### Setup
Create a C# API controller with a deliberate security issue:

```csharp
// UsersController.cs - SQL injection vulnerability
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IDbConnection _db;

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string name)
    {
        // Vulnerable: string concatenation in SQL
        var sql = $"SELECT * FROM Users WHERE Name = '{name}'";
        var users = await _db.QueryAsync<User>(sql);
        return Ok(users);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        // Missing input validation
        var user = new User { Name = request.Name, Email = request.Email };
        await _db.ExecuteAsync("INSERT INTO Users (Name, Email) VALUES (@Name, @Email)", user);
        return Created($"/api/users/{user.Id}", user);
    }
}
```

### Task Prompt
```
Review and fix the security issues in UsersController.cs.
Files changed: UsersController.cs
Review focus: security
```

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| SQL injection found | String interpolation in SQL identified | Required |
| SQL injection fixed | Parameterized query used | Required |
| Input validation noted | Missing validation on Create endpoint | Required |
| Input validation added | FluentValidation or manual validation | Expected |
| Tests pass after fix | 0 failures | Required |
| Output compact | < 40 lines | Quality |
| Deferred items listed | Any minor issues noted but not fixed | Quality |

### Assertions

```bash
# 1. No string interpolation in SQL
! grep -E '\$".*SELECT.*{' UsersController.cs

# 2. Parameterized query used
grep -E '@name|@Name|new\s*{.*name' UsersController.cs

# 3. Build passes
dotnet build --no-restore 2>&1 | tail -1 | grep -q "succeeded"
```

---

## Scenario: Address-PR-Comments

### Setup
Provide a list of mock PR review comments.

### Task Prompt
```
Address these review comments:
1. [Major] UsersController.cs:15 - Use async suffix for async methods (SearchAsync)
2. [Major] UsersController.cs:22 - Return 404 when no users found, not empty 200
3. [Minor] UsersController.cs:8 - Consider constructor injection via interface
Review focus: review_comments provided
```

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| Async suffix added | Method renamed to SearchAsync | Required |
| 404 handling added | Returns NotFound() when empty | Required |
| Minor deferred | Constructor injection noted as deferred | Expected |
| Tests updated | Renamed test methods match | Required |

---

## Metrics to Collect

| Metric | How to Measure |
|--------|---------------|
| Issues found | Count from review output |
| Issues fixed | Count from fix output |
| Fix iterations | Number of review-fix cycles |
| False positives | Issues raised that aren't real problems |
| Token usage | Agent metadata |
| Wall-clock time | Timestamps |
