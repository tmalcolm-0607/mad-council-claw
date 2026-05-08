# Coverage Loop - Judge Rubric

## Context
The agent was asked to write tests to improve code coverage for previously untested code paths.

## Instructions
You are evaluating code produced by an AI agent. Review the provided source files and score each criterion 0 or 1.

Return your assessment as JSON:
```json
{
  "criteria_scores": [
    { "criterion": "Distinct Code Paths", "score": 0, "explanation": "..." },
    { "criterion": "No Duplicate Logic", "score": 1, "explanation": "..." },
    { "criterion": "Proper Mocking", "score": 0, "explanation": "..." }
  ],
  "score": 1,
  "max_score": 3,
  "rationale": "Overall assessment in 1-2 sentences."
}
```

## Criteria

### 1. Distinct Code Paths (0-1)
**Score 1 if:** Each test covers a different branch, condition, or code path. Tests target different if/else branches, exception handling paths, null checks, or boundary conditions. Each test increases coverage by exercising previously untested logic.

**Score 0 if:** Tests are redundant (multiple tests exercise the same code path with trivially different inputs). Tests that only vary input values without changing which branches are executed do not earn credit. Tests that duplicate existing coverage are scored 0.

### 2. No Duplicate Logic (0-1)
**Score 1 if:** Tests avoid repeating the same assertion pattern unnecessarily. Each test has a unique purpose and assertion strategy. Tests with similar setup use shared fixtures or helper methods rather than copy-paste.

**Score 0 if:** Tests contain duplicated assertion logic (e.g., 5 tests that all assert `result != null` with no other meaningful differences). Tests that copy-paste the same setup and assertion blocks without meaningful variation are scored 0.

### 3. Proper Mocking (0-1)
**Score 1 if:** External dependencies (databases, HTTP clients, file systems, third-party APIs) are properly mocked or stubbed. Mocks are configured with realistic behaviors. Tests do not make real network calls or database queries. Mock verification is used where appropriate to assert interactions.

**Score 0 if:** Tests make real external calls (database queries, HTTP requests), do not mock dependencies that should be mocked, or use mocks incorrectly (e.g., mocks that always return null without realistic behavior). Tests that rely on external state or side effects are scored 0.
