# Pattern: Learning Signals (Execution + Outcome)

**Canonical name:** Learning Signals. Variants: *telemetry pairing*, *self-assessment vs independent-eval*, *honest retro*, *post-execution signal capture*.

**One-line definition:** After an agent completes work, capture two signals: the agent's self-assessment of what it did + an independent evaluation of the outcome. The **gap between them is the learning**.

## When to use

- Systems that need to improve over time (skills / prompts / model picks).
- Any skill where "it finished" doesn't tell you "it did well."
- Remediation / migration workflows where the user has opinions the agent should hear.
- Any automated process you want to understand post-hoc.

## When NOT to use

- One-off interactive sessions where no improvement pipeline consumes the signal.
- Stateless query-response flows (no work unit to assess).
- Systems without a correlation key (no way to match self-assessment to outcome).

## Core mechanics

```
Agent completes work unit (run_id = G)
     ↓
Self-assessment signal (execution)
  - What was proposed / applied
  - Self-reported scores (1-5 on multiple axes)
  - Patterns noted (what_worked, what_was_hard)
  - Correlated by run_id = G
     ↓ (later, independent)
Independent evaluation (outcome)
  - Quality rating
  - Effort-to-merge
  - User accepted / modified / rejected
  - Also correlated by run_id = G
     ↓
The gap = learning
  - Self-rated 5, independently rated 2 → agent overconfident
  - Self-rated 2, independently rated 5 → agent under-reports
  - Patterns from what_was_hard feed prompt improvements
```

Two signals, one correlation key. The system stores both; analysis tools compare them.

## Canonical implementation

### `plugins/sfi-dev-toolkit/skills/remediation-review/SKILL.md` + `mise-v2-pr-quality-evaluator-skill/SKILL.md`

SFI's ALAS (Agentic Learning and Assessment System):

**Execution signal (remediation-review):**

```json
{
  "run_id": "<guid>",
  "kpi_id": "ID2.1.9",
  "skill_used": "mise-v1-to-v2-aspnetcore",
  "mode": "interactive",
  "session_summary": {
    "changes_proposed": "<what the skill proposed — full journey>",
    "changes_applied": true,
    "developer_accepted": true,
    "developer_modified": false,
    "escalation_needed": false,
    "turns_taken": 4,
    "improvisation_needed": false,
    "pr_url": "<PR URL or null>"
  },
  "scores": {
    "accuracy": 4,
    "completeness": 3,
    "tsg_alignment": 5,
    "dx": 4,
    "confidence": 3
  }
}
```

**Outcome signal (mise-v2-pr-quality-evaluator):**

```json
{
  "run_id": "<guid>",
  "pr_id": "12345",
  "quality_score": "B",
  "effort_to_merge": "Low",
  "dimensions": {
    "intent_alignment": 4,
    "change_minimalism": 5,
    "pattern_consistency": 3,
    "abstraction": 4,
    "coherence": 4,
    "middleware_order": 5
  }
}
```

**Correlation**: both carry the same `run_id`. ALAS stores them in one hub issue — execution signal in the body, outcome signal as a comment. The analysis consumes pairs.

## Honest self-assessment

Critical detail from the SFI pattern: **deliberately low scores (2, 3) are valued over inflated 5s**.

Why: if agents always self-report 5/5, the self-assessment carries no signal. The point is the **gap** between self and independent. Agents need to be honest about what was hard, what required improvisation, what they're uncertain about.

Concretely in `/council-retro`: the skill asks the user to score, not to self-approve. Low scores are a feature, not a bug.

## Pros

- **Real improvement data.** Aggregate across sessions: which skills overreport? Which underreport? What patterns correlate with low outcome scores?
- **Captures intangibles.** "Turns taken" and "improvisation needed" surface issues that don't appear in code diffs.
- **Prompt-tuning signal.** If a skill consistently self-reports high confidence on outcomes that independently score low, the prompt is overconfident.
- **Grounded in run_id.** Correlation is mechanical; no fuzzy-matching needed.
- **Works across skill boundaries.** One session may invoke many skills; the whole journey is captured under one run_id.

## Cons

- **Requires independent evaluator.** Self-assessment alone is just diary entries. Need a second signal.
- **Storage + analysis infra.** Hub issues, ALAS — requires something to consume + analyze the signals.
- **Agents resist honest low scores.** Training data biases toward confident answers. Prompts need explicit "low is valuable" framing.
- **Mismatch on async outcomes.** Execution signal is immediate; outcome signal may come days later (when the PR merges). Correlation must survive the gap.

