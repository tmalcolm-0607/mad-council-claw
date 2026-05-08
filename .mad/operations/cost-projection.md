# Cost Projection — Phase 1 & Beyond

Dollar estimates for operating MAD.Council at different scales. Grounded in the token counts modeled in `metrics/financial-metrics.md` and provider pricing as of 2026-04-17. Numbers are **estimates for sizing decisions**, not contractual commitments.

## Pricing snapshot (verify at Phase-1 kickoff)

All prices in USD per 1M tokens. Batch/cached discounts ignored for upper-bound sizing; apply them in real cost reporting.

| Provider × model | Input $/M | Output $/M | Notes |
|---|---|---|---|
| Anthropic Claude Opus 4.7 | $15 | $75 | Baseline for all Advocate / Architect / Fuser / propose-Skeptic calls. |
| Anthropic Claude Opus 4.7 (1M context) | $18 | $90 | Rarely invoked; large-brief fallback only. |
| OpenAI GPT-5.3-Codex | $2.50 | $10 | Ensemble member (Skeptic only in `--mode auto`). |
| Goldeneye (internal) | negotiated | negotiated | Assume ≈ $5 / $15 for sizing until contract clarifies. |

Prompt-caching (Anthropic) can cut input costs by ~50–90% on repeat briefs. Sizing below assumes **no caching** — a pessimistic upper bound. Actual production spend typically runs 40–60% of the numbers here once caching kicks in.

## Per-invocation token model

Token budgets per skill invocation (input + output), grounded in the dry-run trace (`operations/dry-run-happy-path.md`) and the review-brief size in `skills/council-review/plan.md`:

| Skill | Input tokens (p95) | Output tokens (p95) | Notes |
|---|---|---|---|
| `/council-open` | — | — | No model call; pure file I/O. **$0.** |
| `/council-join` | — | — | No model call. **$0.** |
| `/council-post` | 0–400 | 0 | Mention validation + literal-phrase scan are string ops. Only model call if `--assist` mode (Phase 5). |
| `/council-check` | — | — | No model call. Rendering is deterministic. |
| `/council-leave` | — | — | No model call; Completion Report is structured aggregation. |
| `/council-list` | — | — | No model call. |
| `/council-resolve` | — | — | No model call. Wraps `/council-post`. |
| `/council-retro` | — | — | No model call. Captures typed scores. |
| **`/council-review` `propose`** (3 calls) | 1,200 × 3 = 3,600 | 800 × 3 = 2,400 | Brief 1–5 KB; output 2–3 KB per role. |
| **`/council-review` `auto`** (6 calls) | 1,200 × 3 + 1,200 × 3 (ensemble) + 3,000 fuser = 9,600 | 800 × 3 + 800 × 3 + 1,500 fuser = 6,300 | Ensemble = Skeptic × 3 models. Fuser reads all Skeptic outputs + rubric. |
| `/council-verdict` | — | — | Manual override path. No model call; consent gate + rationale. |

## Per-review cost

Using prices above:

| Mode | Input cost | Output cost | Total per review |
|---|---|---|---|
| **`propose` (all Claude Opus)** | 3,600 × $15/M = **$0.054** | 2,400 × $75/M = **$0.180** | **$0.234** |
| **`auto` — all Opus (worst case)** | 9,600 × $15/M = **$0.144** | 6,300 × $75/M = **$0.473** | **$0.617** |
| **`auto` — mixed ensemble** (Opus + GPT-5.3-Codex + Goldeneye avg) | ~$0.09 input | ~$0.30 output | **~$0.39** |

**Baseline to memorize:** `propose` ≈ $0.25/review · mixed `auto` ≈ $0.40/review · all-Opus `auto` ≈ $0.62/review.

## Scenario projections

### Scenario A — Dogfood (S0): 5 engineers, ~3 reviews/day/engineer

- 15 reviews/day × 30 days = 450 reviews/month.
- All in `propose` mode (ensemble too expensive for dogfood pace).
- **Monthly cost: 450 × $0.234 = $105.**
- Plus infra (storage, telemetry): negligible — file-based.

### Scenario B — Internal pilot (S1): 8 teams × ~5 engineers × 5 reviews/day

- 200 reviews/day × 30 days = 6,000 reviews/month.
- 80% `propose`, 20% `auto` for security-sensitive reviews.
- **Monthly cost: (4,800 × $0.234) + (1,200 × $0.39) = $1,123 + $468 = $1,591.**

### Scenario C — Internal GA (S2): 50 teams × 5 engineers × 5 reviews/day

- 1,250 reviews/day × 30 days = 37,500 reviews/month.
- 70% `propose`, 30% `auto`.
- **Monthly cost: (26,250 × $0.234) + (11,250 × $0.39) = $6,143 + $4,388 = $10,531.**

### Scenario D — Default-on (S3): 200 teams × 10 engineers × 3 reviews/day

