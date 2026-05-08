# Template — code review report

Canonical shape for `/code-reviewer` output. Use when reviewing code that is NOT a PR (in-progress branch, design doc with code samples, etc.).

> **EXAMPLE — replace this when authoring**

```markdown
# Code Review — <target>

**Reviewer**: <name or "automated">
**Target**: <branch | file path | commit SHA>
**Mode**: <standard | --council | --deep>
**Date**: <ISO date>

## Summary

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| MUST-FIX | 2 |
| SHOULD-FIX | 5 |
| CONSIDER | 3 |
| PRAISE | 2 |

## Findings

[Apply the same Output Contract format as pr-review/templates/review-findings.md]

## Anti-hallucination check

- [x] Categories with no findings stated explicitly
- [x] Confidence threshold gates applied (sub-floor findings demoted to mention)
- [x] FETCH-BEFORE-CITE: every cited file read before claim

## Verdict

ACCEPT | ACCEPT_WITH_CAVEATS | REJECT
```

Reference `pr-review/templates/review-findings.md` for the per-finding shape and severity-to-confidence floor table.
