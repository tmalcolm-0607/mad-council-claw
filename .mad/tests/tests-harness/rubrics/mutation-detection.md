# Mutation Detection - Judge Rubric

## Context
The agent was asked to review a consumer-project codebase and identify/fix bugs, security issues, performance problems, and convention violations. The codebase contains injected mutations (domain-specific defects).

## Instructions
You are evaluating code produced by an AI agent. The agent was given a codebase with deliberate defects and asked to find and fix them. Score each criterion 0 or 1.

Return your assessment as JSON:
```json
{
  "criteria_scores": [
    { "criterion": "Defect Detection", "score": 0, "explanation": "..." },
    { "criterion": "Root Cause Accuracy", "score": 1, "explanation": "..." },
    { "criterion": "Fix Correctness", "score": 0, "explanation": "..." },
    { "criterion": "No Regressions", "score": 1, "explanation": "..." },
    { "criterion": "Precision", "score": 0, "explanation": "..." }
  ],
  "score": 2,
  "max_score": 5,
  "rationale": "Overall assessment in 1-2 sentences."
}
```

## Criteria

### 1. Defect Detection (0-1)
**Score 1 if:** The agent identified the injected defect and described it in its output. The agent's description matches the category of the defect (e.g., "wrong partition key" for a Cosmos DB mutation, "missing authorization" for a security mutation).

**Score 0 if:** The agent did not identify the defect, or described a completely different issue in the same file without addressing the actual defect.

### 2. Root Cause Accuracy (0-1)
**Score 1 if:** The agent correctly described WHY the code is wrong, not just that it is wrong. For example, explaining that using `Id` as partition key causes cross-partition queries, or that string interpolation in queries enables NoSQL injection.

**Score 0 if:** The agent found the defect but gave an incorrect or vague explanation of the root cause (e.g., "this looks wrong" without explaining the consequence).

### 3. Fix Correctness (0-1)
**Score 1 if:** The agent's fix resolves the defect correctly. The fix follows the ecosystem patterns (e.g., uses `CaseNumber` for partition key, uses parameterized queries, uses `LoggerMessage` source generators). The fix does not introduce new defects.

**Score 0 if:** The fix is incorrect, incomplete, or introduces new patterns inconsistent with the codebase. A fix that "works" but violates conventions scores 0.

### 4. No Regressions (0-1)
**Score 1 if:** After the agent's modifications, the project still builds (`dotnet build` succeeds) and no existing functionality is broken. The agent did not remove or alter correct code.

**Score 0 if:** The build fails, or the agent made changes to correct code that broke existing functionality.

### 5. Precision (0-1)
**Score 1 if:** The agent only modified code related to the injected defect. Changes are targeted and minimal. No unnecessary refactoring or "improvements" to correct code.

**Score 0 if:** The agent made extensive changes beyond the defect, modified correct code, or added unnecessary features/refactoring. False positives (flagging correct code as defective) result in a 0.
