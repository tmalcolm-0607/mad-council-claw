---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-004
lane: lane-c
date: 2026-05-06
sources:
  - https://learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk
  - https://learn.microsoft.com/javascript/api/agent365-sdk-node/agent365-overview
  - https://learn.microsoft.com/microsoft-agent-365/developer/quickstart-nodejs-langchain
  - https://learn.microsoft.com/microsoft-agent-365/developer/quickstart-nodejs-claude
  - https://learn.microsoft.com/microsoft-agent-365/developer/samples
  - https://learn.microsoft.com/microsoft-agent-365/developer/notification
  - https://learn.microsoft.com/microsoft-agent-365/developer/microsoft-opentelemetry
  - https://github.com/microsoft/Agent365-Samples/tree/main/nodejs
  - https://github.com/microsoft/Agent365-nodejs
---

# Microsoft Agent 365 SDK — TypeScript availability

## Why this lane exists

Wave-1 Lane B documented Agent 365 conceptually (`agent-365-sdk.md`) and named Claude Code SDK as a supported framework, but did not enumerate which language ports of the Agent 365 SDK exist. Wave-4 Lane C confirms: **Agent 365 SDK has full Node.js / TypeScript parity with .NET and Python.** Six `@microsoft/agents-a365-*` npm packages (v1.0.0) cover the full surface — observability, notifications, runtime utilities, tooling, and framework-specific extensions for Claude / OpenAI / LangChain.

## Sources

- **Agent 365 SDK overview**: `learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk` — package matrix per language.
- **Agent 365 SDK for JavaScript v1.0.0 reference**: `learn.microsoft.com/javascript/api/agent365-sdk-node/agent365-overview` — official TS landing page.
- **Node.js LangChain quickstart**: `learn.microsoft.com/microsoft-agent-365/developer/quickstart-nodejs-langchain` — full sample walkthrough.
- **Node.js Claude quickstart**: `learn.microsoft.com/microsoft-agent-365/developer/quickstart-nodejs-claude`.
- **Sample agent gallery**: `learn.microsoft.com/microsoft-agent-365/developer/samples` — JavaScript samples for Claude / LangChain / Devin / n8n / Perplexity / Vercel.
- **GitHub repos**: `github.com/microsoft/Agent365-nodejs` (SDK source), `github.com/microsoft/Agent365-Samples/tree/main/nodejs` (samples).

## Load-bearing patterns

### Definitive finding: full TS parity

Per `learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk` (verbatim, May 2026):

> "The Agent 365 SDK packages for JavaScript are on NPM. All packages begin with **`@microsoft/agents-a365-`**."

| Package | Description |
|---|---|
| `@microsoft/agents-a365-notifications` | Notification services and models for handling user notifications. Type-safe handling for email, Word comments, and other collaboration scenarios. |
| `@microsoft/agents-a365-observability` | OpenTelemetry-based observability and tracing. Comprehensive monitoring for agent invocations, tool executions, and AI model inference calls with seamless Azure Monitor integration. |
| `@microsoft/agents-a365-runtime` | Core runtime utilities — authentication, authorization, and Power Platform API discovery for enterprise-ready AI agents. |
| `@microsoft/agents-a365-tooling` | Core tooling functionality for MCP (Model Context Protocol) tool server management. Foundation for discovering, registering, and managing tool servers across different AI frameworks. |
| `@microsoft/agents-a365-tooling-extensions-claude` | Claude SDK integration — auto tool discovery and registration for Anthropic's Claude. |
| `@microsoft/agents-a365-tooling-extensions-openai` | OpenAI Agents SDK integration — auto MCP tool registration. |
| `@microsoft/agents-a365-tooling-extensions-langchain` | LangChain integration — auto registration as DynamicStructuredTool instances. |

