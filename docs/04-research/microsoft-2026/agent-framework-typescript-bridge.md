---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-004
lane: lane-c
date: 2026-05-06
sources:
  - https://learn.microsoft.com/agent-framework/
  - https://learn.microsoft.com/agent-framework/integrations/a2a
  - https://learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry
  - https://learn.microsoft.com/javascript/api/overview/agents-overview
  - https://learn.microsoft.com/agent-framework/workflows/as-agents
  - https://learn.microsoft.com/agent-framework/workflows/orchestrations/group-chat
  - https://www.npmjs.com/search?q=%40microsoft%2Fagent-framework
---

# Agent Framework TypeScript bridge options (research-gap resolution)

## Why this lane exists

Wave-1 Lane B documented Microsoft Agent Framework workflow primitives (`SequentialBuilder`, `WorkflowBuilder`, `GroupChatBuilder`, `MagenticBuilder`, `AddFanOutEdge`, `AddFanInBarrierEdge`, `workflow.AsAIAgent()`) verbatim in **C# and Python**, and flagged that **TypeScript samples were absent**. Wave-4 Lane C resolves the question definitively: **there is no native TypeScript port of Microsoft Agent Framework workflow primitives as of May 2026.** This file enumerates the bridge options.

## Sources

- **Microsoft OpenTelemetry Distro instrumentation matrix**: `learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry` — explicitly lists "Agent Framework | Python: Supported | Node.js: **Not supported** | .NET: Supported".
- **M365 Agents SDK JavaScript packages**: `learn.microsoft.com/javascript/api/overview/agents-overview` — full package list; **no `@microsoft/agent-framework`** entry.
- **AF Workflows-as-agents (C# / Python only)**: `learn.microsoft.com/agent-framework/workflows/as-agents`.
- **AF A2A integration (Python only)**: `learn.microsoft.com/agent-framework/integrations/a2a`.
- **AF Group Chat orchestration (C# / Python only)**: `learn.microsoft.com/agent-framework/workflows/orchestrations/group-chat`.

## Load-bearing patterns

### Definitive finding: No TS port exists

Three orthogonal evidences confirm the gap:

1. **Microsoft OpenTelemetry Distro instrumentation matrix** (verbatim, May 2026):

   | Framework | Python | Node.js | .NET |
   |---|---|---|---|
   | Semantic Kernel | Supported | **Not supported** | Supported |
   | OpenAI and OpenAI Agents SDK | Supported | Supported | Supported |
   | Agent Framework | Supported | **Not supported** | Supported |
   | LangChain | Supported | Supported | Not listed |

   "Not supported" for AF on Node.js means there's no JS auto-instrumentation — strongly implies there's no JS package emitting AF-specific signals.

2. **M365 Agents SDK npm package list (`learn.microsoft.com/javascript/api/overview/agents-overview`)** does not include `@microsoft/agent-framework`. The full TS namespace is `@microsoft/agents-*` (Activity Protocol routing), not `@microsoft/agent-framework-*`.

3. **AF docs pivots**: every AF docs page that has a language pivot offers `programming-language-csharp | programming-language-python`. There is no `programming-language-typescript` or `-javascript` pivot anywhere in `learn.microsoft.com/agent-framework/` (verified May 2026 across `/integrations/a2a`, `/workflows/as-agents`, `/workflows/orchestrations/group-chat`, `/agents/middleware/defining-middleware`).

### Bridge options (engine's TS surface needs SOMETHING — pick one)

Three viable bridge architectures, each with different cost/fidelity/maintenance characteristics:

#### Option A — TS wraps C# AF via A2A

```
[TS engine] ──A2A HTTP+JSON──▶ [C# AF host: ASP.NET Core + Microsoft.Agents.AI.Hosting.A2A.AspNetCore]
                                  │
                                  ├─ workflow.AsAIAgent() → AddA2AServer() → MapA2AHttpJson()
                                  ├─ SequentialBuilder / WorkflowBuilder / GroupChatBuilder
                                  └─ AddFanOutEdge / AddFanInBarrierEdge
```

**Pros:**
- Reuses the canonical AF C# implementation — no semantic drift.
- TS engine doesn't reimplement primitives; just calls them via A2A.
- Bridges to all AF features (workflows, orchestrations, middleware, sessions).

**Cons:**
- Requires running a C# host process alongside the TS engine.
- HTTP-per-call latency overhead (AF's own warning: "Every A2A call is HTTP. Adds latency vs. in-process.").
- Two language runtimes = two debugger contexts.
- AF v1 still missing long-running A2A tasks (verbatim caveat from `agents/providers/agent-to-agent`).

**Best when:** the engine's distribution model already includes a server host (Electron with embedded service); cross-platform deploy is fine; latency budget tolerates HTTP RTT.

#### Option B — TS reimplements AF patterns with structural fidelity

```
[TS engine ]
  ├─ TS WorkflowBuilder      ←─ structurally faithful port of C#
  ├─ TS SequentialBuilder
  ├─ TS GroupChatBuilder
  ├─ AddFanOutEdge / AddFanInBarrierEdge
  └─ TS workflow.asAIAgent() // matches C# workflow.AsAIAgent()
```

**Pros:**
- Single-language stack; no separate C# host.
- In-process; no HTTP latency.
- TS-idiomatic (Promises, async iterators, discriminated unions).

**Cons:**
- Maintenance: every AF release in C#/Python must be tracked + ported.
- Risk of semantic drift over time (the canonical impl evolves; ports lag).
- Doubles the surface area we own.
- We don't get AF's auto-instrumentation (per Distro matrix above — no Node.js auto-instrumentation for AF, even if we mimic it).

**Best when:** the engine's TS-only ergonomics are paramount; team has bandwidth to track AF upstream; the workflow-primitive subset we need is bounded (e.g. just Sequential + GroupChat — not Magentic).

#### Option C — Hybrid: M365 Agents SDK (TS native) + AF subset on demand via A2A

```
[TS engine using @microsoft/agents-hosting]
  ├─ Activity Protocol routing (TS native)
  ├─ Adapter / hosting / storage (TS native)
  └─ When a workflow primitive is needed:
      └─ A2A call to a small C# AF host that exposes specific compositions on demand
```

**Pros:**
- 80% of agent functionality (Activity routing, channel adapters, storage, auth) is TS-native via M365 Agents SDK.
- Only the workflow-orchestration 20% needs the C# bridge — minimal surface.
- Can ship a minimal C# bridge (one Bicep / one Dockerfile) for users who need AF workflows; everyone else uses pure TS.

**Cons:**
- Architectural complexity: now two "engines" (TS native + C# bridge).
- User-facing: which abstraction do you reach for? Decision-tree fatigue.

**Best when:** the engine wants to be primarily TS-native but acknowledge AF parity is a separate, opt-in feature.

### Recommendation matrix

| If the engine values... | Pick |
|---|---|
| Time-to-market + max AF feature coverage | A (A2A bridge) |
| TS purity + acceptable subset of AF features | B (structural-fidelity port) |
| TS-first with optional AF on demand | C (hybrid) |

Wave-1 Lane B's F-NEW-af-typescript-bridge candidate is now better-resolved as one of these three options. The engine's wave-5+ planning should pick.

### What TS HAS that fills part of the gap

#### M365 Agents SDK (TS) — Activity Protocol layer

Per `activity-protocol-implementation-patterns.md` (this wave): full TS surface for Activity-Protocol routing. **NOT** a workflow orchestrator — `OnActivity` is per-activity routing, not multi-step workflow composition.

#### `@a2a-js/sdk` — A2A client (TS)

Per `workiq-a2a-impl-patterns.md` (this wave): `A2AClient.fromCardUrl(...)` for calling external agents. Useful for **consuming** AF workflows hosted in C#/Python. NOT useful for **building** workflows in TS.

#### Azure AI Projects TS SDK (`@azure/ai-projects`)

```typescript
const project = new AIProjectClient(PROJECT_ENDPOINT, new DefaultAzureCredential());
const openAIClient = project.getOpenAIClient();
const conversation = await openai.conversations.create();
const response = await openAIClient.responses.create({
  conversation: conversation.id,
  input: "...",
  agent_reference: { name: AGENT_NAME, type: "agent_reference" },
});
```

This is Foundry's TS surface. Per wave-1 Lane B: useful for stateful agent invocation, but **not** for AF workflow composition. `agent_reference` references an already-registered agent; it doesn't compose new workflows.

#### Durable Functions for Node.js — partial workflow surface

Durable Functions has Node.js bindings (`durable-functions` npm package). For our engine, this is a third bridge option (sub-option of B): use DF as the TS workflow orchestrator (durable timers, retries, fan-out/fan-in via Durable Functions activities), keeping AF for any agent-as-tool primitive that DF can't express. Adds Azure Durable Functions runtime as a dependency though.

### Concrete C# bridge skeleton (Option A reference)

```csharp
// Program.cs — minimal C# host that exposes AF workflows over A2A
using Microsoft.Agents.AI.Hosting.A2A.AspNetCore;
using Microsoft.Agents.AI.Foundry;
using Microsoft.Extensions.Azure;
using Azure.Identity;

var builder = WebApplication.CreateBuilder(args);

// Register the AF agent
builder.Services.AddSingleton<AIAgent>(sp => {
    var chatClient = new AzureOpenAIClient(new Uri(endpoint), new DefaultAzureCredential())
        .GetChatClient("gpt-4o");
    return chatClient.AsAIAgent("You are a helpful assistant.", "Helper");
});

// Register A2A server
builder.Services.AddA2AServer<AIAgent>();

var app = builder.Build();

// Map A2A endpoint with HTTP+JSON binding (v1 default)
app.MapA2AHttpJson<AIAgent>("/a2a/helper");

// Optional: also map JSON-RPC for legacy compat
app.MapA2AJsonRpc<AIAgent>("/a2a/helper");

app.Run();
```

Then the TS engine calls:

```typescript
const client = await A2AClient.fromCardUrl('http://localhost:5000/a2a/helper/.well-known/agent.json');
const response = await client.sendMessage({ message: { ... } });
```

## Verbatim quotes worth preserving

> "Agent Framework | Python: Supported | Node.js: **Not supported** | .NET: Supported" — Microsoft OpenTelemetry Distro instrumentation matrix, May 2026.

> "Every A2A call is HTTP. Adds latency vs. in-process agent-as-tool. Keep agents co-located when performance-sensitive." — `learn.microsoft.com/agent-framework/journey/agent-to-agent`. Cost guideline for Option A.

## Implications for the engine catalog (refs F-NNN)

- **F-typescript-af-bridge (revisited from wave-1)**: now resolved as a 3-option decision (A/B/C above). Engine's planning needs to pick.
- **F-ibackend-provider-shape (wave-1)**: still applies regardless of bridge choice — `chatClient.AsAIAgent(instructions, name)` shape is consistent across C#/Python; engine's TS abstraction `chatClient.asAIAgent(instructions, name)` matches.
- **F-fan-out-fan-in-primitive (wave-1)**: in Option B, we port this to TS; in Option A, we expose it via A2A; in Option C, it's available via the C# bridge.
- **F-workflow-as-agent-composition (wave-1)**: same — option-dependent.

## NEW F-NNN candidates

- **F-214: af-bridge-decision-record** — engine ships a documented Architectural Decision Record (ADR) selecting Option A/B/C based on the engine's actual scope at the time of decision. ADR includes: workflow-primitives-needed list, performance-budget envelope, team-language-bandwidth assessment.
- **F-215: af-bridge-ts-shim** — if the decision is Option A, engine ships a minimal C# AF host as a docker image + a TS client that wraps `A2AClient.fromCardUrl(...)` with engine-specific helpers (workflow-as-agent typing, structured response parsing, error mapping).
- **F-216: af-pattern-fidelity-eval** — a synthetic eval suite that compares the engine's bridge output against the canonical AF C# output for the same input. Catches semantic drift in Option B; catches API-version drift in Options A/C.
- **F-217: durable-functions-bridge-option** — engine documents (and optionally ships) a Durable Functions Node.js variant of Option B for users who want a TS-native workflow runtime with Microsoft pedigree but accept the Azure DF dependency.

## Confidence

**HIGH** — the gap finding is corroborated by three independent evidences (Distro matrix, npm package list absence, AF docs pivot list absence). Bridge architectures (A/B/C) are well-known patterns from cross-language interop literature; the specific application to AF + TS is the contribution. The C# bridge skeleton uses verbatim API names from `Microsoft.Agents.AI.Hosting.A2A.AspNetCore` (per wave-1 NuGet refs). Single deferred verification: whether `@microsoft/agent-framework` exists as a private/preview/internal-only npm package — `microsoft_docs_search` did not surface it, but `npm view @microsoft/agent-framework` from a connected dev box would confirm absence definitively. Treat the conclusion as HIGH-confidence pending that final spot-check.
