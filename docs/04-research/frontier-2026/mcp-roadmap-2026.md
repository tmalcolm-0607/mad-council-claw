---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/
---

# MCP — 2026 Roadmap

## Source
https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/ (fetched 2026-05-07)

## Load-bearing patterns

- **Transport Evolution and Scalability**: ACTIVE priority. Horizontal scaling, session management, metadata discovery via `.well-known` endpoints. Stateless server design. NO new official transports — evolution of HTTP, not replacement.
- **Agent Communication**: ITERATIVE priority. Task-lifecycle improvements: retry semantics, expiry policies. Currently the messiest area; A2A bridges complicate it.
- **Governance Maturation**: IN PROGRESS. Contributor ladder + Working-Group delegation model. SEPs (Spec Enhancement Proposals) move fastest when aligned with priority areas.
- **Enterprise Readiness**: FORMING. Audit trails, SSO auth, gateway behavior, configuration. The slowest-moving area; community WGs needed to advance.
- **On the Horizon (not active)**: SEP-1932 (DPoP), SEP-1933 (Workload Identity Federation) — security/auth work that hasn't entered active development yet.
- **Sampling + Multi-agent coordination NOT addressed**: Listed as "On the Horizon" requiring community WGs. This is a gap relative to A2A and Agents-SDK feature parity.

## Verbatim quotes worth preserving

> "SEPs aligned with the priority areas above will move the fastest."

> "Working and Interest Groups are now the primary vehicle for protocol development."

> "Running it at scale has surfaced a consistent set of gaps: stateful sessions fight with load balancers, horizontal scaling requires workarounds."

## Implications for the engine catalog

The "scalability gap" finding is the most important signal for the engine: stateful MCP sessions don't horizontally scale. The kit's MCP-tiering rule (CLI-tier vs context-tier) is a partial mitigation but doesn't address the underlying architecture. The "no new transports" decision means the engine should NOT invent transports; HTTP + Stdio remain the only sanctioned channels. The "audit trails + SSO" Enterprise-Readiness work maps to the kit's existing `consent-log.jsonl` + dangerous-operations policy — the engine is ahead of MCP here. The Sampling/Multi-agent gap is interesting: the kit's agent-teams orchestration is doing what MCP itself doesn't yet specify.

## NEW F-NNN candidates

- F-025 mcp-stateless-session-discipline — Engine mandates stateless MCP-server interaction patterns; documents the "stateful sessions don't scale" finding as a kit-wide rule — confidence: H
- F-026 mcp-well-known-discovery — Engine uses `.well-known` endpoint discovery for MCP server metadata; falls back to manual config when unavailable — confidence: M
- F-027 mcp-roadmap-tracker — Engine has a tracked roadmap of MCP SEP status (DPoP, Workload Identity, etc.); features that depend on emerging SEPs are flagged as "preview, requires SEP-NNNN" — confidence: M
- F-028 mcp-sampling-gap-bridge — Engine implements multi-agent coordination via the agent-teams pattern (filling the MCP roadmap gap); when MCP eventually specifies, migrate — confidence: H

## Confidence

HIGH — Official MCP roadmap; priorities and gap signals are authoritative. Action items are immediately implementable.
