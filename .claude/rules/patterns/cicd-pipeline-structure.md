---
paths:
  - "**/*.yml"
  - "**/*.yaml"
  - ".azure-pipelines/**"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# CI/CD Pipeline Structure Patterns

Standards for organizing Azure DevOps pipelines based on large-enterprise patterns.

> **For pipeline compliance verification:** run the `lens-pipeline-audit:pipeline-audit` skill (installed at `.claude/skills/lens-pipeline-audit/skills/pipeline-audit/SKILL.md`; canonical source at `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/`). The 20-standard catalog at `.claude/skills/lens-pipeline-audit/rules/pipeline-standards-catalog.md` (kit mirror of `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/rules/pipeline-standards-catalog.md`) is authoritative — this file documents the same shape with kit-style explanations.

## Pipeline Organization

### File Structure

```
.azure-pipelines/
├── ci.yml                    # Continuous Integration (PR validation)
├── build.yml                 # Official build pipeline
├── release.yml               # Deployment orchestration
├── templates/                # Reusable pipeline templates
│   ├── build-template.yml
│   ├── test-template.yml
│   └── deploy-template.yml
└── variables/                # Environment-specific variables
    ├── dev.yml
    ├── ppe.yml
    └── prod.yml
```

### Shared-Platform Template Structure

Example layout used when a product line shares a common pipeline-template repo (substitute your product code or service name for `<Product>` below):

```
.azure-pipelines/
├── <Product>.Pipeline.yml           # Main pipeline extending templates
├── <Product>.Stages.yml             # Stage definitions
├── <Product>.Variables.yml          # Global variables
└── templates/
    ├── jobs/
    │   ├── build-job.yml
    │   ├── test-job.yml
    │   └── publish-job.yml
    └── steps/
        ├── dotnet-build.yml
        ├── dotnet-test.yml
        └── nuget-publish.yml
```

---

## Multi-Stage Pipeline Pattern (Canonical)

LENS release pipelines extend the M365 Official Pipeline Template and use a **two-stage shape with rings inside the production stage**: `Test_ReleaseStage` (NPE, `isProduction: false`) → `ManualApproval_BeforePPE` (human gate) → `Production_ReleaseStage` (single stage, `isProduction: true`, `workflow: lockbox`, with rings PPE → PROD via `select: rings(PPE,PROD)`).

This shape is mandated by canonical standards RING-001/RING-002/RING-003 + AUTH-001/AUTH-003/AUTH-004 + GATE-001 + AREG-001/AREG-002 + FLAG-001 + PARAM-001/PARAM-002. The example below is adapted from `references/LENS-Docs/sources/docs/enghub/core/content/CreatingServices/configuringPpeAndProdRings.md`.

