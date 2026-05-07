---
artifact-class: research-finding
source-tag: [R:frontier-2026-gap]
confidence: medium
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://gurusup.com/blog/agent-orchestration-patterns
  - https://blog.whoisjsonapi.com/ai-agent-engineering-in-2026-architectures-patterns-and-real-world-systems/
  - https://www.ibm.com/think/news/ai-tech-trends-predictions-2026
  - https://agixtech.com/insights/conductor-vs-swarm-multi-agent-ai-orchestration/
  - https://www.digitalapplied.com/blog/agent-architecture-patterns-taxonomy-2026
  - https://nevo.systems/blogs/nevo-journal/ai-agent-swarms
  - https://machinelearningmastery.com/7-agentic-ai-trends-to-watch-in-2026/
  - https://www.sitepoint.com/the-definitive-guide-to-agentic-design-patterns-in-2026/
---

# 2026 emerging patterns (gap analysis vs wave-1)

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter. Looking specifically for items NOT covered in wave-1's 12 frontier whitepapers.

## Wave-1 coverage check (what we already have)

Wave-1 already documented: orchestrator-worker (F-010), handoffs (F-021), capability negotiation (F-029), evaluator-optimizer loop (F-005), multi-agent research system (F-010 to F-016), agent autonomy framework (F-017 to F-020), Skills authoring (F-051 to F-056), A2A protocol (F-057 to F-063), MCP (F-025 to F-033). This wave-2 finding focuses on **patterns NOT covered**.

## NEW patterns surfaced (vs wave-1)

- **Agentic Operating System (AOS)** — frontier framing for 2026/2027. An AOS is the runtime layer that standardizes orchestration, safety, compliance, and resource governance across heterogeneous agent ecosystems. Distinct from individual agent frameworks (LangGraph, CrewAI, AutoGen). Predicted as the next major abstraction tier — equivalent to "OS for agents." Status: aspirational/forecast, not shipping.
- **Plan-and-Execute pattern (frontier-economic variant)**: capable model creates strategy → cheaper models execute. Cited 90% cost reduction vs frontier-everywhere. Distinguished from generic orchestrator-worker by the explicit cost-economic motivation: the plan tier is fixed-Opus, the execute tier is fixed-Haiku/Sonnet. Surfaces in 2026 sources but not in wave-1's 12 papers.
- **The "Puppeteer Orchestrator" framing** — Gartner's term for production-deployed coordinator agents. 1,445% surge in multi-agent system inquiries Q1 2024 → Q2 2025. Naming convention emerging in industry parlance distinct from "orchestrator-worker" academic term.
- **Hybrid Conductor+Swarm** — for mid-market firms, neither pure-conductor nor pure-swarm wins; a hybrid (reliability of conductor + scalability of swarm) is the recommended ROI shape. Specifically applies when work has BOTH well-scoped subtasks (need conductor reliability) AND open-ended exploration tasks (need swarm scale).
- **Pipeline as a primary pattern (5th orchestration shape)** — sequential stage-based processing. Underrated; many 2026 sources list it alongside orchestrator/swarm/mesh/hierarchical as a peer. Wave-1 implicitly covers prompt chaining (F-001), but Pipeline as a multi-agent shape (each stage a different agent) is distinct.
- **Multi-agent collaboration as 2026 leap** — "the next major leap is collaboration; ecosystems of specialized agents instead of single all-purpose agents." Industry direction signal: multi-agent default beats single-agent default for non-trivial tasks. The "single super-agent" approach is being abandoned.
- **Hierarchical + Graph wins production; Swarm/Blackboard rarely do** — empirical 2026 finding. Despite swarm hype, production systems use hierarchical (supervisor-worker) or graph (LangGraph state-graph) topologies. Swarm is "theoretically interesting but rarely outperforms" hierarchical/graph in real deployments. This refines wave-1's pattern coverage with a production-validity ranking.
- **Policy-driven schemas for agent runtimes** — emerging shape: agent behavior is governed by declarative policy schemas, not by hardcoded prompts. The runtime interprets policy against task context. Frontier; precedes the AOS framing as a building block.

