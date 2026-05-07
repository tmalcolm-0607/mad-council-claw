---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-005 / lane-b)
wave: wave-005
lane: lane-b
topic: per-feature-ledger-authoring-M10-multi-model
date: 2026-05-06
status: complete
---

# Wave 5 / Lane B — per-feature ledgers for M10 multi-model

## Scope

M10 (multi-model adversarial review) catalog drop. Author RED-state ledgers for the 6 features F-082..F-087: `council-mode-dispatch`, `cross-model-agreement-table`, `both-flag-critical-hard-block`, `same-model-fallback`, `first-use-consent-gate`, `high-blast-radius-skills-wired`. Plus M10 README.

## What was created

| Group | Path | Count |
|---|---|---|
| M10 ledgers | `docs/03-feature-catalog/M10-multi-model/F-{082..087}-*.md` | 6 |
| Milestone README | `docs/03-feature-catalog/M10-multi-model/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-005/lane-b-summary.md` | 1 |
| **Total** | | **8** |

## Per-ledger frontmatter contract (matches wave-002 lane-b precedent)

Every ledger carries: `artifact-class: feature-ledger`, `generated-by: hand-authored (wave-005 / lane-b)`, `status: red` + `status-since: 2026-05-06` + `status-history`, `feature-id: F-NNN`, `short-slug`, `milestone: M10`, `provenance.surfaces`, `fr-coverage: []`, `test-files: {unit, node, browser, integration, e2e}`, `red-green-rule:` literal, `depends-on`, `out-of-scope-notes:` per `rules/no-silent-deferrals.md`, `confidence: high`.

## Per-ledger body sections

All 6 ledgers carry the 6 required body sections: Behavior contract (3-5 sentences, present-tense imperative); Acceptance scenarios (3 GIVEN/WHEN/THEN each); Red→green wire-up (test-file table marked TBD); Dependencies (Hard / Soft / Independent); Surface trace (provenance with one-line "what it contributes"); Implementation notes (empty placeholder).

## Provenance distribution

| Source family | Surfaces cited |
|---|---|
| MAD kit (`kit:`) | rules/lens-multi-model-review-pattern.md, Invoke-CopilotMultiModel.ps1, rules/skill-standards.md, rules/prescriptive-content-review.md, rules/dangerous-operations-policy.md, rules/degradation-fallback-policy.md, rules/orchestrator-identity.md (referenced in F-082 body) |
| Canonical-e (`ce:`) | US-7 (cross-model adversarial review user story), FR-MULTI-001 (functional requirement) |
| Clawpilot (`cp:`) | wave-002-wave-003-copilot-cli-design-review (the FIRST production proof-of-concept of this pattern; surfaced orchestrator-direct-invocation anti-pattern, demonstrated table shape, validated session-scoped consent reuse) |

## Anomalies / context gaps

- **F-NNN -> FR-XXX exact mapping deferred.** `fr-coverage: []` is empty in all 6 files; mapping done via `/mad-spec` per-feature in the M10 implementation wave.
- **No live test files.** Test-files frontmatter arrays empty until the M10 implementation wave lands `tests/{unit,integration}/F-NNN-*.test.ts` files.
- **F-087 ("skills wired") has implicit dependency on F-077 (skill-audit).** F-077 lives in M7 (already drafted in wave-004). The F-087 audit-style acceptance scenarios assume `/skill-audit` infrastructure exists; if M7 implementation lags M10, F-087 GREEN may need a stub audit harness.
- **Dispatcher script Windows-host bias.** `Invoke-CopilotMultiModel.ps1` is PowerShell-native; cross-platform parity is implicit in `kit:lens-multi-model-review-pattern.md` but not explicitly tracked. Surfacing as a FUTURE consideration; not a v1 blocker since the kit is Windows-first today.

## Out of scope (per `rules/no-silent-deferrals.md`)

Each ledger's `out-of-scope-notes:` block names the adjacent surface explicitly. Aggregate:

