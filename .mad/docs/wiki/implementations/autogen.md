# Implementation: AutoGen → Microsoft Agent Framework

**What it is:** Microsoft's multi-agent framework. Originally released as AutoGen; being unified into the broader **Microsoft Agent Framework** as of 2025–2026. Both support group-chat-style multi-agent coordination with structured termination conditions.

**Role in MAD.Council:** Reference implementation for the group-chat / selector pattern. MAD.Council doesn't use AutoGen directly — our coordination primitive is file-based channels — but the patterns (round-robin, selector, termination) are canonical and the Council layer draws structurally from GroupChat.

**Last verified:** 2026-04-17.

## Core primitives

### GroupChatManager (the orchestrator)

A coordinator that selects the next speaker from a set of participants. Knows the conversation state, applies a selection algorithm, and enforces termination.

```
User message
      ↓
┌──────────────────┐
│ GroupChatManager │ ← selects next speaker each turn
└─────┬────────────┘
      ↓ (broadcasts)
  [Agent A] [Agent B] [Agent C] ... all see every message
```

### Speaker-selection algorithms

| Algorithm | What it does | Use case |
|---|---|---|
| **RoundRobinGroupChat** | Fixed order; cycles through participants | Predictable turn-taking; debugging clarity |
| **SelectorGroupChat** | LLM chooses next speaker based on conversation state | Dynamic flows; expert routing |
| **SwarmGroupChat** | Handoff-based; current speaker names next | Explicit hand-off workflows |
| **Manual** | User picks the next speaker | Interactive orchestration |

### Termination conditions

**Required** — absence = infinite loop. Common conditions:

- `TextMentionTermination("APPROVE")` — stop when someone says "APPROVE"
- `MaxMessageTermination(20)` — hard cap on turns
- Combined with `|` (OR) or `&` (AND) logic

### Teams → Workflows

Microsoft Agent Framework generalizes: a "team" is one pattern; "workflows" express more complex graphs (DAG-style). Migration guide bridges AutoGen `team` → Agent Framework `workflow`.

## Pros

- **Explicit message protocol.** Every participant sees every message in order. No hidden back-channels.
- **Typed messaging.** Messages have concrete types (TextMessage, ToolCallMessage, etc.), not free-form prose. Parseable by downstream consumers.
- **Mandatory termination.** The framework won't let you start a GroupChat without a termination condition — prevents the common "forgot to stop" bug.
- **Multiple speaker algorithms.** Can swap RoundRobin ↔ Selector ↔ Swarm without rewriting agent logic.
- **Well-documented migration path** from AutoGen to Microsoft Agent Framework — existing investment preserved.
- **Production-grade persistence** (MAF Workflows): durable state, human-in-the-loop gates, pause/resume.

## Cons

- **GroupChat broadcasts to all.** Noisy when only 2 of 10 agents care about a message. No per-message recipient targeting.
- **Verbose default prompts.** AutoGen agents include substantial boilerplate — token-costly if not trimmed.
- **Single-speaker-at-a-time.** Parallelism is limited; you can nest teams but within one chat only one speaker talks.
- **Framework lock-in.** Your coordination lives in Python code, not as portable skill files. Hard to move to another runtime.
- **Learning curve.** The AutoGen v0.2 → v0.4 → Microsoft Agent Framework naming + API churn has been substantial. Docs lag reality on occasion.
- **Selector LLM round-trips** cost tokens for every turn. Offload to simpler selectors when possible.

## Do / Don't

**Do**:

- **Always declare a termination condition.** If you're about to create a GroupChat without one, stop.
- **Use RoundRobin for 2–5 agents** with predictable flow. It's the cheapest.
- **Use Selector for 3+ experts** where routing depends on content.
- **Use Swarm for explicit handoff workflows** (A completes → hands off to B explicitly).
- **Set `max_turns` as a safety cap** even when you have a text-mention termination — belt and suspenders.
- **Nest teams for large fleets.** 10 agents in one GroupChat is noisy; 3 teams of 3 is cleaner.
- **Prefer Microsoft Agent Framework for new projects.** The migration guide from AutoGen is Microsoft-maintained; AutoGen itself is in maintenance mode.
- **Strip boilerplate** from agent system prompts. Default descriptions are verbose; tune for your tokens.
- **Separate orchestrator from workers.** Don't give the GroupChatManager domain responsibilities; matches `rules/orchestrator-identity.md`.

**Don't**:

