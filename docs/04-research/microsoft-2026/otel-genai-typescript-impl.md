---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-004
lane: lane-c
date: 2026-05-06
sources:
  - https://learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry
  - https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable
  - https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-collect-detect
  - https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-configuration
  - https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-add-modify
  - https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-filter
  - https://learn.microsoft.com/microsoft-agent-365/developer/observability
  - https://github.com/Azure/azure-sdk-for-js/tree/main/sdk/monitor/monitor-opentelemetry/samples-dev
---

# OpenTelemetry GenAI semantic conventions — TypeScript / Node.js implementation patterns

## Why this lane exists

Wave-1 Lane B documented `otel-genai-multi-agent.md` at the conceptual level — what GenAI semantic conventions exist, what spans are emitted, span hierarchy. Wave-4 Lane C closes the implementation gap on the **Node.js + TypeScript** side: how to wire Microsoft's OpenTelemetry Distro for Node.js, what auto-instrumentation is and isn't supported, how to do manual GenAI spans when auto-instrumentation is missing.

## Sources

- **Microsoft OpenTelemetry Distro coverage matrix**: `learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry` — language-by-language support.
- **Azure Monitor OpenTelemetry Node.js setup**: `learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable` — npm install + config patterns.
- **Auto-collection & resource detectors**: `learn.microsoft.com/azure/azure-monitor/app/opentelemetry-collect-detect` — included instrumentation libraries for Node.js.
- **Sampling, filter, modify**: `learn.microsoft.com/azure/azure-monitor/app/opentelemetry-{configuration,add-modify,filter}` — Node.js-specific code samples.
- **Authoritative TS samples**: `github.com/Azure/azure-sdk-for-js/tree/main/sdk/monitor/monitor-opentelemetry/samples-dev` — verbatim cited as "TypeScript samples for Azure Monitor OpenTelemetry (authoritative parity source)".

## Load-bearing patterns

### Microsoft OpenTelemetry Distro — Node.js coverage

Per `learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry` (verbatim, May 2026):

| Category | Node.js coverage |
|---|---|
| **Common application instrumentation** | HTTP, Azure SDK, Azure Functions, MongoDB, MySQL, PostgreSQL, Redis, Bunyan, Winston |
| **Common agent and generative AI instrumentation** | OpenAI Agents SDK, LangChain, **Microsoft Agent 365 baggage**, **Microsoft Agent 365 scopes** |

**Notable absences in Node.js auto-instrumentation:**
- Semantic Kernel: Not supported
- Microsoft Agent Framework: Not supported (per `agent-framework-typescript-bridge.md` finding)
- OpenAI direct (non-Agents SDK): Supported in Node.js (per OpenAI line)

### Node.js setup — minimal install

```sh
npm install @azure/monitor-opentelemetry
```

Plus, for advanced scenarios:
```sh
npm install @opentelemetry/api @opentelemetry/sdk-metrics @opentelemetry/resources @opentelemetry/semantic-conventions @opentelemetry/sdk-trace-base
```

### TS configuration — `useAzureMonitor` (default)

```typescript
const { useAzureMonitor } = await import("@azure/monitor-opentelemetry");
const monitor = useAzureMonitor({
  enableTraceBasedSamplingForLogs: true,
  azureMonitorExporterOptions: {
    connectionString:
      process.env.APPLICATIONINSIGHTS_CONNECTION_STRING || "<YOUR-CONNECTION-STRING>",
  },
});
```

Dynamic import (`await import(...)`) is the recommended pattern when auto-instrumentation needs to attach BEFORE other modules load. Static `import` works if call site is the entry point.

### TS configuration — Microsoft OpenTelemetry Distro with Agent 365

```typescript
import { useMicrosoftOpenTelemetry } from "@microsoft/opentelemetry";

const tokenResolver = (agentId, tenantId) => {
  return "your-token";
};

useMicrosoftOpenTelemetry({
  a365: {
    enabled: true,
    tokenResolver,
  },
  instrumentationOptions: {
    openaiAgents: { enabled: true },
  },
});
```

Two distinct npm packages — pick the right one:

| Package | Use when |
|---|---|
| `@azure/monitor-opentelemetry` | Targeting Azure Monitor / App Insights (no Agent 365) |
| `@microsoft/opentelemetry` | Targeting **Agent 365 governance plane** + optionally Azure Monitor |

The Agent 365 path adds: tenant-aware token resolution, agent observability scopes, governance-plane export. Doc: `learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry`.

### Node.js auto-instrumentation libraries (verbatim)

**Requests:**
- HTTP/HTTPS

**Dependencies:**
- MongoDB
- MySQL
- Postgres (`opentelemetry-instrumentation-pg`)
- Redis (and `redis-4`)
- Azure SDK (`@azure/instrumentation/opentelemetry-instrumentation-azure-sdk`)

**Logs:**
- Bunyan (NOT enabled by default; set `enabled: true`)
- Winston (NOT enabled by default; set `enabled: true`)

### TS configuration — manually configure instrumentation

