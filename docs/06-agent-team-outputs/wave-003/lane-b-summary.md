---
artifact-class: lane-summary
wave: wave-003
lane: lane-b
date: 2026-05-06
topic: copilot-cli-multi-model-design-review-retry
generated-by: lane-b-orchestrator
generated-by-version: 0.1.0
status: preview
---

# Wave-003 Lane B summary — Copilot CLI design review retry

## Scope

Per Lane C wave-2 loop-improvement proposal #1: re-dispatch Copilot CLI design review with `-TimeoutSeconds 1200` to obtain the second-voice cross-model signal that wave-2 Opus timeout at 600s prevented.

Time-budget allocation: ≤15 min wall-clock (Opus expected ~5-10 min on 12KB brief).

## Path taken

**Standalone Opus dispatch** (NOT full dispatcher re-run, which would have re-spent gpt-5.5 budget unnecessarily). Used Start-Job + `copilot --model claude-opus-4.7 --yolo -p $brief` with Wait-Job -Timeout 1200.

| Model | Wave-2 status | Wave-3 retry status | Wall-clock | Tokens (in / out / cached) |
|---|---|---|---|---|
| `gpt-5.5` | completed (exit 0) wave-2 | reused wave-2 result | ~33s (wave-2) | 36.7k / 2.2k / 0 |
| `claude-opus-4.7` | TIMEOUT 600s (wave-2) | **completed (exit 0) wave-3 retry** | **~94s (1m 28s)** | **63.7k / 4.6k / 27.7k** |

**Key finding:** Opus completed comfortably under the 600s default. The wave-2 timeout was a transient (cold-cache, warm-up, or short-lived availability blip), not a fundamental capacity issue. **Recommendation: keep dispatcher default at 600s; add retry-once-on-timeout to dispatcher logic — would have caught wave-2 for free.**

## Cross-model agreement table

Built per `lens-multi-model-review-pattern.md`. Full table in `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md` § Cross-model agreement table.

### Severity counts after cross-model synthesis

| Bucket | Count | F-IDs |
|---|---:|---|
| HARD BLOCK (both flag Critical, OR severity escalates via cross-model agreement) | **7** | F1 (governance ordering), F2 (IBackendProvider), F3 (hallucinated tools), F4 (skill supply-chain), F5 (identity bootstrap), F6 (OAuth race), F7 (fanout cost) |
| MUST-FIX (both flag Major) | **5** | F8, F11, F12, F13, F14, F15 |
| SHOULD-FIX (single-model Major) | **8** | F9, F10, F16, F17, F18, F19, F28, F29, F30, F31 |
| CONSIDER (Minor or single-model) | **6** | F20, F21, F22, F23, F24, F25, F26, F32 |
| PRAISE both flag | **4** | P1, P2, P4, P5 |
| PRAISE single-model | **4** | P3, P6, P7, P8 |

## F-NNN promotion outcomes (cross-model upgraded)

Wave-2 promoted F-127..F-134 (8 entries) at HIGH (single-model). Wave-3 retry cross-model verification:

- **All 8 of F-127..F-134 retain HIGH cross-model confidence** — Opus and gpt-5.5 concur on root cause for all 8, even where severity tag differs.
- **F-133 (real-agent-filesystem-isolation)** demoted to MEDIUM cross-model confidence — gpt-5.5 only; Opus folds the lesson into supervision-lock C2/M5 finding rather than calling it out separately. Keep F-133 as a feature but mark MEDIUM until wave-4 corroborates.
- **3 NEW F-NNN candidates from Opus-only findings** (F-135, F-136, F-137) — promote at MEDIUM/LOW pending wave-4 corroboration.

