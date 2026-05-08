---
title: Rule — PR comment triage (recurring loop responsibility)
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — PR comment triage

For active pull requests owned by the work-loop, every loop iteration MUST review unread PR comments and triage each one — fix-now or backlog-with-confidence. After each fix, confirm the comment author can re-verify post-update with file:line evidence.

**Source:** session 6ac2f083 (2026-05-02). User explicitly added this as a recurring loop feature. PRs accumulate review feedback; without continuous triage, the feedback cycle stretches and reviewers lose context. The loop's value comes from continuous attention; PR comments are an external feedback channel that must be folded into the same continuous discipline as audits and gap analyses.

## Rule statement

When the work-loop owns one or more active PRs, every iteration MUST include a triage step that:

1. **Fetches unread PR comments** (newest first, only those not yet triaged in prior iters).
2. **Triages each comment** per `scope-discipline.md`:
   - HIGH-confidence (≥80%) actionable feedback → fix-now in this iter
   - Lower confidence → backlog row with confidence + unblock condition
   - Already-addressed → respond with evidence (file:line or commit SHA), mark thread resolved
   - Out-of-scope-by-design → respond with rationale, mark wontFix or closed
3. **After fix**: push commit + verify gate(s) pass + post a reply confirming the change with file:line evidence so the comment author can re-verify.
4. **Track triage state** in a per-PR file (e.g. `.mad/work-items/<work-item>/pr-triage-{pr-id}.md`) — comment ID, status (pending / fixed / backlogged / dismissed-with-rationale), date triaged, fix commit SHA if applicable.

The "TRIAGE EACH COMMENT" mandate is exhaustive — Top-N capping is forbidden per `no-top-n-capping.md`.

## How to apply

- Determine the active PR list from the work-item state (e.g. `progress.json` or equivalent). If no active PRs: skip; this rule does not apply.
- Tooling: prefer the project's wrapper scripts (e.g. `.claude/scripts/Ado-PR-Collect.ps1`, `Ado-PR-Comment.ps1`, `Post-ReviewFindings.ps1`) per `deployment-scripts.md`. NEVER use `gh` for ADO repos.
- Each iter's audit MUST include a "PR comment review" lane if any active PRs have unread comments.
- Comment-triage is THE primary external feedback signal for the loop's correctness — treat findings with the same severity weight as council verdicts.
- `--no-verify`-style shortcuts and skipping the triage step are forbidden.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| "Address top 3 most-recent comments only" | Truncates the feedback signal that drives loop correctness | Triage EACH comment exhaustively |
| Fix code per comment but don't reply | Reviewer can't tell if the fix landed; thread stays open | Reply with file:line + commit SHA evidence |
| Reply "fixed" without commit SHA in the reply | Reviewer can't audit | Always cite SHA in the reply |
| Mark thread resolved before pushing the fix commit | Thread closed, fix not yet visible | Resolve only after the fix is pushed and gates pass |
| Skip triage for "this iter's small" — defer all comments to next iter | Backlog accumulates; reviewer engagement decays | Triage each iter; even "no new comments" is recorded |

## Related

- `.claude/rules/scope-discipline.md` — generalized "classify and act" mandate that drives the triage flow
- `.claude/rules/no-top-n-capping.md` — exhaustive enumeration applied to comment lists
- `.claude/rules/deployment-scripts.md` — ADO PR tooling wrapper-scripts policy
- `.claude/skills/pr-review/SKILL.md` — review-side counterpart that inherits the same exhaustive-enumeration discipline
