---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/azure/foundry/agents/concepts/what-is-memory
  - https://learn.microsoft.com/azure/foundry/agents/how-to/memory-usage
---

# Memory in Foundry Agent Service (preview)

## Sources

- Memory concept overview — `learn.microsoft.com/azure/foundry/agents/concepts/what-is-memory`
- How-to: create + use memory — `learn.microsoft.com/azure/foundry/agents/how-to/memory-usage` (csharp / python / typescript / rest pivots)

## Load-bearing patterns

### Preview status (verbatim)

> "Memory (preview) in Foundry Agent Service and the Memory Store API (preview) are licensed to you as part of your Azure subscription and are subject to terms applicable to 'Previews' in the Microsoft Product Terms..."

This is **preview as of 2026-05**. Flag in any engine doc that depends on it.

### What memory is — the two categories

| Category | Description | Managed by |
|---|---|---|
| **Short-term memory** | Tracks current session's conversation; immediate context | Agent orchestration framework's session context |
| **Long-term memory** | Distilled knowledge across sessions; recall and build on prior interactions | Foundry's memory store (the persistent layer) |

> "Memory in Foundry Agent Service is designed for long-term memory. It extracts meaningful information from conversations, consolidates it into durable knowledge, and makes it available across sessions."

### Two kinds of long-term memory

| Type | Description | Configuration |
|---|---|---|
| **User profile memory** | Information + preferences about user (preferred name, dietary restrictions, language preference). "Static" w.r.t. conversation. Retrieve once at session start. | `user_profile_details` parameter |
| **Chat summary memory** | Distilled summary of each topic/thread in a chat session. Lets users continue conversations or reference prior sessions without repeating context. Retrieve based on current conversation. | `chat_summary_enabled: true` |

### Two ways to use memory

1. **Memory search tool** — Attach to a prompt agent; agent reads + writes memory store during conversations. **Recommended for most scenarios.**
2. **Memory store APIs** — Direct low-level API access for advanced cases.

### Customization via `user_profile_details`

Two patterns:

#### Prioritization (positive)
> "Set `user_profile_details` to prioritize 'flight carrier preference and dietary restrictions' for a travel agent. This focused approach helps the memory system know which details to extract, summarize, and commit to long-term memory."

#### Exclusion (negative)
> "Set `user_profile_details` to 'avoid irrelevant or sensitive data, such as age, financials, precise location, and credentials.'"

The same parameter accepts BOTH directions. Privacy-respecting + memory-efficient.

### Per-agent memory store boundary

> "Create a dedicated memory store for each agent to establish clear boundaries for memory access and optimization."

Each store specifies:
- Chat model deployment
- Embedding model deployment

### Scope parameter — user-level isolation

Per the how-to: "You control access using the `scope` parameter, which segments memory across users to ensure secure and isolated experiences."

### CRUD surface (verbatim from usage support table)

| Capability | Python | C# | JavaScript | REST |
|---|---|---|---|---|
| Create / update / list / delete memory stores | ✔️ | ✔️ | ✔️ | ✔️ |
| Update + search memories | ✔️ | ✔️ | ✔️ | ✔️ |
| Attach memory to a prompt agent | ✔️ | ✔️ | ✔️ | ✔️ |

All four SDK surfaces (Python / C# / JavaScript / REST) at parity. No "Python only" capability.

### Sample C# create

```csharp
MemoryStore updatedStore = projectClient.MemoryStores.UpdateMemoryStore(
    name: memoryStoreName,
    description: "Updated description"
);
```

## Verbatim quotes worth preserving

> "Memory in Microsoft Foundry Agent Service is a managed, long-term memory solution. It enables agent continuity across sessions, devices, and workflows."

> "Memory stores act as persistent storage, defining which types of information are relevant to each agent. You control access using the `scope` parameter, which segments memory across users to ensure secure and isolated experiences."

> "Customize what information the agent stores to keep memory efficient, relevant, and privacy-respecting."

## Implications for the engine catalog (refs F-NNN)

- **F-long-term-memory** — engine has a long-term memory primitive distinct from short-term session context. Two flavors: user profile (static, fetched once) + chat summary (per-thread, fetched relevance-weighted).
- **F-per-agent-memory-boundary** — every engine agent gets a dedicated memory store. No shared global memory. Maps to "project = isolation boundary" from Foundry standard setup.
- **F-scope-isolation** — engine's memory primitive accepts a `scope` parameter (user-level isolation default). Critical for multi-tenant deployments.
- **F-user-profile-details-prioritization** — engine memory store config accepts EITHER prioritization (what to remember) OR exclusion (what to forget) via the same parameter shape.
- **F-memory-as-tool** — engine exposes memory as a tool to the agent (agent reads/writes via tool calls). Lower-level direct API access available for advanced uses.
- **F-multi-language-parity** — engine's memory SDK has Python / C# / TypeScript / REST parity (matches Foundry).

## NEW F-NNN candidates (if any)

- **F-NEW: memory-extraction-policy** — engine ships a default `user_profile_details` policy template that EXCLUDES sensitive fields (age, financials, precise location, credentials, government IDs, secrets). Inherit from Foundry's example, then extend per consumer project.
- **F-NEW: cross-session-continuity-test** — engine has a built-in eval that verifies long-term memory survives session restart + agent restart + memory-store relocation. Required for "agent continuity" claims.
- **F-NEW: memory-store-export** — engine offers JSON export of an agent's memory store for portability + backup. Foundry doesn't (yet) provide one-click export of full conversation histories — engine can fill that gap.

## Confidence

**HIGH** — every contract detail (CRUD surface, scope parameter, `user_profile_details` shape, two memory categories) is verbatim from current Microsoft Learn `azure/foundry/agents/concepts/what-is-memory` + `.../how-to/memory-usage` docs. **CAVEAT: feature is preview as of 2026-05.** Any engine adoption commitment that depends on this should flag preview status. Three active gaps: (1) no documented memory store size limits, (2) no documented retention policies (does memory expire?), (3) no documented cross-region replication for memory stores. Flag these as research-gaps for a future lane.
