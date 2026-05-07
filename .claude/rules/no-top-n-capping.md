---
title: Rule — No Top-N capping
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — No Top-N capping

Tasks that surface findings — audits, investigations, code reviews, inventories, gap analyses, retrospectives — must enumerate exhaustively. Top-N caps ("Top 5", "first 10", "most important 3") silently truncate the very findings the task exists to surface.

**Source:** session 249a59a7 (2026-05-02). During iter 1-41 of the collab-engine session, every audit/review/inventory subagent prompt the orchestrator composed contained a cap. The user had to flag the antipattern manually each time. Example: a "5 LENS services" report was returned against `references/`; user replied "your report doesn't have all /lens-* services :(" — the orchestrator had to re-run with all 13 repos enumerated. NO existing rule permits Top-N capping. Multiple rules mandate the opposite.

## Rule statement

Every task that produces a list of findings MUST enumerate every relevant item. Empty categories are evidence of completeness, not omissions to be quietly dropped — they MUST be stated explicitly ("no findings in category X") rather than silently elided.

The cap was an LLM-default the orchestrator imposed without authority. Rules that already mandate exhaustive enumeration:
- `pr-comment-triage.md` — "TRIAGE EACH COMMENT"
- `scope-discipline.md` — "every item classify and act"
- `skill-standards.md` § Dimension 2 — anti-hallucination discipline

## How to apply

- Every Task subagent prompt MUST include the literal sentinel: `Enumerate exhaustively. No Top-N capping. Every item classified and acted upon. State 'no findings' explicitly when a category is empty.`
- Acceptable use of "top N" is *display ordering only* — the prompt must include both the cap phrase AND the exhaustive-enumeration sentinel to communicate "rank top N for human display, list all internally."
- When enumeration is too long for one report, do NOT truncate — split into part1.md / part2.md, or write to disk and reference by path. Never silently shorten.
- Reports that cite "no findings in category X" must make that statement explicit. Empty categories are evidence of completeness.

## Mechanical detection

Hook `.claude/hooks/detect-top-n-capping.js` (PreToolUse:Task) scans Task prompts for cap phrases:

```
\btop[-\s]+\d+\b
\bfirst\s+\d+\b
\b(?:most|least)\s+(?:important|critical|severe|relevant)\s+\d+\b
\b(?:limit|cap|bound)\s+(?:to|at)\s+\d+\b
\bonly\s+(?:the\s+)?(?:top|first)\s+\d+\b
\b(?:list|enumerate|return|show|report)\s+(?:up\s+to\s+|at\s+most\s+)?\d{1,2}\s+(?:issues|findings|items|results|files|repos|services)\b
\bmaximum\s+(?:of\s+)?\d+\s+(?:issues|findings|items)\b
```

If a cap phrase is present AND `Enumerate exhaustively` is absent, the Task spawn is BLOCKED with `permissionDecision: deny` and a remediation message.

Override: `TOP_N_HOOK_DISABLED=true` in `.claude/settings.local.json` env (NOT recommended — defeats the antipattern detector).

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| "Top 5 issues" in a subagent prompt | Truncates findings the task exists to surface | "Enumerate exhaustively" + (optionally) "rank top 5 for display" |
| "First 10 violations" inventory | Same | Enumerate all; split report if too long |
| "Most important 3 risks" in a risk register | Hides risks 4+ that may matter more in context | List all risks; rank for display only |
| Reporting empty categories silently | Caller can't tell if category was checked | "No findings in category X" explicitly stated |

## Related

- `.claude/hooks/detect-top-n-capping.js` — mechanical PreToolUse:Task block
- `.claude/rules/scope-discipline.md` — "nothing is out of scope; classify everything"
- `.claude/rules/pr-comment-triage.md` — "TRIAGE EACH COMMENT" mandate
- `.claude/rules/skill-standards.md` § Dimension 2 — anti-hallucination
- `CLAUDE.md` § Subagent output completeness — operator-facing summary that cites this rule
