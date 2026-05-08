# Fixture: basic input for /check-environment-health (synthetic)

Synthetic input for the check-environment-health skill. The skill probes a deployed environment (App Service, Cosmos, Key Vault, App Insights) and reports green/yellow/red per resource.

## Synthetic input artifact

Environment: `tonym` (NPE)
Resources expected:
- App Service: `app-myapi-tonym-westus3`
- Cosmos: `cosmos-myapp-tonym-westus3`
- App Insights: `appi-myapp-tonym-westus3`
- Managed Identity: `id-myapi-tonym-westus3`

## Skill invocation

```
/check-environment-health
```

## Notes

This fixture exercises the smart-default flow (probe each resource → categorize → report). For mode-specific fixtures (--watch, --json, --since <N>m), add additional fixtures.
