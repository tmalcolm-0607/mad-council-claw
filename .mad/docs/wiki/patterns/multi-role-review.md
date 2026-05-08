# Pattern: Multi-Role Review (Council)

**Canonical name:** Multi-Role Review. Variants: *adversarial audit*, *mock-court*, *triage team*, *critic ensemble*, *debate-style evaluation*.

**One-line definition:** N distinct-perspective reviewers analyze the same artifact; their findings are aggregated under a shared severity rubric; a binding verdict is emitted.

## When to use

- The work product is consequential (code merge, design change, security decision, spec update).
- Single-reviewer review has known blind spots — defenders miss their own biases, attackers miss context, generalists miss architecture.
- You want reviewer accountability ("Skeptic found X") rather than opaque "the reviewer said…".
- False negatives are more costly than the extra review latency.

Published research validates this pattern at +10% to +90% accuracy gains over single-reviewer baselines:
- **CourtEval** (arxiv 2508.02994): 3-role Grader/Critic/Defender for LLM evaluation.
- **VulTrial** (arxiv 2505.10961): 4-role mock-court (security-researcher/code-author/moderator/review-board) for code vulnerability detection.
- **RPA-Check LLM Court** (arxiv 2604.11655): role-playing courtroom simulation.
- **The Star Chamber** (Mozilla.ai, 2026): multi-LLM consensus fan-out implementation for Claude Code.

## When NOT to use

- **Trivial reviews** — typo fixes, dependency bumps. Overhead dominates.
- **Time-sensitive ops** — incident response, live debugging. Defer to single reviewer + post-hoc retro.
- **Highly specialized domains** — if only one agent has the expertise, the other "roles" hallucinate.

## Core mechanics

```
Artifact under review
         ↓
  ┌──────┴──────┬────────────┬──────────────┐
  ↓             ↓            ↓              ↓
Advocate     Skeptic      Architect     [optional ensemble]
(defend)    (attack)     (zoom out)
  ↓             ↓            ↓              ↓
  └──────┬──────┴────────────┴──────────────┘
         ↓
   YAGNI + pattern-verification filters
         ↓
   Aggregate findings (severity rubric)
         ↓
   Compute verdict (binding: FIX/ACCEPT/ESCALATE/INVESTIGATE)
```

## Role primitives

Two naming conventions are both well-established. Pick based on framing.

### Construct-focused (recommended default)

| Role | Mindset | What they produce |
|---|---|---|
| **Advocate** | Author's proxy. Reconstruct intent from evidence. Defend choices. Flag uncertainties the author had. | Narrative + defended choices + uncertainties. |
| **Skeptic** | Attacker. Assume ≥1 flaw exists; find it. Runtime behavior > style. Go deep, not shallow. | Enumerated flaws with concrete scenarios + traced paths + file:line. |
| **Architect** | Principal engineer. Zoom out. Patterns, coupling, direction, maintainability. Single-source-of-truth guardian. | Pattern-level findings with trade-off analysis. |

Source: `plugins/triage-team/agents/advocate.md`, `skeptic.md`, `architect.md`.

### Court-metaphor (for security audits)

| Construct-focused | Court-metaphor |
|---|---|
| Advocate | Defender / Defense Attorney |
| Skeptic | Prosecutor |
| Architect | Judge / Moderator |

Cosmetic alias — mindsets are identical. Security contexts often prefer the court framing because the "binding verdict" concept transfers naturally.

Source: `plugins/adversarial-audit/agents/prosecutor.md`, `defender.md`, `judge.md`.

### Role count variants

- **3-role** (default, most common): Advocate/Skeptic/Architect.
- **2-role** (maker-checker): generator + critic. Simpler; used in AutoGen's maker-checker pattern.
- **4-role** (VulTrial-style): adds a "review board" or "jury" for tie-breaking.
- **N-role ensemble**: duplicate one role (typically Skeptic) across N models for consensus. See `wiki/patterns/multi-model-ensemble.md`.

3-role is the sweet spot: enough perspectives to cover blind spots, not so many that coordination dominates.

## Evidence standard

From `plugins/triage-team/`, verbatim: **"Evidence beats assertion."**