**Source repos:**
- Agent365-dotnet: `github.com/microsoft/Agent365-dotnet`
- Agent365-python: `github.com/microsoft/Agent365-python`
- Agent365-nodejs: `github.com/microsoft/Agent365-nodejs` ← **TS parity confirmed**

**Sample repos:**
- `github.com/microsoft/Agent365-Samples/tree/main/nodejs` (JS/TS samples)

### Sample matrix (per `learn.microsoft.com/microsoft-agent-365/developer/samples`)

JavaScript samples cover MORE frameworks than other languages:

| Framework | Sample (JS) |
|---|---|
| Claude Agent SDK | Yes — `Claude Sample Agent` |
| LangChain.js | Yes — `LangChain Sample Agent` |
| Devin API | Yes — `Devin Sample Agent` |
| n8n | Yes — `n8n Sample Agent` |
| Perplexity SDK | Yes — `Perplexity Sample Agent` |
| Vercel AI SDK | Yes — `Vercel Sample Agent` |

For comparison:
- **Python** has 2 framework samples: Agent Framework, OpenAI Agents SDK.
- **.NET** has 1: Semantic Kernel.

**JavaScript is the framework-richest of the three Agent 365 sample languages.** This is a meaningful finding — third-party AI framework integration goes JS-first; .NET/Python lag in sample coverage.

### TS class-based agent — A365Agent pattern

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
  isApplicationInstalled: boolean = true;
  termsAndConditionsAccepted: boolean = true;
  agentName = 'A365 Agent';
  authHandlerName = 'agentic';

  constructor() {
    const useAgenticAuth = process.env.USE_AGENTIC_AUTH === 'true';

    super({
      storage: new MemoryStorage(),
      ...(useAgenticAuth && {
        authorization: {
          agentic: {
            type: 'agentic',
          }
        }
      })
    });

    this.onActivity(ActivityTypes.Message, async (context: TurnContext, state: TurnState) => {
      await this.handleAgentMessageActivity(context, state);
    });
  }

  async handleAgentMessageActivity(turnContext: TurnContext, _state: TurnState): Promise<void> {
    if (process.env.USE_AGENTIC_AUTH !== 'true') return;

    const agentId = turnContext?.activity?.recipient?.agenticAppId ?? '';
    const tenantId = turnContext?.activity?.recipient?.tenantId ?? '';

    const authToken = await this.authorization.exchangeToken(turnContext, 'agentic', {
      scopes: ['api://9b975845-388f-4429-889e-eab1ef63949c/Agent365.Observability.OtelWrite']
    });

    myTokenService.set(agentId, tenantId, authToken?.token || '');
  }
}
```

Notable shape:
- Inherits `AgentApplication<TurnState>` from `@microsoft/agents-hosting`.
- `agenticAppId` + `tenantId` come from `context.activity.recipient` — these are A365-specific extensions to the Activity schema.
- `authorization.exchangeToken(context, 'agentic', { scopes: [...] })` — OBO flow for service-to-service tokens.
- Class fields `isApplicationInstalled` / `termsAndConditionsAccepted` / `agentName` / `authHandlerName` are A365 lifecycle markers consumed by Agent 365 governance plane.

### TS notification handler

```typescript
import { AgentApplication, TurnContext, TurnState } from '@microsoft/agents-hosting';
import { ActivityTypes } from '@microsoft/agents-activity';
import {
  AgentNotificationActivity,
  NotificationType
} from '@microsoft/agents-a365-notifications';

constructor() {
   super();

   this.onAgentNotification("agents:*", async(context, state, activity) => {
      await this.handleAgentNotificationActivity(context, state, activity);
   });
}

async handleAgentNotificationActivity(context, state, activity) {
   await context.sendActivity("Received an AgentNotification!");
}
```

`onAgentNotification("agents:*", handler)` — wildcard subscription to any A365 notification with prefix `agents:*`. The `@microsoft/agents-a365-notifications` package adds:
- `AgentNotificationActivity` type
- `NotificationType` enum (categorizes email / Word-comments / collaboration events)

This is **distinct** from `OnActivity(ActivityTypes.*)` — Agent Notifications are A365-governance signals, separate from user-conversation activities.

### TS observability authentication scope

```typescript
import { getObservabilityAuthenticationScope } from '@microsoft/agents-a365-runtime';

