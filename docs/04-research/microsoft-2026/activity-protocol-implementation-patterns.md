---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-004
lane: lane-c
date: 2026-05-06
sources:
  - https://learn.microsoft.com/microsoft-365/agents-sdk/agent-application
  - https://learn.microsoft.com/javascript/api/@microsoft/agents-activity/
  - https://learn.microsoft.com/dotnet/api/microsoft.agents.builder.app.agentapplication.onactivity
  - https://learn.microsoft.com/microsoft-365/agents-sdk/quickstart
  - https://learn.microsoft.com/microsoft-365/agents-sdk/bf-migration-nodejs
  - https://learn.microsoft.com/microsoft-365/agents-sdk/activity-protocol
---

# Activity Protocol — implementation patterns deep-dive (TS + C#)

## Why this lane exists

Wave-1 Lane B documented Activity Protocol's *spec shape* (`activity-protocol.md`). Wave-1 also flagged that **TS samples were sparse**. Wave-4 Lane C closes that gap by enumerating concrete `OnActivity` / `onActivity` implementation patterns in TypeScript AND C# from `microsoft_code_sample_search` + `microsoft_docs_search` (May 2026). Result: TS coverage is now strong — `@microsoft/agents-hosting` + `@microsoft/agents-activity` + `@microsoft/agents-hosting-express` is a fully-functional TS implementation surface.

## Sources

- **TS API reference**: `learn.microsoft.com/javascript/api/@microsoft/agents-activity/` — package entry point.
- **TS quickstart**: `learn.microsoft.com/microsoft-365/agents-sdk/quickstart` — node + TS echo agent.
- **TS migration patterns**: `learn.microsoft.com/microsoft-365/agents-sdk/bf-migration-nodejs` — Bot Framework → Agents SDK migration patterns (most TS samples in docs).
- **TS AgentApplication routing**: `learn.microsoft.com/microsoft-365/agents-sdk/agent-application` — `onActivity` / `onMessage` / `onConversationUpdate` routing.
- **C# API reference**: `learn.microsoft.com/dotnet/api/microsoft.agents.builder.app.agentapplication.onactivity` — 4 overloads (string, Regex, RouteSelector, MultipleRouteSelector).
- **Activity Protocol spec**: `learn.microsoft.com/microsoft-365/agents-sdk/activity-protocol` — schema + activity types.

## Load-bearing patterns

### TypeScript: full implementation surface (wave-1 gap closed)

The TS package layout per `learn.microsoft.com/javascript/api/overview/agents-overview`:

| Package | Role |
|---|---|
| `@microsoft/agents-activity` | Types and validators implementing the Activity protocol spec |
| `@microsoft/agents-hosting` | Classes to implement and host agents (`AgentApplication`, `TurnContext`, `MemoryStorage`) |
| `@microsoft/agents-hosting-express` | `startServer` method to host an agent in Express |
| `@microsoft/agents-hosting-dialogs` | Dialog hosting |
| `@microsoft/agents-hosting-storage-blob` | Azure Blob storage extension |
| `@microsoft/agents-hosting-storage-cosmos` | Cosmos DB storage extension |
| `@microsoft/agents-copilotstudio-client` | Direct-to-Engine client for Copilot Studio agents |

**Environment requirement (verbatim):** "The packages should target node20 or greater, and can be used from JavaScript using CommonJS or ES6 modules, or from TypeScript."

### TS quickstart pattern (canonical 5-line agent)

```typescript
import { AgentApplication, MemoryStorage, TurnContext, TurnState } from '@microsoft/agents-hosting'
import { startServer } from '@microsoft/agents-hosting-express'

const app = new AgentApplication<TurnState>({ storage: new MemoryStorage() })

app.onConversationUpdate('membersAdded', async (context: TurnContext) => {
    await context.sendActivity('Hello! How can I help you?')
})

app.onActivity('message', async (context: TurnContext, state: TurnState) => {
    await context.sendActivity(`You said: ${context.activity.text}`)
})

startServer(app)
```

This is functionally equivalent to the C# `OnActivity(ActivityTypes.Message, ...)` shape — wave-1 Lane B's claim that "TypeScript samples are sparse" was over-conservative. The TS shape exists and is canonical.

### TS class-based AgentApplication subclass

