# LENS Pipeline Standards Catalog

**Source**: `LENS-Docs/sources/docs/enghub/core/content/CreatingServices/configuringPpeAndProdRings.md`
**Extracted**: 2026-04-20
**Status**: All source documents are in preview state and subject to change.

> **DISCLAIMER**: All LENS-Docs documents are marked "preview state" and subject to change.
> Standards below reflect the current text as of extraction date.

## Obligation Model

| Tier | Weight | Language |
|------|--------|----------|
| REQUIREMENT | 3x | "must", "must not", "mandated", "required", "do not" |
| STANDARD | 2x | Declared as the standard, imperative recommendation |
| RECOMMENDATION | 1x | "should", "recommended", "preferred" |

---

## Category: Ring Architecture (RING)

### RING-001: PPE and Prod as rings in single production stage
- **Tier**: REQUIREMENT (weight 3x)
- **Exact quote**: "1ES enforces a limit of **one production Ev2 stage per cloud** (e.g., Public). Both PPE and Prod environments are `isProduction: true` because both deploy to PrdTRS. This means they cannot be separate pipeline stages. They **must** be **rings within a single production stage**."
- **Source**: configuringPpeAndProdRings.md — "Why Rings Are Required"
- **Check**: Pipeline has exactly one stage with `isProduction: true`; that stage uses ring-based deployment (`StageMapPath` referencing the outer ring map or `select: rings(...)`)
- **Violation signal**: Multiple `isProduction: true` stages (separate PPE and PROD stages)

### RING-002: Production stage isProduction flag
- **Tier**: REQUIREMENT (weight 3x)
- **Exact quote**: "1ES restricts pipelines to **one production Ev2 stage per cloud** (e.g., Public). Since both PPE and Prod are `isProduction: true` (both deploy to PrdTRS), they **must** be rings within a single stage, not separate stages."
- **Source**: configuringPpeAndProdRings.md — "Production Stage (PPE + Prod via Rings)"
- **Check**: The single production stage has `isProduction: true`

### RING-003: Outer ring stage map via StageMapPath
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "Use `StageMapPath` for the **outer ring orchestration map** (simplifies deployment, no registration needed)."
- **Source**: configuringPpeAndProdRings.md — "StageMapPath vs StageMapName"
- **Check**: Production stage ev2 block contains `StageMapPath: StageMap.rings.json`

### RING-004: 5-stage inner stage maps
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "All LENS services should use **5-stage** stage maps" with stages: Canary, Pilot, Medium, Heavy, Broad
- **Source**: configuringPpeAndProdRings.md — "Creating Inner Stage Maps (Per-Ring)"
- **Check**: Each inner stage map JSON has exactly 5 stages named Canary, Pilot, Medium, Heavy, Broad (in order)
- **Note**: Applies to `StageMap.ppe.json` and `StageMap.prod.json` if provided

### RING-005: REMAINING_REGIONS in final stage of inner stage maps
- **Tier**: RECOMMENDATION (weight 1x)
- **Exact quote**: "**Always include `REMAINING_REGIONS`** in the last stage. This lets Ev2 auto-split remaining regions into sequential stages honoring region pairs"
- **Source**: configuringPpeAndProdRings.md — "Creating Inner Stage Maps (Per-Ring)"
- **Check**: Last stage (Broad) in each inner stage map contains `"REMAINING_REGIONS"`

### RING-006: Manual promotion in outer stage map
- **Tier**: RECOMMENDATION (weight 1x)
- **Exact quote**: "**`configuration.promotion.manual: true`** with `timeout: P7D` (7 days). Requires an operator to click 'End wait' in the Ev2 portal to promote from PPE to Prod."
- **Source**: configuringPpeAndProdRings.md — "Creating the Outer Stage Map (Ring Orchestration)"
- **Check**: Outer stage map (`StageMap.rings.json`) has `promotion.manual: true` and `timeout: "P7D"`

---

## Category: Pipeline Parameters (PARAM)

### PARAM-001: rolloutType constrained to normal and emergency
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "Only `normal` and `emergency` rollout types are supported. **Decision:** LENS severity practices mean `globaloutage` does not apply to our services."
- **Source**: configuringPpeAndProdRings.md — "Rollout Type"
- **Check**: `rolloutType` parameter `values:` list contains only `normal` and `emergency` (not `globaloutage`, not free-text)
- **Violation signal**: `globaloutage` in values, or parameter is type `string` without constrained `values:` list

