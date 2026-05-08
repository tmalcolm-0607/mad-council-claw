# Pattern: Scope Discipline

**Canonical name:** Scope Discipline. Variants: *scope discipline*, *minimum change*, *anti-scope-creep*, *targeted task delegation*.

**One-line definition:** Every action matches the scope of what was asked — no more. A bug fix changes only what fixes the bug. An orchestrator does only what the user explicitly requested. Abstractions are delayed until they have three callers.

## When to use

- Every coding skill.
- Every orchestrator skill.
- Every content-generating skill that could expand scope implicitly.

In other words: everywhere.

## When NOT to use

- Never. Scope discipline is always applicable. The *strength* may vary, but the principle doesn't.

## Core mechanics

Three lenses to apply before every action:

### Lens 1 — Task scope

"Is this action solving the asked problem?"

If yes, proceed. If no, either add to a follow-up task or remove from the current diff.

### Lens 2 — Minimum change

"Could I solve this with fewer lines / fewer files?"

If yes, do that. A 3-line fix is better than a 30-line fix, even if the 30-line is "cleaner."

### Lens 3 — Orchestrator scope

"Is this the specific action the user asked for, or what I think should happen?"

Do the specific action. You may *suggest* follow-ups ("Would you like X too?") but the first action is the asked action.

## Canonical sources

### `rules/minimum-change.md` (MAD)

"The smallest change that fulfills the task. Nothing more."

- Don't add error handling for scenarios that can't happen.
- Don't add abstractions before three callers.
- Don't rename variables "while you're in there."
- Don't reorganize imports "to clean up."
- Don't add comments explaining what the code does.
- Don't add feature flags for hypothetical future work.

### `rules/orchestrator-identity.md` Rule 3 (MAD)

"Do what's asked, not what you think should happen."

From `plugins/zen-agents/agents/orchestrator.md` verbatim:

> If user asks to "create a design doc from Teams chat context" → Delegate ONLY to system-design-author. If user asks to "review this PR" → Delegate ONLY to peer-reviewer. You MAY suggest prerequisites, but ALWAYS execute the specific task asked for FIRST.

### `plugins/server-migration/skills/develop/SKILL.md` "MINIMUM CHANGE" rule

"Smallest change that fulfills the task."

### Project-level `CLAUDE.md`

> Don't add features, refactor, or introduce abstractions beyond what the task requires. A bug fix doesn't need surrounding cleanup; a one-shot operation doesn't need a helper. Don't design for hypothetical future requirements. Three similar lines is better than a premature abstraction.

## Pros

- **Shorter diffs.** Easier review, less risk of breakage.
- **Clearer intent.** The change matches the description, no "and also…" surprises.
- **Preserves future flexibility.** Premature abstractions constrain future code; minimum change doesn't.
- **Reduces cognitive load.** Reviewers see one thing changing, not five.
- **Faster to ship.** Small diffs merge faster.
- **Fewer regressions.** Every extra line is potential breakage.
- **Aligns with Council review.** Smaller diffs get simpler reviews.

## Cons

- **Tempting to "just clean up" related issues.** Sometimes the adjacent code is genuinely bad; deferring feels wrong.
- **Can leave known issues.** If you spot a bug while fixing another, strict scope discipline says "file it, don't fix it here."
- **Discipline takes effort.** LLMs (and humans) naturally expand scope. Holding the line requires active effort.
- **Can look "lazy."** A reviewer seeing "you didn't fix the obvious adjacent issue" may push back.

## Do / Don't

**Do**:

- **State the task explicitly before starting.** "The task is X. Anything else is out of scope for this diff."
- **Read surrounding code (per `verification-protocol.md` Rule 2).** Understanding context doesn't mean changing it.
- **File follow-up tasks.** If you find an adjacent issue, log it — don't fix it in this diff.
- **Before saving, audit the diff.** "Does this touch anything not named in the task? If yes, move or remove."
- **Before committing, minimize.** "Could I have done this in fewer lines?" If yes, shrink.
- **Suggest, don't do.** Orchestrators can suggest follow-ups; they don't execute without explicit user ask.
- **Invoke the specific specialist.** Don't generalize delegation ("review the repo") when the user asked for specific action ("review PR #N").
- **Defer abstractions.** Three similar lines > one clever abstraction on day-1.

