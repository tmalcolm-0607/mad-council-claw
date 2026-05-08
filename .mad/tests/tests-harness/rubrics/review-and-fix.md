# Review and Fix - Judge Rubric

## Context
The agent was asked to review code for SQL injection vulnerabilities and fix them with parameterized queries.

## Instructions
You are evaluating code produced by an AI agent. Review the provided source files and score each criterion 0 or 1.

Return your assessment as JSON:
```json
{
  "criteria_scores": [
    { "criterion": "Correct Parameterization", "score": 0, "explanation": "..." },
    { "criterion": "Comprehensive Validation", "score": 1, "explanation": "..." },
    { "criterion": "No New Security Issues", "score": 0, "explanation": "..." }
  ],
  "score": 1,
  "max_score": 3,
  "rationale": "Overall assessment in 1-2 sentences."
}
```

## Criteria

### 1. Correct Parameterization (0-1)
**Score 1 if:** All SQL queries use proper parameterized queries with bound parameters (e.g., `@param` placeholders in SQL with parameter collections). No string concatenation or interpolation is used to build SQL statements. Parameters are passed through the database driver's parameter mechanism.

**Score 0 if:** The fix uses string escaping, sanitization functions, or manual input validation instead of parameterized queries. Any use of string concatenation or interpolation to build SQL queries earns a 0, even if additional validation is present.

### 2. Comprehensive Validation (0-1)
**Score 1 if:** ALL SQL injection vectors are addressed. This includes obvious cases (e.g., WHERE clauses with user input) and subtle cases (e.g., ORDER BY, LIMIT, table names in dynamic queries). The agent identified and fixed every location where user input flows into SQL.

**Score 0 if:** The fix addresses only the most obvious SQL injection point but leaves other vulnerable queries unchanged. Missing even one SQL injection vector (e.g., fixing WHERE but not ORDER BY) results in a 0.

### 3. No New Security Issues (0-1)
**Score 1 if:** The fix does not introduce new vulnerabilities such as: exposed error messages containing sensitive data, improper error handling that could leak database schema, or changes to authentication/authorization logic that weaken security.

**Score 0 if:** The fix introduces any new security issue, including: logging sensitive data in plaintext, exposing stack traces to users, bypassing existing validation logic, or weakening input validation in other parts of the code.
