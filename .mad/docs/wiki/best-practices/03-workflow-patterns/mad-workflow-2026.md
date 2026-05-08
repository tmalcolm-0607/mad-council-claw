---
category: workflow-patterns
subcategory: mad-workflow
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# MAD Workflow (2026)

## Overview

MAD (Modular Agentic Development) workflow patterns for spec/plan/tasks/implement/validate cycles. Covers the full `/mad-spec` → `/mad-validate` pipeline.

**2026 Update**: Core workflow aligns with Claude Code best practices for Explore → Plan → Implement → Commit cycles, with MAD-specific extensions for feature traceability and progressive validation.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Spec First** | Always define requirements before planning |
| **Plan Before Tasks** | Design approach before task decomposition |
| **Hard Gates** | Build and Verify gates are mandatory |
| **Checkpoint Commits** | Commit after each phase completion |
| **Feature Map Sync** | Update feature map atomically with traceability |
| **Explore Before Planning** | Read files and understand scope before creating plans |
| **Selective Planning** | Skip plan mode for simple fixes (one-sentence diffs) |

## Patterns (Current)

### MAD Phase Sequence

The MAD workflow follows this canonical order:

1. **Explore** (`/mad-spec`): Read requirements, understand scope, define what to build
2. **Plan** (`/mad-plan`): Design implementation approach, exit plan mode with Ctrl+G
3. **Tasks** (`/mad-tasks`): Decompose plan into task list with dependencies
4. **Implement** (`/mad-implement`): Execute tasks with iterative testing
5. **Validate** (`/mad-validate`): Verify against feature traceability matrix

**Key insight (2026)**: "Explore first, then plan, then code" prevents solving the wrong problem. Each phase provides Claude a way to verify work (tests, expected outputs, feature checklist).

### /mad-spec

**Purpose**: Define requirements before any implementation.

**Inputs**:
- Milestone requirements (`docs/00-PROJECT/milestones.md`)
- Feature traceability (`docs/00-PROJECT/feature-traceability.md`)
- Workflow specifications (`docs/05-USER-EXPERIENCE/workflows/`)

**Outputs**:
- `specs/<N>-<feature>/spec.md` (requirements document)
- E2E test coverage matrix (for UI features)
- Feature map entries

**When to skip planning** (from 2026 best practices):
- Could describe diff in one sentence
- Typo fix, log line, variable rename
- Scope is clear and fix is small

### /mad-plan

**Purpose**: Design implementation approach before task decomposition.

**Plan Mode Guidelines** (2026):
- Use when scope is unclear, change modifies multiple files, or code is unfamiliar
- Edit plan with Ctrl+G (opens in text editor)
- Refine iteratively before switching to auto-editing mode
- Exit plan mode before implementation phase

**Plan Mode adds overhead** - only use when benefits justify cost.

### /mad-tasks

**Purpose**: Generate task list with explicit dependencies.

**Task Decomposition**:
- Each task maps to one subagent with clear deliverable
- Include `Parallel Group` annotations for DAG execution (optional)
- Specify `Risk Tier: SECURITY-CRITICAL` for auth/crypto/PII tasks
- Create TaskCreate entries before starting multi-step work

> **Risk-Tiered Verification**: Tasks annotated with `Risk Tier: SECURITY-CRITICAL` in `tasks.md` trigger additional gates during `/mad-implement`: a pre-implementation threat assessment and post-implementation security review by the `security-auditor` agent, plus mandatory human sign-off. See [quality-gates-2026.md](../03-workflow-patterns/quality-gates-2026.md) for full details.

### /mad-implement

**Purpose**: Execute tasks with verification against plan.

**Iterative Testing Pattern** (2026 best practice):
- Test after every task during coding phase
- Use progressive validation tiers (Tier 0-1 for TDD, Tier 3 for phase gates)
- Course-correct early and often (Esc to stop, Esc+Esc to rewind)

