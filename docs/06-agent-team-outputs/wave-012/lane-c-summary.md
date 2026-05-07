---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-012 / lane-c)
wave: wave-012
lane: lane-c
topic: per-feature-ledger-authoring-F-122-to-F-126-frontier-research-candidates
date: 2026-05-07
status: complete
---

# Wave 12 / Lane C — F-122..F-126 frontier-research candidate ledgers (RED)

## Scope

The 5 NEW F-NNN candidates allocated by `foundational-plan.md` § "Plus 5 NEW F-NNN candidates from frontier research" had been **PLANNED** for several waves but never authored. This lane closes that gap by writing RED-state ledgers in the respective milestone directories per `rules/no-silent-deferrals.md` (PLANNED with no work artifact is a slow-rolling silent deferral).

## What was created

| Group | Path | Count |
|---|---|---|
| F-122 ledger | `docs/03-feature-catalog/M4-headless-cli/F-122-a2a-endpoint-exposure.md` | 1 |
| F-123 ledger | `docs/03-feature-catalog/M16-telemetry/F-123-otel-genai-spans.md` | 1 |
| F-124 ledger | `docs/03-feature-catalog/M1-backend/F-124-multi-tier-routing.md` | 1 |
| F-125 ledger | `docs/03-feature-catalog/M7-skills-perms-auto/F-125-mcp-tool-cap-per-workspace.md` | 1 |
| F-126 ledger | `docs/03-feature-catalog/M8-settings-persistence/F-126-context-budget-allocation.md` | 1 |
| Milestone READMEs updated | M1, M4, M7, M8, M16 (feature-row + frontmatter `features:` span) | 5 |
| Roadmap updated | `roadmap.md` (NEW-from-research table 5×PLANNED→RED, totals row, wave-12 transition note) | 1 |
| This summary | `docs/06-agent-team-outputs/wave-012/lane-c-summary.md` | 1 |
| **Total** | | **14** |

## Provenance trace (per ledger)

| Feature | Wave-1 source | Foundational-plan reference | Open decision (D-NN) |
|---|---|---|---|
| F-122 a2a-endpoint-exposure | wave-1 lane-b finding 10 (A2A protocol Microsoft adapters) | F-122 catalog row + `[R:WorkIQ + msft-learn finding 10]` | n/a (HTTP+JSON binding settled per `workiq-a2a-impl-patterns.md`) |
| F-123 otel-genai-spans | wave-1 lane-b finding 16 (OTel GenAI semantic conventions) | F-123 + `[R:msft-learn Foundry observability]` | n/a |
| F-124 multi-tier-routing | wave-1 lane-a finding 21 (Multi-tier routing 60% cost reduction) | F-124 + `[R:WebSearch frontier 2026 architecture]` | **D-4 OPEN** (rules-based default vs ML-routed) |
| F-125 mcp-tool-cap-per-workspace | wave-1 lane-b finding 15 (WorkIQ internal tool-explosion lesson) | F-125 + `[R:WorkIQ internal tool-explosion lesson]` + § Architecture (Tool plane: cap default 10) | **D-3 OPEN** (is 10 the right default?) |
| F-126 context-budget-allocation | wave-1 lane-a finding 23 (Context window management as architectural concern) | F-126 + `[R:WebSearch frontier 2026]` | n/a (mirrors `rules/context-guardian.md`) |

## Per-ledger frontmatter contract (matches wave-2 lane-b shape)

Every ledger carries:
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-012 / lane-c)`
- `status: red`, `status-since: 2026-05-07`, `status-history` includes the prior `planned` state
- `feature-id: F-122..F-126`, `short-slug`
- `milestone: M1|M4|M7|M8|M16`
- `provenance.surfaces: [foundational-plan + wave-1 lane summary + relevant kit rules + research file when applicable]`
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (empty arrays)
- `red-green-rule:` literal (matches wave-2 lane-b verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md`
- `confidence: high`

Each ledger's body has the 6 wave-2-lane-b sections: behavior contract, 3 acceptance scenarios, red→green wire-up table, dependencies (Hard/Soft/Independent), surface trace, implementation notes (empty placeholder).

## Anomalies / context gaps

- **D-3 + D-4 remain OPEN.** Both gate the corresponding ledgers' GREEN flip. This is correctly tracked in `out-of-scope-notes` of F-124 + F-125 and in `docs/10-backlog/design-decisions-pending.md`. Not a Lane-C anomaly; just a constraint on subsequent waves.
- **F-122 acceptance scenario 3 references a "consent gate" pattern** that requires the `<state-dir>/consent-log.jsonl` file path established by `dangerous-operations-policy.md` to exist at runtime. This file is not yet created by any GREEN feature; it appears in the dependency-on path of F-122 implementation but is shared cross-feature. Tracked.
- **F-126 mirrors `rules/context-guardian.md` thresholds (0.50 / 0.70 / 0.85) deliberately**, even though `rules/no-invented-constraints.md` says missing config = no signal. The thresholds are documented defaults the user can override per workspace; the defaults are not silently invented because they are explicitly cited from the kit rule. The ledger states this in the behavior contract.
- **No silent deferrals.** `out-of-scope-notes` per ledger names the adjacent F-NNN that DOES cover the off-scope concern (e.g., F-122 cites F-D-007 Teams adapter; F-123 cites F-D-017 Foundry deployment; F-126 cites F-131 fan-out budget governor).

