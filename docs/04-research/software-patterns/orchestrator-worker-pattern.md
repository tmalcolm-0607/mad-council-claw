---
artifact-class: research-finding
source-tag: [R:software-patterns]
confidence: high
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://www.anthropic.com/research/building-effective-agents
  - https://mlpills.substack.com/p/diy-17-orchestrator-worker-llm-agent
  - https://beam.ai/agentic-insights/multi-agent-orchestration-patterns-production
  - https://aimultiple.com/llm-orchestration
  - https://gurusup.com/blog/multi-agent-orchestration-guide
  - https://gurusup.com/blog/agent-orchestration-patterns
  - https://www.heyuan110.com/posts/ai/2026-02-26-multi-agent-orchestration/
---

# Orchestrator-worker pattern (canonical primary + specialists + aggregator)

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter. Cross-references wave-1 Lane A finding F-010 (Anthropic Multi-Agent Research System).

## Load-bearing patterns

- **Orchestrator-Worker is the dominant production-deployed multi-agent pattern in 2026**. Across Anthropic (Claude Code), OpenAI (Codex / Operator), Microsoft (Magentic / AutoGen), Google (Antigravity), and Kimi Agent Swarm — all converge on a single orchestrator + N specialist workers + aggregator step. Other patterns (mesh, swarm, blackboard) exist academically but rarely outperform in production.
- **The five sub-decisions of orchestration**:
  1. **When to spawn**: trigger condition (task complexity threshold, declared parallelism, user request)
  2. **Whom to delegate to**: specialist selection (skill-match, capability-score, cost-tier)
  3. **How to communicate**: brief format (structured task description, scoped context, output contract)
  4. **How to aggregate**: synthesis step (merge, vote, weighted-by-confidence, cross-check)
  5. **When to stop**: termination criterion (all-converged, time-budget, quality-floor met)
  Mature engines surface all five as configurable; immature engines hard-code 4 of 5 and only expose "when to spawn".
- **Workers don't talk to each other. All coordination flows through the orchestrator.** This is the structural property that distinguishes orchestrator-worker from mesh. It buys: predictability, debuggability, single audit trail, simpler failure recovery. It costs: orchestrator becomes the bottleneck for high-throughput scenarios.
- **Each worker can use different model/tools/prompts**. The pattern is not "fan out the same prompt N times" — it's "fan out N different specializations, each potentially on a different model tier with a different toolset." This is what makes orchestrator-worker compatible with multi-tier model routing (orchestrator on Opus, workers on Sonnet, aggregator on Sonnet).
- **The aggregator is a first-class step, not an afterthought**. Workers' raw outputs are rarely directly consumable. The aggregator (a) deduplicates, (b) reconciles disagreements, (c) cross-validates evidence, (d) produces the orchestrator's final synthesis. Skipping the aggregator is the most common production failure mode for orchestrator-worker (workers' outputs leak directly into final response).
- **Anthropic's framing**: "Suited for complex tasks where you can't predict the subtasks needed (in coding, the number of files that need to be changed and the nature of the change in each file likely depend on the task)." This distinguishes orchestrator-worker from Routing (which has predefined classification → predefined handler).
- **Plan-and-Execute variant**: capable model creates a strategy → cheaper models execute. Reduces costs by up to 90% vs frontier-everywhere. The kit's `agent-teams.md` "lead Opus + teammates Sonnet" pattern is exactly this.

## Verbatim quotes worth preserving

> "Workers don't communicate with each other, all coordination flows through the orchestrator."

> "This workflow is well-suited for complex tasks where you can't predict the subtasks needed."

> "Orchestration learning decomposes into five sub-decisions (when to spawn, whom to delegate to, how to communicate, how to aggregate, when to stop)."

## Implications for the engine catalog

The kit's `agent-teams.md` already prescribes the orchestrator-worker shape (lead + 3-4 teammates) and Plan-and-Execute (lead Opus, teammates Sonnet). Gaps versus 2026 best practice: (a) the aggregator step is implicit ("orchestrator integrates the agreement table") rather than a first-class skill or rule, (b) the five sub-decisions are not separately surfaced — most live in implicit conventions, (c) no telemetry distinguishing orchestrator-side vs worker-side cost/latency, (d) no formal contract for the worker brief (each invocation reinvents the prompt format).

## NEW F-NNN candidates

- F-084 aggregator-as-first-class-step — Engine treats the aggregation step as a named skill phase (not implicit synthesis); aggregator skills declare merge strategy (vote, dedupe, cross-validate, weighted) and are auditable independently — confidence: H
- F-085 orchestration-five-decisions-config — Engine surfaces the 5 sub-decisions (spawn / delegate / communicate / aggregate / stop) as named configuration knobs per orchestrator skill, instead of hard-coding 4 of 5 — confidence: M
- F-086 worker-brief-contract — Standardized brief shape for worker invocations: scoped context (path), output contract, termination criterion, cost budget. Skills that spawn workers MUST emit briefs in this shape — confidence: H
- F-087 plan-and-execute-explicit-mode — Make Plan-and-Execute (capable-model planner + cheap-model executors) a declared skill mode with a `--plan-and-execute` flag and built-in cost tracking. Document the 90% cost-reduction claim with telemetry confirmation — confidence: M
- F-088 orchestration-bottleneck-telemetry — Default telemetry distinguishes orchestrator-side from worker-side wall-clock + token cost so the operator can see if the orchestrator is becoming the bottleneck (vs workers being underused or overused) — confidence: M

## Confidence

HIGH — orchestrator-worker is THE most-validated 2026 multi-agent pattern (cited across Anthropic + Microsoft + OpenAI + Google production deployments). The five-sub-decisions framing is more recent (May 2026) but already cited across multiple production-evidence sources.
