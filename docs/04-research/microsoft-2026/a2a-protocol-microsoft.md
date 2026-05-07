---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/agent-framework/integrations/a2a
  - https://learn.microsoft.com/agent-framework/hosting/agent-to-agent
  - https://learn.microsoft.com/agent-framework/journey/agent-to-agent
  - https://learn.microsoft.com/agent-framework/migration-guide/agent-to-agent-sdk-v1
  - https://learn.microsoft.com/agent-framework/agents/providers/agent-to-agent
  - https://learn.microsoft.com/microsoftteams/platform/teams-sdk/in-depth-guides/ai/a2a/overview
  - https://a2a-protocol.org/latest/
  - https://www.nuget.org/packages/Microsoft.Agents.AI.Hosting.A2A.AspNetCore
  - https://www.nuget.org/packages/Microsoft.Agents.AI.Hosting.A2A
  - https://www.nuget.org/packages/Microsoft.Agents.AI.A2A
---

# A2A protocol — Microsoft adapters

## Sources

- A2A integration in Agent Framework — `learn.microsoft.com/agent-framework/integrations/a2a`
- A2A Hosting (NuGet packages) — `learn.microsoft.com/agent-framework/hosting/agent-to-agent`
- Agent-to-Agent journey doc — `learn.microsoft.com/agent-framework/journey/agent-to-agent`
- A2A SDK v1 migration guide — `learn.microsoft.com/agent-framework/migration-guide/agent-to-agent-sdk-v1`
- A2A Agent (consumer side) — `learn.microsoft.com/agent-framework/agents/providers/agent-to-agent`
- Teams SDK A2A — `learn.microsoft.com/microsoftteams/platform/teams-sdk/in-depth-guides/ai/a2a/overview`
- A2A protocol spec — `a2a-protocol.org/latest/`

## Load-bearing patterns

### What A2A is

Verbatim from `agent-framework/journey/agent-to-agent`:

> "**Agent-to-Agent (A2A)** is an [open protocol](https://a2a-protocol.org/latest/) designed for exactly this. It defines a standard way for agents to discover each other, exchange messages, and coordinate on tasks — over HTTP, across any boundary, in any language or framework."

A2A capabilities (per `integrations/a2a`):
1. **Agent discovery** through agent cards
2. **Message-based communication** between agents
3. **Long-running agentic processes** via tasks
4. **Cross-platform interoperability** between different agent frameworks

### Microsoft's adapters — three NuGet packages

| Package | Role |
|---|---|
| `Microsoft.Agents.AI.Hosting.A2A` | Core hosting logic (server registration, request handling, session management) |
| `Microsoft.Agents.AI.Hosting.A2A.AspNetCore` | ASP.NET Core endpoint mapping for A2A protocol bindings (transitively includes the core package) |
| `Microsoft.Agents.AI.A2A` | Client-side `A2AAgent` — wraps any A2A endpoint as a standard `AIAgent` |

### Hosting pattern (server side)

Per `hosting/agent-to-agent`, the minimal ASP.NET Core hosting:

```dotnetcli
dotnet add package Microsoft.Agents.AI.Hosting.A2A.AspNetCore --prerelease
dotnet add package A2A.AspNetCore --prerelease
dotnet add package Azure.AI.Projects --prerelease
dotnet add package Azure.Identity
dotnet add package Microsoft.Agents.AI.Foundry --prerelease
```

Then: `app.MapA2AHttpJson(...)` or `app.MapA2AJsonRpc(...)` to map endpoints.

**Standard URL surface:**
- Agent endpoint: `/a2a/<agent-name>` (e.g., `/a2a/weather-agent`)
- Agent card: `/.well-known/agent.json` (discoverable)

> "Any A2A-compliant client can discover and communicate with this agent."

### v1 migration — load-bearing changes (Apr-May 2026)

Per `migration-guide/agent-to-agent-sdk-v1`, three breaking changes in v1:

#### 1. Server registration is now a separate step
- **Before:** `MapA2A` did everything (server setup + endpoint mapping + agent card)
- **After:** `AddA2AServer(agent)` registers; `MapA2AHttpJson` / `MapA2AJsonRpc` map endpoints separately

#### 2. Default protocol changed
- **Before:** A2A Agent always used JSON-RPC (via `A2AClient`)
- **After:** Default is **HTTP+JSON** with JSON-RPC as fallback
- To preserve old behavior: `A2AClientOptions.PreferredBindings = [ProtocolBindingNames.JsonRpc]`

#### 3. `ITaskManager` no longer exposed to consumers
- Underlying `IAgentHandler` resolved internally by the A2A server

### Teams SDK A2A — separate adapter

