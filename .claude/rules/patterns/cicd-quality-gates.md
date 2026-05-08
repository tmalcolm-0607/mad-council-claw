---
paths:
  - "**/*.yml"
  - "**/*.yaml"
  - "**/package.json"
  - "**/*.csproj"
---

# CI/CD Quality Gates Patterns

Standards for quality gates in CI/CD pipelines based on large-enterprise patterns.

> **For pipeline compliance verification:** run the `lens-pipeline-audit:pipeline-audit` skill (installed at `.claude/skills/lens-pipeline-audit/skills/pipeline-audit/SKILL.md`; canonical source at `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/`). The 20-standard catalog at `.claude/skills/lens-pipeline-audit/rules/pipeline-standards-catalog.md` (kit mirror of `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/rules/pipeline-standards-catalog.md`) is authoritative for ring/auth/gate/parameter/registration standards. The coverage thresholds documented below are **kit-internal policy**, NOT canonical pipeline gates — canonical LENS does not gate ring promotion on coverage.

## Quality Gate Hierarchy

```
+===========================================================================+
|  Kit policy: gates run after each user story or phase.                    |
|  Order: Build -> Test -> Coverage -> Security -> Compliance               |
|                                                                           |
|  Note: this hierarchy is the KIT's recommended discipline. Canonical      |
|  LENS pipeline promotion is gated on Managed SDP bake + ManualValidation  |
|  + 5-stage region progression (RING-004, GATE-001, GATE-002), not on the  |
|  coverage thresholds shown later in this file.                            |
+===========================================================================+
```

---

## Build Gate

### .NET Projects

```yaml
# Azure DevOps
- task: DotNetCoreCLI@2
  displayName: 'Build'
  inputs:
    command: 'build'
    projects: '**/*.csproj'
    arguments: '--configuration Release --no-restore'

# With Central Package Management
- task: DotNetCoreCLI@2
  displayName: 'Restore with CPM'
  inputs:
    command: 'restore'
    projects: 'dirs.proj'  # Traversal project
    feedsToUse: 'config'
    nugetConfigPath: 'nuget.config'
```

### Node.js Projects

```yaml
# GitHub Actions
- name: Install dependencies
  run: npm ci

- name: Build
  run: npm run build

- name: Type check
  run: npm run type-check
```

### Build Gate Criteria

| Criterion | Pass Condition |
|-----------|----------------|
| Compilation | Exit code 0 |
| Warnings | Must not exceed threshold (prefer 0) |
| TypeScript | No type errors |
| Artifacts | Output artifacts exist |

---

## Test Gate

### .NET Test Configuration

```yaml
- task: DotNetCoreCLI@2
  displayName: 'Run Tests'
  inputs:
    command: 'test'
    projects: '**/*Tests.csproj'
    arguments: >
      --configuration Release
      --collect:"XPlat Code Coverage"
      --logger trx
      --results-directory $(Agent.TempDirectory)/TestResults
      -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
```

### Node.js Test Configuration

```yaml
- name: Run Tests
  run: npm test -- --coverage --coverageReporters=cobertura

- name: Upload coverage
  uses: actions/upload-artifact@v4
  with:
    name: coverage-report
    path: coverage/
```

### Coverage Thresholds (Kit-Recommended)

> **Kit-internal policy, not a canonical pipeline gate.** Canonical lens-pipeline-audit does NOT gate ring promotion on coverage — promotion gates on Managed SDP bake times + `ManualValidation@0` + 5-stage region progression. The thresholds below are the kit's recommended discipline; consumer projects MAY adopt them, override them, or replace them with their own coverage policy. The authoritative kit-wide value lives in `.claude/rules/quality-gates.md`; the values here align with that policy.

```
+===========================================================================+
|  Kit-recommended coverage targets:                                        |
|                                                                           |
|  Diff line coverage: 100% (all changed lines must be covered)             |
|  Branch coverage >= 85%                                                   |
|  Function coverage >= 90%                                                 |
|                                                                           |
|  These are KIT POLICY, not LENS canonical pipeline gates. Adopt or        |
|  override per consumer project's CLAUDE.md.                               |
+===========================================================================+
```

#### .NET Coverage Enforcement

```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <CollectCoverage>true</CollectCoverage>
  <CoverletOutputFormat>cobertura</CoverletOutputFormat>
  <Threshold>90</Threshold>
  <ThresholdType>line,branch</ThresholdType>
  <ThresholdStat>total</ThresholdStat>
</PropertyGroup>
```

#### Node.js Coverage Enforcement

```json
// package.json
{
  "jest": {
    "coverageThreshold": {
      "global": {
        "branches": 85,
        "functions": 90,
        "lines": 90,
        "statements": 90
      }
    }
  }
}
```

### Test Gate Criteria

| Criterion | Pass Condition |
|-----------|----------------|
| Test execution | All tests pass |
| Coverage (diff lines) | 100% |
| Coverage (branches) | >= 85% |
| Test count | No decrease from baseline |
| Flaky tests | 0 allowed |

---

## Static Analysis Gate

### CodeQL Analysis

```yaml
# Azure DevOps (via internal compliance pipeline template)
- task: CodeQL3000Init@0
  displayName: 'CodeQL Initialize'

- task: DotNetCoreCLI@2
  displayName: 'Build for CodeQL'
  inputs:
    command: 'build'

- task: CodeQL3000Finalize@0
  displayName: 'CodeQL Finalize'
```

```yaml
# GitHub Actions
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: csharp, javascript

- name: Build
  run: dotnet build

- name: Perform CodeQL Analysis
  uses: github/codeql-action/analyze@v3
```

