# Coverage Oracle — tasks.md

What a *complete* `specs/<N>-<feature>/tasks.md` must cover. Loaded for `tasks-change`.

## Required sections

| # | Section | What it covers |
|---|---------|----------------|
| 1 | **Conventions block** | `[ ]` pending, `[x]` done, `[!]` blocked, `[P]` parallel-eligible |
| 2 | **Phase grouping** | Tasks grouped by phase from plan.md |
| 3 | **Per-task atomicity** | Each task names: target file scope + acceptance criterion + estimated subagent type |
| 4 | **Dependency markers** | `[P]` parallel-eligible only when files disjoint; sequential by default |
| 5 | **Acceptance gate per phase** | Test selector or behavioral probe that gates phase completion |
| 6 | **Blockers section** | `[!]` items lifted to top with cause + remediation owner |

## Severity per missing element

| Element | Missing severity |
|---------|------------------|
| 1 Conventions block | MUST-FIX (consumers won't know status) |
| 2 Phase grouping | **BLOCKING** (no phase = no parallelization safe) |
| 3 Per-task atomicity | **BLOCKING** (vague tasks fail TDD) |
| 4 Dependency markers | MUST-FIX |
| 5 Acceptance gate per phase | **BLOCKING** |
| 6 Blockers section | SHOULD-FIX (or "no blockers" stated) |

## Special checks

- **Atomicity**: a task is atomic if it can be done by one subagent in one round with one acceptance criterion. Tasks containing "and also" or "then" → MUST-FIX (split required)
- **File-ownership conflict**: two `[P]` tasks claiming overlap on same file → BLOCKING
- **Acceptance traceability**: every task's acceptance criterion maps back to a plan.md Verification Spec entry → SHOULD-FIX if missing the link

## Anti-hallucination

- "Task lacks atomicity" cites the task line + the conjunction triggering the split
- "File-ownership conflict" cites both `[P]` tasks + the shared file path

## Cross-references

- `mad-tasks/templates/tasks.md` — canonical shape
- `mad-plan/templates/plan.md` — upstream input
