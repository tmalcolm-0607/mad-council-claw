---
title: Rule — No silent deferrals
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — No silent deferrals

Don't quietly drop features the user asked for. If something the user wants doesn't fit current scope, raise it as a discussion — don't unilaterally write it into an Out-of-Scope, v1.5-deferred, or "follow-up" list.

**Source:** session 249a59a7 (2026-05-02). User explicitly said: "i never asked for any deferrals i dont want any deferrals without discussion why do you keep removing features i ask for/want." This was after Lobster Device & App Runtime pillar (Teams integration, personal-assistant capability) had been silently labeled "deferred to v1.5" — the user's loop directive explicitly named "personal assistant" and "collaboration engine"; deferring those defeated the purpose.

## Rule statement

Adding a feature without asking is allowed (per the autonomous-loop discipline). Removing or deferring a user-requested feature without asking is NOT allowed. The asymmetry is intentional: silent additions are easy to revert if wrong; silent deferrals erase user intent.

## How to apply

- Before listing a user-requested feature in OoS / deferred / v1.5 / "follow-up": ask the user explicitly. State the trade-off (effort, blast radius, scope creep) and let them choose.
- If a feature is already labeled OoS/deferred and the user surfaces it as a gap, treat that as a directive to reverse — fold it in, do NOT justify the deferral.
- "Adding without asking" is permissible. "Removing/deferring without asking" requires a conversation.
- Existing rationalized deferrals from upstream documents (e.g. a source spec that already declares "FR-X deferred to v1.5 because Y") are PRESERVED, not invented. Do not introduce NEW deferral keywords beyond what the source already declares.

## Mechanical detection

Hook `.claude/hooks/content-scan-deferrals.js` (PostToolUse:Write|Edit) scans written content for deferral keyword patterns:

```
v1\.5  |  \bOoS\b  |  out[ -]of[ -]scope  |  deferred  |  future work
follow[ -]up(?: work|task|item)?  |  next iteration  |  v\d+\.\d+ scope
descoped  |  not in scope  |  punt(?:ed|ing)? to
```

Hits append violations to `.mad/scratch/deferral-flags.json`. The companion `validate-artifact-completeness.js` (SubagentStop) blocks completion if flags exist without `acknowledged_by_user: true`.

The hook auto-exempts paths that legitimately track or document deferrals: `backlog.md`, `CHANGELOG.md`, `.mad/reports/*.md`, `.mad/scratch/*.md`, `.claude/hooks/*.js`, `.claude/scripts/*.{ps1,js,sh}`, `.claude/rules/no-silent-deferrals.md`, `.claude/rules/no-top-n-capping.md`, plus mad-council-claw catalog/output paths: `docs/03-feature-catalog/**/*.md`, `docs/06-agent-team-outputs/**/*.md`, `docs/05-design-reviews/**/*.md`, `docs/04-research/**/*.md`. The mad-council-claw paths legitimately reference deferral keywords in canonical wave-2 lane-b ledger templates (mandatory `out-of-scope-notes:` block) and downstream lane summaries / council reviews / research findings — per the "preserved not invented" clause above. New scanning patterns added to the hook MUST also extend the exemption list to prevent recursive self-trigger.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Quietly drop a user-requested feature into "Out of scope" | Erases user intent; breaks trust | Ask explicitly with trade-off summary |
| Add `deferred to v1.5` to a feature the user has been actively asking about | Same | Ask; if user agrees, document with rationale + revisit-trigger |
| Re-add a previously-acknowledged deferral after the user surfaced it as a gap | Treats user feedback as noise | Fold the feature in; do not re-justify the deferral |
| Use `feedback` framing in code/comments to introduce a deferral | Same as silent-drop, just lexically softer | Treat all deferral language uniformly: ask first |

## Related

- `.claude/hooks/content-scan-deferrals.js` — keyword detector and exemption pattern
- `.claude/hooks/validate-artifact-completeness.js` — SubagentStop block on unacknowledged flags
- `.claude/rules/scope-discipline.md` — "nothing is out of scope; classify everything" companion rule
- `.claude/rules/autonomous-loop-discipline.md` — defines the symmetry: continue without asking, but defer requires asking
- `CLAUDE.md` § Deferral discipline — operator-facing summary that cites this rule
