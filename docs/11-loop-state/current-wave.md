# Current wave

**Wave:** 20
**Status:** In-flight. Lane D complete. Lanes A/B/C briefed for next orchestrator firing.
**Started:** 2026-05-08
**Wave-19 closed:** 2026-05-08 (HEAD `53c2a6c`; see `docs/11-loop-state/wave-history/wave-019.md`)
**Prior closed waves:** 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 — see `wave-history/`.

## Pickup point

Any fresh Claude Code session, Copilot CLI invocation, or subagent can pick up here:

1. Read `docs/01-requirements/foundational-plan.md` (the contract)
2. Read `roadmap.md` (navigable view; auto-tracks ledger status)
3. Read `docs/11-loop-state/wave-history/wave-019.md` (most recent close summary)
4. Read `docs/11-loop-state/orchestrator-steering-2026-05-07.md` (HARD BLOCK F3 + runtime-validation gap + recommended pickup order)
5. Pick a lane below that's not yet claimed
6. Append a row to the claim table; commit
7. Output to `docs/06-agent-team-outputs/wave-020/lane-<your-handle>-<topic>.md`
8. Commit per the chain-of-thought commit message shape (see `foundational-plan.md` § "Commit message shape")

## Wave 20 lane plan

| Lane | Topic | Output target | Subagent type | Status |
|---|---|---|---|---|
| A | F-205 Batch 2 — kit-bootstrap incremental landing (next batch: hooks + scripts OR skills + agents — concurrent-session call per `[scope:F-205]` ledger §Implementation notes) | `.claude/hooks/*` OR `.claude/skills/*` files copied + `tests/node/F-205-kit-bootstrap.test.ts` extended with batch-2 assertions + ledger §status-history append + roadmap transition note + lane-a-summary | general-purpose | BRIEFED-FOR-NEXT-FIRING |
| B | F-009 IBackendProvider RED -> GREEN (M1 backend unblock — opens F-010..F-013) | `tests/unit/F-009-ibackendprovider.test.ts` + `packages/engine-core/src/backend.ts` extension (interface + factory plumbing) + ledger flip + roadmap update + lane-b-summary | general-purpose | BRIEFED-FOR-NEXT-FIRING |
| C | M2 LOCKED transition pass — F-017 + F-021 GREEN -> LOCKED via post-impl council reviews (closes M2 `[scope:M2]` cleanup) | `docs/05-design-reviews/council-reviews/F-017-pii-redaction-egress-review.md` + `docs/05-design-reviews/council-reviews/F-021-degradation-fallback-review.md` + ledger frontmatter `status: locked` for both + roadmap LOCKED-row updates + lane-c-summary | general-purpose | BRIEFED-FOR-NEXT-FIRING |
| D | Wave-20 plan + wave-19 retrospective + roadmap freshness (this lane) | `docs/11-loop-state/current-wave.md` (this file) + `docs/11-loop-state/wave-history/wave-019.md` + `docs/11-loop-state/recent-improvements.md` append + `roadmap.md` frontmatter wave bump | general-purpose (this lane) | COMPLETE |

## Lane A brief — F-205 Batch 2

**Scope** (concurrent-session call): pick the next category for incremental landing per `[scope:F-205]` ledger §Implementation notes 4-batch sequence. Two viable candidates:

1. **Batch 2-hooks**: copy kit-generic hooks from `C:/Users/tonym/Repos/MAD - Clean/.claude/hooks/` -> `C:/Users/tonym/Repos/mad-council-claw/.claude/hooks/`. Extend `tests/node/F-205-kit-bootstrap.test.ts` with hook-existence + synthetic-fixture-fires assertions. Lands acceptance items (a) hooks portion + (f) hook-fires assertion.
2. **Batch 2-skills**: copy core council + MAD primitives from `C:/Users/tonym/Repos/MAD - Clean/.claude/skills/` -> `C:/Users/tonym/Repos/mad-council-claw/.claude/skills/`. Extend test with skill-presence assertions. Lands acceptance items (a) skills + (g) `/council-list` + (h) `/mad-spec`.

**Disjoint files** (Lane A only): `.claude/hooks/*` OR `.claude/skills/*` (not both); `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` (status-history append only); `tests/node/F-205-kit-bootstrap.test.ts` (extension only); `roadmap.md` (transition note append).