### PARAM-002: managedValidationOverrideDuration constrained to PT1H/PT6H/PT24H
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "**Standard:** Use constrained values (`PT1H`, `PT6H`, `PT24H`), not free-text input. **Decision:** Free-text ISO 8601 durations are error-prone (typos like `P24H` instead of `PT24H` cause silent failures)."
- **Source**: configuringPpeAndProdRings.md — "Managed Validation Override Duration"
- **Check**: `managedValidationOverrideDuration` parameter has `values: [PT1H, PT6H, PT24H]` (exactly these three, no others)
- **Violation signal**: Free-text parameter (no `values:` list), or values list differs from `[PT1H, PT6H, PT24H]`

---

## Category: Feature Flags (FLAG)

### FLAG-001: enableContinuousApproval: true
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "**Standard:** Enable `enableContinuousApproval: true`. **Decision:** When a pipeline has multiple production stages (or ring-based progression), each stage would normally require a separate lockbox approval. Continuous approval reduces this to a single approval for the entire rollout."
- **Source**: configuringPpeAndProdRings.md — "Feature Flags"
- **Check**: `featureFlags.enableContinuousApproval: true` present at the pipeline extends level

---

## Category: Artifact Registration (AREG)

### AREG-001: forceRegistration: true on ALL stages
- **Tier**: REQUIREMENT (weight 3x)
- **Exact quote**: "Both flags should be set on **every** stage (NPE, PPE+Prod). They are safe for all environments and prevent the most common deployment failures during iterative development."
- **Source**: configuringPpeAndProdRings.md — "Artifact Registration Flags"
- **Check**: Every ev2 block in every release job has `forceRegistration: true`
- **Violation signal**: Any ev2 block missing `forceRegistration: true`

### AREG-002: skipRegistrationIfExists: true on ALL stages
- **Tier**: REQUIREMENT (weight 3x)
- **Exact quote**: "Both flags should be set on **every** stage (NPE, PPE+Prod)."
- **Source**: configuringPpeAndProdRings.md — "Artifact Registration Flags"
- **Check**: Every ev2 block in every release job has `skipRegistrationIfExists: true`
- **Violation signal**: Any ev2 block missing `skipRegistrationIfExists: true`

---

## Category: Security & Auth (AUTH)

### AUTH-001: Production stage uses workflow: lockbox
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: Example pipeline shows `workflow: lockbox` for production stage; NPE uses `workflow: test`
- **Source**: configuringPpeAndProdRings.md — "Production Stage (PPE + Prod via Rings)"
- **Check**: Production stage (`isProduction: true`) approval block has `workflow: lockbox`

### AUTH-002: No serviceConnection on production stage
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "Unlike the NPE stage, production stages do not use a `serviceConnection`. Torus JIT + lockbox handles authentication automatically. **Do not add a `serviceConnection` here.**"
- **Source**: configuringPpeAndProdRings.md — "No Service Connection Needed"
- **Check**: Production stage ev2 block does NOT contain `serviceConnection:`

### AUTH-003: Lockbox scope has serviceGroupName
- **Tier**: REQUIREMENT (weight 3x)
- **Exact quote**: "Per lockbox documentation, `serviceGroupName` and `subscriptionIds` are **mandatory**. Without them, the lockbox request will fail."
- **Source**: configuringPpeAndProdRings.md — "Lockbox Scope Parameters"
- **Check**: Production stage approval scope has `serviceGroupName:` set to a non-empty value

### AUTH-004: Lockbox scope has subscriptionIds
- **Tier**: REQUIREMENT (weight 3x)
- **Exact quote**: "`serviceGroupName` and `subscriptionIds` are **mandatory**. Without them, the lockbox request will fail."
- **Source**: configuringPpeAndProdRings.md — "Lockbox Scope Parameters"
- **Check**: Production stage approval scope has `subscriptionIds:` list with at least one entry

---

## Category: Approval Gates (GATE)