```yaml
resources:
  repositories:
    - repository: m365Pipelines
      type: git
      name: 1ESPipelineTemplates/M365GPT
      ref: refs/tags/release            # canonical: moving release tag
  pipelines:
    - pipeline: ArtifactPipeline
      source: <REPO_NAME> Official Mainline Build Drops Pipeline (yaml)

trigger: none

# --- Parameters (PARAM-001, PARAM-002) -------------------------------------

parameters:
  # PARAM-001: only normal and emergency rollout types
  - name: rolloutType
    displayName: Rollout type (normal or emergency)
    type: string
    default: normal
    values:
      - normal
      - emergency

  # PARAM-002: constrained duration values, not free-text
  - name: managedValidationOverrideDuration
    displayName: Managed Validation Override Duration (ISO 8601)
    type: string
    default: PT24H
    values:
      - PT1H
      - PT6H
      - PT24H

  - name: ringSelect
    displayName: Ring selection
    type: string
    default: 'rings(PPE,PROD)'
    values:
      - 'rings(PPE,PROD)'
      - 'rings(PPE)'

# --- Pipeline Template -----------------------------------------------------

extends:
  template: v1/M365.Official.PipelineTemplate.yml@m365Pipelines
  parameters:
    serviceTreeId: <SERVICE_TREE_ID>
    pool:
      name: Azure-Pipelines-1ESPT-ExDShared

    # FLAG-001: reduce lockbox requests with continuous approval
    featureFlags:
      enableContinuousApproval: true

    stages:

      # === NPE Stage (TestTRS) ============================================
      - stage: Test_ReleaseStage
        displayName: Release to Test Environment (NPE)
        templateContext:
          isProduction: false
          cloud: Public
          approval:
            workflow: test                  # AUTH-001: NPE uses workflow: test
        jobs:
          - job: Test_ReleaseJob
            templateContext:
              type: releaseJob
              workflow: m365-ev2-ra
              inputs:
                - input: artifactsDrop
                  pipeline: ArtifactPipeline
                  dropMetadataContainerName: DropMetaData
                  rootPaths: '/target/publish/<SERVICE_PATH>/Ev2/ServiceGroupRoot/'
                  entraServiceConnection: <DROP_SERVICE_CONNECTION>
                  dropServiceURI: https://ossinfra.artifacts.visualstudio.com/DefaultCollection
              ev2:
                serviceConnection: <EV2_SERVICE_CONNECTION>
                serviceRootPath: 'target/publish/<SERVICE_PATH>/Ev2/ServiceGroupRoot/'
                rolloutSpecPath: RolloutSpec.json
                serviceGroupOverride: "Microsoft.M365.<SERVICE_GROUP>.npe"
                forceRegistration: true              # AREG-001
                skipRegistrationIfExists: true       # AREG-002
                select: regions(<NPE_REGIONS>)
                StageMapName: <NPE_STAGE_MAP_NAME>
                StageMapVersion: <NPE_STAGE_MAP_VERSION>

      # === Manual Approval Gate (GATE-001) ================================
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
            timeoutInMinutes: 10080         # GATE-002: 1 week timeout
            steps:
              - task: ManualValidation@0     # GATE-001
                timeoutInMinutes: 10080
                condition: always()
                inputs:
                  notifyUsers: <TEAM_EMAIL>
                  instructions: >
                    Verify NPE deployment succeeded and service is healthy
                    before approving PPE + Prod release.

      # === Production Stage (PPE + Prod via Rings) ========================
      # RING-001/RING-002: single isProduction:true stage with rings inside
      - stage: Production_ReleaseStage
        displayName: Release to PPE + Prod (Ring Progression)
        dependsOn: [ManualApproval_BeforePPE]
        templateContext:
          isProduction: true                # RING-002
          cloud: Public
          approval:
            workflow: lockbox               # AUTH-001: production uses lockbox
            scope:
              serviceGroupName: Microsoft.M365.<SERVICE_GROUP>   # AUTH-003 mandatory
              subscriptionIds:                                   # AUTH-004 mandatory
                - <PPE_SUBSCRIPTION_ID>
                - <PROD_SUBSCRIPTION_ID>
              releaseReason: "Deploy <SERVICE_NAME> to PPE + Prod - MOBRV2 Pipeline"   # CONFIG-003
        jobs:
          - job: Production_ReleaseJob
            templateContext:
              type: releaseJob
              workflow: m365-ev2-ra
              inputs:
                - input: artifactsDrop
                  pipeline: ArtifactPipeline
                  dropMetadataContainerName: DropMetaData
                  rootPaths: '/target/publish/<SERVICE_PATH>/Ev2/ServiceGroupRoot/'
                  entraServiceConnection: <DROP_SERVICE_CONNECTION>
                  dropServiceURI: https://ossinfra.artifacts.visualstudio.com/DefaultCollection
              ev2:
                # AUTH-002: NO serviceConnection on production (Torus JIT + lockbox handles auth)
                serviceRootPath: 'target/publish/<SERVICE_PATH>/Ev2/ServiceGroupRoot/'
                rolloutSpecPath: RolloutSpec.json
                serviceGroupOverride: "Microsoft.M365.<SERVICE_GROUP>"
                forceRegistration: true               # AREG-001
                skipRegistrationIfExists: true        # AREG-002
                StageMapPath: StageMap.rings.json     # RING-003: outer ring orchestration
                select: ${{ parameters.ringSelect }}
                RolloutType: ${{ parameters.rolloutType }}
                ManagedValidationOverrideDuration: ${{ parameters.managedValidationOverrideDuration }}
```

