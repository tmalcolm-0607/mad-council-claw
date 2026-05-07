---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/microsoft-365/copilot/extensibility/whats-new
  - https://learn.microsoft.com/microsoft-365/copilot/release-notes
  - https://learn.microsoft.com/microsoft-365/copilot/extensibility/agent-builder-build-agents
  - https://learn.microsoft.com/microsoft-365/copilot/extensibility/declarative-agent-ui-widgets
---

# M365 Copilot extensibility — 2026 surface

## Sources

- What's new in M365 Copilot extensibility — `learn.microsoft.com/microsoft-365/copilot/extensibility/whats-new`
- M365 Copilot release notes — `learn.microsoft.com/microsoft-365/copilot/release-notes` (Jan 13 2026 entry)
- Agent Builder — `.../extensibility/agent-builder-build-agents`
- Declarative agent UI widgets (MCP Apps + OpenAI Apps SDK) — `.../extensibility/declarative-agent-ui-widgets`

## Load-bearing patterns

### 2026 timeline (from "what's new")

| Date | Capability |
|---|---|
| **Mar 2026** | Share agents to teams (not just users/groups) in Microsoft Teams |
| **Mar 2026** | **Natural language to create an agent in Agent Builder** — agent auto-configured |
| **Mar 2026** | **Interactive UI widgets for declarative agents** via OpenAI Apps SDK + MCP server actions; widgets render inline or full-screen |
| **Feb 2026** | Agent Builder availability in GCC-High |
| **Jan 2026** | **Retrieval API pay-as-you-go consumption** (preview) — access without M365 Copilot license |
| **Dec 2025** | **Teams meeting AI insights APIs GA in Microsoft Graph v1.0** (action items, meeting notes, mentions) |

### GPT-5 in Agent Builder (Jan 13, 2026 release notes)

Verbatim: "Declarative agents built in Microsoft 365 Copilot now use **GPT-5 as the underlying chat model**, enabling advanced reasoning, more natural language understanding, and improved multi-step processing."

Roadmap ID: 502552. Available across Android, Windows, iOS, Mac, Web.

### Mail / People / Meeting Insights expansion (Jan 13, 2026)

Verbatim: "Copilot declarative agents can now integrate with richer M365 data: mail, people's data, Teams chats, and meeting transcripts."

Sample queries the docs use:
- "Summarize decisions and blockers from this week's meetings relating to Project X."
- "Draft follow up emails for unresolved items from yesterday."

This is the data surface for any productivity-style engine integration.

### Interactive UI widgets — the MCP Apps + OpenAI Apps SDK surface

UI widgets supported via two methods:
1. **MCP Apps** — extension to MCP that enables MCP servers to deliver interactive UIs to hosts
2. **OpenAI Apps SDK** — tools to build ChatGPT apps based on the MCP Apps standard with extra ChatGPT functionality

Widget URL convention: `{hashed-mcp-domain}.widget-renderer.usercontent.microsoft.com` (SHA-256 of MCP server domain).

Authentication: OAuth 2.1 + Microsoft Entra SSO. Anonymous for dev only.

#### Component bridge — what's supported

| OpenAI Apps SDK API | MCP Apps equivalent | Supported? |
|---|---|---|
| `window.openai.toolInput` / `toolOutput` | `app.ontoolinput` / `app.ontoolresult` | ✅ |
| `window.openai.callTool(name, args)` | `app.callServerTool({name, arguments})` | ✅ |
| `window.openai.sendFollowUpMessage({prompt})` | `app.sendMessage(...)` | ✅ |
| `window.openai.requestDisplayMode(...)` | `app.requestDisplayMode({mode})` | ✅ (full screen only) |
| `window.openai.uploadFile(file)` / `getFileDownloadUrl(...)` | — | ❌ |
| `window.openai.openExternal({href})` | `app.openLink({url})` | ✅ |
| `window.openai.theme` | `app.getHostContext()?.theme` | ✅ |

### Agent Builder (the no-code on-ramp)

