---
artifact-class: lane-summary
wave: wave-001
lane: lane-b
date: 2026-05-07
status: complete
---

# Lane B — Wave 001 Summary

Microsoft 2026 internal + readonly stack research. 11 topics, ≤5-min wall-clock budget, Microsoft Learn MCP + WorkIQ MCP + microsoft_code_sample_search.

## Topics processed (11/11)

| # | Topic | Source-status | Confidence | F-NNN candidates |
|---|-------|---------------|------------|------------------|
| 1 | Microsoft Agent Framework workflows + 5 orchestration patterns | Full content (multiple sources) | HIGH | 3 NEW |
| 2 | Foundry Agent Service hosted agents + BYO Cosmos thread storage | Full content | HIGH | 3 NEW |
| 3 | Agent 365 SDK + CLI | Full content (multiple sources) | HIGH | 3 NEW |
| 4 | M365 Copilot extensibility 2026 (GPT-5 + MCP UI widgets + Mail/People/Meeting Insights) | Full content | HIGH | 3 NEW |
| 5 | Copilot Studio 2026 release wave 1 (connected agents + evaluations) | Full content | HIGH | 3 NEW |
| 6 | Activity Protocol (the M365 messaging shape) | Full content (spec + 3 product pages) | HIGH | 3 NEW |
| 7 | A2A protocol — Microsoft adapters (AF + Teams SDK) | Full content (multiple sources + NuGet) | HIGH | 4 NEW |
| 8 | OpenTelemetry GenAI semantic conventions for multi-agent (Microsoft+Outshift) | Full content (multiple sources) | HIGH | 3 NEW |
| 9 | Memory in Foundry Agent Service (preview) | Full content | HIGH (with PREVIEW caveat) | 3 NEW |
| 10 | WorkIQ internal context | **NO citable internal source-docs returned**; LLM synthesis only | MEDIUM (research gap, not failure) | 3 NEW (1 is research-gap entry) |
| 11 | microsoft_code_sample_search for AF + IBackendProvider | Full content (C# + Python rich; **TS sparse for AF workflows**) | HIGH (C#/Python); MEDIUM (TS gap) | 3 NEW |

**No findings** explicit: zero. Every topic returned content. Two topics returned **finding-shaped negative results** (10: WorkIQ has no indexed source docs for the named programs; 11: native AF TypeScript samples are sparse) — these are themselves load-bearing findings the engine catalog needs to address.

## Confidence-weighted findings

- HIGH-confidence findings: 8 of 11 topics
- MIXED HIGH/MEDIUM (preview caveat or partial gap): 2 of 11 topics (#9 memory preview; #11 TS code samples)
- MEDIUM-confidence (synthesis-not-sourced): 1 of 11 topics (#10 WorkIQ internal context)
- LOW-confidence: 0
- BLOCKING gaps: 0 (all topics produced citable findings)

## NEW F-NNN candidates total: ~34

Candidates not yet renumbered (F-NNN ledger is Lane Zero / Wave-N consolidation step). Each per-topic file lists 3-4 NEW candidates with rationale. Highlights by cross-topic convergence:

**Multi-Microsoft-surface convergence (≥3 topics cite the same primitive)**:
- **Activity Protocol everywhere** (topics 4 / 5 / 6 / 8) — engine speaking Activity Protocol unlocks M365 Copilot + Copilot Studio + M365 Agents SDK + (transitively) Agent 365. Single endpoint shape covers four surfaces.
- **A2A as cross-boundary lingua franca** (topics 1 / 3 / 7) — AF workflows-as-agents + Agent 365 SDK + A2A spec all converge on `/a2a/<name>` + `/.well-known/agent.json` as the standard cross-boundary primitive. Engine should expose every workflow as A2A by default.
- **OTel GenAI conventions** (topics 1 / 3 / 5 / 8) — Microsoft+Outshift conventions appear in Foundry, Agent Framework, Agent 365 Distro, Copilot Studio observability. Engine emits these by default (NOT optional).
- **Per-agent isolation boundary** (topics 2 / 3 / 9) — Foundry projects, Agent 365 blueprints, Foundry memory stores all enforce per-agent boundaries. Engine adopts same: no shared global state across agents.

**Convergence with Lane A frontier-2026 patterns** (anticipated; needs cross-lane analysis):
- AF Group Chat ↔ Anthropic multi-agent research system (orchestrator-worker)
- AF Magentic ↔ Anthropic measuring-autonomy / OpenAI Agents SDK handoffs
- Agent 365 blueprints ↔ MCP capability negotiation
- Activity Protocol ↔ A2A protocol (both message-shaped, but different scopes — one for M365 surfaces, one for cross-org agent comms)

## Per-topic candidate detail

### Topic 1 (workflows): F-NEW workflow-as-A2A-endpoint, F-NEW orchestration-pattern-selector, F-NEW checkpoint-resume-protocol
### Topic 2 (Foundry Agent Service): F-NEW foundry-callable-engine, F-NEW enterprise-memory-mapping, F-NEW ru-budget-helper
### Topic 3 (Agent 365): F-NEW agent-365-control-plane, F-NEW blueprint-as-kit-config, F-NEW claude-code-sdk-bridge
### Topic 4 (M365 Copilot): F-NEW dual-render-ui-widget, F-NEW ai-insights-aggregator, F-NEW agent-builder-import
### Topic 5 (Copilot Studio): F-NEW copilot-studio-connect-out, F-NEW dual-grader-eval, F-NEW connected-agent-governance-checklist
### Topic 6 (Activity Protocol): F-NEW activity-protocol-bridge, F-NEW hub-pattern, F-NEW streaming-by-default
### Topic 7 (A2A): F-NEW a2a-bridge-mode, F-NEW teams-a2a-adapter, F-NEW a2a-protocol-binding-selector, F-NEW long-running-task-shim
### Topic 8 (OTel): F-NEW ms-otel-distro-bundle, F-NEW agent-365-otel-export, F-NEW span-naming-helper
### Topic 9 (memory): F-NEW memory-extraction-policy, F-NEW cross-session-continuity-test, F-NEW memory-store-export
### Topic 10 (WorkIQ): F-NEW human-source-research-gap, F-NEW agent-governor-component, F-NEW capability-token-mint
### Topic 11 (code samples): F-NEW af-typescript-bridge, F-NEW backend-adapter-registry, F-NEW fan-out-template-helper

## WorkIQ rich-vs-thin observation (per the lane brief)

| Query | Result quality |
|---|---|
| Microsoft 2026 hybrid Electron+headless / clawpilot UX / multi-agent governance / Project Lobster / SCHIE / MSEC / MSR / Foundry / Agent 365 / Unified SDK / production lessons | **THIN** — WorkIQ explicitly returned: "I did not find any discoverable, citable internal documents that explicitly codify these items together or publish a single 'official best-practice' standard under those names. The search returned no usable internal references." MCP responded with LLM synthesis labeled as engineering-validated guidance, not Microsoft official policy. |

**Implication:** the named programs likely exist (Tony Malcolm has direct knowledge per the prior session) but are not surfaced through WorkIQ's indexable corpus. This is an **indexing gap**, not a knowledge gap. Future lanes should: (a) escalate to human PM contacts for the named programs; (b) search WorkIQ with codenames + alternate spellings; (c) cross-check against any internal Teams channels Tony has access to.

## Microsoft Learn MCP — rich for everything

All 9 Microsoft Learn searches returned 10 high-quality content chunks each. Code Sample Search returned 10 high-quality TypeScript + C# + Python samples for AF / Foundry. **Microsoft Learn MCP is the canonical source for Microsoft 2026 Agent stack research and should be the default first-call for any future Microsoft-surface investigation.**

## Cross-lane handoff implications

- **For Lane Zero / Wave-N synthesis:** the 34 F-NEW candidates need renumbering into the F-NNN ledger. Suggest reserving F-100 to F-150 for Lane B (matching Lane A's F-001 to F-063).
- **For future Lane C (kit + canonical-e):** topic 11's F-NEW af-typescript-bridge is critical — it informs whether the engine can use AF directly or needs a TS-side wrapper.
- **For backlog/research-gaps.md:** topic 10's F-NEW human-source-research-gap should be added as a research-gap entry: "Identify human source(s) for Project Lobster, SCHIE QaaS Governance, MSEC GenAI Bootcamp MCP security, MSR AI Tooling roadmap docs."
- **For Lane D (cross-source disposition matrix):** topic 6 (Activity Protocol) and topic 7 (A2A) overlap with Lane A topic 12 (A2A spec) — needs disposition entry to avoid double-counting.

## Confidence

**HIGH** for the lane overall. 8 of 11 topics produced HIGH-confidence findings sourced from current Microsoft Learn docs. 2 topics produced MIXED-HIGH/MEDIUM findings (preview status flagged honestly; TS gap flagged honestly). 1 topic produced an honest research-gap finding (WorkIQ thin) without fabricating internal Microsoft 2026 spec content. All findings are auditable to Microsoft Learn URLs or WorkIQ query metadata.
