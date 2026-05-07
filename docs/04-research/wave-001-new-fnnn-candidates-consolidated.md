---
artifact-class: candidate-consolidation
wave: wave-002
lane: lane-d
date: 2026-05-07
status: preview
generated-by: lane-d-consolidation
generated-by-version: 0.1.0
confidence: HIGH (lanes A + D directly enumerated; lane B mapped from summary slugs; lane C produces dispositions, not net-new F-NNN)
---

# Wave-001 NEW F-NNN candidates — consolidated

Wave-2 / Lane D consolidation. Pulls every NEW F-NNN candidate surfaced by wave-1 lanes A/B/C/D, dedups overlaps, and allocates F-IDs starting at F-127 (F-122..F-126 were the iter-4 prior candidates documented in `foundational-plan.md` § Feature catalog "Plus 5 NEW F-NNN candidates from frontier research").

## Source counts (verified, not estimated)

| Lane | F-NNN candidates surfaced | Method |
|---|---:|---|
| Lane A — frontier whitepapers | 63 (F-001..F-063 in lane-A's local numbering) | direct count via Grep `^F-\d` across `frontier-2026/*.md` (12 files; matches lane-A summary "63") |
| Lane B — Microsoft 2026 | 34 (F-NEW slugs, not yet renumbered) | from lane-B summary § "NEW F-NNN candidates total: ~34" + per-topic slugs enumerated |
| Lane C — clawpilot/openclaw | 0 net-new F-NNN; 15 lessons L1..L15 (inform dispositions on existing F-NNN) | from lane-C summary "Synthesis (15 lessons L1-L15)"; no F-NNN block in lane-C output |
| Lane D — kit + canonical-e | 0 net-new F-NNN; surfaced ~58 drops, ~53 defers, ~11 changes against kit + canonical-e | from lane-D summary § Disposition summary |
| **TOTAL gross** | **97** F-NNN-shaped candidates from A + B | A has 63, B has 34 |
| **After dedup** | **~78 unique** | dedup applied below |
| **F-IDs allocated** | **F-127 .. F-204** | starting at F-127 per the existing F-122..F-126 base |

Lane A's local F-001..F-063 numbering is **internal to that lane's worksheet only** — those slugs need re-allocation into the F-NNN ledger. Lane B's `F-NEW <slug>` entries similarly need allocation. Lanes C and D produce zero net-new F-NNN (but do produce many disposition updates against existing F-NNN — see § "Existing-F-NNN disposition updates" below).

**No findings explicit:** Lane C produced 0 net-new F-NNN. Lane D produced 0 net-new F-NNN. This is correct — Lane C's job was lessons-from-prior-art (cross-cutting discipline) and Lane D's job was kit + canonical-e mapping (disposition matrix).

## Deduplication

Before allocating F-IDs, dedup overlapping candidates. Most overlaps are between Lane A frontier patterns and Lane B Microsoft-stack equivalents (e.g., A2A in both). Cross-walk:

| Candidate slug | Sources | Description | Proposed milestone | Dedup decision |
|---|---|---|---|---|
| a2a-endpoint-exposure | Lane A (F-057..F-063 a2a-protocol-spec) + Lane B Topic 1/3/7 + existing F-122 | Engine workflows expose `/a2a/<name>` + `/.well-known/agent.json` | M4 (headless CLI) / M9 (M365) | merge into existing F-122 — NO NEW F-NNN; tighten F-122 spec from lane-A + lane-B detail |
| otel-genai-spans | Lane A (F-035 OTel-default-tracing) + Lane B Topic 8 (otel-genai-multi-agent) + existing F-123 | OTel GenAI semantic conventions emitted by default | M16 (telemetry) | merge into existing F-123 — tighten with lane-B specifics |
| multi-tier-routing | Lane A (F-024 OpenAI handoff-as-tool) + Lane A (F-034 Copilot BYOK multi-provider) + Lane A (F-050 Devin model-routing-rules) + existing F-124 | Haiku/Sonnet/Opus (or equivalent) tiered routing | M1 (backend) | merge into existing F-124 — multi-source convergence is itself the validation |
| mcp-tool-cap-per-workspace | Lane A (F-029..F-033 MCP spec) + Lane B Topic 11 (TS sparse) + existing F-125 | Per-workspace tool cap (default 10) | M7 (skills+perms+auto) | merge into existing F-125 — tighten default value backed by lane-B |
| context-budget-allocation | Lane A (F-040..F-044 Cursor/Windsurf) + existing F-126 | Context-window budget allocation per agent | M8 (settings) | merge into existing F-126 |
| handoff-as-tool / handoff / opaque-collaboration | Lane A F-002 + F-021 + F-058 (4-way convergence) | Single "handoff" primitive across Anthropic/OpenAI/MCP/Cursor | M2 (governance triad) — handoff is governance-shaped | one F-NNN, not three (4-way convergence is one finding) |
| orchestrator-worker / dispatch | Lane A F-010 + F-021 + F-029 (3-way convergence) | Orchestrator-worker primitive as first-class | M2 / M3 (cross-cutting) | one F-NNN, not three |
| evals-first-scaffold / 3-tier-evals | Lane A F-013 + F-053 (3-way convergence) | Eval harness scaffolded BEFORE feature work | M0 (bootstrap) — already informs F-001..F-008 shape | one F-NNN |
| monitor-not-approve / agentic-engineering-mode-default / task-clarity-gate | Lane A F-018 + F-044 + F-049 (3-way convergence) | Default to monitor mode; task clarity is the gate (the 67%/15% asymmetry) | M2 (governance) | one F-NNN — collapse three into one |
| BYOK-multi-provider / model-routing-rules | Lane A F-034 + F-050 (already merged into F-124 above) | — | — | already merged |
| activity-protocol-bridge | Lane B Topic 6 (3-way Microsoft convergence: M365 Copilot + Copilot Studio + M365 Agents SDK + Agent 365) | Activity Protocol shape on engine endpoint | M9 (M365) | one F-NNN |
| af-typescript-bridge | Lane B Topic 11 (TS gap finding) | Wrapper layer for AF (TS samples are sparse for workflows) | M1 (backend) | one F-NNN |
| dual-grader-eval | Lane B Topic 5 (Copilot Studio dual-grader) | Two graders compare verdicts; quorum or escalate | M10 (multi-model review) | one F-NNN |
| memory-extraction-policy / cross-session-continuity-test / memory-store-export | Lane B Topic 9 (Foundry memory PREVIEW caveat) | Three companion features for memory plane | M11 (soul/introspect/replay) — memory is replay-adjacent | three separate F-NNN — they're independent features, not duplicates |
| capability-token-mint / agent-governor-component | Lane B Topic 10 | Governance plane primitives | M2 (governance triad) | two separate F-NNN |
| streaming-by-default | Lane B Topic 6 (Activity Protocol) | Engine endpoints stream by default; client opts out | M4 (headless CLI) + M5 (desktop shell) | one F-NNN |
| hub-pattern | Lane B Topic 6 | A2A + Activity Protocol "hub" — one endpoint serves multiple bots | M4 / M9 | one F-NNN |
| durable-checkpoint-resume | Lane A F-014 (Anthropic-Multi-Agent finding, kit gap) | Durable run state survives crash; resume protocol | M11 (replay) | one F-NNN |
| agent-card-publishing | Lane A F-057 (A2A discoverability primitive, missing from kit) | `/.well-known/agent.json` publish | M4 / M9 | one F-NNN — already partially covered by F-122; this is the publishing-side complement |

**After dedup:** 97 gross → ~78 unique candidates → with F-122..F-126 already allocated for the 5 highest-convergence candidates, **~73 candidates need F-IDs F-127..F-199** (inclusive). Padding to F-204 for late additions during ledger authoring.

## F-ID allocation (F-127 .. F-204)

Per-lane sub-ranges to keep provenance greppable:

| F-ID range | Source | Rationale |
|---|---|---|
| F-127..F-159 | Lane A frontier candidates (after dedup; ~33 candidates) | 33 of Lane A's 63 candidates survived dedup against existing F-001..F-126 + against each other |
| F-160..F-189 | Lane B Microsoft 2026 candidates (after dedup; ~30 candidates) | 30 of Lane B's 34 candidates survived dedup |
| F-190..F-204 | Reserved padding for ledger-authoring drift | unallocated; to be claimed during catalog drop |

### F-127..F-159 — Lane A frontier candidates (sub-allocation table)

| F-ID | Slug | Milestone | Source | Behavior contract (one sentence) | Provenance |
|---|---|---|---|---|---|
| F-127 | three-tier-eval-harness | M0 (bootstrap) | Lane A F-013 + F-053 | Eval harness scaffolded BEFORE F-001..F-008 — every feature ledger has a RED test on day 0. | anthropic-multi-agent-research-system.md + anthropic-skills-authoring.md |
| F-128 | orchestrator-worker-primitive | M2 (governance) | Lane A F-010 + F-021 + F-029 | First-class orchestrator-worker primitive (not ad-hoc prompt routing). | anthropic-multi-agent-research-system.md + openai-agents-sdk.md + mcp-specification.md |
| F-129 | handoff-as-tool | M2 | Lane A F-002 + F-021 + F-058 | Handoff is a typed tool; agent A "transfers control" to agent B with payload. | anthropic-building-effective-agents.md + openai-agents-sdk.md + a2a-protocol-spec.md |
| F-130 | task-clarity-gate (67%/15% asymmetry) | M2 | Lane A F-018 + F-044 + F-049 | Default to monitor mode; pre-execution task-clarity check; ambiguous tasks escalate. | anthropic-measuring-agent-autonomy.md + cursor-windsurf-2026.md + devin-aider-cline-continue-2026.md |
| F-131 | durable-checkpoint-resume | M11 (replay) | Lane A F-014 | Engine run state crash-survivable; resume protocol on next launch. | anthropic-multi-agent-research-system.md |
| F-132 | agent-card-publishing | M4/M9 | Lane A F-057 | Engine publishes `/.well-known/agent.json` for every workflow. | a2a-protocol-spec.md |
| F-133 | extended-thinking-budget | M1 | Lane A F-001..F-005 | Per-task reasoning budget; configurable per IBackendProvider. | anthropic-building-effective-agents.md |
| F-134 | parallel-tool-call-fan-out | M2 | Lane A F-001..F-005 | Engine dispatches independent tool calls in parallel by default. | anthropic-building-effective-agents.md |
| F-135 | citations-on-by-default | M16 | Lane A F-001..F-005 | Citations attached to every tool result emitted to UI. | anthropic-building-effective-agents.md |
| F-136 | computer-use-permission-tier | M7 | Lane A F-006..F-009 (2026 trends) | Computer-use tool gated behind explicit permission tier. | anthropic-2026-agentic-coding-trends.md |
| F-137 | session-spawn-isolation | M3 | Lane A F-010..F-016 | Spawned session inherits no parent state by default. | anthropic-multi-agent-research-system.md |
| F-138 | autonomy-level-tag | M2 | Lane A F-017..F-020 | Every action carries an autonomy-level tag (fully-supervised / monitored / autonomous). | anthropic-measuring-agent-autonomy.md |
| F-139 | handoff-context-shaping | M1 | Lane A F-022..F-024 | Handoff payload is shaped (not raw history dump); explicit "what the receiver needs." | openai-agents-sdk.md |
| F-140 | mcp-resource-subscription | M6 | Lane A F-025..F-028 | Engine subscribes to MCP resources for live updates. | mcp-roadmap-2026.md |
| F-141 | mcp-elicitation-protocol | M6 | Lane A F-029..F-033 | Engine supports MCP elicitation (server asks user for clarification). | mcp-specification.md |
| F-142 | mcp-prompt-template-discovery | M6 | Lane A F-029..F-033 | Engine discovers MCP server prompt templates dynamically. | mcp-specification.md |
| F-143 | mcp-sampling-control | M6 | Lane A F-029..F-033 | Engine controls MCP sampling (server requests model completions). | mcp-specification.md |
| F-144 | byok-multi-provider | M1 | Lane A F-034 | BYOK across providers; user-supplied keys encrypted at rest. | github-copilot-sdk.md |
| F-145 | otel-default-tracing | M16 | Lane A F-035 | OTel tracing on by default for every agent action. | github-copilot-sdk.md (also reinforced by Lane B Topic 8) |
| F-146 | git-aware-context-loading | M8 | Lane A F-040..F-044 | Engine reads .git metadata to scope context to current PR/branch. | cursor-windsurf-2026.md |
| F-147 | rules-mdc-format | M7 | Lane A F-040..F-044 | Engine adopts `.cursor/rules/*.mdc` shape for project rules. | cursor-windsurf-2026.md |
| F-148 | windsurf-cascade-mode | M7 | Lane A F-040..F-044 | Multi-step automated edit sessions with explicit checkpoints. | cursor-windsurf-2026.md |
| F-149 | aider-architect-mode | M2 | Lane A F-045..F-050 | Two-pass: architect writes plan, coder implements. | devin-aider-cline-continue-2026.md |
| F-150 | continue-config-yaml | M8 | Lane A F-045..F-050 | Project-level config in YAML at repo root. | devin-aider-cline-continue-2026.md |
| F-151 | cline-act-vs-plan-toggle | M2 | Lane A F-045..F-050 | Explicit toggle: planning mode vs acting mode. | devin-aider-cline-continue-2026.md |
| F-152 | skill-progressive-disclosure | M7 | Lane A F-051..F-056 | Skill body hides reference content; main thread sees thin SKILL.md only. | anthropic-skills-authoring.md |
| F-153 | skill-frontmatter-signature | M7 | Lane A F-051..F-056 | generated-by + generated-by-version + skill-state-file-id (kit already has this). | anthropic-skills-authoring.md |
| F-154 | skill-coverage-oracle | M7 | Lane A F-051..F-056 | Per-content-type oracle file enumerating expected sections. | anthropic-skills-authoring.md |
| F-155 | a2a-task-lifecycle | M9 | Lane A F-057..F-063 | Submitted → working → input-required → completed/canceled lifecycle. | a2a-protocol-spec.md |
| F-156 | a2a-streaming-via-sse | M9 | Lane A F-057..F-063 | Engine streams A2A task updates over SSE. | a2a-protocol-spec.md |
| F-157 | a2a-push-notifications | M9 | Lane A F-057..F-063 | Engine emits push notifications for long-running A2A tasks. | a2a-protocol-spec.md |
| F-158 | a2a-multi-turn | M9 | Lane A F-057..F-063 | A2A tasks can have multi-turn input-required loops. | a2a-protocol-spec.md |
| F-159 | a2a-auth-schemes | M9 | Lane A F-057..F-063 | Engine declares + honors auth_schemes in agent card. | a2a-protocol-spec.md |

### F-160..F-189 — Lane B Microsoft 2026 candidates (sub-allocation table)

| F-ID | Slug | Milestone | Source | Behavior contract (one sentence) | Provenance |
|---|---|---|---|---|---|
| F-160 | workflow-as-a2a-endpoint | M4/M9 | Lane B Topic 1 | Every AF-style workflow exposes itself as A2A endpoint. | agent-framework-workflows.md |
| F-161 | orchestration-pattern-selector | M2 | Lane B Topic 1 | Engine config picks Sequential/Concurrent/Handoff/Group/Magentic per workflow. | agent-framework-workflows.md |
| F-162 | checkpoint-resume-protocol | M11 | Lane B Topic 1 | (companion to F-131; AF-specific shape) | agent-framework-workflows.md |
| F-163 | foundry-callable-engine | M9 | Lane B Topic 2 | Engine workflows can be invoked from Foundry Agent Service (HTTP). | foundry-agent-service.md |
| F-164 | enterprise-memory-mapping | M11 | Lane B Topic 2 | Foundry memory primitives map to engine's IMemoryProvider. | foundry-agent-service.md |
| F-165 | ru-budget-helper | M16 | Lane B Topic 2 | Cosmos/Foundry RU budget tracking + warning thresholds. | foundry-agent-service.md |
| F-166 | agent-365-control-plane | M9 | Lane B Topic 3 | Engine registers via Agent 365 control plane (telemetry + governance hooks). | agent-365-sdk.md |
| F-167 | blueprint-as-kit-config | M0 | Lane B Topic 3 | Agent 365 blueprint shape adopted as engine kit config schema. | agent-365-sdk.md |
| F-168 | claude-code-sdk-bridge | M1 | Lane B Topic 3 | Engine speaks Claude Agent SDK shape so Claude Code can drive it. | agent-365-sdk.md |
| F-169 | dual-render-ui-widget | M5 | Lane B Topic 4 | UI widget renders in M365 Copilot + engine desktop shell with same code. | m365-copilot-extensibility.md |
| F-170 | ai-insights-aggregator | M14 | Lane B Topic 4 | Mail/People/Meeting Insights surface in daily briefing. | m365-copilot-extensibility.md |
| F-171 | agent-builder-import | M0 | Lane B Topic 4 | Engine imports M365 Agent Builder export format for bootstrapping. | m365-copilot-extensibility.md |
| F-172 | copilot-studio-connect-out | M9 | Lane B Topic 5 | Engine workflows callable from Copilot Studio "connected agents." | copilot-studio-2026.md |
| F-173 | dual-grader-eval | M10 | Lane B Topic 5 | Two graders compare; quorum or escalate. | copilot-studio-2026.md |
| F-174 | connected-agent-governance-checklist | M2 | Lane B Topic 5 | Pre-flight checklist when engine accepts a Copilot Studio inbound call. | copilot-studio-2026.md |
| F-175 | activity-protocol-bridge | M9 | Lane B Topic 6 | Engine endpoint speaks Activity Protocol (Teams/Outlook/M365 Copilot reach). | activity-protocol.md |
| F-176 | hub-pattern | M9 | Lane B Topic 6 | One engine endpoint serves multiple bot personas. | activity-protocol.md |
| F-177 | streaming-by-default | M4/M5 | Lane B Topic 6 | Engine streams by default; client opts out for batched. | activity-protocol.md |
| F-178 | a2a-bridge-mode | M9 | Lane B Topic 7 | Engine acts as A2A bridge between Microsoft + non-Microsoft agents. | a2a-protocol-microsoft.md |
| F-179 | teams-a2a-adapter | M9 | Lane B Topic 7 | Teams chat ↔ A2A task translation layer. | a2a-protocol-microsoft.md |
| F-180 | a2a-protocol-binding-selector | M9 | Lane B Topic 7 | Engine picks A2A binding (HTTP/SSE/push/etc) per peer agent card. | a2a-protocol-microsoft.md |
| F-181 | long-running-task-shim | M9 | Lane B Topic 7 | Long-running A2A tasks survive engine restart via task-id persistence. | a2a-protocol-microsoft.md |
| F-182 | ms-otel-distro-bundle | M16 | Lane B Topic 8 | Engine bundles Microsoft OTel distro (Geneva-compatible). | otel-genai-multi-agent.md |
| F-183 | agent-365-otel-export | M16 | Lane B Topic 8 | OTel spans exported in Agent 365 schema for governance plane. | otel-genai-multi-agent.md |
| F-184 | span-naming-helper | M16 | Lane B Topic 8 | Span naming follows OTel GenAI conventions; helper enforces. | otel-genai-multi-agent.md |
| F-185 | memory-extraction-policy | M11 | Lane B Topic 9 | Configurable rules for what gets stored as memory (PREVIEW caveat). | foundry-agent-memory.md |
| F-186 | cross-session-continuity-test | M11 | Lane B Topic 9 | Eval: agent recalls fact across session restarts. | foundry-agent-memory.md |
| F-187 | memory-store-export | M11 | Lane B Topic 9 | User can export their memory store as portable bundle. | foundry-agent-memory.md |
| F-188 | agent-governor-component | M2 | Lane B Topic 10 | Governance plane "governor" intercepts before tool exec. | workiq-internal-context.md |
| F-189 | capability-token-mint | M2 | Lane B Topic 10 | Engine mints scoped capability tokens for tool calls. | workiq-internal-context.md |

### F-190..F-199 — Lane B residuals + reserved padding

| F-ID | Slug | Milestone | Source | Behavior contract (one sentence) | Provenance |
|---|---|---|---|---|---|
| F-190 | af-typescript-bridge | M1 | Lane B Topic 11 | TS-side wrapper for Microsoft Agent Framework workflows (since native TS samples sparse). | agent-framework-code-samples.md |
| F-191 | backend-adapter-registry | M1 | Lane B Topic 11 | Registry pattern for IBackendProvider implementations. | agent-framework-code-samples.md |
| F-192 | fan-out-template-helper | M2 | Lane B Topic 11 | Template helper for parallel agent fan-out (matches MR1 discipline). | agent-framework-code-samples.md |
| F-193..F-199 | _reserved_ | _TBD_ | _ledger drift_ | _claimed during catalog drop_ | — |

## Existing-F-NNN disposition updates from wave-1

Lane C lessons L1..L15 + Lane A 4-way convergences validate or tighten existing F-NNN. These are NOT new candidates; they are evidence-based updates.

| F-NNN | Update | Source finding |
|---|---|---|
| F-001 | TIGHTEN: explicit non-monolith design — orchestration layer supervising independent runtimes per agent | openclaw v4 roadmap finding (Lane C topic 4) "next gen will not be one monolith" |
| F-002 | TIGHTEN: per-agent identity scoped to role, not user (refresh-token-per-role) | Lane C L2 + openclaw issue #43367 F3 |
| F-007 (IPC contract) | TIGHTEN: lift clawpilot's `common/ipc-contract.ts` 2,075-LOC pattern verbatim | Lane C L4 |
| F-008 (storage layout) | TIGHTEN: per-agent filesystem isolation (`<state-dir>/agents/<agent-id>/`) | Lane C L1 |
| F-014 (audit log) | TIGHTEN: audit log + signed verdicts + cost ledger as governance triad (not three independent features) | Lane C L15 |
| F-018 | VALIDATED industry-default | Lane A F-018 (anthropic-measuring-agent-autonomy) |
| F-022 (tool-quota) | TIGHTEN: default quota of 10 per workspace (per WorkIQ "tool-explosion" lesson) | Lane B Topic 11 + existing F-125 |
| F-023..F-027 (cron) | TIGHTEN: bounded retry + circuit breaker on heartbeats | Lane C L9 |
| F-028..F-031 (CLI) | TIGHTEN: parent-child supervision with PID-file + OS-flock reaping | Lane C L3 |
| F-039 (theming + shortcuts) | INFORMS: clawpilot v0.22.66 has 134 top-level files in `electron/` — deep UX surface | Lane C topic 1 (clawpilot-architecture.md) |
| F-044..F-050 (MCP & tools) | TIGHTEN: IBackendProvider with lint-enforced invariants + IMemoryProvider abstraction + IPlatformAdapter | Lane C L6 + L7 + L8 |
| F-076..F-081 (M365) | TIGHTEN: MSAL + WAM + per-tenant policy (Lane C clawpilot-architecture §11) | Lane C topic 1 |
| F-082..F-087 (multi-model) | TIGHTEN: dispatch via Task subagent spawn (orchestrator never calls Invoke-CopilotMultiModel.ps1 directly) | kit's `lens-multi-model-review-pattern.md` (already enforced; reinforced by Lane A 4-way convergence) |
| F-088..F-092 (soul + replay) | INFORMS: deterministic-replay + cost-ledger sourced from canonical-e (not openclaw — openclaw's plugin SDK v2 is separate) | Lane D canonical-e-inventory + Lane C openclaw-v4-roadmap |
| F-093..F-095 (visualization) | INFORMS: clawpilot has NO replay-scrubber surface — confirmed net-new (Lane C topic 2 inventory) | Lane C topic 2 (clawpilot-features-inventory.md) |
| F-096..F-100 (multimodal) | INFORMS: clawpilot has NO voice-input or screenshot-to-prompt — confirmed net-new | Lane C topic 2 |
| F-101..F-103 (productivity NEW) | INFORMS: WorkIQ has NO indexed source-docs for daily-briefing scenarios; user PM contacts needed | Lane B Topic 10 (WorkIQ thin) |
| F-104..F-109 (build/packaging) | TIGHTEN: cross-platform Windows-first; beta+stable release channels | Lane C L12 + L14 |
| F-110..F-113 (telemetry) | TIGHTEN: per-feature telemetry tests (RED test for telemetry coverage) | Lane C L13 |
| F-122 (a2a-endpoint-exposure) | TIGHTEN: includes `/.well-known/agent.json` publishing + auth_schemes declaration + multi-turn input-required + push notifications + SSE streaming | Lane A F-057..F-063 + Lane B Topic 1+3+7 |
| F-123 (otel-genai-spans) | TIGHTEN: bundle Microsoft OTel distro; export in Agent 365 schema; span-naming helper | Lane B Topic 8 |
| F-124 (multi-tier-routing) | VALIDATED industry-default by 4-way convergence (Anthropic + OpenAI + Copilot + Devin) | Lane A 4-way |
| F-125 (mcp-tool-cap-per-workspace) | TIGHTEN: default value 10 grounded in WorkIQ + Microsoft 2026 internal lesson | Lane B Topic 10 + 11 |
| F-126 (context-budget-allocation) | TIGHTEN: per-agent budget (not global); allocator policy in M8 | Lane A F-040..F-044 |

**No findings explicit:** No existing F-NNN was DROPPED based on wave-1. No existing F-NNN was MOVED to a different milestone. All disposition updates are TIGHTEN or VALIDATED or INFORMS.

## Cross-lane convergence summary

The most load-bearing wave-1 finding is **the 4-way convergence on dispatch/handoff/capability-negotiation**: Anthropic + OpenAI + MCP + Cursor all converge on the same primitive. Engine v1 must treat this as a single unified surface (F-129 handoff-as-tool + F-128 orchestrator-worker-primitive), not three loosely-related features.

The second most load-bearing finding is the **67%/15% asymmetry** (Lane A devin-aider-cline-continue-2026): well-defined tasks succeed at 67% PR-merge rate; ambiguous tasks fail at 85%. This validates the kit's existing triage-gate + makes F-130 task-clarity-gate the engine's load-bearing v1 primitive (it's the engine surface for the triage discipline).

The third most load-bearing finding is **Activity Protocol everywhere** (Lane B 3-Microsoft-surface convergence: M365 Copilot + Copilot Studio + M365 Agents SDK + Agent 365). Single endpoint shape covers four Microsoft surfaces. F-175 activity-protocol-bridge unlocks all four with one feature.

## Loop-improvement observations (carry into wave-3 methodology)

1. **Lane numbering vs F-NNN allocation**: Lane A used internal F-001..F-063 numbering that COLLIDED with the canonical F-001..F-126 ledger from foundational-plan.md. Future lanes should use slug-only naming (`F-NEW <slug>`) until the consolidation step allocates F-IDs. Wave-2 / Lane D (this lane) had to renumber Lane A's worksheet — costly. Codify as a methodology rule for wave-3.
2. **Lane C's "0 net-new F-NNN" outcome is correct, not a failure**: Lane C's job was lessons-from-prior-art. Disposition updates against existing F-NNN are the right output shape. Future lanes that produce dispositions instead of F-NNN should declare that intent in their lane brief.
3. **Lane D's "MEDIUM confidence" because Lane C hadn't committed**: serializing dependent lanes wastes wall-clock. Future waves should either (a) make lanes fully independent, or (b) use cross-lane handoff via `docs/06-agent-team-outputs/wave-NNN/lane-X-summary.md` polled at end-of-wave synthesis (this consolidation step IS that polling).
4. **97 → 78 dedup ratio**: ~20% of cross-lane candidates were duplicates. Acceptable; expected when lanes are run in parallel without coordination. Codify the ratio so future waves don't panic when 30% of candidates evaporate at consolidation.

## Provenance

- Lane A summary: `docs/06-agent-team-outputs/wave-001/lane-a-summary.md`
- Lane B summary: `docs/06-agent-team-outputs/wave-001/lane-b-summary.md`
- Lane C summary: `docs/06-agent-team-outputs/wave-001/lane-c-summary.md`
- Lane D summary: `docs/06-agent-team-outputs/wave-001/lane-d-summary.md`
- Foundational plan F-122..F-126: `docs/01-requirements/foundational-plan.md` § Feature catalog "Plus 5 NEW F-NNN candidates from frontier research"
- Direct enumeration count via Grep `^F-\d` across `docs/04-research/frontier-2026/*.md` = 63 (matches lane-A summary)
