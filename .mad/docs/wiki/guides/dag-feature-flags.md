# DAG Feature Flags

Feature flags for controlling DAG (Directed Acyclic Graph) execution behavior in the MAD workflow. DAG execution is **backward compatible** and **opt-in** — existing tasks.md files work unchanged without any DAG features enabled.

---

## Overview

The DAG feature flag system provides granular control over task dependency analysis and execution. Flags are set via environment variables in `.claude/settings.local.json` and control:

- **Execution mode**: How tasks are processed (classic, parse-only, validate, execute)
- **Visualization**: Whether Mermaid diagrams can be generated
- **Context budget management**: When to halt execution and create handoffs
- **Agent Teams integration**: Parallel wave execution coordination

All DAG features are designed to be incrementally adoptable. Start with `classic` mode (zero overhead), progress through validation modes to verify your task structure, then enable full execution when ready.

---

## Feature Flags Reference

| Flag | Type | Default | Valid Values | Purpose |
|------|------|---------|--------------|---------|
| `DAG_EXECUTION_MODE` | string | `classic` | `classic`, `dag-parse-only`, `dag-validate`, `dag-execute` | Controls how tasks are processed |
| `DAG_VISUALIZATION_ENABLED` | boolean | `false` | `true`, `false` | Enables `/dag-visualize` skill |
| `DAG_CONTEXT_THRESHOLD` | number | `0.85` | `0.50` - `1.0` | Context budget threshold for halting execution |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | string | (unset) | `1`, `true` | Required for parallel wave execution |

### Phase 3+ Flags (Planned)

These flags are reserved for future phases and currently have no effect:

| Flag | Phase | Purpose |
|------|-------|---------|
| `DAG_EVENT_BUS_ENABLED` | Phase 3 | Enable reactive triggers between tasks |
| `DAG_ASSET_TRACKING` | Phase 4 | Track asset lineage across tasks |
| `DAG_INCREMENTAL_MODE` | Phase 4 | Enable incremental execution (skip unchanged subgraphs) |

### How to Set Flags

Flags are set in `.claude/settings.local.json` under the `env` key:

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-validate",
    "DAG_VISUALIZATION_ENABLED": "true",
    "DAG_CONTEXT_THRESHOLD": "0.85",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Important**: These are environment variables read by Claude Code from the settings file. Do NOT set them as shell environment variables — Claude Code only reads from `settings.local.json`.

---

## Execution Modes

The `DAG_EXECUTION_MODE` flag is the primary control. It determines how `tasks.md` is interpreted and executed.

### `classic` (default)

Traditional phase-by-phase execution. No behavior changes. No overhead.

- Tasks execute sequentially within each phase
- No DAG parsing or dependency analysis
- All other `DAG_*` flags are **ignored** when this mode is active
- This is the safe baseline -- zero risk of regression

### `dag-parse-only`

Parse `tasks.md` into a DAG structure and validate the graph, but execute using classic phase-by-phase ordering.

- Adds DAG metadata (dependencies, file ownership) to task representations
- Validates that the dependency graph is well-formed
- Does **not** change execution order
- Useful for verifying that task annotations are correct before enabling DAG execution
- Minimal overhead: parsing happens once at plan load time

### `dag-validate`

Everything in `dag-parse-only`, plus emit warnings for structural issues.

- Detects cycles in the dependency graph
- Warns on file ownership conflicts (two tasks modifying the same file)
- Identifies suboptimal task ordering (tasks that could run earlier based on dependencies)
- Suggests parallelization opportunities
- Still executes using classic phase-by-phase ordering
- Recommended as the validation step before switching to `dag-execute`

### `dag-execute` (Phase 2)

**Behavior**: Full wave-based execution with file conflict enforcement.

**Use case**:
- Production DAG execution
- Parallel wave execution (with Agent Teams)
- Enforced file ownership (prevents conflicts)
- Context budget management (halts on threshold)

