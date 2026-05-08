---
category: ai-llm-patterns
subcategory: model-selection
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Model Selection (2026)

## Overview

Model selection criteria for Opus 4.5/4.6, Sonnet 4.5, and Haiku 4.5 across different task types, with cost optimization strategies for agent teams.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Opus for Reasoning** | Complex analysis, architecture, security - quality critical |
| **Sonnet for Balance** | 90% of Opus capability at 2x speed - recommended default |
| **Haiku for Cleanup** | Mechanical tasks, formatting, batch ops - 90% cost savings |
| **Teammate Sonnet** | 40% cost savings using Sonnet for teammates |
| **Composite Agents** | Use Opus for composites (multi-step reasoning) |

## Patterns (Current)

### Model Lineup (Claude 4.5 Series)

**From pricing analysis** (claudefa.st, finout.io, aifreeapi.com):

| Model | Input/Output (per MTok) | Cost Ratio vs Opus | Best For |
|-------|------------------------|-------------------|----------|
| **Opus 4.5/4.6** | $5 / $25 | 1.00x (baseline) | Complex reasoning, architecture, security |
| **Sonnet 4.5** | $3 / $15 | **0.60x (40% savings)** | Pair programming, balanced performance (recommended) |
| **Haiku 4.5** | ~$0.50 / ~$2.50 | **~0.10x (90% savings)** | Simple tasks, high volume |

**Recommendation from community**: "Sonnet wins as it offers 90% of Opus capability at 2x speed, rarely hits usage limits, ideal for pair programming workflow."

### Agent Type Mappings

**From `.claude/rules/model-selection.md`**:

| Agent | Model | Rationale |
|-------|-------|-----------|
| **Core Workflow** | | |
| work-planner | Opus | Planning requires understanding complex requirements, identifying dependencies |
| code-investigator | Opus | Deep code analysis, trace execution flows, multi-file synthesis |
| code-implementer | Opus | TDD implementation demands architectural judgment, quality over speed |
| code-reviewer | Opus | Nuanced analysis of quality, security, maintainability |
| feature-verifier | Opus | Careful reasoning to interpret test results in context |
| **Research Pipeline** | | |
| research-scout | Sonnet | Breadth-first discovery prioritizes coverage, cost-effective |
| research-curator | Opus | Truth-gating requires judgment to assess validity, filter weak evidence |
| research-reviewer | Opus | Adversarial analysis needs deep reasoning to challenge conclusions |
| parallel-researcher | Opus | Runs curator + reviewer logic internally |
| **Composite Agents** | | |
| investigate-and-implement | Opus | Orchestrates multi-step workflow, requires full capability |
| review-and-fix | Opus | Opus-level judgment to distinguish real issues from noise |
| coverage-loop | Opus | Iterative reasoning to identify meaningful gaps |
| **Utility** | | |
| janitor | Haiku | Simple cleanup, minimal reasoning, maximum cost efficiency |
| test-selector | Sonnet | Test tier selection follows heuristic rules |

### Cost Optimization

**Tactical model switching**: 60-80% cost savings possible

| Strategy | Savings | When to Use |
|----------|---------|-------------|
| Sonnet for teammates | 40% | Agent teams with 2+ teammates |
| Haiku for cleanup | 90% | Mechanical tasks, batch operations |
| Sonnet as default | 40% | Interactive pair programming workflow |
| Hybrid approach | 60-80% | Mix models by task complexity |

**From thecaio.ai cost reduction guide**:
- Switch to Haiku for simple tasks: `/model haiku`
- Use Sonnet for balanced work (default recommendation)
- Reserve Opus for complex reasoning/architecture

### Selection Criteria Matrix

| Criterion | Haiku | Sonnet | Opus |
|-----------|-------|--------|------|
| **Reasoning Depth** | Shallow | Moderate | Deep |
| **Pattern Matching** | Basic | Strong | Excellent |
| **Creative Problem Solving** | Limited | Good | Excellent |
| **Multi-file Analysis** | Poor | Good | Excellent |
| **Nuanced Judgment** | Limited | Moderate | Excellent |
| **Cost Efficiency** | Highest | Good | Lowest |
| **Speed** | Fastest | Fast | Slowest |

**Decision guide**:

| Upgrade to Opus if... | Downgrade to Haiku if... |
|-----------------------|--------------------------|
| Task involves security | Task is purely mechanical |
| Multiple files interact | Single file, simple change |
| Architectural impact | No business logic |
| User-facing quality | Internal/temporary |

### Team Cost Optimization (Sonnet Teammates)

