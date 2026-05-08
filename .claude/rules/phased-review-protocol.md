---
paths:
  - "**/specs/**"
  - "**/*review*"
  - ".mad/scratch/review-*/**"
---

# Phased Review Protocol

How to conduct reviews that span multiple reference repos without exceeding context limits.

## When to Use

| Scenario | Protocol |
|----------|----------|
| Single-repo PR, < 500 line diff | Standard `/pr-review` |
| Single-repo PR, > 500 line diff | `/pr-review` with diff chunking |
| Cross-repo comparison, 2+ reference repos | `/pr-deep-review` (this protocol) |
| Post-review pattern extraction | `/apply-learnings` |

## Core Principle: Artifacts as Handoff

Never pass raw code between agents via prompt text. Instead:

1. Agent A writes findings to a **file** in `.mad/scratch/review-{ID}/`
2. Agent B reads that **file** as input
3. Each file has a **size cap** (200 lines for baselines, 100 lines for findings)
4. A **manifest.json** tracks which artifacts exist and which phases are complete

This keeps each agent's context bounded regardless of how many repos or files are involved.

## Baseline Extraction Pattern

When comparing a PR against a reference repo, don't read the whole repo. Extract a compact baseline:

```
Input: Reference repo path + PR feature description
Output: ~200 line pattern summary covering:
  - DI registration (how services are registered)
  - Error handling (exception types, Result<T>, middleware)
  - Config (Options pattern, validation, section names)
  - Testing (frameworks, naming, mocking approach)
  - Health checks (registration, implementation)
  - Logging (source generators, structured logging)
  - Domain-specific patterns relevant to the PR
```

**Rule**: If a baseline exceeds 200 lines, the investigator must summarize — not truncate.

**Enforcement**: Output constraints are ENFORCED BY HOOK (`validate-baseline-size.js`). Agents will be blocked from stopping if their baseline exceeds 200 lines. The hook allows up to 2 retries before falling back to orchestrator-level truncation.

## Continuation Checkpoints

Any review phase can be interrupted and resumed:

1. **Manifest-based**: `manifest.json` tracks per-task completion within each phase
2. **File-based**: Completed artifacts persist on disk across sessions
3. **Summary-based**: `continuation-notes.md` captures orchestrator state for handoff

A new session reads the manifest, skips completed tasks, and continues from the first incomplete task.

## Reference Repo Priority

When budget is limited, prioritize repos in this order:

1. **PR's own repo** - always first (e.g., the repo's own patterns for its PR)
2. **Most architecturally similar** — same service tier or domain
3. **Most advanced patterns** — repos known for mature implementations
4. **Broadest coverage** — repos that cover patterns not seen in earlier baselines

Skip repos that add no new patterns beyond what earlier baselines already covered.

## Context Budget Rules

| Role | Max Context | Mechanism |
|------|-------------|-----------|
| Baseline extractor | 15K tokens | `code-investigator` with maxTurns: 15 |
| Domain reviewer | 18K tokens | `domain-reviewer` with maxTurns: 20 |
| Cross-ref investigator | 15K tokens | `general-purpose` with Write access (must persist to disk) |
| Consistency checker | Included in architecture reviewer | Part of architecture-reviewer budget |
| Community researcher | 5K per finding | WebSearch/WebFetch per needs_research finding |
| Report synthesizer | 8K tokens | Reads compact findings only |
| Orchestrator | 30K tokens | Never reads raw code, only artifacts |

## Agent Type Selection for File Output

Agents that must persist findings to disk MUST have Write access:

| Agent Type | Can Write Files? | Use For |
|------------|-----------------|---------|
| `code-investigator` | NO (Read, Grep, Glob only) | Prompts that return results to orchestrator |
| `general-purpose` | YES (all tools) | Cross-ref and baseline tasks that write to disk |
| `code-implementer` | YES (Read, Write, Edit, Grep, Glob, Bash) | Implementation tasks |
| `domain-reviewer` | NO (Read, Grep, Glob only) | Review tasks that return findings to orchestrator |
| `general-purpose` (consistency) | YES (all tools) | Consistency check that writes to findings/ |

**Rule**: If a background agent's findings must survive context compaction or session restart, use an agent type with Write access and instruct it to save findings to `.mad/scratch/review-{ID}/findings/`.

## Orchestrator Context Protection

Background agents return completion notifications as conversation turns. Each notification consumes orchestrator context even when findings are already on disk.

