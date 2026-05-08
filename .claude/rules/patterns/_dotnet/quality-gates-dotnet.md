---
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.sln"
---

# .NET Quality Gates

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal quality-gate commands and the kit's coverage discipline. Canonical LENS pipelines do NOT gate ring promotion on coverage — promotion gates on Managed SDP bake + `ManualValidation@0` + 5-stage region progression (per `references/LENS-Common/sources/plugins/LENS/Quality/lens-pipeline-audit/rules/pipeline-standards-catalog.md`). The coverage threshold below is the kit's recommended discipline (see `.claude/rules/quality-gates.md` for the authoritative kit-wide value: 100% diff coverage). Adopt or override per consumer project.

Quality gate commands for .NET projects. Execute after each phase with actual output as proof.

## Gate Commands

| Gate | Command | Success Criteria |
|------|---------|------------------|
| Build | `dotnet build --no-incremental` | Exit 0, "0 Error(s)" |
| Test | `dotnet test --no-build` | "Passed!, Failed: 0" |
| Coverage | `dotnet test --collect:"XPlat Code Coverage"` | 100% diff line coverage (kit policy; see `quality-gates.md`) |
| Format | `dotnet format --verify-no-changes` | Exit 0 |
| Security | `dotnet list package --vulnerable` | No high/critical vulnerabilities |

## Detailed Gate Specifications

### Build Gate

```bash
dotnet build --no-incremental -c Release
```

**Success criteria**:
- Exit code 0
- Output contains "Build succeeded"
- Output contains "0 Error(s)"
- Warnings should be reviewed (treat as errors in CI)

**If fails**: Fix compilation errors before proceeding.

### Test Gate

```bash
dotnet test --no-build -c Release --logger "console;verbosity=normal"
```

**Success criteria**:
- Exit code 0
- Output shows "Passed!"
- Output shows "Failed: 0"
- No skipped tests without justification

**If fails**: Use Graduated Test Recovery (do NOT re-run full suite immediately):

### Graduated Test Recovery (MANDATORY on test failure)

When tests fail, narrow scope first, widen only after fix is confirmed:

| Level | Scope | Command | When to Use |
|-------|-------|---------|-------------|
| 1 | Single test | `dotnet test tests/<Project>.Tests --filter "FullyQualifiedName~<TestClass>.<Method>"` | TDD red-green cycle, debugging a specific failure |
| 2 | Test class | `dotnet test tests/<Project>.Tests --filter "FullyQualifiedName~<TestClass>"` | After fixing a test, check siblings |
| 3 | Test project | `dotnet test tests/<Project>.Tests` | After completing a task |
| 4 | Affected projects | `dotnet test tests/Domain.Tests tests/Application.Tests` | After changes spanning layers |
| 5 | Full solution | `dotnet test src/consumer-project.sln` | Phase gates only |

**Test Impact Heuristic** (default behavior for progressive validation):

This heuristic is used by default for progressive validation via the test-selector agent.
See `.claude/agents/test-selector.md` for agent implementation.

| Changed Layer | Run These Test Projects |
|--------------|------------------------|
| `src/Domain/` | `Domain.Tests` |
| `src/Application/` | `Application.Tests`, `Api.Tests` |
| `src/Infrastructure/` | `Infrastructure.Tests` |
| `src/Api/` | `Api.Tests` |
| Multiple layers / phase gate | Full solution (`src/consumer-project.sln`) |

**Conservative fallback**: When changed files cannot be confidently mapped to a layer (e.g., configuration files, build scripts, unknown file types), the test-selector falls back to running the full test suite. False positives (running extra tests) are preferred over false negatives (missing affected tests).

**Filter syntax (xUnit)**:
```bash
# Exact test method
dotnet test --filter "FullyQualifiedName~HitPointsTests.Constructor_WithValidValue"

# All tests in a class
dotnet test --filter "FullyQualifiedName~HitPointsTests"

# By xUnit Trait
dotnet test --filter "Category=Integration"

# Exclude slow tests during TDD
dotnet test --filter "Category!=Integration"

# Combine with OR
dotnet test --filter "FullyQualifiedName~TestA|FullyQualifiedName~TestB"
```

