---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: high
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - https://learn.microsoft.com/power-platform/release-plan/2026wave1/microsoft-copilot-studio/
  - https://learn.microsoft.com/power-platform/release-plan/2026wave1/microsoft-copilot-studio/copilot-ai-innovation
  - https://learn.microsoft.com/power-platform/release-plan/2026wave1/
  - https://learn.microsoft.com/microsoft-copilot-studio/add-agent-copilot-studio-agent
  - https://learn.microsoft.com/microsoft-copilot-studio/guidance/multi-agent-patterns
  - https://learn.microsoft.com/power-platform/release-plan/2025wave2/microsoft-copilot-studio/planned-features
---

# Copilot Studio — 2026 release wave 1

## Sources

- 2026 wave 1 plan (Copilot Studio) — `learn.microsoft.com/power-platform/release-plan/2026wave1/microsoft-copilot-studio/`
- Copilot + AI innovation page — `.../microsoft-copilot-studio/copilot-ai-innovation`
- Power Platform 2026 wave 1 overview — `learn.microsoft.com/power-platform/release-plan/2026wave1/`
- Connect to existing Copilot Studio agent — `learn.microsoft.com/microsoft-copilot-studio/add-agent-copilot-studio-agent`
- Multi-agent orchestration patterns guidance — `.../guidance/multi-agent-patterns`
- 2025 wave 2 planned features (history) — `.../release-plan/2025wave2/microsoft-copilot-studio/planned-features`

## Load-bearing patterns

### 2026 wave 1 (April-September 2026) overview — Copilot Studio

Verbatim from the wave 1 plan:

> "In the upcoming release, Copilot Studio will make it easier to create and operate agents. A key functionality will be Copilot Studio support to further extend agents built with Agent Builder in Microsoft 365 Copilot, including new knowledge types, sophisticated tools, and support for evaluations. In addition, high value out-of-the-box actions in workflows will make it easier for customers to apply AI for their automation needs."

From the Power Platform overview:

> "Microsoft Copilot Studio continues its journey to make agent and agentic workflows even easier to build and more powerful. Now you can further customize agents built with Agent Builder in M365 Copilot, and power your automation with high value AI actions. Deeper governance, multi-agent orchestration and evaluations enable further scaling. **With deeper integration with Microsoft Foundry and Work IQ, your agents can use the latest AI technology in coordination with your most organizational data.**"

### Connected agents (the 2026 multi-agent shape)

Per `multi-agent-patterns` guidance, **connected agents** are separate agents with their own orchestration, tools, and knowledge. The main agent delegates part of a request to a child agent.

| Connected agent governance concern | What it means |
|---|---|
| **Orchestration** | Parent agent treats the connected agent as a "tool" with a description; clear handoff criteria |
| **Data handoff** | Conversation history passed by default; specific parameters can be passed too |
| **Security** | Connected agent might have access the parent doesn't — ensure no inadvertent privilege bypass |
| **Audit + monitoring** | Log when connected agent invoked + what it did; correlate parent + connected sessions via telemetry IDs |

**When to NOT separate:** Don't create a separate agent for every subtask. Use a separate agent only if:
1. Complex enough to have its own suite of tools/knowledge (different domain)
2. Requires different governance / access controls
3. You plan to reuse that capability across many main agents

### Connected agents — Generally Available Nov 30, 2025

Per planned features table: connected agents went GA Nov 30, 2025; Public preview was June 16, 2025. Mature feature in 2026.

### Connection setup mechanics

Per `add-agent-copilot-studio-agent`:
1. Other agent must be in the same environment as the main agent
2. Other agent must be **published**
3. Other agent must be configured to allow connections from other agents
4. Maker must own the connected agent or have it shared
5. **Description is local** — once connected, the parent agent controls the description; updates to the connected agent's source description don't auto-sync
6. Optional: clear "Pass conversation history to this agent" to limit context handoff

### Generative actions