### GATE-001: ManualValidation@0 between NPE and production
- **Tier**: STANDARD (weight 2x)
- **Exact quote**: "Add this manual approval stage between your NPE and production stages. It prevents unintended progression to production environments."
- **Source**: configuringPpeAndProdRings.md — "Manual Validation & Bake Times"
- **Check**: A stage using `ManualValidation@0` task exists as a dependency of the production stage (appears in production stage's `dependsOn`)

### GATE-002: Manual approval timeout 10080 minutes
- **Tier**: RECOMMENDATION (weight 1x)
- **Exact quote**: Example pipeline shows `timeoutInMinutes: 10080` (1 week) on both the stage and the ManualValidation task
- **Source**: configuringPpeAndProdRings.md — "Layer 1: Human Approval Gates"
- **Check**: ManualValidation stage and task both have `timeoutInMinutes: 10080`

---

## Category: Configuration Files (CONFIG)

### CONFIG-001: Base + PPE + PROD ring override configs
- **Tier**: RECOMMENDATION (weight 1x)
- **Exact quote**: "Create these files in `ServiceGroupRoot/Configuration/`: `Microsoft.M365.<YourService>.json` (base), `Microsoft.M365.<YourService>.ppe.json` (PPE overrides), `Microsoft.M365.<YourService>.prod.json` (PROD overrides)"
- **Source**: configuringPpeAndProdRings.md — "Ring Configuration"
- **Check**: ServiceGroupRoot/Configuration/ contains a base JSON, a `.ppe.json` override, and a `.prod.json` override

### CONFIG-002: ringScope in RolloutSpec for PPE and PROD
- **Tier**: RECOMMENDATION (weight 1x)
- **Exact quote**: "Add the `ringScope` array alongside your existing `serviceGroupScope`" with entries for PPE and PROD rings
- **Source**: configuringPpeAndProdRings.md — "Adding ringScope"
- **Check**: RolloutSpec.json contains `rolloutMetadata.configuration.ringScope` with PPE and PROD entries

### CONFIG-003: Standard releaseReason format
- **Tier**: RECOMMENDATION (weight 1x)
- **Exact quote**: "Use a consistent `releaseReason` format across all LENS services: `'Deploy <SERVICE_NAME> to PPE + Prod - MOBRV2 Pipeline'`"
- **Source**: configuringPpeAndProdRings.md — "Lockbox Scope Parameters"
- **Check**: `releaseReason` follows pattern "Deploy [NAME] to PPE + Prod - MOBRV2 Pipeline"

---

## Summary

| Category | ID | Tier | Short Name |
|----------|----|------|------------|
| Ring Architecture | RING-001 | REQUIREMENT | PPE+Prod single production stage |
| Ring Architecture | RING-002 | REQUIREMENT | isProduction: true on prod stage |
| Ring Architecture | RING-003 | STANDARD | StageMapPath for outer ring map |
| Ring Architecture | RING-004 | STANDARD | 5-stage inner stage maps |
| Ring Architecture | RING-005 | RECOMMENDATION | REMAINING_REGIONS in Broad stage |
| Ring Architecture | RING-006 | RECOMMENDATION | Manual promotion P7D timeout |
| Pipeline Parameters | PARAM-001 | STANDARD | rolloutType: normal/emergency only |
| Pipeline Parameters | PARAM-002 | STANDARD | managedValidationOverrideDuration: PT1H/PT6H/PT24H |
| Feature Flags | FLAG-001 | STANDARD | enableContinuousApproval: true |
| Artifact Registration | AREG-001 | REQUIREMENT | forceRegistration: true all stages |
| Artifact Registration | AREG-002 | REQUIREMENT | skipRegistrationIfExists: true all stages |
| Security & Auth | AUTH-001 | STANDARD | Production uses workflow: lockbox |
| Security & Auth | AUTH-002 | STANDARD | No serviceConnection on production |
| Security & Auth | AUTH-003 | REQUIREMENT | Lockbox scope serviceGroupName |
| Security & Auth | AUTH-004 | REQUIREMENT | Lockbox scope subscriptionIds |
| Approval Gates | GATE-001 | STANDARD | ManualValidation@0 gate |
| Approval Gates | GATE-002 | RECOMMENDATION | Approval timeout 10080 min |
| Configuration | CONFIG-001 | RECOMMENDATION | Base+PPE+PROD config files |
| Configuration | CONFIG-002 | RECOMMENDATION | ringScope in RolloutSpec |
| Configuration | CONFIG-003 | RECOMMENDATION | releaseReason standard format |
