---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-007 / lane-a)
wave: wave-007
lane: lane-a
topic: per-feature-ledger-authoring-M16-M17
date: 2026-05-06
status: complete
---

# Wave 7 / Lane A — per-feature ledgers for M16 (telemetry) + M17 (docs)

## Scope

Final feature-catalog drop. Author RED-state ledgers for the last two milestones in the v1 wave plan: M16 (telemetry, F-110..F-113) and M17 (docs, F-114..F-118). Span: 9 feature ledgers + 2 milestone READMEs.

After this lane the catalog covers M0..M17 — every milestone in the foundational plan has ledgers. Implementation waves continue against the catalog; M18+ deferred features land in their own catalog drop when scope opens.

## What was created

| Group | Path | Count |
|---|---|---|
| M16 ledgers | `docs/03-feature-catalog/M16-telemetry/F-{110..113}-*.md` | 4 |
| M17 ledgers | `docs/03-feature-catalog/M17-docs/F-{114..118}-*.md` | 5 |
| Milestone READMEs | `docs/03-feature-catalog/{M16-telemetry,M17-docs}/README.md` | 2 |
| This summary | `docs/06-agent-team-outputs/wave-007/lane-a-summary.md` | 1 |
| **Total** | | **12** |

## Per-ledger frontmatter contract

Matches the wave-2 / wave-5 / wave-6 lane briefs verbatim:
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-007 / lane-a)`
- `status: red`, `status-since: 2026-05-06`, `status-history: [...]`
- `feature-id: F-NNN`, `short-slug`, `milestone: M16|M17`
- `provenance.surfaces: [kit:..., cp:..., foundational-plan.md ...]`
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (filled by implementation waves)
- `red-green-rule:` literal (matches lane brief verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md` — every adjacent surface explicitly tracked
- `confidence: high`

## Per-ledger body sections

Every ledger has the 6 required body sections:
1. Behavior contract (3-5 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios each)
3. Red→green wire-up (test-file table, all marked TBD)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

## Provenance distribution

| Source family | Surfaces cited (across 9 ledgers) |
|---|---|
| MAD kit (`kit:`) | rules/no-invented-constraints, rules/no-silent-deferrals, rules/single-owner-accountability, rules/dangerous-operations-policy, rules/degradation-fallback-policy, rules/anomaly-thresholds, rules/lens-telemetry-pattern, rules/verification-protocol, rules/skill-standards, rules/canonical-skill-only, rules/canonical-artifact-frontmatter, rules/mcp-tiering, rules/prompt-injection-policy, rules/loop-cadence-discipline, rules/autonomous-loop-discipline, rules/loop-stop-language-discipline |
| Clawpilot (`cp:`) | src/main/logger, src/services/telemetry, src/main/crash-reporter, electron crashReporter API, src/services/llm/factory, src/main/settings, src/features/settings/SettingsScreen.tsx, README.md, docs/architecture, docs/architecture/electron-process-model.md, docs/architecture/ipc-contract.md, docs/skills, docs/mcp, docs/automation, docs/quickstart |
| Foundational plan | D-1 (default OpenTelemetry-compatible local-file; remote opt-in), M16 telemetry section, M17 docs section |

## Anomalies / context gaps

- **F-NNN → FR-XXX exact mapping deferred.** Per the lane brief, `fr-coverage: []` is filled at `/mad-spec` time. All 9 ledgers honor this — the field is empty in every file.
- **No live test files.** Per the brief, test-files frontmatter arrays stay empty until implementation waves land actual `tests/{unit,integration,e2e}/F-NNN-*.test.ts` files.
- **F-115 architecture-docs scope is breadth not depth.** The 8 topics named (process model / IPC / lifecycle / identity / storage / governance / telemetry / MCP+skills) are anchor points; deeper per-component docs are tracked under per-feature ledgers, not duplicated in `docs/architecture/`. HIGH confidence.
- **F-117 MCP-server-adding-guide is for ADDING servers, not BUILDING them.** Server-side authoring is OUT for v1 per `out-of-scope-notes`. Named explicitly to satisfy `rules/no-silent-deferrals.md`.
- **F-118 automation-cookbook recipe count is "6+" not exactly 6.** Floor-not-ceiling discipline; 6 named recipes are required (cron, CLI, MCP-multi-step, autonomous-loop, multi-skill, a2a-bridge); additional recipes welcome but not required for milestone exit.