- **Don't launch GroupChat without termination.** Silent infinite loops are the #1 AutoGen bug.
- **Don't use GroupChat for 10+ agents.** Split into teams.
- **Don't rely on speaker-selector LLM for simple routing.** If a rule-based selector works (round-robin / swarm), use it.
- **Don't mix termination conditions carelessly.** `&` and `|` can produce surprising combinations. Test.
- **Don't conflate AutoGen v0.2 (legacy) with v0.4+.** APIs changed significantly.
- **Don't assume broadcast is free.** Every broadcast is N token-contexts worth of ingest.

## Common pitfalls

### Infinite GroupChat loops

Missing termination → GroupChat runs until token budget exhausted. Always declare at least one termination condition. `MaxMessageTermination` as a fallback is cheap insurance.

### Selector LLM cost

An LLM-based selector consumes tokens on every turn for the selection decision alone. For a 50-turn chat, that's 50 selector calls on top of 50 participant calls. Rule-based selectors (RoundRobin, Swarm) avoid the extra cost.

### Role collapse in long chats

In a long GroupChat, all participants gradually converge on similar responses (they've all seen the same history). Mitigations: reset per-participant contexts periodically; use Selector to filter "who cares about this message"; prefer smaller focused teams.

### AutoGen v0.2 → v0.4 migration footguns

`autogen_agentchat.teams` (v0.4) is not a drop-in for `autogen.agentchat.groupchat` (v0.2). Migration is non-trivial; Microsoft's migration guide is the canonical reference. New projects: start on Microsoft Agent Framework.

## How MAD.Council relates

**Pattern borrowing, not implementation dependency.** MAD.Council's Council layer is structurally similar to a 3-agent SelectorGroupChat where the "selector" is our deterministic aggregate-and-verdict step. Specifically:

| AutoGen / MAF concept | MAD.Council analog |
|---|---|
| GroupChatManager | `/council-review` driver |
| Round-robin selector | 3 roles run in parallel (not round-robin, but same "every participant contributes" shape) |
| Termination condition | Verdict emission (= implicit termination) |
| Broadcast | Message-by-message visibility in a thread |
| Typed messages | Our `type: task|question|answer|status|fyi|resolve` field |
| Workflows (DAG) | MAD phase gates (§4.5) |
| Durable state | Filesystem state (channel.json + messages/) |

MAD.Council **does not** use the GroupChat runtime; it re-implements the pattern on top of file primitives. Pros: portable, no Python dependency, debuggable by `cat`. Cons: no framework-level guarantees, no Python SDK reuse.

## Implementation-specific mapping

If you're moving a workflow from AutoGen to MAD.Council, this table helps:

| AutoGen/MAF | MAD.Council equivalent | Notes |
|---|---|---|
| `RoundRobinGroupChat([A, B, C])` | Channel with 3 members; `/council-post` visible to all | Turn-taking is explicit via who posts when |
| `SelectorGroupChat(selector_func)` | `/council-review` with role-based parallel fan-out | Different shape; Council does full parallel, not serial |
| `TextMentionTermination("APPROVE")` | `/council-resolve` or `type: resolve` message | Explicit resolve |
| `MaxMessageTermination(20)` | Max-100-messages-per-thread nudge (§7.4) | Soft nudge, not hard stop |
| Typed messages (TextMessage, etc.) | Message `type` field | Simpler discriminator |
| `on_messages()` callback | `/council-check` polling | Pull model, not push |

## References

- **AutoGen stable** — https://microsoft.github.io/autogen/stable/
- **AutoGen design patterns** — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/
- **Group Chat tutorial** — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/group-chat.html
- **Selector Group Chat** — https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/selector-group-chat.html
- **AutoGen → Microsoft Agent Framework migration** — https://learn.microsoft.com/en-us/agent-framework/migration-guide/from-autogen/
- **Microsoft Agent Framework Orchestrations — Group Chat** — https://learn.microsoft.com/en-us/agent-framework/user-guide/workflows/orchestrations/group-chat
- **Mixture of Agents pattern** — https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/mixture-of-agents.html
- Full link list in `wiki/references.md` §3.

## Related wiki entries

- `wiki/patterns/multi-role-review.md` — the pattern our Council layer implements, drawing structurally from GroupChat.
- `wiki/patterns/orchestrator-worker.md` §AutoGen section.
- `wiki/implementations/langgraph.md` — compare-and-contrast on state-machine vs GroupChat modeling.
- `wiki/implementations/anthropic-claude-code.md` — our actual runtime; contrasts framework vs native Task.
- `wiki/anti-patterns.md` §GroupChat without termination.
