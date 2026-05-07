---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/agent-framework/workflows/orchestrations/
  - https://learn.microsoft.com/agent-framework/workflows/orchestrations/group-chat
  - https://learn.microsoft.com/dotnet/ai/conceptual/agents
  - https://learn.microsoft.com/azure/architecture/ai-ml/guide/ai-agent-design-patterns
  - https://learn.microsoft.com/agent-framework/workflows/
  - https://learn.microsoft.com/agent-framework/migration-guide/from-autogen/
  - https://learn.microsoft.com/agent-framework/workflows/as-agents
---

# Microsoft Agent Framework workflows + 5 orchestration patterns

## Sources

- Workflow orchestrations index — `learn.microsoft.com/agent-framework/workflows/orchestrations/`
- Group Chat (csharp + python) — `.../orchestrations/group-chat`
- AI agent orchestration patterns (Azure architecture) — `learn.microsoft.com/azure/architecture/ai-ml/guide/ai-agent-design-patterns`
- Workflows overview — `learn.microsoft.com/agent-framework/workflows/`
- AutoGen → Agent Framework migration — `learn.microsoft.com/agent-framework/migration-guide/from-autogen/`
- Workflows-as-agents — `learn.microsoft.com/agent-framework/workflows/as-agents`
- .NET conceptual agents — `learn.microsoft.com/dotnet/ai/conceptual/agents`

## Load-bearing patterns

### The 5 canonical orchestration patterns (technology-agnostic; Microsoft Agent Framework provides built-in implementations)

| Pattern | Shape | When to use |
|---|---|---|
| **Sequential** | A → B → C → output | Dependent steps, pipelined refinement (researcher → writer → reviewer) |
| **Concurrent** | A, B, C in parallel → aggregate → output | Independent sub-tasks, latency reduction, multi-perspective fan-out |
| **Handoff** | A decides → B or A; B decides → C or B | Routing to specialists by intent; "swarm-style" delegation |
| **Group Chat** | Round-robin / selector across N agents in shared conversation | Iterative refinement, debate, content creation, multi-perspective review |
| **Magentic** | Lead manager-agent dynamically coordinates specialists | Complex dynamic planning where the right next step isn't pre-determined |

**Source quote (workflow-orchestrations index):** "Orchestrations support **human-in-the-loop** interactions through tool approval and request info. Agents can use approval-required tools that pause the workflow for human review before execution."

### Workflow vs Agent (the conceptual split)

- **Agent** — LLM-driven, dynamic step selection based on tools available. Steps are emergent.
- **Workflow** — Predefined sequence of operations. Includes agents as components. Flow is explicitly defined; control over execution path.

Verbatim from `workflows/`: "While an agent and a workflow can involve multiple steps to achieve a goal, they serve different purposes and operate at different levels of abstraction."

### Group Chat — context synchronization mechanism (load-bearing for our --council mode)

Verbatim from `orchestrations/group-chat`:

> "Agents in Agent Framework relies on agent sessions (`AgentSession`) to manage context. In a group chat orchestration, agents **do not** share the same session instance, but the orchestrator ensures that each agent's session is synchronized with the complete conversation history before each turn. To achieve this, after each agent's turn, the orchestrator broadcasts the response to all other agents, making sure all participants have the latest context for their next turn."
>
> "Agents do not share the same session instance because different agent types may have different implementations of the `AgentSession` abstraction. Sharing the same session instance could lead to inconsistencies in how each agent processes and maintains context."

**Implication for MAD.Council:** our existing Advocate/Skeptic/Architect council is structurally identical to AF Group Chat. Per-agent sessions + orchestrator-driven broadcast = our session-id binding + atomic message append model.

### Workflows-as-agents (composition primitive)

Per `workflows/as-agents`: a workflow can be wrapped to look like a regular agent. Other agents can call it as a tool, A2A clients can invoke it over HTTP, and consumers don't need to know they're talking to a workflow at all.

**This is the critical primitive for our hybrid Electron+headless engine** — it means the engine can expose any internal multi-agent process as a single A2A endpoint without leaking the internal topology.

### Key Workflow features (verbatim from the workflows page)

1. **Type Safety** — strong typing ensures messages flow correctly between components
2. **Flexible Control Flow** — graph-based with `executors` and `edges`; conditional routing, parallel processing, dynamic execution paths
3. **External Integration** — built-in request/response patterns for external APIs + HITL
4. **Checkpointing** — save workflow state for recovery and resumption
5. **Multi-Agent Orchestration** — built-in patterns for sequential / concurrent / hand-off / magentic

