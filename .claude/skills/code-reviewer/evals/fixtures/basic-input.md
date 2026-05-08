# Fixture: basic input for /code-reviewer (synthetic)

Synthetic input for the code-reviewer skill. The skill reviews code that is NOT a PR (in-progress branch, file path, commit SHA, design-doc code samples).

## Synthetic input artifact

Target: `src/services/auth/SessionValidator.cs` (in-progress branch)

Excerpt:
```csharp
public sealed class SessionValidator(ILogger<SessionValidator> logger) {
    public bool IsValid(string token) {
        if (token == null) return false;
        var parts = token.Split('.');
        return parts.Length == 3;
    }
}
```

## Skill invocation

```
/code-reviewer src/services/auth/SessionValidator.cs
```

## Notes

This fixture exercises the smart-default flow (read → security/correctness/style passes → severity-tagged findings). For mode-specific fixtures (--council, --deep, --quick), add additional fixtures.