**Don't**:

- **Don't refactor "while you're in there."** Refactors are their own task.
- **Don't rename during a bug fix.** Rename is a different diff.
- **Don't add error handling for scenarios that can't happen.** Trust internal code.
- **Don't add validation for internal boundaries.** Validate at system boundaries (user input, external APIs).
- **Don't create abstractions before callers exist.**
- **Don't add feature flags for hypothetical futures.**
- **Don't generate full-SDLC when one step was requested.**

## Common pitfalls

### "Fix the bug and clean up the function"

Task: "fix the null deref on line 42." Diff: 150 lines of function restructuring. Reviewer: "why?" You: "it was ugly."

Fix: fix the null deref in 5 lines. File a follow-up for restructuring. Let the reviewer decide.

### "Improve error handling while fixing this bug"

Task: "fix the off-by-one in the loop." Diff: loop fix + 3 new try/catch blocks.

Fix: fix the off-by-one. Error handling is a separate concern. If missing error handling is a real issue, that's its own task.

### "Extract a helper for readability"

Task: "add a new field to the response." Diff: new field + 4 extracted helpers because the function felt long.

Fix: add the field. Inline code is fine. Extract helpers when they have multiple callers.

### "Bring this file up to our standards"

Task: anything. Diff: unrelated style changes throughout the file.

Fix: targeted change. Style modernization is a project-level effort, not smuggled into unrelated diffs.

### Orchestrator over-reach

User: "create a design doc from this Teams chat." Orchestrator: creates PRD + design + tasks + implementation plan + CI pipeline.

Fix: create the design doc. Offer follow-ups if relevant, but don't execute unsolicited.

## Interaction with other patterns

- **+ `rules/minimum-change.md`** — policy this pattern operationalizes.
- **+ `rules/orchestrator-identity.md`** Rule 3 — "do what's asked."
- **+ `rules/verification-protocol.md`** — READ BEFORE EDIT ≠ CHANGE BEFORE READ. You read context; you don't modify it.
- **+ `wiki/patterns/yagni-filter.md`** — reviewer side: demotes speculative "add X" findings with no callers.
- **+ `wiki/patterns/multi-role-review.md`** — Council review catches scope-creep in diffs.
- **+ `wiki/anti-patterns.md`** §20-22 — concrete scope-creep anti-patterns.

## MAD.Council specifics

Enforced in two places:

1. **`rules/minimum-change.md`** — every MAD.Council skill inherits the rule.
2. **`/council-review`** — Architect role catches scope-creep in code diffs; findings land with evidence refs.

Also applies to MAD.Council's own implementation:

- When adding a feature to a skill, only change that skill. Don't touch unrelated skills.
- When fixing a bug in `concurrency-safety.md`, don't also restructure `prompt-injection-policy.md`.
- When writing a SKILL.md, don't include sections the spec doesn't require.

The scope discipline applies recursively — MAD.Council **is** a tool for disciplined agent coordination; its own code should exemplify the discipline.

## References

- `rules/minimum-change.md` — MAD rule.
- `rules/orchestrator-identity.md` — Rule 3 sibling.
- `plugins/zen-agents/agents/orchestrator.md` — "Do What's Asked" origin.
- `plugins/server-migration/skills/develop/SKILL.md` — "MINIMUM CHANGE" origin.
- Project `CLAUDE.md` — root-level statement.
- `wiki/anti-patterns.md` §20 (refactor creep), §21 (defensive programming bloat), §22 (premature abstraction).
- Extreme Programming's YAGNI principle — https://martinfowler.com/bliki/Yagni.html
- CHECKLIST pattern #30 — "Do what's asked" orchestrator anti-bloat rule.
- CHECKLIST pattern #100 — MINIMUM CHANGE coder rule.
