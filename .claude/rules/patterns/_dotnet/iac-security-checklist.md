---
paths:
  - "**/*.bicep"
  - "**/deploy/**"
  - "**/*.bicepparam"
  - "**/arm/**"
  - "**/spec.md"
  - "**/plan.md"
---

# IaC Security & Configuration Checklist

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Infrastructure-as-Code security and configuration patterns for Azure-style deployment pipelines. Originally distilled from ~28 PR-review threads across a handful of production consumer services; names and repo references have been removed, but the underlying lessons are ecosystem-agnostic.

---

## Storage Account Hardening

All storage accounts MUST disable shared key access and enforce network restrictions.

### Correct

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowSharedKeyAccess: false          // Entra ID only — no account keys
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'             // No public access
      bypass: 'AzureServices'
      virtualNetworkRules: [
        { id: subnetId }
      ]
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: '${storageAccountName}-diag'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
    metrics: [
      { category: 'Transaction', enabled: true }
    ]
  }
}
```

### Wrong

```bicep
// WRONG: Shared key access enabled (default), no network rules, no diagnostics
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    // allowSharedKeyAccess defaults to true — anyone with the key bypasses Entra ID
    // No networkAcls — publicly accessible
    // No diagnostic settings — blind to access patterns
  }
}
```

**Lesson:** defaults in Azure bicep are usually the wrong default for a production workload. Set `allowSharedKeyAccess: false`, `networkAcls.defaultAction: 'Deny'`, and diagnostic settings explicitly — don't rely on the resource provider default.

---

## TODO/Placeholder Detection in Production Configs

Production configuration files MUST NOT contain TODO comments, placeholder values, or zero-GUID defaults.

### What to Check

| Pattern | Example | Action |
|---------|---------|--------|
| `TODO` in value | `subscriptionId: "TODO"` | **REJECT** |
| All-zeros GUID | `"00000000-0000-0000-0000-000000000000"` | **REJECT** |
| Placeholder strings | `"your-tenant-id"`, `"REPLACE_ME"` | **REJECT** |
| Empty required fields | `connectionString: ""` | **REJECT** |

**Lesson:** production config deploys with a `TODO` in a required field result in hard deployment failures that are only caught at rollout time. A 20-line CI scanner that greps for these patterns catches them at PR-review time instead.

---

## Compiled ARM Gitignore

When Bicep is the source of truth, compiled ARM JSON files MUST NOT be checked into the repository.

### .gitignore Entry

```gitignore
# Compiled ARM templates — Bicep is source of truth
**/arm/*.json
!**/arm/**/*.bicep
```

### Why

Compiled ARM JSON drifts from Bicep source, creating confusion about which is authoritative. Bicep compilation happens in the pipeline.

**Lesson:** pick one source of truth and gitignore the generated output. If both files are tracked, reviewers will waste time diffing the ARM JSON and you'll eventually ship a mismatch.

---

## Deployment Ordering

App services MUST depend on their configuration stores **and** their config key-values. Missing `dependsOn` causes apps to start before config values exist.

### Correct

```
DeployAppService:
  dependsOn:
    - DeployAppConfigStore
    - DeployAppConfigKeyValues    # Config VALUES, not just the store
```

### Wrong

```
# WRONG: App may start before config values are written
DeployAppService:
  dependsOn:
    - DeployAppConfigStore        # Store exists but has no key-values yet
```

**Lesson:** depending on a *store* is not enough — you have to depend on the *values being populated in that store*. The app service sees "the store exists" as green and starts up against an empty config.

---

## Bicepparam Migration

JSON parameter files SHOULD be migrated to `.bicepparam` format when available.

### Correct

```bicep
// main.bicepparam
using 'main.bicep'

param location = 'eastus2'
param environmentName = 'prod'
param storageAccountName = 'stmyappprod'
```

### Legacy (migrate when possible)

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "parameters": {
    "location": { "value": "eastus2" }
  }
}
```

**Lesson:** `.bicepparam` provides type safety, IntelliSense, and expression support that JSON parameter files do not. Reviewers will request the migration repeatedly if you ship new features in the old format.

---

## Value Placement Strategy

Where to place values based on whether they vary by environment.