**From `.claude/rules/model-selection.md` "Agent Teams Teammates" section**:

**Recommendation**: Use **Sonnet 4.5 for teammates** while keeping **Opus 4.5/4.6 for lead**

**Cost savings examples**:

| Team Type | All Opus | Lead Opus + Teammates Sonnet | Savings |
|-----------|----------|------------------------------|---------|
| 3 researchers | 4x Opus | 2.8x Opus | 30% |
| 5 validators | 6x Opus | 4.0x Opus | 33% |
| 3 reviewers | 4x Opus | 2.8x Opus | 30% |

**Rationale**: Sonnet 4.5 sufficient for:
- Research (scout/curator/reviewer pipeline)
- Validation (rule-based checking)
- Code review (pattern-based within domain)
- Implementation (following established patterns)

**Lead requires Opus**:
- Complex synthesis across teammate outputs
- Coordination and decision-making
- Final quality assurance
- Handling edge cases and ambiguity

**Use Opus for teammates only when**:
- Security-critical code review (nuanced vulnerability detection)
- Complex architectural decisions (beyond template execution)
- First-time pattern establishment (once pattern known, Sonnet can follow)

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Model lineup | Opus 4, Sonnet 3.7 | Opus 4.6, Sonnet 4.5, Haiku 4.5 | Update model selection to 4.5 series |
| Sonnet recommendation | "Good enough" | "Recommended default" (90% Opus capability, 2x speed) | Prefer Sonnet for pair programming |
| Team model selection | All teammates same model as lead | Lead Opus + Teammates Sonnet | Use `model: "sonnet"` for teammates |
| Cost awareness | External tracking | Built-in `/cost` command | Use `/cost` for real-time monitoring |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Using Opus for all tasks | Unnecessary cost | Use Sonnet (default) or Haiku (simple tasks) |
| Haiku for complex reasoning | Poor quality, more revisions | Use Opus for architecture, security |
| All teammates Opus | Excessive cost | Lead Opus + Teammates Sonnet (30% savings) |
| Ignoring cost tracking | Budget overruns | Use `/cost` regularly |
| Model switching mid-task | Context loss | Complete task with original model |

## Examples

### Example 1: Agent Model Selection

**Code investigator** (Opus):
```
Task({
  subagent_type: "code-investigator",
  prompt: "Analyze authentication flow across src/auth/. Document token refresh logic, session management, and failure paths.",
  model: "opus"  // Multi-file analysis requires deep reasoning
})
```

**Janitor** (Haiku):
```
Task({
  subagent_type: "general-purpose",
  prompt: "Delete all .log files older than 7 days from .claude/scratch/",
  model: "haiku"  // Mechanical task, maximum cost efficiency
})
```

### Example 2: Team Cost Optimization (Sonnet Teammates)

**Research team** (Lead Opus + 3 Sonnet researchers):

```
TeamCreate({
  team_name: "research-swarm",
  teammates: [
    { name: "oauth2-researcher", model: "sonnet" },
    { name: "jwt-researcher", model: "sonnet" },
    { name: "pkce-researcher", model: "sonnet" }
  ]
})
```

**Cost**: 2.8x Opus (vs 4x if all Opus) = **30% savings**

**Quality**: Sonnet handles structured research pipeline well. Lead synthesizes at Opus level.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Opus too slow for iterative work | Switch to Sonnet for development, Opus for final review |
| Haiku producing low quality | Upgrade to Sonnet - task likely requires pattern matching |
| Team costs excessive | Use Sonnet for teammates, keep Opus for lead |
| Not sure which model | Default to Sonnet (90% Opus capability, 2x speed) |
| Cost tracking unclear | Use `/cost` command for real-time breakdown |

## See Also

- `.claude/rules/model-selection.md` - Per-agent model mappings
- `agent-teams-2026.md` - Team cost optimization
- `.claude/skills/mad-teams/SKILL.md` - Model selection for teams

## Research Metadata

**Sources consulted**:
- https://claudefa.st/blog/models/model-selection (Tier 2 - Community)
- https://www.finout.io/blog/claude-pricing-in-2026-for-individuals-organizations-and-developers (Tier 2)
- https://www.aifreeapi.com/en/posts/claude-api-pricing-per-million-tokens (Tier 2)
- https://www.thecaio.ai/blog/reduce-claude-code-costs (Tier 2)
- `.claude/rules/model-selection.md` (Local pattern file)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across pricing docs + cost optimization guides + local patterns)
**Frequency validation**: 90%+ (pricing consistent across sources, recommendations align)