- 6,000 reviews/day × 30 days = 180,000 reviews/month.
- 70% `propose`, 25% `auto`, 5% `auto` (all-Opus for legal/compliance).
- **Monthly cost: (126,000 × $0.234) + (45,000 × $0.39) + (9,000 × $0.62) = $29,484 + $17,550 + $5,580 = $52,614.**

At Scenario D it becomes worth investing in Anthropic's prompt caching to cut ~50% off input costs. Estimated with caching: **~$35,000/month**.

### Scale factor

$/review × reviews/day × days/month. Per-team cost at Scenario D with caching ≈ $175/team/month — roughly one senior engineer's worth of code-review time saved per team per month for the cost. That's the pitch for the rollout plan (§Rationale in `plans/phase-1-mvp.md`).

## Budget gates

Per `metrics/financial-metrics.md §Budget gates (Phase 5)` — not shipped in Phase 1 but scoped here:

| Gate | Threshold (S2 scale) | Behavior on trip |
|---|---|---|
| **Per-channel daily soft cap** | $5/channel/day | Warn on next `/council-review`; suggest `propose` mode. |
| **Per-channel daily hard cap** | $10/channel/day | Reject new `/council-review` with `rc=5`; mention consent gate via `--force-over-budget`. |
| **Per-user monthly soft cap** | $200/user/month | Warning at 80% / 100%; user sees running-total in `/council-list --verbose`. |
| **Per-user monthly hard cap** | $500/user/month | Rejects reviews unless user flips a per-invocation `--budget-override` consent. |
| **Org monthly budget alert** | 80% of configured monthly budget | PagerDuty-style alert to kit owner. |
| **Org monthly hard cap** | 100% of configured monthly budget | Rejects new reviews org-wide; admin opens ticket to raise budget. |

Defaults are conservative; easy to raise in `channel.json.settings.budget_caps` or an org-level config (Phase-4 concern). Default thresholds reviewed quarterly against actual spend trajectory.

## Cost instrumentation

Every upstream LLM call produces OTel GenAI spans (per `metrics/README.md`) with `gen_ai.usage.input_tokens` + `gen_ai.usage.output_tokens` + `gen_ai.response.model`. The cost-derivation pipeline:

- `council_review.cost_usd` = `input_tokens × provider_input_rate + output_tokens × provider_output_rate`.
- Rates table kept in `metrics/pricing-snapshot.json` (Phase-1 deliverable); pipeline refreshes weekly.
- Derived counter: `council_review.cost_usd_total{channel, user, mode, provider}` — feeds the budget gates above.

## Non-cost: what we DO NOT charge for

- **File I/O time** — nominally free at the spec level; O(disk ops) counts toward latency SLOs, not cost.
- **`/council-check` polling** — the per-minute CronCreate poll is free (no model call). Fan-out across N members costs proportionally to N but each member's check is $0.
- **Scripts** — `atomic-write.ps1`, `seq-increment.ps1`, etc. are local CPU/IO only.
- **MAD artifacts** — `spec.md` / `plan.md` / `tasks.md` in Phase 3 are user-written + model-assisted; the model-assisted write goes through `/council-review auto` or dedicated skills, which bill as normal.

## Reporting

Planned for Phase 5 (not Phase 1):

- Weekly per-user cost summary in `/council-list --verbose`.
- Monthly org roll-up emitted to the kit owner.
- Per-channel spend trend charts in Grafana (Dashboard 2 in `metrics/README.md`).

Phase 1 ships without these — the raw counter is emitted, but aggregation is post-hoc.

## Assumptions & risks

- **Pricing holds.** Verified 2026-04-17. If Anthropic/OpenAI raise input prices 2×, Scenario D doubles. Mitigation: re-verify quarterly + budget buffer 20%.
- **Prompt-caching works as advertised.** Anthropic reports 5-min cache TTL; our review briefs usually fit within that when a user does multiple reviews in succession. Mitigation: measure cache-hit rate in `metrics/financial-metrics.md §Cost per successful outcome`.
- **Ensemble mode remains rare.** If `auto` mode usage creeps from 20–30% to 50%, Scenario D spend rises ~25%.
- **Token counts are approximate.** p95 was used; worst cases (32KB body triggering long brief) can push ~2× input tokens. Budget hard-caps buffer this.

## Non-goals

- **Do not attempt precise unit economics at scaffold phase.** Numbers here are one significant figure; anything tighter would pretend precision we don't have.
- **Do not couple cost projections to the spec.** Spec is provider-agnostic; this doc is empirical.
- **Do not include non-model costs** (salaries, hardware, support) — those belong in the owning team's budget, not this doc.

## Related

- `metrics/financial-metrics.md` — the canonical counters feeding these projections.
- `operations/rate-limits.md` — fan-out shape drives token counts.
- `plans/phase-1-mvp.md §Rationale` — "one senior engineer of review time saved per team per month" comparison.
- `plans/phase-5-intelligence.md §Milestone 12` — per-agent tool-call budgets interact with cost caps.
- `skills/council-review/SKILL.md §Mode-aware sizing` — where the call fan-out is authoritative.
