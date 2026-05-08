# Fixture: auth policy PR (synthetic, security-relevant)

PR: feat(auth): adopt new ServiceAuthorizationPolicies for GET endpoints
Author: Synthetic Engineer
Branch: users/synth/adopt-new-auth-policies → master
Status: active
Files: 4 changed
- src/API/Controllers/CasesController.cs (+14, attribute change)
- src/API/Controllers/DftSearchController.cs (+8, attribute change)
- src/Common/AuthorizationPolicies.cs (+2 new policy constants)
- test/API.Tests/Controllers/CasesControllerTests.cs (+45, new auth tests)

## Diff snippet (synthetic)

```csharp
+ [AnyOfMiseAuthorizationPolicies([AuthorizationPolicies.CaseRead, AuthorizationPolicies.AllowlistedCallers])]
  public async Task<IActionResult> GetCase(...)

+ public const string CaseRead = "CaseRead";
+ public const string AllowlistedCallers = "AllowlistedCallers";
```

## Description

Adopts new MISE auth policies. Reviewer should verify allowlist is non-empty in production config and that the AllowlistedCallers policy isn't fail-open.

## Existing threads

(none)

## Author claims

- All API.Tests passing including new auth tests
