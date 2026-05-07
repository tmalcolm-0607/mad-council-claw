---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/azure/foundry/observability/concepts/trace-agent-concept
  - https://learn.microsoft.com/azure/foundry-classic/how-to/develop/trace-agents-sdk
  - https://learn.microsoft.com/agent-framework/agents/observability
  - https://learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry
  - https://learn.microsoft.com/dotnet/api/microsoft.agents.ai.opentelemetryagent
  - https://learn.microsoft.com/microsoft-agent-365/builder/observability
  - https://opentelemetry.io/docs/specs/semconv/gen-ai/
  - https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/
---

# OpenTelemetry GenAI semantic conventions for multi-agent

## Sources

- Foundry agent tracing overview — `learn.microsoft.com/azure/foundry/observability/concepts/trace-agent-concept`
- Foundry classic trace agents SDK — `learn.microsoft.com/azure/foundry-classic/how-to/develop/trace-agents-sdk`
- Agent Framework observability — `learn.microsoft.com/agent-framework/agents/observability`
- Microsoft OpenTelemetry Distro — `learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry`
- OpenTelemetryAgent class API ref — `learn.microsoft.com/dotnet/api/microsoft.agents.ai.opentelemetryagent`
- Copilot Studio observability — `learn.microsoft.com/microsoft-agent-365/builder/observability`
- OTel GenAI semantic conventions — `opentelemetry.io/docs/specs/semconv/gen-ai/`
- OTel GenAI agent spans — `opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/`

## Load-bearing patterns

### Microsoft + Cisco Outshift collaboration

Verbatim from Foundry agent tracing overview:

> "Microsoft, in collaboration with Cisco Outshift, has introduced new semantic conventions for multi-agent systems, built on OpenTelemetry and W3C Trace Context. These conventions standardize telemetry for multi-agent workflows, enabling consistent logging of metrics for quality, performance, safety, and cost, including tool invocations and collaboration."

These extensions are integrated into:
1. Foundry
2. Microsoft Agent Framework
3. LangChain
4. LangGraph
5. OpenAI Agents SDK
6. Semantic Kernel (per the classic Foundry doc)

### The semantic conventions table (verbatim)

| Type | Context/Parent Span | Name/Attribute/Event | Purpose |
|---|---|---|---|
| **Span** | — | `execute_task` | Captures task planning and event propagation; insights into how tasks are decomposed and distributed |
| **Child Span** | `invoke_agent` | `agent_to_agent_interaction` | Traces communication between agents |
| **Child Span** | `invoke_agent` | `agent.state.management` | Effective context, short or long term memory management |
| **Child Span** | `invoke_agent` | `agent_planning` | Logs the agent's internal planning steps |
| **Child Span** | `invoke_agent` | `agent_orchestration` | Captures agent-to-agent orchestration |
| **Attribute** | `invoke_agent` | `tool_definitions` | Describes the tool's purpose or configuration |
| **Attribute** | `invoke_agent` | `llm_spans` | Records model call spans |
| **Attribute** | `execute_tool` | `tool.call.arguments` | Logs the arguments passed during tool invocation |
| **Attribute** | `execute_tool` | `tool.call.results` | Records the results returned by the tool |
| **Event** | — | `Evaluation` (name, error.type, label) | Enables structured evaluation of agent performance and decision-making |

### Agent Framework adoption

Per `agent-framework/agents/observability`:

> "Agent Framework integrates with OpenTelemetry, and more specifically Agent Framework emits traces, logs, and metrics according to the OpenTelemetry GenAI Semantic Conventions."

`OpenTelemetryAgent` class (in `Microsoft.Agents.AI` namespace) provides a delegating `AIAgent` implementation that emits the OTel GenAI Semantic Conventions for Generative AI systems v1.37.

```
public sealed class OpenTelemetryAgent : Microsoft.Agents.AI.DelegatingAIAgent, IDisposable
```

### Microsoft OpenTelemetry Distro (the unified product)

Per `microsoft-agent-365/developer/microsoft-opentelemetry`:

> "The Microsoft OpenTelemetry Distro combines standard OpenTelemetry pipelines with Microsoft-curated instrumentation. The Distro can collect application telemetry, infrastructure telemetry, and agent or generative AI telemetry depending on language and configuration."

Coverage matrix:

| Language | Common application instrumentation | Common agent + GenAI instrumentation |
|---|---|---|
| Python | OTel resources, processors, readers, logging, metrics, traces | Semantic Kernel, OpenAI Agents SDK, Agent Framework, LangChain, **Microsoft Agent 365 baggage + scopes** |
| Node.js | HTTP, Azure SDK, Azure Functions, MongoDB, MySQL, PostgreSQL, Redis, Bunyan, Winston | OpenAI Agents SDK, LangChain, Microsoft Agent 365 baggage + scopes |
| .NET | ASP.NET Core, HttpClient, SQL Client, Azure SDK, resource detection, metrics, logs | Semantic Kernel, OpenAI + Azure OpenAI, Agent Framework, Microsoft Agent 365 baggage + scopes |

