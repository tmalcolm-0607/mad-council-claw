---
paths:
  - "**/deploy/**"
  - "**/infrastructure/**"
  - "**/*.bicep"
  - "**/arm/**"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# CI/CD Deployment Patterns

Standards for deployment pipelines, Azure-style deployment orchestration, and IaC.

> **For pipeline compliance verification:** run the `lens-pipeline-audit:pipeline-audit` skill (installed at `.claude/skills/lens-pipeline-audit/skills/pipeline-audit/SKILL.md`; canonical source at `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/`). The 20-standard catalog at `.claude/skills/lens-pipeline-audit/rules/pipeline-standards-catalog.md` (kit mirror of `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/rules/pipeline-standards-catalog.md`) is authoritative — this file documents the same shape with kit-style explanations.

## Environment Promotion (LENS Ring Topology)

LENS pipelines deploy through a **two-stage shape with rings inside the production stage** — NOT a linear Dev→Int→PPE→PROD chain. 1ES restricts pipelines to one production Ev2 stage per cloud (e.g., Public). Both PPE and Prod are `isProduction: true` (both deploy to PrdTRS), so they MUST be **rings within a single production stage**, not separate stages.

| Stage | `isProduction` | Approval workflow | Rings | Purpose |
|-------|----------------|-------------------|-------|---------|
| **Test_ReleaseStage** | `false` | `workflow: test` | NPE (e.g., `serviceGroupOverride: ".npe"`) | NPE / pre-production validation |
| **ManualApproval_BeforePPE** | `false` | `workflow: test` (preApproval gate) | — | `ManualValidation@0` human gate before any PrdTRS touch |
| **Production_ReleaseStage** | `true` | `workflow: lockbox` | PPE → PROD (`select: rings(PPE,PROD)`) | Ring-based progression through PPE then PROD |

This topology is mandated by the canonical pipeline standards:

- **RING-001** (REQUIREMENT): PPE and Prod MUST be rings within a single production stage (not separate stages).
- **RING-002** (REQUIREMENT): the single production stage has `isProduction: true`.
- **RING-003** (STANDARD): outer ring orchestration uses `StageMapPath: StageMap.rings.json`.
- **AUTH-001** (STANDARD): production stage uses `workflow: lockbox`; NPE uses `workflow: test`.
- **AUTH-003** / **AUTH-004** (REQUIREMENT): lockbox `scope.serviceGroupName` and `scope.subscriptionIds` are mandatory.
- **GATE-001** (STANDARD): `ManualValidation@0` task gates progression from NPE to production.

For the canonical YAML shape see the example pipeline in `cicd-pipeline-structure.md` § "Multi-Stage Pipeline Pattern (Canonical)".

---

## Progressive Feature Enablement

New infrastructure features (DDoS protection, WAF, diagnostic settings, etc.) MUST be enabled progressively through rings.

| Phase | Targets | Gate |
|-------|---------|------|
| 1 | NPE (`Test_ReleaseStage`) | Automated tests pass |
| 2 | PPE ring (`Production_ReleaseStage`, `select: rings(PPE)`) | Managed SDP bake (per inner stage map) |
| 3 | PROD ring (`Production_ReleaseStage`, `select: rings(PPE,PROD)`) | PPE bake complete + outer-stage-map manual promotion |

**Rule**: the same PR should update parameter files for all rings. Do not enable a feature in NPE without also preparing PPE/PROD parameter files (even if gated behind feature flags or conditional parameters).

---

## Azure Deployment Artifact Structure (Canonical LENS Ev2 Layout)

LENS services use the canonical Ev2 `ServiceGroupRoot` layout per `LENSEv2Standards.md:86-109`. Each Ev2-managed service has a single `ServiceGroupRoot` directory that contains everything Ev2 needs to deploy.

