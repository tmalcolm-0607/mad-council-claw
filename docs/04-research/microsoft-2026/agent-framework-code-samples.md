---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/azure/foundry/agents/concepts/runtime-components
  - https://learn.microsoft.com/azure/durable-task/sdks/durable-agents-microsoft-agent-framework
  - https://learn.microsoft.com/agent-framework/workflows/as-agents
  - https://learn.microsoft.com/agent-framework/workflows/orchestrations/group-chat
  - https://learn.microsoft.com/dotnet/ai/conceptual/prompt-engineering-dotnet
  - https://learn.microsoft.com/agent-framework/agents/middleware/defining-middleware
---

# Microsoft Agent Framework — code samples (TS / C# / Python)

## Sources

- TypeScript: AIProjectClient + agent_reference (multi-turn) — `learn.microsoft.com/azure/foundry/agents/concepts/runtime-components`
- TypeScript: Agents Toolkit echo agent (math-solving thread) — `learn.microsoft.com/azure/foundry-classic/agents/quickstart`
- TypeScript: Foundry Agent Service migration sample (`createVersion` + Code Interpreter) — `learn.microsoft.com/azure/foundry/agents/how-to/migrate`
- C#: Fan-out/fan-in concurrent workflow on Durable Functions — `learn.microsoft.com/azure/durable-task/sdks/durable-agents-microsoft-agent-framework`
- C#: Sequential workflow + AsAIAgent wrapping — `learn.microsoft.com/agent-framework/workflows/as-agents`
- C#: Group chat orchestration setup — `learn.microsoft.com/agent-framework/workflows/orchestrations/group-chat`
- C#: AzureOpenAIClient → AsAIAgent + AgentSession streaming — `learn.microsoft.com/dotnet/ai/conceptual/prompt-engineering-dotnet`
- C#: ChatClientAgent middleware pattern — `learn.microsoft.com/agent-framework/agents/middleware/defining-middleware`
- Python: SequentialBuilder + workflow-as-agent (researcher → writer → reviewer) — `learn.microsoft.com/agent-framework/workflows/as-agents`

## Load-bearing patterns

### TypeScript samples — what's available

**Note:** the search returned **NO TypeScript-specific Agent Framework workflow samples**. TypeScript samples exist for `@azure/ai-projects` (Foundry runtime) but the **`agent-framework` workflow primitives (SequentialBuilder, WorkflowBuilder, GroupChatBuilder, MagenticBuilder) are documented primarily in C# and Python**.

This is a **load-bearing finding for our engine** since the user explicitly chose TS + Electron + Vitest as the stack (Message 3). We should:
1. Verify the AF JS/TS package status (`@microsoft/agent-framework` or equivalent) — likely preview or roadmap.
2. Either (a) wrap the C# AF via gRPC/REST/A2A for TS consumers, or (b) reimplement the patterns in TS (with structural fidelity to the C# shape).
3. File a research-gap on the AF TypeScript timeline.

### TypeScript samples that DO exist (Foundry surface)

#### Multi-turn conversation with `agent_reference`

```typescript
import { DefaultAzureCredential } from "@azure/identity";
import { AIProjectClient } from "@azure/ai-projects";

const project = new AIProjectClient(PROJECT_ENDPOINT, new DefaultAzureCredential());
const openai = await project.getOpenAIClient();

const conversation = await openai.conversations.create();

const response = await openai.responses.create({
  conversation: conversation.id,
  input: "What is the largest city in France?",
  agent_reference: { name: AGENT_NAME, type: "agent_reference" },
});

const followUp = await openai.responses.create({
  conversation: conversation.id,
  input: "What is the population of that city?",
  agent_reference: { name: AGENT_NAME, type: "agent_reference" },
});
```

This is the canonical TS pattern for stateful, multi-turn agent interaction via Foundry.

#### Agents Toolkit thread + run (full lifecycle)

The TS quickstart sample uses `AgentsClient` + `client.threads.create()` + `client.messages.create()` + `client.runs.createAndPoll()`. **This is a polling pattern**, not streaming. For our engine's TS consumers, this is a starting point; streaming requires the Foundry Responses API.

#### Migration sample — agent versioning + Code Interpreter

```typescript
const agent = await projectClient.AgentAdministrationClient.createVersion(
    "my-agent",
    {
        kind: "prompt",
        model: "gpt-4.1",
        instructions: "...",
        tools: [{ type: "code_interpreter" }],
    }
);
```

`createVersion` + `kind: "prompt"` is the new Foundry surface. Older `assistants` shape replaced.

### C# patterns (the canonical shape)

#### Concurrent fan-out / fan-in (Durable Functions)

```csharp
ChatClient chatClient = new AzureOpenAIClient(
    new Uri(endpoint), new DefaultAzureCredential()).GetChatClient(deploymentName);

AIAgent physicist = chatClient.AsAIAgent(
    "You are a physics expert. Be concise (2-3 sentences).", "Physicist");
AIAgent chemist = chatClient.AsAIAgent(
    "You are a chemistry expert. Be concise (2-3 sentences).", "Chemist");

ParseQuestionExecutor parseQuestion = new();
AggregatorExecutor aggregator = new();

Workflow workflow = new WorkflowBuilder(parseQuestion)
    .WithName("ExpertReview")
    .AddFanOutEdge(parseQuestion, [physicist, chemist])
    .AddFanInBarrierEdge([physicist, chemist], aggregator)
    .Build();
```

`AddFanOutEdge` + `AddFanInBarrierEdge` are the AF primitives for concurrent execution + sync.

#### Sequential workflow + workflow-as-agent