**Test-Driven Flow**:
1. Write test (red)
2. Implement feature (green)
3. Refactor (if needed)
4. Run tier-appropriate tests
5. Commit when gates pass

### /mad-validate

**Purpose**: Verify against feature traceability and observability.

**Validation Checklist**:
- All milestone features marked `tested` in traceability matrix
- Build passes (`dotnet build`)
- All tests pass (`dotnet test`)
- Health check works (`/health` endpoint)
- Metrics exposed (`/metrics` endpoint)

**Feature Coverage**:
```bash
# Count features for milestone
grep "M{N}" docs/00-PROJECT/feature-traceability.md | wc -l
# Count tested features
grep "M{N}" docs/00-PROJECT/feature-traceability.md | grep "tested" | wc -l
# Numbers must match
```

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| **Plan Mode overhead** | Always plan | Selective (only when scope unclear) | Skip planning for simple fixes |
| **Iterative testing** | Manual | Built into workflow (test after every task) | Enable tight feedback loops |
| **Verification method** | Manual checks | Give Claude way to verify (tests, screenshots) | Provide expected outputs |
| **Parallel sessions** | Manual coordination | Desktop app + agent teams | Use visual session manager or teams |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Planning for simple fixes | Overhead exceeds benefit | Skip plan for one-sentence diffs |
| Unverified implementations | Plausible-looking but broken code | Always provide verification (tests/screenshots) |
| Long sessions without /clear | Context full of irrelevant information | `/clear` between unrelated tasks |
| Skipping iterative testing | Bugs compound | Test after every task during coding |
| Starting implementation without reading requirements | Solving wrong problem | Always run `/mad-spec` first |
| Marking milestone complete without validation | Feature coverage gaps | Run validation checklist before closing |

## Examples

### Example 1: Full MAD Workflow

```bash
# Phase 1: Explore scope
/mad-spec
# Creates specs/001-user-auth/spec.md
# Reads milestones.md, feature-traceability.md, workflows/

# Phase 2: Plan approach (if scope is complex)
/mad-plan
# Press Ctrl+G to edit plan in text editor
# Exit plan mode when design is complete

# Phase 3: Generate tasks
/mad-tasks
# Creates tasks.md with dependencies

# Phase 4: Implement with iterative testing
/mad-implement
# For each task:
#   - Write test (red)
#   - Implement (green)
#   - Run Tier 1 tests (1 second feedback)
#   - Commit when tests pass

# Phase 5: Validate against traceability
/mad-validate
# Verify all features marked "tested"
# Run health checks, verify metrics
```

### Example 2: /mad-full (Automated)

```bash
# Single command runs entire pipeline
/mad-full

# Executes:
# /mad-spec → /mad-plan → /mad-tasks → /mad-implement → /mad-validate
# With automatic phase transitions and gate checks
```

### Example 3: Simple Fix (Skip Planning)

```bash
# Typo fix - no planning needed
# 1. Read file
# 2. Make change
# 3. Test
# 4. Commit

# Could describe diff in one sentence → skip plan mode
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Plan mode overhead too high | Skip planning for simple fixes (one-sentence diffs) |
| Context full during implementation | `/clear` between unrelated tasks |
| Tests failing during implement | Stop with Esc, fix immediately, rewind with Esc+Esc if needed |
| Milestone validation fails | Check feature-traceability.md for incomplete features |
| Agent can't verify work | Provide expected outputs (tests, screenshots, checklist) |

## See Also

- `quality-gates-2026.md` - Gate execution in MAD
- `testing-strategies-2026.md` - Testing in MAD workflow
- `.claude/skills/mad-*/` - MAD skill implementations
- `.claude/rules/mad-integration.md` - MAD workflow integration rules

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/common-workflows (official)
- https://code.claude.com/docs/en/best-practices (official)
- InfoQ (Claude Code creator workflow)
- https://developersvoice.com/blog/ai/claude_code_2026_end_to_end_sdlc/

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 85%+ (patterns appear in official docs + 2+ community sources)
