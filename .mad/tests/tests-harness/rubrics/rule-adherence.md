# Rule Adherence - Judge Rubric

## Context
The agent was asked to implement a feature following project patterns and conventions (e.g., adding a new API endpoint with proper DI, naming, and architecture).

## Instructions
You are evaluating code produced by an AI agent. Review the provided source files and score each criterion 0 or 1.

Return your assessment as JSON:
```json
{
  "criteria_scores": [
    { "criterion": "Pattern Match", "score": 0, "explanation": "..." },
    { "criterion": "DI Wiring", "score": 1, "explanation": "..." },
    { "criterion": "Naming Conventions", "score": 0, "explanation": "..." }
  ],
  "score": 1,
  "max_score": 3,
  "rationale": "Overall assessment in 1-2 sentences."
}
```

## Criteria

### 1. Pattern Match (0-1)
**Score 1 if:** The implementation follows existing codebase patterns for similar features. This includes: using the same layering (API -> BusinessLogic -> DataAccess), following the same dependency injection approach, matching error handling patterns (e.g., SanitizedException hierarchy), and using the same configuration patterns (e.g., IConfigOptions). Code structure mirrors comparable features in the codebase.

**Score 0 if:** The implementation introduces new patterns inconsistent with the codebase (e.g., directly accessing DataAccess from API layer, using different exception types, introducing new configuration mechanisms). Any significant deviation from established patterns results in a 0.

### 2. DI Wiring (0-1)
**Score 1 if:** Dependency injection is properly configured in `Program.cs` or the appropriate DI configuration file. Services are registered with the correct lifetime (Singleton, Scoped, Transient). Dependencies are injected through constructors. The code compiles and runs without DI resolution errors.

**Score 0 if:** DI registration is missing, incorrect (e.g., Singleton used where Scoped is required), or incomplete (e.g., registering the interface but not the implementation). Code that uses `new` to instantiate services instead of constructor injection is scored 0. Any DI configuration that causes runtime resolution errors is scored 0.

### 3. Naming Conventions (0-1)
**Score 1 if:** All names follow project conventions. This includes: PascalCase for classes and public members, camelCase for local variables and parameters, appropriate suffixes (e.g., `Options` for configuration classes, `Exception` for exception types), and file names matching class names with proper casing. Namespace follows the folder structure.

**Score 0 if:** Any naming convention violation exists. This includes: incorrect casing, missing or wrong suffixes, file names not matching class names, or namespaces inconsistent with folder structure. Even one violation results in a 0.