Per `microsoftteams/platform/teams-sdk/.../a2a/overview`:
- `@microsoft/teams.a2a` (TS) and `microsoft-teams-a2a` (Python)
- Wraps the official A2A SDK (`a2a-js`, `a2a-python`) for both server + client
- Server endpoint at `/a2a` (Teams convention; Agent Framework convention is `/a2a/<name>`)
- Card served at `/a2a/.well-known/agent-card.json` (note: `agent-card.json`, not `agent.json` — slight naming variance vs. AF)

### Consumer side — A2AAgent

Per `agents/providers/agent-to-agent`:

```csharp
A2AClientOptions options = new() {
    PreferredBindings = [ProtocolBindingNames.HttpJson]
};
AIAgent agent = await resolver.GetAIAgentAsync(options: options);
```

> "This agent supports only messages as a response from A2A agents. Support for tasks will be added later as part of the long-running executions work."

### Considerations (verbatim from journey doc)

| Consideration | Detail |
|---|---|
| **Interoperability** | Framework-agnostic. .NET agent calls Python / LangChain / any A2A-implementing agent. "HTTP of agent communication." |
| **Network overhead** | Every A2A call is HTTP. Adds latency vs. in-process agent-as-tool. Keep agents co-located when performance-sensitive. |
| **Operational complexity** | Remote agents are distributed services. Handle network failures, timeouts, retries, versioning. |
| **Discovery at runtime** | Agent cards make discovery dynamic, but you still need to know where to look. Production: configure known endpoints or use a registry. |
| **Conversation state** | Remote agent manages its own conversation state (keyed by context ID). Restart loses state → conversation context may be lost. |

### When to use A2A (vs. agents-as-tools)

| Use A2A when crossing... | Example |
|---|---|
| Service boundaries | Travel-booking microservice ↔ expense-filing microservice |
| Team boundaries | Partner team owns a "compliance-review" agent — you don't have access to their code |
| Organizational boundaries | Third-party document-processing agent — standard discovery + communication |
| Independent evolution | Different release cycles, different teams, different languages |

> "If your agents all live in the same process and are maintained by the same team, agents as tools is simpler and has less overhead. A2A adds value when you cross a process, service, or organizational boundary."

## Verbatim quotes worth preserving

> "Any A2A-compliant client can discover and communicate with this agent."

> "The default protocol has changed. Previously, the A2A Agent always used JSON-RPC (via `A2AClient`). Now, the default is **HTTP+JSON** with JSON-RPC as a fallback."

> "This agent supports only messages as a response from A2A agents. Support for tasks will be added later as part of the long-running executions work." (load-bearing caveat for v1)

## Implications for the engine catalog (refs F-NNN)

- **F-a2a-server-by-default** — every engine workflow auto-exposes an A2A endpoint at `/a2a/<workflow-name>` + agent card at `/.well-known/agent.json`. Aligns with AF Workflows-as-agents pattern.
- **F-a2a-client-pluggable** — engine can call any A2A-compliant agent. Adopt the AF v1 default (HTTP+JSON; JSON-RPC fallback). Use `A2AClientOptions.PreferredBindings` for explicit override.
- **F-cross-org-boundary** — when engine consumes an A2A endpoint outside our org, fire the cross-org consent gate per `dangerous-operations-policy.md` § Cross-org A2A Bridge.
- **F-agent-card-registry** — engine ships a discovery mechanism: known agent cards (engine-internal) + dynamic discovery via `/.well-known/agent.json` lookups.
- **F-network-failure-handling** — A2A consumers in our engine handle network failures, timeouts, retries, versioning per `degradation-fallback-policy.md`. Document the contract.

## NEW F-NNN candidates (if any)

- **F-NEW: a2a-bridge-mode** — engine offers a bridge mode where any internal workflow becomes an A2A agent for external consumption (single config flag exposes the workflow on `/a2a/<name>`).
- **F-NEW: teams-a2a-adapter** — engine ships a Teams-SDK-A2A-compatible variant of its A2A endpoint. Lets Teams apps consume engine workflows directly.
- **F-NEW: a2a-protocol-binding-selector** — engine UI/CLI exposes the protocol-binding choice (HTTP+JSON vs JSON-RPC) per remote agent. Not all remote agents support both — make it explicit.
- **F-NEW: long-running-task-shim** — until A2A long-running tasks land in AF, engine exposes a polling-based equivalent on its A2A endpoint (matches the v1 caveat: "Support for tasks will be added later").

## Confidence

**HIGH** — Microsoft.Agents.AI.A2A* package names are confirmed via NuGet links in source docs. v1 migration changes are documented explicitly. The `.well-known/agent.json` URL convention is the spec convention. The Teams-SDK-A2A naming variance (`agent-card.json` vs `agent.json`) is a real divergence we should note in any engine doc that promises compatibility with both. Long-running-task limitation in v1 is verbatim. Single open question: the exact Bicep/scoped-binding path for cross-tenant A2A — out of scope for this lane.