Every finding must include:
- **Specific references**: file:line for code; section + quoted phrase for specs.
- **Quotes** from comments, descriptions, or prior discussion.
- **Cross-references** to similar patterns elsewhere.
- **Explicit assumption marking**: "Based on the surrounding patterns, this appears intentional because…" rather than stated as fact.

Findings without evidence are **demoted to OBSERVATION** (not actionable) regardless of author confidence. This filter is the single highest-leverage rule in the pattern — it's what prevents "the model thought it saw a bug" from landing as a real finding.

## Severity rubric (shared across roles)

| Severity | Litmus test |
|---|---|
| **CRITICAL** | Real-world attack or data-loss scenario with low attacker cost. Must fix before any deployment. |
| **HIGH** | Plausible failure mode that corrupts state, loses data, or exposes information. Must fix before v1.1. |
| **MEDIUM** | Correctness issue that degrades UX/reliability but doesn't corrupt/expose. Fix if cheap. |
| **LOW** | Nit, cosmetic, theoretical. Log for completeness. |

The rubric is **shared** — Advocate, Skeptic, and Architect all use the same labels. This enables aggregation.

## Verdict types (binding)

| Verdict | Trigger | Consequence |
|---|---|---|
| **FIX** | ≥1 CRITICAL or ≥3 HIGH findings | Work cannot proceed. Remediation thread required. |
| **ACCEPT** | No blocking findings | Work approved. MEDIUM/LOW items logged. |
| **ESCALATE** | Council cannot reach consensus OR a finding is outside its expertise | Routes to human reviewer. |
| **INVESTIGATE** | Findings suggest a problem but evidence is incomplete | Requests additional research (Phase-0 in MAD terms). |

Verdicts are **binding** — a FIX cannot be dismissed without producing a counter-finding through another round of review.

Source: `plugins/adversarial-audit/agents/judge.md`.

## Common implementations

### Marketplace: plugins/adversarial-audit

Full prosecutor/defender/judge loop. Judge verifies evidence line-by-line before rendering verdict. All three roles share the same severity rubric with explicit litmus tests.

- **Pros**: Strong isolation between roles; explicit binding verdicts; evidence-first culture.
- **Cons**: Court metaphor can feel heavy for routine reviews.

### Marketplace: plugins/triage-team

Construct-focused Advocate/Skeptic/Architect. Same evidence-first rules, different naming.

- **Pros**: Naming reduces courtroom-metaphor friction. Useful as default.
- **Cons**: Synthesis step is implied, not named — you need a 4th step to aggregate.

### Marketplace: plugins/review-verdict

The most elaborate implementation. Phase 4 "Fix Mode" runs ~20-24 agents per iteration:
- **Review Response Ensemble** (Phase 4.0): 3-model ensemble + validator classifies existing PR comments.
- **Fix Planning Ensemble** (4.1): 3-model parallel plans.
- **Fix Implementation** (4.2): up to 8 parallel dimension specialists (10 for C++).
- **Self-Review Ensemble** (4.3): 3-model + validator, 4-5 quality facets.
- **Verification Pipeline** (4.4): build/test/lint + multi-agent error analysis.
- **Iterative Re-Analysis** (4.5): incremental re-analysis of fix-touched files.

- **Pros**: Industrial-strength; mode-aware (`auto` vs `propose`); spoofing-protected dedup.
- **Cons**: Token-expensive; justified only for high-consequence reviews.

### External: CourtEval (academic)

3-agent evaluation: Grader (Judge) + Critic (Prosecutor) + Defender (Defense Attorney). Grader scores → Critic challenges → Defender counters → Grader re-scores.

### External: VulTrial (academic)

Code vulnerability detection via mock-court: security researcher (prosecutor) + code author (defense) + moderator (judge) + review board (jury). 4-role variant with tie-breaking.

### External: Mozilla "Star Chamber"

Claude Code skill fanning code reviews to multiple LLM providers in parallel, aggregating consensus. Independent re-implementation of `plugins/review-verdict/` Phase 4 pattern — validates the pattern as industry-canonical.

## Pros