**The "Microsoft Agent 365 baggage + scopes"** is the cross-cutting context propagation mechanism. Set baggage (tenant ID, agent ID) BEFORE the instrumented framework creates spans.

### Exporters

| Exporter | Use case |
|---|---|
| Azure Monitor / Application Insights | Default cloud destination |
| **Microsoft Agent 365** | The governance plane consumes the same OTel signal |
| OTLP (gRPC + HTTP) | Open telemetry protocol — anywhere |
| Console output | Development |

### Copilot Studio observability (specific shape)

Per `microsoft-agent-365/builder/observability`, Copilot Studio captures two GenAI conventions:

#### Invoke agent
- Agent identification (ID, name, Entra ID, type)
- User identification (when on-behalf-of flow)
- Input message (sensitive data redacted)
- Tenant + environment IDs
- Start + end timestamps

#### Execute tool
- Agent identification
- Tool ID + name
- Tool arguments (sensitive data redacted)
- User identification
- Tenant + environment IDs
- Start + end timestamps

Truncation rules:
- Output messages
- Tool arguments
- Tool response (`gen_ai.event.content`)
- Agent description

Caveats:
- Telemetry only for **authenticated sessions**
- Multi-tenant agents excluded
- Agents with names > 42 chars not logged

### W3C Trace Context — the underlying standard

The Microsoft+Outshift extensions ride on top of W3C Trace Context. This is the same standard used for distributed tracing across web services. **Implication:** agent traces correlate with web app traces, database traces, etc. — single trace ID across the entire interaction.

### Key spans in v1.37 conventions (the OTel side)

The OTel GenAI agent spans spec (`opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/`) adds the agent-specific spans on top of the base GenAI conventions. Microsoft's OpenTelemetryAgent emits per v1.37.

## Verbatim quotes worth preserving

> "These conventions standardize telemetry for multi-agent workflows, enabling consistent logging of metrics for quality, performance, safety, and cost, including tool invocations and collaboration."

> "By using Foundry, customers can get unified observability for agentic systems built using any of these frameworks."

> "All telemetry respects privacy boundaries. Sensitive user data in messages and tool inputs and outputs is redacted and not visible to administrators." (Copilot Studio observability)

## Implications for the engine catalog (refs F-NNN)

- **F-otel-genai-default** — engine emits OTel GenAI semantic conventions by default. NOT optional. Use `OpenTelemetryAgent` (or equivalent in TS/Python) as a delegating wrapper around every agent invocation.
- **F-multi-agent-spans** — engine MUST emit `execute_task`, `invoke_agent`, `agent_to_agent_interaction`, `agent.state.management`, `agent_planning`, `agent_orchestration` spans. This is the table from Microsoft+Outshift conventions.
- **F-baggage-propagation** — engine sets baggage (tenant ID, agent ID, channel ID, thread ID) BEFORE creating spans. Inherited downstream by AF / SK / LangChain spans automatically.
- **F-pii-redaction-in-telemetry** — engine inherits Copilot Studio's redaction discipline: sensitive data in messages + tool args + tool results redacted before emit. Field-level allow-list (not block-list).
- **F-truncation-policy** — adopt Copilot Studio truncation rules (output messages, tool args, tool response, agent description) to avoid telemetry-blob inflation.
- **F-evaluation-events** — engine emits OTel `Evaluation` events per the convention (name, error.type, label) for every quality-graded outcome.
- **F-trace-context-w3c** — agent traces correlate with web app traces via W3C Trace Context. Single trace ID across UI → engine → tools.

## NEW F-NNN candidates (if any)

- **F-NEW: ms-otel-distro-bundle** — engine ships a Microsoft OpenTelemetry Distro pre-configured bundle. Drop-in for new consumer projects.
- **F-NEW: agent-365-otel-export** — engine's OTel signal can be routed to Agent 365 governance plane (in addition to App Insights / OTLP / console). Single export config.
- **F-NEW: span-naming-helper** — engine provides a typed helper that ensures span names match the Microsoft+Outshift convention exactly (no drift via free-form span names).

## Confidence

**HIGH** — the Microsoft+Cisco Outshift convention table is documented identically in TWO Microsoft Learn pages (Foundry observability + Foundry classic trace-agents-sdk). The OTel `OpenTelemetryAgent` class is in the published .NET API ref. The Microsoft OpenTelemetry Distro page lists exact instrumentation packages per language. Copilot Studio observability spec is the most concrete real-world implementation example. The OTel GenAI semantic conventions are explicitly marked **experimental and subject to change** per the OTel spec — flag this in any engine doc that promises stability.
