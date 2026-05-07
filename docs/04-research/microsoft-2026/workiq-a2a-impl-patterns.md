---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-004
lane: lane-c
date: 2026-05-06
sources:
  - https://learn.microsoft.com/microsoftteams/platform/teams-sdk/in-depth-guides/ai/a2a/a2a-client?pivots=typescript%20python
  - https://learn.microsoft.com/microsoftteams/platform/teams-sdk/in-depth-guides/ai/a2a/a2a-server?pivots=typescript%20python
  - https://learn.microsoft.com/microsoftteams/platform/teams-sdk/in-depth-guides/ai/a2a/overview
  - https://learn.microsoft.com/agent-framework/integrations/a2a
  - https://learn.microsoft.com/azure/foundry/agents/how-to/tools/agent-to-agent
  - https://learn.microsoft.com/javascript/api/overview/azure/ai-projects-readme
  - https://www.npmjs.com/package/@a2a-js/sdk
  - https://www.npmjs.com/package/@microsoft/teams.a2a
---

# A2A v1.0 client/server implementation patterns (TS + Python + Foundry)

## Why this lane exists

Wave-1 Lane B documented Microsoft's three NuGet adapters for A2A (`Microsoft.Agents.AI.Hosting.A2A`, `.AspNetCore`, `.A2A`) and the v1 migration changes (HTTP+JSON default; `MapA2AHttpJson` / `MapA2AJsonRpc` separate steps; `ITaskManager` removed). It noted Teams SDK A2A as a separate adapter but didn't enumerate the TS surface. Wave-4 Lane C closes that — `@a2a-js/sdk` (the official A2A protocol SDK for JS/TS) AND `@microsoft/teams.a2a` (the Teams SDK A2A plugin) are now documented with concrete client + server patterns.

**Naming clarification (load-bearing):** "WorkIQ A2A v1.0" in the lane brief is shorthand for the broader **A2A protocol v1.0 + Microsoft adapters** ecosystem. The "WorkIQ" branding refers to internal-context retrieval (Teams chats / emails) — that's a separate research file (`workiq-internal-context.md`). Wave-4 Lane C's actual focus per the user brief: **A2A SDK quickstart for TS + Microsoft adapters**.

## Sources

- **A2A TS SDK (`@a2a-js/sdk`)**: `npmjs.com/package/@a2a-js/sdk` + Teams SDK pages reference it.
- **Teams A2A plugin (`@microsoft/teams.a2a`)**: client + server patterns at `learn.microsoft.com/microsoftteams/platform/teams-sdk/.../a2a/`.
- **Foundry A2A tool**: `learn.microsoft.com/azure/foundry/agents/how-to/tools/agent-to-agent` — `a2a_preview` tool type for cross-agent communication via Azure AI Projects.
- **Agent Framework A2A integration (Python)**: `learn.microsoft.com/agent-framework/integrations/a2a` — exposes an AF agent over A2A using `A2AStarletteApplication` + `A2AExecutor`.

## Load-bearing patterns

### TS A2A client — direct sendMessage

```typescript
import { A2AClient } from '@a2a-js/sdk/client';

// Create client from agent card URL
const client = await A2AClient.fromCardUrl('http://localhost:4000/a2a/.well-known/agent-card.json');

// Send a message directly
const response = await client.sendMessage({
  message: {
    messageId: 'unique-id',
    role: 'user',
    parts: [{ kind: 'text', text: 'What is the weather?' }],
    kind: 'message',
  },
});
```

`A2AClient.fromCardUrl(...)` discovers via the agent card URL — the `.well-known/agent-card.json` convention is the discovery surface. Each message includes `messageId`, `role`, `parts[]` (with discriminated `kind: 'text' | 'data' | ...`), `kind: 'message'`.

### TS A2A server — Teams app plugin

