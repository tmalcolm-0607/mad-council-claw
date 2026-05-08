# Pattern: Multi-Model Ensemble + Validator Consensus

**Canonical name:** Multi-Model Ensemble. Variants: *multi-LLM consensus*, *Star Chamber*, *LLM council*, *cross-model voting*, *jury agent*.

**One-line definition:** Run the same task through N independent LLMs (from different providers / different families). Aggregate their outputs using a validator agent that reaches consensus by explicit rules (unanimous / majority / safe-default).

## When to use

- High-consequence reviews where a single-model bias is unacceptable.
- Unattended / CI-CD flows where no human curator filters output.
- Evaluations where independent corroboration adds signal (measurably, per published research).
- Safety-critical findings (security review, verdict-binding Council reviews).

Published research validates significant accuracy gains:
- **+10% accuracy over single-shot** (arxiv 2511.17621, Nov 2025).
- **CodeBLEU + CrossHair consensus code generation** — 90.2% HumanEval vs 83.5% GPT-4o baseline (arxiv 2503.15838).
- **Independent re-implementations**: Mozilla.ai "Star Chamber," OpenReview "Adversarial Multi-Agent Evaluation via Iterative Debate," Awesome-LLM-Ensemble survey.

## When NOT to use

- Interactive / curated review where the human filters. Single-model is cheaper; curator catches single-model bias.
- Trivial tasks (typos, format fixes). The ensemble overhead dominates.
- Tight latency budgets. Three models in parallel is still 3x worst-case latency + validator.
- Tasks where one model is clearly authoritative (e.g., a domain-tuned internal model that dominates for a narrow security/compliance domain).

## Core mechanics

```
Input task
    ↓
┌──────────┬──────────┬──────────┐
│ Model A  │ Model B  │ Model C  │  ← run in parallel, isolated contexts
└────┬─────┴────┬─────┴────┬─────┘
     │          │          │
     └──────┬───┴──────────┘
            ↓
     [Validator agent]
            ↓
   Consensus rules:
   - 3/3 agree → accept
   - 2/3 agree → use majority
   - All disagree → safe-default fallback
            ↓
       Final output
```

Two pieces:

1. **Ensemble** — N models run independently on the same prompt. Isolation is key: one model's hallucination shouldn't taint another.
2. **Validator** — a separate agent (typically a single capable model, e.g., Claude Opus) reads all N outputs and applies consensus rules to emit a final answer.

## Canonical implementation

### `plugins/review-verdict/skills/review-verdict/references/phase-4-fix-mode.md`

Phase 4.0 Review Response Ensemble:

```markdown
Spawn 3 `general-purpose` agents simultaneously, each with a different model:

| Agent | Model | Model ID |
|-------|-------|----------|
| Evaluator A | Claude Opus | claude-opus-4.6 |
| Evaluator B | GPT-5.3-Codex | GPT-5.3-Codex |
| Evaluator C | Goldeneye | goldeneye |
```

Then:

```markdown
Spawn a validator agent (claude-opus-4.6) to reach consensus:
- 3/3 agree on classification → accept.
- 2/3 agree → use majority classification.
- All disagree → classify as valid_low_priority (safe default).
```

Repeated at Phase 4.1 (Fix Planning Ensemble) and Phase 4.3 (Self-Review Ensemble). Overall Phase 4 runs ~20-24 agents per iteration.

## Consensus rules in detail

### Unanimous (3/3)

All three agree → high confidence. Accept.

Pros: Highest-quality signal. Cons: Rare in practice; only ~40% of findings hit 3/3.

### Majority (2/3)

Two agree, one dissents → moderate confidence. Use the majority view; log the dissent.

Pros: Handles the common case where models have different training biases. Cons: May silence valid minority signal; mitigate by logging the dissent.

### All-disagree → safe default

Each model picks a different classification → no signal. Use a declared "safe default."

For review-verdict: safe default is `valid_low_priority` — the finding might be correct but isn't worth blocking on. Prevents "no consensus → block everything."

For other contexts: safe default might be "escalate to human" or "defer."

### Tie-breaker roles