## Out of scope (per `rules/no-silent-deferrals.md`)

- M18+ deferred-features catalog drop — out of scope for this lane; will live under `docs/03-feature-catalog/M18-deferred/` when authored.
- Test plans (`/testplan` per-feature) — runs at `/mad-spec` time per project convention.
- Implementation of any M16 / M17 feature — separate implementation waves.
- 5 NEW frontier-research candidates noted in earlier waves' `out-of-scope-notes` — not authored as ledgers in this lane.

## Confidence

HIGH (all 9 ledgers + 2 READMEs). Source material — `foundational-plan.md` D-1 + M16 telemetry section + M17 docs section, plus clawpilot's existing logger/telemetry/crash-reporter/settings/architecture-docs/skills/mcp/automation surfaces — is consistent and unambiguous for M16 + M17 scope. Behavior contracts are present-tense imperative, acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes, dependencies trace cleanly through the milestone DAG into M0 / M2 / M8 / M9 anchors. The kit-rule citations across both milestones reflect the load-bearing discipline contracts (no-invented-constraints / no-silent-deferrals / dangerous-operations / verification-protocol / loop-cadence-discipline) — these are the rules the ledgers' acceptance scenarios verify in red→green tests.

## Quality-gate checklist (QG1-QG9 for wave-007 lane-a)

- [x] QG1 — net-new — final feature-catalog drop; 9 ledgers + 2 milestone READMEs are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists kit/cp/foundational-plan surfaces; this summary cites the same
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G18 (telemetry plane), G24 (engineering docs onboarding plane)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by `/mad-spec` runs (tracked in milestone READMEs as exit criteria); generates: M18+ deferred catalog drop noted as out-of-scope
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-007 has multiple lanes (this is lane-a)
- [ ] QG7 — Copilot CLI design review — N/A this lane (catalog seeds; review cadence handled at implementation wave time)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + clawpilot read-only synthesis)
- [x] QG9 — open questions captured — frontmatter + summary `Anomalies` section above

## Loop-improvement proposal (QG5)

The wave-007 lane-a drop completes catalog coverage M0..M17. Pattern observations from the cumulative catalog runs (waves 2 / 5 / 6 / 7):

1. **Catalog seeding is durably template-driven.** Every wave used the same per-feature ledger template + milestone-README shape; the consistency across 100+ ledgers is a direct artifact of strict frontmatter + body-section discipline. Recommend: lock the template into `.mad/templates/feature-ledger.md` and `.mad/templates/milestone-overview.md` so future M18+ catalog drops cite the template explicitly rather than copy-paste from a prior milestone.

2. **Out-of-scope notes per ledger continue to be the load-bearing discipline.** Every ledger in this lane names adjacent surfaces explicitly — the F-110 OUT block points to F-111 / F-112 / F-113 / F-018 by ID; F-117 OUT points to v1.5 features by name. This satisfies `rules/no-silent-deferrals.md` mechanically. The pattern holds at scale across 100+ ledgers.

3. **Foundational-plan citations should appear in `provenance.surfaces` whenever a ledger encodes a plan-level decision.** F-110 cites foundational-plan.md D-1 (default OpenTelemetry-compatible local-file); F-113 cites the same D-1 for the tri-state contract. This makes plan-decisions greppable from the catalog, which speeds up future audits ("which ledgers depend on D-1?"). Recommend: future milestone READMEs include a `## Plan decisions encoded` section listing the foundational-plan IDs the milestone realizes.

## Next steps

- Catalog M0..M17 is complete. M18+ deferred-features catalog is out-of-scope for v1 and will land separately when scope opens.
- Implementation waves continue per the wave plan; M16 / M17 implementation waves can begin once these ledgers are committed.
- Wave 7 lanes B / C (if planned) continue against their topics.
