---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/microsoft-agent-365/developer/
  - https://learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk
  - https://learn.microsoft.com/microsoft-agent-365/developer/get-started
  - https://learn.microsoft.com/microsoft-agent-365/connect-existing-agents
  - https://learn.microsoft.com/microsoft-agent-365/developer/deploy-agent-gcp
  - https://learn.microsoft.com/microsoft-365/fasttrack/microsoft-agent-365
  - https://learn.microsoft.com/microsoft-365/copilot/copilot-agent-store
---

# Microsoft Agent 365 SDK + CLI

## Sources

- Agent 365 developer landing — `learn.microsoft.com/microsoft-agent-365/developer/`
- Agent 365 SDK overview — `.../developer/agent-365-sdk`
- Get started — `.../developer/get-started`
- Connect existing agents — `.../connect-existing-agents`
- Deploy on GCP (proves cross-cloud) — `.../developer/deploy-agent-gcp`
- FastTrack offering — `learn.microsoft.com/microsoft-365/fasttrack/microsoft-agent-365`
- Agent Store integration — `learn.microsoft.com/microsoft-365/copilot/copilot-agent-store`

## Load-bearing patterns

### Identity model (the core innovation)

Agent 365 introduces **Microsoft Entra Agent ID** — a first-class identity in your tenant for each agent, subject to the same Conditional Access, identity protection, and access reviews as human users.

**Implication for our engine:** every agent we run can have an Entra-backed identity, not just a service principal. This unlocks:
- Conditional Access policies on agents (e.g., MFA equivalent for sensitive operations)
- Sensitivity labels + DLP applied to agent-touched data automatically
- Defender monitoring for anomalous agent behavior

### The blueprint pattern

> "When you create an agent identity blueprint, the Agent 365 CLI provisions a Microsoft Entra Agent ID for your agent — a first-class identity in your tenant, subject to the same enterprise governance policies as human users."

A **blueprint** is an IT-approved, pre-configured definition of an agent type — the enterprise "template". It defines:
- Agent capabilities
- Required Work IQ tool access
- Security and compliance constraints
- Audit requirements
- Lifecycle metadata
- Linked governance policy templates (DLP, external access restrictions, logging rules)

Activated blueprints are visible in the Microsoft 365 admin center; users request agent instances from admins.

### What the SDK adds (vs. agent frameworks)

Agent 365 SDK does NOT replace Agent Framework / Foundry / Copilot Studio. It LAYERS on top:

| Layer | Role | Provided by |
|---|---|---|
| Enterprise Capabilities | Identity, notifications, observability, tooling | **Agent 365 SDK** |
| Agent Logic | Prompts, workflows, reasoning | Your code |
| LLM Orchestrator Runtime | Model invocation and tool orchestration | Your chosen framework (AF, AutoGen, LangChain, OpenAI Agents SDK, **Claude Code SDK**, etc.) |

Verbatim: "Agent 365 works with agents built on any agent SDK or platform. This includes low-code platforms like Copilot Studio and Azure AI Foundry. It also supports pro-code options such as Microsoft Agent Framework, Microsoft Agents SDK, OpenAI Agents SDK, **Claude Code SDK**, and LangChain SDK. Agent 365 also works with agent code hosted on any endpoint, be it Azure, Amazon Web Services (AWS), Google Cloud Platform (GCP), or any other cloud provider."

**This is a load-bearing data point for our engine** — Claude Code SDK is explicitly named as a supported framework. We can layer Agent 365 SDK on top of our Claude-Code-driven engine.

### What an Agent 365–enabled agent gets

1. **Entra-backed Agent Identity** with its own user resources (e.g., mailbox)
2. **Notifications** — receive + respond to Teams, Outlook, Word comments, emails (just like a human participant)
3. **Full observability via OpenTelemetry** — audited, traceable interactions, inference events, tool usage
4. **Governed MCP servers** — access M365 workloads (Mail, Calendar, SharePoint, Teams) under admin control
5. **Blueprint compliance** — every agent instance inherits compliance, governance, security policies

### Work IQ MCP tools (the standardized M365 tool surface)

Per `connect-existing-agents`: Work IQ MCP tools include **Copilot, Calendar, Mail, SharePoint, OneDrive, Teams, User, Word, and Dataverse/Dynamics 365**.

These are governed by the Agent 365 control plane — admin sets allow-lists; agent code calls through.

### CLI surface

The **Agent 365 CLI** is the command-line backbone:
- Create agent blueprints + supporting resources
- Manage Work IQ tools, permissions, tooling
- Deploy agent code to Azure
- Publish agent application packages to Microsoft admin center
- Clean up (blueprints, identities, Azure resources)

### Capability tiers (incremental adoption)

