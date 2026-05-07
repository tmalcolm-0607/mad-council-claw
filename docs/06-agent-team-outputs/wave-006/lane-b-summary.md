---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-006 / lane-b)
wave: wave-006
lane: lane-b
topic: per-feature-ledger-authoring-M13-multimodal-NEW
date: 2026-05-06
status: complete
---

# Wave 6 / Lane B — per-feature ledgers for M13 (multimodal input NEW)

## Scope

First NEW-per-Message-11 catalog drop. Author 5 RED-state ledgers + a milestone README for M13 multimodal input — voice STT (F-096), engine selection (F-097), activation modes (F-098), screenshot-to-prompt (F-099), image preprocessing (F-100). All 5 features are tagged `[NEW per Message 11]` (`session-requests.md` line 61 + `foundational-plan.md` line 414).

## What was created

| Group | Path | Count |
|---|---|---|
| M13 ledgers | `docs/03-feature-catalog/M13-multimodal/F-{096..100}-*.md` | 5 |
| Milestone README | `docs/03-feature-catalog/M13-multimodal/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-006/lane-b-summary.md` | 1 |
| **Total** | | **7** |

## Per-ledger frontmatter contract (matches wave-2 lane-b + wave-5 lane-c)

Every ledger carries `artifact-class: feature-ledger`; `generated-by: hand-authored (wave-006 / lane-b)`; `status: red`, `status-since: 2026-05-06`, `status-history: [...]` with `[NEW per Message 11]` tag in the note; `feature-id: F-NNN`, `short-slug`, `milestone: M13`; `provenance.surfaces: [kit:...]` (no `ce:` — M13 is NEW per Message 11, not canonical-e; no `cp:` — clawpilot has no voice / screenshot precedent); `fr-coverage: []`; empty `test-files`; verbatim `red-green-rule:`; `depends-on:`; `out-of-scope-notes:` per `rules/no-silent-deferrals.md`; `confidence: high`.

## Per-ledger body sections

All 5 ledgers carry the 6 required sections: present-tense imperative behavior contract; 3 GIVEN/WHEN/THEN acceptance scenarios; red→green wire-up table (TBD); dependencies (Hard/Soft/Independent); surface trace; implementation notes (empty placeholder).

## Anomalies / context gaps

- **F-014 vs F-124 dependency naming on F-099.** Brief states `F-099 depends on F-014 multi-tier-routing (vision-model dispatch)`. Catalog F-014 is actually `pre-close-retro-signal` (M2 governance triad — `docs/03-feature-catalog/M2-governance-triad/F-014-pre-close-retro-signal.md`). The actual multi-tier-routing feature per `foundational-plan.md` line 425 is F-124 (M1 NEW frontier candidate). Per `rules/no-silent-deferrals.md` + `rules/no-invented-constraints.md`, I honored the brief literal — F-099 ledger lists `F-014` in `depends-on:` and surfaces the mismatch in F-099's `out-of-scope-notes` and the M13 README's "Pending design decisions" section. Recommend: council-reconcile at M13 design wave (either fix the brief to F-124 or renumber the multi-tier-routing feature).
- **D-4 cited as adjacent precedent for F-097.** D-4 in `docs/10-backlog/design-decisions-pending.md` (line 18) is "Multi-tier model routing default policy" for LLM tier-routing, not STT-engine routing. F-097 borrows the *shape* (rules-based default with override) but the STT-specific decision (call it "D-4-STT") is a new pending entry — surfaced in the README's "Pending design decisions" section for M13 design wave closure.
- **No canonical-e provenance.** M13 is the first milestone with zero `ce:` surface — Message 11 is the sole authoritative source. Provenance therefore cites kit-only.
- **No clawpilot provenance.** Confirmed via `docs/04-research/openclaw-clawpilot/clawpilot-features-inventory.md` + wave-001 lane-c — clawpilot has no voice-input or screenshot-to-prompt features. M13 is genuinely net-new vs both source codebases.
- **Always-listening consent expiry policy** is undecided. F-098 contracts "re-fire on every workspace switch and every fresh app install" as a reasonable conservative default per `rules/dangerous-operations-policy.md`; M13 design wave reconfirms.