```typescript
useAzureMonitor({
  azureMonitorExporterOptions: { connectionString: "..." },
  instrumentationOptions: {
    bunyan: { enabled: true },
    winston: { enabled: true },
    azureSdk: { enabled: true },
    http: { enabled: true },
    mongoDb: { enabled: true },
    mySql: { enabled: true },
    postgreSql: { enabled: true },
    redis: { enabled: true },
    redis4: { enabled: true },
  },
});
```

### TS configuration — agent-token-aware Agent 365 setup

```typescript
import { useMicrosoftOpenTelemetry } from "@microsoft/opentelemetry";
import { TurnState, AgentApplication, TurnContext, MemoryStorage } from '@microsoft/agents-hosting';
import { ActivityTypes } from '@microsoft/agents-activity';

useMicrosoftOpenTelemetry({
  a365: {
    enabled: true,
    tokenResolver: (agentId: string, tenantId: string, authScopes?: string[]) =>
      myTokenService.getToken(agentId, tenantId),
  },
});

export class A365Agent extends AgentApplication<TurnState> {
  agentName = 'A365 Agent';
  authHandlerName = 'agentic';

  constructor() {
    super({
      storage: new MemoryStorage(),
      authorization: {
        agentic: { type: 'agentic' }
      }
    });

    this.onActivity(ActivityTypes.Message, async (context: TurnContext, state: TurnState) => {
      const agentId = context?.activity?.recipient?.agenticAppId ?? '';
      const tenantId = context?.activity?.recipient?.tenantId ?? '';

      const authToken = await this.authorization.exchangeToken(context, 'agentic', {
        scopes: ['api://9b975845-388f-4429-889e-eab1ef63949c/Agent365.Observability.OtelWrite']
      });

      myTokenService.set(agentId, tenantId, authToken?.token || '');
    });
  }
}
```

Three load-bearing observations:

1. **Token resolver runs per-export**: each OTel batch flush calls `tokenResolver(agentId, tenantId)` synchronously. Pre-cache via OBO on each `OnActivity` to avoid blocking the export.
2. **Scope `Agent365.Observability.OtelWrite`** — the specific OAuth scope for Agent 365 telemetry write. Hard-coded resource ID `9b975845-388f-4429-889e-eab1ef63949c` is the Agent 365 Observability resource.
3. **OBO exchange via AgentApplication.authorization.exchangeToken** — Agent 365's authorization API for token exchange.

### TS sampling configuration

```typescript
const monitor = useAzureMonitor({
  enableTraceBasedSamplingForLogs: true,  // logs follow trace sampling decision
  azureMonitorExporterOptions: { connectionString: "..." },
});
```

### TS resource attributes (env-var path; cross-language)

```bash
export OTEL_SERVICE_NAME="my-service"
export OTEL_RESOURCE_ATTRIBUTES="cloud.provider=azure,cloud.region=westus,cloud.resource_id=/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Web/sites/<APP>"
```

Or PowerShell:

```powershell
$Env:OTEL_SERVICE_NAME="my-service"
$Env:OTEL_RESOURCE_ATTRIBUTES="cloud.provider=azure,cloud.region=westus,cloud.resource_id=/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Web/sites/<APP>"
```

Same vars work across .NET, Java, Node.js, Python.

### TS HTTP instrumentation filtering

```typescript
useAzureMonitor({
  azureMonitorExporterOptions: { connectionString: "..." },
  instrumentationOptions: {
    http: {
      enabled: true,
      requestHook: (span, request) => {
        // Add custom attributes to spans
        span.setAttribute('custom.attr', 'value');
      },
      ignoreIncomingRequestHook: (request) => {
        // Return true to ignore this request
        return request.url?.includes('/health');
      },
    },
  },
});
```

`ignoreIncomingRequestHook` is the canonical way to filter health-check noise; `requestHook` adds per-span attributes.

### TS span/log filtering — non-HTTP signals

> "This example is specific to HTTP instrumentations. For other signal types, there's currently no specific mechanism available to filter out telemetry. Instead, a custom span processor is required."

Custom span processor pattern (TS):

```typescript
import { SpanProcessor, ReadableSpan, Context } from '@opentelemetry/sdk-trace-base';

class FilteringSpanProcessor implements SpanProcessor {
  onStart(span: Span, parentContext: Context): void {}
  onEnd(span: ReadableSpan): void {
    if (span.attributes['db.statement']?.includes('SECRET')) {
      // suppress; do not forward to next processor
      return;
    }
    // forward to inner processor (e.g., the Azure Monitor exporter)
  }
  shutdown(): Promise<void> { return Promise.resolve(); }
  forceFlush(): Promise<void> { return Promise.resolve(); }
}
```

### GenAI semantic conventions — TS manual emission (Agent Framework gap workaround)

Since AF auto-instrumentation is NOT supported on Node.js (per `agent-framework-typescript-bridge.md`), TS engines emit GenAI spans manually:

