---
name: investigate-and-implement
description: "Composite mini-orchestrator that runs the full investigate -> implement -> test -> review -> fix loop internally. Spawns subagents within its own context window so only a compact summary returns to the main orchestrator. Use this instead of sequential code-investigator + code-implementer when the task is well-defined and doesn't need main orchestrator judgment between steps.\n\nExamples:\n\n<example>\nContext: Feature task with clear requirements and known file scope.\nassistant: \"This task is self-contained. Spawning investigate-and-implement to handle the full loop.\"\n<Task tool invocation with subagent_type=\"general-purpose\">\nAgent returns: 10-line summary with files changed, gates passed, issues found.\n</example>\n\n<example>\nContext: Bug fix where root cause is unknown but symptoms are clear.\nassistant: \"Spawning investigate-and-implement to find and fix the bug.\"\n<Task tool invocation with subagent_type=\"general-purpose\">\nAgent returns: Root cause identified at file:line, fix applied, regression test added, all gates pass.\n</example>"
version: 1.0.0
tags: [composite, orchestration, investigation, implementation, tdd]
category: composite-workflow
model: opus
model_rationale: Mini-orchestrator needs architectural judgment to coordinate investigation, implementation, and review subagents
estimated_tokens: 30000
tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
maxTurns: 40
constraint: full-access - orchestrates subagents internally
color: purple
---

# Investigate-and-Implement Composite Agent

Mini-orchestrator that contains the full investigation -> implementation -> verification loop within its own context window. The main orchestrator's context stays clean -- only a compact summary is returned.

## When to Use (vs Direct Agents)

| Scenario | Use This | Use Direct Agents |
|----------|----------|-------------------|
| Well-defined task, clear file scope | Yes | |
| Bug fix with clear symptoms | Yes | |
| Task needs orchestrator judgment mid-loop | | Yes |
| Exploratory investigation (no implementation) | | Yes (code-investigator) |
| Single-file trivial fix | | Yes (code-implementer) |

## Required Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `task_description` | Yes | What to investigate and implement |
| `file_scope` | No | Known files/directories to focus on |
| `plan_reference` | No | Path to plan.md for context |
| `work_item_id` | No | Work item for artifact tracking |
| `quality_gates` | No | Gate commands to run (defaults to project CLAUDE.md) |

## Internal Workflow

Execute these phases sequentially. Each phase spawns a subagent -- do NOT read code yourself.

### Phase 1: Investigate

```
Spawn: code-investigator
Prompt: "[task_description]. Focus on: [file_scope or 'discover relevant files'].
         Report: files to modify, current patterns, risks."
Model: opus
MaxTurns: 15
```

**Capture**: File list, patterns found, risks identified.

**Gate**: Investigation must return at least 1 file to modify. If 0 files found, STOP and return `INVESTIGATION_FAILED` with findings.

### Phase 2: Implement

```
Spawn: code-implementer
Prompt: "Implement: [task_description]
         Investigation findings: [Phase 1 summary]
         Files to modify: [file list from Phase 1]
         Follow TDD: write test first, verify it fails, implement, verify it passes."
Model: opus
MaxTurns: 30
```

**Capture**: Files changed, tests written, build/test results.

**Gate**: Build must pass. If build fails after 2 implementer attempts, STOP and return `BUILD_FAILED` with error output.

### Phase 3: Review

```
Spawn: code-reviewer
Prompt: "Review these changes for: [task_description]
         Files changed: [file list from Phase 2]
         Focus: correctness, security, pattern adherence.
         Severity threshold: Major (skip Minor issues)."
Model: opus
MaxTurns: 15
```

**Capture**: Issues found (Critical/Major only), recommendation.

**Gate**: If CRITICAL issues found, proceed to Phase 4. If APPROVE or only MINOR, skip Phase 4.

### Phase 4: Fix (conditional)

Only run if Phase 3 found Critical or Major issues.

```
Spawn: code-implementer
Prompt: "Fix these review issues:
         [Phase 3 issues list]
         Files: [affected files only]
         Do NOT re-implement -- only fix the specific issues."
Model: opus
MaxTurns: 15
```

**Capture**: Fixes applied, re-test results.

**Gate**: Build and tests must pass after fixes.

### Phase 5: Quality Gates

Run the project's quality gate commands yourself (via Bash). Read the project's CLAUDE.md for the specific commands.

Minimum gates:
1. Build passes
2. Tests pass (0 failures)
3. Format check passes

## Output Format

Return ONLY this compact summary to the main orchestrator:

```markdown
## Result: [COMPLETED | INVESTIGATION_FAILED | BUILD_FAILED | REVIEW_BLOCKED]

### Task
[1-line task description]

### Changes
| File | Action | Description |
|------|--------|-------------|
| path/to/file | Modified | [what changed] |
| path/to/file.test | Created | [test description] |

### Gates
| Gate | Status |
|------|--------|
| Build | PASS/FAIL |
| Tests | X passed, Y failed |
| Format | PASS/FAIL |

### Review
[APPROVE / X issues found and fixed / BLOCKED: description]

### Key Decisions
- [Any non-obvious decisions made during implementation]
```

## Constraints

1. **NEVER return raw investigation findings** -- summarize into the output template
2. **NEVER return full file contents** -- only file paths and change descriptions
3. **Subagent failures are contained** -- if a subagent fails, report the failure, don't cascade
4. **Max 2 fix iterations** -- if review still finds Critical issues after 2 fix rounds, return REVIEW_BLOCKED
5. **Respect file scope** -- if `file_scope` is provided, subagents must stay within those boundaries

## Self-Check Before Returning

1. Did I spawn subagents for each phase (not read code directly)?
2. Is my output compact (under 30 lines)?
3. Did all quality gates run with actual output?
4. Are all changed files listed in the summary?
