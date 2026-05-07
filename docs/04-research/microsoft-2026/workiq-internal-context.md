---
artifact-class: research-finding
source-tag: [R:microsoft-2026]
confidence: medium
wave: wave-001
lane: lane-b
date: 2026-05-07
sources:
  - WorkIQ ask_work_iq query response (Microsoft-internal SharePoint, FTE-only) — no indexed source-doc hits returned
---

# WorkIQ internal context — Microsoft 2026 best practices for hybrid Electron+headless AI agent platforms

## Sources

- **WorkIQ MCP query** (issued 2026-05-07): "What are the Microsoft 2026 internal best practices for hybrid Electron+headless AI agent platforms combining clawpilot UX with multi-agent governance? Include Project Lobster, SCHIE QaaS Governance, MSEC GenAI Bootcamp MCP security, MSR AI Tooling, internal Foundry guidance, Agent 365 roadmap, Unified SDK Plan, and lessons learned from production multi-agent deployments."
- **Result:** WorkIQ returned **NO citable internal source-docs** matching the queried programs. Response was a labeled "engineering-validated synthesis" (the MCP's own LLM synthesis), explicitly marked: *"I did not find any discoverable, citable internal documents that explicitly codify these items together or publish a single 'official best-practice' standard under those names."*

## Load-bearing patterns

### Disclosure (the most important finding)

The named programs (Project Lobster, SCHIE QaaS Governance, MSEC GenAI Bootcamp MCP security, MSR AI Tooling, internal Foundry guidance, Agent 365 roadmap, Unified SDK Plan) **do not have indexed SharePoint documents** that WorkIQ can surface. Two interpretations:
1. **Indexing gap** — these initiatives exist but are not surfaced through WorkIQ's indexable corpus (private Teams channels, restricted sites, OneNote-only).
2. **Naming variance** — the named programs may exist under different internal codenames; WorkIQ failed to deduplicate.

**For our engine catalog, this is a research gap that needs human escalation** (e.g., "Tony Malcolm to ask <PM contact> about SCHIE QaaS Governance docs by codename"). It is NOT acceptable to fabricate official Microsoft 2026 guidance from an LLM synthesis.

### What WorkIQ DID return — labeled as synthesis

The response was a 9-section "engineering-validated best-practice synthesis" that "reflects patterns consistently observed across Microsoft production GenAI systems, security reviews, MSR research principles, and enterprise governance norms." The response **explicitly disclaimed** this is not "official Microsoft policy or documented guidance".

The 9 sections:

1. **Platform Architecture: Electron + Headless Agent Core**
   - Pattern: Electron is UX-only; all agent logic runs headless/remote/sandboxed. No model reasoning or tool orchestration in the client.
   - Practices: Electron handles identity bootstrap (AAD/MSAL), UX rendering, secure channel to agent gateway. Headless service owns planning, reflection, tool calling, memory, state, policy enforcement.
   - Why: Enables revocation, governance, hot-patching. Aligns with Zero Trust + MSEC guidance.

2. **"Clawpilot" UX Model (Human-in-the-Loop by Design)**
   - Pattern: AI proposes → human pulls execution ("claw") rather than auto-acts. Every irreversible action requires explicit user confirmation.
   - Practices: Separate reasoning view / action plan / execution controls. Progressive disclosure. Default to dry-run / explain mode.

3. **Multi-Agent Governance — Do NOT let agents self-govern**
   - Pattern: Agents are workers, not authorities. Governance is external + deterministic.
   - Central Agent Governor service enforces tool allow-lists, token/cost budgets, timeouts, max recursion / delegation depth.
   - Roles: Planner / Executor / Verifier / Observer. No agent can modify policy, spawn unrestricted agents, or access secrets directly.
   - Stated production lesson: "Agent-to-agent autonomy without an external governor always degenerates."

4. **MCP / Tool Security (aligned with MSEC GenAI Bootcamp)**
   - Tools ≠ APIs. Tools are privileged capabilities.
   - Each tool: contract schema, risk tier, independently auditable.
   - Use capability tokens, NOT ambient identity.
   - Enforce input validation, output classification, side-effect declaration.
   - Log tool intent, arguments, result hash.
   - Never: pass raw credentials to an agent; let an agent construct arbitrary tool calls.

5. **SCHIE / QaaS-Style Governance (Quality as a Service)**
   - Quality gates as services, not checklists.
   - Pre-execution: safety classifier, data boundary check.
   - Post-execution: outcome verifier agent, policy diff (expected vs actual).
   - Continuous: golden prompts, regression replay, drift detection.

6. **MSR-Influenced Agent Design Principles**
   - Decompose cognition: planning ≠ execution ≠ verification.
   - Prefer explicit state machines over emergent behavior.
   - Constrain reasoning with structure, not prompts alone.
   - Treat memory as: versioned, scoped, expirable.

7. **Foundry-Style Engineering Guidance (Applied)**
   - Treat agents like distributed systems: idempotency, retries, back-pressure.
   - First-class telemetry: prompt ID, agent ID, tool ID.
   - Design for rollback: reversible actions, compensation flows.

8. **Agent 365 / Unified SDK Direction (Observed Trajectory)**
   - Convergence on: shared agent runtime abstractions, standard tool schemas, policy-as-code.
   - SDKs focus on hosting + governance, not "smart prompts".
   - Implication: avoid proprietary prompt DSLs; externalize policy; keep agents portable.

9. **Lessons Learned from Production Multi-Agent Deployments** (synthesis-level claims)
   1. Autonomy scales risk faster than value
   2. Observability beats clever prompts
   3. Governance must be synchronous, not advisory
   4. Human trust collapses without explainability
   5. Cost controls must be architectural, not post-hoc

### Reference architecture (synthesis-level only)

```
Electron UX
  └── Secure Gateway
        └── Agent Governor
              ├── Planner Agent
              ├── Executor Agent
              ├── Verifier Agent
              └── Tool Registry
                    └── Audited MCP Tools
```

## Verbatim quotes worth preserving

> "I did not find any discoverable, citable internal documents that explicitly codify these items together or publish a single 'official best-practice' standard under those names. The search returned no usable internal references." — WorkIQ response, 2026-05-07

> "Treat this as engineering-validated guidance, not a formally published spec." — WorkIQ response

## Implications for the engine catalog (refs F-NNN)

These implications carry **MEDIUM confidence** because the underlying source is WorkIQ's own LLM synthesis, not citable internal docs. They should be cross-referenced against (a) Lane A frontier-2026 research, and (b) human-confirmed program owners.

- **F-electron-uxonly-headless-agent-core** — pattern matches our existing kit's separation (clawpilot UX in Electron / engine in headless). Treat as confirmed by synthesis but verify with at least one human source.
- **F-claw-pull-execution-model** — formalize the "AI proposes → human pulls" interaction shape. Already aligns with our `dangerous-operations-policy.md` consent gates.
- **F-external-agent-governor** — adopt the "agent governor" pattern as a first-class component. Tool allow-lists / budgets / timeouts / recursion limits all configured externally to the agent itself. Maps to our existing rule fences.
- **F-capability-tokens** — tools accept capability tokens, not ambient identity. Critical for any production deployment.
- **F-quality-as-a-service** — SCHIE/QaaS-style: quality gates run as services on every agent execution. Maps to our existing eval framework.
- **F-cognition-decomposition** — adopt Planner / Executor / Verifier role split as engine's default agent topology (not just a 3-role review).
- **F-versioned-scoped-expirable-memory** — engine memory primitive carries version + scope + expiry by default. Stricter than Foundry's `user_profile_details`.

## NEW F-NNN candidates (if any)

- **F-NEW: human-source-research-gap** — open research-gap entry: "Identify human source(s) for Project Lobster, SCHIE QaaS Governance, MSEC GenAI Bootcamp MCP security, MSR AI Tooling roadmap docs. Without human source these items are MEDIUM-confidence synthesis only."
- **F-NEW: agent-governor-component** — first-class engine component (separate skill/service) that enforces tool allow-lists, cost budgets, recursion limits, timeout caps before any agent invocation.
- **F-NEW: capability-token-mint** — engine ships a capability-token minting service. Each tool call requires a capability token scoped to (agent_id, tool_id, max_invocations, expiry).

## Confidence

**MEDIUM** — the response is high-quality engineering synthesis but **lacks citable internal sources for the named programs**. The 9-section structure is internally consistent and aligns with patterns we see in public Microsoft Learn docs (Foundry, Agent 365, Copilot Studio multi-agent guidance). It does NOT carry the weight of an "official Microsoft 2026 spec" because no such spec was discoverable.

**Action item for next lane:** escalate to a human contact (PM in the Agent 365 / SCHIE / MSEC GenAI orgs) to either (a) provide indexed source docs, or (b) confirm the synthesis is consistent with non-public internal guidance. Until then, all F-NNN entries derived from this file carry the [SYNTHESIS-NOT-SOURCED] tag.