**Brief consumes**: `[scope:F-205]` ledger §Implementation notes (4-batch sequence) + wave-019/lane-c summary (per-batch GREEN interpretation precedent) + steering doc HARD BLOCK F3 (note: F3 revert is wave-019/lane-c owner's call, NOT Lane A's call).

## Lane B brief — F-009 IBackendProvider

**Scope**: flip F-009 from RED to GREEN. M1 backend unblock — currently 0R+1G+5L per roadmap (F-139 NEW added wave-019), but with F-009 still in the "5L" set per the roadmap milestone-overview claim of all-LOCKED-except-F-139. Verify ledger state: `docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md` frontmatter `status:` field is the source of truth. If GREEN/LOCKED, this lane shifts to F-010 / F-011 / F-012 / F-013 candidate transitions.

**Disjoint files** (Lane B only): `tests/unit/F-009-*.test.ts` (new); `packages/engine-core/src/backend.ts` (extend; coordinate with sibling-lane append discipline per wave-018 staging-race convention); `docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md` (frontmatter + status-history); `roadmap.md` (M1 row + transition note).

**Brief consumes**: `docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md` ledger (red-green-rule + acceptance scenarios) + wave-018/lane-b convention for backend-event variant authoring (F-139 reference).

## Lane C brief — M2 LOCKED transition pass

**Scope**: post-impl council reviews for F-017 (pii-redaction-egress) + F-021 (degradation-fallback) per the LOCKED protocol (`status: locked` requires verdict ACCEPT median ≥80). Both features are GREEN at HEAD; verify M2 milestone-overview row state (`docs/03-feature-catalog/M2-governance-triad/`).

**Disjoint files** (Lane C only): `docs/05-design-reviews/council-reviews/F-017-*.md` + `docs/05-design-reviews/council-reviews/F-021-*.md` (new); ledger frontmatter for F-017 + F-021 (status: green -> locked + status-history append); `roadmap.md` (M2 row + transition note).

**Brief consumes**: existing F-017 + F-021 ledgers + impl source (`packages/engine-core/src/redaction.ts` + `packages/engine-core/src/degradation.ts`) + prior LOCKED-review precedents (F-001, F-002, F-006, F-007, F-008, F-014, F-015, F-016, F-018, F-019, F-020, F-022, F-023, F-028).

## Wave 21 lane plan (queued; starts when wave-20 closes)

To be authored at wave-20 close. Carryover candidates:

- F-205 Batch 3 (m-main-derived skill lifts: skill-sanitize, mcp-permission-validate, copilot-cli-bridge).
- F-D-018 activity-protocol-teams-outlook ledger authoring (was-RESERVED -> real ledger).
- M19 reopen-request `/council-review` verdict (gated on F-205 batch covering `/council-review` skill availability).
- M0 closure: F-003 RED -> GREEN if not yet landed.
- Wave-20 lane spillover (any lane that didn't close).

## Multi-instance claim table

Append below as instances claim work. Format: `| instance-type | claimed-item | claimed-utc | eta | status |`.

| Instance type | Claimed item | Claimed (UTC) | ETA | Status |
|---|---|---|---|---|
| (historical waves 1-18) | (see `wave-history/wave-{001..018}.md`) | various | done | DONE |
| (historical wave 19) | (see `wave-history/wave-019.md`; HEAD `53c2a6c`) | 2026-05-07/08 | done | DONE |
| claude-code-(this) | Wave 20 / Lane D (wave plan + history + roadmap freshness) | 2026-05-08 | ≤5 min | COMPLETE |
| _open_ | Wave 20 / Lane A (F-205 Batch 2) | _open_ | _open_ | BRIEFED-FOR-NEXT-FIRING |
| _open_ | Wave 20 / Lane B (F-009 RED -> GREEN) | _open_ | _open_ | BRIEFED-FOR-NEXT-FIRING |
| _open_ | Wave 20 / Lane C (M2 LOCKED transition pass) | _open_ | _open_ | BRIEFED-FOR-NEXT-FIRING |

## Wave-20 quality-gate checklist (per QG1-QG9)

- [ ] QG1 — wave findings net-new — Lane A advances F-205 incremental landing; Lane B opens M1 RED; Lane C closes M2 to all-LOCKED; Lane D refreshes derived artifact + audit trail.
- [ ] QG2 — every finding cites at least one source — verified per-lane on close.
- [ ] QG3 — every wave touches Goal G1-G25 — Lane A G18 (kit inheritance); Lane B G18 (backend); Lane C G24 (governance discipline); Lane D G24 (visibility).
- [ ] QG4 — every wave processes at least one backlog item OR generates one — Lane A advances F-205 batch sequence; Lane C closes M2 backlog; Lane D logs lessons into recent-improvements.md.
- [ ] QG5 — wave ends with loop-improvement proposal — wave-20 closing summary will append.
- [ ] QG6 — multi-agent fan-out — wave-20 has 4 lanes mid-flight (3 briefed + 1 complete).
- [ ] QG7 — Copilot CLI design review (every-5-waves cadence) — last fire wave-19; next due wave-24. Carry-forward.
- [ ] QG8 — Microsoft tools used — carry-forward.
- [ ] QG9 — open questions captured — backlog hygiene rolls into wave-21.

## Next wave handoff

Wave-21 starts when wave-20 lanes A + B + C close (Lane D self-closes on commit of this update + wave-19 history file).

---

## Out-of-band steering input (added 2026-05-07; carried into wave-20)

> `docs/11-loop-state/orchestrator-steering-2026-05-07.md` carries forward two HIGH-PRIORITY items into wave-20:
>
> 1. **HARD BLOCK directive — F-205 frontmatter status field** (cross-model review verdict; F3 in agreement-table). Owner: wave-019 / lane-c session. Action: revert `status: green -> red` + add `batch-1-status: green` field. Loop continues per `loop-stop-language-discipline.md`; F3 must be corrected before Batch-2 transition lands.
> 2. **Runtime-validation gap (2026-05-07T23:50Z)** — honest accounting of which surfaces have NOT been runtime-validated. Per-batch test extension SHOULD include synthetic invocation of each new skill (recommendation, not directive).

## Wave-history line (added 2026-05-08 by wave-20 / lane-d)

Recent wave activity (this file's wave header above is current; live progression below tracks the running tally):

- **Wave 20 (in-flight, 2026-05-08)** — Lane D complete (this lane); Lanes A/B/C briefed for next orchestrator firing. Wave-19 closed at HEAD `53c2a6c`.
- **Wave 19 closed 2026-05-08** — see `wave-history/wave-019.md`. 10 commits; F-033/F-034/F-205 batch-1/F-139/F-140 RED -> GREEN; QG7 Copilot CLI design review fired (composition spine; ZERO HARD BLOCKs); HARD BLOCK F3 surfaced for wave-019/lane-c owner revert; lane-d staging-race tracking; steering doc updates.
- **Wave 18 closed 2026-05-07** — F-023/F-028 LOCKED + F-031 GREEN + F-032 GREEN (M5 desktop-shell milestone OPENS).
- **Wave 17 closed 2026-05-07** — see `wave-history/wave-017-tmp-stash-archive/README.md` for the cross-lane staging-race recovery debris archived this wave.
- **Waves 12-16 closed** — see `wave-history/wave-{012..016}.md` (subset; backfill ongoing).
- **Waves 1-11 closed** — see `wave-history/wave-{001..011}.md`.

Test count at wave-19 close HEAD `53c2a6c`: **323 / 323 PASS** across 38 vitest files (per F-205 lane-c GREEN-time capture).

---

## Historical content preserved below (wave-11 lane plan; superseded by current wave header above)

The original wave-11 lane plan + wave-12 queued items + wave-18 line are preserved here for historical reference. The live progression is the wave header at top of this file.

### Wave 11 lane plan (closed)

| Lane | Topic | Output target | Subagent type | Status |
|---|---|---|---|---|
| A | F-007 ipc-contract-scaffold RED -> GREEN | `tests/unit/F-007-*.test.ts` + `packages/engine-core/src/index.ts` (F-007 region) + ledger flip + roadmap update | general-purpose | DONE |
| B | F-001 GREEN -> LOCKED via post-impl council review | `.mad/reports/council-verdict-F-001-2026-05-07.md` + ledger frontmatter `status: locked` + roadmap LOCKED row | general-purpose | DONE |
| C | M5 desktop-shell first ledger RED -> GREEN candidate (F-032 window) | `tests/unit/F-032-*.test.ts` + impl + ledger flip + roadmap update | general-purpose | DONE |
| D | Roadmap freshness + wave-history backfill (waves 3-10) + wave-11 setup | `roadmap.md` refresh + 8 `wave-history/wave-{003..010}.md` + this `current-wave.md` update + lane-d summary | general-purpose | DONE |

### Wave-12+ queued items (already closed)

Closed across waves 12-19 per `wave-history/`.
