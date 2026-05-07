# Current wave

**Wave:** 2
**Status:** In-flight. Lane D (consolidation) just closed wave-1 + tees up wave-3. Other wave-2 lanes (software-patterns, M0-M2 catalog drop) running in parallel.
**Started:** 2026-05-07
**Wave-1 closed:** 2026-05-07 (see `docs/11-loop-state/wave-history/wave-001.md`)

## Pickup point

Any fresh Claude Code session, Copilot CLI invocation, or subagent can pick up here:

1. Read `docs/01-requirements/foundational-plan.md` (the contract)
2. Read `docs/01-requirements/session-requests.md` (the user's verbatim words)
3. Read `docs/01-requirements/goals.md` (G1-G25)
4. Read `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md` (the F-127..F-204 ledger allocation)
5. Read `docs/11-loop-state/wave-history/wave-001.md` (wave-1 closing summary)
6. Pick a lane below that's not yet claimed (or pick a wave-3 candidate)
7. Append a row to the claim table; commit
8. Execute per `docs/12-resource-roster/<your-instance-type>.md`
9. Output to `docs/06-agent-team-outputs/wave-NNN/lane-<your-handle>-<topic>.md`
10. Commit per the chain-of-thought commit message shape (see `foundational-plan.md` "Commit message shape" section)

## Wave 2 lane plan

| Lane | Topic | Output target | Subagent type | Status |
|---|---|---|---|---|
| A | Software-build patterns (per Goal G14) | `docs/04-research/software-patterns/<topic>.md` | parallel-researcher | IN-FLIGHT (ai-native-architecture-2026.md committed; more pending) |
| B | M0-M2 feature ledger catalog drop | `docs/03-feature-catalog/{README,M0-bootstrap,M1-backend,M2-governance-triad}.md` | general-purpose | PENDING |
| C | (claim available) | TBD | TBD | PENDING |
| D | Wave-1 consolidation + backlog updates | `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md` + 5 backlog files + wave-001.md | general-purpose | DONE (this lane) |

## Wave 3 lane plan (queued; starts when wave-2 closes)

Per `docs/11-loop-state/wave-history/wave-001.md` § Loop-improvement proposal — wave-3 methodology:

| Lane | Topic | Output target |
|---|---|---|
| A | AutoGen 2026 / LangGraph 2026 / Inflection Pi / SWE-bench (close RG-7, RG-8, RG-9, RG-10 + RG-12) | `docs/04-research/frontier-2026-extended/*.md` |
| B | M3-M5 ledger authoring (cron-heartbeat / headless-cli / desktop-shell) — depends on wave-2 Lane B finishing M0-M2 | `docs/03-feature-catalog/{M3,M4,M5}-*.md` |
| C | TypeScript bridge research: AF TS gap (RG-2) + A2A TS impl (RG-3) | `docs/04-research/typescript-bridges/*.md` |
| D | Test scaffolding bootstrap — `tests/` dir, RED test for F-001 | `tests/unit/F-001-engine-bootstrap-loop.test.ts` + `vitest.config.ts` (copy from clawpilot) |
| E (new) | First Copilot CLI design-review dispatch (per QG7 cadence N=5 trigger now reached) | `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-XX-foundation-review.md` |

## Multi-instance claim table

Append below as instances claim work. Format: `| instance-type | claimed-item | claimed-utc | eta | status |`.

| Instance type | Claimed item | Claimed (UTC) | ETA | Status |
|---|---|---|---|---|
| claude-code-1 | Wave 1 / Lane Zero | 2026-05-06 | done | DONE |
| claude-code-2 | Wave 1 / Lanes A-D (parallel research) | 2026-05-06 | done | DONE |
| claude-code-3 (this session) | Wave 2 / Lane D (consolidation) | 2026-05-07 | done | DONE |
| _open_ | Wave 2 / Lane B (M0-M2 catalog drop) | _open_ | _open_ | PENDING |
| _open_ | Wave 2 / Lane C | _open_ | _open_ | OPEN |

## Wave-2 quality-gate checklist (per QG1-QG9)

- [x] QG1 — wave findings net-new — Lane D consolidated (no duplicates of wave-1)
- [x] QG2 — every finding cites at least one source — verified in consolidation matrix
- [x] QG3 — every wave touches at least one Goal G1-G25 — Lane D touches G14, G15, G17, G22, G23
- [x] QG4 — every wave processes at least one backlog item OR generates one — Lane D processed and updated 5 backlog files (RG-1..12, D-9..23, F-NNN slate, RC-1..15, promotion candidates)
- [x] QG5 — wave ends with loop-improvement proposal — see `wave-001.md` § Loop-improvement proposal (also seeds wave-3 methodology)
- [x] QG6 — multi-agent fan-out — wave-2 has 3 lanes mid-flight (A, D, others pending)
- [ ] QG7 — Copilot CLI design review (N=5) — wave-3 trigger point
- [x] QG8 — Microsoft tools used — wave-1 Lane B already satisfied; wave-2 cadence rolls forward
- [x] QG9 — open questions captured — RG/D/Q backlogs updated this wave

## Next wave handoff

Wave-3 starts when wave-2 lanes A + B + C close (Lane D already done). The wave-3 methodology improvements identified in this consolidation are documented in `wave-001.md` § Loop-improvement proposal and can be lifted into `recent-improvements.md` once wave-2 finalizes.