```typescript
import { AgentApplication, MemoryStorage, MessageFactory } from '@microsoft/agents-hosting'

class MyAgent extends AgentApplication {
    constructor() {
        super({ storage: new MemoryStorage() })
        this.setupRoutes()
    }

    setupRoutes() {
        this.onMessage('/help', this.handleHelp)
        this.onMessage('/status', this.handleStatus)
        this.onMessage('/reset', this.handleReset)
        this.onActivity('message', this.handleDefault)
        this.onConversationUpdate('membersAdded', this.handleWelcome)
    }

    handleHelp = async (context, state) => { /* ... */ }
    handleDefault = async (context, state) => {
        const messageCount = (state.conversation.messageCount ?? 0) + 1
        state.conversation.messageCount = messageCount
        await context.sendActivity(MessageFactory.text(`Echo: ${context.activity.text} (Message #${messageCount})`))
    }
}

export default new MyAgent()
```

### TS InstallationUpdate handler (Agent 365)

```typescript
this.onActivity(ActivityTypes.InstallationUpdate, async (context: TurnContext, state: TurnState) => {
    const from = context.activity?.from
    if (context.activity.action === 'add') {
        await context.sendActivity('Thank you for hiring me!')
    } else if (context.activity.action === 'remove') {
        await context.sendActivity('Thank you for your time.')
    }
})
```

`ActivityTypes.InstallationUpdate` is a new (2026) activity type for Agent 365 enterprise install/uninstall lifecycle events. Not present in classic Bot Framework; specific to M365 Agents SDK.

### TS Express manual hosting (when you can't use `startServer`)

```typescript
import express from 'express'
import { CloudAdapter, authorizeJWT, AuthConfiguration } from '@microsoft/agents-hosting'

const authConfig: AuthConfiguration = loadAuthConfigFromEnv()
const adapter = new CloudAdapter(authConfig)
const expressApp = express()

expressApp.use(express.json())
expressApp.use(authorizeJWT(authConfig))

expressApp.post('/api/messages', async (req, res) => {
    await adapter.process(req, res, async (context) => {
        await app.run(context)
    })
})
```

`/api/messages` is the canonical inbound URL. JWT authorization via `authorizeJWT` is mandatory for Bot Service traffic.

### C# OnActivity — 4 overloads (most flexible signature surface)

Per `Microsoft.Agents.Builder.dll v1.4.83`:

| Overload | Selector |
|---|---|
| `OnActivity(string type, ...)` | Exact activity type string |
| `OnActivity(Regex typePattern, ...)` | Regex match against activity type |
| `OnActivity(RouteSelector routeSelector, ...)` | Custom function `(context) => bool` |
| `OnActivity(MultipleRouteSelector, ...)` | Combination of String + Regex + RouteSelector |

All overloads accept `rank` (UInt16 0..65535 — order of evaluation), `autoSignInHandlers` (string[]), `isAgenticOnly` (bool — gate to agentic requests only). `rank` is load-bearing for routing precedence: lower rank evaluates first.

### TS `@microsoft/agents-activity` package — Activity helpers

```typescript
import { Activity } from '@microsoft/agents-activity'
import { addAIToActivity, ClientCitation } from '@microsoft/agents-activity'

const activity: Activity = {
  type: 'message',
  text: 'Based on the documents, here are the key findings...'
}

const citations: ClientCitation[] = [{
  '@type': 'Claim',
  position: 1,
  appearance: {
    '@type': 'DigitalDocument',
    name: 'Research Report 2024',
    url: 'https://example.com/report.pdf',
  }
}]

