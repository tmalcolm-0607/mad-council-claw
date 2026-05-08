---
paths:
  - "**/*.yml"
  - "**/*.yaml"
  - ".azure-pipelines/**"
---

# CI/CD Pipeline Structure Patterns

Standards for organizing Azure DevOps pipelines based on large-enterprise patterns.

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

## Multi-Stage Pipeline Pattern

### Azure DevOps

```yaml
trigger:
  branches:
    include:
      - main
      - release/*
  paths:
    include:
      - src/**
    exclude:
      - docs/**
      - '**/*.md'

pr:
  branches:
    include:
      - main
  paths:
    include:
      - src/**

stages:
  - stage: Build
    displayName: 'Build and Test'
    jobs:
      - job: BuildJob
        pool:
          vmImage: 'windows-latest'
        steps:
          - template: templates/build-template.yml

  - stage: DeployDev
    displayName: 'Deploy to Development'
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployDev
        environment: 'Development'
        strategy:
          runOnce:
            deploy:
              steps:
                - template: templates/deploy-template.yml
                  parameters:
                    environment: 'dev'

  - stage: DeployPPE
    displayName: 'Deploy to PPE'
    dependsOn: DeployDev
    jobs:
      - deployment: DeployPPE
        environment: 'PPE'
        strategy:
          runOnce:
            deploy:
              steps:
                - template: templates/deploy-template.yml
                  parameters:
                    environment: 'ppe'

  - stage: DeployProd
    displayName: 'Deploy to Production'
    dependsOn: DeployPPE
    jobs:
      - deployment: DeployProd
        environment: 'Production'
        strategy:
          runOnce:
            deploy:
              steps:
                - template: templates/deploy-template.yml
                  parameters:
                    environment: 'prod'
```

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

Always pin template versions to prevent breaking changes:

```yaml
# GOOD: Pinned to specific tag
ref: refs/tags/v2.0.0

# ACCEPTABLE: Pinned to specific commit
ref: abc123def456

# BAD: Using branch (can change unexpectedly)
ref: refs/heads/main
```

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
├── NuGet.Config              # Package source configuration
└── Internal/
    ├── InternalBuild.props   # Internal build-system properties
    └── InternalBuild.targets # Internal build-system targets
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
| Unpinned template versions | Breaking changes propagate | Pin to tags/commits |
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