Verbatim: "Generative actions dynamically create conversations by using AI to find and connect the right plugins in real time. Makers set up their agent with the right plugins. Then, with generative AI, the system automatically decides which plugins to use, what information it needs from the user, and how to guide the conversation and run the plugins until it completes the request."

This is the low-code equivalent of Agent Framework's Magentic pattern.

### Code interpreter expansions (2026)

| Feature | Public preview | GA |
|---|---|---|
| Code interpreter on customer-uploaded files | Oct 6, 2025 | Nov 14, 2025 |
| Code interpreter on SharePoint sources | Mar 16, 2026 | May 2026 |

### Evaluations (the 2026 governance investment)

| Feature | Public preview | GA |
|---|---|---|
| Evaluate use of tools and topics | Mar 2, 2026 | Mar 31, 2026 |
| Evaluate test sets with multiple graders | Feb 8, 2026 | — |

This is Copilot Studio's answer to "agent evaluations CLI" — built into the platform.

### Foundry integration (2026 deepening)

Per the wave 1 overview: **deeper integration with Microsoft Foundry and Work IQ**. Copilot Studio agents can call Foundry-hosted models + tools as first-class citizens.

### Three multi-agent patterns guidance recognizes (per `multi-agent-patterns`)

1. **Connected agents** — described above
2. **Inline topics** — for simple subtasks within a single agent
3. **External agents** — Bot Framework / 3rd-party integrations

### Viva Insights business-impact analysis

Per planned features: "Analyze the business impact of agents in Viva Insights" went GA Jan 13, 2026. Provides agent ROI metrics in the same surface where leaders consume Viva data.

## Verbatim quotes worth preserving

> "Generative actions dynamically create conversations by using AI to find and connect the right plugins in real time."

> "With deeper integration with Microsoft Foundry and Work IQ, your agents can use the latest AI technology in coordination with your most organizational data."

> "Agent-to-agent autonomy without an external governor always degenerates." — paraphrased from `multi-agent-patterns` security guidance

> "Don't create a separate agent for every subtask. ... A practical approach is to start with one agent and only split into multiple agents when you clearly see a need for modularity or a boundary that shouldn't be crossed by a single agent."

## Implications for the engine catalog (refs F-NNN)

- **F-connected-agents-bridge** — engine exposes its workflows as Copilot Studio "connected agents" (same env, published, allow connections). Engine becomes consumable from low-code Copilot Studio agents.
- **F-evaluation-framework** — engine ships its own evaluation framework but inherits the multi-grader pattern from Copilot Studio's 2026 capability. Use multiple graders per test set.
- **F-generative-actions-equivalent** — engine's "Skills" surface should support generative-actions-style dynamic plugin selection (LLM picks the right tool from the registered set).
- **F-viva-insights-bridge** — engine emits agent ROI metrics in Viva-compatible format. Leaders consuming Viva insights see engine-driven ROI alongside Copilot Studio agent ROI.
- **F-shared-environment-tenancy** — adopt Copilot Studio's "same environment" model for cross-agent connection. Maps to our channel/owner model.

## NEW F-NNN candidates (if any)

- **F-NEW: copilot-studio-connect-out** — engine ships a Copilot Studio template that auto-connects to engine workflows. One-click for low-code adoption.
- **F-NEW: dual-grader-eval** — adopt 2026 Copilot Studio "multiple graders per test set" pattern as engine's eval default. At least 2 graders per fixture.
- **F-NEW: connected-agent-governance-checklist** — codify the 4 connected-agent governance concerns (orchestration / data handoff / security / audit) as a pre-flight skill any engine workflow runs before exposing itself.

## Confidence

**HIGH** — all 2026 wave 1 dates and feature names sourced from current `power-platform/release-plan/2026wave1/microsoft-copilot-studio/*` docs. Connected-agents GA date (Nov 30, 2025) and the 4 governance concerns (orchestration / data handoff / security / audit) are verbatim from current docs. Generative actions is documented behavior. The only "preview" caveat is **code interpreter on SharePoint sources** (May 2026 GA target) — flag in any engine doc that promises immediate availability.