**NEVER run `dotnet test src/consumer-project.sln` during a TDD red-green cycle.**

### Coverage Gate

```bash
dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage
```

**Success criteria** (kit-internal policy; see `.claude/rules/quality-gates.md`):
- **100% diff line coverage** (all changed lines covered)
- New code MUST be covered
- Branch / function targets per `.claude/rules/patterns/cicd-quality-gates.md` § Coverage Thresholds (kit-recommended)

> Kit-internal policy, not a canonical LENS pipeline gate. Consumer projects MAY override this stance in their own CLAUDE.md.

**Viewing coverage** (requires reportgenerator):
```bash
reportgenerator -reports:./coverage/**/coverage.cobertura.xml -targetdir:./coverage/report -reporttypes:Html
```

#### Merging Coverage XMLs (Required for ADO PR Diff-Coverage)

Running `dotnet test` per project leaves `N` separate coverage XMLs (one per test project). The merge step is implicit but mandatory for ADO PR diff-coverage gating, otherwise only one project's coverage is reported.

```bash
# After running dotnet test on all test projects, merge the per-project XMLs into one Cobertura report
reportgenerator \
  -reports:./coverage/**/coverage.cobertura.xml \
  -targetdir:./coverage/report \
  -reporttypes:"Cobertura;Html"
```

The merged `Cobertura.xml` produced under `./coverage/report/` is what feeds ADO's diff-coverage tab. Local diff-coverage measurement uses `.claude/scripts/Measure-DiffCoverage.ps1` (see `.claude/rules/quality-gates.md` § "Local Diff Coverage" — ADO remains the source of truth; local measurement is systematically lower).

### Format Gate

```bash
dotnet format --verify-no-changes --verbosity diagnostic
```

**Success criteria**:
- Exit code 0
- No files would be modified

**If fails**: Run `dotnet format` to fix, then re-verify.

### Security Gate

```bash
dotnet list package --vulnerable --include-transitive
```

**Success criteria**:
- No packages with "High" or "Critical" severity
- Medium severity should be reviewed
- Low severity acceptable but track

**If vulnerabilities found**: Update packages or document exception.

## Gate Checklist Template

```markdown
## Phase [N] Gate Checklist (.NET)

### Gate 1: Build
Command: `dotnet build --no-incremental -c Release`
Output:
```
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

### Gate 2: Tests
Command: `dotnet test --no-build -c Release`
Output:
```
Passed!  - Failed:     0, Passed:    47, Skipped:     0, Total:    47
```

### Gate 3: Coverage
Command: `dotnet test --collect:"XPlat Code Coverage"`
Output:
```
Line coverage: 84.2%
Branch coverage: 78.5%
```

### Gate 4: Format
Command: `dotnet format --verify-no-changes`
Output:
```
Formatted code file count: 0
```

### Gate 5: Security
Command: `dotnet list package --vulnerable`
Output:
```
The following sources were used:
   https://api.nuget.org/v3/index.json

No packages with known vulnerabilities were found.
```

### Gate Result: PASS
```

## CI/CD Integration

### Azure Pipelines

```yaml
- task: DotNetCoreCLI@2
  displayName: 'Build'
  inputs:
    command: 'build'
    arguments: '--no-incremental -c Release /p:TreatWarningsAsErrors=true'

- task: DotNetCoreCLI@2
  displayName: 'Test'
  inputs:
    command: 'test'
    arguments: '--no-build -c Release --collect:"XPlat Code Coverage"'

- task: DotNetCoreCLI@2
  displayName: 'Format Check'
  inputs:
    command: 'custom'
    custom: 'format'
    arguments: '--verify-no-changes'
```

### GitHub Actions

```yaml
- name: Build
  run: dotnet build --no-incremental -c Release

- name: Test
  run: dotnet test --no-build -c Release --collect:"XPlat Code Coverage"

- name: Format Check
  run: dotnet format --verify-no-changes
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Build warnings | Add `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` to csproj |
| Low coverage | Add tests for uncovered branches, use coverage report to identify gaps |
| Format differences | Ensure `.editorconfig` is committed and consistent |
| Vulnerable packages | Run `dotnet outdated` to identify update candidates |