## Out of scope (per `rules/no-silent-deferrals.md`)

- Test files for F-122..F-126 — per the wave-2 lane-b convention, test-files frontmatter arrays stay empty until the implementation wave lands the actual `tests/{unit,integration,e2e}/F-NNN-*.test.ts` files.
- D-3 (F-125 default cap value) and D-4 (F-124 default routing policy) closure — out of this lane's scope; both gate the GREEN flip of their respective ledgers.
- Implementation of any of F-122..F-126 — RED ledgers only; implementation is later waves.
- F-D-016..F-D-018 (the 3 NEW deferred items added alongside F-122..F-126 in foundational-plan) — these are deferred, tracked under M19.
- F-127..F-204 (78 wave-1 consolidated F-NNN candidates) — tracked separately under `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md`; not in scope for this lane.

## Confidence

HIGH (all 5 ledgers). Source material — `foundational-plan.md` § "Plus 5 NEW F-NNN candidates" + wave-1 lane-a/lane-b summaries (findings 10/15/16/21/23) — is consistent and unambiguous. Behavior contracts cite kit rules (`no-invented-constraints.md`, `single-owner-accountability.md`, `dangerous-operations-policy.md`, `context-guardian.md`) and external standards (A2A v1.0, OTel GenAI semantic conventions). Acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes. Dependencies trace cleanly through milestone DAGs.

## Quality-gate checklist (QG1-QG9 for wave-012 lane-c)

- [x] QG1 — net-new — 5 ledgers + 5 README updates + roadmap update + this summary are net-new artifacts; closes the PLANNED-but-not-authored gap noted in roadmap.md
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists kit/foundational-plan/wave-1-lane-summary surfaces
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers), G6 (catalog completeness), G7 (M1 backend), G18 (multi-agent fan-out at wave structure)
- [x] QG4 — backlog item processed — 5 PLANNED items flipped to RED; surfaced D-3 + D-4 as still-OPEN gates on future GREEN flips
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-012 has multiple lanes
- [ ] QG7 — Copilot CLI design review — N/A this lane (consider for next wave on F-124 / F-126 since both are rules-substrate-adjacent)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + wave-1 summaries read-only synthesis)
- [x] QG9 — open questions captured — D-3 + D-4 surfaced in ledger out-of-scope-notes + this summary

## Loop-improvement proposal (QG5)

Three concrete proposals:

1. **Add a "PLANNED audit" step to the lane-A roadmap-freshness lane.** The 5 PLANNED items sat unauthored for ~10 waves before being picked up. A simple grep at lane-A roadmap-refresh time — `grep "PLANNED" roadmap.md | wc -l` — surfaces aging PLANNED items for explicit triage. Threshold: any PLANNED row >3 waves old auto-promotes to a backlog item with explicit FIX-NOW-or-DEFER decision per `rules/scope-discipline.md`.

2. **Per-ledger D-NN dependency awareness.** F-124 + F-125 carry `depends-on: [...]` arrays for F-NNN dependencies but don't have a structured field for D-NN design-decision dependencies. Adding `decision-deps: [D-3, D-4]` to ledger frontmatter would let auto-tooling check "can this ledger flip GREEN yet?" mechanically. Proposed: extend the ledger schema in a wave-N kit-improvement lane.

3. **NEW-from-research provenance pattern is reusable.** The wave-1 finding → wave-12 ledger trace is clean; the pattern (cite the wave-N lane-summary finding number in `provenance.surfaces`) should be the standard for any future "frontier-research candidate" promotions. Recommend codifying in a ledger-template doc.

## Commits

5 ledger commits + 1 README/roadmap-batch commit (per the brief's "Commit each ledger + README + roadmap separately" directive — interpreted as 1 commit per ledger; the README + roadmap updates batch with the corresponding ledger commit since each milestone README only references its own F-NNN). Plus 1 lane-summary commit. **No push.**

| Commit | Files |
|---|---|
| C1 — F-122 a2a-endpoint-exposure ledger (RED) | F-122 ledger + M4 README update + roadmap update |
| C2 — F-123 otel-genai-spans ledger (RED) | F-123 ledger + M16 README update |
| C3 — F-124 multi-tier-routing ledger (RED) | F-124 ledger + M1 README update |
| C4 — F-125 mcp-tool-cap-per-workspace ledger (RED) | F-125 ledger + M7 README update |
| C5 — F-126 context-budget-allocation ledger (RED) | F-126 ledger + M8 README update |
| C6 — wave-012 lane-c summary | This file |

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request.
