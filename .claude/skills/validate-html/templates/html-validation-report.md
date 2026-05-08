# Template — HTML validation report

Canonical shape for `/validate-html` output.

> **EXAMPLE — replace this when authoring**

```markdown
# HTML Validation — <target>

**Target**: `<file or URL>`
**Date**: <ISO date>
**Probes used**: a11y (axe-core or equivalent), broken-link, console-error capture, viewport sizing

## Summary

| Probe | Findings |
|-------|----------|
| Console errors | 2 |
| Broken in-page links | 0 |
| 404 resources | 1 |
| a11y violations | 5 (1 critical) |
| Viewport issues | 0 |

## Findings

### [BLOCKING] missing alt on header logo

Evidence: `<img src="logo.png">` at index.html:42
Rule: WCAG 2.1 1.1.1 — non-text content needs text alternative
Confidence: 0.95
Suggested fix: add `alt="Acme Corp logo"`.

(repeat per finding)

## Anti-hallucination

- Every probe response captured (DOM excerpt, console line, network log)
- Empty categories stated explicitly ("No console errors captured.")

## Verdict

ACCEPT_WITH_CAVEATS or REJECT depending on severity counts.
```

## Reference

- `rules/skill-standards.md` § Dimension 2 — confidence floors