```
Ev2/ServiceGroupRoot
│
├── Configuration/                                   # Per-environment / per-ring config files
│   └── Microsoft.M365.LENS.<ServiceName>.json       # Base (shared) config
│   └── Microsoft.M365.LENS.<ServiceName>.ppe.json   # PPE ring overrides
│   └── Microsoft.M365.LENS.<ServiceName>.prod.json  # PROD ring overrides
│   └── Microsoft.M365.LENS.<ServiceName>.npe.json   # NPE config (independent, not inherited)
│
├── Parameters/                                      # Bicep parameter files (resolved via ScopeBindings)
│   └── appService.bicepparam
│   └── appHostingPlan.bicepparam
│   └── anotherTemplateExample.bicepparam
│
├── Templates/                                       # Bicep templates + compiled ARM (gitignored)
│   └── appService.bicep
│   └── appHostingPlan.bicep
│   └── anotherTemplateExample.bicep
│
├── Ev2.proj                                         # Bicep → ARM compilation entry
├── RolloutSpec.json                                 # Orchestrates rollout (see "RolloutSpec" above)
├── ScopeBindings.json                               # Binds parameters/outputs across deployment scopes
├── ServiceModel.json                                # Deployable units + ExecutionConstraints
├── ServiceSpecification.json                        # Service registration spec (do NOT set OwnerGroupObjectId)
├── ServiceGroupSpecification.json                   # (sometimes; auto-registered by pipeline normally)
├── StageMap.rings.json                              # Outer ring orchestration (PPE → PROD)
├── StageMap.ppe.json                                # Inner PPE 5-stage map
├── StageMap.prod.json                               # Inner PROD 5-stage map
└── buildver.txt                                     # Load-bearing version handoff (Build → Deploy)
```

| Artifact | Role |
|----------|------|
| `Configuration/` | Per-environment / per-ring config; resolved at deploy time via `ringScope` in RolloutSpec |
| `Templates/` | Bicep source; compiled ARM JSON output is gitignored (build artifact) |
| `Ev2.proj` | Compiles Bicep into ARM and outputs to the directory Ev2 reads |
| `ServiceModel.json` | Defines deployable units (`ServiceResourceDefinitions`) and groups (`ServiceResourceGroupDefinitions`) per scope (global / geo / region) |
| `RolloutSpec.json` | Orchestrates rollout; references `ServiceResourceDefinitions` from ServiceModel |
| `ScopeBindings.json` | Binds configuration values + deployed outputs across templates |
| `ServiceSpecification.json` | Service registration; do **not** provide `OwnerGroupObjectId` (resolved automatically via ServiceTree) |
| `buildver.txt` | Deployment version; populated automatically by pipeline parameters or manually for ad-hoc deployments |

---

## ServiceModel.json (Key Fields)

```json
{
  "serviceMetadata": {
    "serviceGroup": "Your.Service.Group",
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

## RolloutSpec — Canonical `rolloutMetadata.configuration` Shape

LENS RolloutSpec.json files use the canonical Ev2 `rolloutMetadata.configuration` shape. The deployment steps themselves live in `orchestratedSteps` (per-service); `rolloutMetadata.configuration` holds the configuration scope that Ev2 needs to resolve per-ring values, register the service model, and notify operators.

```json
{
  "rolloutMetadata": {
    "configuration": {
      "serviceGroupScope": {
        "specPath": "Configuration/$serviceGroup().json"
      },
      "ringScope": [
        {
          "ring": "PPE",
          "serviceGroupLevelSpecPath": "Configuration/Microsoft.M365.<YourService>.ppe.json"
        },
        {
          "ring": "PROD",
          "serviceGroupLevelSpecPath": "Configuration/Microsoft.M365.<YourService>.prod.json"
        }
      ]
    },
    "serviceModelPath": "ServiceModel.json",
    "scopeBindingsPath": "ScopeBindings.json",
    "name": "<YOUR_SERVICE_NAME>",
    "rolloutType": "Major",
    "buildSource": {
      "parameters": {
        "versionFile": "buildver.txt"
      }
    },
    "notification": {
      "email": {
        "to": "<TEAM_EMAIL>"
      }
    }
  },
  "orchestratedSteps": [
    // service-specific deployment steps live here (no changes needed when adding rings)
  ]
}
```

Required fields (per `configuringPpeAndProdRings.md:294-340` + `LENSEv2Standards.md:53-65`):

| Field | Purpose |
|-------|---------|
| `serviceGroupScope.specPath` | `Configuration/$serviceGroup().json` — base config (the `$serviceGroup()` function resolves to your service group name) |
| `ringScope[]` | Per-ring override configs; one entry per ring (PPE, PROD); ring names must match the outer stage map |
| `serviceModelPath` | Path to `ServiceModel.json` |
| `scopeBindingsPath` | Path to `ScopeBindings.json` |
| `name` | Rollout display name |
| `rolloutType` | Rollout classification (e.g., `Major`) |
| `buildSource.parameters.versionFile` | `buildver.txt` — load-bearing handoff between Build and Deploy |
| `notification.email.to` | Operator notification distribution list |

> **Do not author a custom `rollback.criteria.{healthCheckFailure,deploymentFailure}` block.** That shape does not match the Ev2 v1 RolloutSpec schema. Ev2 Managed SDP handles rollback/halt automatically via stage-map bake gates — see "Bake Times" below.

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

> **Exception**: JSON parameter files that use deployment-pipeline scope binding replacements (`{{...}}` tokens) cannot be migrated to `.bicepparam` because the Bicep compiler does not support placeholder syntax. Keep these as `.parameters.json` with an inline comment explaining the constraint.

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

## Service Group Naming — Stable Spec, Pipeline-Time `.npe` Override

`ServiceModel.json` (and `ServiceSpecification.json`) declare the **stable canonical Service Group name**. Environment-ring suffixes (specifically `.npe` for NPE) are applied **at pipeline-time** via `serviceGroupOverride` on the ev2 block of the NPE stage. Production rings (PPE + PROD) use the bare name.

| Layer | Value |
|-------|-------|
| `ServiceModel.json` `serviceGroup` | `Microsoft.M365.<SERVICE_GROUP>` (stable; no suffix) |
| Pipeline NPE stage `serviceGroupOverride` | `Microsoft.M365.<SERVICE_GROUP>.npe` |
| Pipeline production stage `serviceGroupOverride` | `Microsoft.M365.<SERVICE_GROUP>` (bare name) |

```json
// ServiceModel.json — stable canonical name
{
  "serviceMetadata": {
    "serviceGroup": "Microsoft.M365.<SERVICE_GROUP>"
  }
}
```

```yaml
# Pipeline NPE stage ev2 block applies the .npe suffix
ev2:
  serviceGroupOverride: "Microsoft.M365.<SERVICE_GROUP>.npe"   # NPE only
  ...

