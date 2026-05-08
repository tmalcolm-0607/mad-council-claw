# Investigate and Implement - Judge Rubric

## Context
The agent was asked to investigate a bug (integer division causing incorrect results) and implement a fix.

## Instructions
You are evaluating code produced by an AI agent. Review the provided source files and score each criterion 0 or 1.

Return your assessment as JSON:
```json
{
  "criteria_scores": [
    { "criterion": "Minimal Fix", "score": 0, "explanation": "..." },
    { "criterion": "No Unnecessary Changes", "score": 1, "explanation": "..." },
    { "criterion": "Meaningful Tests", "score": 0, "explanation": "..." }
  ],
  "score": 1,
  "max_score": 3,
  "rationale": "Overall assessment in 1-2 sentences."
}
```

## Criteria

### 1. Minimal Fix (0-1)
**Score 1 if:** The fix targets only the identified bug (e.g., changes integer division to floating-point division). No unrelated logic is modified. Changes are confined to the specific function or lines causing the bug.

**Score 0 if:** The fix includes refactoring of unrelated code, changes to unrelated functions, or modifications that go beyond addressing the specific integer division issue.

### 2. No Unnecessary Changes (0-1)
**Score 1 if:** The changeset contains ONLY the bug fix and its associated tests. No reformatting, whitespace changes, comment updates, or style adjustments to unrelated code. No new dependencies or configuration changes unless absolutely required by the fix.

**Score 0 if:** The changeset includes any of: reformatting unrelated code, adding comments to unchanged functions, refactoring variable names outside the fix scope, or modifying files unrelated to the bug.

### 3. Meaningful Tests (0-1)
**Score 1 if:** Tests specifically verify the bug fix by testing the condition that caused the integer division error (e.g., testing that division results are now accurate floating-point values). Tests include assertions that would have failed before the fix and pass after.

**Score 0 if:** Tests are superficial (e.g., only check that code compiles), redundant with existing tests, or do not actually exercise the fixed code path. Tests that merely call the function without asserting the fix's correctness do not earn credit.
