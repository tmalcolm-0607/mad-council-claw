# Eval: investigate-and-implement

## Scenario: Fix-Known-Bug

### Setup
Create a temp C# project with a deliberate bug:

```csharp
// Calculator.cs - has an off-by-one error
public class Calculator
{
    public int Add(int a, int b) => a + b;
    public int Subtract(int a, int b) => a - b;
    public int Multiply(int a, int b) => a * b;
    public int Divide(int a, int b) => a / b;  // No zero-division guard
    public double Average(int[] numbers) => numbers.Sum() / numbers.Length;  // Integer division bug
}
```

### Task Prompt
```
Fix the bug in Calculator.Average - it uses integer division instead of floating-point division,
causing incorrect results for non-evenly-divisible inputs. Also add a guard for empty arrays.
```

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| Bug identified | `Average` method has integer division | Required |
| Fix applied | Cast to `(double)` or use `1.0 *` | Required |
| Empty array guard | Throws or returns 0/NaN for empty input | Required |
| Test written | At least 1 test for the fix | Required |
| Tests pass | 0 failures | Required |
| Output compact | < 30 lines returned to orchestrator | Quality |
| Subagents used | code-investigator + code-implementer spawned | Quality |
| No extra changes | Only Calculator.cs and test file modified | Quality |

### Assertions (machine-checkable)

```bash
# 1. Average method uses floating-point division
grep -E '(double|1\.0|\(float\))' Calculator.cs

# 2. Empty array handled
grep -E '(Length\s*==\s*0|\.Any\(\)|IsNullOrEmpty|throw.*ArgumentException)' Calculator.cs

# 3. Test file exists
ls **/Calculator*Test*.cs

# 4. Build passes
dotnet build --no-restore 2>&1 | tail -1 | grep -q "succeeded"

# 5. Tests pass
dotnet test --no-build 2>&1 | grep -E "Passed|Failed"
```

---

## Scenario: Implement-New-Feature

### Setup
Same Calculator project, no bugs.

### Task Prompt
```
Add a Factorial method to Calculator that computes n! for non-negative integers.
It should throw ArgumentOutOfRangeException for negative inputs and return 1 for 0.
```

### Expected Outcomes

| Check | Expected | Weight |
|-------|----------|--------|
| Method added | `public long Factorial(int n)` or similar | Required |
| Negative guard | Throws `ArgumentOutOfRangeException` | Required |
| Base case | Returns 1 for n=0 | Required |
| Test written | At least 3 test cases (0, positive, negative) | Required |
| Tests pass | 0 failures | Required |
| TDD followed | Test written before implementation (check git log order) | Quality |

---

## Metrics to Collect

| Metric | How to Measure |
|--------|---------------|
| Token usage | Count from agent output metadata |
| Wall-clock time | `date` before and after |
| Subagent count | Count Task tool invocations in agent output |
| Context returned | Line count of final output |
| Correctness | Assertion pass rate |
| Files changed | `git diff --name-only` |