# Pipeline production stage ev2 block uses the bare name (PPE + PROD via rings)
ev2:
  serviceGroupOverride: "Microsoft.M365.<SERVICE_GROUP>"        # PPE + PROD
  ...
```

This matches `configuringPpeAndProdRings.md:553,604`. Do NOT bake `.npe` / `.test` / `.ppe` / `.prod` into `ServiceModel.json` — keep the spec name stable; the pipeline applies the NPE suffix at deploy time.

### Region Selection (Two Canonical Forms + a Hybrid)

There are two valid ways to tell Ev2 which regions to deploy to for each ring (per `configuringPpeAndProdRings.md:617-651`). Choose whichever fits your team's workflow. The choice affects whether `Register-AzureServicePresence` is needed on the SAW.

**Option A — Registered presence + `rings()` select** (used by the canonical example pipeline):

```yaml
select: rings(PPE,PROD)
```

| Pros | Cons |
|------|------|
| Pipeline YAML stays clean | Region list is not visible in pipeline YAML |
| No pipeline changes when adding a region | Requires SAW access to update presence (`Register-AzureServicePresence`) |

**Option B — Explicit regions in `select`** (skip presence registration, regions visible in YAML):

Per the [Service Presence docs](https://eng.ms/docs/products/ev2/features/rollout-orchestration/service-presence): *"Service presence is not required to be registered when a specific region is selected explicitly."* Ev2 auto-registers presence after a successful deployment.

```yaml
# Same regions for both rings
select: rings(PPE).regions(westus3,eastus,northeurope,westeurope), rings(PROD).regions(westus3,eastus,northeurope,westeurope)

