# Pattern: Evidence Beats Assertion

**Canonical name:** Evidence Beats Assertion. Variants: *evidence-first review*, *cite or concede*, *file:line-or-OBSERVATION*, *grounded findings*.

**One-line definition:** Every finding, claim, or recommendation must cite specific evidence (file:line, section+quote, message-ID+quote). Findings without evidence are demoted to OBSERVATION — not actionable, regardless of the author's confidence.

## When to use

- Every multi-role review skill (`/council-review`, `plugins/adversarial-audit/`, `plugins/triage-team/`, `plugins/review-verdict/`).
- Any agent that produces actionable findings (not just commentary).
- Any documentation that describes system behavior — "the system does X" must be provable.
- Any security claim ("this code is safe because…" needs evidence of the safeness).

## When NOT to use

- **Exploratory brainstorming.** If the purpose is to surface hypotheses, evidence comes later. But flag that these are hypotheses, not findings.
- **Prose explanation of design intent.** A doc explaining "why we chose this approach" is narrative, not review; evidence standard still helps but isn't mandatory.
- **Speculative/forward-looking statements.** "This might cause issues at scale" is valid to raise; evidence burden shifts to whoever investigates next.

## Core mechanics

```
Finding A (with evidence):        ✅ retained at original severity
  severity: HIGH
  evidence: "src/handler.ts:42 — `return null` on parse error"
  description: "Silent-null on parse failure allows callers to deref"

Finding B (without evidence):     ⚠️ demoted to OBSERVATION
  severity: HIGH
  evidence: (none)
  description: "Error handling seems inconsistent"
  → Demoted: severity → OBSERVATION
  → Annotation: "No file:line cite; treat as observation, not actionable."
```

The demotion is automatic. The rule is mechanical. The author's confidence in the finding is irrelevant — no citation, no severity.

## Evidence shape requirements

Different contexts have different evidence shapes:

### For code findings

- `<file>:<line>` or `<file>:<line-range>` at minimum.
- Quoted snippet when space allows.
- Cross-references to similar sites (if pattern-level).

### For spec findings

- `<section-name>` + quoted phrase.
- Section hierarchy if nested (e.g., "§8.2 Dangerous Operations §Category table").

### For thread findings (MAD.Council /council-review)

- `<message-id>` + quoted phrase from body.
- Thread-level: thread_id + range of seqs.

### For system-behavior claims

- Trace path (data flow from input to observable output).
- Reproducible scenario (specific inputs that demonstrate the behavior).

### For "it should do X" style recommendations

- Cite precedent: either existing codebase pattern OR canonical reference (Anthropic docs, OWASP, etc.).
- If citing a missing pattern, that's a pattern-verification concern (see `wiki/patterns/yagni-filter.md`) — grep first.

## Canonical sources

### Marketplace: plugins/triage-team (verbatim wording)

> "Evidence beats assertion. Every claim needs specific references, quotes, cross-references."

All three roles (Advocate, Skeptic, Architect) enforce this rule. Findings without evidence are flagged and demoted.

### Marketplace: plugins/adversarial-audit

Prosecutor/Defender/Judge all enforce the rule. The Judge's verdict is conditional on evidence quality — FIX verdict requires at least one CRITICAL finding with file:line-backed evidence.

### Marketplace: plugins/review-verdict

Phase 4.0 classification rules explicitly require evidence before accepting a finding as `valid_actionable`:

```
VERIFY against the actual codebase — read the relevant code to confirm the claim.
```

### External: academic mock-court frameworks

CourtEval (arxiv 2508.02994), VulTrial (arxiv 2505.10961), RPA-Check (arxiv 2604.11655) all structure the debate around evidence exchange. The "judge" role weighs evidence, not arguments.

## Pros

- **Filters LLM hallucinations.** Without the rule, models produce plausible-sounding claims about code that doesn't exist. With it, every claim is checkable.
- **Auditable.** A reviewer reading a verdict can verify each finding by following the citation.
- **Reduces false-positive noise.** Reviews containing 50% unverifiable findings produce 0% actionable output; the rule concentrates attention on the actionable 50%.
- **Builds reviewer credibility.** Evidence-backed findings that are later confirmed increase trust in the reviewer; vague assertions that turn out wrong destroy it.
- **Catches fabrication early.** If a model cites `src/handler.ts:42` and line 42 doesn't exist, the citation is self-disqualifying — caught at grep time, not at production time.

## Cons

- **Slows down some legitimate findings.** A deeply held suspicion ("this feels wrong") can't easily be elevated without spending effort on tracing a path.
- **Enforces present-code-only findings.** Future-concern findings ("this will break at scale") don't have current-state evidence. Mitigate by allowing OBSERVATION-tier future concerns.
- **Citations can be faked.** A model that hallucinates `file:line` references passes the letter of the rule but not the spirit. Mitigate by verifying citations actually point at what's claimed.
- **Overhead on trivial findings.** Finding a typo shouldn't require full trace citation. Use severity to calibrate — LOW severity findings have proportionately lower evidence bars.

