---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://openai.github.io/openai-agents-python/handoffs/
  - https://openai.github.io/openai-agents-python/
  - https://developers.openai.com/api/docs/guides/agents/orchestration
  - https://openai.com/index/the-next-evolution-of-the-agents-sdk/
---

# OpenAI — Agents SDK + Handoff Abstractions

## Source
- https://openai.github.io/openai-agents-python/handoffs/
- https://openai.github.io/openai-agents-python/
- https://developers.openai.com/api/docs/guides/agents/orchestration
- https://openai.com/index/the-next-evolution-of-the-agents-sdk/
- (fetched 2026-05-07 via WebSearch)

## Load-bearing patterns

- **Handoff as a first-class abstraction**: Handoffs are represented to the LLM as tools — the agent sees `transfer_to_<agent_name>` and chooses to invoke it just like any other tool call. NOT a separate primitive.
- **Per-agent handoffs param**: Every Agent has a `handoffs` parameter that takes either an Agent directly OR a Handoff object that customizes behavior. Composable.
- **Customization via handoff() function**: `tool_name_override`, `tool_description_override`, `on_handoff` callback, `input_filters` for context shaping.
- **on_handoff callback**: Fires the moment the LLM chooses the handoff — useful for kicking off data fetching speculatively or logging the routing decision.
- **Structured-metadata + filtered-history**: Advanced handoffs carry structured metadata + history filters; specific APIs differ by language SDK (Python vs TS).
- **Handoff-default-tool-name convention**: Defaults to `transfer_to_<agent_name>` — naming convention is part of the discoverability contract.
- **Specialized agents > generalist**: The SDK encourages many narrow agents with explicit handoffs vs one generalist with branching prompts.

## Verbatim quotes worth preserving

> "Handoffs allow an agent to delegate tasks to another agent, which is particularly useful in scenarios where different agents specialize in distinct areas."

> "Handoffs are represented as tools to the LLM."

> (from `agents/orchestration` docs) "All agents have a handoffs param, which can either take an Agent directly, or a Handoff object that customizes the Handoff."

## Implications for the engine catalog

OpenAI's "handoff = tool call" framing is a cleaner mental model than the kit's current "spawn subagent" pattern. The kit could expose Skill / Agent dispatch the same way: every available skill appears as a tool to the orchestrator LLM, the orchestrator picks one, and the dispatch is mechanical. This unifies "Routing" + "Orchestrator-Workers" patterns from Anthropic into a single primitive. The `on_handoff` callback maps to the kit's hooks (PreToolUse:Task) — both fire at the routing decision point. Structured-metadata + filtered-history is the gap: the kit currently dumps full conversation history into subagent prompts; OpenAI's filter pattern would let us bundle context selectively.

## NEW F-NNN candidates

- F-021 handoff-as-tool-pattern — Engine surfaces every available skill / agent as a tool to the orchestrator LLM; orchestrator picks via tool-call, not via hand-rolled dispatch logic — confidence: H
- F-022 handoff-customization — Engine supports per-handoff `on_handoff` callbacks (fire at routing decision) + `input_filter` (bundle scoped context, not full history) — confidence: H
- F-023 structured-handoff-metadata — Handoffs carry typed metadata (intent, expected-output-shape, deadline, max-turns) — improves subagent task decomposition per Anthropic-multi-agent finding — confidence: M
- F-024 specialized-over-generalist — Engine catalog patterns favor many narrow agents with explicit handoffs over one generalist with branching prompts — confidence: H

## Confidence

HIGH — OpenAI's SDK is the second canonical reference (alongside Anthropic's) for production multi-agent design. Handoff-as-tool is widely implemented and validated.