**Key shape elements** (verify each is present in your pipeline):

- `extends: template: v1/M365.Official.PipelineTemplate.yml@m365Pipelines`
- `featureFlags.enableContinuousApproval: true` (FLAG-001)
- `parameters` with `rolloutType` (values: normal, emergency) and `managedValidationOverrideDuration` (values: PT1H, PT6H, PT24H)
- `Test_ReleaseStage` with `isProduction: false`, `workflow: test`, `serviceGroupOverride: "...npe"`
- `ManualApproval_BeforePPE` stage with `ManualValidation@0`, `timeoutInMinutes: 10080`
- `Production_ReleaseStage` with `isProduction: true`, `workflow: lockbox`, `scope.serviceGroupName`, `scope.subscriptionIds`, `StageMapPath: StageMap.rings.json`, `select: rings(PPE,PROD)`
- Every ev2 block has `forceRegistration: true` and `skipRegistrationIfExists: true` (AREG-001/002)
- No `serviceConnection` on the production stage ev2 block (AUTH-002)

---

## Template Repository Pattern

### External Template Reference

```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: DevOps/PipelineTemplates
      ref: refs/tags/v2.0.0

extends:
  template: pipelines/1es-pipeline.yml@templates
  parameters:
    buildConfiguration: 'Release'
    runCodeQL: true
    runCredScan: true
```

### Benefits

| Benefit | Description |
|---------|-------------|
| Consistency | All teams use same pipeline patterns |
| Security | Centralized security scanning configuration |
| Maintenance | Update templates once, propagate everywhere |
| Compliance | Internal build-system / SDL requirements built into templates |

### Version Pinning

Pin template versions for **kit-internal templates and third-party templates** to prevent breaking changes; use canonical moving tags for **1ES Pipeline Templates** (the platform expects them).

```yaml
# GOOD: Pinned to specific tag (team-owned templates)
ref: refs/tags/v2.0.0

# ACCEPTABLE: Pinned to specific commit (team-owned templates)
ref: abc123def456

# BAD: Using branch (can change unexpectedly)
ref: refs/heads/main
```

#### Exception — `1ESPipelineTemplates/M365GPT` uses `refs/tags/release` (moving tag)

The 1ES Pipeline Template `1ESPipelineTemplates/M365GPT` is consumed via the moving tag `refs/tags/release`. This is the **1ES-prescribed consumption point** — pinning to a specific commit SHA or semver tag breaks the canonical consumption pattern AND misses 1ES security / compliance updates as 1ES rolls them forward.

