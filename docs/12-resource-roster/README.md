# 12 — Resource roster

Per Goal G16 / Message 21 ("use the tools Microsoft provides me as well. we have many many benefits internally") and the user directive "we need all our resources at our disposal here to create this next iteration."

## Resource map

| Resource | What it does | When to use | File |
|---|---|---|---|
| Claude Code (this session) | Primary orchestrator; subagent dispatch; MAD pipeline | Always-on driver | `claude-code-instances.md` |
| Additional Claude Code sessions | Parallel work on disjoint waves | When a wave's lanes can fan out across processes | same |
| Copilot CLI multi-model dispatch | Cross-model design review (Claude Opus + GPT-5+) | Every N=5 waves per QG7; per-feature high-blast-radius reviews | `copilot-cli.md` |
| Subagent types | Task-specific deep work per `agent-teams.md` | ≥3 disjoint lanes per wave | `subagent-types.md` |
| WorkIQ MCP | Microsoft-internal context (Project Lobster, SCHIE, MSEC, MSR) | At least one lane per N=3 waves per QG8 | `microsoft-internal-tools.md` |
| Microsoft Learn MCP | 2026 Microsoft official guidance | Same | same |
| microsoft_code_sample_search | Microsoft official code samples | Code-pattern research | same |
| WebSearch + WebFetch | Frontier external research | Per-wave research lanes | per kit's anti-hallucination discipline |
| GitHub `gh` CLI | Repo management, PR ops, issue tracking | Commit / push / PR / issue | NOTE: identity must be `tmalcolm`, NOT `tonym_microsoft` (EMU). Check with `gh auth status` before remote ops. |
| PowerShell scripts | Deterministic ops (`Run-DotnetGates.ps1`, `Diagnose-LensDcsDeploy.ps1`, etc.) | When a deterministic check exists | per-script docs in MAD kit |
| Geneva / Kusto / dgrep | Microsoft logging/telemetry | Production diagnostics | `dgrep-query` skill |
| Council skills | Multi-agent adversarial review | Design reviews, retros | per-skill SKILL.md in MAD kit |
| MAD pipeline skills | Spec-driven feature dev | Per-feature implementation | per-skill SKILL.md in MAD kit |
| Cron / ScheduleWakeup | Self-paced loop continuation | Long waiting periods (>warm-cache) | `loop-cadence-discipline.md` |

## Per-resource files (planned)

- `claude-code-instances.md` — how to spin up another Claude Code session for parallel work
- `copilot-cli.md` — Invoke-CopilotMultiModel.ps1 dispatch protocol
- `microsoft-internal-tools.md` — WorkIQ, msft-learn, microsoft_code_sample_search, Geneva, Kusto, dgrep
- `subagent-types.md` — which subagent for which task (research-scout, code-investigator, code-implementer, parallel-researcher, general-purpose, domain-reviewer)
- `mcp-server-roster.md` — available MCP servers + capabilities

These are populated by Wave 1 Lane D (MAD-kit + canonical-e foundational mapping) and refined per wave.
