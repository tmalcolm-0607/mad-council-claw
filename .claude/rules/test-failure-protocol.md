# Test Failure Protocol

## Core Principle

**All test failures discovered during your work are your responsibility.** There is no such thing as "not our problem" when it comes to failing tests.

## Discovery Protocol

When quality gates or test runs show failures:

### Step 1: Categorize

Run tests on main branch to determine:
- **Regressions** (our change broke them) → Fix immediately
- **Pre-existing** (failed before our change) → Follow pre-existing protocol

### Step 2: For Regressions

1. Fix immediately - do not proceed with implementation
2. Run targeted test with `--filter` to verify fix
3. Re-run full test suite to verify no new regressions
4. Document what broke and why in commit message

### Step 3: For Pre-existing Failures

**YOU MUST CHOOSE ONE:**

| Option | When to Use | Action |
|--------|-------------|--------|
| **Fix Now** | Trivial fix (<30 min), high impact | Fix, test, commit with separate bug fix commit |
| **Track for Later** | Complex fix, requires research | Create bug spec via `/mad-spec`, link in commit message |
| **Add Skip Logic** | Infrastructure not available | Add `[SkippableFact(Skip = "...")]` with clear reason |

**FORBIDDEN**: Saying "95 pre-existing failures - unrelated to our changes" and proceeding without action.

### Step 4: Report Status

In your summary, explicitly state:
- How many failures were found
- How many were regressions vs pre-existing
- What action was taken for each category
- Links to tracking specs if applicable

## Infrastructure-Dependent Tests

Tests requiring PostgreSQL, Docker, or external services:

### Option A: Skip Gracefully (Preferred)
```csharp
public class MyIntegrationTests : IAsyncLifetime
{
    public async Task InitializeAsync()
    {
        if (!await IsInfrastructureAvailable())
            Skip.If(true, "PostgreSQL/Docker not available");
    }
}
```

### Option B: Skip Attribute
```csharp
[SkippableFact(Skip = "Requires PostgreSQL running locally")]
public async Task MyTest() { ... }
```

### Option C: Conditional Execution
```csharp
[SkippableFact]
public async Task MyTest()
{
    Skip.IfNot(await IsPostgresAvailable(), "PostgreSQL not running");
    // ... test code
}
```

**NEVER**: Let infrastructure tests fail hard and call them "pre-existing failures"

## Hook Enforcement

The `validate-quality-gates.js` hook will enforce:
- Tests are run, not skipped
- Failures are acknowledged and tracked
- "Pre-existing failure" claims require proof (spec ID or fix commit)

## Examples

### ❌ WRONG (Current Behavior)
```
"The quality gates failed with 95 failures. These are all pre-existing
failures (ComfyUIClient, tracing, metrics, GameHub, Campaign E2E) -
unrelated to our changes. Our 8 new tests all passed."
```

### ✅ CORRECT
```
"Quality gates found 95 failures. Analysis:
- 4 regressions (ComfyUIClientTests) - JSON mock mismatch. Fixed in commit abc123.
- 18 infrastructure tests missing skip logic - Added Skip attributes in commit def456.
- 73 pre-existing failures - Created tracking bug: specs/BUG-20260216-quality-gates-failures
All regressions fixed. Pre-existing failures tracked for team triage."
```
