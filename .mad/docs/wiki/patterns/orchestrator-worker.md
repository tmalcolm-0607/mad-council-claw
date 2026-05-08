# Pattern: Orchestrator-Worker

**Canonical name:** Orchestrator-Worker. Also called *operator pattern*, *lead-agent pattern*, *conductor-orchestra*, *dispatcher-worker*.

**One-line definition:** A central agent (orchestrator) decomposes a goal into subtasks and delegates each to specialized workers; the orchestrator synthesizes worker outputs into the final result.

## When to use

- Task is complex enough that a single model run produces worse results than multiple specialized runs.
- Subtasks are independent or have a known dependency graph (can be executed in parallel or in a fixed order).
- Quality matters more than latency or token cost.
- You need observability — knowing "which subagent produced this finding" is more valuable than a monolithic response.

Anthropic's published multi-agent research system reports **90.2% performance improvement over single-agent baselines** on internal evaluations using this pattern. The gain comes from specialization + parallelism, not from the orchestration alone.

## When NOT to use

- **Simple fact-finding** — Anthropic's own scaling rule: one agent with 3–10 tool calls. Orchestrating this is overhead.
- **Tight latency budgets** — orchestration overhead is 2-5x single-agent latency.
- **Unbounded subtask trees** — without explicit scaling rules, orchestrators spawn too-many subagents and burn context.

## Core mechanics

```
User request
     ↓
┌─────────────┐
│ Orchestrator│   1. Decompose request into subtasks
│             │   2. Assign each subtask to a worker (possibly in parallel)
│             │   3. Wait for results (or stream as they complete)
│             │   4. Synthesize into final output
└─────────────┘
  ↓   ↓   ↓
 W1  W2  W3    ← workers operate concurrently, isolated contexts
```

The orchestrator's job has four parts:

1. **Decompose** — break the goal into well-scoped subtasks. Each subtask needs an objective, output format, definition of done, and tool-usage guidance. "Vague handoffs produce vague results" (Anthropic).
2. **Delegate** — invoke each worker with only the context it needs. Do NOT pass the whole conversation history; pass a clean brief.
3. **Coordinate** — if subtasks have dependencies, sequence them. If independent, fan out in parallel.
4. **Synthesize** — aggregate worker outputs. The orchestrator writes the final response; workers don't write to the user.

## Common implementations

### Anthropic Claude Code (Task tool)

