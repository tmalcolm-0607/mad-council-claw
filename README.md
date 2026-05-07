# MAD Council Claw

A hybrid TypeScript + Electron + Vitest engine — clawpilot UX shell + canonical-e governance discipline + MAD kit primitives. Pluggable model backend (Anthropic SDK + GitHub Copilot SDK behind `IBackendProvider`). Both desktop AND headless surfaces. Per-feature RED → GREEN → LOCKED lifecycle with physical proof.

## Status

**Wave 1 in progress** — Lane Zero (repo bootstrap) complete locally. Lanes A-D (research) dispatching next.

The loop runs CONTINUOUSLY, not until convergence. Per-wave quality gates fire before each wave ships its output; the loop itself never stops.

See `docs/11-loop-state/current-wave.md` for the live pickup point.

## Repository layout

| Section | Purpose |
|---|---|
| [`docs/01-requirements/`](docs/01-requirements/) | Foundational plan + verbatim session requests + Goals G1-G25 + glossary |
| [`docs/02-architecture/`](docs/02-architecture/) | Four planes (UX / Orchestration / Tool / Governance), stack decisions, reference architectures, trade-offs |
| [`docs/03-feature-catalog/`](docs/03-feature-catalog/) | ~125 F-NNN features across milestones M0..M19; each ledger has behavior contract + acceptance scenarios + RED test |
| [`docs/04-research/`](docs/04-research/) | Frontier 2026, Microsoft 2026, openclaw + clawpilot, software patterns — confidence-tagged |
| [`docs/05-design-reviews/`](docs/05-design-reviews/) | Council reviews (Advocate / Skeptic / Architect), Copilot CLI multi-model design reviews, retros |
| [`docs/06-agent-team-outputs/`](docs/06-agent-team-outputs/) | Per-wave, per-lane subagent outputs |
| [`docs/07-roadmap/`](docs/07-roadmap/) | Milestone timeline, status history, decision log |
| [`docs/08-behavioral-reasoning/`](docs/08-behavioral-reasoning/) | The "why" library — recurring disciplines and their rationale |
| [`docs/09-examples-proof/`](docs/09-examples-proof/) | Per-feature physical evidence (red-test-output, green-test-output, council verdicts) |
| [`docs/10-backlog/`](docs/10-backlog/) | Open questions, research gaps, design decisions, implementation TODO, feature promotions, retire candidates, dropped-with-rationale |
| [`docs/11-loop-state/`](docs/11-loop-state/) | Current wave, recent improvements, confidence ledger, wave history |
| [`docs/12-resource-roster/`](docs/12-resource-roster/) | What resources we have and how to use them (Claude Code, Copilot CLI, WorkIQ, msft-learn MCP, subagent types, etc.) |

## How to contribute

Any fresh Claude Code session, Copilot CLI invocation, Anthropic SDK session, or other agent can pick up loop work:

1. Read `docs/11-loop-state/current-wave.md` — pickup point and claim table
2. Read `docs/01-requirements/session-requests.md` + `docs/01-requirements/goals.md` — foundational context (do this even if you've worked here before — Goal G24 says start every instance from the same baseline)
3. Read `docs/10-backlog/README.md` — pick an item from `research-gaps.md`, `implementation-todo.md`, or `design-decisions-pending.md`
4. Claim by appending to `current-wave.md`: instance type / claimed item / ETA
5. Execute per `docs/12-resource-roster/<your-instance-type>.md`
6. Output to `docs/06-agent-team-outputs/wave-NNN/lane-<your-handle>-<topic>.md`
7. Commit + PR per micro-session discipline (one feature/topic per PR, ≤1 wave or ≤1 lane or ≤1 feature)
8. Mark backlog item resolved (or partial; back to backlog with progress note)

## Non-negotiables (these survive context compaction)

- Per Goal G21: NEVER create large spanning PRs that are impossible to review/validate
- Per Goal G27 / Message 27: small micro-sessions targeting features with full behavior tests AND physical proof
- Per Message 30+31: requirements are ADDITIVE across the session, NOT sequential overrides; nothing is a "pivot"
- Per Goal G25: don't make assumptions
- Per kit's `no-silent-deferrals.md`: removing user-requested features without asking is forbidden
- Per kit's `no-top-n-capping.md`: enumerate exhaustively; "Top 5" is forbidden in subagent prompts

## License

MIT — see [LICENSE](LICENSE).
