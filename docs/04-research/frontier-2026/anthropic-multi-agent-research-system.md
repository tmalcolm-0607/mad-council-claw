---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://www.anthropic.com/engineering/multi-agent-research-system
---

# Anthropic — Multi-Agent Research System

## Source
https://www.anthropic.com/engineering/multi-agent-research-system (fetched 2026-05-07)

## Load-bearing patterns

- **Lead-agent + subagent orchestration**: A lead researcher analyzes the query, develops strategy, spawns specialized subagents in parallel, then synthesizes their compressed results.
- **Horizontal parallelism**: Lead spawns 3-5 subagents concurrently (not sequentially) — directly maps to the kit's "agent-teams default 4" rule.
- **Vertical parallelism**: Each subagent issues 3+ tool calls simultaneously rather than serially — token-cost optimization that compounds with horizontal fan-out.
- **Detailed task decomposition**: Subagents receive explicit objectives, output formats, tool guidance, AND clear scope boundaries — vague briefs produce duplicated work.
- **Effort-scaling rules**: Embed complexity-based resource allocation in prompts (1 agent for simple facts; 10+ for complex research) so the orchestrator picks the right team size.
- **Tool-matching heuristics**: Match tool selection to user intent; prefer specialized over generic tools — directly informs the kit's MCP-tiering rule.
- **Broad-to-narrow search**: Start with short queries, evaluate results, progressively narrow — the search-strategy primitive.
- **Extended-thinking integration**: Subagents plan approaches before tool use AND interleave thinking after tool results.
- **Self-improvement via Claude-as-prompt-engineer**: Use Claude itself to diagnose subagent failures and refine prompts — meta-loop pattern.
- **Three-tier evaluation**: small-sample (20 queries) → LLM-as-judge with rubrics (0.0-1.0 score) → human edge-case testing.
- **Resumable durable execution**: Checkpoint state so agents resume from the failure point rather than restart from scratch.

## Verbatim quotes worth preserving

> "The lead agent analyzes it, develops a strategy, and spawns subagents to explore different aspects simultaneously."

> "These changes cut research time by up to 90% for complex queries, allowing Research to do more work in minutes instead of hours."

> "Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information."

## Implications for the engine catalog

This document is the canonical reference for the kit's agent-teams discipline (`agent-teams.md` already mandates ≥3 parallel groups; this validates 4 as a stronger default). The vertical-parallelism finding is a NEW gap in the kit — current orchestration emphasizes parallel SUBAGENTS but doesn't push parallel TOOL CALLS within each subagent. The 3-tier evaluation pattern maps directly to F-NNN candidates for engine evals (synthetic fixture + LLM-judge rubric + human-spot-check). Resumable execution is a critical gap relative to the current handoff/resume-protocol — checkpoint granularity needs first-class treatment. Self-improvement via Claude-as-prompt-engineer is the meta-loop the kit's `/apply-learnings` skill nominally implements but inconsistently.

## NEW F-NNN candidates

- F-010 lead-subagent-orchestrator — First-class engine primitive: 1 lead + N parallel subagents + synthesis step; default N=4 per `agent-teams.md` — confidence: H
- F-011 vertical-tool-parallelism — Subagent prompts MUST include "issue independent tool calls in parallel" directive; the engine measures tool-call sequentiality and warns on serial-when-parallel-possible — confidence: H
- F-012 effort-scaling-prompt-block — Standard prompt block: "This task warrants N agents. Topic decomposability dictates N." — replaces hand-rolled team-size decisions — confidence: H
- F-013 three-tier-eval-harness — Engine ships eval harness: synthetic fixtures (20 cases) + LLM-as-judge with weighted rubric + human-spot-check on top failures — confidence: H
- F-014 durable-checkpoint-resume — First-class state checkpointing per agent invocation; orchestrator resumes from last checkpoint, not from scratch — confidence: H
- F-015 claude-as-prompt-engineer-loop — Meta-loop: when a subagent fails, spawn a "diagnose this failure, propose a refined prompt" agent; gated by council-verdict before applying — confidence: M
- F-016 broad-to-narrow-search-primitive — Engine treats "search" as a 2-pass primitive (broad scan then narrow drill-down) rather than single-shot query — confidence: M

## Confidence

HIGH — Anthropic's most operationally-detailed multi-agent reference; every pattern named here is empirically validated by their Research product. The kit already implements ~60% of these; the rest are the wave-002+ implementation backlog.
