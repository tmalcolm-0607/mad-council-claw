# Current wave

**Wave:** 3
**Status:** In-flight. Lanes A (frontier extended research) + B (M3-M5 ledgers) + C (RED test scaffold + toolchain) + D (this lane: roadmap + wave-002 close + wave-003 setup) running in parallel.
**Started:** 2026-05-07
**Wave-2 closed:** 2026-05-07 (see `docs/11-loop-state/wave-history/wave-002.md`)
**Wave-1 closed:** 2026-05-07 (see `docs/11-loop-state/wave-history/wave-001.md`)

## Pickup point

Any fresh Claude Code session, Copilot CLI invocation, or subagent can pick up here:

1. Read `docs/01-requirements/foundational-plan.md` (the contract)
2. Read `docs/01-requirements/session-requests.md` (the user's verbatim words)
3. Read `docs/01-requirements/goals.md` (G1-G25)
4. Read `roadmap.md` (navigable view; auto-tracks ledger status — added wave-3 Lane D)
5. Read `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md` (the F-127..F-204 ledger allocation)
6. Read `docs/11-loop-state/wave-history/wave-001.md` + `wave-002.md` (closing summaries)
7. Pick a lane below that's not yet claimed (or pick a wave-4 candidate)
8. Append a row to the claim table; commit
9. Execute per `docs/12-resource-roster/<your-instance-type>.md`
10. Output to `docs/06-agent-team-outputs/wave-003/lane-<your-handle>-<topic>.md`
11. Commit per the chain-of-thought commit message shape (see `foundational-plan.md` § "Commit message shape")

## Wave 3 lane plan

| Lane | Topic | Output target | Subagent type | Status |
|---|---|---|---|---|
| A | AutoGen 2026 / LangGraph 2026 / Inflection Pi / SWE-bench (close RG-7, RG-8, RG-9, RG-10 + RG-12) | `docs/04-research/frontier-2026-extended/*.md` | parallel-researcher | IN-FLIGHT |
| B | M3-M5 ledger authoring (cron-heartbeat / headless-cli / desktop-shell) | `docs/03-feature-catalog/{M3-cron-heartbeat,M4-headless-cli,M5-desktop-shell}/F-NNN-*.md` | general-purpose | IN-FLIGHT (F-023, F-024 landed; F-025..F-043 pending) |
| C | First runnable RED test scaffold for F-001 + Vitest/TS/ESLint/Prettier toolchain | `tests/unit/F-001-engine-bootstrap-loop.test.ts` + `vitest.config.ts` + `tsconfig.json` + `packages/engine-core/` + lane-c summary | general-purpose | DONE (per `docs/06-agent-team-outputs/wave-003/lane-c-summary.md`) |
| D | Author `roadmap.md` (navigable artifact) + wave-002 closing summary + wave-003 setup | `roadmap.md` + `docs/11-loop-state/wave-history/wave-002.md` + this `current-wave.md` update + `recent-improvements.md` append + `confidence-ledger.md` append + lane-d summary | general-purpose | IN-FLIGHT (this lane) |
| E (queued) | Re-dispatch Copilot CLI with 600s opus timeout per wave-002 Lane C carryover | `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-XX-foundation-review-v2.md` (opus voice + final agreement-table) | general-purpose | PENDING |

## Wave 4 lane plan (queued; starts when wave-3 closes)

Per wave-002 closing summary § Loop-improvement proposal — wave-4 candidates:

| Lane | Topic | Output target |
|---|---|---|
| A | M6-M8 ledger authoring (MCP & tools / Skills+Perms+Auto / Settings+persistence) | `docs/03-feature-catalog/{M6,M7,M8}-*/F-NNN-*.md` |
| B | F-002 RED test scaffold + impl direction (per-agent identity + run_id) — turns F-001 GREEN as side effect of multi-feature integration test | `tests/unit/F-002-*.test.ts` + impl direction note |
| C | Copilot CLI design review on wave-3 outputs (the M3-M5 ledgers + RED scaffold + roadmap.md) | `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-XX-wave-3-review.md` |
| D | Backlog hygiene — RG-1..RG-12 status review; close items where wave-3 Lane A produced evidence; promote MEDIUM→HIGH where corroborated | backlog file updates + lane-d summary |

## Multi-instance claim table

Append below as instances claim work. Format: `| instance-type | claimed-item | claimed-utc | eta | status |`.

| Instance type | Claimed item | Claimed (UTC) | ETA | Status |
|---|---|---|---|---|
| claude-code-1 | Wave 1 / Lane Zero | 2026-05-06 | done | DONE |
| claude-code-2 | Wave 1 / Lanes A-D (parallel research) | 2026-05-06 | done | DONE |
| claude-code-3 | Wave 2 / Lane D (consolidation + wave-001 close) | 2026-05-07 | done | DONE |
| claude-code-4 | Wave 2 / Lane B (M0-M2 catalog drop) | 2026-05-07 | done | DONE |
| claude-code-5 | Wave 2 / Lane A (software-build patterns) | 2026-05-07 | done | DONE |
| claude-code-6 | Wave 2 / Lane C (Copilot CLI review — partial) | 2026-05-07 | done | DONE |
| claude-code-7 | Wave 3 / Lane C (RED test scaffold + toolchain) | 2026-05-06 | done | DONE |
| claude-code-8 (this session) | Wave 3 / Lane D (roadmap + wave-002 close + wave-003 setup) | 2026-05-07 | ≤5 min | IN-FLIGHT |
| _open_ | Wave 3 / Lane A (AutoGen/LangGraph/Pi/SWE-bench) | _open_ | _open_ | IN-FLIGHT |
| _open_ | Wave 3 / Lane B (M3-M5 ledgers; F-025..F-043 remaining) | _open_ | _open_ | IN-FLIGHT |
| _open_ | Wave 3 / Lane E (Copilot CLI re-dispatch with opus timeout) | _open_ | _open_ | PENDING |

## Wave-3 quality-gate checklist (per QG1-QG9)

- [ ] QG1 — wave findings net-new — Lane A targets RG-7..RG-12 (specific gaps not yet covered); Lane B's M3-M5 ledgers are net-new; Lane C's RED test is net-new; Lane D's roadmap is net-new artifact class.
- [ ] QG2 — every finding cites at least one source — verified per-lane on close.
- [ ] QG3 — every wave touches Goal G1-G25 — Lane A G15+G20; Lane B G18+G22+G23; Lane C G18+G22+G23+G37; Lane D G18+G22+G24.
- [ ] QG4 — every wave processes at least one backlog item OR generates one — Lane A closes RG-7..RG-12; Lane B advances implementation-todo; Lane D updates confidence-ledger.
- [ ] QG5 — wave ends with loop-improvement proposal — wave-3 Lane D closing summary will append to `recent-improvements.md`.
- [ ] QG6 — multi-agent fan-out — wave-3 has 4 lanes mid-flight (A, B, C, D); Lane E queued.
- [ ] QG7 — Copilot CLI design review (N=5) — first attempt was wave-2 Lane C (partial); wave-3 Lane E is the retry target.
- [ ] QG8 — Microsoft tools used — wave-3 Lane A may target msft-learn for Microsoft Agent Framework + AutoGen overlap; carry-forward from wave-2 sufficient for cadence N=3.
- [ ] QG9 — open questions captured — backlog hygiene rolls into wave-4 Lane D.

## Next wave handoff

Wave-4 starts when wave-3 lanes A + B + E close (Lane C + Lane D already done). The wave-4 methodology improvements are documented in this `current-wave.md` § Wave 4 lane plan and will be lifted into `recent-improvements.md` once wave-3 finalizes.