- Orchestrator = main Claude Code session. Workers = sub-agents spawned via Task tool with a specific `subagent_type`.
- **Pros**: native to Claude Code; parallel execution; subagent context is isolated from main.
- **Cons**: subagent output is capped (~32K tokens); long research returns must be chunked by instruction; subagents can't themselves spawn subagents (single-level hierarchy).
- **Do**: give each Task call a clear one-sentence objective + explicit output format + relevant file paths.
- **Don't**: use Task with `run_in_background: true` (confirmed bug: hangs, empty output).
- Reference: `plugins/ai-native-team/agents/fleet-orchestrator.md` (marketplace pattern #1).

### AutoGen (Microsoft, now Microsoft Agent Framework)

- Orchestrator = `GroupChatManager` with a speaker-selector. Workers = agents in the GroupChat.
- **Pros**: explicit message-passing protocol; supports round-robin, auto-select, manual-select selectors; strong typed messaging.
- **Cons**: GroupChat is chatty — messages broadcast to all, not just selected recipient; verbose default prompts.
- **Do**: use GroupChat for 2-5 agents max; use nested teams for larger fleets.
- **Don't**: let the speaker-selector infer turns freely without termination conditions.
- Reference: https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/mixture-of-agents.html

### LangGraph (LangChain)

- Orchestrator = graph supervisor node. Workers = tool nodes or sub-graphs.
- **Pros**: explicit state machine; graph visualization; conditional edges; durable checkpointing via SQLite.
- **Cons**: learning curve for the state-graph model; debugging multi-node flows is harder than linear chains.
- **Do**: model complex flows as graphs with explicit state reducers; use the plan-execute-replan pattern for long tasks.
- **Don't**: try to model trivially-linear tasks as graphs — overhead without benefit.
- Reference: https://blog.langchain.com/planning-agents/ · https://blog.langchain.com/langgraph-multi-agent-workflows/

### Google A2A protocol

- Orchestrator = client agent sending `tasks/send`. Workers = remote agents exposing an A2A endpoint.
- **Pros**: standardized across frameworks (LangGraph/CrewAI/Semantic Kernel/etc. all interoperate); explicit task lifecycle; Agent Cards for capability discovery.
- **Cons**: HTTPS infrastructure; cert management; not designed for local-only single-machine use.
- **Do**: use A2A when cross-toolchain or cross-machine; publish Agent Cards describing each agent's capabilities.
- **Don't**: use A2A for single-machine single-toolchain — the overhead isn't worth it. Use Claude Code Task or an in-process orchestrator instead.
- Reference: https://a2a-protocol.org/latest/specification/ · `plugins/a2a-starship/`

### Marketplace plugins using this pattern

- `plugins/ai-native-team/agents/fleet-orchestrator.md` — canonical 4-stage pipeline (plan → implement → test → review) with circuit breaker.
- `plugins/agent-orchestrator/agents/orchestrator.md` — meta-orchestrator that discovers other agents via YAML frontmatter scoring.
- `plugins/zen-agents/agents/orchestrator.md` — strictest variant: "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF." Orchestrator cannot even call MCP tools.
- `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` — routing orchestrator with explicit "router not remediator" identity.
- `plugins/adversarial-audit/` — specialized: orchestrator fans to prosecutor/defender/judge workers.

## Pros (general)

- **Specialization** — a code-reviewer worker does a better job than a generalist; so does a test-generator. Ensemble of specialists > single generalist.
- **Parallelism** — independent subtasks execute concurrently; latency is `max(workers)` not `sum(workers)`.
- **Isolation** — each worker's context is bounded. One worker's prompt-injection exposure doesn't poison another's context.
- **Observability** — findings are attributed. "Skeptic found X in step 2" is more actionable than "the agent found X."
- **Reviewability** — orchestrator's decomposition is a plan artifact. Reviewers can critique the plan before workers execute.

## Cons (general)

- **Decomposition quality dominates outcomes** — a bad plan means bad results. "Vague handoffs produce vague results" (Anthropic).
- **Overhead** — 2-5x token cost vs single-agent for simple tasks. Only pays off when the task is complex.
- **Coordination bugs** — workers may disagree; orchestrator must resolve. Most failures are coordination failures, not worker failures.
- **Single point of failure** — orchestrator crash = whole task crash. Checkpoint orchestrator state to survive.
- **Effort scaling is explicitly hard** (Anthropic, verbatim) — "agents struggled to judge appropriate resource allocation."

## Do / Don't

**Do**:

- **Bound the workers**: explicit tool-call budgets per worker. Anthropic's rule: simple=3-10 calls, comparison=10-15, complex=>10. See `wiki/patterns/bounded-iteration-caps.md`.
- **Write clear briefs**: objective + output format + definition of done + tool-usage guidance + task boundaries.
- **Delegate, don't supervise**: once a worker is running, the orchestrator doesn't interrupt. Wait for the result.
- **Keep the orchestrator simple**: "ORCHESTRATE ONLY" (zen-agents). The orchestrator is a router, not a do-er.
- **Use separate context per worker**: don't pass the full conversation. Brief cleanly.
- **Synthesize, don't concatenate**: the orchestrator produces a coherent final output, not a list of worker reports.
- **Report progress per stage**: "📋 Stage N/M" output (fleet-orchestrator style) makes debugging sane.
- **Use quality gates between stages**: don't advance past stage K if stage K-1 produced CRITICAL findings.

**Don't**:

- **Don't pass the full conversation to workers** — context bloat and prompt-injection contagion.
- **Don't let the orchestrator do the work itself** — if you're editing a file in the orchestrator, you've abandoned the pattern.
- **Don't chain workers without explicit contracts** — worker-to-worker handoff needs file:line evidence and an output schema.
- **Don't let workers spawn their own workers** — unbounded recursion. Use single-level hierarchy or explicitly-sized nested teams.
- **Don't skip the synthesis step** — raw worker output is not a response. Orchestrator must aggregate.
- **Don't rely on implicit termination** — explicit stop conditions (max iterations, circuit breaker, timeout) required.

## Interaction with other patterns

- **+ `multi-role-review.md`** (Council) — the 3-role review is itself an orchestrator-worker pattern where Advocate/Skeptic/Architect are the workers.
- **+ `run-id-correlation.md`** — the orchestrator generates the run_id; workers inherit it; the final artifact is traceable back to the single invocation.
- **+ `completion-report-protocol.md`** — each worker emits a Completion Report; the orchestrator's synthesis is partly a merge of those reports.
- **+ `circuit-breakers.md`** — when a worker fails N consecutive times, the orchestrator stops delegating to it (zen-agents fleet-orchestrator 3-failure rule).
- **+ `bounded-iteration-caps.md`** — workers have explicit tool-call budgets; orchestrator enforces.

## MAD.Council specifics

- `/council-review` runs orchestrator-worker where the orchestrator is the review driver and the 3 workers are Advocate/Skeptic/Architect.
- `/council-post` is NOT orchestrator-worker — it's a leaf action with no subagents.
- The optional ensemble mode (`mad.council.a2a.md` §5.6) nests another orchestrator-worker inside the Skeptic role (3-model consensus).
- A2A bridge is a transport primitive, not orchestration — but `a2a-starship`'s Ship Bridge acts as orchestrator-like when routing tasks across machines.

## References

- Anthropic — "Building Effective Agents" — https://www.anthropic.com/research/building-effective-agents
- Anthropic — "How we built our multi-agent research system" — https://www.anthropic.com/engineering/multi-agent-research-system
- Anthropic claude-cookbooks — `patterns/agents/orchestrator_workers.ipynb`
- AutoGen design patterns — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/
- LangGraph multi-agent workflows — https://blog.langchain.com/langgraph-multi-agent-workflows/
- Marketplace CHECKLIST patterns #1 (spec-first), #29 (orchestrator-only identity), #30 (anti-SDLC-bloat) — `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md`
