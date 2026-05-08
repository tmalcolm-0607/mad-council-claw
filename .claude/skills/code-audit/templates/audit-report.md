# Template — code-audit report

Canonical shape for `/code-audit` output. Convention sweep across a directory tree.

> **EXAMPLE — replace this when authoring**

```markdown
# Code Audit — <target-dir>

**Date**: <ISO date>
**Operator**: <alias>
**Conventions audited**: <list rules/patterns/_*/files referenced>

## Summary

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| MUST-FIX | 2 |
| SHOULD-FIX | 8 |
| CONSIDER | 4 |
| PRAISE | 1 |

## Findings

### MUST-FIX

#### [MF-1] src/services/Auth/SessionValidator.cs:42 — JWT signature not verified

Evidence:
```csharp
return parts.Length == 3;
```

Rule: `rules/patterns/_dotnet/dotnet-auth.md` § JWT validation
Confidence: 0.86
Suggested fix: use `JwtSecurityTokenHandler.ValidateToken` with the IssuerSigningKey from MISE config.

(repeat per finding)

## Anti-hallucination

- Categories with zero findings stated explicitly ("Security: no S1-S15 patterns triggered.")
- Every cited file:line was Read before claim (FETCH BEFORE CITE)
- Confidence floors applied per `rules/skill-standards.md` § Dimension 2

## Verdict

ACCEPT_WITH_CAVEATS — N MUST-FIX items; user reviews + remediates before merge.
```

## Reference

- `pr-review/templates/review-findings.md` — same shape for PR-context
- `code-reviewer/templates/code-review.md` — same shape for branch/file