- **Coverage**: 3 perspectives catch what 1 misses. Measured +10% gain (arxiv 2511.17621); +6.7% (CourtEval).
- **Accountability**: Findings attributed to a role. "Skeptic found X" is actionable.
- **Binding verdicts**: Automatable. A FIX verdict can gate a merge; an ACCEPT can auto-approve.
- **Evidence culture**: The file:line-or-demote rule is a permanent quality filter.
- **Blind-spot mitigation**: Advocate catches Skeptic's over-reach; Architect catches both roles' narrow focus.

## Cons

- **Token cost**: 3x single-review (or 3x ensemble = 9x) for each review round.
- **Latency**: Parallel workers help, but synthesis still serializes.
- **Role collapse**: If model is weak, all 3 roles may produce similar findings — "they agree" isn't signal, they were all one model.
- **False-positive amplification**: A Skeptic with hair-trigger sensitivity generates findings that cascade. Mitigated by YAGNI + pattern-verification passes.
- **Verdict disputes**: A FIX verdict may be "wrong" — the author may have context the Council lacked. ESCALATE is the mitigation.

## Do / Don't

**Do**:

- **Separate model instances per role**: if the same model plays all 3 roles in sequence, you lose the isolation benefit. Either parallel calls or explicit context reset between roles.
- **Run YAGNI and pattern-verification filters**: before accepting a Skeptic "add feature X" finding, grep for callers. Before flagging a deviation, check if the deviation is actually an improvement. See `wiki/patterns/yagni-filter.md`.
- **Mode-aware sizing**: `auto` / CI mode uses 3-model ensemble (no curator to filter); `propose` / interactive mode uses single model per role (user filters). See `wiki/patterns/mode-aware-sizing.md`.
- **Cap findings**: max 10-12 per role. If a role emits 30 findings, the signal-to-noise is wrong.
- **Require file:line on every finding**: no exceptions. Demote findings without refs to OBSERVATION.
- **Share the severity rubric**: all roles use the same 4 labels with the same litmus tests.
- **Make verdicts binding**: if a FIX can be ignored, the pattern becomes decorative.

**Don't**:

- **Don't merge roles into one super-reviewer**: you lose the whole point. "Single agent with a checklist" is not the same pattern.
- **Don't let roles see each other's findings during their pass**: parallel isolation is essential. Aggregate after, not during.
- **Don't skip the synthesis step**: raw finding lists are not a verdict. Something must emit the binding label.
- **Don't re-litigate verdicts informally**: if a FIX is disputed, run another review with ESCALATE or run with different roles. Don't override in chat.
- **Don't use this pattern for trivial changes**: typo fixes, dependency bumps. The overhead dominates.

## Interaction with other patterns

- **+ `orchestrator-worker.md`**: Multi-Role Review IS an orchestrator-worker pattern. The review driver is the orchestrator; roles are the workers.
- **+ `run-id-correlation.md`**: All 3 role findings inherit the same `run_id` as the thread under review — enables post-hoc attribution.
- **+ `completion-report-protocol.md`**: Each role produces a mini Completion Report; synthesizer merges.
- **+ `multi-model-ensemble.md`**: The Skeptic role is often ensemble-replicated across models for consensus.
- **+ `yagni-filter.md`**: Applied between role outputs and verdict computation.

## MAD.Council specifics

- `/council-review <thread-id>` runs the 3 roles in parallel.
- `--alias-set court` / `--alias-set construct` picks naming.
- `--ensemble` adds multi-model Skeptic replication.
- Verdict lands in `threads/<thread-id>/verdict.json`.
- `/council-verdict` allows manual override (use sparingly; requires rationale).
- Verdict is posted as a `resolve` message to the thread — the thread lifecycle respects the verdict.

## References

- `plugins/adversarial-audit/agents/` — court-metaphor source.
- `plugins/triage-team/agents/` — construct-focused source.
- `plugins/review-verdict/skills/review-verdict/` — industrial-scale implementation.
- `plugins/ai-security-pack/agents/critic.md` — alternate single-critic variant with pattern-verification pass.
- arxiv 2508.02994 (CourtEval)
- arxiv 2505.10961 (VulTrial)
- arxiv 2604.11655 (RPA-Check)
- Mozilla.ai "The Star Chamber" blog
- `mad.council.a2a.md` §5 — the spec section this pattern implements.
- CHECKLIST patterns #8 (adversarial), #28 (construct-focused naming), #42 (spoofing-protected dedup), #43 (mode-aware ensemble).