**Rules**:
1. **Cap background agents**: Max 8 per session. Prefer 4-6 with file-based handoff.
2. **Don't wait for late notifications**: Once artifacts exist on disk, proceed. Agent completion messages add no value if findings are already file-persisted.
3. **Checkpoint after Phase 2**: Before launching cross-reference agents, verify orchestrator context is still healthy. If > 50% consumed, use `/compact` or consolidate phases.
4. **Prefer foreground for small tasks**: If an agent will return < 50 lines, run foreground (non-background) to avoid idle notification overhead.
5. **Cross-ref agents write to disk**: Always use `general-purpose` (not `code-investigator`) for cross-reference tasks so findings persist regardless of context state.

## Deliverable Validation

After each phase completes, the orchestrator MUST verify all expected artifact files exist before proceeding to the next phase.

### Orchestrator File Check Pattern

```
For each expected_file in phase manifest:
  if !exists(expected_file):
    log to .mad/scratch/review-{ID}/failures.log
    skip this repo/domain in downstream aggregation
    continue (do NOT abort the entire review)
  if countLines(expected_file) < 5:
    log warning: trivial deliverable
    include but flag in synthesis
```

### Hook-Level Validation

The `validate-agent-deliverable.js` SubagentStop hook provides supplementary checks:

- Detects expected deliverable paths from agent prompt keywords
- Warns (non-blocking) if files are missing or trivially short (<5 lines)
- Logs all failures to `.mad/scratch/review-{ID}/failures.log`

| Deliverable Type | Expected Path | Hook Behavior |
|-----------------|---------------|---------------|
| Baseline | `baselines/{repo}-patterns.md` | Warn if missing/trivial |
| Master baseline | `baselines/{project}-master.md` | Warn if missing/trivial |
| Cross-reference | `findings/crossref-{repo}.md` | Warn if missing/trivial |
| Community research | `findings/research-results.md` | Warn if missing/trivial |
| Domain findings | Returned in-memory | Skipped (no file check) |

### Failure Log Convention

All failures append to `.mad/scratch/review-{ID}/failures.log` with timestamp, agent ID, and expected path. The orchestrator reads this during SYNTHESIZE to note incomplete analyses.

## Findings Schema (--deep --fix)

See `.mad/docs/phased-review-schema.md` for the full JSON schema, confidence-gated classification, and fix_outcome values.

## Phase 3: Parallel Execution

Cross-reference agents write to independent files and CAN run in parallel. This replaces the original sequential design.

### Parallelism Rules

Launch cross-ref agents in a SINGLE Task tool message (synchronous parallel). Do NOT use `run_in_background: true` — it has confirmed bugs causing hangs (#20679), empty outputs (#21352), and session freezes (#17540).

### Parallelism Budget

| Phase 1+2 Context Usage | Phase 3 Parallelism |
|-------------------------|---------------------|
| < 40% | Up to 4 parallel agents |
| 40% - 60% | Up to 3 parallel agents |
| > 60% | Sequential, or `/compact` first |

### Staggered Batch Fallback

If more than 4 repos need cross-referencing: launch priority-sorted batches of 3-4 agents. After each batch, check context health. If > 60%, run remaining sequentially or skip lowest-priority repos.

### Pre-Flight Validation

Before launching: verify all repo paths exist, output directory exists, file names are unique per repo, and each agent's prompt specifies its exact output path.

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| All repos in one agent | Context overflow | One agent per repo |
| Raw diff in prompt | Wastes tokens on unchanged lines | Write diff to file, agent reads it |
| No manifest | Can't resume | Always maintain manifest.json |
| Baseline > 200 lines | Downstream agents bloat | Summarize, don't truncate |
| Skipping repo existence check | Agent fails reading nonexistent path | `ls` before spawning |
| `code-investigator` for disk-persisted tasks | Can't write — findings lost on context clear | Use `general-purpose` agent |
| 10+ background agents in one session | Completion notifications bloat orchestrator context | Cap at 8, prefer 4-6 |
| Waiting for stale agent notifications | Context waste on already-consumed data | Proceed once artifacts exist on disk |
| `run_in_background: true` for agents | Hangs, empty outputs, session freezes | Synchronous parallel via single message |
| Sequential Phase 3 for <4 repos | Unnecessary wall-clock delay | Parallel with batched fallback |
| Skipping deliverable file check | Missing artifacts silently dropped | Check file existence after each phase |
| Skipping consistency check | Pattern drift undetected | Run Phase 2.5 with baseline |
| Automatic web search on every finding | Latency and noise | Conditional research only (Phase 2.7) |