addAIToActivity(activity, citations)
```

`addAIToActivity()` — TS helper that adds AI-content metadata + citations to an Activity. Citations rendered specially in Teams. Schema.org-style typing (`@type: 'Claim'`, `@type: 'DigitalDocument'`).

### Activity types — full catalog (verbatim from C# spec; same in TS)

| Type | Purpose | TS Constant | C# Constant |
|---|---|---|---|
| Message | Text/media/cards | `'message'` | `ActivityTypes.Message` |
| ConversationUpdate | Member joined/left | `'conversationUpdate'` | `ActivityTypes.ConversationUpdate` |
| Event | Async nonverbal trigger | `'event'` | `ActivityTypes.Event` |
| Invoke | Specific operation/command (Teams `task/fetch` / `task/submit`) | `'invoke'` | `ActivityTypes.Invoke` |
| Typing | Typing indicator (NOT supported in M365 Copilot) | `'typing'` | `ActivityTypes.Typing` |
| Handoff | External-channel control transfer (AudioCodes voice) | `'handoff'` | `ActivityTypes.Handoff` |
| InstallationUpdate | Enterprise install/uninstall (Agent 365 — 2026) | `ActivityTypes.InstallationUpdate` | `ActivityTypes.InstallationUpdate` |

### C# attachment-receiving pattern (port to TS by structural fidelity)

```csharp
agent.OnActivity(ActivityTypes.Message, async(turnContext, turnState, cancellationToken) => {
    var activity = turnContext.Activity;
    if (activity.Attachments != null && activity.Attachments.Count > 0) {
        foreach (var attachment in activity.Attachments) {
            // Read attachment.ContentType / attachment.ContentUrl
            // Securely download from URL (short-lived; move to own storage)
        }
    }
})
```

TS equivalent: `context.activity.attachments` (camelCase) + same per-attachment read pattern via `fetch` or Azure Blob SDK.

### TS event-handler with state (counter pattern)

```typescript
agent.onMessage(async (context, state) => {
    const messageCount = (state.conversation.messageCount ?? 0) + 1
    state.conversation.messageCount = messageCount
    await context.sendActivity(`Message #${messageCount}: ${context.activity.text}`)
})
```

`state.conversation` is the per-conversation persistent state; `state.user` is per-user. Backed by `MemoryStorage` (dev) / Blob / Cosmos (prod).

## Verbatim quotes worth preserving

> "The packages should target node20 or greater, and can be used from JavaScript using CommonJS or ES6 modules, or from TypeScript." — `learn.microsoft.com/javascript/api/overview/agents-overview`

> "The Microsoft 365 Agent SDK simplifies building full stack, multichannel, trusted agents for platforms including Microsoft 365, Teams, Copilot Studio, and Web chat. We also offer integrations with third parties such as Facebook Messenger, Slack, or Twilio." — confirms TS surface is multi-channel-ready.

> "Use `ActivityTypes` constants instead of hard-coded strings." — best practice to avoid magic strings.

## Implications for the engine catalog (refs F-NNN)

- **F-typescript-af-bridge (revisited from wave-1)**: bridge is needed for Agent **Framework** workflow primitives (SequentialBuilder, WorkflowBuilder, etc.) which remain Python+C#-only. But for Activity-Protocol-level routing (the M365 *Agents SDK*, distinct from Agent *Framework*), TS is fully native — no bridge needed.
- **F-onactivity-universal-listener**: TS pattern matches C#: `app.onActivity(ActivityTypes.Message, handler)` is the universal entrypoint. Engine adapts equally well across both.
- **F-channel-data-inspection**: TS `context.activity.channelData` is the per-channel-affordance escape hatch. Engine inspects before processing.
- **F-streaming-by-default**: TS streaming examples in wave-1 used `@azure/ai-projects` Foundry SDK; for activity-level streaming, the M365 Agents SDK has a separate `azure-ai-streaming` sample (`samples/nodejs/azure-ai-streaming`).

## NEW F-NNN candidates

- **F-205: ts-agent-application-template** — engine ships a TS `AgentApplication` subclass template that pre-wires: storage selection (Memory/Blob/Cosmos), `onMessage`/`onActivity`/`onConversationUpdate` route stubs, JWT-protected `/api/messages`, citation helper. One `npm init` to working agent.
- **F-206: activity-types-typed-router** — engine ships a typed-route helper that wraps `OnActivity(string)` with discriminated-union activity-type narrowing. TS gets full type-safety on `context.activity` payload (currently `any` for many channelData fields).
- **F-207: rank-based-routing-discipline** — engine documents + enforces a `rank`-ordering convention for `OnActivity` overloads (auth handlers @100, app-specific routes @1000, default fallthrough @ushort.MaxValue). Avoids implicit "registration order" footgun.
- **F-208: installation-update-lifecycle-handler** — engine ships a default `InstallationUpdate` handler that emits a Council `welcome` thread on install + `archive` thread on remove. Maps Agent 365 enterprise lifecycle to MAD.Council semantics.

## Confidence

**HIGH** — every code sample is verbatim from `microsoft_docs_search` / `microsoft_code_sample_search` results dated May 2026. The package list (`@microsoft/agents-activity`, `@microsoft/agents-hosting`, `@microsoft/agents-hosting-express`) is the authoritative TS surface per `learn.microsoft.com/javascript/api/overview/agents-overview` (v1.4.1). `OnActivity` 4-overload C# signature is verbatim from `Microsoft.Agents.Builder v1.4.83` API reference. **Wave-1 Lane B's "sparse TS samples" finding is corrected**: M365 Agents SDK has full TS parity with C# at the Activity-Protocol routing level. The remaining gap (Agent *Framework* workflow primitives) is a different surface and is covered separately in `agent-framework-typescript-bridge.md`.