Three creation paths in Agent Builder:
1. **Natural language describe** (recommended; auto-configures)
2. **Manual via Configure tab**
3. **Start from a template**

### Retrieval API PAYG (preview)

The Retrieval API (tenant-level data sources: SharePoint + M365 Copilot connectors) is now **available without a M365 Copilot add-on license** via pay-as-you-go consumption. Preview as of Jan 2026.

**Implication for our engine:** consumers without M365 Copilot license can still grant our engine access to their tenant data via Retrieval API PAYG.

### Teams Meeting AI Insights APIs (GA Dec 2025)

In Microsoft Graph v1.0:
- `List aiInsights` (per `onlineMeeting`)
- `Get callAiInsight`

Returns AI-generated meeting insights: action items, meeting notes, mentions.

**Implication:** our engine's "Daily briefing + project workspace" feature (per the user's Message 11) can lean on Graph v1.0 directly — no preview API exposure.

### Other Copilot extensibility lanes (visible in Jan 13 release notes)

- **Generate Office documents from agents in Copilot Studio lite** (PowerPoint / Excel / Word saved to OneDrive)
- **Connect Dropbox** for smarter Copilot file access
- **Search for meetings by organizer** in Copilot Chat ("Find meetings organized by X next week")

## Verbatim quotes worth preserving

> "You can now create agents more quickly with Agent Builder in Microsoft 365 Copilot by using natural language. The agent is automatically configured for you."

> "You can now add interactive UI widgets to your declarative agents by extending MCP server-based actions using the OpenAI Apps SDK. Widgets can render inline or in full-screen mode within Microsoft 365 Copilot."

> "The Microsoft 365 Copilot Retrieval API is now available to users without a Microsoft 365 Copilot add-on license via pay-as-you-go consumption (preview)."

## Implications for the engine catalog (refs F-NNN)

- **F-mcp-ui-widgets** — engine's "Multimodal input (voice + screenshot-to-prompt)" feature (Message 11) maps to the MCP Apps + OpenAI Apps SDK widget surface. Our engine's UI components can render inside M365 Copilot AND inside our own Electron shell.
- **F-graph-meeting-insights** — engine's "Daily briefing + project workspace" feature consumes Graph v1.0 `aiInsights` directly. No preview-API risk.
- **F-retrieval-api-payg** — for non-M365-Copilot-licensed users, engine offers Retrieval API PAYG as the tenant-data on-ramp. Differentiator vs. competitors that require full Copilot license.
- **F-mail-people-meeting-context** — engine declarative agents tap mail/people/Teams chats/meeting transcripts. Aligns with the user's "M365 integration (WorkIQ + MSAL/WAM auth)" v1 feature lane (Message 10).
- **F-agent-builder-bridge** — engine can be exposed via Agent Builder for low-code consumers; the natural-language describe path drives auto-configuration.
- **F-gpt-5-default** — for Microsoft tenants, default our engine's M365-bound agents to GPT-5 (matches Agent Builder default).

## NEW F-NNN candidates (if any)

- **F-NEW: dual-render-ui-widget** — engine ships UI widgets that render in BOTH M365 Copilot (via MCP Apps) AND our Electron shell (native React). Single component definition; two render targets.
- **F-NEW: ai-insights-aggregator** — engine consumes Graph `aiInsights` across all onlineMeetings, dedupes, and surfaces a project-level rollup. Differentiator over per-meeting chat queries.
- **F-NEW: agent-builder-import** — bidirectional: engine can import a declarative agent from Agent Builder (manifest.json) AND export to Agent Builder so non-engine users can adopt.

## Confidence

**HIGH** — sources are the official "what's new" + release notes pages, dated explicitly. GPT-5 in Agent Builder is the load-bearing 2026 data point and is documented with a Roadmap ID (502552). The MCP Apps + OpenAI Apps SDK component bridge table is verbatim from the M365 docs. The only minor caveat is **Retrieval API PAYG is in preview** — flag this in any consumer-facing doc that promises tenant-data access without M365 Copilot license.