```typescript
import { AgentCard } from '@a2a-js/sdk';
import { A2APlugin } from '@microsoft/teams.a2a';
import { App } from '@microsoft/teams.apps';

const agentCard: AgentCard = {
  name: 'Weather Agent',
  description: 'An agent that can tell you the weather',
  url: `http://localhost:${PORT}/a2a`,
  version: '0.0.1',
  protocolVersion: '0.3.0',
  capabilities: {},
  defaultInputModes: [],
  defaultOutputModes: [],
  skills: [
    {
      id: 'get_weather',
      name: 'Get Weather',
      description: 'Get the weather for a given location',
      tags: ['weather', 'get', 'location'],
      examples: [
        'Get the weather for London',
        'What is the weather',
        "What's the weather in Tokyo?",
        'How is the current temperature in San Francisco?',
      ],
    },
  ],
};

const app = new App({
  plugins: [new A2APlugin({ agentCard })],
});
```

**AgentCard schema (TS, verbatim from sample):**
- `name`, `description`, `url`, `version`, `protocolVersion` (`'0.3.0'` is current)
- `capabilities` — empty object means default/none
- `defaultInputModes` / `defaultOutputModes` — modality declarations
- `skills[]` — each with `id`, `name`, `description`, `tags[]`, `examples[]`

Skills' `examples` field is load-bearing for *intent matching* by the calling LLM — these are not just docstrings; they're the prompts the calling agent will pattern-match against to decide whether to invoke this skill.

### TS A2A client via ChatPrompt (LLM-driven dispatch)

```typescript
// Now we can send the message to the prompt and it will decide if
// the a2a agent should be used or not and also manages contacting the agent
const result = await prompt.send(message);
```

Pattern: register `A2AClientPlugin` against `ChatPrompt`; the LLM decides whether to invoke each registered A2A agent based on its agent card's skill `examples[]`. This is the "agent-as-tool" composition shape, with A2A providing the cross-process binding.

### Foundry A2A — `a2a_preview` tool type

```typescript
import { DefaultAzureCredential } from "@azure/identity";
import { AIProjectClient } from "@azure/ai-projects";

const PROJECT_ENDPOINT = "https://<resource>.ai.azure.com/api/projects/<project>";
const A2A_CONNECTION_NAME = "my-a2a-connection";

const project = new AIProjectClient(PROJECT_ENDPOINT, new DefaultAzureCredential());
const openAIClient = project.getOpenAIClient();

const a2aConnection = await project.connections.get(A2A_CONNECTION_NAME);

const agent = await project.agents.createVersion("MyA2AAgent", {
    kind: "prompt",
    model: "gpt-4.1-mini",
    instructions: "You are a helpful assistant.",
    tools: [
        {
            type: "a2a_preview",
            project_connection_id: a2aConnection.id,
        },
    ],
});

const streamResponse = await openAIClient.responses.create(
    { input: userInput, stream: true },
    {
        body: {
            agent: { name: agent.name, type: "agent_reference" },
            tool_choice: "required",
        },
    },
);

for await (const event of streamResponse) {
    if (event.type === "response.created") { /* ... */ }
    else if (event.type === "response.output_text.delta") { process.stdout.write(event.delta); }
    else if (event.type === "response.output_text.done") { /* ... */ }
    else if (event.type === "response.output_item.done") {
        const item = event.item as any;
        if (item.type === "remote_function_call") {
            const callId = item.call_id;
            const label = item.label;
        }
    }
    else if (event.type === "response.completed") { /* ... */ }
}
```

Three load-bearing observations:

1. **`type: "a2a_preview"`** — Foundry's A2A tool type is still **preview-tagged** (May 2026). Will become `"a2a"` at GA.
2. **Streaming events**: Foundry's response API emits typed events (`response.created`, `response.output_text.delta`, `response.output_text.done`, `response.output_item.done`, `response.completed`) plus `remote_function_call` items for cross-agent calls.
3. **`tool_choice: "required"`** — forces the agent to use the A2A tool. Useful when the orchestrator is the LLM and you want predictable handoff.

### Python AF agent over A2A — `A2AStarletteApplication`

```python
import uvicorn
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCapabilities, AgentCard, AgentSkill
from agent_framework import Agent
from agent_framework.a2a import A2AExecutor
from agent_framework.openai import OpenAIChatClient

