---
title: Rule — Autonomous-loop continuation discipline
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — Autonomous-loop continuation discipline

When operating in `/loop` dynamic mode or any kit-defined autonomous-loop pattern (Self-Improvement Loop Protocol, MAD pipeline orchestration, etc.), the orchestrator MUST continue iterating without pausing to ask permission between iterations.

**Source:** session 6ac2f083 (2026-05-02). User correction after multiple iterations ended with "Want me to (a) tag, (b) branch, (c) stop?" framing instead of immediately spawning the next iter's audit. The autonomous-loop pattern in `CLAUDE.md` § Self-Improvement Loop Protocol defines per-iteration steps; the next step after "implementation done + integrated" is **iter+1 AUDIT**, not "stop and ask."

## Rule statement

The loop's job IS to continue. Surface the next iteration's work; don't poll for permission to do the work the loop is defined to do.

## Continue without prompting when

- An iteration's deliverables are complete (commits landed, council verdicts written, integration done).
- Stop conditions per `Check-LoopStopConditions.ps1` (or equivalent mechanical predicate) have NOT yet exited 0.
- The next move is mechanically determined by the prior iter's findings or the next phase in the documented sequence.

## Stop only when

- Explicit user "stop", "pause", "wait", or equivalent command in the current session.
- `context-guardian` HALT threshold (~85% effective context) per `.claude/rules/context-guardian.md`.
- Genuine BLOCKING ambiguity that requires user judgment — e.g., "which production environment?" — NOT "do you want me to tag this commit?".
- Mechanical stop conditions exit 0 across all required phases.
- Spinning detected (3 consecutive iters with identical findings — see the spinning-detection convention in any well-shaped loop).

## Anti-pattern

`Want me to (a)/(b)/(c)?` framing between iterations is a YAGNI tax on autonomous work. Pick the highest-leverage next move from the documented sequence and execute. Surface decisions only when the choice is genuinely ambiguous AND blocks forward progress.

The asymmetry with `no-silent-deferrals.md` is intentional:
- **Continuing without asking** is allowed (this rule).
- **Removing/deferring user-requested work without asking** is forbidden (`no-silent-deferrals.md`).

Silent additions to forward progress are easy to revert if wrong; silent deferrals erase user intent.

## How to apply

- After completing an integration / commit / merge in loop mode: immediately spawn the next iter's audit team (or whatever the documented next step is — typically 4 parallel `code-investigator` per `agent-teams.md`).
- Use the just-completed iter's findings as priors for the next iter's gap forensics.
- The loop ends when stop conditions are met per `Check-LoopStopConditions.ps1`, NOT when an iteration's deliverables are wrapped up.
- If the operator explicitly says "pause", "stop", "wait" — pause. The rule is "don't ASK for permission"; following an explicit user directive is different.

## Examples (concrete)

| Situation | Correct behavior |
|---|---|
| iter N's commits land + gates pass | Spawn iter N+1 audit team |
| iter N produced 4 HIGH-confidence findings | Spawn iter N+1 implementer team to fix them; don't ask "should I fix these?" |
| iter N produced 2 LOW-confidence findings | Add backlog entries per `scope-discipline.md`; spawn iter N+1 |
| User said "stop" | Stop |
| Context budget hits 80% | Continue with awareness of HALT threshold; consider compact between iters |
| Context budget hits 85% (HALT) | Stop, write handoff, instruct user to `/resume-handoff` in fresh session |
| Genuine ambiguity: "which deployment ring should this go to?" | Ask the user; this is not a YAGNI tax — it's a real blocking decision |
| Pseudo-ambiguity: "should I commit and continue?" | Don't ask; commit and continue per the loop's contract |

## Related

- `.claude/rules/no-silent-deferrals.md` — companion rule on the asymmetry (additions OK; deferrals require asking)
- `.claude/rules/loop-cadence-discipline.md` — when the loop wakes, this rule says it should keep working
- `.claude/rules/loop-stop-language-discipline.md` — language to use mid-loop (no closing-bow; surface next iter's priors)
- `.claude/rules/context-guardian.md` — when to actually stop (HALT threshold)
- `CLAUDE.md` § Self-Improvement Loop Protocol — the full per-iteration step sequence this rule reinforces
