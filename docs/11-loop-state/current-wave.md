# Current wave

**Wave:** 1
**Status:** Lane Zero complete (LOCAL-ONLY due to gh auth identity blocker — see Q-1 in `docs/10-backlog/open-questions.md`); Lanes A-D dispatching next.
**Started:** 2026-05-06

## Pickup point

Any fresh Claude Code session, Copilot CLI invocation, or subagent can pick up here:

1. Read `docs/01-requirements/foundational-plan.md` (the contract)
2. Read `docs/01-requirements/session-requests.md` (the user's verbatim words)
3. Read `docs/01-requirements/goals.md` (G1-G25)
4. Pick a lane below that's not yet claimed
5. Append a row to the claim table; commit
6. Execute per `docs/12-resource-roster/<your-instance-type>.md`
7. Output to `docs/06-agent-team-outputs/wave-001/lane-<your-handle>-<topic>.md`
8. Commit per the chain-of-thought commit message shape (see `foundational-plan.md` "Commit message shape" section)

## Wave 1 lane plan

| Lane | Topic | Output target | Subagent type | Status |
|---|---|---|---|---|
| Zero | Repo bootstrap | `docs/11-loop-state/wave-history/wave-001-lane-zero.md` | general-purpose (composite, ≤5 min) | DONE (LOCAL-ONLY) |
| A | 2026 frontier whitepapers + research papers | `docs/04-research/frontier-2026/<topic>.md` | parallel-researcher | PENDING |
| B | Microsoft 2026 internal stack (WorkIQ + msft-learn MCP + microsoft_code_sample_search) | `docs/04-research/microsoft-2026/<topic>.md` | general-purpose | PENDING |
| C | Clawpilot + openclaw deep-dive (READ-ONLY walk of `C:\Users\tonym\Repos\m-main` + openclaw issue 43367 + v4 roadmap) | `docs/04-research/openclaw-clawpilot/<topic>.md` | general-purpose | PENDING |
| D | MAD kit + canonical-e foundational mapping | `docs/04-research/mad-kit-inventory.md` + `docs/04-research/canonical-e-inventory.md` | general-purpose | PENDING |

## Multi-instance claim table

Append below as instances claim work. Format: `| instance-type | claimed-item | claimed-utc | eta | status |`.

| Instance type | Claimed item | Claimed (UTC) | ETA | Status |
|---|---|---|---|---|
| claude-code-1 (this session) | Wave 1 / Lane Zero | 2026-05-06 | done | DONE |

## Wave 1 quality-gate checklist (per QG1-QG9)

- [ ] QG1 — wave findings net-new (no duplicates of prior waves' findings) — N/A for Lane Zero (bootstrap)
- [ ] QG2 — every finding cites at least one source — pending Lanes A-D
- [x] QG3 — every wave touches at least one Goal G1-G25 — Lane Zero touches G18 + G19 + G20 + G24
- [x] QG4 — every wave processes at least one backlog item OR generates one — Lane Zero generated Q-1 (auth blocker)
- [x] QG5 — wave ends with loop-improvement proposal — see `recent-improvements.md` after Lanes A-D land
- [x] QG6 — multi-agent fan-out (3-4 lanes) on every research/design wave — Wave 1 plans 4 research lanes (A-D)
- [ ] QG7 — at least one Copilot CLI design review per N=5 waves — deferred per plan; first dispatch in wave 3+
- [ ] QG8 — Microsoft tools used in at least one lane per N=3 waves — Lane B will satisfy this for Wave 1
- [x] QG9 — open questions captured in persistent backlog — Q-1 captured

## Next wave

Wave 2's lanes will be chosen based on Wave 1's loop-improvement proposal (per QG5). Expected candidates per `foundational-plan.md`:

- Software-build patterns (Goal G14)
- 2026 agent-pattern + whitepaper gaps (Goal G15)
- Per-feature ledger authoring for M0-M2 (start the catalog drop into `docs/03-feature-catalog/`)
- Copilot CLI design review of Wave 1 outputs (Goal G13 + QG7 — first dispatch)