flight_skill = AgentSkill(
    id="Flight_Booking",
    name="Flight Booking",
    description="Search and book flights across Europe.",
    tags=["flights", "travel", "europe"],
    examples=[],
)

public_agent_card = AgentCard(
    name="Europe Travel Agent",
    description="Helps users search and book flights and hotels across Europe.",
    url="http://localhost:9999/",
    version="1.0.0",
    defaultInputModes=["text"],
    defaultOutputModes=["text"],
    capabilities=AgentCapabilities(streaming=True),
    skills=[flight_skill],
)

agent = Agent(
    client=OpenAIChatClient(),
    name="Europe Travel Agent",
    instructions="You are a helpful Europe Travel Agent.",
)

request_handler = DefaultRequestHandler(
    agent_executor=A2AExecutor(agent),
    task_store=InMemoryTaskStore(),
)

server = A2AStarletteApplication(
    agent_card=public_agent_card,
    http_handler=request_handler,
).build()

uvicorn.run(server, host="0.0.0.0", port=9999)
```

**Python stack components:**
- `a2a-sdk` (the official `a2a-python` SDK)
- `A2AStarletteApplication` — Starlette ASGI app
- `A2AExecutor(agent)` — wraps an `agent_framework.Agent` to expose it on A2A
- `DefaultRequestHandler` + `InMemoryTaskStore` — task tracking for long-running A2A tasks
- `AgentCapabilities(streaming=True)` — declares streaming support on the agent card

**Critical comparison vs. TS:** Python AF has `A2AExecutor` to wrap an existing AF agent and serve it over A2A. **TS does not have an equivalent because AF Workflows don't exist on TS.** The TS A2A path goes through `@microsoft/teams.a2a` `A2APlugin` + the `@microsoft/teams.apps` App framework — which is Teams-shaped, not workflow-shaped.

### URL convention divergence (Teams SDK vs. Agent Framework)

| Source | Agent endpoint | Card endpoint |
|---|---|---|
| Agent Framework (.NET) | `/a2a/<agent-name>` (e.g., `/a2a/weather-agent`) | `/.well-known/agent.json` |
| Teams SDK A2A (TS) | `/a2a` (no name suffix) | `/a2a/.well-known/agent-card.json` |

**Two divergences:**
1. AF uses agent-name suffix; Teams SDK uses fixed `/a2a` path.
2. AF uses `agent.json`; Teams SDK uses `agent-card.json`.

A bridge that wants to be both-compatible must serve both endpoints (or alias them).

### v1 migration — protocol bindings (revisited from wave-1)

```typescript
// Default behavior (HTTP+JSON, falls back to JSON-RPC)
const client = await A2AClient.fromCardUrl(cardUrl);