## Patterns explicitly mentioned but NOT load-bearing in 2026

- **"Magentic" (Microsoft Agent Framework)** — surfaced in earlier 2025 commentary but the 2026 industry usage has shifted to "orchestrator" / "puppeteer" framing. Magentic-One (the original Microsoft research project) is now subsumed under Microsoft Agent Framework's orchestrator-pattern surface. Wave-1 covered AutoGen; the Magentic terminology is fading.
- **"Digital assembly line" as a distinct named pattern** — search returned no strong 2026 sources using this exact term as a pattern name. The IBM 2026 trends piece references "agent ecosystems"; "digital assembly line" appears to be a pre-2026 marketing term that hasn't crystallized into a standard pattern name. **No findings** under this specific pattern label; the underlying concept (sequential agent stages) IS captured by the Pipeline pattern.

## Verbatim quotes worth preserving

> "A shift is enabling the emergence of agentic runtimes to run complex workflows with dynamic adaptation through policy-driven schemas, forming the foundation for an 'Agentic Operating System (AOS).'"

> "The next major leap in agentic AI is collaboration, with organizations building ecosystems of specialized agents that work together to solve complex problems instead of relying on single, all-purpose agents."

> "Hierarchical (supervisor-worker) and graph topologies are the two multi-agent patterns that earn their cost in production."

> "The Plan-and-Execute pattern, where a capable model creates a strategy that cheaper models execute, can reduce costs by 90% compared to using frontier models for everything."

## Implications for the engine catalog

The kit's `agent-teams.md` is hierarchical (lead + teammates), which validates as a production-default. The kit does NOT yet expose: (a) Plan-and-Execute as an explicit mode (it's implicit in "lead Opus + teammates Sonnet"), (b) Pipeline as a first-class multi-agent shape (different agents per stage), (c) Hybrid Conductor+Swarm guidance (when to choose each), (d) policy-driven schemas (the kit is rule-driven, which is similar but not the same — rules govern human-in-loop discipline, policy schemas govern runtime agent behavior).

The "AOS" framing is aspirational; the kit cannot/should-not commit to becoming an AOS. But the kit IS in the same shape (orchestration + safety + compliance + resource governance) and can claim "an AOS-shaped engineering kit."

## NEW F-NNN candidates

- F-099 plan-and-execute-explicit-mode — (Duplicate-with-emphasis from F-087 in orchestrator-worker doc; combine entries when consolidating into engine catalog) — Plan-and-Execute as a declared mode with cost-tier locked split — confidence: M
- F-100 pipeline-as-multi-agent-shape — First-class Pipeline pattern: a sequence of stages where each stage is potentially a different agent + tier + skill. Distinct from orchestrator-worker (parallel) and from prompt-chaining (single-agent serial) — confidence: M
- F-101 conductor-vs-swarm-decision-rule — Documented decision rule for when to use conductor (orchestrator-worker hierarchical) vs swarm vs hybrid. The kit's `agent-teams.md` has a decision rule but only for "team vs subagent"; this needs the inter-multi-agent-pattern decision — confidence: M
- F-102 production-pattern-validity-rank — Catalog ranks patterns by 2026 production-validity: hierarchical = HIGH, graph = HIGH, orchestrator-worker = HIGH, pipeline = MEDIUM, swarm = LOW, blackboard = LOW. Skills using LOW-validity patterns require explicit justification — confidence: H
- F-103 policy-driven-runtime-aspiration — Document policy-driven runtime as an aspirational direction (vs the kit's current rule-driven discipline). Track AOS evolution (2026/2027) for adoption signals — confidence: L
- F-104 single-agent-anti-pattern-flag — Add anti-pattern: "use a single super-agent for non-trivial tasks." Multi-agent default per 2026 industry convergence — confidence: M

## Confidence

MEDIUM — emerging patterns by definition have less validation; the production-validity ranking (F-102) is HIGH-confidence (cited consistently across sources); AOS framing is LOW-confidence (forecast/aspirational). Composite MEDIUM. Wave-1 already covered most HIGH-confidence patterns; this wave-2 doc captures the gaps and aspirational frontier.
