# DAG Execution Guide

Comprehensive guide for writing DAG-optimized tasks in the MAD workflow with explicit dependencies, parallelization hints, and file ownership tracking.

---

## Table of Contents

1. [Overview](#overview)
2. [Task Format Reference](#task-format-reference)
3. [Optional DAG Fields](#optional-dag-fields)
4. [Migration Patterns](#migration-patterns)
5. [Wave Optimization](#wave-optimization)
6. [File Ownership](#file-ownership)
7. [Priority Computation](#priority-computation)
8. [Best Practices](#best-practices)
9. [Examples from Real Features](#examples-from-real-features)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### What is DAG Execution?

DAG (Directed Acyclic Graph) execution extends the traditional MAD workflow with:

- **Explicit dependencies**: Tasks declare their predecessors using task IDs
- **Automatic parallelization**: DAG engine groups independent tasks into execution waves
- **Cycle detection**: Circular dependencies are caught before execution begins
- **Critical path analysis**: Longest dependency chain identified for scheduling optimization
- **File conflict detection**: Prevent race conditions when multiple tasks modify the same files

### Backward Compatibility

DAG execution is **opt-in** and **backward compatible**:

- **Existing tasks.md files work unchanged**: No migration required
- **Implicit dependencies**: When no DAG annotations present, engine infers dependencies from phase order
- **Progressive adoption**: Add DAG fields incrementally as features benefit from parallelization

### Feature Flags

DAG execution is controlled via environment variables in `.claude/settings.local.json`:

| Flag | Default | Description |
|------|---------|-------------|
| `DAG_EXECUTION_MODE` | `classic` | Execution mode: `classic`, `dag-parse-only`, `dag-validate`, `dag-execute` |
| `DAG_VISUALIZATION_ENABLED` | `false` | Enable `/dag-visualize` skill |

See [dag-feature-flags.md](./dag-feature-flags.md) for complete flag reference.

---

## Task Format Reference

### Standard Task Structure (Unchanged)

Every task in tasks.md follows this format:

```markdown
- [ ] T001 Create ComfyUIOptions class in src/Infrastructure/AI/ComfyUIOptions.cs
  - **Functionality**: Configuration class for ComfyUI client settings with validation
  - **Purpose**: Type-safe configuration with fail-fast validation
  - **Progression**: Define class → add properties → implement IValidateOptions
  - **Success criteria**: Class compiles, ValidateOnStart() ensures invalid config prevents startup
```

Components:
1. **Checkbox**: `- [ ]` for pending, `- [x]` for complete
2. **Task ID**: Unique identifier (e.g., `T001`, `T010`)
3. **Description**: Brief summary with file path
4. **Context fields** (indented with `-`):
   - **Functionality**: What this task does (1 sentence)
   - **Purpose**: Why this task is needed (1 sentence)
   - **Progression**: Step-by-step flow (brief)
   - **Success criteria**: Deterministic verification gate

### Optional DAG Extensions

Add these fields **after** the standard context fields when explicit dependencies or parallelization hints are beneficial:

```markdown
- [ ] T020 Create ComfyUIClient class in src/Infrastructure/AI/ComfyUIClient.cs
  - **Functionality**: HTTP client for ComfyUI API
  - **Purpose**: Send generation requests and poll for results
  - **Progression**: Create class → add SubmitPromptAsync → add PollStatusAsync
  - **Success criteria**: Unit tests pass with mocked HttpClient
  - **Dependencies**: T010, T011
  - **Parallel Group**: comfyui-client
  - **Priority**: 5
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
```

DAG fields:
- **Dependencies**: Comma-separated list of task IDs that must complete before this task starts
- **Parallel Group**: Label for tasks that can execute concurrently (optional, for visualization)
- **Priority**: Execution priority (0 = highest, 100 = lowest)
- **Owned Files**: Files modified by this task (for conflict detection)

---

## Optional DAG Fields

### Dependencies

**Format**: `- **Dependencies**: T010, T020, T030`

**Purpose**: Explicitly declare which tasks must complete before this task can start.

**When to use**:
- Task reads outputs from another task (e.g., T020 uses ComfyUIOptions created by T010)
- Task extends functionality of another task (e.g., T030 adds error handling to T020's client)
- Task integrates components from multiple tasks (e.g., T040 uses T020 client + T030 service)

**When NOT to use**:
- Dependencies are obvious from phase order (Phase 2 implicitly depends on Phase 1)
- Task is independent (no dependencies = root node)

**Example**:
```markdown
- [ ] T040 Create PortraitGenerationService in src/Application/Services/
  - **Functionality**: Orchestrates portrait generation flow
  - **Dependencies**: T020, T030
  - **Success criteria**: Unit tests pass
```

**Interpretation**: T040 cannot start until both T020 (ComfyUIClient) and T030 (PromptBuilderService) are complete.

### Parallel Group

**Format**: `- **Parallel Group**: api-layer`

**Purpose**: Label tasks that can execute concurrently for visualization and scheduling hints.

**When to use**:
- Multiple tasks work on unrelated subsystems (e.g., `api-layer` vs `service-layer`)
- Tasks operate on disjoint file sets (e.g., `frontend-tests` vs `backend-tests`)
- Phase contains 3+ independent tasks that benefit from clear grouping

**When NOT to use**:
- Only 1-2 tasks in phase (overhead exceeds benefit)
- Tasks share dependencies (not truly parallel)

**Example**:
```markdown
Phase 3: Integration

- [ ] T050 Create PortraitGenerationController
  - **Parallel Group**: api-layer
  - **Owned Files**: src/Api/Controllers/PortraitGenerationController.cs

- [ ] T051 Create ComfyUIHealthController
  - **Parallel Group**: api-layer
  - **Owned Files**: src/Api/Controllers/ComfyUIHealthController.cs

- [ ] T060 Create PortraitGenerationServiceTests
  - **Parallel Group**: service-tests
  - **Owned Files**: tests/Application.Tests/Services/PortraitGenerationServiceTests.cs
```

**Visualization**: Parallel groups appear as subgraphs in Mermaid diagrams, making wave structure visible.

### Priority

**Format**: `- **Priority**: 5`

**Purpose**: Control execution order within a wave when multiple tasks are ready.

**Priority scale**:
- **0-9**: High priority (critical path, blockers for downstream tasks)
- **10-49**: Medium priority (normal development tasks)
- **50-100**: Low priority (cleanup, documentation, optional enhancements)

**Auto-computed when omitted**:
- 40% weight: Downstream task count (more downstream = higher priority)
- 40% weight: Critical path depth (deeper path = higher priority)
- 20% weight: Estimated duration (shorter tasks = slightly higher priority)

**When to set explicitly**:
- Task is on critical path (set priority 0-5)
- Task blocks many downstream tasks (set priority < 10)
- Task is low-stakes and can be deferred (set priority > 50)

**When to omit**:
- Let auto-computation handle priority (default behavior)
- Priority is obvious from dependencies

**Example**:
```markdown
- [ ] T010 Create ComfyUIOptions class
  - **Priority**: 0
  - **Rationale**: Blocks all ComfyUI integration tasks

- [ ] T099 Update documentation with API examples
  - **Priority**: 80
  - **Rationale**: Non-blocking, can be deferred
```

### Owned Files

**Format**: `- **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs, src/Infrastructure/AI/IComfyUIClient.cs`

**Purpose**: Declare which files this task modifies to detect file ownership conflicts.

**When to use**:
- Task creates or modifies source files (always include)
- Task works on files that might be modified by parallel tasks (conflict prevention)
- Phase has 2+ parallel tasks (required for conflict detection)

**When NOT to use**:
- Task is read-only (tests, validation, documentation review)
- Task modifies files unique to its scope (no risk of conflict)

**Glob patterns supported**:
```markdown
- **Owned Files**: src/Infrastructure/AI/*.cs
- **Owned Files**: tests/**/*ComfyUI*.cs
```

**File conflict detection**:
- Same file in same wave = **HIGH severity conflict** (serialize or move to next wave)
- Wildcard overlap with specific file = **HIGH severity conflict**
- Different files in same directory = **NO conflict**

**Example**:
```markdown
Phase 3: Parallel Implementation

- [ ] T050 Create PortraitGenerationController
  - **Parallel Group**: api-layer
  - **Owned Files**: src/Api/Controllers/PortraitGenerationController.cs

- [ ] T051 Create ComfyUIHealthController
  - **Parallel Group**: api-layer
  - **Owned Files**: src/Api/Controllers/ComfyUIHealthController.cs

# NO CONFLICT: Different files, safe to parallelize
```

**Conflict example**:
```markdown
Phase 2: Parallel Implementation

- [ ] T020 Add ComfyUIClient.SubmitPromptAsync method
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs

- [ ] T021 Add ComfyUIClient.PollStatusAsync method
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs

# CONFLICT DETECTED: Same file, same wave
# Resolution: Serialize (T021 depends on T020) or move T021 to Wave 2
```

---

## Migration Patterns

### From Implicit to Explicit Dependencies

**Before** (implicit dependencies via phase order):
```markdown
Phase 1: Setup
- [ ] T001 Create docker-compose.comfyui.yml
- [ ] T002 Add ComfyUI config to appsettings.json

Phase 2: Core Logic
- [ ] T010 Create ComfyUIOptions class
- [ ] T020 Create ComfyUIClient class
```

**After** (explicit dependencies unlock parallelization):
```markdown
Phase 1: Setup
- [ ] T001 Create docker-compose.comfyui.yml
  - **Parallel Group**: infrastructure

- [ ] T002 Add ComfyUI config to appsettings.json
  - **Parallel Group**: infrastructure

Phase 2: Core Logic
- [ ] T010 Create ComfyUIOptions class
  - **Dependencies**: T002
  - **Priority**: 0

- [ ] T020 Create ComfyUIClient class
  - **Dependencies**: T010
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
```

**Result**: T001 and T002 can execute in parallel (Wave 1), T010 executes in Wave 2, T020 executes in Wave 3.

### From Phase-Based to Wave-Based

**Before** (coarse-grained phases):
```markdown
Phase 2: Foundational Infrastructure (all sequential)
- [ ] T010 Create ComfyUIOptions
- [ ] T011 Create ComfyUIOptionsValidator
- [ ] T012 Create PortraitGeneratedEvent
- [ ] T013 Create PortraitGenerationFailedEvent
```

**After** (fine-grained waves):
```markdown
Phase 2: Foundational Infrastructure

- [ ] T010 Create ComfyUIOptions
  - **Priority**: 0

- [ ] T011 Create ComfyUIOptionsValidator
  - **Dependencies**: T010
  - **Owned Files**: src/Infrastructure/AI/ComfyUIOptionsValidator.cs

- [ ] T012 Create PortraitGeneratedEvent
  - **Parallel Group**: domain-events
  - **Owned Files**: src/Domain/Events/PortraitGeneratedEvent.cs

- [ ] T013 Create PortraitGenerationFailedEvent
  - **Parallel Group**: domain-events
  - **Owned Files**: src/Domain/Events/PortraitGenerationFailedEvent.cs
```

**Result**:
- Wave 1: T010
- Wave 2: T011, T012, T013 (all parallel)

### Adding File Ownership Incrementally

**Step 1**: Identify parallel tasks in same phase
```markdown
Phase 3: Integration
- [ ] T050 Create PortraitGenerationController
- [ ] T051 Create ComfyUIHealthController
- [ ] T060 Create PortraitGenerationServiceTests
```

**Step 2**: Add Owned Files to detect conflicts
```markdown
Phase 3: Integration
- [ ] T050 Create PortraitGenerationController
  - **Owned Files**: src/Api/Controllers/PortraitGenerationController.cs

- [ ] T051 Create ComfyUIHealthController
  - **Owned Files**: src/Api/Controllers/ComfyUIHealthController.cs

- [ ] T060 Create PortraitGenerationServiceTests
  - **Owned Files**: tests/Application.Tests/Services/PortraitGenerationServiceTests.cs
```

**Step 3**: Run conflict detection
```bash
node .claude/lib/file-ownership.js tasks.md
```

**Step 4**: Resolve conflicts if detected (add dependencies or move to next wave)

---

## Wave Optimization

### What Are Waves?

**Wave**: A group of tasks that can execute in parallel because all their dependencies are satisfied.

**Wave properties**:
- All tasks in Wave N have zero unresolved dependencies
- Wave N+1 depends on at least one task from Wave N
- Wave duration = max(task durations) since tasks run concurrently

**Example**:
```
Wave 1: T001, T002 (no dependencies)
Wave 2: T010 (depends on T002)
Wave 3: T020, T021, T022 (all depend on T010)
Wave 4: T030 (depends on T020, T021, T022)
```

### Critical Path

**Definition**: The longest weighted path through the dependency graph from any root to any leaf.

**Why it matters**:
- Critical path determines minimum project duration (sum of task durations on path)
- Tasks on critical path have zero slack (any delay delays the entire project)
- Non-critical tasks have slack (can be delayed without affecting project completion)

**Visualization**: Critical path edges are highlighted in red with bold arrows in `/dag-visualize` output.

**Example**:
```
T001 (5min) → T010 (10min) → T020 (15min) → T030 (5min) = 35min critical path
T002 (5min) → T012 (5min) = 10min non-critical path

Total project duration: 35min (determined by critical path)
```

### Optimization Strategies

**Strategy 1: Parallelize independent tasks**
```markdown
# Before: Sequential (30min total)
- [ ] T020 Create ComfyUIClient (10min)
- [ ] T021 Create PromptBuilderService (10min)
- [ ] T022 Create ImageStorageService (10min)

# After: Parallel (10min total, all in same wave)
- [ ] T020 Create ComfyUIClient
  - **Parallel Group**: services
- [ ] T021 Create PromptBuilderService
  - **Parallel Group**: services
- [ ] T022 Create ImageStorageService
  - **Parallel Group**: services
```

**Strategy 2: Front-load critical path tasks**
```markdown
# High priority = execute first when multiple tasks ready
- [ ] T010 Create ComfyUIOptions
  - **Priority**: 0
  - **Rationale**: On critical path, blocks 10 downstream tasks
```

**Strategy 3: Defer low-priority tasks**
```markdown
# Low priority = execute last within wave
- [ ] T099 Update API documentation
  - **Priority**: 80
  - **Rationale**: Non-blocking, can be deferred to end
```

**Strategy 4: Break long tasks into smaller chunks**
```markdown
# Before: Single task blocks downstream
- [ ] T020 Create complete ComfyUIClient (30min)

# After: Incremental tasks unblock earlier
- [ ] T020 Create ComfyUIClient skeleton (5min)
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
- [ ] T021 Add SubmitPromptAsync method (10min)
  - **Dependencies**: T020
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
- [ ] T022 Add PollStatusAsync method (10min)
  - **Dependencies**: T020
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
```

---

## File Ownership

### Why Track File Ownership?

**Problem**: When multiple tasks in the same wave modify the same file, race conditions occur:
- Task A writes method X to ComfyUIClient.cs
- Task B writes method Y to ComfyUIClient.cs (concurrently)
- Result: Merge conflict, lost work, or corrupted file

**Solution**: Explicit file ownership prevents conflicts before execution:
- Extract file paths from task metadata (dag.ownedFiles) or description text
- Build file-to-task mapping
- Detect conflicts (same file, same wave)
- Propose resolution strategies (serialize or move-to-next-wave)

### File Path Extraction

**Explicit metadata** (preferred):
```markdown
- [ ] T020 Create ComfyUIClient class
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs, src/Infrastructure/AI/IComfyUIClient.cs
```

**Implicit from description** (fallback):
```markdown
- [ ] T020 Create ComfyUIClient class in src/Infrastructure/AI/ComfyUIClient.cs
```

**Glob patterns**:
```markdown
- [ ] T050 Create API controllers
  - **Owned Files**: src/Api/Controllers/*Controller.cs
```

**Path normalization**:
- Strip leading `./` and `../` prefixes
- Normalize backslashes to forward slashes
- Validate against `VALID_PATH_PREFIXES` (`src/`, `tests/`, `lib/`, `frontend/`, `infra/`)

### Conflict Detection

**Same file, same wave** = HIGH severity conflict:
```markdown
Wave 2:
- [ ] T020 Add SubmitPromptAsync to ComfyUIClient.cs
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
- [ ] T021 Add PollStatusAsync to ComfyUIClient.cs
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs

# CONFLICT: Same file modified by 2 tasks in Wave 2
```

**Wildcard overlap** = HIGH severity conflict:
```markdown
Wave 2:
- [ ] T050 Create PortraitGenerationController.cs
  - **Owned Files**: src/Api/Controllers/PortraitGenerationController.cs
- [ ] T051 Refactor all controllers
  - **Owned Files**: src/Api/Controllers/*.cs

# CONFLICT: Wildcard overlaps with specific file
```

**Different files** = NO conflict:
```markdown
Wave 2:
- [ ] T050 Create PortraitGenerationController.cs
  - **Owned Files**: src/Api/Controllers/PortraitGenerationController.cs
- [ ] T051 Create ComfyUIHealthController.cs
  - **Owned Files**: src/Api/Controllers/ComfyUIHealthController.cs

# NO CONFLICT: Different files, safe to parallelize
```

### Resolution Strategies

**Serialize strategy**: Keep first task in wave, move subsequent tasks to incrementally later waves.

**Example**:
```markdown
# Before (conflict in Wave 2):
Wave 2: T020, T021, T022 (all modify ComfyUIClient.cs)

# After (serialized):
Wave 2: T020
Wave 3: T021
Wave 4: T022
```

**MoveToNext strategy**: Move all conflicting tasks (except first) to next wave.

**Example**:
```markdown
# Before (conflict in Wave 2):
Wave 2: T020, T021, T022 (all modify ComfyUIClient.cs)

# After (moved to next):
Wave 2: T020
Wave 3: T021, T022 (still parallel if no further conflicts)
```

**Manual resolution**: Add explicit dependencies to enforce order.

**Example**:
```markdown
- [ ] T021 Add PollStatusAsync to ComfyUIClient.cs
  - **Dependencies**: T020
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
```

---

## Priority Computation

### Explicit Priority

Set priority explicitly when task priority is critical:

```markdown
- [ ] T010 Create ComfyUIOptions class
  - **Priority**: 0
  - **Rationale**: On critical path, blocks all ComfyUI integration tasks
```

Priority scale:
- **0-9**: High priority (critical path, blockers)
- **10-49**: Medium priority (normal tasks)
- **50-100**: Low priority (cleanup, documentation)

### Auto-Computed Priority

When priority is omitted, the DAG engine computes it from graph structure:

**Algorithm**:
```javascript
function computePriority(node, graph) {
  if (node.dag.priority != null) {
    return clamp(node.dag.priority, 0, 100);
  }

  const downstreamCount = countDownstreamTasks(node, graph);
  const criticalPathDepth = computeLongestPathFromNode(node, graph);
  const estimatedDuration = node.dag.estimatedDuration || 300; // 5min default

  let priority = 50;
  priority -= (downstreamCount * 5);       // More downstream = higher priority
  priority -= (criticalPathDepth * 3);     // Deeper path = higher priority
  priority += (estimatedDuration / 100);   // Shorter duration = higher priority

  return clamp(priority, 0, 100);
}
```

**Intuition**:
- Tasks with many downstream dependents get higher priority (unblock more work)
- Tasks on longer paths get higher priority (reduce critical path)
- Shorter tasks get slightly higher priority (quick wins)

**Example**:
```
T010: 10 downstream tasks, path depth 5, duration 5min
  priority = 50 - (10*5) - (5*3) + (5*60/100) = 50 - 50 - 15 + 3 = -12 → 0 (clamped)

T099: 0 downstream tasks, path depth 0, duration 30min
  priority = 50 - 0 - 0 + (30*60/100) = 50 + 18 = 68
```

### Wave Sorting

Within a wave, tasks are sorted by priority (ascending: 0 before 100).

**Example**:
```markdown
Wave 2 (all ready to execute):
- T010 (priority 0) ← Execute first
- T020 (priority 15)
- T021 (priority 15)
- T099 (priority 68) ← Execute last
```

---

## Best Practices

### When to Add DAG Annotations

**Add Dependencies when**:
- Task has non-obvious predecessors (not inferred from phase order)
- Task integrates outputs from multiple prior tasks
- Phase has complex dependency chains (3+ levels deep)

**Add Parallel Group when**:
- Phase contains 3+ independent tasks
- Visualization would benefit from logical grouping
- Tasks operate on distinct subsystems (api-layer, service-layer, tests)

**Add Priority when**:
- Task is on critical path (set 0-5)
- Task blocks many downstream tasks (set < 10)
- Task is low-stakes and can be deferred (set > 50)

**Add Owned Files when**:
- Task creates or modifies source files
- Phase has 2+ parallel tasks (required for conflict detection)
- Files might be modified by other tasks (prevent race conditions)

### When to Omit DAG Annotations

**Omit Dependencies when**:
- Dependencies are obvious from phase order
- Task has no dependencies (root node)
- Overhead of tracking exceeds benefit

**Omit Parallel Group when**:
- Only 1-2 tasks in phase
- All tasks are sequential (no parallelization benefit)

**Omit Priority when**:
- Auto-computation handles priority adequately
- Task priority is average (not critical, not deferrable)

**Omit Owned Files when**:
- Task is read-only (no file modifications)
- Task modifies files unique to its scope (no conflict risk)

### File Ownership Best Practices

**DO**:
- ✅ Use glob patterns for related files: `src/Api/Controllers/*.cs`
- ✅ List all modified files explicitly when file set is small
- ✅ Run conflict detection before executing parallel phases
- ✅ Resolve conflicts by adding dependencies or moving to next wave

**DON'T**:
- ❌ Use overlapping wildcards: `src/**/*.cs` and `src/Api/**/*.cs` conflict
- ❌ Forget to add Owned Files when task modifies source files
- ❌ Ignore conflict warnings (serialization prevents race conditions)
- ❌ Use absolute paths: Stick to repository-relative paths

### Priority Best Practices

**DO**:
- ✅ Set priority 0-5 for critical path tasks
- ✅ Set priority > 50 for cleanup/documentation tasks
- ✅ Let auto-computation handle normal tasks (10-49)
- ✅ Document rationale for explicit priority

**DON'T**:
- ❌ Set priority on every task (over-specification)
- ❌ Use priority to force execution order (use Dependencies instead)
- ❌ Set priority < 0 or > 100 (will be clamped)

---

## Examples from Real Features

### Example 1: ComfyUI Integration (001-docker-local-ai)

**Phase 1: Setup** (parallel tasks, no dependencies):
```markdown
- [ ] T001 Create docker-compose.comfyui.yml
  - **Parallel Group**: infrastructure
  - **Owned Files**: docker-compose.comfyui.yml

- [ ] T002 Add ComfyUI config to appsettings.json
  - **Parallel Group**: infrastructure
  - **Owned Files**: src/Api/appsettings.Development.json

- [ ] T003 Create src/Infrastructure/AI/ directory
  - **Parallel Group**: infrastructure

- [ ] T004 Create wwwroot/images/portraits/ directory
  - **Parallel Group**: infrastructure
```

**Result**: Wave 1 contains all 4 tasks (all parallel, no conflicts).

**Phase 2: Foundational Infrastructure** (explicit dependencies):
```markdown
- [ ] T010 Create ComfyUIOptions class
  - **Dependencies**: T002
  - **Priority**: 0
  - **Owned Files**: src/Infrastructure/AI/ComfyUIOptions.cs

- [ ] T011 Create ComfyUIOptionsValidator
  - **Dependencies**: T010
  - **Owned Files**: src/Infrastructure/AI/ComfyUIOptionsValidator.cs

- [ ] T012 Create PortraitGeneratedEvent
  - **Parallel Group**: domain-events
  - **Owned Files**: src/Domain/Events/PortraitGeneratedEvent.cs

- [ ] T013 Create PortraitGenerationFailedEvent
  - **Parallel Group**: domain-events
  - **Owned Files**: src/Domain/Events/PortraitGenerationFailedEvent.cs
```

**Result**:
- Wave 1: T010 (priority 0, on critical path)
- Wave 2: T011, T012, T013 (all parallel)

### Example 2: API Layer (parallel controllers)

**Phase 3: Integration** (parallel tasks, no conflicts):
```markdown
- [ ] T050 Create PortraitGenerationController
  - **Parallel Group**: api-layer
  - **Dependencies**: T040
  - **Owned Files**: src/Api/Controllers/PortraitGenerationController.cs

- [ ] T051 Create ComfyUIHealthController
  - **Parallel Group**: api-layer
  - **Dependencies**: T040
  - **Owned Files**: src/Api/Controllers/ComfyUIHealthController.cs

- [ ] T060 Create PortraitGenerationServiceTests
  - **Parallel Group**: service-tests
  - **Dependencies**: T040
  - **Owned Files**: tests/Application.Tests/Services/PortraitGenerationServiceTests.cs
```

**Result**: Wave 1 contains T050, T051, T060 (all parallel, different files).

### Example 3: Sequential Refinement (file conflict)

**Before** (conflict detected):
```markdown
- [ ] T020 Add ComfyUIClient.SubmitPromptAsync method
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs

- [ ] T021 Add ComfyUIClient.PollStatusAsync method
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs

# CONFLICT: Same file, same wave
```

**After** (serialized with explicit dependency):
```markdown
- [ ] T020 Add ComfyUIClient.SubmitPromptAsync method
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs

- [ ] T021 Add ComfyUIClient.PollStatusAsync method
  - **Dependencies**: T020
  - **Owned Files**: src/Infrastructure/AI/ComfyUIClient.cs
```

**Result**: T020 in Wave 1, T021 in Wave 2 (serialized).

---

## Troubleshooting

### Cycle Detection Errors

**Error**: "Cycle detected in task dependency graph: T010 → T020 → T030 → T010"

**Cause**: Circular dependencies create infinite loop.

**Solution**:
1. Visualize graph: `/dag-visualize` to see cycle
2. Identify breaking point: Which dependency is incorrect?
3. Remove or reverse dependency: Break cycle by reordering or splitting tasks

**Example**:
```markdown
# Before (cycle):
- [ ] T010 Create Options
  - **Dependencies**: T030
- [ ] T020 Create Client
  - **Dependencies**: T010
- [ ] T030 Configure Client
  - **Dependencies**: T020

# After (cycle broken):
- [ ] T010 Create Options
- [ ] T020 Create Client
  - **Dependencies**: T010
- [ ] T030 Configure Client
  - **Dependencies**: T020
```

### File Conflict Warnings

**Warning**: "File conflict detected: src/Infrastructure/AI/ComfyUIClient.cs modified by T020, T021 in Wave 2"

**Cause**: Multiple tasks in same wave modify same file.

**Solution 1: Add explicit dependency**:
```markdown
- [ ] T021 Add PollStatusAsync method
  - **Dependencies**: T020
```

**Solution 2: Move to next wave**:
```markdown
# Keep T020 in current wave, manually move T021 to next phase
```

**Solution 3: Verify false positive**:
- If tasks modify different methods/regions, conflict may be acceptable
- Use code review to ensure no actual race condition

### Priority Inversion

**Symptom**: Low-priority task executes before high-priority task in same wave.

**Cause**: Wave contains multiple ready tasks, but low-priority task was encountered first.

**Solution**: Set explicit priority for critical tasks:
```markdown
- [ ] T010 Create ComfyUIOptions
  - **Priority**: 0
  - **Rationale**: On critical path
```

### Missing Dependencies

**Symptom**: Task executes before prerequisite, causing failure.

**Cause**: Implicit dependency not captured in DAG annotations.

**Solution**: Add explicit dependency:
```markdown
- [ ] T020 Create ComfyUIClient
  - **Dependencies**: T010
```

### Overlapping Wildcards

**Error**: "Wildcard conflict detected: src/**/*.cs and src/Api/**/*.cs"

**Cause**: Two tasks use overlapping glob patterns.

**Solution**: Make wildcards more specific or use explicit file lists:
```markdown
# Before (overlapping):
- [ ] T050 Refactor all source files
  - **Owned Files**: src/**/*.cs
- [ ] T051 Refactor API layer
  - **Owned Files**: src/Api/**/*.cs

# After (specific):
- [ ] T050 Refactor domain layer
  - **Owned Files**: src/Domain/**/*.cs
- [ ] T051 Refactor API layer
  - **Owned Files**: src/Api/**/*.cs
```

### Graph Parsing Errors

**Error**: "Invalid task ID: T01A"

**Cause**: Task ID format does not match expected pattern (T followed by digits).

**Solution**: Use standardized task ID format: `T001`, `T010`, `T100`.

**Error**: "Task T020 not found in dependency list"

**Cause**: Task references non-existent task ID in Dependencies field.

**Solution**: Verify all referenced task IDs exist in tasks.md.

---

## Summary

### Key Takeaways

1. **DAG annotations are optional**: Add them incrementally when parallelization benefits justify the overhead.
2. **Dependencies unlock parallelization**: Explicit dependencies allow DAG engine to discover independent tasks.
3. **File ownership prevents conflicts**: Always add Owned Files when task modifies source files.
4. **Priority controls execution order**: Use explicit priority for critical path tasks, let auto-computation handle the rest.
5. **Visualization reveals structure**: Use `/dag-visualize` to see waves, critical path, and conflicts.

### Quick Reference

| Field | When to Add | When to Omit |
|-------|-------------|--------------|
| **Dependencies** | Task has non-obvious predecessors | Dependencies obvious from phase order |
| **Parallel Group** | 3+ independent tasks in phase | Only 1-2 tasks, all sequential |
| **Priority** | Critical path or deferrable task | Normal priority, auto-computation adequate |
| **Owned Files** | Task modifies source files | Read-only task, no conflict risk |

### Next Steps

1. **Enable DAG parsing**: Set `DAG_EXECUTION_MODE=dag-parse-only` in `.claude/settings.local.json`
2. **Visualize existing tasks**: Run `/dag-visualize` on current tasks.md
3. **Add Dependencies incrementally**: Start with obvious dependencies, expand as needed
4. **Run conflict detection**: Use `file-ownership.js` to detect file conflicts
5. **Review critical path**: Identify bottleneck tasks, consider breaking into smaller chunks

See [dag-feature-flags.md](./dag-feature-flags.md) for phase rollout plan and execution modes.
