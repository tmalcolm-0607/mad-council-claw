# Phased Review Findings Schema (--deep --fix)

When `--deep --fix` is used, Phase 4.5 (TRIAGE) generates a structured `findings.json` from the synthesized report.

## Schema

```json
{
  "review_id": "PR-12345",
  "generated_at": "2026-02-07T12:00:00Z",
  "findings": [
    {
      "id": "F-001",
      "severity": "CRITICAL|MAJOR|MINOR",
      "confidence": 0.95,
      "category": "security|architecture|testing|quality|performance",
      "location": {
        "file": "src/Services/MyService.cs",
        "line_start": 45,
        "line_end": 52
      },
      "description": "Missing input validation on user-provided caseId",
      "fix_type": "AUTO|SUGGEST|HUMAN_ONLY",
      "fix_complexity": "TRIVIAL|SIMPLE|COMPLEX|ARCHITECTURAL",
      "suggested_fix": {
        "description": "Add Guard.Against.NullOrWhiteSpace for caseId parameter",
        "code_snippet": "Guard.Against.NullOrWhiteSpace(caseId, nameof(caseId));",
        "insertion_point": { "file": "src/Services/MyService.cs", "line": 46 }
      },
      "fix_outcome": null
    }
  ]
}
```

## Confidence-Gated Classification

| Confidence | Complexity | Action |
|-----------|------------|--------|
| >= 0.9 | TRIVIAL or SIMPLE | AUTO-FIX |
| >= 0.9 | COMPLEX | SUGGEST-FIX |
| 0.7 - 0.9 | TRIVIAL or SIMPLE | SUGGEST-FIX |
| 0.7 - 0.9 | COMPLEX | HUMAN-ONLY |
| < 0.7 | Any | HUMAN-ONLY |
| Any | ARCHITECTURAL | HUMAN-ONLY |

## fix_outcome Values (Populated After Fix Phase)

| Value | Meaning |
|-------|---------|
| `null` | Not yet attempted |
| `FIXED` | Fix applied and verified |
| `UNFIXED` | Fix attempted but verification failed |
| `REGRESSED` | Fix caused regression - reverted |
| `SKIPPED` | Classified as HUMAN-ONLY or user declined |
