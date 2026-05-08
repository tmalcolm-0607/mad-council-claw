---
paths:
  - "**/*.cs"
---

> **Kit-policy supplement; canonical LENS is silent on feature flags.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills — none prescribe a feature-flag mechanism.

# Feature Flags

Canonical LENS is silent on feature flags. Consumer projects pick a backing mechanism (Azure App Configuration, an internal Experimentation and Configuration Service, LaunchDarkly, or custom). The kit-internal recommendation below avoids inventing canonical claims; treat it as guidance, not enforcement.

## Recommended shape

Inject `IFeatureManager` from `Microsoft.FeatureManagement` and consume via:

```csharp
if (await this.featureManager.IsEnabledAsync("MyService.MyFeature"))
{
    // new path
}
else
{
    // existing path
}
```

## Naming convention

Flag names follow `{Service}.{FeatureName}` per `naming-conventions.md`. Define flags as constants to avoid typo risk:

```csharp
public static class FeatureFlags
{
    public const string EnableNewWorkflow = "MyService.EnableNewWorkflow";
}
```

## Anti-patterns

| Anti-pattern | Fix |
|--------------|-----|
| Inline flag-name strings at call sites | Use a constants class |
| Manual `IConfiguration.GetValue<bool>("Features:X")` checks | Use `IFeatureManager` (supports gradual rollout, targeting filters) |
| No fallback path | Always provide an `else` for the disabled state |

No further LENS-canonical guidance applies.
