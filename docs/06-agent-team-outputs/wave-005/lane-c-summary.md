---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-005 / lane-c)
wave: wave-005
lane: lane-c
topic: per-feature-ledger-authoring-M11-soul-introspect-replay
date: 2026-05-06
status: complete
---

# Wave 5 / Lane C — per-feature ledgers for M11 (soul / introspect / replay)

## Scope

Catalog drop for M11 — the canonical-e governance pillar (soul boundary + schema + introspection + signal pairs + deterministic replay). Author 5 RED-state ledgers + a milestone README, matching the wave-2 lane-b + wave-3 lane-a + wave-4 lane-a/b format used for M0-M8. Span: F-088..F-092 (5 features).

This adds the meta-governance plane to the catalog seed: M2 governs *what* runs do; M11 governs *what runs are allowed to be* and *how we know what they actually were*.

## What was created

| Group | Path | Count |
|---|---|---|
| M11 ledgers | `docs/03-feature-catalog/M11-soul-introspect-replay/F-{088..092}-*.md` | 5 |
| Milestone README | `docs/03-feature-catalog/M11-soul-introspect-replay/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-005/lane-c-summary.md` | 1 |
| **Total** | | **7** |

## Per-ledger frontmatter contract (matches wave-2 lane-b)

Every ledger carries: `artifact-class: feature-ledger`; `generated-by: hand-authored (wave-005 / lane-c)`; `status: red`, `status-since: 2026-05-06`, `status-history: [...]`; `feature-id: F-NNN`, `short-slug`, `milestone: M11`; `provenance.surfaces: [ce:..., kit:...]`; `fr-coverage: []` (filled by `/mad-spec`); `test-files: {...}` empty arrays; verbatim `red-green-rule:`; `depends-on: [...]`; `out-of-scope-notes:` per `rules/no-silent-deferrals.md`; `confidence: high`.

## Per-ledger body sections

All 5 ledgers carry the 6 required body sections: behavior contract (present-tense imperative); 3 GIVEN/WHEN/THEN acceptance scenarios; red→green wire-up table (TBD test files); dependencies (Hard/Soft/Independent); surface trace; implementation notes (empty placeholder).

## Provenance distribution

| Source family | Surfaces cited |
|---|---|
| Canonical-e (`ce:`) | FR-SOUL-001, FR-SOUL-SCHEMA-001, FR-INTROSPECT-001, FR-INTROSPECT-002, FR-CALIBRATION-001, FR-REPLAY-001 |
| MAD kit (`kit:`) | rules/non-negotiable-rules, rules/orchestrator-identity, rules/canonical-artifact-frontmatter, rules/no-silent-deferrals, rules/verification-protocol, rules/lens-multi-model-review-pattern, rules/concurrency-safety, council-retro-skill |
| Clawpilot (`cp:`) | none — M11 is canonical-e-pure (no clawpilot precedent) |

## Anomalies / context gaps

- **D-8 referenced in F-088 + F-089 per lane brief.** The brief frames D-8 as "soul scope default = full canonical-e concept (PENDING)". The actual D-8 in `docs/10-backlog/design-decisions-pending.md` is "Daily briefing destinations" (F-103, M3-adjacent). I honored the brief's framing — F-088 + F-089 reference D-8 as PENDING per the lane spec; the README `Pending design decisions` section also surfaces D-2 (boundary location) and D-26 (enforcement mechanism, HIGH-confidence per wave-3 cross-model). Recommend: reconcile D-NN numbering at next council-review of `design-decisions-pending.md` so the soul-scope decision has its own D-NN entry rather than overloading D-8.
- **No clawpilot provenance.** M11 is canonical-e-pure — clawpilot does not have a soul-boundary or replay precedent. Provenance therefore cites canonical-e + kit only.
- **F-091 grader-vs-work identity invariant** is the strongest single test in M11 — it's the only place an AI architectural mistake (the same model grading itself) can subvert the entire calibration plane silently. Recommend: M11 implementation wave promote this scenario to a multi-model adversarial test per `lens-multi-model-review-pattern.md`.

## Out of scope (per `rules/no-silent-deferrals.md`)

Every ledger's `out-of-scope-notes` block names the F-NNN / FR / wave that DOES cover the adjacent surface. Concretely:
- soul.json sigstore signing → v1.5 (FR-IDENTITY-002 family) — F-089
- M365 snapshot capture → v1.5 (FR-OUTLOOK/TEAMS/WORKIQ-SNAPSHOT-001) — F-092
- Replay UI scrubber → M12 (D-7 closure) — F-092 + README
- Multi-grader calibration → post-v1 — F-091
- Cross-version replay → post-v1 — F-092
- Capability-based enforcement → v-next (D-26 option c) — F-088 + README
- Soul scope default v1 envelope → PENDING D-8 closure (M11 design wave) — F-088 + F-089

## Confidence

HIGH (all 5 ledgers + README). Canonical-e FR-SOUL/INTROSPECT/REPLAY family is unambiguous; foundational-plan M11 row + canonical-e-inventory dispositions (lines 152-162) align cleanly. D-8 + D-2 + D-26 closures are tracked as design dependencies, not blockers — ledgers contract the *shape*, not the *default values*.

## Quality-gate checklist (QG1-QG9 for wave-005 lane-c)

- [x] QG1 — net-new — first M11 catalog drop; 5 ledgers + README + this summary are net-new
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists ce/kit surfaces; this summary cites canonical-e-inventory.md + foundational-plan.md
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers), G6 (catalog), and the canonical-e governance pillar (G8 v1 lane: governance triad)
- [x] QG4 — backlog item processed/generated — surfaces D-8 + D-2 + D-26 as PENDING in M11; M11 design wave council-review is the closure path
- [x] QG5 — loop-improvement proposal — see below
- [x] QG6 — multi-lane fan-out — wave-005 has parallel lanes; this is lane C
- [ ] QG7 — Copilot CLI design review — N/A this lane (catalog seed; multi-model adversarial deferred to M11 implementation wave per F-091 anomaly note)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + canonical-e read-only synthesis)
- [x] QG9 — open questions captured — Anomalies section + per-ledger `out-of-scope-notes`

## Loop-improvement proposal (QG5)

The lane brief flagged D-8 as "pending" but the actual D-8 in `design-decisions-pending.md` is unrelated (daily briefing destinations). I honored the brief's framing while surfacing the mismatch here. Pattern to lift: when a lane brief references a D-NN by number, the orchestrator should cross-check `docs/10-backlog/design-decisions-pending.md` BEFORE dispatching the lane and either (a) update the brief to use the correct D-NN, or (b) explicitly note "the pending decision being referenced is the soul-scope-default question, currently un-numbered; tracked under M11 design wave". This avoids the receiving subagent silently reconciling the mismatch (as I did) without surfacing it for council-review.

Recommend: add a pre-dispatch hook that grep-validates D-NN references in lane briefs against the live backlog file. Same pattern as the canonical-skill hooks in `validate-mad-pipeline.js`.

## Next steps

- Wave 5 / other lanes continue against their topics.
- M11 design wave (post-catalog) closes D-2, D-8, D-26 via council-review before any implementation begins.
- M11 implementation wave begins after design closure; F-091's grader-vs-work invariant is the priority multi-model adversarial target.
