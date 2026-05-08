# Fixture: basic input for /apply-learnings (synthetic)

Synthetic input for the apply-learnings skill. The skill consumes captured patterns from `.mad/learning/` (knowledge candidates from long investigations, PR-comment patterns, validation outcomes) and proposes them as new skills, rules, or doc updates.

## Synthetic input artifact

Captured candidates in `.mad/learning/patterns.json`:
- 1 knowledge candidate from a 22-min code-investigator session on async-cancellation
- 3 PR-comment patterns extracted from recent reviews
- 1 validation outcome: "feature passed but coverage dropped — flag for test improvement"

User invocation: `/apply-learnings --knowledge` (review pending knowledge candidates).

## Skill invocation

```
/apply-learnings --knowledge
```

## Notes

This fixture exercises the smart-default flow (enumerate → propose → user-review). Other modes: `--patterns`, `--stats`, `--apply <id>`.