| Value Type | Placement | Example |
|------------|-----------|---------|
| **Env-varying** | ScopeBindings or Parameters | Subscription ID, resource group name, SKU |
| **Env-invariant** | `.bicepparam` defaults or Bicep defaults | API version, resource kind, static tags |
| **Auto-populated by ARM** | Do not set manually | `$schema`, `contentVersion`, `apiVersion` (set by Bicep compiler) |

**Rule**: If a value changes between Dev / test / PPE / Prod, it belongs in ScopeBindings or Parameters. If it is the same everywhere, hardcode it in the Bicep template or `.bicepparam` file.

**Lesson:** mixing env-varying values into the template (rather than parameters) is a frequent source of "it worked in test but prod has the wrong subscription" bugs. The placement decision is worth making once, explicitly, rather than case-by-case.

---

## Deployment Naming Conventions

Azure deployment resources have character limits. Pick a naming scheme that is collision-free across all environments and regions, and validate it in CI.

| Resource | Pattern | Example |
|----------|---------|---------|
| App Hosting Plan | `_Region-AppHostingPlan_` | `_EastUS2-AppHostingPlan_` |
| Resource Group | `{service}-{env}-{region}` | `myapp-prod-eus2` |
| Deployment unit | Short, unique per region | `MYAPP-EUS2` |
| Service Group | Environment-agnostic name | `MyApp` (NOT `MyApp.prod`) |

### Collision Prevention

Two resource group definitions MUST NOT resolve to the same Azure resource group name. Verify naming formulas produce unique values across all environments and regions.

**Lesson:** when two deployment definitions end up with the same resource-group name, deployments will silently overwrite each other's resources. A 30-line CI script that enumerates the product (environments × regions × resource types) and asserts uniqueness prevents this at PR time.

---

## Scope Binding Fragility

Deployment scope bindings that use whitespace-sensitive find/replace patterns are fragile. If anyone reformats the parameter file, the replacement silently fails.

### Mitigation

- Prefer structured parameter references over string find/replace
- Add pipeline validation that scope bindings resolved correctly
- Test with reformatted files to ensure bindings still work

**Lesson:** any mechanism where a formatting change silently breaks behaviour is a bug waiting to happen. Replace string-level find/replace with structured references wherever possible, and add a test that reformats the parameter file and re-runs binding to catch regressions.

---

## Preview API Versions

Production Bicep templates SHOULD use GA (Generally Available) API versions, not preview versions.

| API Version | Status | Action |
|-------------|--------|--------|
| `2023-05-01` | GA | Preferred |
| `2024-01-01-preview` | Preview | Warn in prod |

Preview APIs may have breaking changes, missing features, or be withdrawn.

**Lesson:** preview APIs are fine for dev / test experimentation but become a migration-cost surprise when the preview is withdrawn or a breaking change lands. Pin to GA versions in anything that reaches production.

---

## Enforcement

| Pattern | Status |
|---------|--------|
| Storage account without `allowSharedKeyAccess: false` | **REJECT** |
| Network-unrestricted storage with shared key access | **REJECT** |
| Production config with TODO/placeholder values | **REJECT** |
| Compiled ARM JSON when Bicep source exists | **REJECT** |
| Missing `dependsOn` from app service to config values | **REJECT** |
| Resource group naming collision | **REJECT** |
| JSON parameter files when `.bicepparam` is available | **WARN** |
| Preview API version in production templates | **WARN** |
| Missing diagnostic settings on resources | **WARN** |
| Hardcoded region lists (should use dynamic iteration) | **WARN** |
| Environment suffix in Service Group name (e.g., `.prod`) | **REJECT** |
| Env-varying value hardcoded in Bicep/bicepparam instead of ScopeBindings | **WARN** |

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Shared key access on storage | Bypasses Entra ID delegation model | `allowSharedKeyAccess: false` + RBAC |
| Public network access without restrictions | Storage exposed to internet | `networkAcls.defaultAction: 'Deny'` + VNet rules |
| TODO values in production configs | Hard deployment failures | CI validation step that scans for placeholders |
| Compiled ARM alongside Bicep | Drift between source and compiled | `.gitignore` ARM JSON, compile in pipeline |
| App service without config dependency | App starts with empty/default config | `dependsOn` on config key-value deployment |
| Whitespace-sensitive scope bindings | Silent failure on file reformat | Structured parameter references |
| Hardcoded region lists in Bicep | Manual updates when regions added | Dynamic iteration over region parameter array |