**What it does**:
1. All validation from `dag-validate`
2. **Execute tasks wave-by-wave** (respects dependencies)
3. Enforce file ownership (conflict = error)
4. Parallel execution within waves (if Agent Teams enabled)
5. Context budget checks after each wave
6. Halt and create handoff if context threshold exceeded

**Requirements**:
- Tasks must have valid DAG structure (no cycles)
- File ownership must be unambiguous (no conflicts in same wave)
- For parallel execution: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and `.claude/agent-teams-config.json` enabled

**Phase 2 Status**: `dag-execute` is **implemented** in `dag-executor.js`. Wave-based execution is available. Agent Teams integration is a stub (falls back to sequential execution) pending Agent Teams API maturity.

---

## Context Threshold Flag

### `DAG_CONTEXT_THRESHOLD`

**Type**: Number (0.50 - 1.0)

**Default**: `0.85`

**Purpose**: Controls when `dag-execute` halts due to context budget exhaustion.

**Behavior**:
- After each wave completes, context usage is estimated
- If usage > threshold, execution halts
- A `ContextBudgetExceededError` is thrown with handoff details
- Orchestrator should generate handoff document and stop work

**Threshold levels**:
- `0.50` - Conservative (halts at 50% context)
- `0.70` - Moderate (halts at 70% context)
- `0.85` - Default (halts at 85% context)
- `0.95` - Aggressive (halts at 95% context, risky)
- `1.0` - Disabled (no context checks, **not recommended**)

**When to adjust**:
- Lower threshold (e.g., `0.70`): You want early handoffs, prefer shorter sessions
- Higher threshold (e.g., `0.95`): You want to maximize work per session, accept risk of surprise compaction

**Context estimation**:
- Uses `context-metrics.js` if available (sliding window token tracking)
- Falls back to conservative heuristic (30% estimated usage)
- ~30% error margin — treat as directional signal, not precise

**Integration with Context Guardian**:
- Context Guardian hook uses independent thresholds (ADVISORY 50%, PREPARE 70%, HALT 85%)
- DAG threshold is checked **after each wave** during `dag-execute`
- Both systems work together to prevent context exhaustion

---

## Agent Teams Integration

### `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

**Type**: String (`"1"` or `"true"`)

**Default**: (unset)

**Purpose**: Required for parallel wave execution via Agent Teams.

**Behavior**:
- Checked by `dag-executor.js` before attempting parallel execution
- Must be set to `"1"` or `"true"`
- Also requires `.claude/agent-teams-config.json` to have `phases.implement-parallel = "teams"`
- If either check fails, falls back to sequential wave execution

**When to enable**:
- You want parallel task execution within waves
- Tasks in a wave have **disjoint file ownership** (no conflicts)
- Agent Teams API is stable and available
- You accept increased token cost (N teammates ~ N+1x tokens)

**Current status**:
- Phase 1: Sequential execution only (Agent Teams integration is a stub)
- Phase 2 (in progress): Full parallel execution with teammate spawning

**See**: `.claude/rules/agent-teams.md` for complete Agent Teams integration details.

---

## Configuration Examples

### Example: Minimal DAG Setup (Phase 1)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-parse-only",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

### Example: Full Validation (Phase 1)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-validate",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

### Example: Wave-Based Execution (Phase 2)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-execute",
    "DAG_CONTEXT_THRESHOLD": "0.85",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

### Example: Parallel Execution with Agent Teams (Phase 2 Future)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-execute",
    "DAG_CONTEXT_THRESHOLD": "0.85",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

---

## Phase Rollout Plan

### Phase 1: Foundation Layer (COMPLETED)

**Capabilities**:
- `classic`, `dag-parse-only`, `dag-validate` modes
- `/dag-visualize` skill
- Cycle detection, wave computation, critical path
- File ownership analysis (warning-only)

**Recommended flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-validate",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

**Goal**: Validate task structure, identify issues, visualize dependencies without changing execution behavior.

---

### Phase 2: Smart Parallelization (IN PROGRESS)

