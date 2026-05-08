---
paths:
  - "**/deploy/**"
  - "**/infrastructure/**"
  - "**/*.bicep"
  - "**/arm/**"
---

# CI/CD Deployment Patterns

Standards for deployment pipelines, Azure-style deployment orchestration, and IaC.

## Environment Promotion

**Path**: Dev → Int → PPE/SDF → PROD → Sovereign

| Environment | Approval | Purpose |
|-------------|----------|---------|
| Dev | None | Developer testing |
| Int | None | Integration testing |
| PPE/SDF | Team lead | Pre-production validation |
| PROD | Change board | Production |

---

## Azure Deployment Artifact Structure

Azure-style deployment pipelines typically organize artifacts like this:

```
ServiceGroupRoot/
├── ServiceModel.json       # Service definition (required)
├── ScopeBindings/          # Environment bindings (Dev, Int, PPE, Prod)
├── Parameters/             # Environment parameters
└── RolloutSpecs/           # Standard, Express, Hotfix specs
```

---

## ServiceModel.json (Key Fields)

```json
{
  "serviceMetadata": {
    "serviceGroup": "your-service-group",
    "serviceTreeId": "guid-here",
    "contacts": { "securityContact": "...", "oncallContact": "..." }
  },
  "serviceResourceGroupDefinitions": [{
    "name": "ApiResources",
    "azureResourceGroupName": "rg-your-service-${Environment}-${Region}",
    "serviceResourceDefinitions": [
      { "name": "WebApp", "composedOf": { "arm": { "templatePath": "..." } } }
    ]
  }]
}
```

---

## RolloutSpec Steps

1. **PreDeploymentValidation** - Validate templates
2. **Deploy** - Deploy resources
3. **HealthCheck** - Verify `/api/health`
4. **WarmUp** - Hit warmup endpoints

```json
"rollback": {
  "enabled": true,
  "criteria": { "healthCheckFailure": true, "deploymentFailure": true }
}
```

---

## Bicep Best Practices

```bicep
param environment string
param location string = resourceGroup().location
var appServicePlanSku = environment == 'prod' ? 'P1V3' : 'B1'

// Use modules, output for downstream dependencies
module storage 'modules/storage.bicep' = { params: { environment, location } }
output storageAccountName string = storage.outputs.accountName
```

---

## Bicep Artifact Management

### Gitignore Compiled ARM Templates

When using Bicep, compiled ARM JSON (`*.json`) in template directories is a build artifact. Do not commit it alongside Bicep source.

```gitignore
# Templates/ — Bicep generates ARM JSON at build time
ServiceGroupRoot/Templates/*.json

# Explicitly track needed non-generated files
!ServiceGroupRoot/ServiceModel.json
!ServiceGroupRoot/Parameters/*.json
!ServiceGroupRoot/ScopeBindings/*.json
```

**Whitelist approach**: Gitignore broadly, then explicitly unignore files that must be tracked.

### Use `.bicepparam` Instead of `.parameters.json`

Bicep parameter files (`.bicepparam`) provide type safety and expression support. Prefer them over legacy JSON parameter files.

```bicep
// CORRECT: main.bicepparam — type-safe, supports expressions
using 'main.bicep'

param environment = 'prod'
param location = 'westus2'
param appServicePlanSku = environment == 'prod' ? 'P1V3' : 'B1'
```

```json
// WRONG: main.parameters.json — no type safety, no expressions
{
  "$schema": "...",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "prod" }
  }
}
```

### Runtime Version Verification

Before targeting a runtime version in Bicep templates, verify it is GA (Generally Available) in Azure for the target region. Preview runtimes may not be available in all regions and can cause deployment failures.

| Check | How |
|-------|-----|
| App Service runtime | `az webapp list-runtimes` |
| Functions runtime | `az functionapp list-runtimes` |
| Region availability | Azure portal > Region > Services |

---

## Validation Before Deploy

```yaml
- task: AzureCLI@2
  inputs:
    inlineScript: |
      az deployment group validate --resource-group $(RG) --template-file main.bicep
      az deployment group what-if --resource-group $(RG) --template-file main.bicep
```

---

## Secrets Management

- Use Key Vault references: `@Microsoft.KeyVault(VaultName=...;SecretName=...)`
- Never commit secrets to parameter files
- Inject secrets post-deployment via script

---

## Health Check Contract

```json
{ "status": "healthy", "version": "1.0.0", "checks": { "database": "healthy" } }
```

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Direct production deployment | Go through PPE first |
| Hardcoded parameters | Use parameter files per environment |
| Secrets in parameter files | Use Key Vault references |
| No rollback plan | Configure deployment-pipeline rollback |
| Single region deployment | Deploy to paired regions |
| Committed compiled ARM JSON alongside Bicep source | Gitignore generated JSON, build from Bicep in pipeline | **REJECT** |
| `.parameters.json` when `.bicepparam` available | Use `.bicepparam` for type safety | **WARN** |
| Targeting preview runtime without verification | Verify GA status with `az webapp list-runtimes` | **WARN** |
