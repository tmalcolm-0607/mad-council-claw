# Implementation: LangGraph

**What it is:** LangChain's state-machine-based orchestration framework. Treats agent workflows as explicit graphs: nodes are functions, edges are transitions, state is immutable and checkpointed. Python-first with a TypeScript variant.

**Role in MAD.Council:** Reference implementation for the plan-execute-replan pattern. MAD.Council doesn't use LangGraph directly — the spec explicitly rejects SQLite-backed state (§2) — but LangGraph's explicit-state-machine modeling is where our MAD phase gates (§4.5) draw structural inspiration.

**Last verified:** 2026-04-17.

## Core primitives

### The Graph

```
┌──────┐      ┌──────────┐      ┌─────────┐
│START │─────►│  Planner │─────►│Executor │─────┐
└──────┘      └──────────┘      └────┬────┘     │
                    ▲                │           │
                    │                ▼           │
                    │          ┌──────────┐      │
                    └──────────│ Replanner│◄─────┘
                               └────┬─────┘
                                    ▼
                                ┌──────┐
                                │ END  │
                                └──────┘
```

Nodes are functions: `(state) -> state`. Edges can be static or conditional.

### State

Immutable, checkpointed after every step. Defined as a typed schema (Pydantic for Python). Reducers merge updates from parallel branches.

```python
class AgentState(TypedDict):
    messages: Annotated[list, add_messages]
    plan: list[str]
    past_steps: list[tuple[str, str]]
    response: str
```

### Checkpointers

Persist state to durable storage:

| Backend | Durability | Use case |
|---|---|---|
| `MemorySaver` | In-process | Dev / testing |
| **`SqliteSaver`** | Local file, survives restart | **Local dev with durability; recommended for single-machine** |
| `PostgresSaver` | Production database | Multi-machine, scale-out |

**Thread-id resumption**: every invocation uses a `thread_id`. On failure, resuming with the same thread_id picks up from the last successful checkpoint. Agents can run for hours, survive deploys, resume exactly.

### Supervisor pattern

Multiple specialized agents as separate graphs, coordinated via a supervisor node that routes between them.

```python
supervisor_agent = create_supervisor(
    agents=[coder_agent, researcher_agent, reviewer_agent],
    model=llm,
    prompt="You are a supervisor; route the task to the right agent."
)
```

### Plan-Execute-Replan