- HARD-BLOCK explicit override consent gate (M19-deferred).
- Per-invocation re-prompting of consent (v1 reuses session-scoped; M19-deferred for heightened trust).
- Multi-host fallback (v1 covers only local-Copilot-missing).
- Auto-escalation trigger logic (`blast_radius ≥ 7` lives in `kit:rules/prescriptive-content-review.md` § Gap 5; this milestone covers inheritance contract, not trigger).
- Consent revocation mid-session (M19-deferred).
- Per-skill rollout beyond 6 anchor skills (handled when each skill is authored / refreshed).

## Confidence

HIGH (all 6 ledgers). Source material — `kit:rules/lens-multi-model-review-pattern.md` is dense, prescriptive, and explicit about the inheritance contract, dispatch shape, agreement-table shape, hard-block rule, fallback path, and consent gate. Plus the wave-2/wave-3 Copilot CLI design review provided a real production proof-of-concept that validated every load-bearing element of the pattern. Behavior contracts are present-tense imperative; acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes; dependencies trace cleanly through the M10 DAG.

## Quality-gate checklist (QG1-QG9 for wave-005 lane-b)

- [x] QG1 — net-new — first M10 catalog drop; 6 ledgers + M10 README are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists kit/ce/cp surfaces; this summary cites lens-multi-model-review-pattern.md + Invoke-CopilotMultiModel.ps1 + canonical-e US-7 / FR-MULTI-001 + wave-2/3 Copilot CLI design review
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers), G6 (catalog), G18 (multi-agent fan-out: M10 IS the multi-agent cross-model fan-out plane)
- [x] QG4 — backlog item processed/generated — generates: per-ledger `fr-coverage: []` to be filled by /mad-spec; generates M19-deferred candidates explicitly enumerated in M10 README out-of-scope
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-005 has multiple lanes (this is lane-b)
- [x] QG7 — Copilot CLI design review — N/A this lane (catalog drop, not a design review)
- [x] QG8 — Microsoft tools used — N/A this lane (foundational-plan + kit + canonical-e read-only synthesis)
- [x] QG9 — open questions captured — frontmatter + summary `Anomalies` section above

## Loop-improvement proposal (QG5)

Three patterns surfaced by this drop worth lifting into the next wave:

1. **Production proof-of-concept as provenance source.** The wave-2/wave-3 Copilot CLI design review IS the first instance of this pattern in production, and citing it as `cp:wave-002-wave-003-copilot-cli-design-review` keeps the trail of empirical validation. Recommend: future catalog drops that codify a pattern already exercised in earlier waves should always cite the originating wave/lane as a `cp:` surface — that's the difference between "we plan to do X" and "X works because we already did it."

2. **Inheritance-contract ledger pattern.** F-087 (skills-wired) is a different ledger shape than F-082..F-086: it's a CONTRACT-COMPLIANCE feature, not a code-implementation feature. Acceptance scenarios are audit-style ("when /skill-audit runs, then..."). Recommend: future milestones that include rule-inheritance-coverage features (M11+ if ALAS rules need similar wiring discipline) follow the F-087 shape — audit-style acceptance + dependency on the audit infrastructure feature.

3. **Cross-feature dependency clarity in the milestone DAG.** The M10 README's DAG explicitly shows that F-087 depends on ALL of F-082..F-086 GREEN — that linearization is what an implementer needs to pick the right starting feature. Recommend: every milestone README continues to carry an explicit DAG, and where one feature depends on "all upstream", it's spelled out (not implied).

## Next steps

- Wave 5 / Lane A, C, D continue against their topics.
- Wave 6+ may pick up M11 (soul/introspect/replay), M12-M19 catalog drops, OR begin the M10 implementation wave (which would land actual `Invoke-CopilotMultiModel.ps1` integration tests + dispatcher harness + hard-block enforcement code, flipping F-082..F-087 to GREEN).
- F-087 GREEN gate explicitly waits on M7 F-077 (skill-audit) — track cross-milestone dependency in next wave's risk register.
