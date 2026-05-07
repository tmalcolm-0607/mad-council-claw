---
title: Rule — No invented constraints
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — No invented constraints

The orchestrator MUST NOT invent budgets, caps, limits, quotas, deadlines, headcount, or other constraints that the user has not explicitly set. Decisions like "should we run iter N+1?" or "spawn 4 investigators or 2?" must be based on the actual decomposability of the topic, not on a hallucinated constraint.

**Source:** session 249a59a7 (2026-05-02). The orchestrator inserted a "5M-token soft cap" as a default assumption in iter 1's audit and propagated it through every subsequent iter summary as "Loop budget: ~XM used / ~YM remaining." The user asked "where did you pull the 2M budget? limit? we do not have a budget or limit." This was real friction — the orchestrator was framing decisions around a constraint that didn't exist.

## Rule statement

Do NOT invent or assume constraints. If the user has not explicitly set a budget, cap, limit, quota, deadline, or headcount, the orchestrator must NOT:

- Display "tokens used / remaining", "$ spent / remaining", or "time used / remaining" lines in iter summaries
- Gate decisions on the imaginary constraint
- Frame the constraint in user-facing prose ("we have ~2M tokens left for this work")
- Propagate the imaginary constraint to subagent prompts

This applies to ALL classes of unset constraint:

| Class | Examples |
|---|---|
| Token budget | "5M tokens", "soft cap of 100K per iter" |
| Cost budget | "$50/week", "stay under $100" |
| Time budget | "2 hours total", "should finish by EOD" |
| Headcount | "use 3 subagents max", "stay under 10 concurrent" |
| Quota | "10 PR reviews per day", "spawn limit per session" |
| Deadline | "ship by Friday" |

## How to apply

- Iter summaries report what landed and what's next. NO budget framing unless the user has set one.
- "Spawn 4 investigators or 2?" → answer based on the topic's actual decomposability (≥4 disjoint lanes? then 4; ≥3? then 3; etc.), NOT on a budget hypothesis.
- "Should we run iter N+1?" → answer based on stop conditions per `Check-LoopStopConditions.ps1`, NOT on "we have ~$X budget left."
- If a constraint becomes real (the user explicitly sets one — "don't burn more than $X this week"), track it then. Until then, no budget framing.
- Constraints INSIDE a product being built (e.g., a service's own rate-limiter, a Cosmos DB RU/s budget the service enforces) are PRODUCT FEATURES, not orchestrator-imposed loop constraints. They follow product spec; this rule does not constrain them.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| "Loop budget: ~2M tokens used / ~3M remaining" in every iter summary | Hallucinated constraint; user didn't set it | Remove the line |
| "Stop after iter 10 to stay under budget" | Same | Stop on mechanical conditions per `Check-LoopStopConditions.ps1` |
| "Use 2 investigators instead of 4 to save tokens" | Decomposition-based decision now hijacked by imaginary cost | Pick by topic decomposability per `agent-teams.md` |
| Inserting a soft-cap into a hook or script "as a sensible default" | Bakes the hallucination into infrastructure | Don't bake; if a cap is needed, the user sets it explicitly |

## Edge case: when the user DOES set a constraint

If the user explicitly says "don't burn more than $50 this week" or "we have a 4-hour budget for this":

- Track it explicitly. Document in CLAUDE.md or a per-work-item state file.
- Display the constraint + remaining-margin in summaries.
- Gate decisions on it appropriately.
- This is the expected pattern when a constraint IS real — distinct from inventing one when it isn't.

## Related

- `.claude/rules/skill-standards.md` § Dimension 2 — anti-hallucination discipline
- `.claude/rules/scope-discipline.md` — "every item classify and act" — same family of rules against silent dropping/adding
- `.claude/rules/autonomous-loop-discipline.md` — what to ask vs not ask; budgets are not a reason to stop unless explicitly set
- `CLAUDE.md` § Skill-invocation timing metrics — the legitimate metrics framework that records WHAT happened (durations, tokens) but doesn't gate on imaginary budgets
