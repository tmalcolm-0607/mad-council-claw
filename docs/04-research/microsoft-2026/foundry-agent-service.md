---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/azure/cosmos-db/gen-ai/azure-agent-service
  - https://learn.microsoft.com/azure/foundry/agents/concepts/standard-agent-setup
  - https://learn.microsoft.com/azure/foundry/agents/environment-setup
  - https://learn.microsoft.com/azure/foundry-classic/agents/whats-new
  - https://learn.microsoft.com/azure/foundry/agents/faq
  - https://learn.microsoft.com/azure/foundry/how-to/high-availability-resiliency
---

# Foundry Agent Service — hosted agents + BYO Cosmos thread storage

## Sources

- Cosmos integration with Foundry Agent Service — `learn.microsoft.com/azure/cosmos-db/gen-ai/azure-agent-service`
- Standard agent resources — `learn.microsoft.com/azure/foundry/agents/concepts/standard-agent-setup`
- Environment setup — `learn.microsoft.com/azure/foundry/agents/environment-setup`
- What's new (May 2025 GA) — `learn.microsoft.com/azure/foundry-classic/agents/whats-new`
- FAQ — `learn.microsoft.com/azure/foundry/agents/faq`
- High availability + resiliency — `learn.microsoft.com/azure/foundry/how-to/high-availability-resiliency`

## Load-bearing patterns

### Three setup modes — choose one

| Mode | Storage | When |
|---|---|---|
| **Basic** | Microsoft-managed (logically separated) | OpenAI Assistants compatibility; no compliance burden |
| **Standard** | BYO Azure Storage + Cosmos DB + AI Search | Compliance, full data ownership |
| **Standard + BYO VNet** | All of the above + private network | Enterprise security, data exfiltration controls |

### BYO Cosmos schema (the load-bearing detail)

Foundry creates a database called **`enterprise_memory`** with **3 dedicated containers**, **each requiring 1000 RU/s** (3000 RU/s total minimum):

| Container | Stores |
|---|---|
| `thread-message-store` | End-user conversation messages |
| `system-thread-message-store` | Internal system messages |
| `agent-entity-store` | Agent metadata (instructions, tools, name) — model inputs and outputs |

**Throughput rule:** for multiple projects under the same Foundry account, multiply by project count. Two projects = 6000 RU/s minimum.

**Both Provisioned Throughput and Serverless modes are supported.**

### Project = isolation boundary

Per `environment-setup`:

> "All agents in the same project share access to the same file storage, thread storage (conversation history), and search indexes. Data is isolated between projects. Agents in one project cannot access resources from another. **Projects are currently the unit of sharing and isolation in Foundry.**"

**Implication for our engine:** when we expose multi-tenant agent sessions, each tenant maps to a Foundry project, NOT a shared project with logical filtering.

### CMK encryption

- Basic setup: Microsoft-managed keys only
- Standard setup: customer-managed keys (CMKs) supported

### Disaster recovery surface

Per `high-availability-resiliency`:
- Cosmos point-in-time restore for `enterprise_memory` database
- Agent definitions exportable via Foundry REST API or Azure AI Projects SDK
- "There's no built-in one-click export or import feature for complete conversation histories" — consumers own backup ceremony for thread bodies
- Restore creates a new Cosmos account; you must update the Foundry connection + reapply role assignments

### Azure Storage scopes

Two blob containers auto-provisioned per project:
- One for files
- One for intermediate system data (chunks, embeddings)

### Cosmos role assignments at provisioning (Phase 6 in standard setup)

- `enterprise_memory` database scope: **Cosmos DB Built-in Data Contributor** (database-level, no per-container role needed)
- All developers needing to author/edit agents: **Azure AI User** role on the project

### Connected agents (within Foundry — different from AF workflows)

Per May 2025 GA notes: "Connected agents allow you to create task-specific agents that can interact seamlessly with a primary agent. This feature enables you to build multi-agent systems without the need for external orchestrators."

**Caveat from Azure architecture guide:** "The workflows in this service are primarily nondeterministic, which limits which patterns you can fully implement." Connected agents are simpler than AF Group Chat / Magentic.

### Logic Apps triggers (May 2025 GA)

Foundry agents can be auto-invoked by Logic Apps events: new email, new customer ticket. **Implication:** our engine could expose itself as a Foundry-callable agent for event-driven triggering.

## Verbatim quotes worth preserving

> "With BYO Thread Storage, user-agent conversations, model transactions are stored in your own Azure Cosmos DB account—giving you full control and enhanced security." — Cosmos integration page

> "Standard setup provisions three containers in your Cosmos DB account, each requiring 1000 RU/s." — standard-agent-setup

> "Microsoft doesn't use your data for training models." — FAQ (load-bearing for any enterprise pitch)

> "Cosmos DB point-in-time restore creates a new account. You must update the Agent Service connection string and reapply role assignments if you use system-assigned managed identities. **User-assigned managed identities reduce this overhead.**" — HA/resiliency page

## Implications for the engine catalog (refs F-NNN)

- **F-byo-thread-storage** — engine's hybrid mode (Electron desktop + headless server) needs an equivalent of the `enterprise_memory` 3-container shape. Our council-channel filesystem (channel.json, threads/*, verdicts/*) IS this pattern, but in BYO-FS form. Document the mapping: `channel.json:owner_alias` ↔ Foundry project; `messages/*.json` ↔ `thread-message-store`; `verdicts/*.json` ↔ `agent-entity-store`.
- **F-byo-search** — when we add semantic search across council history, BYO Azure AI Search is the canonical Microsoft 2026 shape (matches Foundry Standard Setup).
- **F-cmk-encryption** — for prod-tier deployments, document CMK as required (matches the `prod` tier discipline in `dangerous-operations-policy.md`).
- **F-project-isolation** — adopt the Foundry "project = isolation boundary" rule as the engine's tenancy primitive. No shared project with logical filtering.
- **F-uami-default** — user-assigned managed identity should be the engine's default (per the HA page, it reduces operational overhead during DR).

## NEW F-NNN candidates (if any)

- **F-NEW: foundry-callable-engine** — engine exposes itself as a Foundry-compatible "connected agent" so Foundry orchestrations can include us. Requires implementing the Foundry agent contract (REST endpoint + agent card).
- **F-NEW: enterprise-memory-mapping** — explicit mapping document (or skill) that translates between our council file layout and Foundry's `enterprise_memory` schema, so users can migrate either direction.
- **F-NEW: ru-budget-helper** — engine ships a Cosmos RU/s sizing calculator for users adopting BYO mode (3000 RU/s baseline + project-count multiplier + per-thread workload model).

## Confidence

**HIGH** — all numbers (3000 RU/s minimum, 1000 RU/s per container, 3-container schema name `enterprise_memory`) are stated verbatim in current Microsoft Learn docs. The May 2025 GA milestone, BYO modes, and Logic Apps triggers are all in the official "what's new" page. The two minor gaps that remain — (a) what happens to BYO-mode pricing across regions, (b) exact Bicep template structure — are linked from the source pages but not material for our engine catalog at this stage.
