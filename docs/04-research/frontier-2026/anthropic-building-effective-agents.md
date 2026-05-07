---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://www.anthropic.com/research/building-effective-agents
---

# Anthropic — Building Effective Agents

## Source
https://www.anthropic.com/research/building-effective-agents (fetched 2026-05-07)

## Load-bearing patterns

- **Augmented LLM**: Foundation enhancing models with retrieval, tools, and memory capabilities. The base building block on which all higher-order patterns rest.
- **Prompt Chaining**: Decompose tasks into sequential steps where each LLM call processes previous output. Trades latency for predictability.
- **Routing**: Classify inputs and direct them to specialized, optimized downstream handlers — the dispatcher pattern formalized.
- **Parallelization**: Execute independent subtasks simultaneously OR run the same task multiple times for diverse outputs (sectioning vs voting).
- **Orchestrator-Workers**: Central LLM dynamically breaks down tasks and delegates to specialized workers — distinguished from pre-defined Routing by dynamic decomposition.
- **Evaluator-Optimizer**: One model generates responses while another provides iterative feedback in loops — adversarial loop pattern.
- **Agents**: Autonomous systems where LLMs dynamically direct processes using tools based on environmental feedback. The most autonomous tier.

## Verbatim quotes worth preserving

> "Workflows are systems where LLMs and tools are orchestrated through predefined code paths. Agents are systems where LLMs dynamically direct their own processes and tool use."

> "Agentic systems often trade latency and cost for better task performance. For many applications, optimizing single LLM calls with retrieval and in-context examples is usually enough."

> "Tool definitions and specifications should be given just as much prompt engineering attention as overall prompts."

## Implications for the engine catalog

The 7-pattern taxonomy maps directly to the engine's planned council/orchestration architecture: Orchestrator-Workers IS the council pattern (lead investigator + parallel sub-agents per `agent-teams.md` §4-agent default); Evaluator-Optimizer IS the council-review verdict loop; Routing IS the dispatcher we already have for skill activation. F-NNN candidates for explicit Augmented-LLM (memory + retrieval as primitives), Routing (skill dispatcher as a first-class engine surface), and ACI investment ("agent-computer interface design parity with HCI design") deserve catalog entries.

## NEW F-NNN candidates

- F-001 augmented-llm-primitive — Engine MUST expose retrieval + tool-call + memory as first-class primitives, not bolt-ons — confidence: H
- F-002 dispatch-routing-skill — Engine MUST treat skill/agent dispatch as an explicit Routing pattern with classifiable input shape — confidence: H
- F-003 agent-computer-interface-discipline — Tool definitions get prompt-engineering parity with system prompts; ACI is a first-class design axis — confidence: H
- F-004 workflow-vs-agent-mode-selector — Engine MUST distinguish "predefined orchestration" (workflow) from "dynamic LLM-directed" (agent) modes; both are valid; mode is configurable per task — confidence: H
- F-005 evaluator-optimizer-loop — First-class adversarial-feedback loop primitive (lift the council-review pattern into a generic Evaluator-Optimizer engine surface) — confidence: H

## Confidence

HIGH — Anthropic's canonical agent-engineering doc; every pattern is widely cited and validated across the marketplace (zen-agents, sfi-dev-toolkit, fleet-orchestrator all implement subsets).