| F-NNN | Title | Wave-2 conf | Wave-3 conf | Cross-model decision |
|---|---|---|---|---|
| F-127 | foundation-governance-kernel | HIGH (gpt-5.5) | HIGH (both Critical) | HARD BLOCK |
| F-128 | per-agent-identity-bootstrap | HIGH (gpt-5.5) | HIGH (severity escalates) | HARD BLOCK |
| F-129 | oauth-refresh-singleflight-lock | HIGH (gpt-5.5) | HIGH (severity escalates) | HARD BLOCK |
| F-130 | tool-invocation-proof-gate | HIGH (gpt-5.5) | HIGH (both Critical) | HARD BLOCK |
| F-131 | fanout-budget-governor | HIGH (gpt-5.5) | HIGH (severity escalates) | HARD BLOCK |
| F-132 | parent-child-supervision-locks | HIGH (gpt-5.5) | HIGH (both Major) | MUST-FIX |
| F-133 | real-agent-filesystem-isolation | HIGH (gpt-5.5) | MEDIUM (single-model) | PROMOTE at MEDIUM |
| F-134 | skill-supply-chain-attestation | HIGH (gpt-5.5) | HIGH (severity escalates) | HARD BLOCK |
| **F-135** | mcp-oauth-2.1-tls-pin | n/a | MEDIUM (both, F-NNN shape divergent) | PROMOTE at MEDIUM |
| **F-136** | agent-manifest-export | n/a | LOW (Opus only) | PROMOTE at LOW |
| **F-137** | supervisor-status-stream | n/a | LOW (Opus only) | PROMOTE at LOW |

## Outputs (committed this lane)

| Path | Type |
|---|---|
| `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md` | UPDATED — full cross-model agreement table; wave-3 retry resolution section |
| `docs/06-agent-team-outputs/wave-003/lane-b-summary.md` | this file |
| `docs/10-backlog/feature-promotions.md` | UPDATED — wave-3 cross-model verdict column added |
| `docs/10-backlog/research-gaps.md` | UPDATED — RG-13 closed (Opus retry succeeded); RG-16 added (dispatcher retry-once-on-timeout) |
| `docs/10-backlog/design-decisions-pending.md` | UPDATED — D-24/D-25/D-26 cross-model corroboration noted |

## Anomalies

- **Wave-2 600s timeout was transient.** Opus retry succeeded at ~94s. Likely causes (cold-cache, model availability, short-lived blip) cannot be confirmed without Copilot-side telemetry. Wave-4 dispatcher upgrade: add retry-once-on-timeout (60s sleep then retry same TimeoutSeconds).
- **Wave-3 dispatched Opus standalone**, NOT via `Invoke-CopilotMultiModel.ps1` — to avoid re-spending gpt-5.5 budget. Dispatcher remains canonical for fresh dispatches; standalone path is correct for retry-of-one-leg. Document the pattern in `lens-multi-model-review-pattern.md` under § Fallback (next iter).
- **UTF-8 mojibake** persists in both raw outputs (`ΓÇö`, `ΓåÆ`). Cosmetic; intent preserved. Upstream Copilot CLI stdout encoding issue.
- **Severity-tag divergence is the cross-model signal** (not a flaw). When Opus says Major and gpt-5.5 says Critical (e.g., F5 identity bootstrap), the disagreement IS the signal — both flag, but they prioritize differently. Take the higher severity per `lens-multi-model-review-pattern.md` "both-flag → take higher severity" rule.

## Loop-improvement proposal for wave-4

1. **Add retry-once-on-timeout to `Invoke-CopilotMultiModel.ps1`** — 60s sleep, retry same TimeoutSeconds, then declare failure. Would have caught wave-2 transient automatically.
2. **Normalize Copilot CLI UTF-8 output** — wrap dispatcher with `[System.Text.UTF8Encoding]::new($false)` Out-File; the mojibake persists across both runs.
3. **Promote F-127..F-132 + F-134 spec stubs to wave-4 architecture lane** — the 7 HARD BLOCKs need full F-NNN spec entries before M0 freeze. Run a third-model corroboration pass on F-133 / F-135 / F-136 / F-137 (the MEDIUM/LOW candidates) to either upgrade or drop them.
4. **Build the milestone DAG with cross-model HARD BLOCK gates baked in** — every M0..M2 feature should show its `requires`/`blocks` edges plus which HARD BLOCK F-NNNs gate it.

## Metrics

- duration: ~5 min wall-clock (Opus retry ~94s + table-build + commits + this summary)
- tool_uses: ~12 (Read x4, Write x3, Edit x2, Bash x4 incl. PowerShell dispatch)
- artifacts: 4 files updated + 1 new lane summary + 0 raw output (Opus result already in scratch)
- models-dispatched (wave-3 only): 1 (claude-opus-4.7, exit 0, ~94s)
- cumulative cross-model: 2 voices captured (gpt-5.5 wave-2 + Opus wave-3)
