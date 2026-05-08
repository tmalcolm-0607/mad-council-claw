---
name: pipeline-audit
description: Audit a LENS release pipeline YAML for compliance with PPE/Prod ring-based deployment standards from configuringPpeAndProdRings.md. Generates a scored compliance report with remediation guidance. Use when asked to audit a pipeline, check release pipeline compliance, or verify a pipeline meets LENS standards.
allowed-tools: Read, Write, Bash, Grep, Glob, Agent
user-invocable: true
---

<!-- TODO: source — LENS-Common plugins/LENS/Quality/lens-pipeline-audit (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. -->

# LENS Pipeline Audit

Audit a LENS release pipeline YAML (and optionally stage maps and RolloutSpec) against the 20 standards defined in `configuringPpeAndProdRings.md`. Output a scored compliance report with evidence for each check and remediation steps for every gap.

## Usage

```
/lens-pipeline-audit:pipeline-audit                                       # Auto-discover pipeline in cwd
/lens-pipeline-audit:pipeline-audit --pipeline path/to/pipeline.yml       # Audit specific pipeline file
/lens-pipeline-audit:pipeline-audit --pipeline p.yml --ev2 path/to/Ev2/  # Pipeline + Ev2 artifacts dir
/lens-pipeline-audit:pipeline-audit --output ./reports/                   # Custom output directory
/lens-pipeline-audit:pipeline-audit --standards-only                      # Print catalog without auditing
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--pipeline` | auto-discover | Path to pipeline YAML file |
| `--ev2` | auto-discover | Path to Ev2 ServiceGroupRoot directory (for stage maps, RolloutSpec, config files) |
| `--output` | `./lens-pipeline-audit/` | Output directory for report files |
| `--standards-only` | false | Print the standards catalog without auditing |

## Standards Reference

This skill audits against 20 standards extracted from `configuringPpeAndProdRings.md` using the same 3-tier obligation model as `lens-standards-audit`:

| Tier | Weight | Language in source |
|------|--------|--------------------|
| REQUIREMENT | 3x | "must", "mandatory", "required" |
| STANDARD | 2x | Declared as the standard, imperative |
| RECOMMENDATION | 1x | "should", "recommended" |

Full catalog: `rules/pipeline-standards-catalog.md` in this plugin.

---

## Behavior

### Phase 0: Discover Artifacts

1. Locate the pipeline YAML:
   - Use `--pipeline` argument if provided
   - Otherwise search `cwd` for files matching: `*release*.yml`, `*Release*.yml`, `*pipeline*.yml`, `*Pipeline*.yml`
   - Also look in `.pipelines/`, `pipelines/`, `sources/dev/*/pipelines/`, `sources/dev/*/src/Ev2/`
   - If multiple candidates found, list them and ask the user to confirm

2. Locate Ev2 artifacts (stage maps, RolloutSpec, config files):
   - Use `--ev2` argument if provided
   - Otherwise search from the pipeline file's directory and nearby for `ServiceGroupRoot/`
   - Look for these specific files (all optional — skip checks that need them if not found):
     - `ServiceGroupRoot/StageMap.ppe.json`
     - `ServiceGroupRoot/StageMap.prod.json`
     - `ServiceGroupRoot/StageMap.rings.json`
     - `ServiceGroupRoot/RolloutSpec.json` (or `RolloutSpec.App.json`)
     - `ServiceGroupRoot/Configuration/` — any `*.json` files

3. If no pipeline file found: ABORT with:
   ```
   No pipeline YAML found. Provide the path explicitly:
     /lens-pipeline-audit:pipeline-audit --pipeline path/to/your-pipeline.yml
   ```

4. If `--standards-only` specified: print the standards catalog from `rules/pipeline-standards-catalog.md` and STOP.

---

### Phase 1: Read Artifacts

Read all discovered artifacts:
- Pipeline YAML (full file)
- Each stage map JSON found
- RolloutSpec.json if found
- Configuration directory file listing and content of JSON files found

**Extract Registration Parameters**: While reading, capture these values — they are used to populate the Ev2 Registration Commands section in the audit report:

| Parameter | Source |
|-----------|--------|
| `serviceTreeId` | `extends.parameters.serviceTreeId` in the pipeline YAML |
| `serviceGroupName` | Production stage `templateContext.approval.scope.serviceGroupName` |
| `subscriptionIds` | Full list from `templateContext.approval.scope.subscriptionIds` in the production stage |
| Ring names | Each stage `name` in `StageMap.rings.json` |
| PPE stage map name + version | `name` and `version` fields in `StageMap.ppe.json` |
| PROD stage map name + version | `name` and `version` fields in `StageMap.prod.json` |
| Deployment regions | Default values of the `select:` or `regions` parameter in the pipeline YAML; also from inner stage map region entries |

If any value is not found in the artifacts, use `<NOT-FOUND>` as the placeholder in the generated commands — do not omit the command block.

---

### Phase 2: Audit Each Standard

Evaluate all 20 standards in order. For each standard:

1. **Identify** what to look for (specified per-standard below)
2. **Search** the appropriate artifact file
3. **Assign status** using the scoring table
4. **Record evidence**: file path + line number or excerpt (quote the actual text found)
5. **Write remediation** if not COMPLIANT

#### Scoring Table

| Status | Score | Use when |
|--------|-------|----------|
| COMPLIANT | 100% | Found exact evidence meeting the standard |
| PARTIAL | 50% | Partially meets the standard (e.g., present on some stages but not all) |
| NON-COMPLIANT | 0% | REQUIREMENT or STANDARD tier; definitively absent or violated |
| NOT-ADOPTED | 0% | RECOMMENDATION tier; not followed (not a failure) |
| NOT-APPLICABLE | N/A | Standard cannot apply to this pipeline (justify why) |

#### Confidence Table

| Confidence | Use when |
|------------|----------|
| HIGH | Clear evidence (exact field found at specific line) |
| MEDIUM | Indirect evidence or partial match |
| LOW | Cannot confirm without running the pipeline; manual review recommended |

---

### Audit Checks (all 20 standards)

#### RING-001 [REQUIREMENT]: PPE and Prod in single production stage
- **File**: Pipeline YAML
- **How to check**: Count stages with `isProduction: true`. Look for evidence of ring-based deployment: `StageMapPath`, `select: rings(...)`, or `workflow: lockbox` + `ringScope` references.
- **COMPLIANT**: Exactly one `isProduction: true` stage; that stage deploys PPE and Prod via rings (not two separate stages)
- **NON-COMPLIANT**: Two or more `isProduction: true` stages, OR separate PPE and PROD stages each with `isProduction: true`
- **PARTIAL**: One production stage exists but ring configuration is incomplete/ambiguous
- **Remediation**: Collapse PPE and Prod into a single stage with `isProduction: true` using `StageMapPath: StageMap.rings.json` and ring-based select.

#### RING-002 [REQUIREMENT]: Production stage has isProduction: true
- **File**: Pipeline YAML
- **How to check**: Find the stage that deploys to PPE/Prod environments. Check `templateContext.isProduction`.
- **COMPLIANT**: Stage targeting PPE/Prod has `isProduction: true`
- **NON-COMPLIANT**: PPE/Prod stage missing `isProduction: true` or set to `false`
- **Remediation**: Add `isProduction: true` to `templateContext` of the production stage.

#### RING-003 [STANDARD]: Outer ring stage map via StageMapPath
- **File**: Pipeline YAML
- **How to check**: Find the production stage ev2 block. Look for `StageMapPath:`.
- **COMPLIANT**: Production ev2 block contains `StageMapPath: StageMap.rings.json` (or equivalent path)
- **NON-COMPLIANT**: Production stage uses `StageMapName` + `StageMapVersion` for the ring orchestration map, or StageMapPath is absent
- **Remediation**: Replace `StageMapName`/`StageMapVersion` with `StageMapPath: StageMap.rings.json` in the production stage ev2 block.

#### RING-004 [STANDARD]: 5-stage inner stage maps
- **File**: `StageMap.ppe.json` and `StageMap.prod.json` (if available)
- **How to check**: Read the `stages` array. Count entries and check names.
- **COMPLIANT**: Exactly 5 stages named Canary, Pilot, Medium, Heavy, Broad (in sequence order 1–5)
- **NON-COMPLIANT**: Fewer than 5 stages, or different stage names
- **NOT-APPLICABLE**: Stage map files not provided/found
- **Remediation**: Restructure stage maps to use the 5-stage pattern: Canary (seq 1), Pilot (seq 2), Medium (seq 3), Heavy (seq 4), Broad (seq 5).

#### RING-005 [RECOMMENDATION]: REMAINING_REGIONS in Broad stage
- **File**: `StageMap.ppe.json` and `StageMap.prod.json` (if available)
- **How to check**: Find the last stage (Broad, sequence 5). Check its `regions` array for `"REMAINING_REGIONS"`.
- **COMPLIANT**: Last stage contains `"REMAINING_REGIONS"` in its regions list
- **NOT-ADOPTED**: Last stage does not include `"REMAINING_REGIONS"`
- **NOT-APPLICABLE**: Stage map files not provided/found
- **Remediation**: Add `"REMAINING_REGIONS"` to the `regions` array of the Broad stage.

#### RING-006 [RECOMMENDATION]: Outer stage map manual promotion with P7D
- **File**: `StageMap.rings.json` (if available)
- **How to check**: Check `configuration.promotion.manual` and `configuration.promotion.timeout` at the **top level** of the stage map.
- **COMPLIANT**: Top-level `configuration.promotion.manual: true` and `configuration.promotion.timeout: "P7D"`
- **NOT-ADOPTED**: Top-level `manual` is false, missing, or timeout differs from P7D
- **NOT-APPLICABLE**: Outer stage map not provided/found
- **Remediation**: Set `configuration.promotion.manual: true` and `configuration.promotion.timeout: "P7D"` in `StageMap.rings.json`.
- **IMPORTANT — two-level promotion**: Individual stages may override `promotion.manual: false` to disable manual gates **between rings within the same stage** (e.g., PPE-Foundation → PPE automatic, to avoid gates between geo-resources and region-resources). This is intentional and does NOT negate the top-level gate. The top-level `manual: true` controls promotion **between stages** (PreProduction → Production, i.e., PPE → PROD). Do NOT flag per-stage `manual: false` overrides as non-compliant if the top-level `manual: true` is present — they serve different purposes.

#### PARAM-001 [STANDARD]: rolloutType constrained to normal and emergency
- **File**: Pipeline YAML
- **How to check**: Find the `rolloutType` parameter. Check its `type`, `values:` list.
- **COMPLIANT**: Parameter has `type: string` with `values:` containing exactly `normal` and `emergency` (and nothing else)
- **NON-COMPLIANT**: Parameter is free-text without constrained values, OR `globaloutage` appears in the values list, OR `rolloutType` parameter is absent entirely
- **PARTIAL**: Parameter exists with constrained values but includes `globaloutage` alongside normal/emergency
- **Remediation**:
  ```yaml
  - name: rolloutType
    displayName: Rollout type (normal or emergency)
    type: string
    default: normal
    values:
    - normal
    - emergency
  ```

#### PARAM-002 [STANDARD]: managedValidationOverrideDuration constrained to PT1H/PT6H/PT24H
- **File**: Pipeline YAML
- **How to check**: Find `managedValidationOverrideDuration` parameter. Check its `values:` list.
- **COMPLIANT**: Parameter has `values: [PT1H, PT6H, PT24H]` — exactly these three, in any order
- **NON-COMPLIANT**: Free-text parameter without constrained values, OR parameter absent entirely
- **PARTIAL**: Parameter has constrained values but includes items outside [PT1H, PT6H, PT24H]
- **Remediation**:
  ```yaml
  - name: managedValidationOverrideDuration
    displayName: Managed Validation Override Duration (in ISO 8601 format)
    type: string
    default: PT24H
    values:
    - PT1H
    - PT6H
    - PT24H
  ```

#### FLAG-001 [STANDARD]: enableContinuousApproval: true
- **File**: Pipeline YAML
- **How to check**: Find the `extends.parameters.featureFlags` section. Look for `enableContinuousApproval`.
- **COMPLIANT**: `featureFlags.enableContinuousApproval: true` is present
- **NON-COMPLIANT**: `enableContinuousApproval` is absent, or set to `false`
- **Remediation**:
  ```yaml
  extends:
    template: ...
    parameters:
      featureFlags:
        enableContinuousApproval: true
  ```

#### AREG-001 [REQUIREMENT]: forceRegistration: true on ALL stages
- **File**: Pipeline YAML
- **How to check**: Find every `ev2:` block across all release jobs. Check each for `forceRegistration: true`.
- **COMPLIANT**: Every ev2 block has `forceRegistration: true`
- **PARTIAL**: Some but not all ev2 blocks have `forceRegistration: true` (list which stages are missing it)
- **NON-COMPLIANT**: No ev2 blocks have `forceRegistration: true`
- **Remediation**: Add `forceRegistration: true` to every ev2 block (NPE, production, and any other release stages).

#### AREG-002 [REQUIREMENT]: skipRegistrationIfExists: true on ALL stages
- **File**: Pipeline YAML
- **How to check**: Find every `ev2:` block. Check each for `skipRegistrationIfExists: true`.
- **COMPLIANT**: Every ev2 block has `skipRegistrationIfExists: true`
- **PARTIAL**: Some but not all ev2 blocks have it (list which stages are missing it)
- **NON-COMPLIANT**: No ev2 blocks have `skipRegistrationIfExists: true`
- **Remediation**: Add `skipRegistrationIfExists: true` to every ev2 block.

#### AUTH-001 [STANDARD]: Production stage uses workflow: lockbox
- **File**: Pipeline YAML
- **How to check**: Find the production stage (`isProduction: true`). Check `templateContext.approval.workflow`.
- **COMPLIANT**: Production stage approval has `workflow: lockbox`
- **NON-COMPLIANT**: Production stage uses `workflow: test` or a direct serviceConnection instead of lockbox
- **Remediation**: Change `workflow:` to `lockbox` in the production stage approval block.

#### AUTH-002 [STANDARD]: No serviceConnection on production stage
- **File**: Pipeline YAML
- **How to check**: Find the production stage ev2 block. Check for presence of `serviceConnection:`.
- **COMPLIANT**: `serviceConnection:` is absent from the production stage ev2 block
- **NON-COMPLIANT**: `serviceConnection:` is present in the production stage ev2 block
- **Remediation**: Remove `serviceConnection:` from the production stage ev2 block. Lockbox handles auth automatically.

#### AUTH-003 [REQUIREMENT]: Lockbox scope has serviceGroupName
- **File**: Pipeline YAML
- **How to check**: Find the production stage `templateContext.approval.scope`. Check for `serviceGroupName:`.
- **COMPLIANT**: `scope.serviceGroupName:` is present with a non-placeholder value (not empty, not `<SERVICE_GROUP>`)
- **NON-COMPLIANT**: `serviceGroupName:` absent, or scope section missing entirely
- **PARTIAL**: `serviceGroupName:` present but still contains a placeholder (e.g., `Microsoft.M365.<SERVICE_GROUP>`)
- **Remediation**: Add `serviceGroupName: Microsoft.M365.YourServiceGroup` to the production stage `approval.scope`.

#### AUTH-004 [REQUIREMENT]: Lockbox scope has subscriptionIds
- **File**: Pipeline YAML
- **How to check**: Find the production stage `templateContext.approval.scope`. Check for `subscriptionIds:` list.
- **COMPLIANT**: `scope.subscriptionIds:` is a non-empty list (at least one entry, even if it's a placeholder)
- **NON-COMPLIANT**: `subscriptionIds:` absent or empty list
- **PARTIAL**: Present as a list but contains only placeholders (e.g., `<PPE_SUBSCRIPTION_ID>`)
- **Remediation**: Add `subscriptionIds:` with your PPE and Prod Torus subscription IDs to the production stage `approval.scope`.

#### GATE-001 [STANDARD]: ManualValidation@0 between NPE and production
- **File**: Pipeline YAML
- **How to check**: Find all stages with `ManualValidation@0` task. Check that at least one such stage is listed in the production stage's `dependsOn:`.
- **COMPLIANT**: A stage containing `ManualValidation@0` exists and is in the production stage's `dependsOn:` list
- **NON-COMPLIANT**: No ManualValidation stage exists, or it exists but is not a dependency of the production stage
- **Remediation**: Add a manual approval stage between NPE and production:
  ```yaml
  - stage: ManualApproval_BeforePPE
    displayName: Manual Approval Before PPE
    dependsOn: [Test_ReleaseStage]
    templateContext:
      cloud: Public
      isProduction: false
      approval:
        workflow: test
    jobs:
    - job: ApprovalGate
      templateContext:
        preApproval: true
      condition: always()
      pool: server
      timeoutInMinutes: 10080
      steps:
      - task: ManualValidation@0
        timeoutInMinutes: 10080
        condition: always()
        inputs:
          notifyUsers: <TEAM_EMAIL>
          instructions: "Verify NPE deployment succeeded and service is healthy before approving PPE + Prod release."
  ```
  Then add `dependsOn: [ManualApproval_BeforePPE]` to the production stage.

#### GATE-002 [RECOMMENDATION]: Manual approval timeout 10080 minutes
- **File**: Pipeline YAML
- **How to check**: Find the ManualValidation stage and task. Check `timeoutInMinutes` on both the job and the task.
- **COMPLIANT**: Both stage/job `timeoutInMinutes` and ManualValidation@0 task `timeoutInMinutes` are set to `10080`
- **NOT-ADOPTED**: Timeout is set to a different value or is absent
- **Remediation**: Set `timeoutInMinutes: 10080` on both the pool-server job and the ManualValidation@0 task step.

#### CONFIG-001 [RECOMMENDATION]: Base + PPE + PROD ring override config files
- **File**: `ServiceGroupRoot/Configuration/` directory (if available)
- **How to check**: List files in the Configuration directory. Look for three files: one base JSON (no environment suffix), one `.ppe.json`, one `.prod.json`.
- **COMPLIANT**: All three files present (base, .ppe.json, .prod.json)
- **NOT-ADOPTED**: Missing one or more override files, or all settings are in a single config file
- **NOT-APPLICABLE**: Configuration directory not provided/found
- **Remediation**: Create three configuration files in `ServiceGroupRoot/Configuration/`:
  - `Microsoft.M365.YourService.json` — shared base settings (tenantId, resource naming, etc.)
  - `Microsoft.M365.YourService.ppe.json` — PPE-specific overrides (environment: "ppe", PPE subscriptionId, etc.)
  - `Microsoft.M365.YourService.prod.json` — Prod-specific overrides (environment: "prod", Prod subscriptionId, zone redundancy, etc.)

#### CONFIG-002 [RECOMMENDATION]: ringScope in RolloutSpec
- **File**: `RolloutSpec.json` or `RolloutSpec.App.json` (if available)
- **How to check**: Read the file. Look for `rolloutMetadata.configuration.ringScope` array with PPE and PROD entries.
- **COMPLIANT**: `ringScope` array present with at least PPE and PROD ring entries, each with a `serviceGroupLevelSpecPath`
- **NOT-ADOPTED**: `ringScope` absent, or only `serviceGroupScope` present
- **NOT-APPLICABLE**: RolloutSpec not provided/found
- **Remediation**: Add `ringScope` to `rolloutMetadata.configuration`:
  ```json
  "ringScope": [
    { "ring": "PPE", "serviceGroupLevelSpecPath": "Configuration/Microsoft.M365.YourService.ppe.json" },
    { "ring": "PROD", "serviceGroupLevelSpecPath": "Configuration/Microsoft.M365.YourService.prod.json" }
  ]
  ```

#### CONFIG-003 [RECOMMENDATION]: Standard releaseReason format
- **File**: Pipeline YAML
- **How to check**: Find `releaseReason:` in the production stage scope. Check if it follows the pattern `"Deploy <NAME> to PPE + Prod - MOBRV2 Pipeline"`.
- **COMPLIANT**: Format matches "Deploy [ServiceName] to PPE + Prod - MOBRV2 Pipeline"
- **NOT-ADOPTED**: `releaseReason` absent, or uses a non-standard format
- **Remediation**: Set `releaseReason: "Deploy YourServiceName to PPE + Prod - MOBRV2 Pipeline"` in the production stage approval scope.

---

### Phase 3: Compute Scores

After evaluating all 20 standards, compute:

1. **Weighted Overall Score**:
   - COMPLIANT items: full weight × tier weight
   - PARTIAL items: 0.5 × tier weight
   - NON-COMPLIANT / NOT-ADOPTED: 0 × tier weight
   - NOT-APPLICABLE items: excluded from denominator
   - Score = (sum of earned weighted points) / (sum of applicable weighted points) × 100%

2. **Requirements-Only Score**: Percentage of REQUIREMENT tier items that are COMPLIANT or PARTIAL

3. **Standards Adoption Score**: Percentage of STANDARD tier items that are COMPLIANT or PARTIAL

4. **Recommendations Adoption Score**: Percentage of RECOMMENDATION tier items that are COMPLIANT (informational only — not a compliance gate)

5. **Gap List**: All NON-COMPLIANT and PARTIAL items, sorted by tier (REQUIREMENTS first, then STANDARDS)

---

### Phase 4: Write Report Files

Write to `{output}/`:

#### File 1: `pipeline-audit-report.md`

```markdown
# LENS Pipeline Audit Report

## Compliance Scores

| Metric | Score | Details |
|--------|-------|---------|
| Weighted Overall | {N}% | All applicable standards, tier-weighted |
| Requirements Only | {N}% ({n}/{total}) | Hard compliance gates |
| Standards Adoption | {N}% ({n}/{total}) | Declared tool/pattern standards |
| Recommendations | {N}% ({n}/{total}) | Guidance (informational only) |

**Overall verdict**: PASS / FAIL
(PASS = Requirements-Only score ≥ 100% AND Standards Adoption ≥ 80%)

---

**Pipeline**: {pipeline file path}
**Date**: {ISO timestamp}
**Ev2 Artifacts**: {path or "not provided"}
**Standards Source**: configuringPpeAndProdRings.md (preview state)

> **DISCLAIMER**: configuringPpeAndProdRings.md is in preview state and subject to change.
> Scores reflect compliance as of the audit date.

---

## Gaps — Action Required

{Only items that are NON-COMPLIANT or PARTIAL}

| ID | Tier | Standard | Status | Finding |
|----|------|----------|--------|---------|
| RING-001 | REQUIREMENT | PPE+Prod single stage | NON-COMPLIANT | {short description} |
| ... | | | | |

### {ID}: {Standard Name}
- **Status**: NON-COMPLIANT / PARTIAL
- **Evidence**: {what was found or what was absent — quote the actual text or note the line}
- **Remediation**:
  {specific fix with code snippet}

---

## Full Findings

{All 20 standards in order}

| ID | Tier | Standard | Status | Confidence | Evidence |
|----|------|----------|--------|------------|---------|
| RING-001 | REQUIREMENT | PPE+Prod single stage | {status} | {HIGH/MED/LOW} | {evidence excerpt} |
| RING-002 | REQUIREMENT | isProduction: true | {status} | {HIGH/MED/LOW} | {evidence excerpt} |
| ... | | | | | |

---

## Ev2 Registration Commands

Use these commands to verify and create the Ev2 registrations required by this pipeline.
Values are populated from the pipeline YAML and Ev2 artifacts discovered during this audit.
Replace any `<NOT-FOUND>` placeholders with the correct values before running.

> Run in a PowerShell session with the Ev2 PowerShell module loaded and authenticated.

### Service Registration

```powershell
# Verify
Get-AzureServiceRolloutServiceRegistration `
    -ServiceIdentifier "{serviceTreeId}" `
    -RolloutInfra Prod

# Register (if not already registered)
# -ServiceSpecificationPath: path to ServiceSpecification.json (contains the serviceTreeId and service metadata)
New-AzureServiceRolloutServiceRegistration `
    -ServiceSpecificationPath "{path/to/ServiceSpecification.json}" `
    -RolloutInfra Prod
```

*Source: `extends.parameters.serviceTreeId` identifies the service; `ServiceSpecification.json` is typically inside ServiceGroupRoot or at the Ev2 root*

### Service Group Registration *(optional — only if not autoregistered already with pipeline)*

```powershell
# Verify
Get-AzureServiceRolloutServiceGroupRegistration `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroup "{serviceGroupName}" `
    -RolloutInfra Prod

# Register (if not already registered)
# -ServiceGroupSpecificationPath: path to ServiceGroupSpec.json (Ev2 service group definition file)
# -ServiceGroupOverride: optional — overrides the service group name defined in the spec file
New-AzureServiceRolloutServiceGroupRegistration `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroupSpecificationPath "{path/to/ServiceGroupSpec.json}" `
    -RolloutInfra Prod
```

> `ServiceGroupSpec.json` is the Ev2 service group definition file — typically located at the root of the Ev2 directory (not inside ServiceGroupRoot). If it does not exist, it must be created before running this command.

### Subscription Registration

```powershell
{for each ring, read subscriptionKey from Configuration/<ring>.json and subscriptionId from approval.scope.subscriptionIds}

Register-AzureServiceSubscription `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroup "{serviceGroupName}" `
    -SubscriptionKey "{subscriptionKey-from-ring-config}" `
    -SubscriptionId "{subscriptionId}" `
    -Ring "{ringName}" `
    -RolloutInfra Prod
```

> `-SubscriptionKey` is the logical key defined in `subscriptionKey` within each ring's configuration JSON (e.g., `Microsoft.M365.<Service>.ppe.json`). It must match the key referenced in `ServiceModel.json`.

### Ring Registration

```powershell
{for each ring name found in StageMap.rings.json}
New-AzureServiceRing `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroup "{serviceGroupName}" `
    -Ring "{ringName}" `
    -RolloutInfra Prod
```

### Inner Stage Map Registration

```powershell
# PPE stage map  (name and version are read from the JSON file automatically)
New-AzureServiceStageMap `
    -StageMapFilePath "{path/to/StageMap.ppe.json}" `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroup "{serviceGroupName}" `
    -RolloutInfra Prod

# PROD stage map
New-AzureServiceStageMap `
    -StageMapFilePath "{path/to/StageMap.prod.json}" `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroup "{serviceGroupName}" `
    -RolloutInfra Prod
```

### Azure Presence Registration *(optional — only if not auto-registered via deployment)*

```powershell
{for each ring found in StageMap.rings.json, group all explicit regions (excluding REMAINING_REGIONS) into one call per ring}

Register-AzureServicePresence `
    -ServiceIdentifier "{serviceTreeId}" `
    -ServiceGroup "{serviceGroupName}" `
    -Ring "{ringName}" `
    -Locations '{region1}', '{region2}', '{region3}' `
    -RolloutInfra Prod
```

---

## Standards Reference

These standards are drawn from:
`configuringPpeAndProdRings.md` — LENS-Docs/sources/docs/enghub/core/content/CreatingServices/

For the full standards catalog, see `pipeline-standards-catalog.md` in this plugin.
```

#### File 2: `pipeline-audit-findings.md`

A detailed per-standard findings log with full evidence quotes and remediation steps for every item (even COMPLIANT ones, for audit trail purposes).

---

## Output Summary

| Artifact | Path | Contents |
|----------|------|----------|
| Main report | `{output}/pipeline-audit-report.md` | Scores, gap table, action items |
| Detailed findings | `{output}/pipeline-audit-findings.md` | All 20 standards with full evidence |

After writing files, print to the user:
1. The compliance score table (4 metrics)
2. The verdict (PASS/FAIL)
3. The gap list (NON-COMPLIANT and PARTIAL items with short remediation)
4. The output file paths

---

### Phase 5: Severity Summary and Remediation Menu

After printing the report, classify every NON-COMPLIANT and PARTIAL finding into one of three severity buckets:

| Severity | Definition | Impact |
|----------|------------|--------|
| **Critical** | REQUIREMENT tier — NON-COMPLIANT or PARTIAL | Directly causes FAIL verdict; must fix to reach PASS |
| **Non-Critical** | STANDARD tier — NON-COMPLIANT or PARTIAL | Reduces Standards Adoption score; fix to reach ≥ 80% |
| **Recommended** | RECOMMENDATION tier — NOT-ADOPTED or PARTIAL | Informational only; does not affect PASS/FAIL |

Print the following block **exactly** after the gap list:

```
───────────────────────────────────────────────────────
 FINDINGS SUMMARY
───────────────────────────────────────────────────────
 🔴 Requirements Only  (REQUIREMENT gaps): {N} — {comma-separated IDs}
 🟡 Standard Adoption  (STANDARD gaps):    {N} — {comma-separated IDs}
 🔵 Recommendations    (not adopted):      {N} — {comma-separated IDs}

 What would you like to do?

   1  Requirements Only  — resolve REQUIREMENT gaps to unblock PASS
   2  Standard Adoption  — resolve STANDARD gaps to improve score
   3  Recommendations    — resolve RECOMMENDATION gaps (not adopted)
   4  Fix all            — resolve ALL gaps across every tier
   [Enter] Skip — review reports only

 Type a number and press Enter, or press Enter to skip.
───────────────────────────────────────────────────────
```

- If there are zero findings in a severity bucket, omit that line.
- If there are zero findings in ALL buckets, omit the entire block and print: `✅ No gaps to fix — pipeline is fully compliant.`

#### Handling the user's choice

**Option 1 — Requirements Only:**
Apply fixes only for items whose tier is REQUIREMENT and whose status is NON-COMPLIANT or PARTIAL.
Proceed to the Remediation Execution section below.

**Option 2 — Standard Adoption:**
Apply fixes only for items whose tier is STANDARD and whose status is NON-COMPLIANT or PARTIAL.
Proceed to the Remediation Execution section below.

**Option 3 — Recommendations:**
Apply fixes only for items whose tier is RECOMMENDATION and whose status is NOT-ADOPTED or PARTIAL.
Proceed to the Remediation Execution section below.

**Option 4 — Fix all:**
Apply fixes for ALL NON-COMPLIANT, PARTIAL, and NOT-ADOPTED items across every tier (REQUIREMENT + STANDARD + RECOMMENDATION).
Proceed to the Remediation Execution section below.

**Enter (skip):**
Do nothing. Remind the user: "Reports saved to `{output}/`. Run the audit again after making changes to verify compliance."

---

### Remediation Execution

When the user selects an option, apply fixes in this order for each selected gap:

#### Per-gap fix rules

For each gap to fix, follow these rules:

**RING-001 — PPE and PROD not in a single ring-based stage:**
- Create `StageMap.rings.json` in the Ev2 ServiceGroupRoot/StageMaps/ directory modelled after the LENS-Delivery reference (2 outer stages: PreProduction with PPE rings, Production with PROD rings; top-level `manual: true`, `timeout: P7D`; per-stage `manual: false` for intra-stage promotion).
- Create `StageMap.ppe.json` and `StageMap.prod.json` with the 5-stage Canary/Pilot/Medium/Heavy/Broad pattern (Broad stage uses `REMAINING_REGIONS`), if they do not exist.
- In the pipeline YAML: collapse the existing PPE and PROD stages into a single `isProduction: true` stage. Add `StageMapPath:` pointing to `StageMap.rings.json`. Remove the `select: regions(...)` pattern. Add both PPE and PROD subscription IDs to the lockbox `subscriptionIds:` list.
- **STOP and ask the user** if the PROD subscription ID is unknown before writing the file — do not guess or leave a placeholder silently.

**RING-003 — No StageMapPath in production stage:**
- In the production stage ev2 block: replace `select: regions(...)` with `StageMapPath: StageMaps/StageMap.rings.json`. If `StageMap.rings.json` does not exist, create it (see RING-001 rule).

**RING-004 — Inner stage maps missing or not 5-stage:**
- Create or rewrite `StageMap.ppe.json` and `StageMap.prod.json` with exactly 5 stages: Canary (seq 1), Pilot (seq 2), Medium (seq 3), Heavy (seq 4), Broad (seq 5). Broad stage must have `"regions": ["REMAINING_REGIONS"]`.

**RING-005 — REMAINING_REGIONS absent from Broad stage:**
- In `StageMap.ppe.json` and `StageMap.prod.json`, add `"REMAINING_REGIONS"` to the `regions` array of the last stage (Broad).

**RING-006 — Outer stage map missing manual: true / P7D:**
- In `StageMap.rings.json`, add or update the top-level `configuration.promotion` block: `{ "manual": true, "timeout": "P7D" }`.

**PARAM-001 — rolloutType includes globaloutage:**
- Remove `globaloutage` from the `values:` list.
- Remove the `icmIncidentId` parameter if it exists (it is only needed for globaloutage).
- Update the `displayName` to remove any mention of "globaloutage".

**PARAM-002 — managedValidationOverrideDuration is free-text:**
- Add `values: [PT1H, PT6H, PT24H]` immediately after the `default: PT24H` line.

**FLAG-001 — enableContinuousApproval missing:**
- Add the following block under `extends.parameters`, before `pool:`:
  ```yaml
  featureFlags:
    enableContinuousApproval: true
  ```

**AREG-001 — forceRegistration: true missing on some stages:**
- Add `forceRegistration: true` to every ev2 block that lacks it.

**AREG-002 — skipRegistrationIfExists: true missing on some stages:**
- Add `skipRegistrationIfExists: true` to every ev2 block that lacks it.

**AUTH-001 — Production stage not using workflow: lockbox:**
- Change `workflow:` to `lockbox` in the production stage `templateContext.approval` block.

**AUTH-002 — serviceConnection present on production stage:**
- Remove `serviceConnection:` from the production stage ev2 block.

**AUTH-003 — serviceGroupName absent from lockbox scope:**
- Add `serviceGroupName: Microsoft.M365.{ServiceName}` to the production stage `approval.scope`. Ask the user for the correct service group name if not inferable from the pipeline.

**AUTH-004 — subscriptionIds absent or empty:**
- Add `subscriptionIds:` with the PPE and PROD Torus subscription IDs. Ask the user for the values if not present elsewhere in the pipeline.

**GATE-001 — ManualValidation not in a separate preceding stage:**
- Extract the ManualValidation logic into a new dedicated stage (e.g., `ManualApproval_BeforePPE`) with `isProduction: false` and `workflow: test`.
- Set `dependsOn: [ManualApproval_BeforePPE]` on the production stage.
- Remove the embedded `preApproval` job from the production stage.

**GATE-002 — Manual approval timeout not 10080:**
- Set `timeoutInMinutes: 10080` on both the pool-server job and the ManualValidation@0 task step.

**CONFIG-001 — Missing base/PPE/PROD config files:**
- Create the missing files in `ServiceGroupRoot/Configuration/`. Use the existing files as a template if any are present. Ask the user to fill in environment-specific values (subscription IDs, resource names).

**CONFIG-002 — ringScope absent from RolloutSpec:**
- Add `rolloutMetadata.configuration.ringScope` to `RolloutSpec.json` with PPE and PROD entries pointing to the appropriate config files.

**CONFIG-003 — releaseReason not in standard format:**
- Update `releaseReason` to `"Deploy {ServiceName} to PPE + Prod - MOBRV2 Pipeline"`.

#### After applying fixes

1. Print a summary of every file changed and every change made (file path + what was added/removed/updated).
2. Remind the user to run the audit again to verify: `/lens-pipeline-audit:pipeline-audit --pipeline {pipeline_path}`
3. If RING-001 was fixed, warn: "Verify the PROD subscription ID in the lockbox scope before running the pipeline."

---

## Error Handling

| Error | Resolution |
|-------|------------|
| No pipeline YAML found | Use `--pipeline` to specify path explicitly |
| Pipeline found but no Ev2 artifacts | Audit proceeds; standards requiring Ev2 files are scored NOT-APPLICABLE |
| Pipeline YAML has syntax issues | Note parsing uncertainty in confidence scores; mark affected checks as LOW confidence |
| Stage map JSON malformed | Mark RING-004/005/006 as LOW confidence; note the issue |
| User selects fix but a required value is unknown (subscription ID, service group name) | Ask the user before writing the file — never use placeholder values silently |

## Notes

- **NOT-APPLICABLE** items are excluded from score denominators
- **PARTIAL** scores count as 50% toward the weighted total
- RECOMMENDATION NOT-ADOPTED items do not affect PASS/FAIL verdict
- The verdict threshold (100% Requirements + 80% Standards) can be adjusted per team agreement
- For PARTIAL or LOW confidence items, always include manual verification guidance
- When fixing files, prefer minimal diffs — change only what is needed to satisfy the standard
