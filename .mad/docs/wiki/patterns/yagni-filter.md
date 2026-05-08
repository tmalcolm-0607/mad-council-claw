# Pattern: YAGNI Filter

**Canonical name:** YAGNI Filter. Variants: *YAGNI check*, *callers-grep filter*, *hypothetical-feature demoter*.

**One-line definition:** Before accepting a reviewer finding that proposes adding a feature or abstraction, grep the codebase/spec for actual callers. If nothing references the hypothetical feature, demote the finding to LOW with an explanatory note.

**"YAGNI" =** "You Aren't Gonna Need It" — a software-engineering principle that abstractions shouldn't be built before their users exist.

## When to use

- Multi-role review (`wiki/patterns/multi-role-review.md`) — Skeptic role often produces "add X for robustness" findings. YAGNI filter demotes the noise.
- Automated review comment processing — filters "add unit test for case Z" when case Z has no production path.
- Code review on PRs from junior engineers — catches "let me improve this while I'm here" speculative additions.

## When NOT to use

- Security findings — "you should add input validation here" is usually correct even without known exploit. Don't filter security away.
- Documentation findings — missing doc on a public API is a real issue regardless of internal callers.
- Spec reviews on systems being designed (no code to grep yet). The filter needs something to grep.

## Core mechanics

```
Finding from Skeptic: "Add method processBatch(items) for better batching."
      ↓
YAGNI check:
  grep for callers of hypothetical processBatch()
      ↓
  0 callers → demote finding to LOW with note:
    "YAGNI — not called anywhere; propose revisiting if a caller appears."
  ≥1 caller → retain finding at original severity
```

The filter runs **between** individual findings and the aggregate verdict. It does not discard findings — it demotes them and annotates the reason.

## Canonical implementation

From `plugins/review-verdict/skills/review-verdict/references/phase-4.0-comments.md` (Phase 4.0 Review Response Ensemble):

Each evaluator runs these steps on each review comment:

```
1. READ the comment without reacting.
2. VERIFY against the actual codebase.
3. EVALUATE — Is this technically correct for this specific codebase?
4. YAGNI CHECK — If the reviewer suggests adding a feature, endpoint, or abstraction:
   search the codebase to check if anything actually uses or would use it.
   If nothing calls it, note: "YAGNI — not called anywhere in the codebase."
5. CLASSIFY:
  - valid_actionable
  - valid_low_priority
  - incorrect
```

The YAGNI check is step 4 — it runs after the "is this technically correct?" step and before classification. Findings that are technically correct but address hypothetical needs get classified `valid_low_priority` instead of `valid_actionable`.

## Pros

- **Reduces false-positive noise.** Ensemble reviews can produce dozens of "consider adding…" suggestions; YAGNI trims to the ones that matter.
- **Grounded in evidence.** The "nobody calls this" reason is concrete and checkable.
- **Preserves the finding.** Demotion, not deletion. If a caller appears later, the note says "propose revisiting."
- **Cheap.** A grep is fast and cheap.
- **Transparent.** The reason is in the demotion note; reviewers can second-guess.
- **Aligns with `rules/minimum-change.md`.** If you wouldn't write the feature, you wouldn't flag its absence as blocking.

## Cons

- **False negatives on legitimate abstraction needs.** Sometimes you should build X before Y calls it (e.g., exposing an API for external consumers not yet in the codebase).
- **Depends on codebase-wide grep.** If the callers live in another repo you can't search, the check is unreliable.
- **Tempts over-demotion.** Reviewers may demote anything that "looks" speculative without verifying.
- **Doesn't help with quality issues.** "This function has bad naming" isn't a YAGNI case.

## Do / Don't

**Do**:

- **Run the grep.** The filter is worthless if the check is skipped.
- **Include the grep output in the demotion note.** "YAGNI — searched for `processBatch` in src/, 0 hits."
- **Demote, don't delete.** The finding may become actionable later.
- **Annotate the demotion reason.** Three-liner: what was suggested, what was checked, why demoted.
- **Run YAGNI before classification.** Order matters — classify after the YAGNI pass, not before.
- **Skip YAGNI for security findings.** Input validation for code paths that don't exist yet is still correct.

**Don't**:

- **Don't use YAGNI to dismiss valid observations.** If Skeptic says "this function has no tests," grep for tests; absence of tests isn't a YAGNI demotion, it's a real finding.
- **Don't demote without evidence.** "Seems hypothetical" isn't a reason; "0 callers found" is.
- **Don't apply to cross-repo situations you can't see.** If the caller might live in another repo, note that and retain the finding.
- **Don't skip YAGNI because the Skeptic sounds confident.** High-confidence hypothetical findings are the most likely to waste developer time.

## Common pitfalls

### Grep for wrong symbol

Skeptic says "add a `handleRetry` method." You grep for "`handleRetry`" — 0 hits, demote. But the actual usage is in a dynamic lookup (`methods[key]()`). You've demoted a real need.

Mitigation: for dynamic-lookup patterns, broaden the grep or retain finding with "verification uncertain" note.

### Cross-language/cross-repo blindness

Skeptic in a Python codebase says "add an IDL type for the gateway API." You grep Python — 0 hits. The callers are in a Go service next door that you don't have access to.

Mitigation: when external-caller possibility is known, note it and retain.

### YAGNI on documentation

Skeptic says "document the `processBatch` function." You grep — there's no function. But the finding is about a documentation gap in the spec that does reference a `processBatch` pattern.

Mitigation: YAGNI applies to code findings, not documentation findings. Distinguish.

### Over-eager demotion

Reviewer runs YAGNI filter aggressively, demoting anything forward-looking. Result: the review loses useful architectural suggestions.

Mitigation: YAGNI is for hypothetical features ("add X"); it's not for architectural observations ("this coupling is going to bite us").

## Interaction with other patterns

- **+ `wiki/patterns/multi-role-review.md`** — applied after role outputs, before verdict computation. Canonical placement in review-verdict Phase 4.0.
- **+ `rules/minimum-change.md`** — same principle: don't build for hypothetical needs.
- **+ `rules/verification-protocol.md`** Rule 1 (FETCH BEFORE CITE) — the grep itself is a verification; don't demote without running it.

## MAD.Council specifics

Applied in `/council-review` per `mad.council.a2a.md` §5.7. Skeptic findings pass through YAGNI + pattern-verification before verdict computation. Demoted findings carry the YAGNI note and are surfaced as LOW (not omitted) in the final verdict report.

Example annotation in verdict.json:

```json
{
  "id": "skeptic-finding-03",
  "original_severity": "MEDIUM",
  "demotion": {
    "filter": "YAGNI",
    "reason": "Searched src/ for `processBatch` — 0 hits; no callers would use the proposed abstraction.",
    "demoted_to": "LOW"
  },
  "title": "Consider adding processBatch method for batch handling"
}
```

## References

- `plugins/review-verdict/skills/review-verdict/references/phase-4-fix-mode.md` §Phase 4.0 — canonical implementation.
- `plugins/ai-security-pack/agents/critic.md` §Pattern Verification — complementary filter ("deviation may be improvement").
- `rules/minimum-change.md` — same principle at rule level.
- `mad.council.a2a.md` §5.7 — Council layer integration.
- CHECKLIST pattern #90 — pattern-verification pass.
- The YAGNI principle (Extreme Programming, Martin Fowler) — https://martinfowler.com/bliki/Yagni.html
