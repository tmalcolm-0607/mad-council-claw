# Template — PR review findings

Canonical shape for findings emitted by `/pr-review`. Use this when manually drafting a finding artifact or when the skill produces structured output for downstream consumption.

> **EXAMPLE — replace this when authoring**

## Header (required)

```yaml
---
pr_id: <ADO PR number>
title: <PR title>
author: <author display name>
branch: <source-branch> → <target-branch>
status: <active | completed | abandoned>
mode_used: <standard | --quick | --council | --deep>
risk_score: <0-10+>
generated_utc: <ISO-8601>
---
```

## Per-finding shape

```
[<severity>] <file>:<line> — <one-line title>

Evidence:
  <offending snippet, ≤6 lines>

Rule:
  <citation: rules/<file>.md, S# from references/security-checklist.md, recurring-issue-check #N>

Confidence: <0-100>

Suggested fix:
  <one-line description, or code snippet ≤6 lines>
```

Severities: `BLOCKING` / `MUST-FIX` / `SHOULD-FIX` / `CONSIDER` / `PRAISE`.

## Section template

```markdown
## Pass 1 — Security (S1-S15)

[Findings here, or "Security: no S1-S15 patterns triggered."]

## Pass 2 — Conventions, quality, correctness

[Findings here, or "No findings: all 8 recurring checks clean, architecture/testing/code-quality nominal."]

## Verdict

ACCEPT | ACCEPT_WITH_CAVEATS | FIX | ESCALATE | INVESTIGATE
Vote analog: approve | approve-with-suggestions | wait-for-author | reject

## Skill features exercised

- [list dimensions of the smart-default flow that fired]
```

## Anti-hallucination requirement

If a category produced no findings, **state that explicitly**. Never pad. Examples:

✓ "Security: no S1-S15 patterns triggered."
✓ "Pass 2: 0 of 8 recurring checks fired."
✗ Empty section / silent omission

## Confidence threshold gates

Per `rules/skill-standards.md` § Dimension 2:

| Severity | Min confidence to post |
|----------|-----------------------|
| BLOCKING | 80 |
| MUST-FIX | 70 |
| SHOULD-FIX | 60 |
| CONSIDER | 50 |
| PRAISE | 70 |

Sub-floor findings → mention in conversation only, do not post inline.