Some implementations add a 4th agent as tie-breaker (VulTrial's "review board"). Adds cost, catches 2/3 splits. Not used by review-verdict; worth considering if 2/3 splits are frequent.

## Pros

- **Catches single-model bias.** One model has blind spots; three models with different training don't share all of them.
- **Measurable accuracy gain.** +10% to +7% range across published benchmarks.
- **Independence gives signal.** If 3 models from 3 vendors all say "this is a security issue," that's strong evidence.
- **Safe defaults prevent false-positive cascades.** All-disagree → low-priority is conservative.
- **Transparent decision process.** Dissent is loggable; the consensus computation is reviewable.
- **Works in unattended mode.** No human needed to filter.

## Cons

- **Token cost.** 3x single-model cost + validator = ~3.2x. Justified only when stakes warrant.
- **Latency.** Parallel helps, but validator is serial. +1 model's worth of latency over single-model.
- **Model availability.** Running GPT + Claude + Goldeneye requires access to all three. Budget + auth + rate limits.
- **Sycophant consensus.** If all three models are trained on similar data, they may agree for wrong reasons ("all wrong together").
- **Validator bias.** The validator is one model. Its biases drive the final output even when the ensemble dissents.
- **Not every task benefits.** Some tasks have objectively-correct answers where ensemble adds noise, not signal.

## Do / Don't

**Do**:

- **Pick models from different families.** Claude + GPT + Gemini > Claude + Claude + Claude. Diversity drives independence.
- **Isolate contexts.** Each model gets the same prompt in a fresh context. No shared memory.
- **Run in parallel.** Serial ensemble costs latency for no benefit.
- **Declare consensus rules upfront.** 3/3 / 2/3 / all-disagree — the thresholds are the contract.
- **Declare safe defaults explicitly.** `valid_low_priority` or `escalate_to_human` or `defer` — never implicit.
- **Log dissent.** Even when the majority wins, the dissenting finding is signal — surface in the verdict report.
- **Use the pattern only when the value justifies the cost.** See `wiki/patterns/mode-aware-sizing.md` — ensemble only in `auto` mode.
- **Cap the ensemble at 3.** 5-model ensembles have been tried; marginal gain is small, cost is large.
- **Pair with `wiki/patterns/yagni-filter.md`.** Filter findings before ensemble — no point running 3 models on a pre-demoted finding.

**Don't**:

- **Don't run ensemble on every call.** Mode-aware sizing — interactive mode uses single model; ensemble is for unattended.
- **Don't use the same model in all N slots.** That's not an ensemble, that's redundancy.
- **Don't combine ensemble with low temperature across all models.** Diverse outputs are the point; if all three give identical output, temperature was too low.
- **Don't skip the validator.** Raw 3 outputs are confusion; validator is what makes it consensus.
- **Don't hide the dissent.** "Consensus: X" without showing the minority view is less useful.
- **Don't assume the validator is unbiased.** It's still one model. Pick the validator deliberately (typically the strongest generalist; Claude Opus is a common choice).

## Common pitfalls

### All three models trained on similar data

Three agents that all give the same wrong answer isn't consensus; it's correlated failure. Pick families that differ in training data + architecture when possible.

### Validator interpreting classifications loosely

If Evaluator A says "valid_actionable" and Evaluator B says "actionable_valid," these are the same — but a naive validator may treat them as disagreement. Normalize classification labels before consensus check.

### 2/3-majority on inconsistent axes

Evaluator A classifies severity as HIGH. Evaluator B says "this isn't a finding at all." Evaluator C says severity MEDIUM. What's the 2/3? Severity and classification are different axes; 2/3 on one doesn't mean 2/3 on the other. Decide your consensus axis.

### Model access drift

Your ensemble uses Claude + GPT + Goldeneye. GPT model is deprecated. Now your ensemble is 2-model + error. Pin model IDs; have a fallback plan.

### Cost explosion

20-24 agents per Phase 4 iteration (review-verdict). If you run Phase 4 on every PR, costs scale linearly with PR count. Rate-limit; use mode-awareness to restrict ensemble to high-consequence reviews.

## Interaction with other patterns

- **+ `wiki/patterns/multi-role-review.md`** — ensemble is applied within a role (typically Skeptic), not across roles. Advocate/Skeptic/Architect are already N=3; an ensemble replicates Skeptic across M models.
- **+ `wiki/patterns/mode-aware-sizing.md`** — enabled only in `auto` mode in review-verdict.
- **+ `wiki/patterns/yagni-filter.md`** — filter cheap findings first; run ensemble on survivors only.
- **+ `wiki/patterns/bounded-iteration-caps.md`** — ensemble runs are capped per iteration; don't re-run ensemble on the same finding in a loop.

## MAD.Council specifics

`mad.council.a2a.md` §5.6 — ensemble is **optional**, off by default, enabled via `/council-review --ensemble` flag. When enabled:

- Applied to the **Skeptic role** (where false positives are most costly).
- Advocate and Architect remain single-model.
- 3-model consensus with safe default `valid_low_priority`.
- Only available in `auto` mode (no point when the user is curating).

The default Council review is 3-role single-model. Ensemble is opt-in for high-stakes reviews. Text-similarity consensus in v1; behavioral-equivalence (CrossHair-style) deferred to Phase 5 (see CHECKLIST gap: `Behavioral-equivalence consensus`).

## References

- **arxiv 2511.17621** — "Market Making as Scalable Framework for Safe Multi-Agent LLM" (+10% accuracy).
- **arxiv 2503.15838** — "Enhancing LLM Code Generation with Ensembles" (90.2% HumanEval).
- **arxiv 2512.20352** — "Multi-LLM Thematic Analysis with Dual Reliability Metrics."
- **Mozilla.ai Star Chamber blog** — https://blog.mozilla.ai/the-star-chamber-multi-llm-consensus-for-code-quality/
- **Awesome-LLM-Ensemble survey** — https://github.com/junchenzhi/Awesome-LLM-Ensemble
- **OpenReview iterative debate** — https://openreview.net/forum?id=06ZvHHBR0i
- `plugins/review-verdict/skills/review-verdict/references/phase-4-fix-mode.md` — marketplace canonical.
- `mad.council.a2a.md` §5.6 — MAD.Council integration.
- CHECKLIST patterns #43, #50 — mode-aware ensemble sizing + consensus structure.
