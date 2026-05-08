# Implementation: Google A2A Protocol

**What it is:** Agent2Agent (A2A) — an open protocol by Google (announced April 2025, Linux Foundation, Apache 2.0, 50+ partners) for communication between agents built on different frameworks. JSON-RPC 2.0 over HTTPS, Agent Cards for capability discovery, support for sync / SSE streaming / async push.

**Role in MAD.Council:** The interop protocol. When MAD.Council's A2A Layer (§6) is enabled, channel members publish A2A-compatible Agent Cards and can bridge to external A2A agents (LangGraph, CrewAI, Semantic Kernel, Copilot CLI) via a Ship Bridge. The marketplace plugin `a2a-starship` is the canonical bridge implementation.

**Last verified:** 2026-04-17. Current spec version: 0.3+ (latest at https://a2a-protocol.org/latest/specification/).

## Core primitives

### Agent Card

JSON capability advertisement, typically served at `/.well-known/agent-card.json` (newer) or `/.well-known/agent.json` (legacy). Every A2A-compliant agent publishes one.

```json
{
  "name": "ES Orchestrator",
  "description": "Coordinates ES training runs across seed sets",
  "url": "https://trainer.example.com/a2a",
  "version": "1.0.0",
  "defaultInputModes": ["text"],
  "defaultOutputModes": ["text"],
  "capabilities": {
    "streaming": true,
    "pushNotifications": true
  },
  "skills": [
    {
      "id": "train-seed",
      "name": "Train seed",
      "description": "Train an ES seed with given config",
      "tags": ["ml", "training"],
      "examples": ["train seed 7 with v4_aligned config"]
    }
  ],
  "authentication": {
    "schemes": ["bearer"]
  }
}
```

### Transport

**JSON-RPC 2.0 over HTTP(S).** Three interaction modes:

1. **Synchronous request/response** — `tasks/send` → returns a Task object.
2. **SSE streaming** — long-running tasks stream events via Server-Sent Events.
3. **Async push** — remote agent POSTs to a caller-provided webhook URL when task completes.

### Task lifecycle

A2A defines a `Task` object with lifecycle states:

```
submitted → in_progress → (completed | failed | canceled)
                        ↓
                 input_required ← (client responds) → in_progress
```

Maps onto MAD.Council thread states (§6.3): submitted→active, in_progress→status-messages, input_required→open-question, completed→resolved-accept, failed→resolved-escalate, canceled→archived-early.

### Agent Executor (Python SDK)

Core server-side primitive. You implement `a2a.server.agent_execution.AgentExecutor`:

```python
from a2a.server.agent_execution import AgentExecutor
from a2a.server.task_manager import TaskManager

class MyAgent(AgentExecutor):
    async def execute(self, task, context):
        # process the task
        # yield updates (for streaming)
        # return final response
        ...
```

### Authentication schemes

OpenAPI-compatible:

- **API key** — simplest; good for intra-org.
- **OAuth 2.0** — client credentials flow preferred for machine-to-machine.
- **OIDC Discovery** — for cross-org bridging with consent.

## Pros

- **Standardization.** 50+ partner frameworks interop. LangGraph / CrewAI / Semantic Kernel / custom can all speak A2A.
- **Capability discovery via Agent Cards.** Client agents query `/.well-known/agent-card.json` and pick the right agent for a task.
- **Well-defined task lifecycle.** `submitted → in_progress → ...` semantics are protocol-level, not framework-specific.
- **Streaming-first.** SSE support for long-running tasks is built in, not bolted on.
- **Async push for webhooks.** Fire-and-forget tasks with callback — useful for tasks that take minutes or hours.
- **Auth is OpenAPI-compatible.** You inherit an existing ecosystem of tooling (OAuth, OIDC, API key).
- **Open-source under Linux Foundation.** No vendor lock-in.
- **Python SDK is well-documented.** Reference implementations available for server (`A2AServer`) and client (`A2AClient`).

## Cons

- **HTTPS infrastructure required.** TLS certs, hostnames, network config. Not designed for local-only single-machine.
- **Cert trust on dev machines** — self-signed certs need trusting; corporate environments may restrict this.
- **JSON-RPC 2.0 verbosity.** Every call has envelope overhead (jsonrpc, id, method, params). Negligible at scale but not free.
- **Task lifecycle is protocol-defined; doesn't fit every workflow.** Non-task-shaped interactions (streaming logs, pub/sub events) don't map cleanly.
- **Cross-org auth requires OIDC discovery.** Setup cost; not a drop-in for API-key-only environments.
- **Agent Card is a public artifact.** If the well-known URL is reachable, anyone can discover capabilities. Restrictions live at auth level.
- **Protocol still evolving.** v0.2 → v0.3 introduced breaking changes (signed security cards, gRPC support). Expect further churn through 2026.

## Do / Don't

**Do**:

- **Publish Agent Cards at `/.well-known/agent-card.json`** (or legacy `/agent.json`). Standard path; interop depends on it.
- **Use OAuth 2.0 client credentials** for machine-to-machine intra-org.
- **Use OIDC** for cross-org with consent.
- **Implement streaming (SSE)** for tasks expected to run >10s.
- **Implement push notifications** for tasks >1 min — keeps clients informed without polling cost.
- **Version your Agent Card** (`version: "1.0.0"`). Clients can pin or negotiate.
- **Document your skills** in the Agent Card's `skills[]` array with examples. Capability-based routing needs this.
- **Pin A2A SDK version** in production. Breaking changes in v0.x; don't auto-upgrade.
- **Use Ship Bridge (a2a-starship) for MAD.Council cross-machine** — don't reimplement the bridge layer.

**Don't**:

- **Don't use A2A for single-machine** single-toolchain workflows. The overhead isn't worth it; use Claude Code Task.
- **Don't skip authentication.** Even intra-org; token theft is a real attack class.
- **Don't expose an Agent Card without rate limits.** Public endpoints attract probes.
- **Don't put secrets in the Agent Card.** It's a public (or authenticated-read) document.
- **Don't assume push-notification delivery is reliable.** Design for retries; implement idempotency.
- **Don't use A2A as a general-purpose RPC.** It's task-shaped; forcing non-task interactions produces awkward semantics.
- **Don't conflate transport (JSON-RPC) with framework.** A2A is transport + task semantics; what the agent does is your framework's business.

## Common pitfalls

### HTTPS cert on corporate machines

Dev certs may not be trustable on locked-down corp machines. `a2a-starship`'s `shipbridge-setup` documents the HTTP fallback (plain HTTP on `localhost:8222`) — use when cert trust is the blocker.

### Agent Card path confusion

Legacy `/.well-known/agent.json` vs newer `/.well-known/agent-card.json`. Clients should check both. Servers should publish at the newer path; a redirect from legacy is optional but polite.

### Task timeout mismatch

Server's task timeout > client's HTTP timeout → client disconnects while server continues; wasted work. Coordinate timeouts end-to-end.

### OIDC discovery delay

Cross-org calls with OIDC do an extra discovery round-trip. First call is slow (~1s added). Cache discovery results when possible.

### Auth token in logs

Bearer tokens in URL query strings (bad) or error messages (bad) leak into logs. Always put tokens in the `Authorization` header; never log auth errors with full header contents.

### Breaking changes in v0.x

A2A is pre-1.0. v0.2 → v0.3 had breaking changes. Pin your SDK version; review migration notes before upgrading.

## How MAD.Council relates

**Phase-4 integration target.** MAD.Council v1.1 Phase 4 (per `mad.council.a2a.md` §12) adds:

1. Agent Card publication in `channel.json` `members[i].agent_card`.
2. `transport: a2a-http | a2a-stream | a2a-push` on messages.
3. A2A task lifecycle mapping to thread states.
4. Bridge up to `plugins/a2a-starship/` Ship Bridge for cross-machine/cross-toolchain.

**Key design tension (CHK-024):** A2A Agent Cards are published at `/.well-known/agent-card.json` (URL-addressable). MAD.Council's Agent Card is inside `channel.json` (filesystem-addressable). These are **not cross-compatible** without a shim. Options:

- **(a)** Publish a well-known endpoint when A2A mode is enabled (Ship Bridge serves the card).
- **(b)** Accept incompat — MAD.Council's card is channel-internal metadata, not A2A-discoverable externally.
- **(c)** Both — internal for fast member-to-member lookup, well-known via Ship Bridge for external A2A discovery.

(c) is the likely answer. The Ship Bridge already fronts the channel; exposing `/.well-known/agent-card.json` per-member is a small addition.

## Marketplace integration: a2a-starship

The `plugins/a2a-starship/` plugin in the marketplace is **a real Google A2A implementation** in .NET 10 with two components:

- **Ship Bridge** — central hub; runs on one machine (`https://localhost:8222` default); serves agent discovery + task routing.
- **Crew Communicator** — per-Claude-Code-session MCP-stdio client; advertises `--name` + `--description` as that session's Agent Card.

MAD.Council's Phase-4 integration runs Crew Communicator on every machine, and Ship Bridge on one (typically the same machine as the "primary" channel host). Members on other machines connect through Ship Bridge.

## Implementation-specific mapping

| A2A primitive | MAD.Council equivalent | Notes |
|---|---|---|
| Agent Card (`/.well-known/agent-card.json`) | `channel.json` `members[i].agent_card` + optional Ship Bridge exposure | Internal vs external; CHK-024 tracks |
| `tasks/send` | `/council-post --type task --transport a2a-http` | A2A task is born from a channel task message |
| Task state `submitted` | thread `status: active` | Initial state |
| Task state `in_progress` | Thread with ≥1 status messages | Derived |
| Task state `input_required` | Thread with unanswered `type: question` | Derived |
| Task state `completed` | Thread resolved verdict=ACCEPT | Terminal |
| Task state `failed` | Thread resolved verdict=ESCALATE with no takeup | Terminal |
| SSE stream | Channel digest polling (pull) + future A2A stream (push) | Phase-4 adds streaming |
| OAuth 2.0 client creds | Inherited from Ship Bridge | MAD.Council doesn't reimplement |
| OIDC cross-org | Consent gate in `rules/dangerous-operations-policy.md` | Explicit user "yes" required |

## References

- **A2A Protocol Specification (latest)** — https://a2a-protocol.org/latest/specification/
- **A2A Spec v0.2.5 (pinned)** — https://a2a-protocol.org/v0.2.5/specification/
- **A2A GitHub** — https://github.com/a2aproject/A2A
- **Google A2A announcement (April 2025)** — https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
- **A2A Python SDK tutorial** — https://a2aprotocol.ai/docs/guide/google-a2a-python-sdk-tutorial
- **Google Codelab: purchasing concierge A2A** — https://codelabs.developers.google.com/intro-a2a-purchasing-concierge
- **A2A endpoint in LangChain Agent Server** — https://docs.langchain.com/langsmith/server-a2a
- **"Getting Started" quickstart** — https://google.github.io/adk-docs/a2a/quickstart-exposing/
- **Building Multi-Agent Systems with Google A2A (Medium, Feb 2026)** — https://medium.com/@vidsagar/building-multi-agent-systems-with-googles-a2a-protocol-5dc58d9b645c
- Full link list in `wiki/references.md` §1.

## Related wiki entries

- `mad.council.a2a.md` §6 — A2A Layer spec.
- `wiki/patterns/orchestrator-worker.md` §Google A2A section — pattern-level view.
- `wiki/implementations/anthropic-claude-code.md` — local runtime that bridges up via A2A.
- `wiki/implementations/langgraph.md` — external framework reachable via A2A.
- `wiki/implementations/marketplace-plugins.md` — `a2a-starship` plugin reference.
- CHK-024 in `_review-checklist.md` — tracks the Agent Card location design decision.