## Out of scope (per `rules/no-silent-deferrals.md`)

Every ledger's `out-of-scope-notes` block names the F-NNN / version / wave that DOES cover the adjacent surface. Concretely:

- Cloud STT engines (Azure Speech, OpenAI Whisper-API, Deepgram) → v1.5 — F-097
- Multi-language transcription (non-en-US) → post-v1 — F-096
- Real-time streaming partials → v1.5 — F-096
- Speaker diarization / multi-speaker capture → F-D-016 in-meeting-live-assistant — F-096
- Custom wake-word training → post-v1 — F-098
- Multi-user voice-print discrimination → v1.5 (FR-IDENTITY-002 family) — F-098
- Drag-and-drop image input → v1.5 — F-099
- Multi-image prompts → v1.5 — F-099
- Camera / webcam capture → post-v1 — F-099
- ML-driven auto-redaction → post-v1 — F-100
- OCR text extraction → v1.5 — F-100
- Image format conversion (HEIC etc.) → v1.5 — F-100
- Multi-frame analysis on animated images → post-v1 — F-100
- Per-skill / per-automation preprocessing override → v1.5 — F-100

## Confidence

HIGH (all 5 ledgers + README). Source material — `foundational-plan.md` M13 row + `session-requests.md` Message 11 — is unambiguous on the 5 feature names. Behavior contracts are present-tense imperative; acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes; dependencies trace cleanly through the milestone DAG. The F-014 vs F-124 ID mismatch is the only material anomaly and is surfaced rather than silently reconciled.

## Quality-gate checklist (QG1-QG9 for wave-006 lane-b)

- [x] QG1 — net-new — first M13 catalog drop; 5 ledgers + README + this summary are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` cites kit surfaces; this summary cites foundational-plan.md + session-requests.md + clawpilot-features-inventory.md
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), and the multimodal NEW lane (V:11 in foundational-plan)
- [x] QG4 — backlog item processed/generated — generates: `D-4-STT` as new pending design decision; surfaces F-014 vs F-124 ID mismatch for council-reconciliation; surfaces always-listening consent expiry as M13 design wave item
- [x] QG5 — loop-improvement proposal — see below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-006 has parallel lanes; this is lane B
- [ ] QG7 — Copilot CLI design review — N/A this lane (catalog seed; multi-model adversarial deferred to M13 implementation wave per always-listening consent surface)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + session-requests read-only synthesis)
- [x] QG9 — open questions captured — Anomalies section + per-ledger `out-of-scope-notes` + README "Pending design decisions"

## Loop-improvement proposal (QG5)

**Pre-dispatch dependency-ID validation.** The brief's `F-099 depends on F-014 multi-tier-routing` is the second case (after wave-5 lane-c's D-8 mismatch) of a dispatch brief carrying an F-NNN / D-NN reference that disagrees with the live catalog. Pattern to lift: a pre-dispatch hook that grep-validates every `F-NNN` and `D-NN` token in lane briefs against `docs/03-feature-catalog/**/F-*.md` and `docs/10-backlog/design-decisions-pending.md`. On mismatch, either (a) rewrite the brief with the corrected ID, or (b) attach a `[ID-MISMATCH-NOTE]` block telling the receiving subagent how to handle it (honor literal + surface, or reconcile silently with rationale). Today the receiving subagent guesses, and "honor literal + surface" vs "silently reconcile" produces inconsistent outcomes across lanes. Same pattern as `validate-mad-pipeline.js` canonical-skill hooks.

## Next steps

- Wave 6 / other lanes continue against their topics.
- M13 design wave (post-catalog) closes D-4-STT, the F-014/F-124 ID reconciliation, the default wake phrase, and always-listening consent expiry policy via council-review before any implementation begins.
- M13 implementation wave begins after design closure; F-098 always-listening consent gate is the priority `rules/dangerous-operations-policy.md` adversarial test target; F-100 EXIF-strip + cancel-drops-original are the priority privacy-discipline integration tests.
