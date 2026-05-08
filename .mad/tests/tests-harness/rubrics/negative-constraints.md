# Negative Constraints - Judge Rubric

## Context
The agent was asked to implement a feature with specific boundary conditions and constraints (e.g., pagination with max page size, input validation with specific rules).

## Instructions
You are evaluating code produced by an AI agent. Review the provided source files and score each criterion 0 or 1.

Return your assessment as JSON:
```json
{
  "criteria_scores": [
    { "criterion": "Boundary Checks", "score": 0, "explanation": "..." },
    { "criterion": "Clean Architecture", "score": 1, "explanation": "..." },
    { "criterion": "Production Quality", "score": 0, "explanation": "..." }
  ],
  "score": 1,
  "max_score": 3,
  "rationale": "Overall assessment in 1-2 sentences."
}
```

## Criteria

### 1. Boundary Checks (0-1)
**Score 1 if:** All edge cases and boundaries are properly handled. This includes: null/empty input validation, numeric range checks (min/max values), array bounds checks, off-by-one prevention, and proper handling of empty collections. Boundary conditions specified in the requirements (e.g., "max page size is 100") are enforced.

**Score 0 if:** Any boundary condition is missing or incorrectly handled. This includes: missing null checks, accepting out-of-range values, incorrect array indexing, or failing to enforce specified constraints. Even one missing boundary check results in a 0.

### 2. Clean Architecture (0-1)
**Score 1 if:** Code follows SOLID principles with proper separation of concerns. Single Responsibility: each class has one clear purpose. Open/Closed: code is extensible without modification. Liskov Substitution: abstractions are properly used. Interface Segregation: interfaces are focused. Dependency Inversion: depends on abstractions not concretions. Proper layering is maintained (no business logic in API controllers, no data access in business logic classes unless via repositories).

**Score 0 if:** Any SOLID violation exists. This includes: classes with multiple responsibilities, business logic in controllers, tight coupling to concrete implementations, god objects, or improper layering. Code that mixes concerns (e.g., HTTP handling and business logic in the same method) is scored 0.

### 3. Production Quality (0-1)
**Score 1 if:** Code is production-ready with proper error handling, structured logging with appropriate log levels, no debug code (Console.WriteLine, commented-out code, TODO markers), no hardcoded values that should be configurable, and proper resource disposal (using/IDisposable). Exceptions are properly typed and include meaningful messages.

**Score 0 if:** Any production-readiness issue exists. This includes: unhandled exceptions, missing logging, debug code left in place, hardcoded connection strings or secrets, resource leaks, or generic exception types (Exception, SystemException) thrown without context. Even one issue results in a 0.
