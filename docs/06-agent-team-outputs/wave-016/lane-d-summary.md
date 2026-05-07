# Wave-016 / Lane D — QG7 Copilot CLI design review (M0+M1+M2 implementation)

## Scope

First **implementation-review** since wave-002 (which was catalog-only). 18 LOCKED features (F-001..F-022 minus a few infrastructure-only) are now built. Multi-model dispatch via `Invoke-CopilotMultiModel.ps1` against `claude-opus-4.7` + `gpt-5.5`.

## Path taken

**copilot-cli-multi-model** — both models returned complete reviews. Cross-model agreement table populated per `lens-multi-model-review-pattern.md`. Wave-001's lesson held: TimeoutSeconds=1200 was sufficient (Opus completed in ~4 min, gpt-5.5 in ~1 min).

## Headline findings

**1 HARD BLOCK + 8 MUST-FIX + 13 SHOULD-FIX/CONSIDER + 7 PRAISE.** Full review at `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-016-impl-review.md`. 6 HARD BLOCK / MUST-FIX D-entries appended to `docs/10-backlog/design-decisions-pending.md` (D-35..D-40).

### HARD BLOCK (both models flag Critical/escalation)

- **F1 — No engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014.** 18 standalone primitives have no composition layer. `bootstrap()` makes zero backend or governance calls. Promote **F-138 engine-cycle-orchestrator** as M3 pre-impl prerequisite (D-35).

### MUST-FIX (both models flag Major)

- **F2** — F-013 didn't resolve wave-002 HARD BLOCK F2 (IBackendProvider over-normalization). F-013 is just type guards + a content extractor; no IChat/IToolDispatch/IIdentity split.
- **F4** — `index.ts` `export *` leaks ~50+ symbols flat — no public API boundary (D-39).
- **F7** — F-129..F-134 wave-002 candidates not materialized; need explicit milestone assignment (D-40).
- **F12** — F-007 IPC contract is empty scaffold; document `common/` as cross-package types-only.
- **F15** — No concurrency tests for halt/cost/quota.
- **F16** — No cross-feature integration test; `tests/integration/` is empty `.gitkeep`.
- **F3** — HaltTrigger union expanded into cross-feature kernel sentinel union; halt.ts has become a de-facto governance kernel (D-37).

### Single-model Critical (Opus) — demoted to MUST-FIX per cross-model rule

- **F8** — BackendEvent lacks `usage` variant; cost ledger has no event source (D-36). Promote **F-139 backend-event-usage-variant**.
- **F9** — StubBackend halt contract diverges from concrete backends; F-009 test asserts wrong contract (D-38).

### NEW F-NNN candidates

- **F-138** engine-cycle-orchestrator (M3 pre-impl) — both models
- **F-139** backend-event-usage-variant (M3 pre-impl) — Opus C-2
- **F-140** retro-outcome-degradation (M3) — Opus m-1
- **F-141** governance-kernel-extract (M3) — gpt-5.5 + wave-002 F-127
- **F-142** engine-core-public-api-boundary (M3) — both models

### Wave-002 HARD BLOCK resolution status

| Wave-002 verdict | M0-M2 status |
|---|---|
| F1 governance-before-backend | ⚠️ Features exist; not wired |
| F2 IBackendProvider split | ❌ F-013 is just type guards |
| F3 tool-proof-gate (F-130) | ❌ Not implemented |
| F5 identity-before-backend (F-128) | ✅ BackendSessionConfig requires Agent+Session |
| F6 oauth-singleflight (F-129) | ❌ Not implemented |
| F7 fanout-budget (F-131) | ❌ Not implemented |
| F8 supervision-locks (F-132) | ❌ Not implemented |

### Praise (preserve in M3+)

- **P-1** — RunHaltedVerdict first-owner shared-type pattern (both models confirm).
- **P-2..P-7** — Type-only imports + exhaustive switches + FETCH-BEFORE-CITE comments + injectable test seams + clean F-015 audit + no-invented-constraints discipline on CostLedger (Opus).

## Loop-improvement proposals for wave-17+

1. Mandate one integration test per milestone before milestone-freeze.
2. Add `BackendEvent` variant-stability CI gate.
3. Track wave-002 verdict resolution status in a machine-readable file.
4. Profile barrel export surface for dead-symbol contraction.
5. Maintain QG7 cadence: ~14-wave gap from foundation to first impl-review was right; next slot is wave-21 (M3-M5 mid-impl).

## Anomalies

- **Opus included full source-file dumps before findings** (3155 lines of preamble before structured synthesis). For wave-17+ briefs, explicitly forbid "echo source back" preamble.
- **GPT output was streaming-corrupted in places** (interleaved between agent steps). Substance sound; extraction took care.
- **index.ts modified during dispatch** — heartbeat.ts (F-023, M3) added to barrel mid-review. Reflected in F14 finding (M3 boundary leak).

## Artifacts

- Brief: `.mad/scratch/wave-016-impl-review-brief.md`
- Output dir: `.mad/scratch/wave-016-impl-review-output/`
- Opus result: `opus-result.json` (~180KB)
- GPT result: `gpt-result.json` (~65KB)
- Review doc: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-016-impl-review.md`
- D-entries appended: D-35 through D-40 in `docs/10-backlog/design-decisions-pending.md`