This is **explicit trust delegation to the 1ES platform** (the platform team owns the template's security and compliance posture and rolls forward via the moving tag). It is NOT a general statement that all "moving tags" are auto-safe — for any other template repository (team-owned, third-party, non-1ES platform), pin to a specific tag or commit per the rules above.

```yaml
# CANONICAL: 1ES-prescribed moving tag — do NOT pin to a specific version
resources:
  repositories:
    - repository: m365Pipelines
      type: git
      name: 1ESPipelineTemplates/M365GPT
      ref: refs/tags/release            # canonical: moving release tag
```

<!-- Provenance: cross-service fleet audit confirmed `configuringPpeAndProdRings.md:794-799` prescribes the moving tag; confirming source `releasePipelines.md:50-53`. -->

LENS service pipelines across CMS / DCS / Common / Delivery / SMS / Teams / LRMS uniformly use `refs/tags/release` for `1ESPipelineTemplates/M365GPT`. The canonical guidance at `configuringPpeAndProdRings.md:794-799` prescribes the moving tag; confirming source at `releasePipelines.md:50-53`.

**Refined rule**: pin versions for **team-owned template repos and non-1ES third-party templates**; use canonical moving tags **only** for 1ES Pipeline Templates (`1ESPipelineTemplates/M365GPT` and any future 1ES platform templates). When in doubt, check the canonical 1ES doc for the consumption pattern.

---

## Internal Compliance Pipeline Templates

Internal compliance build systems often provide reusable pipeline templates that bake in required security and provenance tasks. The example below is pseudocode for such a template; adapt the template path and pool names to whichever compliance pipeline your CI system provides.

```yaml
extends:
  template: v1/Compliance.Official.PipelineTemplate.yml@ComplianceTemplates
  parameters:
    pool:
      name: Compliance-Hosted-Windows-2022
      os: windows

    customBuildTags:
      - AIMigrationFinished

    stages:
      - stage: Build
        jobs:
          - job: BuildJob
            steps:
              - task: DotNetCoreCLI@2
                inputs:
                  command: 'build'
```

Lesson: when your CI provider offers a compliance-hardened pipeline template, extend it rather than authoring raw YAML — otherwise the moment compliance requirements change (new scanners, new task versions) you have to update every pipeline manually.

### Required Security Tasks

| Task | Purpose |
|------|---------|
| CodeQL | Static code analysis |
| CredScan | Credential detection |
| BinSkim | Binary security analysis |
| PoliCheck | Policy compliance |
| Component Governance | OSS license compliance |

---

## Internal Build-System MSBuild Patterns

Large organisations often integrate their .NET projects with a signed/official internal build system. The pattern below uses a placeholder `InternalBuildTargets` property; adapt for whichever internal build system you use.

### Official vs Local Builds

```xml
<!-- Directory.Build.props -->
<Project>
  <PropertyGroup>
    <!-- Internal build system sets these for official builds -->
    <IsOfficialBuild Condition="'$(IsOfficialBuild)' == ''">false</IsOfficialBuild>
    <BuildVersion Condition="'$(BuildVersion)' == ''">0.0.1-local</BuildVersion>
  </PropertyGroup>

  <!-- Import internal build targets for official builds -->
  <Import Project="$(InternalBuildTargets)" Condition="Exists('$(InternalBuildTargets)')" />
</Project>
```

### MSBuild Targets Structure

```
Build/
├── Directory.Build.props     # Global build properties
├── Directory.Build.targets   # Global build targets
├── NuGet.Config             # Package source configuration
└── Internal/
    ├── InternalBuild.props  # Internal-build-system properties
    └── InternalBuild.targets # Internal-build-system targets
```

### Internal Build Pipeline Integration

```yaml
- task: MSBuild@1
  displayName: 'Build (official)'
  inputs:
    solution: '$(Build.SourcesDirectory)\src\MySolution.sln'
    platform: 'Any CPU'
    configuration: '$(BuildConfiguration)'
    msbuildArguments: >
      /p:IsOfficialBuild=$(IsOfficialBuild)
      /p:BuildVersion=$(Build.BuildNumber)
      /p:InternalBuildTargets=$(Build.SourcesDirectory)\Build\Internal\InternalBuild.targets
```

### NuGet Package Generation

```xml
<!-- Directory.Build.props for package projects -->
<PropertyGroup Condition="'$(IsPackable)' == 'true'">
  <PackageVersion>$(BuildVersion)</PackageVersion>
  <PackageId>$(AssemblyName)</PackageId>
  <GeneratePackageOnBuild>true</GeneratePackageOnBuild>
  <PackageOutputPath>$(Build.ArtifactStagingDirectory)\packages</PackageOutputPath>
</PropertyGroup>
```

---

## Path-Based Triggers for Monorepos

### Azure DevOps

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - services/api/**
    exclude:
      - services/api/docs/**
      - '**/*.md'

# Separate pipeline for frontend
# In frontend-ci.yml:
trigger:
  paths:
    include:
      - services/frontend/**
```

### Path Filter Strategy

| Component | Trigger Paths | Exclude |
|-----------|---------------|---------|
| Backend API | `services/api/**` | `**/docs/**`, `**/*.md` |
| Frontend | `services/web/**` | `**/*.md` |
| Shared Libraries | `packages/shared/**` | `**/*.md` |
| Infrastructure | `infrastructure/**` | - |

---

## Environment Gates

### Validating Pipeline Changes Without Deploying (`validateOnly: true`)

Production stages enforce branch policies that block runs from feature branches. Two ways to validate pipeline + Ev2 configuration without performing a real deployment:

| Approach | When |
|----------|------|
| Run NPE stage from any branch | Validates artifacts and deployment flow against TestTRS |
| Add `validateOnly: true` to the production stage's ev2 block | Runs a validation rollout from a production branch (`release/*`, `master`) without deploying real resources |

```yaml
# In the production stage ev2 block — temporarily add validateOnly to test pipeline changes
ev2:
  validateOnly: true                        # Runs validation rollout only — no actual deployment
  serviceRootPath: 'target/publish/<SERVICE_PATH>/Ev2/ServiceGroupRoot/'
  rolloutSpecPath: RolloutSpec.json
  serviceGroupOverride: "Microsoft.M365.<SERVICE_GROUP>"
  forceRegistration: true
  skipRegistrationIfExists: true
  StageMapPath: StageMap.rings.json
  select: ${{ parameters.ringSelect }}
```

> **REMOVE before real deploy.** Leaving `validateOnly: true` in the pipeline silently prevents actual deployment. Add it for the validation run, push, observe results, then remove it in a follow-up commit before the real release. Per `configuringPpeAndProdRings.md:957-974`.

---

### Manual Approval Gates

```yaml
# Azure DevOps
stages:
  - stage: DeployProd
    jobs:
      - deployment: DeployProd
        environment: 'Production'  # Environment with approval configured
```

### Variable Groups

```yaml
variables:
  - group: 'MyApp-Dev-Variables'
  - group: 'MyApp-Secrets'

# Environment-specific variable groups
stages:
  - stage: DeployDev
    variables:
      - group: 'MyApp-Dev-Variables'
  - stage: DeployProd
    variables:
      - group: 'MyApp-Prod-Variables'
```

---

## M365GPT Pipeline Patterns

### Extends Pattern

```yaml
# M365GPT.Pipeline.yml
trigger:
  branches:
    include:
      - main
      - release/*

resources:
  repositories:
    - repository: M365GPTTemplates
      type: git
      name: M365GPT/PipelineTemplates
      ref: refs/tags/v3.0.0

extends:
  template: pipelines/dotnet-service.yml@M365GPTTemplates
  parameters:
    serviceName: 'MyService'
    buildConfiguration: 'Release'
    runIntegrationTests: true
    deployToEnvironments:
      - dev
      - ppe
      - prod
```

### Template Parameters

```yaml
# templates/dotnet-service.yml
parameters:
  - name: serviceName
    type: string
  - name: buildConfiguration
    type: string
    default: 'Release'
  - name: runIntegrationTests
    type: boolean
    default: false
  - name: deployToEnvironments
    type: object
    default: []

stages:
  - stage: Build
    jobs:
      - template: ../jobs/build-job.yml
        parameters:
          serviceName: ${{ parameters.serviceName }}
          configuration: ${{ parameters.buildConfiguration }}

  - ${{ each env in parameters.deployToEnvironments }}:
    - stage: Deploy_${{ env }}
      dependsOn: Build
      jobs:
        - template: ../jobs/deploy-job.yml
          parameters:
            environment: ${{ env }}
            serviceName: ${{ parameters.serviceName }}
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Single monolithic pipeline | Hard to maintain, slow | Split into stages/jobs |
| No path filters in monorepo | Every change triggers all pipelines | Use path-based triggers |
| Unpinned team-owned template versions | Breaking changes propagate | Pin to tags/commits (1ES platform templates excepted — see Version Pinning section) |
| Hardcoded secrets in YAML | Security vulnerability | Use variable groups/secrets |
| No environment gates | Accidental production deploy | Require approvals |
| Copy-paste pipelines | Drift, maintenance burden | Use templates |
| Inline scripts over templates | Hard to test and maintain | Extract to template files |

---

## Checklist

When creating CI/CD pipelines:

- [ ] Separate CI (PR validation) from CD (deployment)
- [ ] Use multi-stage structure with clear dependencies
- [ ] Configure path-based triggers for relevant directories
- [ ] Reference templates from versioned repository
- [ ] Configure environment gates for production
- [ ] Include security scanning (CodeQL, CredScan)
- [ ] Pin all external dependencies and templates
- [ ] Exclude documentation from build triggers
- [ ] Use variable groups for environment-specific configuration
- [ ] Configure the internal build system for official builds