# Different regions per ring
select: rings(PPE).regions(westus3,eastus), rings(PROD).regions(westus3,eastus,northeurope,westeurope)
```

| Pros | Cons |
|------|------|
| Region list is visible in pipeline YAML | Pipeline YAML must be updated when regions change |
| No SAW access needed to add/remove regions | Can get verbose with many regions |

**Three canonical forms** (used in different stages of the same pipeline):

| Form | When | Example |
|------|------|---------|
| `select: regions(<NPE_REGIONS>)` | NPE stage (no rings) | `select: regions(westus3,eastus)` |
| `select: rings(PPE,PROD)` | Production stage, Option A | (registered presence resolves regions) |
| `select: rings(PPE).regions(...), rings(PROD).regions(...)` | Production stage, Option B | (explicit per-ring regions) |

---

### Promotion Gates (RING-006, IMPORTANT — two-level semantic)

LENS pipelines have **two distinct levels of `manual:` semantics**, and conflating them is the most common false-positive in pipeline audits.

| Level | Where it appears | What `manual: true` means | What `manual: false` means |
|-------|------------------|---------------------------|----------------------------|
| **Outer (between rings)** | `StageMap.rings.json` → `configuration.promotion.manual` | Operator must click "End wait" in Ev2 portal to promote PPE → PROD | Auto-promote on bake completion |
| **Per-ring (between stages within a ring)** | Inner stage maps (`StageMap.ppe.json`, `StageMap.prod.json`) per-stage `manual` | Operator must click "End wait" between Canary → Pilot → ... → Broad | Auto-progress on bake completion (this is the LENS standard) |

The canonical outer stage map has top-level `configuration.promotion.manual: true` with `timeout: P7D` (7 days) — see `configuringPpeAndProdRings.md:139-176`. Per-stage `manual: false` inside an inner stage map is **expected and correct**; do NOT raise it as an audit finding.

> **Audit rule** (per `.claude/skills/lens-pipeline-audit/skills/pipeline-audit/SKILL.md:176`): RING-006 is satisfied when the OUTER stage map has `manual: true` + `timeout: P7D`. Per-stage `manual: false` in INNER stage maps is the intended progression model.

---

### Bake Times (Ev2 Managed SDP)

LENS production deployments rely on Ev2 Managed SDP to bake between stages. Two layers of bake control matter:

| Layer | Mechanism | Default | Override |
|-------|-----------|---------|----------|
| **Between rings** (PPE → PROD) | Outer-stage-map manual promotion | 7 days max (operator clicks "End wait" in Ev2 portal) | `timeout: P7D` in `StageMap.rings.json` |
| **Between stages within a ring** (Canary → Pilot → Medium → Heavy → Broad) | Ev2 Managed SDP automatic bake | 24 hours (normal rollouts), 6 hours (emergency) | `managedValidationOverrideDuration` parameter, constrained to `PT1H` / `PT6H` / `PT24H` (PARAM-002) |

A full production deployment flows like:

```
NPE deploy
  → [Manual approval — 1 week max via ManualValidation@0]
    → PPE ring (Canary → Pilot → Medium → Heavy → Broad, with bake between each stage)
      → [Manual promotion — 7 day max via outer stage map]
        → Prod ring (Canary → Pilot → Medium → Heavy → Broad, with bake)
