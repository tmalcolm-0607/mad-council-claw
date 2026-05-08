# lens-pipeline-audit

Audit LENS release pipeline YAML files for compliance with PPE and Prod ring-based deployment standards from `configuringPpeAndProdRings.md`.

## What It Does

Reads your release pipeline YAML (and optionally Ev2 stage maps, RolloutSpec, and configuration files) and evaluates it against the 20 standards defined in [`configuringPpeAndProdRings.md`](https://o365exchange.visualstudio.com/O365%20Core/_git/LENS-Docs?path=/sources/docs/enghub/core/content/CreatingServices/configuringPpeAndProdRings.md).

Produces:
- A **compliance score** across 4 dimensions (Requirements, Standards, Recommendations, Weighted Overall)
- A **PASS/FAIL verdict** (based on Requirements and Standards tiers)
- A **gap table** with actionable remediation steps for every non-compliant item
- **Automated gap remediation** — applies fixes directly to pipeline YAML and Ev2 artifact files for any non-compliant standard
- An **Ev2 Registration Commands** section populated with real values from your pipeline artifacts
- Full findings files for audit trail purposes

## Standards Covered

| Category | Standards | Key checks |
|----------|-----------|------------|
| Ring Architecture | RING-001 to RING-006 | Single production stage, StageMapPath, 5-stage maps |
| Pipeline Parameters | PARAM-001, PARAM-002 | rolloutType, managedValidationOverrideDuration |
| Feature Flags | FLAG-001 | enableContinuousApproval |
| Artifact Registration | AREG-001, AREG-002 | forceRegistration, skipRegistrationIfExists |
| Security & Auth | AUTH-001 to AUTH-004 | lockbox workflow, no serviceConnection, scope fields |
| Approval Gates | GATE-001, GATE-002 | ManualValidation@0, timeout |
| Configuration | CONFIG-001 to CONFIG-003 | Base+PPE+PROD configs, ringScope, releaseReason |

## Ev2 Registration Commands

After every audit the report includes a fully-populated **Ev2 Registration Commands** section. Values are extracted automatically from the pipeline and Ev2 artifacts — no manual substitution needed for compliant pipelines.

Commands generated:

| Registration | PowerShell cmdlet | Source field |
|---|---|---|
| Service | `Get-` / `New-AzureServiceRolloutServiceRegistration` | `extends.parameters.serviceTreeId` |
| Service Group *(optional)* | `Get-` / `New-AzureServiceRolloutServiceGroupRegistration` | `approval.scope.serviceGroupName` |
| Subscription | `Register-AzureServiceSubscription` | `approval.scope.subscriptionIds` |
| Ring | `New-AzureServiceRing` | Ring names from `StageMap.rings.json` |
| Inner Stage Map | `New-AzureServiceStageMap` | `name` + `version` from `StageMap.ppe/prod.json` |
| Azure Presence *(optional)* | `Register-AzureServicePresence` | Ring names + region entries from inner stage maps; `-RolloutInfra Prod` |

Any value not found in the artifacts is marked `<NOT-FOUND>` — the command block is never omitted.

## Installation

```
/plugin install lens-pipeline-audit
```

Or locally:
```bash
claude --plugin-dir C:/REPO/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit
```

## Usage

```
# Auto-discover pipeline in current directory
/lens-pipeline-audit:pipeline-audit

# Audit a specific pipeline file
/lens-pipeline-audit:pipeline-audit --pipeline sources/dev/LEAPI/src/Ev2/LEAPI.Release.yml

# Audit pipeline + Ev2 artifacts
/lens-pipeline-audit:pipeline-audit --pipeline LEAPI.Release.yml --ev2 sources/dev/LEAPI/src/Ev2/ServiceGroupRoot/

# Print the standards catalog only (no audit)
/lens-pipeline-audit:pipeline-audit --standards-only

# Save report to a specific directory
/lens-pipeline-audit:pipeline-audit --pipeline LEAPI.Release.yml --output C:/Reports/pipeline-audit/
```

## Output

```
lens-pipeline-audit/
├── pipeline-audit-report.md     # Scores, gaps, remediation actions, Ev2 registration commands
└── pipeline-audit-findings.md   # Full per-standard evidence log
```

## Scoring

| Tier | Weight | Verdict impact |
|------|--------|----------------|
| REQUIREMENT | 3x | Failure if any NON-COMPLIANT |
| STANDARD | 2x | Failure if < 80% adoption |
| RECOMMENDATION | 1x | Informational only |

**PASS** = 100% Requirements + ≥80% Standards adoption

## Automated Remediation

After the audit, the skill classifies every gap into a severity bucket and offers an interactive fix menu:

```
 🔴 Requirements Only  (REQUIREMENT gaps): N — IDs
 🟡 Standard Adoption  (STANDARD gaps):    N — IDs
 🔵 Recommendations    (not adopted):      N — IDs

   1  Requirements Only  — resolve REQUIREMENT gaps to unblock PASS
   2  Standard Adoption  — resolve STANDARD gaps to improve score
   3  Recommendations    — resolve RECOMMENDATION gaps
   4  Fix all            — resolve ALL gaps across every tier
   [Enter] Skip — review reports only
```

Selecting an option applies the fixes **directly to your files** — no manual editing required. Every standard has a dedicated fix rule:

| Standard | What gets fixed |
|----------|----------------|
| RING-001 | Collapses separate PPE/PROD stages into a single ring-based production stage; creates `StageMap.rings.json` |
| RING-003 | Replaces `select: regions(...)` with `StageMapPath: StageMaps/StageMap.rings.json` |
| RING-004 | Creates/rewrites inner stage maps with the 5-stage Canary→Pilot→Medium→Heavy→Broad pattern |
| RING-005 | Adds `REMAINING_REGIONS` to the Broad stage in inner stage maps |
| RING-006 | Sets `configuration.promotion.manual: true` and `timeout: "P7D"` in `StageMap.rings.json` |
| PARAM-001 | Removes `globaloutage` from `rolloutType` values and drops `icmIncidentId` parameter |
| PARAM-002 | Adds constrained `values: [PT1H, PT6H, PT24H]` to `managedValidationOverrideDuration` |
| FLAG-001 | Adds `featureFlags.enableContinuousApproval: true` under `extends.parameters` |
| AREG-001/002 | Adds `forceRegistration: true` / `skipRegistrationIfExists: true` to every ev2 block |
| AUTH-001 | Changes `workflow:` to `lockbox` on the production stage |
| AUTH-002 | Removes `serviceConnection:` from the production stage ev2 block |
| AUTH-003/004 | Adds `serviceGroupName` / `subscriptionIds` to the lockbox scope |
| GATE-001 | Extracts `ManualValidation@0` into a dedicated gate stage with correct `dependsOn` wiring |
| GATE-002 | Sets `timeoutInMinutes: 10080` on both the gate job and the `ManualValidation@0` task |
| CONFIG-001 | Creates missing base / `.ppe.json` / `.prod.json` config files in `ServiceGroupRoot/Configuration/` |
| CONFIG-002 | Adds `ringScope` array to `RolloutSpec.json` with PPE and PROD entries |
| CONFIG-003 | Updates `releaseReason` to the standard `"Deploy [Name] to PPE + Prod - MOBRV2 Pipeline"` format |

After applying fixes, the skill prints a summary of every file changed and prompts you to re-run the audit to verify compliance.

## Source Standards

`LENS-Docs/sources/docs/enghub/core/content/CreatingServices/configuringPpeAndProdRings.md`

> All LENS-Docs documents are in preview state and subject to change.
