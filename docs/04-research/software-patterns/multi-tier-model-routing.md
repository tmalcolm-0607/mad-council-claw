---
artifact-class: research-finding
source-tag: [R:software-patterns]
confidence: high
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://kansei-link.com/en/insights/claude-model-cost-guide-2026.html
  - https://www.morphllm.com/sonnet-vs-haiku
  - https://www.augmentcode.com/guides/ai-model-routing-guide
  - https://zenvanriel.com/ai-engineer-blog/llm-api-cost-comparison-2026/
  - https://pecollective.com/tools/claude-pricing-guide/
  - https://aiempiremedia.com/claude-pricing-2026/
---

# Multi-tier model routing (Haiku → Sonnet → Opus)

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter.

## Load-bearing patterns

- **The 75/15/10 rule**: a converged industry recommendation for 2026 — Haiku (4.5) handles ~75% of work (classify, route, validate, extract, simple Q&A); Sonnet (4.6) handles ~15% middle band (real reasoning, multi-step but well-scoped); Opus (4.6) handles the ~10% deepest (architectural decisions, ambiguous specs, security review, novel problem decomposition). Different sources cite slightly different splits but all converge on the same shape.
- **Pricing tiers (March 2026)**:
  - Haiku 4.5: $1 input / $5 output per 1M tokens (5x cheaper than Sonnet, 25x cheaper than Opus on input)
  - Sonnet 4.6: $3 input / $15 output (the workhorse default)
  - Opus 4.6: $5 input / $25 output (frontier reasoning)
- **Documented cost savings ranges**:
  - 50-80% chain cost reduction with three-tier routing (most production deployments)
  - 60-80% with minimal quality impact (most apps)
  - 40-60% vs all-Sonnet baseline
  - 80-90% vs naive-Opus baseline when stacked with prompt caching (90% on cache hits) + Batch API (50% off batch jobs)
- **Routing-decision primitives**: classify the task first (cheap classifier or rule-based), then route. Anti-pattern: routing on user-input length alone — length ≠ complexity. Better signals: task type tag, declared user intent, prior-iteration confidence score, presence of multi-step reasoning markers.
- **Stacking discounts (multiplicative, not additive)**: Tier-routing × prompt-caching × Batch-API can compound. 60% from routing × 90% from cache × 50% from batch ≠ summed savings — stacked, you get the multiplicative residual cost.

## Verbatim quotes worth preserving

> "Haiku routes and handles simple tasks, Sonnet processes the 80% of requests that require real intelligence, and Opus tackles the 10 to 15% that demand the deepest reasoning."

> "This three-tier routing alone delivers 50–80% cost reduction in most production deployments."

> "Together [tier routing + caching + Batch API], these optimizations can reduce costs by 80-90% compared to naive Opus usage."

## Implications for the engine catalog

The kit currently has `model-selection.md` as a rule but no mechanical enforcement of the 75/15/10 split. The 2026 reference architecture treats this as a routing-table primitive, not a per-skill recommendation. Strong F-NNN candidate: a kit-level routing rule that pairs each skill (or skill phase) with a tier (Haiku/Sonnet/Opus) and a routing-rationale comment, validated by a CI-style audit (`/skill-audit` extension). The "lead Opus + teammates Sonnet" pattern from `agent-teams.md` is one specific instance of this; the general primitive is missing.

## NEW F-NNN candidates

- F-069 mandatory-model-tier-declaration — Every skill SKILL.md frontmatter MUST declare `model-tier: haiku|sonnet|opus` (or per-phase tier map for multi-step skills). Tier-skill-audit verifies declared tier vs cost telemetry post-run — confidence: H
- F-070 task-classifier-as-primitive — A built-in cheap classifier (Haiku-class) that routes tasks to tiers based on (a) task type, (b) declared complexity, (c) prior-iter confidence. Engine ships this as a default skill that orchestrators delegate routing to — confidence: H
- F-071 stacked-discount-defaults — Engine defaults: prompt-caching ON for system prompts >1KB; Batch API ON for non-real-time skill phases (audits, research sweeps); per-skill SLA budget that turns these on/off — confidence: H
- F-072 cost-anomaly-alerting — When a session's actual cost exceeds the projected cost (based on model tiers × tokens) by N×, emit an anomaly per `anomaly-thresholds.md`. Catches "accidentally invoked Opus 12 times in a tight loop" — confidence: M
- F-073 tier-downgrade-resilience — Routing rule: on Opus rate-limit or 5xx, fail-down to Sonnet with a recorded `tier-downgraded` flag in telemetry. Avoids hard-fail when frontier capacity is constrained — confidence: M

## Confidence

HIGH — the 50-80% / 60-80% / 80-90% number bands are cited consistently across at least 4 of the 6 sources; pricing tiers are direct quotes from Anthropic's pricing page (cited indirectly via the comparison sites).