// Force JSON-RPC (preserve pre-v1 behavior)
// In .NET: A2AClientOptions.PreferredBindings = [ProtocolBindingNames.JsonRpc]
// In TS @a2a-js/sdk: equivalent option in client options bag
```

The v1 default is HTTP+JSON. JSON-RPC remains the fallback for compat.

### npm packages reference

| Package | Purpose |
|---|---|
| `@a2a-js/sdk` | Core A2A protocol SDK for JS/TS (client + types) |
| `@a2a-js/sdk/client` | Subpath: `A2AClient` |
| `@microsoft/teams.a2a` | Teams SDK A2A plugin (`A2APlugin`) |
| `@microsoft/teams.apps` | Teams SDK App framework (`App`) |

### Long-running tasks — verbatim caveat from wave-1

> "This agent supports only messages as a response from A2A agents. Support for tasks will be added later as part of the long-running executions work." — `learn.microsoft.com/agent-framework/agents/providers/agent-to-agent`

The v1 limitation is still in place as of May 2026 in the .NET adapter. Python's `A2AExecutor` accepts a `task_store` (`InMemoryTaskStore`) — but this is task-tracking inside the Python A2A server, not A2A's own long-running task contract. **The A2A long-running task contract itself is still in development at the protocol level (`a2a-protocol.org/latest/`).** A Microsoft-adapter-level shim (engine F-NEW: long-running-task-shim from wave-1) remains the right pattern.

## Verbatim quotes worth preserving

> "tool_choice: 'required'" — Foundry pattern to force A2A tool usage.

> "type: 'a2a_preview'" — Foundry's tool type is still preview-tagged in May 2026; expected to become `'a2a'` at GA.

> "Capabilities=AgentCapabilities(streaming=True)" — agent cards declare streaming support; consumers respect.

## Implications for the engine catalog (refs F-NNN)

- **F-a2a-server-by-default (revisited)**: TS path uses `@microsoft/teams.a2a` `A2APlugin` if Teams-shaped, OR direct `@a2a-js/sdk` server primitives (the SDK has server-side classes too — `A2AClient` is just one half). For our engine, the right shape is to ship a `@microsoft/teams.a2a`-compatible plugin AND an Express-mountable A2A server (mounting `/a2a` directly).
- **F-a2a-client-pluggable (revisited)**: TS uses `A2AClient.fromCardUrl(...)`; `.well-known/agent-card.json` is the entry. Engine's A2A consumer-side wraps this with retry / timeout / circuit-breaker per `degradation-fallback-policy.md`.
- **F-foundry-a2a-tool-integration**: engine workflows expose themselves as Foundry `a2a_preview` tools so Foundry agents can call them. Once `a2a_preview` → `a2a` at GA, this becomes a stable integration.

## NEW F-NNN candidates

- **F-209: a2a-card-dual-naming-bridge** — engine serves both `/a2a/<name>/.well-known/agent.json` (Agent Framework convention) AND `/a2a/.well-known/agent-card.json` (Teams SDK convention) for the same workflow, with content fidelity. Closes the URL-convention divergence per `a2a-protocol-microsoft.md`'s identified Teams-vs-AF naming gap.
- **F-210: a2a-skill-examples-quality-gate** — engine pre-flight gate verifies every published `skills[].examples[]` array has ≥3 distinct phrasings (LLM dispatch quality is sensitive to example diversity). Surfaces a CONSIDER finding when `examples.length < 3`.
- **F-211: foundry-a2a-tool-binding** — engine ships a Bicep template + manifest helper that creates the Foundry `Connection` resource + connects an engine workflow as an `a2a_preview` tool in one config.
- **F-212: a2a-streaming-event-mapper** — engine maps Foundry's typed streaming events (`response.created`, `response.output_text.delta`, `response.output_item.done`, `response.completed`) to MAD.Council message-stream semantics. One translation layer for Foundry → engine bridge.
- **F-213: a2a-task-store-pluggable** — analog to Python's `InMemoryTaskStore`, engine ships `MemoryTaskStore` (default) + `CosmosTaskStore` (production) so multi-instance engine deployments share long-running task state. Shim for the upstream A2A protocol gap.

## Confidence

**HIGH** — every TS code sample is verbatim from `microsoft_code_sample_search` results. `@microsoft/teams.a2a` is documented in Teams SDK; `@a2a-js/sdk` is the official A2A protocol SDK referenced from the same Teams docs. Foundry `a2a_preview` tool type is verbatim from `learn.microsoft.com/azure/foundry/agents/how-to/tools/agent-to-agent` (May 2026). Python `A2AExecutor`/`A2AStarletteApplication` is verbatim from `learn.microsoft.com/agent-framework/integrations/a2a`. URL-convention divergence is observed in the docs themselves (Teams docs say `/a2a/.well-known/agent-card.json`; AF docs say `/.well-known/agent.json`). **Wave-1 Lane B's "Teams SDK A2A naming variance" gap is now corroborated and elevated to F-209.** Single open question: TS server-side primitives (vs. Teams plugin) — `@a2a-js/sdk` server module exists per the package shape but specific TS server class names beyond `A2AClient` are not surfaced in the searched docs corpus; deferred to direct npm inspection.
