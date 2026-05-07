---
artifact-class: research-finding
source-tag: [R:software-patterns]
confidence: high
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://www.firecrawl.dev/blog/ai-agent-sandbox
  - https://beyondscale.tech/blog/ai-agent-sandboxing-enterprise-security-guide
  - https://medium.com/@simoncalabrese94/the-architecture-of-autonomy-ai-harness-in-openai-agents-sdk-pydantic-ai-b70179c1c3f5
  - https://northflank.com/blog/how-to-sandbox-ai-agents
  - https://arxiv.org/html/2604.11839
  - https://medium.com/@romanklis/the-invisible-wall-of-ai-security-running-local-autonomous-agents-without-the-risk-7193d36ce4a0
  - https://edera.dev/stories/what-is-an-ai-agent-sandbox
  - https://northflank.com/blog/best-code-execution-sandbox-for-ai-agents
---

# Agent autonomy + sandboxing patterns (unbounded agents are a liability)

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter.

## Load-bearing patterns

- **"Unbounded agents are a liability" is the 2026 industry consensus**. Major platform updates (OpenAI Agents SDK, Anthropic Claude Code restrictions, exposure incidents at multiple vendors through 2025-2026) all converge on: autonomy without isolation = automated vulnerability. Containerless agents are no longer acceptable for production.
- **Sandbox = stack of 4 independent isolation boundaries**:
  1. **Network egress controls** — explicit allow-list, no default-internet. Untrusted agents must declare which hosts they need.
  2. **Filesystem boundaries** — chrooted or container-FS scope; no host-FS escape; explicit mount-points for inputs/outputs.
  3. **Process isolation** — separate PID namespace; no host process visibility; resource limits (CPU/mem/fork-bomb protection).
  4. **Secrets scoping** — explicit allow-list of env vars; no env-var pass-through by default; injected secrets scrubbed from logs and outputs.
  No single boundary is sufficient. The shift from "container is good enough" to "4-layer stack required" is the central 2026 architecture shift.
- **Container isolation strength tiers (weakest → strongest)**:
  - **Standard containers (Docker, OCI)**: shared host kernel; not sufficient for untrusted code execution. Safe for trusted code only.
  - **gVisor**: user-space kernel interception; mid-tier; runs containers but interposes syscalls. Reasonable for most LLM-generated code.
  - **MicroVMs (Firecracker, Kata Containers)**: dedicated kernel per workload; strongest isolation outside hardware enclaves. Required for "truly untrusted" code execution.
  Industry trajectory: containers were the 2024 default; gVisor was the 2025 default; microVMs are the 2026 default for new agentic platforms.
- **Environment variable leakage is the #1 sandbox blind spot**. A "properly isolated" sandbox can still exfiltrate secrets passed as env vars — through logs, through model context, through tool outputs. Mitigation: explicit env-scrubbing + network-egress control (egress is the exfil channel; cutting it neutralizes most env-var leaks even if the secret reaches the agent).
- **2026 platform shipments**: Cloudflare, Vercel, Ramp, Modal all shipped sandbox features in late 2025 / early 2026. OpenAI's new Agents SDK ships sandboxing as a first-class primitive (not opt-in). Anthropic's Claude Code restricts code-file reads from main orchestrator (delegation pattern) — a different shape of the same concern.
- **Capability-based access (vs role-based)**: emerging research direction (arxiv 2604.11839 "Learned Capability Governance") proposes capabilities granted per-task, with usage learned and refined. Distinct from static sandbox policies; requires runtime monitoring + policy adaptation. Frontier-stage; not yet production-default.

## Verbatim quotes worth preserving

> "Unbounded agents are a liability."

> "Autonomy without security is an automated vulnerability."

> "Standard containers share the host kernel and are not sufficient isolation for agentic workloads that execute LLM-generated code or call external tools."

> "Environment variable leakage is the biggest security blind spot in agent sandboxing."

## Implications for the engine catalog

The kit currently does NOT have a sandbox primitive. The Bash tool runs with full user privileges, the Write tool can target any path the user has access to, and there's no per-skill resource limit. The kit's blast-radius management is via convention (orchestrator-identity, dangerous-operations-policy, tool allow-listing per skill), not via mechanical isolation. This is acceptable for a single-user dev kit; it is NOT acceptable for any multi-tenant or hosted shape.

F-NNN candidates: (a) explicit sandbox-tier declaration per skill (none / process-isolated / container / microVM), (b) network-egress control as a settings.json primitive, (c) env-scrubbing rule (no env vars pass to subagent contexts unless explicitly listed), (d) capability-based access as an aspirational design direction (track for v2+).

## NEW F-NNN candidates

- F-089 sandbox-tier-declaration — Every skill SKILL.md MUST declare sandbox tier: `none | process | container | microvm`. Skills with declared `none` cannot invoke Bash/Write to host paths. Default for new skills: `process` (no host-FS write, scoped tmpdir only) — confidence: H
- F-090 env-scrub-rule — `.claude/rules/env-var-scope.md`: only env vars in declared allow-list pass to subagent invocations + tool calls. Default scrubs: ANTHROPIC_API_KEY, AZURE_*, GITHUB_*, AWS_* (anything looking like a credential) — confidence: H
- F-091 network-egress-allowlist — Engine settings.json supports `network-egress-allowlist` per skill: declare which hosts/domains are reachable. Default: deny-all for sandbox-tier `container|microvm`, allow-all for `process|none` (existing behavior, but now declared) — confidence: M
- F-092 four-boundary-audit — `/skill-audit` checks all 4 boundaries (network / FS / process / secrets) per skill against declared sandbox tier; gap-flag in matrix. Currently no audit covers this — confidence: H
- F-093 microvm-mode-aspirational — Document microVM-tier sandbox as aspirational design direction in roadmap; cite Firecracker/Kata as candidate runtimes; track when LENS/CMS or any consumer project needs this — confidence: L

## Confidence

HIGH — "unbounded agents are a liability" is the most-cited single phrase across the 8 sources; the 4-boundary stack model is consistently described; tier ordering (containers / gVisor / microVMs) matches across multiple independent sources. The kit's gap here is large and known.
