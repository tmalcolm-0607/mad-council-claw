---
title: Rule — Loop-stop language discipline
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — Loop-stop language discipline

While a loop is mid-execution (mechanical stop conditions have not yet exited 0), the orchestrator MUST NOT use closing-bow language ("final state", "loop complete", "all done", "session complete"). Every session-mid checkpoint surfaces the NEXT iter's priors; closing-bow language is reserved for actual loop completion.

**Source:** session 6ac2f083 (2026-05-02). User explicitly enforced: "not final state? your continuously running the loop correct?" The orchestrator had been wrapping iter checkpoints with closing-bow language despite stop conditions not being met. Combined with `autonomous-loop-discipline.md` and `scope-discipline.md`, the discipline is: every iteration ends by surfacing the NEXT iteration's work, never by closing the topic.

## Forbidden phrasings (mid-loop)

| Forbidden | Why it fails |
|---|---|
| "Final state" | Implies loop is complete when it isn't |
| "Final clean state" | Same |
| "Loop complete" | Same |
| "Session complete" | Confuses "session ending" with "loop ending" |
| "Done" | Ambiguous; reads as terminal |
| "All set" | Same |
| "Wrapping up" | Implies the work itself is wrapping when it isn't |
| "Mission accomplished" | Closing-bow class |
| Any closing-bow language that implies finished work | Misrepresents the loop's continuing state |

## Required phrasings (mid-loop)

| Phrasing | When |
|---|---|
| "iter N checkpoint" | After committing an iter's deliverables; surface iter N+1 next |
| "iter N deliverables landed; iter N+1 priors:" | When transitioning between iters within session |
| "Working tree clean at iter N; next move:" | After cleanup; about to spawn next iter's work |
| "Mid-loop pause point" | Only when handing off cross-session (e.g., HALT threshold reached) |
| "Blocked on user judgment for X; otherwise iter N+1 next" | Genuine blocking ambiguity |

## When closing-bow language IS appropriate

ONLY when:
1. `Check-LoopStopConditions.ps1` (or equivalent mechanical predicate) exits 0 across all required phases.
2. AND the user explicitly accepts the completion.

Both conditions must hold. Either alone is insufficient — mechanical exit-0 without user acceptance still means the loop is paused at a checkpoint, not complete.

## How to apply

- After committing iter N's batch + retro: immediately surface iter N+1's audit lanes or implementation work in your reply.
- If genuinely paused (waiting for user input on a high-confidence question), say "blocked on user judgment for X; otherwise iter N+1 next" — NOT "complete".
- Closing bows belong only when stop conditions exit 0 AND the user explicitly accepts.
- The asymmetry in `autonomous-loop-discipline.md` reinforces this: the loop continues without asking permission; closing-bow language is a different KIND of pause-and-ask (assumes user will sign off) and is forbidden mid-loop.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| End an iter checkpoint with "We're all set!" | Suggests the loop is done | "iter N checkpoint; iter N+1 lanes:" + list |
| "Loop complete." while progress.json shows phases not done | Lies about state | "iter N done; mechanical conditions: X/6 phases pass; next: phase Y" |
| Open the next iter with "Final summary of last iter:" | "Final" is the closing-bow word; misframes a mid-loop summary | "Iter N summary:" |
| Close a session at HALT threshold with "Done!" | The loop is paused, not done | "Mid-loop pause point at HALT; resume with /resume-handoff" |

## Related

- `.claude/rules/autonomous-loop-discipline.md` — companion: loop continues without asking permission
- `.claude/rules/scope-discipline.md` — every iter ends by surfacing the next iter's work, not by closing the topic
- `.claude/rules/no-silent-deferrals.md` — closing language is a soft form of "deferring everything else to never"
- `.claude/rules/context-guardian.md` — HALT threshold is a legitimate cross-session pause; uses "Mid-loop pause point" phrasing
- `CLAUDE.md` § Stop-condition discipline — operator-facing summary that cites this rule
