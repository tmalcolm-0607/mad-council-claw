# Upstream Rate Limits — model-provider budget & back-off

MAD.Council's Council layer fans out to multiple LLM calls per `/council-review` invocation. Fan-out is where provider rate limits bite first. This document says what limits exist, what we do when we hit them, and what the operator sees.

## Fan-out by mode

| Mode | Advocate | Architect | Skeptic | Fuser | Total calls per review |
|---|---|---|---|---|---|
| `propose` (default) | 1 × Opus | 1 × Opus | 1 × Opus | — | **3** |
| `auto` | 1 × Opus | 1 × Opus | 3 × {Opus, GPT, Goldeneye} | 1 × Opus | **6** |

(Values match `agents/*/plan.md` and the CHK-052 clarification — ensemble fans out on Skeptic only, not all roles.)

Per-role **4-minute timeout** (CHK-043, under Claude Code's 5-min stream abort). Per-role **tool-call budget** (Phase-5 Milestone 12: Advocate 15 / Skeptic 25 / Architect 20 / Fuser 10). Tokens per role are bounded by the brief size (typically 2–10 KB) + role output cap (typically 2–5 KB).

## Provider limits (as of 2026-04-17)

Snapshot; verify against provider console at Phase-1 kickoff.

| Provider | Free-tier / Build | Scale-tier / Enterprise | Enforcement |
|---|---|---|---|
| Anthropic Claude (Opus) | 50 RPM, 40,000 tokens/min | 4,000 RPM, 400,000 tokens/min | HTTP 429 with `retry-after` header |
| OpenAI (GPT-5.3-Codex) | 10 RPM | tier-dependent; contractual | 429 + `x-ratelimit-*` headers |
| Goldeneye (internal) | project-dependent | project-dependent | HTTP 503 + `Retry-After` |

Two consumption axes matter:

- **Requests per minute (RPM)** — a 6-call `/council-review auto` invocation spikes RPM by 6 briefly. At 3 concurrent reviews, that's 18 requests in a narrow window — well inside Scale-tier but can trip Free-tier.
- **Tokens per minute (TPM)** — briefs are ~5 KB (≈1200 tokens) input; outputs ≈2 KB (≈500 tokens). A 6-call review ≈10,200 tokens, worst-case near ~20 KB total (≈4800 tokens). 5 concurrent reviews ≈ 24K tokens — mostly safe on Scale-tier.

## Provider-tier sizing guidance

| Expected concurrent reviews | Recommended tier | Notes |
|---|---|---|
| 1–2 (single-user dogfood) | Free / Build | Fine for S0 rollout. |
| 3–5 (small pilot) | Build (Claude) + equivalent | Stay in `propose` mode; `auto` can trip during co-occurring reviews. |
| 6–15 (internal GA) | Scale (Claude) + equivalent | Both modes comfortable. |
| 16+ | Scale + deliberate queueing | See §Queueing strategy below. |

## Back-off strategy

MAD.Council uses **exponential back-off with full jitter** (AWS-style, not FB-style) for 429/503 responses:

```
attempt_n_wait_ms = random(0, min(base_ms * 2^n, cap_ms))
```

Defaults:
- `base_ms = 1000` (1 second)
- `cap_ms = 32000` (32 seconds)
- Max retries: **3** (bounded iteration cap per `wiki/patterns/bounded-iteration-caps.md`)

After 3 retries, the role invocation times out and returns a **soft failure** to `/council-review`, which:

1. Records the role as `timed_out: true` in verdict.json.
2. Fires the `council_review.rate_limit_role_drop_total{role=<name>}` counter.
3. Applies mechanical ESCALATE-trigger logic (per CHK-040): if ≥2 of 3 roles drop due to rate limits, escalate the verdict to ESCALATE with `escalate_trigger: "rate_limit_exhaustion"`.

## Queueing strategy (Scale-tier, high-concurrency)

When MAD.Council runs in an environment with more than ~15 concurrent reviews per minute, the retry-queue alone becomes lossy (more retries than headroom). Phase-5 introduces a shared-session budget:

- **In-process queue** at the /council-review skill level: up to 3 reviews wait in memory before the 4th gets a synchronous "queue full — try again in N seconds" response.
- **Per-channel review-rate cap**: no more than 1 review per 30 seconds per channel by default. Configurable via `channel.json.settings.review_rate_cap_seconds`.
- **Global rate-limit dashboard**: `council_review.rate_limit_headroom_pct` (derived metric) shows how close the running average is to the provider tier ceiling. Alert at 80%.

These are Phase-5 features — Phase 1–2 rely on retry + drop + ESCALATE.

## Headers and observability

Every upstream call records (per OpenTelemetry GenAI semantic conventions):

- Request/response duration (`gen_ai.client.operation.duration` histogram).
- Token counts (`gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`).
- HTTP status + retry count in span attributes.
- `retry-after` header value when received.

This feeds:
- `council_review.rate_limit_hit_total{provider, model, mode}` — counter.
- `council_review.retry_attempts` — histogram.
- `council_review.rate_limit_headroom_pct{provider}` — derived daily.

## Graceful degradation ladder

Fallback order when limits bite (from least-to-most degraded):

1. **Retry with back-off** — first 3 attempts for the failing role.
2. **Drop-one-role** — proceed with 2 of 3 roles; verdict quality flagged with `roles_run[n].timed_out=true`. User sees "Proceeded with 2 of 3 roles — rate limit on Architect" in the rendered verdict.
3. **Drop-to-propose mode** — for the current review only, fall back from `auto` to `propose` (no ensemble on Skeptic). Record `mode_degraded_from` in verdict JSON.
4. **ESCALATE to human** — if ≥2 of 3 roles drop, or if propose-mode also hits limits, the verdict escalates. User resolves manually via `/council-verdict`.
5. **Reject review** — only if the first model call gets 429 on first attempt with no back-off headroom (e.g., TPM exhausted). User sees "Review deferred 60 seconds — provider rate limit. Retry via /council-review."

Ladder rungs 1–4 happen automatically; rung 5 requires explicit user retry.

## What operators see

In `/council-review` output:

```
Running Council on thread reproduce-the-race-a1b2…
  Advocate (Opus): OK (confidence 0.9, 41s)
  Skeptic (ensemble): 2 of 3 succeeded (GPT rate-limited; back-off exhausted)
  Architect (Opus): OK (confidence 0.78, 33s)

Verdict: FIX (with-caveats) — proceeded with partial ensemble (Skeptic degraded)
```

Readers see degraded state inline; no hidden fallback.

## Secrets posture

Rate-limit responses from providers sometimes leak identity signals (account ID in `x-ratelimit-reset` context, etc.). The telemetry pipeline **strips** `authorization`, `x-api-key`, and any `x-user-*` / `x-account-*` headers before emission. Headers marked `retry-after` and `x-ratelimit-remaining` are retained — safe.

## Non-goals

- **Do not** implement a full circuit-breaker over providers — per `rules/degradation-fallback-policy.md` we drop the role, not the entire review. A circuit-breaker-over-provider pattern leads to cross-role starvation.
- **Do not** preemptively rate-limit MAD calls based on estimated budget — upstream is authoritative; we react to their 429/503, we don't try to predict.
- **Do not** silently retry forever. Bounded at 3 attempts per call.

## Verification

Layer-3 fault injection:

- [ ] Stub provider returns 429 on first call, 200 on retry — verify 1 retry path succeeds.
- [ ] Stub returns 429 on all calls — verify role drop after 3 retries, verdict reports `timed_out: true`.
- [ ] Stub returns 429 for 2 of 3 Skeptic ensemble models — verify consensus still emerges if majority succeeds.
- [ ] Stub returns 429 for all 3 Skeptic ensemble models — verify fallback to propose mode.
- [ ] Stub returns 429 for Advocate + Skeptic — verify ESCALATE verdict with `escalate_trigger: "rate_limit_exhaustion"`.

## Related

- `rules/degradation-fallback-policy.md` — the "never-block-on-optional" rule the ladder instantiates.
- `wiki/patterns/bounded-iteration-caps.md` — the "max 3 retries" pattern.
- `skills/council-review/SKILL.md` §Error handling — where these rungs attach.
- `metrics/technical-metrics.md` §Latency + error histograms — where the telemetry lands.
- `metrics/financial-metrics.md` §Token usage — rate-limit events interact with spend.
- `plans/phase-5-intelligence.md` §Milestone 12 — per-agent tool-call budgets (tightly related).
- Anthropic usage docs: `https://docs.anthropic.com/en/api/rate-limits` (canonical provider-side reference).