## Do / Don't

**Do**:

- **Capture both signals.** Execution without outcome = no gap analysis.
- **Use the same run_id on both.** Correlation depends on it.
- **Score on multiple axes.** Single-number scores compress away detail. 3-5 axes balance signal vs friction.
- **Include "full journey" prose**, not just the final outcome. The path matters for learning.
- **Frame low scores positively.** "2 means you found it hard, that's useful" — the prompt tells the agent this.
- **Pair with `wiki/patterns/completion-report-protocol.md`.** Reports naturally carry the execution signal.
- **Pair with `wiki/patterns/run-id-correlation.md`.** Without run_id, no pairing.
- **Make it optional.** `/council-retro` shouldn't block session close. If skipped, log a note but don't fail.

**Don't**:

- **Don't skip self-assessment because it "feels like overhead."** It's the cheapest part. Skip outcome-capture instead if budget is tight.
- **Don't use the same agent for self-assessment AND outcome.** That's not "independent"; that's one agent grading itself.
- **Don't aggregate signals into single scores too aggressively.** "Overall = 4" loses the texture of "accuracy=5, completeness=2."
- **Don't demand signals the agent can't honestly provide.** If the skill didn't measure it, don't ask for it.
- **Don't publish signals without privacy consideration.** Learning signals can include user identity + project context. Handle per `rules/stride-threat-model.md` §Info Disclosure.

## Common pitfalls

### Self-assessment always 5/5

Agent prompt doesn't explicitly value low scores → agent reports high confidence always → no signal. Mitigation: prompt framing. SFI's prompt: "Deliberately low scores (2, 3) are valued over inflated 5s."

### Outcome signal never arrives

PR is never merged; outcome evaluator never runs. Execution signal has no pair. Mitigation: have the evaluator run on PR-open too, with interim "unresolved" outcome; update when PR merges.

### run_id lost in middle layer

Execution signal has run_id; outcome signal lost it (some intermediate skill didn't propagate). Correlation broken. Mitigation: the run_id must propagate via every layer. Schema validation at each hop.

### Analysis-tools-never-built

Signals captured, stored, never queried. The pattern's value is in the aggregation. Mitigation: commit to building the analyzer early, even if simple.

## Interaction with other patterns

- **+ `wiki/patterns/run-id-correlation.md`** — correlation is the correlation-key pattern applied to signals.
- **+ `wiki/patterns/completion-report-protocol.md`** — Completion Reports naturally carry execution signals.
- **+ `wiki/patterns/multi-role-review.md`** — verdict IS a form of outcome signal.
- **+ `rules/stride-threat-model.md`** — signals are identifiable data; apply Info Disclosure rules.

## MAD.Council specifics

`/council-retro` per `mad.council.a2a.md` §9.4:

Execution signal:

```json
{
  "run_id": "<guid>",
  "channel": "es-training",
  "session_summary": {
    "what_worked": "Free-form prose",
    "what_was_hard": "Free-form prose",
    "improvisation_needed": true,
    "turns_taken": 47,
    "verdicts_required": 2,
    "a2a_bridges_used": 0
  },
  "scores": {
    "accuracy": 4,
    "completeness": 3,
    "tsg_alignment": 5,
    "dx": 4,
    "confidence": 3
  }
}
```

Outcome signal sources (where available):

- Council verdicts (explicit outcome: FIX / ACCEPT / ESCALATE / INVESTIGATE).
- PR quality evaluator (when thread produced a PR).
- User's acceptance / modification of proposed actions.

Correlation via `run_ids_involved` in the Completion Report + `run_id` in each verdict/message.

Storage:
- `<channel>/retros/<alias>-<ts>.json` locally.
- Optionally submitted to ALAS-compatible hub if configured.

## References

- `plugins/sfi-dev-toolkit/skills/remediation-review/SKILL.md` — execution signal canonical source.
- `plugins/sfi-dev-toolkit/skills/mise-v2-pr-quality-evaluator-skill/SKILL.md` — outcome signal canonical source.
- `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` §Step 9 — signal-capture protocol.
- `plugins/agent-native-toolkit/agents/content-quality-loop.md` — iterative signal variant.
- `mad.council.a2a.md` §9.4 — `/council-retro` spec.
- `wiki/patterns/run-id-correlation.md` — correlation primitive.
- `wiki/patterns/completion-report-protocol.md` — execution signal carrier.
- CHECKLIST cross-cutting pattern #6 — mandatory learning signal before session close.
- CHECKLIST pattern #39 — honest-low-score principle.