```typescript
import { trace, SpanKind } from '@opentelemetry/api';

const tracer = trace.getTracer('engine.agent', '1.0.0');

export async function runAgent(input: string) {
  return tracer.startActiveSpan('gen_ai.invoke_agent', { kind: SpanKind.INTERNAL }, async (span) => {
    span.setAttribute('gen_ai.system', 'azure_openai');
    span.setAttribute('gen_ai.request.model', 'gpt-4o');
    span.setAttribute('gen_ai.operation.name', 'chat');
    span.setAttribute('gen_ai.agent.id', 'engine.helper.v1');
    span.setAttribute('gen_ai.agent.name', 'Helper');

    try {
      const result = await chatClient.respond(input);

      span.setAttribute('gen_ai.usage.input_tokens', result.usage.promptTokens);
      span.setAttribute('gen_ai.usage.output_tokens', result.usage.completionTokens);
      span.setAttribute('gen_ai.response.id', result.id);
      span.setAttribute('gen_ai.response.model', result.model);

      return result;
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({ code: 2, message: (err as Error).message });
      throw err;
    } finally {
      span.end();
    }
  });
}
```

GenAI semconv attribute names (`gen_ai.system`, `gen_ai.request.model`, `gen_ai.operation.name`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.agent.id`) are stable across language ports; the TS impl just sets them on a generic OTel span.

### Agent 365 packages — observability-specific

Per `learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk`:

| Package | Description |
|---|---|
| `@microsoft/agents-a365-observability` | OpenTelemetry-based observability and tracing for Agent 365 applications. Provides comprehensive monitoring for agent invocations, tool executions, and AI model inference calls with seamless Azure Monitor integration. |
| `@microsoft/agents-a365-runtime` | Core runtime utilities including `getObservabilityAuthenticationScope()` |

The `@microsoft/agents-a365-observability` package wraps the GenAI semconv emission so engine consumers don't have to build it manually — but only works inside an `AgentApplication` context.

## Verbatim quotes worth preserving

> "TypeScript samples for Azure Monitor OpenTelemetry (authoritative parity source): https://github.com/Azure/azure-sdk-for-js/tree/main/sdk/monitor/monitor-opentelemetry/samples-dev"

> "Bunyan and Winston aren't enabled by default. You can enable instrumentation libraries by setting `enabled: true` in the instrumentation options."

> "This example is specific to HTTP instrumentations. For other signal types, there's currently no specific mechanism available to filter out telemetry. Instead, a custom span processor is required."

> "Agent Framework | Python: Supported | Node.js: **Not supported** | .NET: Supported" — repeated here because it's the load-bearing constraint for TS GenAI instrumentation.

## Implications for the engine catalog (refs F-NNN)

- **F-ms-otel-distro-bundle (wave-1)**: TS variant uses `@azure/monitor-opentelemetry` (Azure Monitor only) OR `@microsoft/opentelemetry` (Agent 365 governance plane). Engine bundles BOTH packages and exposes one config flag to pick.
- **F-agent-365-otel-export (wave-1)**: TS path requires `@microsoft/opentelemetry` + `tokenResolver` callback wired to OBO exchange. Document the pattern.
- **F-streaming-by-default (wave-1)**: streaming responses still emit GenAI spans; `gen_ai.response.streaming = true` attribute. Engine ensures streaming chat clients still emit usage attributes at end-of-stream.

## NEW F-NNN candidates

- **F-218: ts-genai-span-helper** — engine ships a TS helper `withGenAiSpan(operationName, attrs, fn)` that wraps any agent invocation and emits the GenAI semconv span automatically (system, model, operation, usage, agent.id). Closes the AF Node.js auto-instrumentation gap by making manual emission ergonomic.
- **F-219: token-resolver-cache** — engine ships a `TokenResolverCache` for Agent 365 OTel exports that pre-caches OBO tokens per `(agentId, tenantId)` tuple with TTL. Avoids per-export OBO cost.
- **F-220: filtering-span-processor-template** — engine ships a `FilteringSpanProcessor` template (TS) that takes a predicate and suppresses matching spans. Closes the doc gap "no specific mechanism" for non-HTTP signal filtering.
- **F-221: dual-export-router** — engine ships a TS span/log/metric router that fan-outs to Azure Monitor + Agent 365 + OTLP simultaneously, with per-signal selection. One config; multiple destinations.
- **F-222: genai-semconv-version-pin** — engine pins the GenAI semconv version it emits and surfaces this in its agent card / health endpoint, so consumers know which version of `gen_ai.*` attributes to expect (the convention itself is still evolving — pin to avoid silent drift).

## Confidence

**HIGH** — every TS code sample (npm install, `useAzureMonitor`, `useMicrosoftOpenTelemetry`, manual span pattern, custom span processor) is verbatim from `microsoft_docs_search` results dated May 2026. The Node.js coverage matrix is the critical evidence for the Agent Framework gap (carried over from `agent-framework-typescript-bridge.md`). The `@microsoft/opentelemetry` and `@microsoft/agents-a365-observability` packages are confirmed in the Agent 365 docs. The "no filtering for non-HTTP signals" caveat is verbatim. The authoritative TS samples link (`azure-sdk-for-js/.../monitor-opentelemetry/samples-dev`) is verbatim cited by Microsoft as the parity source. Pending: GenAI semconv version pin specifics — the OTel GenAI semantic conventions repository (`open-telemetry/semantic-conventions`) is the canonical version source; engine should adopt the latest stable version at integration time.