## Do / Don't

**Do**:

- **Require evidence in the output schema.** Every finding's JSON must have an `evidence` field; empty or null means demotion.
- **Verify cited evidence automatically.** After a role produces findings, grep for each cited path/symbol; demote if not found.
- **Cite across multiple sites for pattern-level findings.** "This duplication exists at A, B, C" is stronger than "duplication exists."
- **Mark derived assumptions explicitly.** "Based on the surrounding patterns, this appears intentional" is OK — just flag it as derived.
- **Use OBSERVATION as a valid outcome.** Don't force evidence where none exists; demote to OBSERVATION with clear note.
- **Quote the source.** Not just a file:line; the literal content being critiqued. Makes verification instant.
- **Concede with honesty.** If confronted with counter-evidence, withdraw the finding. Credibility requires knowing when to let go.

**Don't**:

- **Don't accept "I think" as evidence.** That's opinion; evidence is specific.
- **Don't accept vague locations.** "Somewhere in the handler" — no. "handler.ts:42" — yes.
- **Don't let confidence substitute for evidence.** A model 99%-confident without a citation is 99%-confident-and-wrong-about-knowing-without-citing.
- **Don't demote silently.** Always annotate why the finding was demoted so readers can distinguish "we looked and it's not a problem" from "we couldn't verify."
- **Don't double-count evidence.** Three findings citing the same file:line are one finding, not three; merge.
- **Don't require evidence for structural observations.** "This channel has 50 threads" is a count, not a claim — evidence would be recursive.

## Common pitfalls

### Hallucinated citations

Model produces a finding citing `src/utils/validator.ts:87` — that file doesn't exist, or line 87 is blank. Citation is fake.

Mitigation: post-generation verification step. Grep for each cited file+line; if missing, demote to OBSERVATION with annotation "citation could not be verified."

### "Evidence" that's just description

Finding reads: "evidence: the code silently fails without logging." That's a paraphrase, not a citation.

Mitigation: schema enforcement — evidence field must contain a file:line-like pattern or quoted phrase, not free-form description.

### Over-rigorous for trivial findings

LOW severity "typo on line 42" blocked from inclusion because not enough evidence. Overhead dominates.

Mitigation: evidence bar scales with severity. LOW: file:line suffices. CRITICAL: file:line + quoted phrase + traced path + scenario.

### Multi-site pattern findings demoted for wrong reason

"Duplication exists across handlers" — no specific file:line. Demoted.

Mitigation: require 2+ citations for pattern-level findings; show all citations; don't allow single-citation pattern claims.

## Interaction with other patterns

- **`wiki/patterns/multi-role-review.md`** — this rule is verbatim in triage-team / adversarial-audit / review-verdict; all three roles enforce it.
- **`wiki/patterns/yagni-filter.md`** — YAGNI's "grep for callers" is an evidence-verification check applied to Skeptic findings.
- **`rules/verification-protocol.md`** — the four rules (FETCH BEFORE CITE, READ BEFORE EDIT, MATCH EXISTING STYLE, ACTUAL BEFORE PRESENT) are engineering-side Evidence-Beats-Assertion.
- **`wiki/patterns/run-id-correlation.md`** — run_id provides the correlation key for cross-verifying claims across artifacts.

## MAD.Council specifics

Enforced in three places:

1. **`agents/advocate/agent.md` / `skeptic/agent.md` / `architect/agent.md`** — each role's output schema requires `evidence` field per finding. No evidence → demotion to OBSERVATION.

2. **`skills/council-review/plan.md`** — verdict-compute step does a post-generation verification pass. Findings without verified citations are marked in verdict.json with `demotion.filter: "evidence_missing"`.

3. **`rules/verification-protocol.md`** — the engineering-side mirror. "FETCH BEFORE CITE" is Evidence Beats Assertion for code authors.

## References

- `plugins/triage-team/agents/advocate.md` + `skeptic.md` + `architect.md` — canonical "Evidence beats assertion" source.
- `plugins/adversarial-audit/agents/judge.md` — enforcement at verdict time.
- `plugins/review-verdict/skills/review-verdict/references/phase-4.0-comments.md` — VERIFY step.
- `rules/verification-protocol.md` — engineering-side mirror.
- `wiki/patterns/multi-role-review.md` §5.3 Evidence standard.
- arxiv 2508.02994 (CourtEval) — academic framing of evidence-weighted verdicts.
- CHECKLIST pattern #8 (adversarial multi-role review) + §5.3 evidence rule.
