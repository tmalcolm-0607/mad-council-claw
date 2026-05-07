---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-006 / lane-a)
wave: wave-006
lane: lane-a
topic: per-feature-ledger-authoring-M12-M14-NEW-features
date: 2026-05-06
status: complete
---

# Wave 6 / Lane A — per-feature ledgers for M12 (visualization) + M14 (productivity)

## Scope

Author RED-state ledgers for the two NEW milestones introduced per Message 11: M12 (visualization NEW, F-093..F-095) and M14 (productivity NEW, F-101..F-103). All 6 features are tagged `[NEW per Message 11]` — they are NOT in clawpilot, NOT in canonical-e, NOT in the kit. They derive from the user's explicit answer "Multimodal input (voice + screenshot-to-prompt), Agent execution timeline + replay scrubber, Daily briefing + project workspace, Bring-your-own MCP + encrypted local storage" — M12 takes the timeline+scrubber half, M14 takes the daily-briefing half.

## What was created

| Group | Path | Count |
|---|---|---|
| M12 ledgers | `docs/03-feature-catalog/M12-visualization/F-{093..095}-*.md` | 3 |
| M14 ledgers | `docs/03-feature-catalog/M14-productivity/F-{101..103}-*.md` | 3 |
| Milestone READMEs | `docs/03-feature-catalog/{M12-visualization,M14-productivity}/README.md` | 2 |
| This summary | `docs/06-agent-team-outputs/wave-006/lane-a-summary.md` | 1 |
| **Total** | | **9** |

## Per-ledger frontmatter contract (matches wave-2 lane-b)

Every ledger carries the same shape as wave-2 lane-b (M0/M1/M2 catalog seed):
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-006 / lane-a)`
- `status: red`, `status-since: 2026-05-06`, `status-history: [...]`
- `feature-id: F-NNN`, `short-slug`
- `milestone: M12|M14`
- `provenance.surfaces: [kit:..., cp:..., ce:...]` (each NEW feature's primary surface is `kit:foundational-plan.md M{12|14} NEW Message 11`)
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (filled by M12/M14 implementation waves)
- `red-green-rule:` literal (matches wave-2 verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md` — every adjacent surface explicitly tracked
- `confidence: high`

## Per-ledger body sections (6, matches wave-2)

1. Behavior contract (3-5 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios each)
3. Red→green wire-up (test-file table, all marked TBD)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

## Dependency cross-walk

| Ledger | Depends on (Hard) | Reason |
|---|---|---|
| F-093 timeline-ui | F-015 audit-chain, F-032 desktop shell, F-092 deterministic-replay | Timeline data source + host window + cross-verify against replay |
| F-094 replay-scrubber | F-092, F-093 | Replay manifest is determinism anchor; overlays timeline UI |
| F-095 timeline-filtering | F-093 | Filters operate on timeline nodes |
| F-101 daily-briefing | F-019 cost-ledger, F-080 workiq-adapter | Cost section + WorkIQ-surfaces section data sources |
| F-102 briefing-schedule | F-061 automations-base, F-101 | Scheduling primitive + briefing generator |
| F-103 briefing-destination | F-101 | Dispatches the briefing artifact |

All 6 hard dependencies (F-015, F-019, F-032, F-061, F-080, F-092, F-093, F-101) exist as ledgers in prior waves OR within this lane (F-093, F-101). No dangling deps.

## Provenance distribution

| Source family | Surfaces cited across 6 ledgers |
|---|---|
| MAD kit (`kit:`) | foundational-plan.md M12/M14 NEW Message 11 (primary, every ledger), rules/{verification-protocol, no-silent-deferrals, no-top-n-capping, no-invented-constraints, loop-cadence-discipline, degradation-fallback-policy}.md |
| Canonical-e (`ce:`) | FR-AUDIT-001 (F-093), FR-REPLAY-001 (F-094) — secondary anchors only; primary surface for all 6 is `kit:foundational-plan.md M{12|14} NEW Message 11` |
| Clawpilot (`cp:`) | src/main/logger (F-093 — existing structured logger as audit source), src/services/llm/factory (F-102 — factory pattern as registration shape model) |

## Anomalies / context gaps

