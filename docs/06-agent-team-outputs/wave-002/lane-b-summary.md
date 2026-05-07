---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-002 / lane-b)
wave: wave-002
lane: lane-b
topic: per-feature-ledger-authoring-M0-M1-M2
date: 2026-05-07
status: complete
---

# Wave 2 / Lane B — per-feature ledgers for M0, M1, M2

## Scope

First feature-catalog drop into `docs/03-feature-catalog/`. Author RED-state ledgers for the foundation milestones M0 (bootstrap), M1 (backend), and M2 (governance triad). Span: F-001..F-022 (22 features total).

Wave 1 did not author any ledgers; this is the catalog seed. M0 implementation waves (M0 wave is M3+ in the wave plan) will land actual test files + impl that flip individual ledgers to GREEN.

## What was created

| Group | Path | Count |
|---|---|---|
| M0 ledgers | `docs/03-feature-catalog/M0-bootstrap/F-{001..008}-*.md` | 8 |
| M1 ledgers | `docs/03-feature-catalog/M1-backend/F-{009..013}-*.md` | 5 |
| M2 ledgers | `docs/03-feature-catalog/M2-governance-triad/F-{014..022}-*.md` | 9 |
| Milestone READMEs | `docs/03-feature-catalog/{M0-bootstrap,M1-backend,M2-governance-triad}/README.md` | 3 |
| This summary | `docs/06-agent-team-outputs/wave-002/lane-b-summary.md` | 1 |
| **Total** | | **26** |

## Per-ledger frontmatter contract (matches lane brief)

Every ledger carries:
- `artifact-class: feature-ledger`
- `generated-by: hand-authored (wave-002 / lane-b)`
- `status: red`, `status-since: 2026-05-07`, `status-history: [...]`
- `feature-id: F-NNN`, `short-slug`
- `milestone: M0|M1|M2`
- `provenance.surfaces: [kit:..., ce:..., cp:...]`
- `fr-coverage: []` (filled later by `/mad-spec`)
- `test-files: {unit, node, browser, integration, e2e}` (filled by M0 implementation wave)
- `red-green-rule:` literal (matches lane brief verbatim)
- `depends-on: [...]`
- `out-of-scope-notes:` per `rules/no-silent-deferrals.md` — every adjacent surface explicitly tracked
- `confidence: high`

## Per-ledger body sections

Every ledger has the 6 required body sections from the lane brief:
1. Behavior contract (3-5 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios each)
3. Red→green wire-up (test-file table, all marked TBD)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

## Provenance distribution

| Source family | Surfaces cited (rough counts across 22 ledgers) |
|---|---|
| MAD kit (`kit:`) | rules/no-invented-constraints, rules/no-silent-deferrals, rules/single-owner-accountability, rules/concurrency-safety, rules/anomaly-thresholds, rules/degradation-fallback-policy, rules/mcp-tiering, rules/orchestrator-identity, rules/non-negotiable-rules, rules/prompt-injection-policy, rules/verification-protocol, claude-api-skill, lens-multi-model-review-pattern.md, lens-telemetry, council-retro-skill, foundational-plan.md M-1 / M0 / M1 / M2 sections, Invoke-CopilotMultiModel.ps1 |
| Canonical-e (`ce:`) | FR-CORE-001..005, FR-IDENTITY-001, FR-AUDIT-001/002, FR-AUDIT-PRIVACY-001, FR-KILL-001, events.md (12 numbered types), halted_by_* trigger enum |
| Clawpilot (`cp:`) | src/main/index.ts, src/main/ipc, src/preload, src/agents/identity, src/main/logger, src/services/llm{,/anthropic,/copilot,/factory}, package.json, tsconfig.json, packages/, vitest.config.ts, playwright.config.ts, package-lock.json, userData layout |

## Anomalies / context gaps