### Magentic customization (deep)

Per AutoGen migration guide:
- **Manager configuration** — Agent with custom instructions and model settings
- **Round limits** — `max_round_count`, `max_stall_count`, `max_reset_count`
- **Event streaming** — output events with `AgentResponseUpdate` data
- **Agent specialization** — custom instructions and tools per agent
- **Human-in-the-loop** — plan review, tool approval, stall intervention

### Future patterns on the AF roadmap (per AutoGen migration guide)

- **Swarm pattern** — handoff-based agent coordination (currently in development)
- **SelectorGroupChat** — LLM-driven speaker selection (currently in development)

### Foundry Agent Service connected agents (the no-code variant)

Per Azure architecture guide: "Foundry Agent Service provides a managed, no-code approach to chaining agents together by using its connected agents functionality. The workflows in this service are primarily nondeterministic, which limits which patterns you can fully implement. Use Foundry Agent Service when you need a managed environment and your orchestration requirements are straightforward."

**Implication:** for our engine we want the SDK-level Agent Framework workflows (full control), not Foundry connected agents (managed but constrained).

## Verbatim quotes worth preserving

> "These orchestrations handle the boilerplate of agent coordination so you can focus on the agents themselves." — workflows/journey

> "One of the most powerful composition patterns is wrapping a workflow so it looks like a regular agent." — workflows/as-agents

> "AutoGen's `Team` abstraction runs continuously once started and doesn't provide built-in mechanisms to pause execution for human input. Any human-in-the-loop functionality requires custom implementations outside the framework." — AutoGen migration

> "A key new feature in Agent Framework's `Workflow` is the concept of **request and response**, which allows workflows to pause execution and wait for external input before continuing." — AutoGen migration

## Implications for the engine catalog (refs F-NNN)

- **F-multi-model-adversarial-review (--council mode)** — directly maps to AF Group Chat. Use `GroupChatBuilder` with Advocate/Skeptic/Architect; orchestrator broadcasts each turn. Our existing kit's 3-role pattern is the right shape; AF gives us a typed, durable runtime.
- **F-orchestration-pattern-library** — vendor all 5 patterns as first-class engine primitives (not just Group Chat). `Sequential` for spec→plan→tasks; `Concurrent` for fan-out research; `Handoff` for clawpilot Skills routing; `Magentic` for auto-pace loops; `Group Chat` for council.
- **F-workflows-as-agents (composition)** — every named engine workflow exposed as a callable agent for A2A inbound. This is what makes our engine pluggable into the broader Microsoft ecosystem (Agent 365 can call us; Copilot Studio can connect to us; etc.).
- **F-checkpointing** — adopt AF checkpointing primitive for our long-running loops. Per `mad-iteration` profile (270s wakeups), checkpoints across cron firings prevent state loss.
- **F-HITL-request-response** — engine's "human-in-the-loop" surface (consent gates, approval prompts) should use AF's `request_info()` + `@response_handler` shape rather than reinvent.

## NEW F-NNN candidates (if any)

- **F-NEW: workflow-as-A2A-endpoint** — every named engine workflow auto-exposes an `/.well-known/agent.json` agent card. Internal topology is private; external surface is one A2A endpoint per workflow. (Combines AF workflows-as-agents + A2A hosting.)
- **F-NEW: orchestration-pattern-selector** — engine ships a pattern-decision helper: given a task description, recommend Sequential / Concurrent / Handoff / Group Chat / Magentic. Cuts cognitive load for engine consumers.
- **F-NEW: checkpoint-resume-protocol** — concrete contract for resuming workflows across our cron-driven loop wakeups (matches our `mad-iteration` cadence in `loop-cadence-discipline.md`).

## Confidence

**HIGH** — all patterns sourced from current Microsoft Learn docs (April-May 2026 indexed). Cross-referenced across Workflows index, Group Chat deep-dive, .NET conceptual agents, Azure architecture pattern guide, and AutoGen migration guide. Five named patterns appear consistently across all sources. Workflows-as-agents is documented as a first-class composition primitive. The only "preview" caveat is that **Swarm** and **SelectorGroupChat** are roadmap items — already on the AF roadmap per the migration guide.
