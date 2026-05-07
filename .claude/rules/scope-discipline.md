---
title: Rule — Scope discipline (nothing is out of scope without classification)
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — Scope discipline

Every item surfaced by investigation MUST be resolved. Two valid paths: HIGH-confidence fix-now, OR add to backlog with confidence + rationale. "Out of scope" / "deferred" without a backlog entry is not allowed. Closing a session with `git status --short` showing un-classified items is forbidden.

**Source:** session 6ac2f083 (2026-05-02). User explicitly enforced: "nothing is out of scope stop it" + "if it's an issue we identify we need to plan/improve it, but it needs to be a high confidence item or added to the backlog not out of scope or deferred." Drift accumulates when items go unclassified. Auto-mode means: pick a resolution and execute.

## Rule statement

When investigation (audit, repo-status check, gap analysis, comment triage, build-output review) identifies an issue OR untracked/modified item, resolve it. Two paths only:

1. **HIGH-confidence (≥80%) → fix now.** Commit the work, gitignore the transient, delete the debris, revert the regression. Pick the right action and execute.
2. **Lower confidence → backlog with confidence + rationale.** The backlog file is project-scoped (e.g. `.mad/work-items/<work-item>/claude-md-backlog.md`, `plan-backlog.md`, or the appropriate location). The entry must include: the finding, the confidence number, why it's not fixable now, what would unblock it.

What is NOT allowed:

- Labeling an item "out of scope" without backlog entry.
- Deferring to "another session's work" without resolving (committing to the right branch, gitignoring, or deleting).
- Closing a session with `git status --short` showing items the orchestrator hasn't classified.

## How to apply

- For every modified tracked file: revert (regression) or commit (intentional). Document why.
- For every untracked file: classify (work-product / transient / debris) and act (commit / gitignore / delete).
- For every "I see a thing but I'm not sure what to do" moment: write a backlog entry with confidence + unblock condition.
- Auto-generated state files (failures.json, agent-effectiveness.json, scratch/*.json, etc.): gitignore them. They churn on every run and shouldn't pollute history.
- "Different session's work" is not a free pass. Either it belongs on this branch (commit) or it belongs elsewhere (move + gitignore the source path) — both decisions are explicit, not deferred.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| "Top 5 issues found; rest out of scope" | Same antipattern class as Top-N capping; truncates findings | Enumerate exhaustively per `no-top-n-capping.md`; classify each |
| `git status` shows 30 untracked files at session end; "leaving for next session" | Drift. Next session sees noise and doesn't know what's intentional. | Triage every entry; commit / gitignore / delete |
| "Will get to that next iter" without backlog row | Forgotten by next iter | Backlog row with confidence + unblock condition |
| Reverting a regression silently without commit message explaining what broke | Same regression returns | Commit revert with rationale |

## Related

- `.claude/rules/no-silent-deferrals.md` — the deferral-specific case
- `.claude/rules/no-top-n-capping.md` — the enumeration discipline that drives "every item classify and act"
- `.claude/rules/pr-comment-triage.md` — applies same discipline to PR review feedback
- `.claude/rules/non-negotiable-rules.md` — broader fence list including "MUST NOT skip quality gates"