- **All 6 features primary-cite the foundational plan, not canonical-e or clawpilot.** This is intentional and correct — Message 11's NEW features by construction are NOT in the prior surfaces. The provenance honestly attributes each to the user's NEW-features answer rather than retrofitting fake surface citations.
- **F-NNN -> FR-XXX exact mapping deferred.** Per wave-2 lane-b convention, `fr-coverage: []` is empty arrays in all 6 files; mapping happens at `/mad-spec` time.
- **No live test files.** Per the wave-2 convention, test-files frontmatter arrays stay empty until implementation waves land actual test files.
- **D-7 closure noted.** F-094 + M11 README cross-reference D-7 (replay scrubber overlay design); M12 README's pending-decisions section names D-7 + D-M12-1 + D-M12-2 explicitly.
- **D-M14-1 (cron mechanism) is the load-bearing design decision for M14.** F-061 internal-scheduler vs OS-level cron has implications for engine-uptime semantics; M14 README's pending-decisions section flags it.

## Out of scope (per `rules/no-silent-deferrals.md`)

Each ledger's `out-of-scope-notes` block names every adjacent surface explicitly. M12 deferrals: saved-filter presets, cross-run side-by-side, live-replay, branching replay, live-streaming, cross-run filter, filter export to CSV, full-text search. M14 deferrals: template extensibility, weekly rollups, time-zone personalization, cross-project aggregation, voice-narrated briefing, full crontab syntax, multiple schedules per workspace, schedule-pause/PTO, catch-up runs, email/Teams/Slack destinations, encrypted destination payloads, multi-destination fan-out. Every deferred item is named in either a ledger's out-of-scope-notes or the milestone README's out-of-scope section.

## Confidence

HIGH (all 6 ledgers + 2 READMEs). Source material — the user's verbatim Message 11 answer in `foundational-plan.md` lines 59-63 + the M12/M14 rows of the milestone catalog table at lines 413+415 — is consistent and unambiguous. Each NEW feature's behavior contract is present-tense imperative; acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes; dependencies trace cleanly through the milestone DAG with all 6 hard deps existing as prior-wave ledgers or within this lane.

## Quality-gate checklist (QG1-QG9 for wave-006 lane-a)

- [x] QG1 — net-new — first M12+M14 ledger drop; 6 ledgers + 2 READMEs are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists the kit/cp/ce surfaces; this summary cites foundational-plan.md Message 11 verbatim
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G19 (M12+M14+M13 NEW milestones from Message 11 honored)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by /mad-spec runs (tracked in milestone READMEs as exit criteria); generates: D-7 closure noted, D-M12-1/D-M12-2/D-M14-1/D-M14-2/D-M14-3 design decisions named
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-006 plan has multiple lanes (this is lane-a)
- [ ] QG7 — Copilot CLI design review — N/A this lane (deferred to wave-006 lane that needs cross-model verification on a higher-blast-radius surface)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + Message 11 read-only synthesis; no WorkIQ / msft-learn lookup needed)
- [x] QG9 — open questions captured — frontmatter + summary `Anomalies` section above + READMEs' "Pending design decisions blocking implementation" sections

## Loop-improvement proposal (QG5)

The 6-ledger drop took ~5 min by following the wave-2 lane-b template verbatim. Three patterns to lift forward:

1. **NEW-feature primary-citation discipline.** When a feature is `[NEW per Message N]`, the primary `provenance.surfaces` entry is `kit:foundational-plan.md M{XX} NEW Message N` — NOT a retrofit citation to canonical-e/clawpilot. Honesty about novelty matters; future M13 (multimodal NEW) and any other NEW milestones should follow the same primary-citation shape.
2. **Deferral-block as feature characterization.** Each ledger's `out-of-scope-notes` block doubles as a precise scope boundary AND as the documentation of what M12/M14 v1 explicitly is NOT. This is more useful than a separate "non-goals" section because it sits next to the feature it scopes. Recommend: every NEW-feature ledger keeps the deferral block load-bearing.
3. **Milestone README pending-design-decisions section.** Flagging D-7 + D-M12-1/-2 + D-M14-1/-2/-3 in the README's own pending-decisions section makes the design-wave council-review intake list explicit. The implementer reading the README knows immediately which decisions block the wave. Recommend: every milestone README carries this section even when empty (an explicit "no pending decisions" note).

## Next steps

- Wave 6 / Lane B-D (or whatever lanes were planned) continue against their topics — likely M13 NEW (multimodal input F-096..F-100) is the natural companion to this lane's NEW work.
- Wave 7+ may pick up M12+M14 implementation waves now that ledgers are in RED state.
- M11 implementation wave is a hard dependency for M12 implementation (F-092 deterministic-replay is required for F-093+F-094 cross-verification).
- M9 implementation wave is a hard dependency for M14 implementation (F-080 WorkIQ adapter is required for F-101 surfaces section).
