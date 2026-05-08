# Workflow Best Practices

This document contains detailed explanations, examples, and troubleshooting guidance for the Claude Code workflow. For quick reference, see the rule files in `.claude/rules/`.

---

## Table of Contents

1. [Orchestration Principles](#orchestration-principles)
2. [Agent Spawning Guide](#agent-spawning-guide)
3. [Research Pipeline Deep Dive](#research-pipeline-deep-dive)
4. [Trust-But-Verify Protocol](#trust-but-verify-protocol)
5. [Plan Management Best Practices](#plan-management-best-practices)
6. [Session Hygiene](#session-hygiene)
7. [Troubleshooting](#troubleshooting)

---

## Orchestration Principles

### Why Orchestration Matters

The main conversation has limited context window capacity. By delegating detailed work to sub-agents, you:

1. **Preserve context** - Orchestrator stays focused on coordination
2. **Isolate failures** - Agent failures don't pollute main context
3. **Enable verification** - Independent verification of agent claims
4. **Improve resumability** - Work artifacts persist across sessions

### The Orchestrator Role

The orchestrator should ONLY do:
- Workflow decisions (which phase, what next)
- Git operations (commits, branches)
- Synthesizing agent outputs
- Running verification commands
- Simple user responses

The orchestrator should NEVER do:
- Read multiple code files directly
- Implement features
- Write documentation
- Conduct investigations

### Why This Failed Before

On 2026-01-20, features were merged with broken builds because:
1. Agent reported "Build Status: SUCCESS"
2. Orchestrator trusted the claim without verification
3. The build had never actually compiled

This led to the trust-but-verify principle being mandatory.

---

## Agent Spawning Guide

### Complete Spawning Template

When spawning any agent, include all of these elements:

```markdown
You are the [agent-name] agent.

Read your full instructions from: .claude/agents/[agent-name].md

**Task**: [Specific, actionable task description]

**Context**:
- Working directory: [absolute path]
- Plan file: [path to plan.md]
- Current phase: [which orchestration phase]
- Previous findings: [summary from prior agents if relevant]

**Output Requirements**:
- Write results to: [artifact path]
- Update plan.md checkboxes as you complete tasks
- Include file:line references for all code findings
- Fill Results section with specific details

**Success Criteria**:
[Explicit conditions that define completion]

**Constraints**:
[Any limitations - e.g., "NEVER modify files" for investigator]
```

### Agent-Specific Examples

#### code-investigator

```markdown
You are the code-investigator agent.

Read your full instructions from: .claude/agents/code-investigator.md

**Task**: Investigate validation patterns in the API layer

**Context**:
- Working directory: C:/source/my-project
- Plan file: specs/003-validation/plan.md
- Current phase: Phase 4 - Investigate

**Output Requirements**:
- Write results to: .claude/work-items/WI-001/artifacts/investigation/validation-patterns.md
- Document all validation locations with file:line
- Identify endpoints missing validation
- Note existing patterns to follow

**Success Criteria**:
- All API endpoints catalogued
- Validation presence/absence documented
- Recommended approach identified

**Constraints**:
- NEVER modify any files
- Read-only investigation
```

#### code-implementer

```markdown
You are the code-implementer agent.

Read your full instructions from: .claude/agents/code-implementer.md

**Task**: Add input validation to POST /users endpoint

**Context**:
- Working directory: C:/source/my-project
- Plan file: specs/003-validation/plan.md
- Current phase: Phase 5 - Implement
- Investigation findings: See artifacts/investigation/validation-patterns.md

**Output Requirements**:
- Write implementation report to: .claude/work-items/WI-001/artifacts/implementation/validation-impl.md
- Follow TDD: test first, then implement
- Run gates after implementation

**Success Criteria**:
- Test exists and initially fails
- Implementation makes test pass
- Build succeeds with 0 errors
- All existing tests still pass

**Constraints**:
- Follow existing validation patterns from investigation
- Use Zod schemas consistent with codebase
```

---

## Research Pipeline Deep Dive

### When to Use the Full Pipeline

Use the 3-tier research pipeline for:
- Architectural decisions with trade-offs
- Best practices research
- "How do others solve X?" questions
- Technology selection

Do NOT use for:
- Quick factual lookups
- Code investigation (use code-investigator)
- Simple questions with obvious answers

### Pipeline Stages Explained

#### Stage 1: research-scout (Sonnet)

**Purpose**: Cast a wide net, find sources, extract raw claims

**What it does**:
- Searches 15-30 sources
- Extracts 10-25 claims without evaluation
- Documents source URLs and types

**What it does NOT do**:
- Curate or filter claims
- Make recommendations
- Assign confidence levels

**Output format**:
```markdown
## Sources Found
1. [Source Title](url) - Type: Primary/Secondary/Vendor

## Raw Claims
1. Claim: "..."
   Source: [1]
   Evidence Type: Empirical/Anecdotal/Theoretical
```

#### Stage 2: research-curator (Opus)

**Purpose**: Validate claims against evidence standards

**What it does**:
- Evaluates evidence quality
- Assigns confidence levels (HIGH/MEDIUM/DROP)
- Drops claims with weak evidence

**Evidence grading**:
| Level | Criteria |
|-------|----------|
| HIGH | 2+ primary sources agree |
| MEDIUM | 1 primary or 2+ secondary |
| DROP | No evidence or vendor-only |

**Output format**:
```markdown
## Validated Claims

### HIGH Confidence
1. Claim: "..."
   Evidence: [primary sources]
   Confidence: HIGH

### MEDIUM Confidence
...

### Dropped Claims
- "..." - Reason: Vendor-only source
```

#### Stage 3: research-reviewer (Opus)

**Purpose**: Adversarial audit - challenge findings, find gaps

**What it does**:
- Questions assumptions
- Identifies missing perspectives
- Proposes safeguards
- Finds contradictions

**Output format**:
```markdown
## Assumptions Challenged
1. Assumption: "..."
   Challenge: "..."
   Recommendation: "..."

## Gaps Identified
...

## Safeguards Recommended
...
```

### Complete Pipeline Example

Topic: "Authentication approach for new API"

1. **Scout** finds 20 sources on JWT vs sessions vs OAuth
2. **Curator** validates: 8 HIGH, 5 MEDIUM, 12 dropped
3. **Reviewer** challenges: "JWT statelessness assumes no revocation need"
4. **Orchestrator** synthesizes: "Use JWT with Redis blacklist for revocation"

---

## Trust-But-Verify Protocol

### Why Verification is Mandatory

Agents may report success due to:
- Partial command execution
- Misinterpreted output
- Optimistic interpretation
- Actual failure masked by verbose output

### Verification Commands

| Agent Claim | Your Verification |
|-------------|-------------------|
| "Build succeeded" | Run `npm run build`, check exit 0 |
| "Tests pass" | Run `npm test`, verify pass count |
| "File created" | Run `ls -la path/to/file` |
| "Coverage >= 80%" | Run `npm run test:coverage`, check metrics |
| "No lint errors" | Run `npm run check`, verify exit 0 |

### What to Look For

**Build verification**:
```bash
npm run build
# Look for:
# - Exit code 0
# - "built in Xms" or similar
# - NO "error" in output
# - Build artifacts exist
```

**Test verification**:
```bash
npm test
# Look for:
# - "X passed, 0 failed"
# - Test count is reasonable (not 0 or very low)
# - No skipped tests you expected to run
```

### Verification Failure Response

When verification fails:

```markdown
VERIFICATION FAILED

**Agent claimed**: "Build succeeded"
**Actual result**: Build failed with 3 errors

**Errors found**:
1. src/utils/validator.ts:42 - Type error
2. src/index.ts:15 - Missing export
3. src/components/Form.tsx:8 - Unused import

**Action**: Return to implementation phase to fix.
```

---

## Plan Management Best Practices

### Real-Time Updates

The plan file must be updated in real-time, not batched:

**WRONG**:
```
1. Complete Task A
2. Complete Task B
3. Complete Task C
4. Update plan with all three
```

**RIGHT**:
```
1. Complete Task A
2. Update plan: [x] Task A
3. Complete Task B
4. Update plan: [x] Task B
5. Complete Task C
6. Update plan: [x] Task C
```

### Results Section Quality

**BAD Results section**:
```markdown
**Results:**
- Looked at the code
- Made some changes
- Tests pass
```

**GOOD Results section**:
```markdown
**Results:**
- Found validation at `src/api/routes/users.ts:87-94`
- Pattern uses Zod schemas from `src/schemas/`
- 3 endpoints missing: POST /sessions, PUT /users/:id, DELETE /items/:id
- Added validation middleware in commit `abc1234`
- Tests: 47 passed, 0 failed (3 new tests added)
```

### Checkpoint Format

After significant milestones:

```markdown
### Checkpoint: Investigation Complete

**Time**: 2026-01-21 14:30
**Status**: Complete

**Completed**:
- [x] Catalog all API endpoints
- [x] Identify validation patterns
- [x] Document missing validation

**Findings**:
- 12 endpoints total
- 3 missing validation
- Zod is the standard validation library

**Next**: Implementation phase
```

---

## Context Management

### Understanding Context Commands

Claude Code provides two commands for managing context:

| Command | Behavior | Use Case |
|---------|----------|----------|
| `/clear` | Wipes conversation completely | Fresh start, task switch |
| `/compact` | Summarizes and compresses | Reduce bloat, keep essentials |

### When to Use /clear

Use `/clear` when:
- Starting a completely new task
- Context has become corrupted or confusing
- Switching between unrelated features
- After completing a major milestone

### When to Use /compact

Use `/compact` when:
- Mid-task but context is getting large
- You need to preserve key findings
- Working on a long feature
- Responses are getting slower

### Pre-Clear Safety Checklist

Before running `/clear`:

```markdown
## Pre-/clear Checklist
- [ ] Plan.md updated with current [x] checkboxes
- [ ] All findings written to artifacts/
- [ ] Work item manifest.json updated
- [ ] No pending changes that need context to understand
- [ ] Current phase documented for resume
```

### Common /clear Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Clear mid-implementation | Lose code context | Complete phase first |
| Clear during debugging | Lose error history | Use agent for debug |
| Clear without updating plan | Lose progress tracking | Always update plan first |
| Clear with pending changes | Can't remember why | Document intent in artifacts |

### Recovery After /clear

Standard recovery procedure:

```bash
# 1. Check current work item
cat ".claude/work-items/sessions/${CLAUDE_SESSION_ID:-default}"

# 2. Read plan for progress
cat specs/<N>-<feature>/plan.md  # or work-items/<ID>/plan.md

# 3. Check git status for uncommitted work
git status

# 4. Read recent artifacts for context
ls -la .claude/work-items/<ID>/artifacts/
```

---

## Session Hygiene

### Three-Session Pattern

For complex features, work across three sessions:

**Session 1: Planning**
- Create spec with /mad-spec
- Generate plan with /mad-plan
- Break down tasks with /mad-tasks

**Session 2: Implementation**
- Investigate with code-investigator
- Implement with code-implementer
- Review with code-reviewer

**Session 3: Verification**
- Run all gates
- Verify with feature-verifier
- Create PR, cleanup

### When to Clear Context

Clear context (`/clear`) when:
- Context usage exceeds 100k tokens
- Switching between major phases
- Starting a new feature
- After completing implementation before review

### Monitoring Context Usage

Check `/cost` periodically:
- Under 50k: Good, continue
- 50-100k: Consider clearing after current task
- Over 100k: Clear before next major task

---

## Troubleshooting

### Problem: Agent claims success but verification fails

**Cause**: Agent may have misinterpreted output or run partial command

**Solution**:
1. Run the command yourself
2. Check the full output
3. If different from claim, return to previous phase
4. Document discrepancy for learning

### Problem: Context window errors

**Cause**: Too many MCP tools or large file reads

**Solution**:
1. Check MCP count (target: under 15)
2. Use `disabledMcpServers` in CLAUDE.md
3. Use agents to offload context-heavy work
4. Clear context and restart

### Problem: Resuming work, unclear where stopped

**Cause**: Plan file not updated properly

**Solution**:
1. Check git history for what was changed
2. Run tests to see current state
3. Update plan file with discovered state
4. Continue from correct point

### Problem: Agents not finding files

**Cause**: Wrong working directory

**Solution**:
1. Always include absolute working directory in agent prompt
2. Verify directory exists before spawning
3. For worktrees, use worktree path not main repo

### Problem: Build passes locally but agent claims failure

**Cause**: Different environment or partial output

**Solution**:
1. Verify agent used correct working directory
2. Check if node_modules need reinstall
3. Verify no environment differences
4. Run build in clean environment

---

## MAD Kit Modernizations (2026-02)

This section documents the comprehensive modernization of the MAD (spec/plan/tasks/implement/validate) workflow kit completed in February 2026. These improvements bring the kit to 2026 standards with industry best practices.

### Overview

**Work Item**: WI-20260208-2208-mad-kit-review
**Scope**: 42 tasks across 12 user stories (Phases 2-4 + Polish)
**Duration**: February 8-9, 2026
**Commits**: 4 major commits (d06f4c00, 5a23b440, b75d11fa, ad940826)

### Phase 2: Standards Alignment

#### Progressive Disclosure (US4)

**Problem**: 3 skills exceeded 500-line best practice
**Solution**: Extract verbose content to reference files

| Skill | Before | After | Reduction |
|-------|--------|-------|-----------|
| project-init | 719 lines | 242 lines | 66% |
| mad-spec | 586 lines | 484 lines | 17% |
| mad-implement | 527 lines | 502 lines | 5% |

**Reference files created**:
- `.claude/skills/project-init/references/` (3 files, 480 lines)
- `.claude/skills/mad-spec/references/` (2 files, 131 lines)
- `.claude/skills/mad-implement/references/` (1 file, 39 lines)

#### MADR 4.0 Adoption (US5)

**Change**: ADR template updated from Nygard 2011 to MADR 4.0 (2020+ community standard)

**Added sections** (optional but recommended):
1. **Validation** - How to verify decision is correct
2. **Pros and Cons** - Structured assessment
3. **More Information** - Expanded references
4. **Follow-up Questions** - Open issues for future revisits
5. **Confirmation** - Formal decision acceptance tracking

**RACI metadata** added to frontmatter:
- `decision_maker` - Who made the final decision
- `consulted` - Who was consulted
- `informed` - Who was notified

**Files updated**:
- `.mad/templates/adr-template.md` - Template structure
- `.claude/skills/mad-adr/SKILL.md` - Documentation with full example

#### Adaptive Workflow Depth (US6)

**Change**: mad-full now performs complexity triage in Phase 0

**Complexity levels**:
- **TRIVIAL** (fix, typo, config) → Skip spec+plan, go straight to tasks+implement (saves ~15 min)
- **STANDARD** (most features) → Full pipeline (spec → plan → tasks → implement)
- **COMPLEX** (architecture, integration) → Full pipeline + `--deep-research` flag

**Override flags**:
- `--complexity <trivial|standard|complex>` - Force specific complexity
- `--force-full` - Always use full pipeline regardless of detection

**Files updated**:
- `.claude/skills/mad-full/SKILL.md` - Phase 0 complexity triage logic
- `.claude/skills/mad-full/modes.md` - Complexity→phase mappings

### Phase 3: Token & Cost Optimization

#### Task System APIs (US7)

**Change**: Documented Claude Code 2.1.16+ native Task System APIs

**APIs documented**:
- `TaskCreate(subject, description, activeForm)` - Create coordination tasks
- `TaskUpdate(taskId, status, owner, blockedBy)` - Update task state and dependencies
- `TaskList()` - Query coordination state

**Benefits over custom coordination**:
- Native shared task list in `~/.claude/tasks/`
- Real-time updates (no polling)
- Atomic operations (no file locking)
- Built-in dependency graph

**Files updated**:
- `.claude/skills/mad-teams/SKILL.md` - API reference with examples
- `.claude/docs/agent-teams-guide.md` - 4 usage examples
- `.claude/skills/mad-full/SKILL.md` - Phase 5 parallel validation docs

#### Sonnet Cost Optimization (US8)

**Savings**: 40% cost reduction by using Sonnet 4.5 for Agent Teams teammates

**Pricing** (2026-02):
- Opus 4.5/4.6: $5 input / $25 output per MTok
- Sonnet 4.5: $3 input / $15 output per MTok
- **Cost ratio**: Sonnet is 0.60x Opus = **40% savings**

**Recommendation**: Use Sonnet for teammates, Opus for lead

**Example savings**:
- 3 researchers: 4x Opus → 2.8x Opus (30% reduction)
- 5 validators: 6x Opus → 4.0x Opus (33% reduction)

**Files updated**:
- `.claude/skills/mad-teams/SKILL.md` - Model Selection & Cost Optimization section
- `.claude/rules/model-selection.md` - Agent Teams Teammates guidance

#### Context Isolation (US9)

**Feature**: `context: fork` frontmatter field prevents context pollution

**Applied to**:
- `mad-tasks` - Isolates 150KB+ template content
- `mad-validate` - Isolates 4 parallel lens outputs
- `pr-pattern-extract` - Isolates 150KB+ PR comment data

**Benefits**:
- Main conversation stays focused
- Large data doesn't consume context window
- Parallel operations don't interfere
- Token efficiency for subsequent operations

**Files updated**:
- 3 skill frontmatters (added `context: fork`)
- `CLAUDE.md` - Context Management section expanded

#### Frontmatter Cleanup (US10)

**Change**: Removed 6 unrecognized frontmatter fields from all skills

**Removed fields** (moved to appropriate locations):
- `version` → `CHANGELOG.md`
- `changelog` → `CHANGELOG.md`
- `author` → `README.md` or removed
- `license` → `README.md` or removed
- `tags` → removed (no official support)
- `category` → removed (no official support)

**Optimizations**:
- Added `disable-model-invocation: true` to 10 read-only skills/agents
- Created 7 new CHANGELOG.md files
- All 18 core skills now have clean frontmatter

**Documentation**:
- `.claude/docs/skill-authoring-guide.md` - Comprehensive guide with migration examples

### Phase 4: Feature Repairs

#### Learning Pipeline (US11)

**Problem**: pr-pattern-extract outputs were ephemeral (deleted by janitor)
**Solution**: Changed output location to persistent `.mad/learning/` directory

**Fixed pipeline**:
```
pr-pattern-extract
    ↓ writes
.mad/learning/pr-patterns/*.md
    ↓ detected by
capture-learning.js hook
    ↓ transforms to
.mad/learning/patterns.json
    ↓ consumed by
apply-learnings skill
    ↓ updates
.claude/rules/patterns/*.md
```

**Pattern sources** (documented in apply-learnings):
- PR reviews (pr-pattern-extract) - Medium-High confidence
- Validation audits (mad-validate) - High confidence
- Failure logs (capture-learning.js) - High confidence when recurring
- Session analysis (session-improve `review`) - Medium confidence

**Files updated**:
- `.claude/skills/pr-pattern-extract/SKILL.md` - Output path changed, Hook Integration section added
- `.claude/skills/apply-learnings/SKILL.md` - Pattern Sources section added

#### C4 Diagrams (US12)

**Changes**: 3 improvements to mad-c4 skill

1. **Deployment diagram support**:
   - New `--level deployment` flag
   - Shows container-to-infrastructure mapping (e.g., API Server → AWS EKS)

2. **Default format changed to PlantUML**:
   - Was: Mermaid (experimental C4 support)
   - Now: PlantUML (stable, full C4 stdlib)
   - Mermaid still available via `--format mermaid`

3. **Default levels changed to 1-2**:
   - Was: All 4 levels (Context, Container, Component, Code)
   - Now: Levels 1-2 only (Context + Container)
   - Rationale: C4 creator discourages Level 4 for permanent docs
   - Override: `--level all` for all 4 levels

**Files updated**:
- `.claude/skills/mad-c4/SKILL.md` - All 3 changes documented with examples

### Key Benefits Summary

| Category | Benefit | Metric |
|----------|---------|--------|
| **Size** | Skills more maintainable | 3 skills reduced 17-66% |
| **Standards** | Industry alignment | MADR 4.0, Task System APIs adopted |
| **Cost** | Lower AI expenses | 40% savings with Sonnet teammates |
| **Performance** | Faster execution | Context isolation prevents pollution |
| **Quality** | Better documentation | 15 new/updated guides, 11 CHANGELOGs |
| **Features** | Working pipelines | Learning pipeline fixed, C4 improved |

### Migration Checklist

If upgrading from pre-2026-02 MAD Kit:

- [ ] Review new MADR 4.0 template (`.mad/templates/adr-template.md`)
- [ ] Update ADRs to include optional sections as needed
- [ ] Use `--complexity` flag when running `/mad-full` for trivial changes
- [ ] Document Team composition with `model: "sonnet"` for teammates
- [ ] Enable `context: fork` for skills processing >100KB data
- [ ] Clean skill frontmatter (remove version/changelog/author/license/tags/category)
- [ ] Update pr-pattern-extract outputs to `.mad/learning/`
- [ ] Use PlantUML for C4 diagrams (or `--format mermaid` if needed)
- [ ] Generate only Levels 1-2 C4 diagrams by default

### References

- MADR 4.0 specification: https://adr.github.io/madr/
- C4 model: https://c4model.com/
- Claude Code Task System APIs: (documented in mad-teams/SKILL.md)
- Skill authoring guide: `.claude/docs/skill-authoring-guide.md`

---

## References

- Rule files: `.claude/rules/`
- Agent definitions: `.claude/agents/`
- Skill documentation: `.claude/skills/*/SKILL.md`
- Work item tracking: `.claude/work-items/`
