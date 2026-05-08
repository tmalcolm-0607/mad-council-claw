# Self-Connect Section Template

Generic shape for a self-Connect Results / Impact section. Replace `{PLACEHOLDER}` text with concrete content from the user's WorkIQ harvest + voice profile.

## Hard rule: every paragraph follows "Did X, resulting in Y"

A bullet that names what was done without naming the measurable or qualitative outcome is incomplete. Every section must surface impact, not just activity.

```
✅ "Refactored {SUBSYSTEM} cert-rotation pipeline to use {NEW_PATTERN}, resulting in {METRIC: e.g. zero cert-related incidents over 8 weeks vs 3 in prior 8}."

❌ "Worked on cert-rotation pipeline."
```

## Section template

```markdown
### {WORKSTREAM_TITLE}

{Lead sentence: what the workstream is, who it serves, what scope you owned.}

{Did X → Y bullet 1}: {decision or artifact you authored}, resulting in {measurable or qualitative outcome}.

{Did X → Y bullet 2}: {decision or artifact you authored}, resulting in {measurable or qualitative outcome}.

{Did X → Y bullet 3}: {decision or artifact you authored}, resulting in {measurable or qualitative outcome}.

Collaboration: {peer 1}, {peer 2}, {peer 3}.
```

## Notes on the "Collaboration" line

- This used to be labeled "Contributors". The user prefers "Collaboration" because it signals two-way value (you used their input AND provided value back to them). Use "Collaboration" by default.
- List peers who contributed to OR consumed the impact of this workstream. Not every cc.
- Keep it factual; the peer-feedback section is where you talk about the relationship.

## Character limits (MS Connect form)

| Field | Limit |
|---|---|
| Results (full Part 1) | 6000 chars |
| Reflect on setbacks | 1000 chars |
| How will your actions help your goals | 1000 chars |

Run the validator script before posting:
```
pwsh .claude/skills/lens-engineering-craftsmanship/scripts/connect-validate.ps1 -InputFile <draft.md>
```

## Anti-patterns (lint will flag)

- Activity without outcome ("worked on X", "drove Y", "owned Z" with no resulting metric or quality statement)
- Outside-perspective citations ("manager noted that I...", "peer review said..."). Manager handles those via Feedback.
- PR numbers in prose (genericize: "the cross-team identifier-hashing PR" not "PR #5042222")
- Em-dashes (—). Use periods or commas.
- AI-slop phrases (see profile.banned_phrases)