**Capabilities**:
- `dag-execute` mode (wave-based execution)
- Context budget management
- Agent Teams integration (stub currently)
- File conflict enforcement

**Recommended flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-execute",
    "DAG_CONTEXT_THRESHOLD": "0.85",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

**Goal**: Sequential wave execution with context management. Parallel execution when Agent Teams API matures.

---

### Phase 3: Event-Driven (PLANNED)

**Capabilities**:
- Reactive triggers (task starts when condition met)
- Conditional branches (if-then-else task flow)
- Saga pattern (compensating transactions for rollback)
- Dynamic wave recomputation

**New flags** (planned):
- `DAG_REACTIVE_ENABLED` - Enable reactive triggers
- `DAG_SAGA_ENABLED` - Enable compensation logic

**Goal**: Complex workflows with conditional execution and error recovery.

---

### Phase 4: Asset-Oriented (PLANNED)

**Capabilities**:
- Incremental execution (skip tasks if inputs unchanged)
- Staleness detection (recompute only stale assets)
- Lineage tracking (what outputs depend on what inputs)
- Cache invalidation (smart rebuild)

**New flags** (planned):
- `DAG_INCREMENTAL_ENABLED` - Enable incremental execution
- `DAG_CACHE_DIR` - Cache directory for artifact tracking

**Goal**: Build-system-like efficiency for large task graphs.

---

## Recommended Adoption Path

1. **Start with validation** (`dag-parse-only` or `dag-validate`) to verify your tasks.md annotations
2. **Enable visualization** (`DAG_VISUALIZATION_ENABLED: "true"`) for debugging and team communication
3. **Progress to execution** (`dag-execute`) only after `dag-validate` reports no warnings
4. **Tune context threshold** based on your workflow (start with default `0.85`)
5. **Enable Agent Teams** when API is stable and tasks have disjoint file ownership

---

## Rollback

To completely disable DAG features and revert to classic behavior:

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "classic"
  }
}
```

All other `DAG_*` flags are ignored when `DAG_EXECUTION_MODE` is set to `classic`. You do not need to remove them from the configuration -- they simply have no effect.

For a clean configuration, remove all `DAG_*` entries:

```json
{
  "env": {}
}
```

---

## Examples and Use Cases

### Use Case 1: Verify Task Structure (Phase 1)

**Scenario**: You have a tasks.md with dependency annotations. You want to verify it's valid before enabling execution.

**Flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-parse-only",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

**Steps**:
1. Run `/dag-visualize` to see your task graph
2. Check for cycles (will error if found)
3. Review wave count and critical path
4. If valid, proceed to `dag-validate`

---

### Use Case 2: Find File Conflicts (Phase 1)

**Scenario**: You want to find tasks that modify the same files before execution.

**Flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-validate",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

**Steps**:
1. Run `/mad-implement` with these flags
2. Review conflict warnings in output
3. Adjust task dependencies or file ownership annotations
4. Re-run until no conflicts remain
5. Proceed to `dag-execute`

---

### Use Case 3: Wave-Based Execution (Phase 2)

**Scenario**: You want tasks to execute in dependency order, with context management.

**Flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-execute",
    "DAG_CONTEXT_THRESHOLD": "0.85",
    "DAG_VISUALIZATION_ENABLED": "true"
  }
}
```

**Steps**:
1. Ensure `dag-validate` passes with no conflicts
2. Enable `dag-execute`
3. Run `/mad-implement`
4. Tasks execute wave-by-wave
5. Context checked after each wave
6. Halts automatically if threshold exceeded

---

### Use Case 4: Conservative Context Management

**Scenario**: You want early handoffs to avoid context exhaustion.

**Flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-execute",
    "DAG_CONTEXT_THRESHOLD": "0.70"
  }
}
```

**Behavior**:
- Execution halts when context reaches 70%
- Handoff document created earlier in session
- Smaller work units per session
- Lower risk of surprise compaction

---

### Use Case 5: Disable DAG Features

**Scenario**: You want to revert to traditional execution temporarily.

**Flags**:
```json
{
  "env": {
    "DAG_EXECUTION_MODE": "classic"
  }
}
```

**Behavior**:
- All DAG features disabled
- Zero overhead (DAG library not loaded)
- Tasks execute in document order
- Existing workflows unchanged

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Setting flags as shell env vars | Claude Code doesn't read shell env — flags ignored | Always set in `.claude/settings.local.json` under `env` key |
| Jumping to `dag-execute` without validation | Undetected cycles or conflicts cause execution failures | Progress through `dag-parse-only` → `dag-validate` → `dag-execute` |
| Setting threshold to `1.0` | Removes safety net, risks losing work on compaction | Use `0.85` default, or `0.95` maximum |
| Enabling Agent Teams without disjoint files | File conflicts cause execution errors | Run `dag-validate` first, resolve conflicts before parallel execution |
| Using `dag-execute` with cycles | Execution fails immediately with cycle error | Fix cycles first, validate with `dag-parse-only` |
| Disabling visualization in Phase 1 | Loses valuable debugging tool | Keep `DAG_VISUALIZATION_ENABLED: "true"` during Phase 1 validation |
| Treating context threshold as precise | ~30% error margin, can false-positive | Adjust threshold if frequent early halts |

---

## Troubleshooting

### Flag Not Taking Effect

**Symptom**: DAG features don't work even after setting flags.

**Causes**:
1. Flags set as shell env vars instead of in `settings.local.json`
2. JSON syntax error in `settings.local.json`
3. Flag name typo (case-sensitive)
4. String value not quoted (should be `"true"`, not `true`)

**Solution**:
- Check `.claude/settings.local.json` syntax
- Verify `env` key exists
- Restart Claude Code if needed

---

### Cycle Detected Error

**Symptom**: `dag-parse-only` or `dag-validate` fails with cycle error.

**Cause**: Circular dependencies in tasks (e.g., T010 → T020 → T030 → T010).

**Solution**:
1. Use `/dag-visualize` to see the cycle path
2. Remove or reorder dependencies to break the cycle
3. Re-run validation

---

### File Conflict Warnings

**Symptom**: `dag-validate` shows file conflict warnings.

**Cause**: Multiple tasks in the same wave modify the same file.

**Solutions**:
1. Add explicit dependencies to serialize conflicting tasks
2. Split file ownership (different tasks modify different files)
3. Defer one task to a later wave

---

### Context Budget Exceeded

**Symptom**: `dag-execute` halts with `ContextBudgetExceededError`.

**Cause**: Context usage exceeded threshold during wave execution.

**Solution**:
- This is expected behavior, not an error
- Review handoff document created by orchestrator
- Start new session and resume from handoff
- Alternatively, raise threshold (e.g., `0.95`) if appropriate

---

### Agent Teams Not Activating

**Symptom**: Tasks execute sequentially even with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`.

**Causes**:
1. `.claude/agent-teams-config.json` missing or `enabled: false`
2. `phases.implement-parallel` not set to `"teams"`
3. Agent Teams API unavailable (falls back to sequential)

**Solution**:
- Verify agent-teams-config.json settings
- Check Agent Teams API status
- Review `.claude/rules/agent-teams.md` for requirements

---

## References

| Resource | Description |
|----------|-------------|
| [DAG Execution Guide](./.claude/docs/dag-execution-guide.md) | Task format, migration patterns, best practices |
| [DAG Engine Library](./.claude/lib/dag-engine.js) | Core graph algorithms (parse, validate, analyze) |
| [DAG Executor Library](./.claude/lib/dag-executor.js) | Wave-based execution, context management, Agent Teams integration |
| [Agent Teams Guide](./.claude/rules/agent-teams.md) | Agent Teams integration for parallel execution |
| [Context Guardian](./.claude/rules/context-guardian.md) | Context budget management rules and thresholds |
| `/dag-visualize` Skill | Mermaid diagram generation skill |
| `CLAUDE.md` DAG Section | High-level overview and quick reference |