### Roslyn Analyzers (.NET)

```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  <WarningsAsErrors />
  <NoWarn />
  <AnalysisLevel>latest-recommended</AnalysisLevel>
  <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
</PropertyGroup>

<ItemGroup>
  <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="8.0.0">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
  </PackageReference>
  <PackageReference Include="StyleCop.Analyzers" Version="1.2.0-beta.556">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
  </PackageReference>
</ItemGroup>
```

### ESLint (JavaScript/TypeScript)

```yaml
- name: Lint
  run: npm run lint -- --max-warnings 0
```

```json
// package.json
{
  "scripts": {
    "lint": "eslint src --ext .ts,.tsx --report-unused-disable-directives"
  }
}
```

### Static Analysis Gate Criteria

| Tool | Pass Condition |
|------|----------------|
| CodeQL | No high/critical vulnerabilities |
| Roslyn | No errors, warnings as configured |
| StyleCop | No violations |
| ESLint | 0 errors, 0 warnings (--max-warnings 0) |

---

## Security Scanning Gate

### Credential Scanning

```yaml
# Azure DevOps (a compliance pipeline template typically includes this automatically)
- task: CredScan@3
  displayName: 'Run CredScan'
  inputs:
    toolMajorVersion: 'V2'
    outputFormat: 'sarif'
    debugMode: false

- task: PostAnalysis@2
  displayName: 'Check CredScan Results'
  inputs:
    CredScan: true
```

### Pre-Commit Hooks (Local)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: detect-private-key
```

### Dependency Scanning

```yaml
# .NET
- task: ComponentGovernanceComponentDetection@0
  displayName: 'Component Governance'
  inputs:
    scanType: 'Register'
    alertWarningLevel: 'High'

# Node.js
- name: Audit dependencies
  run: npm audit --audit-level=high
```

### Security Gate Criteria

| Check | Pass Condition |
|-------|----------------|
| CredScan | 0 credentials detected |
| Dependency audit | No high/critical vulnerabilities |
| SAST (CodeQL) | No high/critical findings |
| License compliance | All licenses approved |

---

## Pre-Commit Hooks Pattern

### Setup Script

```powershell
# scripts/setup-hooks.ps1
$hooksPath = Join-Path $PSScriptRoot ".." ".git" "hooks"

# Install pre-commit framework
pip install pre-commit
pre-commit install

# Additional custom hooks
Copy-Item "$PSScriptRoot/hooks/*" -Destination $hooksPath -Force
```

### Recommended Hooks

```yaml
# .pre-commit-config.yaml
repos:
  # Secret detection
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets

  # Code formatting
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v3.1.0
    hooks:
      - id: prettier
        types_or: [javascript, typescript, json, yaml, markdown]

  # Linting
  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v8.56.0
    hooks:
      - id: eslint
        files: \.(js|ts|tsx)$

  # General checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-merge-conflict
      - id: detect-private-key
      - id: no-commit-to-branch
        args: ['--branch', 'main', '--branch', 'master']
```

---

## Central Package Management (.NET)

### Directory.Packages.props

```xml
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>

  <ItemGroup>
    <!-- Production dependencies -->
    <PackageVersion Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageVersion Include="Newtonsoft.Json" Version="13.0.3" />

    <!-- Test dependencies -->
    <PackageVersion Include="xunit" Version="2.6.6" />
    <PackageVersion Include="Moq" Version="4.20.70" />

    <!-- Analyzers -->
    <PackageVersion Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="8.0.0" />
  </ItemGroup>
</Project>
```

### Directory.Build.props

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
  </PropertyGroup>
</Project>
```

### Traversal Project (dirs.proj)

```xml
<Project Sdk="Microsoft.Build.Traversal">
  <ItemGroup>
    <ProjectReference Include="src/**/*.csproj" />
    <ProjectReference Include="tests/**/*.csproj" />
  </ItemGroup>
</Project>
```

---

## Gate Failure Response

```
+===========================================================================+
|  GATE FAILURE PROTOCOL                                                    |
|                                                                           |
|  1. Pipeline MUST fail - no manual overrides                              |
|  2. Identify specific failure from logs                                   |
|  3. Fix locally, verify gates pass                                        |
|  4. Push fix, re-run pipeline                                             |
|                                                                           |
|  NEVER: Disable gates, lower thresholds, or skip checks                   |
+===========================================================================+
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Coverage thresholds below kit-recommended target | Uncovered code may ship | Enforce kit-recommended diff coverage (or document override in consumer CLAUDE.md) |
| `--max-warnings -1` on lint | Warnings accumulate | Use `--max-warnings 0` |
| Manual gate overrides | Breaks trust in pipeline | Gates are non-negotiable |
| Skipping security scans for speed | Vulnerabilities ship | Security scans are required |
| No pre-commit hooks | Issues found late | Install hooks for early detection |
| Unpinned analyzer versions | Inconsistent results | Pin all analyzer versions |

---

## Checklist

When configuring quality gates:

- [ ] Build gate with zero tolerance for errors
- [ ] Test gate with kit-recommended diff coverage threshold (default 100% — see `.claude/rules/quality-gates.md`)
- [ ] Coverage reports uploaded as artifacts
- [ ] CodeQL or equivalent SAST enabled
- [ ] Credential scanning enabled (CredScan/detect-secrets)
- [ ] Dependency scanning enabled
- [ ] Pre-commit hooks configured
- [ ] Roslyn/ESLint analyzers with strict settings
- [ ] Central Package Management for .NET projects
- [ ] All gate failures block pipeline progress
