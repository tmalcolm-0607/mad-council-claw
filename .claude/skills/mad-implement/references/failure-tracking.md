# Failure Tracking Protocol

Log every failure to `FEATURE_DIR/context.md` for pattern analysis.

## Failure Categories

BUILD, TEST, GATE, TYPE, LINT, DOCKER, E2E, API, DB, CONFIG, LOGIC, OTHER

## Log Format

```markdown
| ID | Date | Category | Task | Error Summary | Root Cause | Fix Applied |
|----|------|----------|------|---------------|------------|-------------|
| F001 | 2026-02-08 | TEST | T012 | Null reference in service test | Missing mock setup | Added `.Returns(value)` |
| F002 | 2026-02-08 | BUILD | T015 | Type mismatch in DTO | Changed API contract | Updated DTO property type |
```

## Pattern Recognition Rule

If a category appears **3+ times** in the failure log → propose adding to CLAUDE.md Anti-Patterns.

## State Preservation

When a failure occurs:
1. Log immediately to `FEATURE_DIR/context.md` before attempting fixes
2. Capture exact error message, stack trace, and task ID
3. Document root cause analysis (not just symptoms)
4. Record fix applied for future reference

## Recovery Logic

**On resume**: Read Failure Log first to avoid repeating mistakes.

Before retrying a previously failed task:
1. Check if same category has failed 2+ times already
2. If yes, review all failures in that category for patterns
3. Apply learnings from previous fixes
4. Consider spawning `code-investigator` if pattern unclear