agentApplication.onActivity(
  ActivityTypes.Message,
  async (context: TurnContext, state: ApplicationTurnState) => {
    const aauAuthToken = await agentApplication.authorization.exchangeToken(context, 'agentic', {
      scopes: getObservabilityAuthenticationScope()
    });
    // cache this auth token and return via token resolver
  }
);
```

`getObservabilityAuthenticationScope()` from `@microsoft/agents-a365-runtime` returns the canonical observability scope string. **Use this rather than hard-coding `'api://9b975845-388f-4429-889e-eab1ef63949c/Agent365.Observability.OtelWrite'`** — the constant may be lifted out of source code with provider-supplied helpers.

### TS install/uninstall lifecycle

```typescript
this.onActivity(ActivityTypes.InstallationUpdate, async (context: TurnContext, state: TurnState) => {
    const from = context.activity?.from;
    console.log(`InstallationUpdate received — Action: '${context.activity.action ?? "(none)"}'`);

    if (context.activity.action === 'add') {
        await context.sendActivity('Thank you for hiring me!');
    } else if (context.activity.action === 'remove') {
        await context.sendActivity('Thank you for your time, I enjoyed working with you.');
    }
}
```

`InstallationUpdate` activity type — Agent 365 emits these when an enterprise user installs/uninstalls the agent. Captures the consent flow + offboarding moment.

### LangChain quickstart prerequisites (verbatim)

For `learn.microsoft.com/microsoft-agent-365/developer/quickstart-nodejs-langchain`:

> "Prerequisites:
> 1. .NET 8.0 (recommended) — for VS Code tooling
> 2. Node.js (version 18 or higher)
> 3. LangChain
> 4. Agents Playground
> 5. Access to Npm
> 6. Access to GitHub
> 7. An existing AI Agent project (uses Agent 365 sample agent from M365 Agents Toolkit / ATK in VS Code)
> 8. A365 CLI
> 9. Agent Identity Auth"

**Notable:**
- A365 CLI is required separately. Documented at `learn.microsoft.com/microsoft-agent-365/developer/agent-365-cli`.
- Microsoft 365 Agents Toolkit (ATK) extension for VS Code is the scaffolding entry point.
- Node.js 18+ — but the M365 Agents SDK package itself targets Node.js 20+. Recommend Node.js 22 LTS.

### A365 CLI (companion tooling)

The A365 CLI is part of the Agent 365 developer experience. Per `learn.microsoft.com/microsoft-agent-365/developer/agent-365-cli` (referenced from quickstart). Install + use are TypeScript-friendly (the CLI is itself a Node.js binary).

### Comparison: M365 Agents SDK vs. Agent 365 SDK

These are TWO different SDKs (easy to confuse):

| | M365 Agents SDK | Agent 365 SDK |
|---|---|---|
| npm prefix | `@microsoft/agents-*` | `@microsoft/agents-a365-*` |
| Scope | Building agents (Activity routing, hosting, storage) | Enterprise capabilities ON TOP OF M365 Agents SDK (observability, notifications, runtime, tooling) |
| Layer | Foundation | Enterprise extensions |
| Required? | Yes (any agent) | Optional (only for enterprise / governance / Agent 365 catalog) |
| Repos | `microsoft/Agents` | `microsoft/Agent365-{dotnet,python,nodejs}` |

**Architecturally**: Agent 365 SDK builds on top of M365 Agents SDK. An Agent 365 agent is a `AgentApplication` (M365 SDK) instance with `@microsoft/agents-a365-*` packages added.

## Verbatim quotes worth preserving

> "The Microsoft Agent 365 SDK extends the Microsoft 365 Agents SDK with enterprise-grade capabilities for building sophisticated agents."

> "The Microsoft Agent 365 SDK focuses on three core areas:
> 1. Observability ...
> 2. Notifications ...
> 3. Tooling ..."

> "Find JavaScript sample code using this SDK here: Agent365-Samples repository, https://github.com/microsoft/Agent365-Samples/tree/main/nodejs" — JavaScript is a first-class sample target.

## Implications for the engine catalog (refs F-NNN)

- **F-claude-code-sdk-bridge (wave-1)**: confirmed via `@microsoft/agents-a365-tooling-extensions-claude` + Claude Sample Agent. Engine bridging Claude Code SDK to Agent 365 has a documented path.
- **F-agent-365-control-plane (wave-1)**: TS engine implementing the control-plane mapping uses `@microsoft/agents-a365-runtime` + `@microsoft/agents-a365-tooling`.
- **F-agent-365-otel-export (wave-1)**: confirmed via `@microsoft/agents-a365-observability` + `useMicrosoftOpenTelemetry({ a365: { enabled: true, tokenResolver } })`.
- **F-blueprint-as-kit-config (wave-1)**: TS path uses `@microsoft/agents-a365-tooling` for blueprint registration.

## NEW F-NNN candidates

- **F-223: a365-agent-template** — engine ships a TS template that combines `@microsoft/agents-hosting` (M365 SDK) + all four `@microsoft/agents-a365-*` core packages (notifications + observability + runtime + tooling) wired with sane defaults. One `npm init` to enterprise-ready agent.
- **F-224: a365-tooling-extension-bridge** — engine ships a generic TS-side tooling-extension contract that any third-party AI framework can implement (analog to `@microsoft/agents-a365-tooling-extensions-{claude,openai,langchain}`). Engine becomes A365-tooling-discoverable for any framework, not just the three Microsoft has shipped extensions for.
- **F-225: a365-cli-integration** — engine ships an A365 CLI plugin (JS-based) that exposes engine commands via the A365 CLI surface. Users running `a365 ...` from the M365 admin / dev box get engine commands without installing a separate engine CLI.
- **F-226: a365-vs-m365-disambiguator** — engine documents the M365 Agents SDK ↔ Agent 365 SDK distinction prominently (CLAUDE.md, README, init wizard). The naming similarity is a documented confusion source. Engine helps users pick the right layer.
- **F-227: a365-installation-update-router** — engine maps `ActivityTypes.InstallationUpdate.action ∈ {'add', 'remove'}` to MAD.Council channel `welcome` / `archive` semantics. Closes Agent 365 enterprise lifecycle ↔ Council channel-lifecycle binding.
- **F-228: a365-notification-router** — engine routes `onAgentNotification('agents:*', ...)` events to specific MAD.Council threads based on `NotificationType` enum (email → email-thread, Word-comments → comment-thread, etc.). Bidirectional: Council can also synthesize and emit AgentNotifications to A365 governance.

## Confidence

**HIGH** — the seven `@microsoft/agents-a365-*` package list is verbatim from `learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk` (May 2026). The Agent365-nodejs GitHub repo is verbatim cited at `github.com/microsoft/Agent365-nodejs`. The TS sample list (Claude/LangChain/Devin/n8n/Perplexity/Vercel) is verbatim from `learn.microsoft.com/microsoft-agent-365/developer/samples`. Code samples (`A365Agent` class, `onAgentNotification`, `getObservabilityAuthenticationScope`, `InstallationUpdate` handler) are verbatim from `microsoft_code_sample_search` results. The Python list (Agent Framework + OpenAI Agents) and .NET list (Semantic Kernel) confirm JavaScript has the broadest framework sample coverage. **Wave-1 Lane B's question "does Agent 365 SDK have a TS port" is answered: yes, with full parity AND broader sample coverage than other languages.**
