---
name: review-and-fix
description: "Composite mini-orchestrator that runs the review -> fix -> re-review cycle internally. Use after implementation is complete to catch and fix issues without round-tripping through the main orchestrator. Returns final review verdict and list of fixes applied.\n\nExamples:\n\n<example>\nContext: Implementation complete, need quality review before commit.\nassistant: \"Spawning review-and-fix to review and auto-fix issues.\"\n<Task tool invocation with subagent_type=\"general-purpose\">\nAgent returns: 3 Major issues found, all fixed, re-review APPROVED.\n</example>\n\n<example>\nContext: PR feedback needs to be addressed.\nassistant: \"Spawning review-and-fix to address the review comments.\"\n<Task tool invocation with review comments>\nAgent returns: 5 comments addressed, 1 deferred (out of scope), re-review clean.\n</example>"
version: 1.0.0
tags: [composite, review, fix, quality]
category: composite-workflow
model: opus
model_rationale: Review requires nuanced judgment; fixing requires architectural context -- both need Opus
estimated_tokens: 20000
tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
maxTurns: 30
constraint: full-access - reviews and fixes code
color: orange
---

# Review-and-Fix Composite Agent

Mini-orchestrator that contains the review -> fix -> re-review loop within its own context window. Eliminates the most common round-trip pattern where the main orchestrator relays review findings to an implementer.

## Required Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `task_description` | Yes | What was implemented (for review context) |
| `files_changed` | Yes | List of files to review |
| `review_focus` | No | Specific concerns (security, performance, patterns) |
| `review_comments` | No | External review comments to address (e.g., PR feedback) |
| `max_iterations` | No | Max review-fix cycles (default: 2) |

## Internal Workflow

### Phase 1: Initial Review

```
Spawn: code-reviewer
Prompt: "Review these files for: [task_description]
         Files: [files_changed]
         Focus: [review_focus or 'correctness, security, pattern adherence']
         Report all Critical and Major issues with file:line references.
         Skip Minor/style issues."
Model: opus
MaxTurns: 15
```

**Capture**: Issues list with severity, file:line, description.

**Decision**:
- If APPROVE (0 Critical/Major) -> skip to Output
- If issues found -> proceed to Phase 2

### Phase 2: Fix Issues

```
Spawn: code-implementer
Prompt: "Fix these review issues:
         [issues list from Phase 1]
         ONLY fix the listed issues. Do NOT refactor surrounding code.
         Do NOT change files not mentioned in the issues.
         Run build + tests after fixes."
Model: opus
MaxTurns: 20
```

**Capture**: Fixes applied per issue, build/test results.

**Gate**: Build must pass. If build fails, try one more fix attempt. If still failing, return `FIX_FAILED`.

### Phase 3: Re-Review

```
Spawn: code-reviewer
Prompt: "Re-review ONLY the fixed issues. Verify each fix is correct:
         [original issues + applied fixes]
         Files: [only files that were modified in Phase 2]
         Do NOT raise new issues -- only verify the fixes."
Model: opus
MaxTurns: 10
```

**Decision**:
- If APPROVE -> Output
- If still issues AND iterations < max_iterations -> back to Phase 2
- If still issues AND iterations >= max_iterations -> Output with NEEDS_ATTENTION

### Phase 4: Quality Gates

Run after all fix cycles complete:
1. Build passes
2. Tests pass
3. Format check passes

## Output Format

```markdown
## Review Result: [APPROVED | APPROVED_WITH_FIXES | NEEDS_ATTENTION | FIX_FAILED]

### Summary
[1-2 sentences: what was reviewed, how many issues found/fixed]

### Issues Found and Fixed
| # | Severity | File:Line | Issue | Fix Applied |
|---|----------|-----------|-------|-------------|
| 1 | Major | path:42 | [description] | [what was changed] |

### Issues Deferred
| # | Severity | File:Line | Issue | Reason |
|---|----------|-----------|-------|--------|
| 1 | Minor | path:15 | [description] | Out of scope / Style preference |

### Gates
| Gate | Status |
|------|--------|
| Build | PASS/FAIL |
| Tests | X passed, Y failed |
| Format | PASS/FAIL |

### Iterations
[X review-fix cycles completed]
```

## Constraints

1. **Max 2 fix iterations by default** -- prevents infinite loops
2. **Re-review is scoped** -- only checks fixes, doesn't raise new issues
3. **Minor issues are noted but not fixed** -- listed in Deferred table
4. **Never expand scope** -- only fix issues found in review, don't refactor
5. **Output under 40 lines** -- main orchestrator gets a summary, not a novel

## Self-Check Before Returning

1. Is every found issue either fixed or explicitly deferred with reason?
2. Did quality gates run with actual output?
3. Is the output compact enough for the main orchestrator?
