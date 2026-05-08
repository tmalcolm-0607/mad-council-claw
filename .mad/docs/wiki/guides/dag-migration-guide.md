# DAG Migration Guide

User-facing guide for migrating from classic phase-based task execution to DAG (Directed Acyclic Graph) wave-based execution.

---

## Table of Contents

1. [What is DAG Execution?](#what-is-dag-execution)
2. [Why Use DAG Execution?](#why-use-dag-execution)
3. [Migration Checklist](#migration-checklist)
4. [How to Opt-In](#how-to-opt-in)
5. [Adding Explicit Dependencies](#adding-explicit-dependencies)
6. [Rollback Procedures](#rollback-procedures)
7. [Troubleshooting](#troubleshooting)
8. [Before/After Examples](#beforeafter-examples)

---

## What is DAG Execution?

DAG (Directed Acyclic Graph) execution is an optional enhancement to the MAD workflow that enables:

- **Parallel task execution** - Tasks with satisfied dependencies run concurrently in waves
- **Explicit dependency tracking** - Tasks declare exactly what they depend on instead of relying on phase order
- **File conflict detection** - System prevents race conditions when multiple tasks modify the same files
- **Intelligent scheduling** - Priority-based execution within waves, critical path analysis

DAG execution is **completely backward compatible**. All existing `tasks.md` files work unchanged. The DAG system infers dependencies from phase order when explicit annotations are absent.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Wave** | A group of tasks that can execute in parallel because their dependencies are satisfied |
| **Dependency** | A task cannot start until its dependencies complete successfully |
| **File Ownership** | Tasks declare which files they modify to prevent parallel write conflicts |
| **Critical Path** | The longest chain of dependent tasks -- determines minimum completion time |

---

## Why Use DAG Execution?

### Benefits

| Benefit | Description | When It Matters |
|---------|-------------|-----------------|
| **Faster execution** | Parallel task execution reduces wall-clock time | Large features (>20 tasks) with parallel work |
| **Better visibility** | Explicit dependencies make execution order transparent | Complex features with cross-phase dependencies |
| **Safer parallelism** | File conflict detection prevents race conditions | Using Agent Teams for parallel implementation |
| **Optimized scheduling** | Critical path analysis ensures high-priority work runs first | Performance-critical features |

### When to Migrate

| Scenario | Recommendation |
|----------|---------------|
| Simple linear feature (<10 tasks) | **Stay with classic mode** -- overhead not justified |
| Feature with Agent Teams parallelization | **Migrate to dag-validate first** -- add file ownership |
| Complex multi-layer feature (>20 tasks) | **Consider dag-execute** -- explicit dependencies improve clarity |
| Feature with cross-phase dependencies | **Migrate to dag-parse-only** -- unlock earlier execution |

### When NOT to Migrate

| Scenario | Rationale |
|----------|-----------|
| Single-step tasks | No benefit from dependency tracking |
| Throwaway spike or prototype | Migration overhead exceeds value |
| All work is inherently sequential | No parallelism to unlock |
| Team unfamiliar with DAG concepts | Learning curve may slow initial work |

---

## Migration Checklist

Follow this checklist to migrate from classic to DAG execution:

### Phase 0: Prerequisites

- [ ] Review DAG concepts in [dag-execution-guide.md](./dag-execution-guide.md)
- [ ] Review feature flags in [dag-feature-flags.md](./dag-feature-flags.md)
- [ ] Confirm `.claude/lib/dag-engine.js` exists and tests pass
- [ ] Confirm `.claude/lib/dag-executor.js` exists

### Phase 1: Parse-Only Mode (Validation)

- [ ] Set `DAG_EXECUTION_MODE=dag-parse-only` in `.claude/settings.local.json`
- [ ] Enable visualization: `DAG_VISUALIZATION_ENABLED=true`
- [ ] Run `/mad-tasks` for an existing feature to verify parsing works
- [ ] Run `/dag-visualize` on the generated tasks.md
- [ ] Verify graph structure matches your understanding of dependencies

**Expected Outcome**: DAG parses successfully, visualization shows expected structure, execution remains unchanged.

### Phase 2: Add Explicit Dependencies (Optional)

If your feature has cross-phase dependencies or you want to unlock parallelism:

- [ ] Run `/dag-migrate specs/<feature>/tasks.md --dry-run` to preview changes
- [ ] Review inferred dependencies for correctness
- [ ] Apply migration: `/dag-migrate specs/<feature>/tasks.md`
- [ ] Verify updated tasks.md with `/dag-visualize`

**Expected Outcome**: Tasks have explicit `Dependencies` fields, graph reflects true ordering constraints.

### Phase 3: Validation Mode (Warnings)

- [ ] Set `DAG_EXECUTION_MODE=dag-validate`
- [ ] Run `/mad-implement` for the feature
- [ ] Review any cycle warnings (fatal -- must fix)
- [ ] Review any file conflict warnings (non-fatal but should fix)
- [ ] Fix all reported issues

**Expected Outcome**: No warnings, execution still classic phase-by-phase but structure validated.

### Phase 4: Execute Mode (Parallel Waves)

- [ ] Set `DAG_EXECUTION_MODE=dag-execute`
- [ ] Run `/mad-implement` for the feature
- [ ] Monitor wave execution and timing
- [ ] Compare wall-clock time to classic execution
- [ ] Verify all quality gates pass

**Expected Outcome**: Tasks execute in parallel waves, quality gates pass, faster completion time.

### Phase 5: Iterate and Refine

- [ ] Add `Priority` fields to critical path tasks if needed
- [ ] Add `Parallel Group` fields for visualization clarity
- [ ] Add `Owned Files` if using Agent Teams
- [ ] Re-run `/dag-visualize` to verify improvements

---

## How to Opt-In

DAG execution is controlled by environment variables in `.claude/settings.local.json`. This file is local to each developer and not committed to version control.

### Step 1: Create or Edit settings.local.json

Location: `C:\source\my-project\.claude\settings.local.json`

If the file doesn't exist, create it:

```json
{
  "env": {}
}
```

### Step 2: Set Execution Mode

Add the `DAG_EXECUTION_MODE` flag:

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-parse-only"
  }
}
```

### Step 3: Enable Visualization (Optional but Recommended)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-parse-only",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

### Step 4: Graduate Through Modes

| Mode | When to Use |
|------|-------------|
| `dag-parse-only` | Initial validation -- verify structure without changing execution |
| `dag-validate` | Detect issues -- warnings for cycles and conflicts |
| `dag-execute` | Full parallelism -- wave-based execution |

**Recommended Path**: `classic` → `dag-parse-only` → `dag-validate` → `dag-execute`

---

## Adding Explicit Dependencies

Explicit dependencies unlock cross-phase parallelism and make execution order transparent.

### Method 1: Automatic via /dag-migrate

The `/dag-migrate` skill analyzes an existing tasks.md and infers dependencies:

```bash
/dag-migrate specs/015-user-management/tasks.md
```

**What it does**:
- Parses phase structure and task ordering
- Extracts file paths from task descriptions
- Infers dependencies from cross-references and file relationships
- Adds `Dependencies` and `Owned Files` fields to all tasks

**Options**:
- `--dry-run` - Preview changes without writing
- `--parallel-groups` - Also add `Parallel Group` fields
- `--priority` - Also add `Priority` fields

**Review the output** -- automatic inference is conservative and may include unnecessary dependencies.

### Method 2: Manual Annotation

Add `Dependencies` field to tasks in your tasks.md:

```markdown
- [ ] T030 Implement UserService in src/services/user.ts
  - **Success criteria**: All unit tests pass
  - **Dependencies**: T010, T020
  - **Owned Files**: src/services/user.ts, tests/services/user.test.ts
```

**Syntax rules**:
- Use task IDs only: `T010, T020`
- Separate multiple IDs with commas
- Use `(none)` or omit field for root tasks
- Dependencies must reference valid task IDs in the same file

### Optional Fields

| Field | Purpose | When to Add |
|-------|---------|-------------|
| `Parallel Group` | Group related tasks for visualization | Features with multiple parallel layers |
| `Priority` | Control execution order within waves (0=highest, 100=lowest) | Critical path tasks need priority |
| `Owned Files` | Declare file modifications for conflict detection | **Always** when using Agent Teams |

---

## Rollback Procedures

### Quick Rollback: Revert to Classic Mode

Set `DAG_EXECUTION_MODE` to `classic` in `.claude/settings.local.json`:

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "classic"
  }
}
```

**Effect**: All DAG features disabled immediately. Execution reverts to traditional phase-by-phase ordering.

**Safe?** Yes. All other `DAG_*` flags are ignored in classic mode. No code changes required.

### Complete Removal

Remove all `DAG_*` entries from settings:

```json
{
  "env": {}
}
```

**Effect**: Clean configuration with no DAG artifacts.

### Reverting tasks.md Annotations

If you added explicit dependencies and want to revert:

1. **Via version control**: `git checkout HEAD -- specs/<feature>/tasks.md`
2. **Via /dag-migrate --rollback**: (Future enhancement) Removes DAG fields while preserving other content
3. **Manual removal**: Delete `Dependencies`, `Parallel Group`, `Priority`, and `Owned Files` fields

**Backward compatibility**: Tasks with DAG fields still work in classic mode -- the fields are simply ignored.

### Troubleshooting Rollback

| Symptom | Fix |
|---------|-----|
| DAG still active after setting `classic` mode | Restart Claude Code session to reload config |
| Settings file not taking effect | Verify file location: `.claude/settings.local.json` (relative to repo root) |
| Syntax error in settings.json | Validate JSON syntax (trailing commas not allowed) |

---

## Troubleshooting

### Parsing and Validation Issues

#### Symptom: Cycle Detected

```
Error: Cycle detected in task dependencies: T010 -> T020 -> T030 -> T010
```

**Cause**: Tasks form a circular dependency chain.

**Fix**:
1. Review the dependency path listed in the error
2. Identify the incorrect dependency (usually the last one in the cycle)
3. Remove or redirect one dependency to break the cycle
4. Consider adding an intermediate task if bidirectional relationship is needed

**Prevention**: Use `/dag-visualize` to catch cycles before execution.

#### Symptom: File Ownership Conflict

```
Warning: File conflict in wave 2: src/routes/index.ts owned by both T013 and T022
```

**Cause**: Two tasks in the same wave modify the same file.

**Fix options**:
1. **Add dependency**: Make T022 depend on T013 to serialize them
2. **Merge tasks**: Combine T013 and T022 if they logically belong together
3. **Split shared file**: Refactor so each task modifies separate files

**Prevention**: Always add `Owned Files` to tasks when using Agent Teams.

#### Symptom: Priority Not Having Effect

High-priority task executes after lower-priority tasks.

**Cause**: Priority only controls ordering *within a wave*. Dependencies determine wave assignment.

**Fix**: Add an explicit dependency if task A must execute before task B. Priority is a scheduling hint, not an override for the dependency graph.

### Execution Issues

#### Symptom: Tasks Not Parallelizing

Tasks with `[P]` markers execute sequentially despite DAG mode enabled.

**Possible causes**:
1. **Mode not set to dag-execute** - Check `DAG_EXECUTION_MODE`
2. **Agent Teams not enabled** - Verify `.claude/agent-teams-config.json` exists and `config.enabled=true`
3. **Implicit phase dependencies** - Add explicit `Dependencies` to override phase-order inference
4. **File ownership conflicts** - Tasks touching same files cannot parallelize

**Debug steps**:
1. Run `/dag-visualize` to see computed waves
2. Check wave assignments -- tasks should be in same wave if they can parallelize
3. Review file ownership for conflicts
4. Verify Agent Teams config: `implement-parallel: "teams"`

#### Symptom: Context Budget Exceeded

```
Error: Context budget exceeded (87.3% > 85.0% threshold). 4 waves remaining. Handoff required.
```

**Cause**: DAG executor monitors context usage and halts when capacity is low.

**Fix**:
1. System will generate a handoff document automatically
2. Start a new session and run `/resume-handoff` to continue
3. Consider adjusting threshold in dag-executor.js if false positive

**Prevention**: Break large features into smaller work items with checkpoints.

### Performance Issues

#### Symptom: DAG Slower Than Classic

**Possible causes**:
1. **Overhead exceeds benefit** - Feature may be too small (<10 tasks)
2. **Serialization due to conflicts** - File ownership conflicts prevent parallelism
3. **Wave synchronization overhead** - Quality gates run after each wave

**Fix**:
1. Measure: Compare wall-clock time for classic vs DAG execution
2. Analyze: Run `/dag-visualize` to see critical path and wave count
3. Optimize: Reduce file conflicts, merge small tasks, adjust priority
4. Consider reverting to classic mode if no speed improvement

---

## Before/After Examples

### Example 1: Simple Linear Feature (No Changes Needed)

**Before (Classic Mode)**:

```markdown
## Phase 1: Setup
- [ ] T001 Create database schema
  - **Success criteria**: Schema applied

## Phase 2: Implementation
- [ ] T002 Create UserService
  - **Success criteria**: Tests pass

- [ ] T003 Create UserController
  - **Success criteria**: Endpoints work
```

**After (DAG Parse-Only Mode)**:

Same file, no changes needed. DAG engine infers:
- Wave 1: T001
- Wave 2: T002, T003 (can parallelize)

**Benefit**: Parallelism discovered automatically without annotation.

---

### Example 2: Cross-Phase Dependencies

**Before (Classic Mode)**:

```markdown
## Phase 2: Foundational
- [ ] T010 Create database schema
- [ ] T011 Setup API server

## Phase 3: User Story 1
- [ ] T020 Implement UserService
  - Depends on database schema (T010)

## Phase 4: User Story 2
- [ ] T030 Implement OrderService
  - Depends on database schema (T010)
```

**Problem**: Classic mode forces T030 to wait for all of Phase 3, even though it only needs T010.

**After (DAG Execute Mode with Explicit Dependencies)**:

```markdown
## Phase 2: Foundational
- [ ] T010 Create database schema in db/migrations/001-init.sql
  - **Success criteria**: Schema applied
  - **Dependencies**: (none)
  - **Owned Files**: db/migrations/001-init.sql

- [ ] T011 Setup API server in src/server.ts
  - **Success criteria**: Server starts
  - **Dependencies**: (none)
  - **Owned Files**: src/server.ts

## Phase 3: User Story 1
- [ ] T020 Implement UserService in src/services/user.ts
  - **Success criteria**: Tests pass
  - **Dependencies**: T010
  - **Owned Files**: src/services/user.ts, tests/services/user.test.ts

## Phase 4: User Story 2
- [ ] T030 Implement OrderService in src/services/order.ts
  - **Success criteria**: Tests pass
  - **Dependencies**: T010
  - **Owned Files**: src/services/order.ts, tests/services/order.test.ts
```

**DAG Waves**:
- Wave 1: T010, T011 (both roots)
- Wave 2: T020, T030 (both depend only on T010)

**Benefit**: T030 starts in Wave 2 alongside T020, not waiting for T020 to complete.

---

### Example 3: Agent Teams with File Ownership

**Before (Classic Mode + Agent Teams)**:

```markdown
## Phase 3: Backend Services

- [ ] T020 [P] Implement UserService
- [ ] T021 [P] Implement AuthService
- [ ] T022 [P] Implement NotificationService
```

**Problem**: Agent Teams may create file conflicts if tasks modify shared files (e.g., `Program.cs` for DI registration).

**After (DAG Execute Mode with File Ownership)**:

```markdown
## Phase 3: Backend Services

- [ ] T020 [P] Implement UserService in src/services/user.ts
  - **Success criteria**: Tests pass
  - **Dependencies**: T010
  - **Parallel Group**: backend-services
  - **Priority**: 10
  - **Owned Files**: src/services/user.ts, tests/services/user.test.ts, src/Program.cs

- [ ] T021 [P] Implement AuthService in src/services/auth.ts
  - **Success criteria**: Tests pass
  - **Dependencies**: T010
  - **Parallel Group**: backend-services
  - **Priority**: 5
  - **Owned Files**: src/services/auth.ts, tests/services/auth.test.ts

- [ ] T022 [P] Implement NotificationService in src/services/notification.ts
  - **Success criteria**: Tests pass
  - **Dependencies**: T010
  - **Parallel Group**: backend-services
  - **Priority**: 30
  - **Owned Files**: src/services/notification.ts, tests/services/notification.test.ts
```

**DAG Engine Detects**: T020 and T021 both modify `Program.cs` -- conflict!

**Resolution**: Execute T020 first (higher priority), then T021 and T022 in parallel.

**Benefit**: File conflicts detected and resolved automatically, preventing race conditions.

---

### Example 4: Priority-Based Scheduling

**Before (Classic Mode)**:

```markdown
## Phase 3: Implementation

- [ ] T020 Add documentation
- [ ] T021 Implement core algorithm
- [ ] T022 Add polish UI
```

**Problem**: All execute sequentially, even though T021 (core algorithm) should run first.

**After (DAG Execute Mode with Priority)**:

```markdown
## Phase 3: Implementation

- [ ] T020 Add documentation in docs/algorithm.md
  - **Success criteria**: Documentation complete
  - **Dependencies**: T021
  - **Priority**: 70
  - **Owned Files**: docs/algorithm.md

- [ ] T021 Implement core algorithm in src/core/algorithm.ts
  - **Success criteria**: Tests pass, performance meets target
  - **Dependencies**: (none)
  - **Priority**: 5
  - **Owned Files**: src/core/algorithm.ts, tests/core/algorithm.test.ts

- [ ] T022 Add polish UI in src/components/polish.tsx
  - **Success criteria**: UI renders correctly
  - **Dependencies**: T021
  - **Priority**: 60
  - **Owned Files**: src/components/polish.tsx
```

**DAG Waves**:
- Wave 1: T021 (highest priority, no dependencies)
- Wave 2: T020, T022 (both depend on T021; T022 executed before T020 due to priority)

**Benefit**: Critical path task (T021) executes first, polish and docs happen after.

---

## See Also

| Resource | Description |
|----------|-------------|
| [dag-feature-flags.md](./dag-feature-flags.md) | Complete flag reference and rollout plan |
| [dag-execution-guide.md](./dag-execution-guide.md) | Task format, dependencies, best practices |
| `.claude/lib/dag-engine.js` | Core graph algorithms (parse, validate, analyze) |
| `.claude/lib/dag-executor.js` | Wave execution, Agent Teams integration |
| `/dag-visualize` skill | Mermaid visualization of task graphs |
| `/dag-migrate` skill | Automatic dependency inference and annotation |
