# Verification Spec Template

Use this template when adding a verification spec section to plan.md files.

---

## Template

Copy and paste this section into your plan.md file, then fill in the bracketed values:

```markdown
## Verification Spec

### Feature Intent
[1-2 sentence description of what the feature does]

### Change Type
[filter | gate | threshold | logic | refactor | new_feature]

### Expected Impact

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Behavior Change | [none / decrease_minor / decrease_moderate / decrease_significant / increase] | [Why this is expected] |

### Structural Signals

| Signal | Pass Condition | Fail Condition |
|--------|----------------|----------------|
| [What to check #1] | [Success indicator] | [Failure indicator] |
| [What to check #2] | [Success indicator] | [Failure indicator] |
| [What to check #3] | [Success indicator] | [Failure indicator] |

### Not a Failure

These outcomes may look concerning but are NOT structural failures:

- [Outcome that's acceptable even if it looks bad]
- [Another acceptable outcome]
```

---

## Filled Example: Input Validation Filter

```markdown
## Verification Spec

### Feature Intent
Add input validation to reject malformed API requests before processing, returning appropriate 400 errors.

### Change Type
filter

### Expected Impact

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Behavior Change | decrease_minor | Validation should reject 5-15% of requests with missing/malformed fields |

### Structural Signals

| Signal | Pass Condition | Fail Condition |
|--------|----------------|----------------|
| Valid requests process normally | Valid requests >= 85% of baseline | Valid requests < 50% of baseline |
| Invalid requests rejected properly | 400 errors for malformed input | 500 errors or silent failures |
| Validation errors are logged | Validation failures appear in logs | No validation log entries |

### Not a Failure

These outcomes may look concerning but are NOT structural failures:

- Overall throughput decreases slightly due to validation overhead
- Some edge cases now rejected that previously succeeded silently
- Test suites with malformed fixtures now fail (expected)
```

---

## Guidelines

### Change Type Selection

| If your feature... | Use change_type |
|-------------------|-----------------|
| Adds a check that rejects some inputs | `filter` |
| Adds a required condition (auth, permissions) | `gate` |
| Changes a numeric limit/timeout/threshold | `threshold` |
| Changes how decisions are made | `logic` |
| Restructures code without changing behavior | `refactor` |
| Adds new capability | `new_feature` |

### Behavior Change Estimation

| Expected change in activity/usage | Use value |
|----------------------------------|-----------|
| No change (0-5%) | `none` |
| Small reduction (5-20%) | `decrease_minor` |
| Moderate reduction (20-40%) | `decrease_moderate` |
| Large reduction (40-70%) | `decrease_significant` |
| Increase in activity | `increase` |

### Good vs Bad Structural Signals

**Good signals** (use these):
- "Feature triggers when expected condition is met"
- "Proper error codes returned for error cases"
- "Logs show expected state transitions"
- "No runtime exceptions"
- "Database writes appear in expected tables"

**Bad signals** (avoid these):
- "Performance improves" (metric, not structure)
- "Users like it better" (outcome, not structure)
- "Fewer bugs reported" (outcome, not structure)
- "Response time faster" (performance, not structure)

### Not a Failure Examples

Common acceptable outcomes:
- Test count or coverage changes
- Performance variations within acceptable range
- Expected functionality now properly rejected
- Edge cases that previously worked incorrectly now fail
- Downstream systems need updates (expected migration)