```

Per `configuringPpeAndProdRings.md:769-781`. The constrained-values list for `managedValidationOverrideDuration` is mandatory — free-text ISO 8601 durations are error-prone (typos like `P24H` instead of `PT24H` cause silent failures).

---

### Lockbox `releaseReason` (CONFIG-003)

Production stage approval blocks include a `releaseReason` field on the lockbox `scope`. Use the canonical LENS-wide format:

```yaml
releaseReason: "Deploy <SERVICE_NAME> to PPE + Prod - MOBRV2 Pipeline"
```

Per `configuringPpeAndProdRings.md:663` + `pipeline-standards-catalog.md:166-170`. A consistent `releaseReason` makes life easier for lockbox approvers — they can quickly identify which service and environment the request is for, rather than parsing free-form text.

| Field | Constraint |
|-------|------------|
| `releaseReason` | Max 256 chars; follow the standard format |
| `serviceGroupName` | Mandatory (AUTH-003); must match `ServiceModel.json` `serviceGroup` |
| `subscriptionIds` | Mandatory (AUTH-004); list of all ring subscriptions (PPE + PROD) |

---

### Stage Map Naming + Version Semantics (RING-004)

LENS uses three stage maps per service: one outer + one inner per ring.

| Map | File | Naming | Registration |
|-----|------|--------|--------------|
| Outer (ring orchestration) | `StageMap.rings.json` | `Microsoft.M365.<Project>.rings.StageMap` | None (read from artifacts via `StageMapPath`) |
| Inner PPE | `StageMap.ppe.json` | `Microsoft.M365.<Project>.PPE.StageMap` | Required (registered via `New-AzureServiceStageMap`) |
| Inner PROD | `StageMap.prod.json` | `Microsoft.M365.<Project>.PROD.StageMap` | Required (registered via `New-AzureServiceStageMap`) |

Per `configuringPpeAndProdRings.md:74-127`. Inner stage maps follow the `Microsoft.M365.<Project>.<Ring>.StageMap` naming pattern with a `version` field that increments on change. The outer map is referenced via `StageMapPath: StageMap.rings.json` in the pipeline (no registration needed); inner maps are referenced via `StageMapName` + `StageMapVersion` for NPE, and via `<RING_NAME>.StageMap/*` (latest version) within the outer map for PPE/PROD.

Registration scripts SHOULD read `name` and `version` from the JSON file rather than hardcoding to avoid drift.

---

### Torus Tenancy

All LENS services deploy to **PrdTRS in the Torus tenant** (`cdc5aeea-15c5-4db6-b079-fcadd2505dc2`). Both PPE and PROD rings have `rolloutInfra: Prod` and the same `tenantId` — that is why both are `isProduction: true` in the pipeline and why they MUST be rings within a single production stage (RING-001).

```json
// StageMap.rings.json — both rings share the same Torus tenant
"rings": [
  {
    "name": "PPE",
    "rolloutInfra": "Prod",
    "tenantId": "cdc5aeea-15c5-4db6-b079-fcadd2505dc2",
    "stageMap": "Microsoft.M365.<YOUR_PROJECT>.ppe.StageMap/*"
  },
  {
    "name": "PROD",
    "rolloutInfra": "Prod",
    "tenantId": "cdc5aeea-15c5-4db6-b079-fcadd2505dc2",
    "stageMap": "Microsoft.M365.<YOUR_PROJECT>.prod.StageMap/*"
  }
]
```

Base config files reference the Torus tenant via the `$(aad.tenants.Torus.id)` ScopeBindings token. Per `configuringPpeAndProdRings.md:153,159,225`.

---

### Ev2 Registrations (LENS-specific)

Once your stage maps, configuration files, and RolloutSpec are in place, Ev2 needs the service, rings, subscriptions, and inner stage maps to be registered. These registrations require a SAW (Secure Access Workstation) machine and Entra ID **LENS Contributor Group elevation** (see `ado-workflow.md` § "Azure Deployment Pipeline Prerequisites").

Pointer-only summary (full canonical guidance: `configuringPpeAndProdRings.md:346-465` + `LENSEv2Standards.md:76`):

| Registration | Cmdlet | Notes |
|--------------|--------|-------|
| Service | `New-AzureServiceRolloutServiceRegistration` | One-time per service; usually already done by other Ev2 deployments in PrdTRS01 |
| Service Group | `New-AzureServiceRolloutServiceGroupRegistration` | Auto-registered by pipeline during Artifact Registration; manual command available as fallback |
| Ring | `New-AzureServiceRing` | One per ring (PPE, PROD) |
| Ring Subscription | `Register-AzureServiceSubscription` | One per ring with the ring's Torus subscription ID |
| Service Presence | `Register-AzureServicePresence` | Optional — required only for region-selection Option A; skipped for Option B |
| Inner Stage Map | `New-AzureServiceStageMap` | One per inner stage map (PPE, PROD); copy JSON files to SAW first |

Important per `LENSEv2Standards.md:76`:

- `ServiceSpecification.json` MUST NOT provide `OwnerGroupObjectId` — it is automatically resolved via ServiceTree integration. This requires the security group to be correctly configured in the ServiceTree Metadata.
- The outer stage map (`StageMap.rings.json`) does NOT need registration — it is read from build artifacts via `StageMapPath`.
- Ring **configuration** (environment-specific values in `Configuration/`) is loaded from artifacts via `ringScope` and does not need to be registered.

---

### Scope Bindings vs Config Files

Environment-specific values belong in per-environment config files, NOT in ScopeBindings.json:

```
CORRECT: Config values in Parameters/test.json, Parameters/ppe.json, etc.
WRONG:   Config values embedded directly in ScopeBindings.json
```

### Rollout Step Naming

Use a consistent convention for step naming: `Deploy` + resource type (e.g., `DeployRegionAppService`, `DeployGeoTrafficManagerProfile`). Avoid redundant prefixes when deployment-pipeline context already implies deployment.

| Pattern | Status |
|---------|--------|
| `.test` / `.npe` / `.ppe` baked into `ServiceModel.json` `serviceGroup` | **REJECT** (use `serviceGroupOverride` at pipeline-time instead) |
| Config values in ScopeBindings instead of parameter files | **WARN** |
| JSON comments in deployment configuration files | **WARN** (JSON spec doesn't support comments) |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach | Status |
|--------------|------------------|--------|
| Direct production deployment | Go through PPE first | **REJECT** |
| Hardcoded parameters | Use parameter files per environment | **REJECT** |
| Secrets in parameter files | Use Key Vault references | **REJECT** |
| Custom `rollback.criteria` block in `RolloutSpec` | Trust Ev2 Managed SDP bake gates (see "Bake Times" section + RolloutSpec callout above); rollback / halt is automatic on stage-map failure thresholds — do not author a custom block (shape doesn't match v1 schema) | **REJECT** |
| Single region deployment | Deploy to paired regions | **WARN** |
| Committed compiled ARM JSON alongside Bicep source | Gitignore generated JSON, build from Bicep in pipeline | **REJECT** |
| `.parameters.json` when `.bicepparam` available | Use `.bicepparam` for type safety | **WARN** |
| Targeting preview runtime without verification | Verify GA status with `az webapp list-runtimes` | **WARN** |
| Environment suffix in `ServiceModel.json` `serviceGroup` | Stable name in spec; apply `.npe` etc. via pipeline `serviceGroupOverride` | **REJECT** |
| Config values in ScopeBindings.json | Use per-environment parameter files | **WARN** |