```csharp
var workflow = new WorkflowBuilder(researchAgent)
    .AddEdge(researchAgent, writerAgent)
    .AddEdge(writerAgent, reviewerAgent)
    .Build();

AIAgent workflowAgent = workflow.AsAIAgent(
    id: "content-pipeline",
    name: "Content Pipeline Agent",
    description: "A multi-agent workflow that researches, writes, and reviews content"
);
```

`workflow.AsAIAgent(...)` — the composition primitive that lets a multi-step workflow look like a single agent (callable by other agents, A2A clients, etc.).

#### Streaming agent + session

```csharp
AIAgent agent = new AzureOpenAIClient(...)
    .GetChatClient("gpt-4o")
    .AsAIAgent();

AgentSession session = await agent.CreateSessionAsync();

await foreach (AgentResponseUpdate update in agent.RunStreamingAsync(userInput, session)) {
    Console.Write(update.Text);
}
```

`AgentSession` is the per-agent session abstraction (each agent type can have its own session implementation).

#### ChatClient middleware pattern

```csharp
var middlewareEnabledChatClient = chatClient
    .AsBuilder()
        .Use(getResponseFunc: CustomChatClientMiddleware, getStreamingResponseFunc: null)
    .Build();

var agent = new ChatClientAgent(middlewareEnabledChatClient, instructions: "You are a helpful assistant.");
```

Middleware on the chat client — for cross-cutting (logging, retries, content filtering).

### Python patterns

#### Sequential workflow as agent (researcher → writer → reviewer)

```python
client = FoundryChatClient(
    project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
    model=os.environ["FOUNDRY_MODEL"],
    credential=AzureCliCredential(),
)

researcher = client.as_agent(name="Researcher", instructions="...")
writer = client.as_agent(name="Writer", instructions="...")
reviewer = client.as_agent(name="Reviewer", instructions="...")

workflow = SequentialBuilder(participants=[researcher, writer, reviewer]).build()
workflow_agent = workflow.as_agent(name="Content Creation Pipeline")

async for update in workflow_agent.run("Write about quantum computing", stream=True):
    print(update.text, end="", flush=True)
```

Mirror of the C# shape — `SequentialBuilder` + `workflow.as_agent()` + streaming `run()`.

### IBackendProvider — pattern observed (cross-language)

The samples show a consistent IBackendProvider-equivalent pattern:
- **C#:** `chatClient.AsAIAgent(instructions, name)` — chat client → agent
- **Python:** `client.as_agent(name=, instructions=)` — same shape
- **TS (Foundry):** `agent_reference: { name, type: "agent_reference" }` — references a registered agent by name

Our engine's IBackendProvider abstraction should match this shape: any backend (Azure OpenAI, OpenAI, Anthropic, local) → the same `AsAIAgent()` / `as_agent()` factory output.

## Verbatim quotes worth preserving

> "Workflow workflow = new WorkflowBuilder(parseQuestion).WithName(\"ExpertReview\").AddFanOutEdge(parseQuestion, [physicist, chemist]).AddFanInBarrierEdge([physicist, chemist], aggregator).Build();" — fan-out/fan-in template

> "AIAgent workflowAgent = workflow.AsAIAgent(...)" — composition primitive

## Implications for the engine catalog (refs F-NNN)

- **F-typescript-af-bridge** — engine's TS surface needs a bridge to AF (since native AF JS/TS is sparse). Two options: (a) call C# AF via REST/gRPC/A2A; (b) reimplement AF patterns in TS with structural fidelity. Decision: deferred to a future lane after AF JS/TS roadmap is confirmed.
- **F-ibackend-provider-shape** — adopt `chatClient.AsAIAgent(instructions, name)` shape across all backends. Any backend (Azure OpenAI / OpenAI / Anthropic / local Ollama) → `IAIAgent` interface.
- **F-fan-out-fan-in-primitive** — adopt `AddFanOutEdge` / `AddFanInBarrierEdge` as the engine's concurrent-pattern primitives. Type-safe + barrier-synced.
- **F-workflow-as-agent-composition** — `workflow.AsAIAgent(id, name, description)` is the load-bearing composition primitive. Engine wraps every workflow as a callable agent.
- **F-agent-session-per-agent** — adopt per-agent session model (each agent type has its own AgentSession implementation). Matches Group Chat's per-agent session synchronization.
- **F-streaming-default** — `RunStreamingAsync` (C#) / `run(stream=True)` (Python) is the default. Polling (`createAndPoll`) is the fallback for legacy clients.
- **F-middleware-on-chat-client** — engine supports middleware at the chat-client layer (logging, retries, content filtering, budget enforcement) before agent wrapping.

## NEW F-NNN candidates (if any)

- **F-NEW: af-typescript-bridge** — first-class TS bridge for AF (calls C# AF via A2A or implements pattern fidelity in TS). Required for our engine's TS+Electron stack.
- **F-NEW: backend-adapter-registry** — engine ships a backend adapter registry (Azure OpenAI / OpenAI / Anthropic / local). Each adapter implements `AsAIAgent(instructions, name)` → `IAIAgent`. Hot-swappable per agent.
- **F-NEW: fan-out-template-helper** — engine ships a helper that, given N parallel branches + an aggregator function, returns a configured fan-out/fan-in workflow.

## Confidence

**HIGH** for the C# + Python patterns (cited verbatim from current Microsoft Learn samples). **MEDIUM** for the TypeScript story — the absence of native AF TS samples is itself a finding, but it's a finding ABOUT a gap, not a verified state-of-the-AF-TS-roadmap. **Action item for next lane:** verify the AF JS/TS package status (npm `@microsoft/agent-framework` or equivalent) directly via `npm view` + GitHub `microsoft/agent-framework` repo, since the docs corpus shows C# + Python predominance.
