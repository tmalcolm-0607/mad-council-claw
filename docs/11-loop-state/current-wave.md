# Current wave

**Wave:** 11
**Status:** In-flight. 4 lanes active.
**Started:** 2026-05-07
**Wave-10 closed:** 2026-05-07 (see `docs/11-loop-state/wave-history/wave-010.md`)
**Prior closed waves:** 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 — see `wave-history/`.

## Pickup point

Any fresh Claude Code session, Copilot CLI invocation, or subagent can pick up here:

1. Read `docs/01-requirements/foundational-plan.md` (the contract)
2. Read `roadmap.md` (navigable view; auto-tracks ledger status — refreshed wave-11 lane-d)
3. Read `docs/11-loop-state/wave-history/wave-010.md` (most recent close summary)
4. Pick a lane below that's not yet claimed (or pick a wave-12 candidate)
5. Append a row to the claim table; commit
6. Output to `docs/06-agent-team-outputs/wave-011/lane-<your-handle>-<topic>.md`
7. Commit per the chain-of-thought commit message shape (see `foundational-plan.md` § "Commit message shape")

## Wave 11 lane plan

| Lane | Topic | Output target | Subagent type | Status |
|---|---|---|---|---|
| A | F-007 ipc-contract-scaffold RED → GREEN | `tests/unit/F-007-*.test.ts` + `packages/engine-core/src/index.ts` (F-007 region) + ledger flip + roadmap update | general-purpose | IN-FLIGHT |
| B | F-001 GREEN → LOCKED via post-impl council review | `.mad/reports/council-verdict-F-001-2026-05-07.md` + ledger frontmatter `status: locked` + roadmap LOCKED row | general-purpose | IN-FLIGHT |
| C | M5 desktop-shell first ledger RED → GREEN candidate (F-032 window) | `tests/unit/F-032-*.test.ts` + impl + ledger flip + roadmap update | general-purpose | IN-FLIGHT |
| D | Roadmap freshness + wave-history backfill (waves 3-10) + wave-11 setup | `roadmap.md` refresh + 8 `wave-history/wave-{003..010}.md` + this `current-wave.md` update + lane-d summary | general-purpose | IN-FLIGHT (this lane) |

## Wave 12 lane plan (queued; starts when wave-11 closes)

To be authored at wave-11 close. Carryover candidates:
- M1 backend: F-009 IBackendProvider RED → GREEN (unblocks F-010..F-013).
- M2 final: F-017 PII-redaction-egress + F-021 degradation-fallback to close M2 to all-GREEN.
- M0 final: F-003/F-004/F-005 — repo-scaffolding, vitest-playwright-config, deps-pinning to close M0 to all-GREEN.
- Wave-11 lane spillover (any lane that didn't close).

## Multi-instance claim table

Append below as instances claim work. Format: `| instance-type | claimed-item | claimed-utc | eta | status |`.

| Instance type | Claimed item | Claimed (UTC) | ETA | Status |
|---|---|---|---|---|
| (historical waves 1-10) | (see prior current-wave.md history; preserved in `git log`) | various | done | DONE |
| _open_ | Wave 11 / Lane A (F-007) | _open_ | _open_ | IN-FLIGHT |
| _open_ | Wave 11 / Lane B (F-001 LOCKED) | _open_ | _open_ | IN-FLIGHT |
| _open_ | Wave 11 / Lane C (F-032 candidate) | _open_ | _open_ | IN-FLIGHT |
| claude-code-(this) | Wave 11 / Lane D (roadmap + wave-history backfill) | 2026-05-07 | ≤5 min | IN-FLIGHT |

## Wave-11 quality-gate checklist (per QG1-QG9)

- [ ] QG1 — wave findings net-new — Lane A targets the M0 IPC scaffold gap (F-007); Lane B introduces the LOCKED transition (first in repo); Lane C opens M5 implementation; Lane D refreshes derived artifact + audit trail.
- [ ] QG2 — every finding cites at least one source — verified per-lane on close.
- [ ] QG3 — every wave touches Goal G1-G25 — Lane A G18; Lane B G24 (governance discipline); Lane C G15+G18; Lane D G24 (visibility).
- [ ] QG4 — every wave processes at least one backlog item OR generates one — Lane B advances LOCKED-track scope; Lane D closes wave-history backfill backlog.
- [ ] QG5 — wave ends with loop-improvement proposal — wave-11 closing summary will append.
- [ ] QG6 — multi-agent fan-out — wave-11 has 4 lanes mid-flight.
- [ ] QG7 — Copilot CLI design review (N=5) — carry-forward; gate satisfied at the cumulative level (waves 2 + 3 attempts).
- [ ] QG8 — Microsoft tools used — carry-forward.
- [ ] QG9 — open questions captured — backlog hygiene rolls into wave-12.

## Next wave handoff

Wave-12 starts when wave-11 lanes A + B + C close (Lane D self-closes on commit of this update + wave-history files).

---

## Out-of-band steering input (added 2026-05-07)

> This file is stale (last updated wave-11). Actual wave progression has continued through wave-12, 13, 14, 15, 16, 17 per `git log` and `roadmap.md` transition notes. The executing session uses `roadmap.md` + `implementation-todo.md` as authoritative status surfaces, not this file.
>
> A separate audit-driven session (967a44fb) has authored backlog updates that should inform the next wave's lane allocation. **Read `orchestrator-steering-2026-05-07.md` (in this same directory) before claiming the next wave's lanes.**
>
> Summary of new backlog items: F-205 kit-bootstrap (M0, HIGH priority, soft-blocks F-206..F-210 + M19 reopen verdict); F-206..F-210 m-relay-main lift candidates (M9); F-D-018 activity-protocol-teams-outlook ledger authored from scratch (was RESERVED); M19 reopen-request package for F-D-008/F-D-010/F-D-018 (gated on /council-review verdict, which is itself gated on F-205 execution).
>
> Audit synthesis: `C:/Users/tonym/Repos/MAD - Clean/.mad/reports/mad-council-claw-audit-2026-05-07.md`