- **F-NNN -> FR-XXX exact mapping deferred.** The lane brief says `fr-coverage: []` is filled when `/mad-spec` runs. Ledgers honor that — the field is empty arrays in all 22 files. Mapping will be done via `/mad-spec` per-feature in the M0 implementation wave.
- **No live test files.** Per the brief, test-files frontmatter arrays stay empty until the M0 wave lands the actual `tests/{unit,integration,e2e}/F-NNN-*.test.ts` files.
- **Two M2 features (F-016 query, F-021 degradation) are not 1:1 mappable to a single canonical-e FR.** Plan tagged the 9 M2 features verbatim ("pre-close signal, hash-audit, query-audit, PII redaction, halt, cost ledger, kill-switch, degradation, tool-quota"). I cited adjacent-but-related canonical-e FRs and kit rules; F-016 cites FR-AUDIT-001 ("Query-AuditLog" sub-surface), F-021 cites the kit rules `degradation-fallback-policy.md` directly (canonical-e doesn't have a single-FR equivalent). Both are HIGH-confidence.
- **F-005 deps-pinning has no canonical-e backing.** It's a build-system primitive, sourced from clawpilot + verification-protocol. HIGH confidence still — reproducible builds is non-negotiable per `rules/verification-protocol.md`.

## Out of scope (per `rules/no-silent-deferrals.md`)

- The 5 NEW frontier-research candidates (F-122 a2a-endpoint, F-123 otel-genai, F-124 multi-tier-routing, F-125 mcp-tool-cap, F-126 context-budget) are mentioned in `out-of-scope-notes` of the relevant ledgers but NOT authored as ledgers in this lane. They will land in their respective milestone waves.
- Test plans (`/testplan` per-feature) — deferred per lane brief; runs at /mad-spec time.
- M3+ milestone ledgers (F-023..F-D-018) — explicitly out of this lane's scope (M0+M1+M2 only).
- F-D-001..F-D-015 deferred catalog ledgers — out of scope for v1; will live under `docs/03-feature-catalog/M19-deferred/` when authored.

## Confidence

HIGH (all 22 ledgers). Source material — `foundational-plan.md` § True Synthesis Feature catalog table + canonical-e-inventory.md FR mappings + clawpilot pattern names from `foundational-plan.md` Architecture sections — is consistent and unambiguous for M0/M1/M2 scope. Behavior contracts are present-tense imperative, acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes, dependencies trace cleanly through the milestone DAG.

## Quality-gate checklist (QG1-QG9 for wave-002 lane-b)

- [x] QG1 — net-new — first feature-catalog drop; 22 ledgers + 3 milestone READMEs are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists kit/ce/cp surfaces; this summary cites foundational-plan.md + canonical-e-inventory.md
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G7 (M1 backend abstraction), G18 (multi-agent fan-out applied to wave structure)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by /mad-spec runs (tracked in milestone READMEs as exit criteria); generates: 5 NEW F-NNN candidates noted as out-of-scope
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-002 plan has multiple lanes
- [ ] QG7 — Copilot CLI design review — N/A this lane (deferred per QG7 cadence to wave 3+)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + canonical-e read-only synthesis)
- [x] QG9 — open questions captured — frontmatter + summary `Anomalies` section above

## Loop-improvement proposal (QG5)

The 22-ledger drop took ~1 wave-cycle by hand-authoring with a tight per-feature template. Pattern to lift:

1. **Template-first authoring** is faster than skill-driven authoring for catalog seeds when the source material (synthesis index) is already tight. Caveat: hand-authored ledgers must NOT replace `/mad-spec`-authored spec.md — these are catalog ledgers, a different artifact class. Spec.md per feature lands when implementation begins.

2. **Out-of-scope notes per ledger** are the load-bearing discipline preventing silent deferrals. Every ledger's `out-of-scope-notes` block names the F-NNN that DOES cover the adjacent surface, satisfying `rules/no-silent-deferrals.md`. Recommend: future catalog drops (M3-M19) carry the same discipline — empty `out-of-scope-notes` is a smell.

3. **Dependency DAG in milestone README** is more useful than per-ledger dependency citations alone — the README's ASCII DAG is what an implementer reads first when picking up a milestone. Recommend: every milestone README carries a DAG diagram.

## Next steps

- Wave 2 / Lane C+D (or whatever lanes were planned) continue against their topics.
- Wave 3+ may pick up M3-M19 catalog drops in the same template; suggested batch: M3+M4 (cron+CLI), then M5 (desktop shell, ~12 features), then M6+M7 (MCP+Skills).
- M0 implementation wave begins when this catalog is committed AND lane briefs converge.