| Tier | M365 custom engine agent | All other agents |
|---|---|---|
| Register | ✓ (auto via existing Entra app reg) | ✓ (requires blueprint) |
| Observability | ✓ | ✓ |
| Work IQ | ✓ | ✓ |
| AI teammate | ✓ | ✓ |

**Implication:** even our engine's agents (registered as Entra apps) can adopt Agent 365 incrementally — start with Register + Observability before adding Work IQ + AI teammate behavior.

### Cross-cloud deployment proof

The GCP deployment guide (and an equivalent AWS guide) proves Agent 365 is cloud-agnostic:
- Microsoft Entra & Graph provide identity, permissions, blueprint
- GCP Cloud Run (or AWS, or any cloud) provides runtime
- Bot Framework messaging endpoint registration points at the cloud-of-choice

### Auto-integrated platforms

Per `copilot-agent-store`: agents built with **Microsoft Foundry, Microsoft Copilot Studio, and Agent Builder in Microsoft 365 Copilot are automatically integrated with Microsoft Agent 365**. External-platform agents need explicit SDK integration.

### Three onboarding paths for external agents

1. **Registry sync** — for agents on Amazon Bedrock / Google Vertex AI, sync into the Agent 365 agent registry for centralized visibility (preview)
2. **SDK integration** — extend agents with Agent 365 SDK for full enterprise capabilities
3. **Apply policies + access controls** — configure RBAC, data access policies, governance controls

## Verbatim quotes worth preserving

> "It enhances agents you've already built — regardless of the underlying stack — by adding enterprise capabilities such as Entra-based Agent identity, governed Work IQ tool access, OpenTelemetry-based observability, notifications through the Activity protocol, and agent ID-driven governance."

> "Agents have unique identities. People invoke them using common gestures (such as @mentions) in apps that enterprise users typically operate in (such as Teams, Word, Outlook, and more)."

> "Microsoft Entra ID governance — The agent's identity and access lifecycle is managed through the same Conditional Access, identity protection, and access reviews that apply to human users."

> "Microsoft Purview — Every data interaction the agent performs is subject to your tenant's sensitivity labels, DLP policies, and retention policies — automatically, with no extra code."

> "Microsoft Defender — Agent behavior is continuously monitored for anomalies and threats. Suspicious activity triggers the same alerts and response workflows as for any user in the tenant."

## Implications for the engine catalog (refs F-NNN)

- **F-entra-agent-identity** — engine's identity primitive should default to Entra Agent ID (not service principal). Maps directly to our `single-owner-accountability.md` rule (every artifact has an owner_alias). Owner-alias = Entra Agent ID for headless agents.
- **F-blueprint-driven-deployment** — adopt Agent 365 blueprints as the engine's deployment template surface. A blueprint is a "kit configuration" we can ship.
- **F-otel-genai-observability** — engine emits OTel GenAI semantic conventions for every agent invocation, tool call, inference. Required for Agent 365 integration. Already aligns with our existing observability discipline.
- **F-work-iq-mcp-integration** — engine uses Work IQ MCP servers (the same ones Microsoft 365 Copilot uses) rather than rolling our own M365 access. Inherits governance for free.
- **F-purview-defender-inheritance** — engine's data interactions automatically inherit tenant DLP/sensitivity-label/retention policies via Purview, anomaly detection via Defender. **No extra code required.**
- **F-cross-cloud-deploy** — engine deployable to Azure / GCP / AWS / on-prem; identity always lives in Entra. Cross-cloud is a first-class shape.

## NEW F-NNN candidates (if any)

- **F-NEW: agent-365-control-plane** — explicit engine surface that maps our channel/thread/verdict ontology to Agent 365 registry entries. Council channels become discoverable in M365 admin center.
- **F-NEW: blueprint-as-kit-config** — package our standard configurations (e.g., "MAD.Council 3-role review", "clawpilot Skills + Permissions") as Agent 365 blueprints for one-click tenant rollout.
- **F-NEW: claude-code-sdk-bridge** — since Agent 365 explicitly names Claude Code SDK as a supported framework, build/document the bridge: how a Claude-Code-driven engine surfaces as an Agent 365 agent.

## Confidence

**HIGH** — every claim cited above is verbatim from current Microsoft Learn `microsoft-agent-365/*` docs. The Claude Code SDK mention is unambiguous: it's listed as a supported framework alongside Agent Framework, OpenAI Agents SDK, LangChain. The cross-cloud deployment guides (GCP shown) confirm the cloud-agnostic claim. FastTrack offering confirms Microsoft is investing in a customer-onboarding path. The only "preview" item is **registry sync for non-Microsoft-cloud agents** — explicit preview tag in the source.
