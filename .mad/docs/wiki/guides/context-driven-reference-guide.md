# Context-Driven Reference Guide

Techniques for providing existing code as context when requesting new code, dramatically improving output quality and consistency.

---

## Table of Contents

1. [What Is Context-Driven Reference](#what-is-context-driven-reference)
2. [Why It Works](#why-it-works)
3. [When to Use](#when-to-use)
4. [How to Apply](#how-to-apply)
5. [Common Scenarios](#common-scenarios)
6. [Anti-Patterns](#anti-patterns)

---

## What Is Context-Driven Reference

Context-driven reference is the practice of pointing Claude to an existing file as a pattern template when asking it to create something new. Instead of describing the desired output from scratch, you reference a concrete example that already follows your project's conventions.

**The pattern**: "Create X following the patterns in `path/to/existing/Y`"

**Without context reference**:
> "Create a React component for user settings"

Claude guesses at your project's component structure, state management, styling approach, and test patterns. The result may work but likely diverges from your conventions.

**With context reference**:
> "Create a React component for user settings following the patterns in `src/components/UserProfile.tsx`"

Claude reads the referenced file, extracts the structural patterns (imports, hooks, state management, JSX structure, prop types, exports), and replicates them. The result is consistent with your codebase from the first attempt.

---

## Why It Works

### Pattern Replication Over Pattern Guessing

AI models produce significantly better output when shown a concrete example rather than relying on general training knowledge. The referenced file provides:

1. **Structural template** - File organization, import ordering, export patterns
2. **Convention evidence** - Naming conventions, error handling approach, logging style
3. **Technology choices** - Which libraries are actually used (not just what the model knows)
4. **Integration patterns** - How components connect to stores, APIs, and other services
5. **Test patterns** - Assertion style, fixture setup, mock approach

### Measured Impact

Teams adopting this pattern report:
- **2-3x fewer revision cycles** per component/endpoint/test
- **Consistent code style** without relying solely on linting
- **Reduced onboarding friction** for new patterns -- one good example propagates

### Why It Beats Detailed Prompts

A 500-word description of your component conventions is less effective than a single file reference because:
- Descriptions are ambiguous; code is precise
- Descriptions omit details you take for granted; code includes them
- Descriptions drift from reality; the referenced file IS reality

---

## When to Use

### Always Use Context References For

| Scenario | What to Reference |
|----------|-------------------|
| New React component | Existing component with similar complexity |
| New API endpoint/controller | Existing endpoint in same domain |
| New test file | Existing test file for similar code |
| New service/business logic class | Existing service with similar patterns |
| New database migration | Most recent migration file |
| New middleware | Existing middleware with similar concerns |
| New hook (React/custom) | Existing custom hook |
| New configuration/setup | Existing config file of same type |

### Skip Context References When

- Writing truly novel code with no existing patterns
- The existing codebase has patterns you want to **break from** (specify what to change)
- Simple one-liner changes or trivial edits
- README or documentation files (unless format consistency matters)

---

## How to Apply

### Step-by-Step

1. **Identify the closest existing example** in your codebase
   - Same layer (component, service, controller, test)
   - Similar complexity (don't reference a 50-line component when building a 500-line one)
   - Recent and well-maintained (not legacy code you plan to refactor)

2. **Construct the prompt with explicit reference**
   ```
   Create [description] following the patterns in `path/to/reference/file`
   ```

3. **Call out any intentional deviations**
   ```
   Create [description] following the patterns in `path/to/reference/file`,
   but use [different approach] for [specific aspect]
   ```

4. **For multi-file creation, reference multiple files**
   ```
   Create the UserSettings feature:
   - Component: follow `src/components/UserProfile.tsx`
   - Tests: follow `tests/components/UserProfile.test.tsx`
   - Store: follow `src/stores/userProfileStore.ts`
   ```

### Prompt Templates

**Component creation**:
```
Create a [ComponentName] component following the patterns in
`src/components/[ExistingComponent].tsx`. It should [functional requirements].
```

**API endpoint**:
```
Add a [METHOD] /api/[resource] endpoint following the patterns in
`src/controllers/[ExistingController].cs`. It should [functional requirements].
```

**Test file**:
```
Create tests for `src/[path/to/file]` following the test patterns in
`tests/[path/to/existing-test]`. Cover [specific scenarios].
```

**Service class**:
```
Create [ServiceName] following the patterns in `src/services/[ExistingService].cs`.
It should [functional requirements]. Include the same error handling and logging approach.
```

---

## Common Scenarios

### 1. React Component with State Management

**Bad**: "Create a campaign list component with filtering and pagination"

**Good**: "Create a CampaignList component following the patterns in `src/components/CharacterList.tsx`. It should display campaigns with name/description columns, support text filtering, and use cursor-based pagination. Follow the same Zustand store pattern as `src/stores/characterStore.ts`."

**Why**: CharacterList.tsx shows exactly how your project handles list rendering, loading states, empty states, error boundaries, and store integration. Claude replicates all of these automatically.

### 2. .NET Controller / API Endpoint

**Bad**: "Add CRUD endpoints for items"

**Good**: "Add CRUD endpoints for Item following the patterns in `src/Api/Controllers/CampaignController.cs`. Use the same Result pattern for error handling, the same validation approach, and the same response DTOs structure from `src/Application/DTOs/CampaignDtos.cs`."

**Why**: The reference controller shows your exact DI pattern, middleware usage, authorization attributes, response formatting, and error handling -- details that are tedious to describe but trivial to replicate.

### 3. Unit Test File

**Bad**: "Write tests for the CombatService"

**Good**: "Write tests for `src/Domain/Services/CombatService.cs` following the test patterns in `tests/Domain.Tests/Services/InitiativeServiceTests.cs`. Use the same fixture setup, assertion style, and test naming convention. Cover the happy path, validation failures, and edge cases for each public method."

**Why**: Test conventions vary wildly between projects (NSubstitute vs Moq, FluentAssertions vs Assert, test naming style, fixture patterns). The reference eliminates all ambiguity.

### 4. Database Migration

**Bad**: "Add a migration for the new Inventory table"

**Good**: "Create a database migration for the Inventory table following the patterns in `src/Infrastructure/Migrations/20260115_AddCampaignTable.cs`. Include the same index naming convention and nullable column annotations."

**Why**: Migrations have project-specific naming conventions, index strategies, and column annotation patterns. One reference file captures all of them.

### 5. Custom React Hook

**Bad**: "Create a hook for managing WebSocket connections"

**Good**: "Create a `useSignalRConnection` hook following the patterns in `src/hooks/useGameSession.ts`. Use the same connection lifecycle management, reconnection strategy, and cleanup approach. The hook should connect to the `/hubs/combat` endpoint."

**Why**: Hook structure (dependency arrays, cleanup functions, error state, loading state) varies by project. The reference ensures consistency.

### 6. Middleware / Cross-Cutting Concern

**Bad**: "Add request logging middleware"

**Good**: "Add request logging middleware following the patterns in `src/Api/Middleware/CorrelationIdMiddleware.cs`. Use the same middleware registration approach in `Program.cs` and the same structured logging format from `src/Infrastructure/Logging/LogMessages.cs`."

**Why**: Middleware involves registration order, DI patterns, and logging conventions that differ across projects.

### 7. Integration Test with Real Dependencies

**Bad**: "Write integration tests for the campaign API"

**Good**: "Write integration tests for the Campaign API endpoints following the patterns in `tests/Integration.Tests/Api/CharacterApiTests.cs`. Use the same `WebApplicationFactory` setup, database seeding approach, and response assertion style. Do NOT mock the database -- follow the same testcontainers pattern."

**Why**: Integration test infrastructure (factory setup, database lifecycle, authentication helpers) is complex and project-specific. The reference prevents the common mistake of writing unit tests disguised as integration tests.

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| No reference at all | Claude guesses conventions, 2-3x more revisions needed | Always provide at least one reference file |
| Referencing legacy/deprecated code | Propagates patterns you want to eliminate | Reference the newest, cleanest example |
| Referencing overly complex code | Claude copies unnecessary complexity | Pick a reference of similar complexity to the target |
| Referencing code from a different layer | Controller patterns don't apply to services | Match the layer: component->component, service->service |
| Multiple conflicting references | Claude tries to merge incompatible patterns | Use one primary reference, note specific deviations |
| "Follow all patterns in the entire project" | Too vague, no actionable signal | Point to 1-3 specific files |
| Referencing without mentioning deviations | Claude copies things you wanted changed | Explicitly state "same as X, except for Y" |

---

## Integration with MAD Workflow

During `/mad-implement`, agents should:

1. **Investigation phase**: Identify the best reference files for each implementation task
2. **Implementation phase**: Include reference file paths in every code-implementer prompt
3. **Review phase**: Verify new code matches referenced patterns

The `code-investigator` agent's report should include a "Reference Files" section listing the best pattern examples for each planned change. The `code-implementer` then uses these references directly.

---

## Summary

Context-driven reference is the single highest-leverage technique for improving AI code generation quality. One concrete example outperforms paragraphs of description. Make it a habit to include a reference file path in every request for new code.
