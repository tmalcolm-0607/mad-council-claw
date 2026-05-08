---
category: ai-llm-patterns
subcategory: token-optimization
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Token Optimization (2026)

## Overview

Token management strategies including artifact patterns, context compression, agent delegation, and handoff protocols to maximize context efficiency.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Artifact Files** | Persist findings to disk, not in-memory - survives context compaction |
| **Agent Delegation** | Offload context-heavy work to agents with fresh context |
| **Composite Agents** | Save ~90% orchestrator context via self-contained loops |
| **File-Based Handoff** | Pass data via files, not prompts - prevents token waste |
| **Context Monitoring** | Track usage with `/cost`, respect thresholds |

## Patterns (Current)

### Prompt Caching (Automatic)

**From community analysis** (stevekinney.com, claudefa.st):

**Feature**: Claude Code automatically uses prompt caching to optimize performance and reduce costs

**Savings**: 90% savings on repeated content after just 2 requests

**How it works**:
- Caches system prompt, CLAUDE.md, rules, agent definitions
- Reuses cached content across requests in same session
- No manual configuration needed

**Optimization**: Structure prompts to maximize reuse of common context

### Context Window Optimization

**From pricing/cost analysis**:

**Key insight**: "Length of context windows directly affects total token usage."

**Optimization strategies**:
- Include only essential background
- Discard unneeded history (use `/clear` between unrelated tasks)
- Chunk documents judiciously (don't paste entire files if only section needed)
- Challenge each piece of information before adding

**From official docs**:
"Concise is key - context window is shared resource. Only add context Claude doesn't already have."

### Built-in Cost Tracking

**From stevekinney.com, claudefa.st**:

**Real-time tracking**: Type `/cost` at any time

**Shows**:
- Input tokens (read)
- Output tokens (generated)
- Estimated cost breakdown by model

**Use cases**:
- Check before spawning expensive agents
- Monitor during long sessions
- Validate optimization efforts

### Compression Strategies

**From official docs + local patterns**:

| Strategy | Purpose | When to Use |
|----------|---------|-------------|
| `/compact` | Compress long conversations with custom instructions | Session > 70% context capacity |
| `/clear` | Reset context between unrelated tasks | After 2+ failed corrections, or task switch |
| Subagents for research | Investigation in separate context, report summaries only | Multi-file analysis, research tasks |
| Composite agents | Self-contained loops return only summary | investigate-and-implement, review-and-fix |
| CLAUDE.md conciseness | Keep under 500 lines, prune regularly | Continuous improvement |

### Artifact Pattern

**From `.claude/rules/phased-review-protocol.md`**:

**Core principle**: Never pass raw code between agents via prompt text

**Instead**:
1. Agent A writes findings to file in `.claude/scratch/`
2. Agent B reads that file as input
3. Each file has size cap (e.g., 200 lines for baselines)
4. Manifest.json tracks artifacts and phase completion

**Benefits**:
- Keeps each agent's context bounded
- Survives context compaction
- Enables session resume
- Prevents orchestrator context bloat

**Example**:
```
Agent 1 prompt:
"Extract DI patterns from repo X.
 Output: .claude/scratch/review-ABC/baselines/repo-x-patterns.md
 Max 200 lines."

Agent 2 prompt:
"Read .claude/scratch/review-ABC/baselines/repo-x-patterns.md.
 Compare against PR diff..."
```

### Agent Context Offloading

**From project patterns**:

| Pattern | Context Savings | Use Case |
|---------|----------------|----------|
| **Direct agent** | Agent context isolated | Single-step tasks (investigate OR implement) |
| **Composite agent** | ~90% orchestrator context saved | Multi-step tasks (investigate + implement + verify) |
| **Synchronous parallel** | Multiple agents run concurrently | 3+ independent tasks via single message with multiple Task tool blocks |
| **Foreground agent** | Clean result in-memory | Short tasks (<50 lines output) |

**From `.claude/rules/model-selection.md`**:

**File count heuristic**:
- 1-2 files: Use direct agent
- 3+ files: Prefer composite agent (each subagent gets fresh context with rules auto-loaded)

**Prevents context saturation** on multi-file tasks where pattern rules consume significant context.

> **PROHIBITED**: `run_in_background: true` is banned by project policy (CLAUDE.md).
> Reason: confirmed bugs -- hangs (#20679), empty outputs (#21352), session freezes (#17540).
> Correct approach: use synchronous parallel Task calls in a **single message** with multiple tool blocks.

### Context Guardian Thresholds

**From `.claude/rules/context-guardian.md`**:

| Threshold | Behavior | Actions |
|-----------|----------|---------|
| **~50% (ADVISORY)** | Warning | Be conservative with agent spawning, avoid large file reads |
| **~70% (PREPARE)** | Wind down | Complete current task, run gates, commit, consider handoff |
| **~85% (HALT)** | Hard stop | Generate handoff document, tell user to start new session |

**Configurable** via `.claude/settings.local.json` env variables:
- `CONTEXT_GUARDIAN_ADVISORY_THRESHOLD` (default 0.50)
- `CONTEXT_GUARDIAN_PREPARE_THRESHOLD` (default 0.70)
- `CONTEXT_GUARDIAN_HALT_THRESHOLD` (default 0.85)

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Prompt caching | Manual | Automatic (90% savings after 2 requests) | No action needed, automatic optimization |
| Cost tracking | External tools | Built-in `/cost` command | Use `/cost` for real-time tracking |
| Context management | Manual `/clear` | Auto compaction + manual control | Rely on auto compaction, use `/compact <instructions>` |
| Agent context | All agents consume orchestrator context | Composite agents save ~90% | Use composites for multi-step tasks (3+ files) |
| Context thresholds | No automated warnings | Context Guardian hook monitors usage | Respect ADVISORY/PREPARE/HALT thresholds |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Ignoring context usage | Performance degradation, surprise compaction | Track with `/cost`, respect Guardian thresholds |
| Long sessions without compaction | Irrelevant context reduces performance | Auto compaction handles this, or manual `/compact` |
| Passing code in prompts | Wastes tokens | Write to file, agent reads file |
| All agents sequential | Unnecessary wall-clock delay for independent tasks | Use synchronous parallel Task calls (single message, multiple tool blocks) |
| `run_in_background: true` on Task spawns | Confirmed bugs: hangs, empty outputs, session freezes | Use synchronous parallel Task calls (single message, multiple tool blocks) |
| Over-explaining to Claude | Wastes tokens | Assume Claude knows standard concepts |
| Not using prompt caching | Miss 90% savings on repeated content | Structure prompts for reuse (automatic) |
| Reading full files unnecessarily | Context waste | Read only needed sections, use Grep for search |
| 10+ concurrent agents | Completion notifications bloat context | Cap at 8, prefer 4-6 with file handoff |

## Examples

### Example 1: Artifact-Based Handoff

**Ineffective** (passes code in prompt):
```
Agent 1 completes, returns 500 lines of findings
Orchestrator stores in memory
Agent 2 launched with findings in prompt → 500 lines wasted
```

**Effective** (artifact pattern):
```
Agent 1 prompt:
"Research OAuth2. Write findings to .claude/scratch/oauth2-research/findings.md. Max 200 lines."

Agent 1 completes, writes file

Agent 2 prompt:
"Read .claude/scratch/oauth2-research/findings.md. Compare against our auth implementation in src/auth/."
```

**Savings**: Orchestrator context stays clean, findings survive compaction, resume-able

### Example 2: Composite Agent Context Savings

**Scenario**: Multi-file feature implementation (5 files, investigate + implement + verify)

**Direct agents**:
```
code-investigator → returns 200 lines to orchestrator
code-implementer → receives 200 lines + new instructions
feature-verifier → receives all previous context

Orchestrator context: ~600 lines consumed
```

**Composite agent**:
```
investigate-and-implement → runs loop internally, returns summary only

Orchestrator context: ~50 line summary

Savings: ~90% orchestrator context
```

**Trade-off**: Composite costs more total tokens but protects orchestrator context for long workflows

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Context filling up fast | Use `/cost` to check; offload to agents; use `/clear` between tasks |
| Agent outputs bloat context | Use artifact pattern - write to file, not in-memory |
| Surprise compaction | Respect Context Guardian thresholds; generate handoff at 85% |
| Prompt caching not helping | Structure prompts to reuse common context (automatic but requires consistency) |
| Agent concurrency overhead | Cap at 8 total; prefer 4-6 with file handoff; use synchronous parallel (not `run_in_background`) |

## See Also

- `context-management-2026.md` - Context thresholds
- `.claude/rules/phased-review-protocol.md` - Artifact patterns
- `.claude/rules/context-guardian.md` - Threshold behaviors
- `.claude/rules/model-selection.md` - Composite vs direct agents

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (Tier 1 - Official)
- https://stevekinney.com/courses/ai-development/cost-management (Tier 2 - Community)
- https://claudefa.st (Tier 2)
- `.claude/rules/phased-review-protocol.md` (Local pattern)
- `.claude/rules/context-guardian.md` (Local pattern)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + cost guides + local patterns)
**Frequency validation**: 90%+ (patterns appear in official docs + multiple optimization guides)
