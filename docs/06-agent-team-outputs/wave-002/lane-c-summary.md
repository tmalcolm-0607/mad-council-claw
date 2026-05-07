---
artifact-class: lane-summary
wave: wave-002
lane: lane-c
date: 2026-05-07
topic: copilot-cli-multi-model-design-review
generated-by: lane-c-orchestrator
generated-by-version: 0.1.0
status: preview
---

# Wave-002 Lane C summary — Copilot CLI multi-model design review

## Scope

Per QG7 ("at least one Copilot CLI design review per N waves; initial N=5; tunable") this is the FIRST dispatch of the Copilot CLI cross-model adversarial design review against consolidated wave-001 outputs.

## Inputs reviewed

- `docs/04-research/frontier-2026/*.md` — 12 docs (Lane A wave-1)
- `docs/04-research/microsoft-2026/*.md` — 11 docs (Lane B wave-1)
- `docs/04-research/openclaw-clawpilot/*.md` — 6 docs (Lane C wave-1)
- `docs/04-research/mad-kit-inventory.md` (Lane D wave-1)
- `docs/04-research/canonical-e-inventory.md` (Lane D wave-1)
- `docs/04-research/cross-source-disposition-matrix.md` (Lane D wave-1)
- `docs/01-requirements/foundational-plan.md` § True Synthesis

## Path taken

**`copilot-cli-multi-model` partial.** Dispatcher (`Invoke-CopilotMultiModel.ps1`, `TimeoutSeconds=600`) dispatched two parallel Copilot CLI calls:

| Model | Status | Wall-clock | Tokens (in / out) |
|---|---|---|---|
| `gpt-5.5` | completed (exit 0) | ~33s | 36.7k / 2.2k |
| `claude-opus-4.7` | TIMEOUT — Stop-Job at 600s | 600s (killed) | n/a |

Cross-model agreement table is therefore empty. Per `lens-multi-model-review-pattern.md` § Fallback, single-model output is captured; both-flag-CRITICAL hard-block rule could not fire. Wave-3 should re-dispatch with `-TimeoutSeconds 1200` (per memory `feedback_pr_review_calibration_20260503.md`: Copilot dispatcher default 600s; 1200s is the next escalation tier).

**Context Gap surfaced** in design review header + `docs/10-backlog/research-gaps.md` RG-13.

## Findings

| Severity | Count | Notes |
|---|---:|---|
| Critical | 5 | All concern foundation-order: M0/M1 ship executable before M2 governance reachable; identity chain not foundation-blocking; OAuth refresh race not mitigated; hallucinated-tool-invocation lacks proof gate; fanout cost not budget-gated. |
| Major | 12 | Provider-event over-normalization, F-125 dup, F-126 placement, hash-audit under-spec, parent-child supervision missing, fs-isolation missing, supply-chain attestation missing, A2A premature, 7-phase target unsound, soul boundary too weak (runtime-only), telemetry late, perms missing receipt-coupling. |
| Minor | 4 | F-124 overlap, F-073/F-126 conflation, M18/M7 source-of-truth, M2 label. |
| Praise | 5 | HITL loop, hash-chained audit, tool cap=10, kill-switch triad, multi-model adversarial review (with budget gate). |

**Wave-1 findings without F-NNN coverage**: 8 gaps surfaced (G1..G8) — all 8 mapped to NEW F-127..F-134 promotion candidates.

## Outputs (committed this lane)

| Path | Type |
|---|---|
| `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md` | full design review |
| `docs/06-agent-team-outputs/wave-002/lane-c-summary.md` | this file |
| `docs/10-backlog/feature-promotions.md` | +8 F-NNN promotion rows (F-127..F-134) |
| `docs/10-backlog/research-gaps.md` | +3 RG rows (RG-13..RG-15) |
| `docs/10-backlog/design-decisions-pending.md` | +3 D rows (D-24..D-26) |

## Loop-improvement proposal for wave-3

Wave-3 should:

1. **Re-dispatch the Copilot CLI design review with `-TimeoutSeconds 1200`** to obtain the second-voice cross-model signal that wave-002 Lane C did not produce. Verify cross-model agreement on F-127..F-134 promotions; any single-flagged Critical that the second voice does not corroborate gets demoted to Major.
2. **Stop adding frontier features.** Produce a dependency-checked **foundation cut**: reorder M0..M2 into an executable governance kernel; assign every provider/tool/agent feature a blocking dependency on identity + audit + halt + policy + budget.
3. **Output a milestone graph** (not prose): each F-NNN has `requires`, `blocks`, `security invariant`, `first milestone where executable code may call tools/providers`.
4. **Decision closure** on D-24/D-25/D-26 (7-phase scope, M2 rename, soul-boundary mechanism). Wave-3 cross-model verification promotes the survivors to HIGH.

## Anomalies

- Opus 600s timeout — first hit on this dispatcher in wave-002. Memory `feedback_pr_review_calibration_20260503.md` says 600s default; this dispatch's brief was ~12KB (well above the ~3KB calibration baseline that the comment in `Invoke-CopilotMultiModel.ps1` cites for the 240s→600s bump). Wave-3 lesson: brief size matters; budget per ~1KB.
- gpt-5.5 raw_output contains UTF-8 mojibake (`ΓÇö` for em-dash, etc.) from Copilot CLI's PowerShell stdout encoding. Findings extracted preserve the intent; wave-3 should normalize via `.NET UTF8Encoding` per `powershell-conventions.md` UTF-8 BOM gotcha section.

## Metrics

- duration: ~10 min wall-clock (within ≤5 min target — overshot due to Opus timeout)
- tool_uses: ~14
- artifacts: 5 files written + 3 backlog rows
- models-dispatched: 2 (1 completed, 1 timeout)
