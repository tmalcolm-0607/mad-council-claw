# 04 — Research

Research findings organized by source. HIGH and MEDIUM confidence both kept; LOW dropped or moved to `docs/10-backlog/research-gaps.md` for evidence-gathering.

## Sub-directories

- `frontier-2026/` — Anthropic, OpenAI, MCP, GitHub Copilot, Cursor, Windsurf, Devin/Aider/Cline/Continue research findings (2026 timeframe).
- `microsoft-2026/` — Microsoft Agent Framework, Foundry Agent Service, Agent 365 SDK, M365 Copilot extensibility, Activity Protocol, A2A, OTel GenAI, WorkIQ internal context.
- `openclaw-clawpilot/` — clawpilot codebase walk + openclaw issue #43367 + openclaw v4.0 roadmap + lessons learned.
- `software-patterns/` — generic software-build patterns (multi-tier model routing, RAG, context-window management, orchestrator-worker, etc.).

## Per-finding contract

Every finding file MUST carry frontmatter:

```yaml
---
title: <topic>
source: <URL | file:line | tool name>
confidence: high | medium
wave-introduced: wave-NNN
last-revisited: YYYY-MM-DD
---
```

And cite at least one source per claim per Goal G16 / quality-gate QG2.
