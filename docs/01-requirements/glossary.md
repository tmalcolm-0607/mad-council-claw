# Glossary

## Source-tag legend

Used in feature catalog ledgers, research findings, and synthesis sections. Cites provenance.

| Tag | Meaning |
|---|---|
| `[V:N]` | Verbatim Message N from `session-requests.md` (the originating chat session) |
| `[R:topic]` | Prior research finding (loop work iter 1-4 from before the methodology was formalized; preserved as baseline research) |
| `[K:path]` | MAD kit reference at `C:\Users\tonym\Repos\MAD - Clean\.claude\` or `.mad\` |
| `[CP:path]` | Clawpilot reference at `C:\Users\tonym\Repos\m-main\` |
| `[CE:path]` | Canonical-e reference at `C:\Users\tonym\Repos\MAD - Clean\specs\15-collab-engine-canonical-e\` |
| `[A:filename]` | Existing artifact on disk under `specs/15-nested-quilt/` (the prior session's outputs) |
| `[NEW]` | Synthesis-time conclusion not from any single prior source |

## Confidence labels

| Label | Threshold | Treatment |
|---|---|---|
| HIGH | ≥80% | Auto-pickup eligible by next available instance; auto-apply for kit/CLAUDE.md/plan changes per kit governance |
| MEDIUM | 50-79% | Kept in backlog; needs more research or user input before action |
| LOW | <50% | Dropped (with rationale) OR moved to research-gaps for evidence-gathering |

## Identifier prefixes

| Prefix | Meaning |
|---|---|
| `M0`..`M19` | Milestone numbers in the feature catalog |
| `F-NNN` | Feature identifier (zero-padded; F-001..F-126 in the current catalog) |
| `F-D-NNN` | Deferred feature identifier (F-D-001..F-D-018) |
| `Q-N` | Open question awaiting user decision |
| `D-N` | Design decision (pending or closed) |
| `R1`..`R41` | Rules / methodology numbering from prior research iterations |
| `MR1`..`MR11` | Methodology Rules in the loop plan |
| `QG1`..`QG9` | Per-wave quality gates |
| `L1`..`L4` | Standing milestones (lock-in events) |
| `G1`..`G25` | Goals — each cites the message it derives from |

## Key terms

- **Wave** — one iteration of the continuous loop. ≤5 min wall-clock per warm-cache discipline. Multi-lane fan-out per agent-teams.md.
- **Lane** — one parallel subagent within a wave. ≥3 lanes per wave (lane A/B/C/D pattern). Each lane writes findings to disk.
- **Lane Zero** — the bootstrap/repo-state lane that runs FIRST in a wave, sequentially, before research lanes (so research lanes can commit findings).
- **Pickup point** — a location in `docs/11-loop-state/current-wave.md` where a fresh instance can claim work without coordinating with the orchestrator.
- **Council review** — Advocate / Skeptic / Architect multi-role adversarial review per `/council-review` skill.
- **Copilot CLI dispatch** — parallel cross-model review (Claude Opus + GPT-5+) via `Invoke-CopilotMultiModel.ps1`.
- **RED / GREEN / LOCKED** — feature lifecycle states. RED = failing test exists. GREEN = test passes. LOCKED = council-review verdict says don't change without explicit re-review.
- **Warm-cache zone** — `delaySeconds` <300s for loop wakes, per `loop-cadence-discipline.md`. Above 300s exits Anthropic prompt-cache TTL; below 270s keeps cache hot.

## Reference repositories

| Repo | Path | Purpose |
|---|---|---|
| MAD kit (this engine's source kit) | `C:\Users\tonym\Repos\MAD - Clean\.claude` + `.mad` | Skills, rules, hooks, scripts, templates we inherit from |
| Clawpilot reference | `C:\Users\tonym\Repos\m-main` | UX patterns + Electron + MCP wiring + Skills + Permissions + Automations |
| Canonical-e reference | `C:\Users\tonym\Repos\MAD - Clean\specs\15-collab-engine-canonical-e\` | Governance discipline (hash audit, halt, cost ledger, soul boundary, deterministic replay) |
| Prior session artifacts | `C:\Users\tonym\Repos\MAD - Clean\specs\15-nested-quilt\` | REVIEW.md, review-distilled.md, rules-without-hooks-audit.md, per-item-review.md, surface-map.md, features/F-001 |