Canonical LangGraph pattern (see https://blog.langchain.com/planning-agents/):

1. **Plan** — LLM produces a structured checklist.
2. **Execute** — run one step at a time, accumulating results.
3. **Replan** — based on past_steps, refine remaining plan OR produce final response.

Benefits over ReAct-style agents: fewer round-trips; sub-tasks execute without re-consulting the planner on each step.

## Pros

- **Explicit state machine.** The graph is the program. You can see every transition, every node's responsibility.
- **Checkpoint-based durability.** `SqliteSaver` gives you crash recovery + pause/resume for free.
- **Thread-id resumption** — an interrupted invocation can be resumed exactly, not restarted.
- **Reducer-based state merging** — parallel branches' updates combine deterministically.
- **Graph visualization.** The graph shape can be rendered; helps debugging and onboarding.
- **Human-in-the-loop interrupt()** — pause the graph at any node for human input, resume after.
- **Plan-Execute beats ReAct** for multi-step tasks — measured in blog post + several production reports.
- **Framework-level retry & timeout primitives** — don't need to implement from scratch.
- **Conditional edges** enable dynamic routing without embedding it in node logic.

## Cons

- **Learning curve.** State-graph modeling is unfamiliar if you're used to linear chains. Expect 1–2 weeks to ramp.
- **Debugging multi-node flows is harder** than debugging a linear agent. The state flows through multiple nodes; tracing requires graph-aware tooling (LangSmith).
- **Lock-in to LangChain ecosystem.** Graphs are LangGraph-native; moving to a different framework means rewriting.
- **Python-first.** TypeScript support exists but lags in features/docs.
- **SQLite backend is local-only.** For cross-machine durable state, need Postgres. MAD.Council's file-based model avoids this tier entirely.
- **Graph drift.** As a graph grows, nodes accumulate responsibilities; cleaning up is a refactoring effort.
- **State schema evolution** — changing the TypedDict requires migration logic for existing checkpoints.

## Do / Don't

**Do**:

- **Model real state machines as graphs.** If your workflow has clear node-transition structure, LangGraph is a good fit.
- **Use `SqliteSaver` for local dev** — durable, zero-infra.
- **Use `PostgresSaver` for production** if you need cross-machine or scale-out.
- **Write explicit state schemas** with Pydantic. Leaving state as dict-of-anything loses the framework's benefit.
- **Use reducers for parallel updates** — `Annotated[list, add_messages]` is the canonical pattern.
- **Add `thread_id` on every invocation.** Without it, checkpointing is meaningless.
- **Add conditional edges** where routing varies; avoid embedding routing logic inside nodes.
- **Use `interrupt()` for human-in-the-loop** checkpoints.
- **Use the supervisor pattern** for multi-agent coordination inside a graph.
- **Render graphs during development** — visualization catches structural bugs fast.

**Don't**:

- **Don't use LangGraph for trivial linear workflows.** A chain is simpler.
- **Don't skip the state schema** — `TypedDict = dict` loses all benefits.
- **Don't put unrelated responsibilities in one node.** Each node should have a single clear action.
- **Don't rely on side effects inside nodes** that aren't reflected in state. Reducers won't know to merge them.
- **Don't change state schema without a migration plan** for existing checkpoints.
- **Don't use `MemorySaver` in production** — it's lost on restart.
- **Don't cross the SQLite → PostgresSaver boundary casually.** It's a deploy-model decision, not a config swap.
- **Don't assume `thread_id` isolates state.** It does for checkpoints, but shared side effects (API calls, file writes) are not isolated.

## Common pitfalls

### Forgetting thread_id

Call `app.invoke({"messages": [...]})` without a thread_id → no checkpointing happens. The workflow runs but on failure loses everything. Always specify `config={"configurable": {"thread_id": "..."}}`.

### Reducer conflicts

Two parallel branches update the same state field without a reducer → last-write-wins → silent data loss. Mitigation: always annotate mergeable fields with `Annotated[..., reducer_func]`.

### Node-explosion

A graph with 50+ nodes is a sign of too-fine-grained decomposition. Aim for nodes that do one clear thing with 10–30 lines of logic.

### State-schema creep

Adding fields to `AgentState` every time a node needs data. Pro tip: pass transient data via function args, not state. State should only hold things that persist across node boundaries.

### SQLite database corruption

`SqliteSaver` stores checkpoints in a single file. Concurrent writes from multiple processes risk corruption. Use Postgres when concurrency is a concern; use SQLite only for single-process dev.

## How MAD.Council relates

**Explicit non-use.** MAD.Council's spec (§2 Non-Goals) rejects SQLite-backed state specifically to preserve the filesystem-trust model. The tradeoff:

| MAD.Council (file-based) | LangGraph (state-machine + SqliteSaver) |
|---|---|
| Debug with `cat` + `ls` | Debug with LangSmith / graph viz |
| No Python dependency | Requires Python + LangGraph install |
| State is just files | State is SQLite rows |
| Cross-agent interop via A2A + files | Cross-agent interop via graph nodes (single-runtime) |
| Crashes mid-write: atomic rename pattern | Crashes mid-write: checkpoint saves you |
| Concurrency via atomic rename | Concurrency via reducers |
| Distributed via A2A bridges | Distributed via PostgresSaver |

LangGraph's **Plan-Execute-Replan** pattern maps loosely to MAD's spec → plan → tasks → verify gates, but the mechanism is different: LangGraph drives the flow through node transitions; MAD's gates are file-presence checks + schema validation.

If you're coming from LangGraph:

- Our `spec.md` + `plan.md` + `tasks.md` approximate the plan-execute-replan artifacts.
- Our `/council-post --type task` is an "execute" step.
- Our `/council-review` is a "replan" (given findings, decide next).
- Our `verdict.json` is the closest thing to a state field (but without LangGraph's reducer machinery).

## Implementation-specific mapping

| LangGraph | MAD.Council equivalent | Notes |
|---|---|---|
| `StateGraph(AgentState)` | channel structure + thread state | Our state is directory + files |
| Node function | Skill invocation | Skills are node-sized |
| Edge / conditional_edge | MAD gate (spec → plan → tasks) | Our edges are gate checks |
| `SqliteSaver` | File-based state | Our durability is filesystem |
| `thread_id` | run_id | Similar correlation role |
| `interrupt()` | `dangerous-operations-policy.md` consent gate | Both pause for human |
| Supervisor agent | Orchestrator identity | Same pattern, different host |
| Plan-Execute-Replan | mad-plan → mad-tasks → mad-review → mad-plan | Loose analog |

## References

- **LangGraph (main)** — https://www.langchain.com/langgraph
- **LangGraph GitHub** — https://github.com/langchain-ai/langgraph
- **Plan-and-Execute Agents blog** — https://blog.langchain.com/planning-agents/
- **Multi-Agent Workflows** — https://blog.langchain.com/langgraph-multi-agent-workflows/
- **Building LangGraph (first principles)** — https://blog.langchain.com/building-langgraph/
- **TypeScript Persistence Guide** — https://langgraphjs.guide/persistence/
- **Human-in-the-loop** — https://docs.langchain.com/oss/python/langchain/human-in-the-loop
- Full link list in `wiki/references.md` §4.

## Related wiki entries

- `wiki/patterns/orchestrator-worker.md` §LangGraph section — pattern detail.
- `wiki/implementations/autogen.md` — contrast: state-machine vs group-chat.
- `wiki/implementations/a2a.md` — how LangGraph agents expose A2A endpoints.
- `wiki/anti-patterns.md` — overlapping pitfalls.
- CHK-028 in `_review-checklist.md` — tracks the SQLite non-use decision.
