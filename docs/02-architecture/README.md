# 02 — Architecture

Engine architecture: the four planes (UX / Orchestration / Tool / Governance), stack decisions, reference architectures consulted, and trade-offs explicitly considered.

## Contents (planned, populated by research waves)

- `4-planes.md` — UX / Orchestration / Tool / Governance plane responsibilities and interfaces
- `stack-decisions.md` — TypeScript + Electron + Vitest; Anthropic SDK + Copilot SDK pluggable behind `IBackendProvider`; both desktop AND headless surfaces
- `reference-architectures.md` — Microsoft Agent Framework, Foundry Agent Service, Agent 365, openclaw, clawpilot — what we adopt and what we adapt
- `trade-offs.md` — options considered and rejected, with rationale

## Why four planes

`[R:WorkIQ Project Lobster + msft-learn agent-framework + clawpilot + canonical-e]` — the four-plane decomposition matches every reference architecture we consulted; each plane has independent failure modes and independent governance hooks.
