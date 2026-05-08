# Fixture: post-mortem mixed PR (code + doc)

Synthetic input replicating the May 2026 post-mortem shape but in a code-reviewer scope: a single source-code change paired with a doc that prescribes how to use the new code.

## Synthetic input artifact

Branch under review:
- `src/services/auth/SessionValidator.cs` — new code (handler with validator)
- `docs/auth/session-validation-pattern.md` — teaching doc prescribing how teams should adopt the pattern

Excerpt of doc body covers:
- When to use ✓
- API shape ✓
- Error handling ✓
- **PATCH-style update flow — MISSING**
- Test guidance — partial (no concurrency / ETag scenario)

Excerpt of `SessionValidator.cs`:
```csharp
public sealed class SessionValidator(ILogger<SessionValidator> logger)
{
    public bool IsValid(string token)
    {
        if (token == null) return false;
        var parts = token.Split('.');
        return parts.Length == 3;
    }
}
```

## Skill invocation

```
/code-reviewer src/services/auth/SessionValidator.cs docs/auth/session-validation-pattern.md
```

## Notes

This fixture is the regression test for the post-mortem applied to code-reviewer scope:

| Miss | Caught by |
|------|-----------|
| 1 No grounding | Step 1.5 — keyword "validator wiring" + "auth" topic match → fires WorkIQ pull on auth-related lessons-learned |
| 2 No ref-repo cross-check | Step 1.7 — content-types are mixed (`code-change` + `doc-change`); doc-change triggers cross-check on prescriptive content |
| 3 No completeness pass | Step 1.9 — `handler-tests.md` oracle + `doc-generic.md` oracle; both load and emit per-section findings |
| 4 No cross-file consistency | Step 1.8 — code + doc are not same-type, but if 2 docs were present this would fire |
| 5 Risk-blind to blast radius | Step 1.6 — doc-change on prescriptive teaching artifact → blast_radius=5; combined with auth path-match (+3) reaches `--council` threshold |
| 6 Severity calibration off | Output Contract — for the doc's missing PATCH-style section: BLOCKING (doc-change structural absence). For the code's missing JWT signature verify: MUST-FIX (code-change structural absence). |
