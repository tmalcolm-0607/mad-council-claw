# Orchestration

**Rule**: Main coordinates. Agents work. Reading code files is **BLOCKED** in the main orchestrator.

Enforced by `hooks/enforce-orchestration.js`.

## Agent dispatch table

| When you need to... | Spawn this agent | subagent_type |
|---------------------|-----------------|---------------|
| Understand code | `code-investigator` or `Explore` | `code-investigator` |
| Modify code | `code-implementer` | `code-implementer` |
| Research decisions | `research-scout` → `curator` → `reviewer` | `research-scout` |
| Review code | `code-reviewer` | `code-reviewer` |
| **Full investigate→implement→verify loop** | **`investigate-and-implement`** | `general-purpose` |
| **Review + auto-fix cycle** | **`review-and-fix`** | `general-purpose` |
| **Close coverage gaps** | **`coverage-loop`** | `general-purpose` |

**Composite agents** (bold) run subagent loops internally, returning a compact summary.

## After an agent completes

1. Update plan checkbox in `specs/<N>-<feature>/plan.md`.
2. Verify agent claims yourself — only report outcomes you have evidence for.
3. Commit if phase done.

## Work Accountability

Persist progress to `plan.md` after each completed task. Before reporting results, verify agent claims yourself — only report outcomes you have evidence for.

## Task Decomposition

For multi-step work, create `TaskCreate` entries before starting. Each task maps to one subagent invocation.

## Script-First Execution

When a task requires complex shell commands, write a script to `scratch/` and execute it — do not run complex commands inline.

## Subagent Output Routing

All agent analysis >10 lines must be written to `work-items/<WI-ID>/` — never kept only in transcript. This protects against context compaction.

## Code Review Preferences

Post individual inline comments (not monolithic). Categorize by severity (critical, major, nit) but use natural prose — no bracket labels or template structure. Human conversational tone. Default to approve-with-suggestions unless blocking issues found.
