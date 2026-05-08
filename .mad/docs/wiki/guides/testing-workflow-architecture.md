# Testing Workflow Architecture

> **Scope note**: this guide is a **concrete case study** documenting how a Microsoft 5-layer .NET service (LENS-CMS) wires the kit's testing primitives end-to-end. Paths like `sources/test/CMS/src/...`, scripts like `Run-DotnetGates.ps1`, and `ACI` deployment specifics are LENS-CMS-flavored and serve as a worked example. The kit's generic testing patterns live in `wiki/patterns/`. Non-.NET / non-Azure consumers adapt the substrate but the **5-subsystem decomposition** (gates → test-selector → test-plan generation → live-browser testing → E2E-in-isolated-environment) generalizes.

End-to-end testing architecture spanning .NET unit/integration tests, quality gates, test-selector agent, AI-driven browser testing, and ACI-based E2E validation.

---

## System Overview

```
   .NET Unit/Integration          /testplan              /live-test               Test-E2E-ACI.ps1
   (Run-DotnetGates.ps1)         (Generate)              (Execute)               (Infrastructure)
         |                            |                       |                        |
         v                            v                       v                        v
  +--------------+           +----------+           +--------------+          +----------------+
  | Build, Test, |           | Workflow  |           | LLM          |          | ACI Container  |
  | Coverage,    |           | Discovery |--plans--> | Navigators   |          | (Managed ID)   |
  | Diff Cov,    |           | Loop      |           | (Playwright) |          | (VNet-injected)|
  | Format       |           +----------+           +--------------+          +----------------+
  +--------------+                |                    |        |                |           |
    |        |                    v                    v        v                v           v
  Pass/Fail  test-selector   test-plans/*.md      Triage    Fix Loop       API Tests    Cosmos/
             (tier select)                        Report    (code-impl)    (bash)       AppInsights
                                                     |         |               |         Verification
                                                     v         v               v
                                                FINAL-REPORT.md           Exit 0/1/2
```

Five independent subsystems that share conventions but serve different purposes:

| Subsystem | Skill/Script | What It Does | When To Use |
|-----------|-------------|--------------|-------------|
| **.NET Quality Gates** | `Run-DotnetGates.ps1` | Build, test, coverage, format validation | Every phase gate; before every commit |
| **Test Selector** | `test-selector` agent | Picks minimum safe test tier from git diff | During `/mad-implement` phase checkpoints |
| **Test Plan Generation** | `/testplan` | Discovers workflows, generates dual-mode plans | Before testing; when routes change |
| **Live Browser Testing** | `/live-test` | AI navigators execute plans against real app | After deployment; regression checks |
| **ACI E2E Testing** | `Test-E2E-ACI.ps1` | API behavioral tests in Azure Container Instance | CI/CD gate; post-deploy verification |

---

## 1. .NET Unit & Integration Tests

### Test Projects

Five test projects under `sources/test/CMS/src/`, mirroring the 5-layer dev architecture:

| Test Project | Tests | What It Tests | Time |
|-------------|-------|---------------|------|
| **Common.Tests** | ~1,410 | Domain models, DTOs, validation, constants | ~155ms |
| **BusinessLogic.Tests** | ~836 | Handlers, mappers, business rules | ~885ms |
| **DataAccess.Tests** | ~1,405 | Cosmos DB repositories, queries | ~1m 21s |
| **Worker.Tests** | — | Background worker processors, metrics | — |
| **API.Tests** | ~691 | Controllers, middleware, integration (E2E scope) | ~7m 34s |

**Total**: ~4,400+ tests. Full suite: ~10 minutes.

### Framework & Tooling

| Component | Technology |
|-----------|-----------|
| Test Framework | **MSTest** (`[TestClass]`, `[TestMethod]`, `[TestCategory]`) |
| Assertions | **FluentAssertions** |
| Mocking | **NSubstitute** |
| Coverage | **coverlet.collector** (XPlat Code Coverage, Cobertura XML) |
| Web Testing | **Microsoft.AspNetCore.Mvc.Testing** (API.Tests, Worker.Tests) |
| Time Testing | **Microsoft.Extensions.TimeProvider.Testing** (Worker.Tests) |

### Test Categories (MSTest `[TestCategory]`)

| Category | Usage | Count |
|----------|-------|-------|
| `Unit` | Primary unit tests | ~77 classes |
| `Validation` | Input/model validation | ~12 classes |
| `SupportingEntities` | Supporting entity tests | ~10 classes |
| `Serialization` | JSON serialization | ~8 classes |
| `DTOs` | DTO structure tests | ~5 classes |
| `Scenario` | Scenario-based tests | ~5 classes |
| `CoreEntities` | Core domain entities | ~5 classes |
| `Configuration` | Config option tests | ~4 classes |
| `Integration` | Integration tests | ~1 class |

### Naming Convention

`Method_Scenario_Expected` (e.g., `GetCaseById_WhenCaseExists_ReturnsCase`)

### Coverage Configuration

**Run settings**: `sources/test/CMS/coverage.runsettings`

```xml
<Format>cobertura</Format>
<ExcludeByAttribute>ExcludeFromCodeCoverage,GeneratedCodeAttribute,CompilerGeneratedAttribute</ExcludeByAttribute>
<ExcludeByFile>**/*.g.cs</ExcludeByFile>
```

**Thresholds**:
- Overall line coverage: **90%** (enforced by `Run-DotnetGates.ps1`)
- Diff coverage: **100%** (enforced by `Measure-DiffCoverage.ps1` and ADO pipeline)

### MSTest Filter Syntax

```bash
# Single method
dotnet test --filter "FullyQualifiedName~CaseHandlerTests.CreateCase"

# All in class
dotnet test --filter "FullyQualifiedName~CaseHandlerTests"

# By category
dotnet test --filter "TestCategory=Unit"

# Exclude category
dotnet test --filter "TestCategory!=Integration"

# OR combine
dotnet test --filter "FullyQualifiedName~TestA|FullyQualifiedName~TestB"
```

---

## 2. Quality Gates (`Run-DotnetGates.ps1`)

### Purpose

Single script that replaces separate `dotnet build/test/format` commands. Runs all gates sequentially, reports compact summary, exits with count of failed gates.

### Gates

| Gate | Command | Success Criteria |
|------|---------|------------------|
| **1: Build** | `dotnet build --nologo -v q` | Exit 0, 0 errors |
| **2: Test** | `dotnet test --no-build --collect:"XPlat Code Coverage"` | `Passed!`, 0 failed |
| **3: Coverage** | Parse `coverage.cobertura.xml` | Line coverage >= 90% |
| **3b: Diff Coverage** | `Measure-DiffCoverage.ps1 -Json` | Diff coverage >= 100% |
| **4: Format** | `dotnet format --verify-no-changes --no-restore` | Exit 0, 0 violations |

### Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `-SolutionPath` | Auto-discovers default location | Path to `.sln` file |
| `-SkipBuild` | false | Skip build gate |
| `-SkipTest` | false | Skip test gate |
| `-SkipFormat` | false | Skip format gate |
| `-SkipCoverage` | false | Skip coverage gate |
| `-SkipDiffCoverage` | false | Skip diff coverage gate |
| `-CoverageThreshold` | 90 | Minimum overall line coverage % |

### Invocation

```bash
# Run all gates
powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1

# Skip format check during early development
powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1 -SkipFormat

# Lower coverage threshold for exploratory work
powershell.exe -NoProfile -File .claude/scripts/Run-DotnetGates.ps1 -CoverageThreshold 80
```

### Gate Failure Behavior

- **Build fails**: Shows last 20 lines of output
- **Test fails**: Shows first 10 failing test names
- **Coverage fails**: Shows line% vs threshold
- **Diff Coverage fails**: Shows first 10 uncovered file:line locations
- **Format fails**: Shows first 5 formatting violations

### Diff Coverage (`Measure-DiffCoverage.ps1`)

Enforces 100% diff coverage — every changed line must be covered by a test.

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `-SolutionPath` | Auto-discover | Path to `.sln` file |
| `-BaseBranch` | `origin/master` | Comparison branch for `git diff` |
| `-Threshold` | 100 | Minimum diff coverage % |
| `-Json` | false | Output JSON for programmatic parsing |
| `-ShowVerbose` | false | Detailed line-by-line report |

Output JSON schema: `{ pass, diffCoveragePercent, coveredLines, totalChangedLines, uncoveredLines, threshold, uncoveredDetails[] }`

---

## 3. Test Selector Agent

### Purpose

Analyzes `git diff` and selects the minimum safe test scope using a Test Impact Heuristic. Invoked by `/mad-implement` at phase checkpoints (Phase 5.5). **Read-only** — recommends a `dotnet test` command but never runs it.

### 4-Tier Validation Architecture

| Tier | Name | Test Scope | Time | When to Use |
|------|------|------------|------|-------------|
| **0** | TDD Red/Green | Single test (`--filter`) | <1s | TDD cycle (caller handles) |
| **1** | Fast Unit | Common.Tests + BusinessLogic.Tests | ~1s | Development rapid feedback |
| **2** | Full Unit | Tier 1 + DataAccess.Tests | ~82s | Pre-commit, data access changes |
| **3** | Core + Integration | Tier 2 + Integration.Tests | ~90s | Phase gate, safety fallback |
| **4** | Full Suite (E2E) | All including API.Tests | ~7m 40s | PR gate, nightly only |

### Test Impact Heuristic

| Changed Layer | Run These Projects | Tier |
|--------------|-------------------|------|
| `src/Common/` | Common.Tests | 1 |
| `src/BusinessLogic/` | BusinessLogic.Tests, API.Tests | 1-2 |
| `src/DataAccess/` | DataAccess.Tests | 2 |
| `src/Api/` | API.Tests | 2-3 |
| `tests/` only | Affected test project | 1-2 |
| `src/DependencyInjection/` or `src/Worker/` | All test projects | 3 |
| `.csproj`, `.sln`, `Directory.Build.props` | Full solution | 3 (fallback) |
| `.json`, `.yml`, `.md`, unknown | Full solution | 3 (fallback) |

### Confidence Scoring

| Score | Classification | Action |
|-------|---------------|--------|
| >= 90% | HIGH | Use recommended tier |
| 70-89% | MEDIUM | Use recommended tier, note reduced confidence |
| < 70% | LOW | Fallback to Tier 3 |

**Conservative bias**: when uncertain, include MORE tests. The PR gate (Tier 4) is the ultimate safety net.

### Output

Selection log written to `.claude/work-items/{WI-ID}/artifacts/test-selections/YYYYMMDD-HHMM.md` (or `.mad/scratch/test-selection-{date}.md` if no active work item).

---

## 4. TDD Workflow

### Red-Green-Refactor

1. **Red**: Write/update test that captures expected behavior (test fails)
2. **Green**: Modify source to make the test pass (minimal code)
3. **Refactor**: Clean up without changing behavior (tests still pass)

### Advisory Hook

A non-blocking hook reminds when modifying `.cs`/`.ts` source files without recent test changes. Excluded: `*.md`, `*.json`, `*.yaml`, `*.yml`, `*.xml`, `*.csproj`, `*.props`, `*.sln`. Cooldown: 5 minutes. Disable: `TDD_ADVISORY_ENABLED=false` in `settings.local.json`.

### Test Failure Protocol

**All failures discovered during your work are your responsibility.**

1. **Categorize**: Run tests on `main` to distinguish regressions vs pre-existing
2. **Regressions**: Fix immediately, verify with `--filter`, re-run full suite
3. **Pre-existing** — choose one:
   - **Fix now** if trivial (<30 min)
   - **Track** via `/mad-spec` bug template
   - **Skip** with `[Ignore("reason")]` (MSTest)
4. **Report**: State count, categories, actions taken

**FORBIDDEN**: Dismissing failures as "pre-existing/unrelated" without action.

### Graduated Test Recovery

| Level | Scope | Command |
|-------|-------|---------|
| 1 | Single test | `--filter "FullyQualifiedName~Class.Method"` |
| 2 | Test class | `--filter "FullyQualifiedName~Class"` |
| 3 | Test project | Single project path |
| 4 | Affected projects | Multiple project paths |
| 5 | Full solution | `CMS.sln` (all projects) |

---

## 5. Test Plan Generation (`/testplan`)

### Purpose

Generates and maintains structured test plan files for every UI/UX workflow. Plans are consumed by `/live-test` navigators. This skill generates plans but does not execute tests.

### Discovery Loop (Phase 0)

```
discovered = {}
loop:
  1. scan frontend/src/router.tsx        (routes)
  2. scan frontend/src/pages/**/*.tsx     (page components)
  3. scan src/Api/Controllers/**/*.cs     (API endpoints)
  4. diff against existing test-plans/
  5. if no new workflows found -> EXIT
  6. generate plan for each new workflow
  7. discovered.add(new workflows)
  8. goto loop
```

Exit condition: full scan produces zero uncovered workflows.

### Dual-Mode Design

Every plan contains two independent sections:

| Attribute | Local Mode | E2E Mode |
|-----------|-----------|----------|
| Backend | Mocked (MSW / vi.mock) | Real running service |
| Mocks | Allowed | **FORBIDDEN** |
| API Verification | Spy on calls | **REQUIRED** (GET after every mutation) |
| Data Persistence | Optional | **REQUIRED** (refresh + re-GET) |
| Auth | Stub tokens | Real credentials |

The defining rule: a plan that only asserts UI state (toasts, spinners) is **incomplete** for E2E mode. Every mutation must be verified via a GET to confirm the write hit the database.

### Plan File Structure

Location: `.claude/skills/live-test/test-plans/{scenario-id}.md`

```
# Test Plan: {scenario-id}

## Metadata
  Scenario ID, Module, Priority (P0/P1/P2), Route, Dependencies

## Test Accounts
  Role, Email, Password (seeded credentials)

## Seed Data
  Entity names, IDs, statuses

## Local Mode
  Setup (test file path, mock framework)
  Steps (render, interact, assert)
  Assertions (component renders, loading/success/error/empty states, API spy)
  Mock Error Scenarios (400, 401, 404, 500, timeout)

## E2E Mode
  Prerequisites (app running, API healthy, seed data present)
  Steps (navigate, interact, submit)
  API Verification (curl GET after every POST/PUT/PATCH)
  Assertions (UI + API response + data persistence)
  Error Scenarios (invalid data, unauthorized access)

## Known Issues / Pass-Fail History
```

### Completeness Criteria

A plan is complete when it has:
- Both Local and E2E sections
- 3+ UI assertions per mode
- 1+ API verification assertion in E2E
- 1+ data persistence assertion in E2E
- 1+ error scenario per mode
- Seed data with real UUIDs (not placeholders)

### Invocation

```bash
/testplan                          # Discover all, generate missing, loop until done
/testplan --scope auth             # Scope to one module
/testplan --workflow story-upload   # Single workflow
/testplan --update                 # Re-scan routes, add new plans
```

### Coverage Report

Written to `.mad/scratch/testplan/coverage-report.md` after generation:
- Total workflows discovered
- Plans generated (new) / updated / skipped
- Workflows without plans (should be 0 after loop)

---

## 6. Live Browser Testing (`/live-test`)

### Purpose

AI-driven manual browser testing where LLM navigators act as human QA testers against a live application using Playwright. Not a test suite runner -- an AI agent following structured test plans.

### Architecture

```
Orchestrator (/live-test)
    |
    +-- Phase 0: Pre-flight
    |       Verify app reachable, API healthy, seed data present
    |       Build test queue from plans
    |       Create scratch directories
    |
    +-- Phase 1: Triage (parallel)
    |       Spawn up to 6 navigators
    |       Each gets disjoint module slice
    |       Each reads test plan, executes steps, records PASS/FAIL/SKIP
    |       Screenshots on failure
    |       Aggregate -> triage/report.md
    |
    +-- Phase 2: Fix (if failures found and --no-fix not set)
    |       Spawn code-implementer agent
    |       Receives aggregated triage report
    |       Fixes root causes, rebuilds/redeploys
    |       Reset seed data, verify health
    |
    +-- Phase 3: Validate (re-test failures only)
    |       Spawn validator navigator(s)
    |       Re-run only failed features
    |       Report PASS/FAIL
    |
    +-- Loop: repeat Phase 2-3 until max_loops or 0 failures
    |
    +-- Phase 4: Final Report
            FINAL-REPORT.md with verdict: PASS / PARTIAL / FAIL
```

### Operating Modes

#### Standard Mode (default)

Up to 6 navigators spawn in parallel via a single Task tool message (synchronous parallel, never `run_in_background`). Each navigator receives a disjoint module slice (auth, dashboard, case-queue, etc.).

Navigator prompt includes:
- Base URL and testing mode (e2e/local)
- Test credentials
- Assigned module and feature list
- Instruction to read test plan before each scenario

Results written to `.mad/scratch/live-test/triage/report-{module}.md`.

#### Team Mode (`--team`)

Navigators use TaskList/TaskUpdate atomic claim loop:

```
Navigator loop:
  1. TaskList() -> find unclaimed scenarios
  2. TaskUpdate({ taskId, owner: self, status: "in_progress" })
  3. Read test plan for claimed scenario
  4. Execute test
  5. Write results to team-results/{navigator-id}/{task-id}.md
  6. TaskUpdate({ taskId, status: "completed", metadata: { result } })
  7. Loop until no pending tasks
```

No central assignment logic. Mutual exclusion via atomic `TaskUpdate(owner)`. Scales to any navigator count.

### E2E API Verification Pattern

```
Action:  POST /v1/cases  ->  UI shows "Case created" toast
Verify:  GET /v1/cases/{id}  ->  must return case record
         Response updatedAt within last 60 seconds
         Refresh page (F5) -> data still present
FAIL if: GET returns 404 or empty body after UI showed success
```

### Anti-Patterns (Always Bugs in E2E Mode)

| Anti-Pattern | Why It Fails |
|--------------|-------------|
| `page.route('**/api/**', ...)` | Mocking defeats E2E purpose |
| No GET after form submission | Write may not have persisted |
| Asserting only toast message | Toast fires before DB confirms |
| `vi.mock()` in Playwright E2E | Mock intercepts real backend |
| Skipping error state testing | Missing coverage for failure paths |

### Output Artifacts

```
.mad/scratch/live-test/
  test-queue.json                  Scenario list with plan filenames
  triage/
    report-{module}.md             Per-navigator results
    report.md                      Aggregated triage
    screenshots/{module}/          Failure screenshots
  fixes/
    fix-{N}.md                     Fix summaries per loop iteration
  validation/
    report-{N}.md                  Re-test results per loop
  team-results/
    {navigator-id}/
      {task-id}.md                 Per-navigator results (team mode)
  FINAL-REPORT.md                  Final verdict and summary
```

### Invocation

```bash
/live-test                                      # Full E2E, fix loop on
/live-test --mode local                         # Local mode with mocks
/live-test --scope auth                         # One module only
/live-test --no-fix                             # Triage only, no fixes
/live-test --max-loops 2                        # Cap fix iterations
/live-test --base-url https://app-tonym.azurewebsites.net   # Deployed env
/live-test --team                               # Agent Teams claim loop
```

---

## 7. ACI E2E Testing (`Test-E2E-ACI.ps1`)

### Purpose

Runs behavioral API tests inside an Azure Container Instance with Managed Identity authentication. Tests the deployed consumer-project API endpoints, Cosmos DB persistence, and App Insights observability -- no browser, no UI.

### Architecture

```
Developer Workstation                    Azure (westus3)
+------------------------+              +----------------------------------+
| Test-E2E-ACI.ps1       |              | rg-<svc>-{env}                   |
|   1. Resolve MI        |--az rest---->|                                  |
|   2. Resolve Subnet    |              |  +----------------------------+  |
|   3. Delete old ACI    |              |  | aci-<svc>-test-{env}       |  |
|   4. Encode test script|              |  | mcr.microsoft.com/         |  |
|   5. Create ACI (ARM)  |              |  |   azure-cli:latest         |  |
|   6. Poll completion   |              |  |                            |  |
|   7. Retrieve logs     |              |  | Test-Api-ACI.sh            |  |
|   8. Cleanup           |              |  |   get MI token (IMDS)      |  |
+------------------------+              |  |   run test suites           |  |
                                        |  |   verify Cosmos DB          |  |
                                        |  |   verify App Insights       |  |
                                        |  +------|--------|--------|---+  |
                                        |         |        |        |      |
                                        |         v        v        v      |
                                        |  App Service  Cosmos DB  App     |
                                        |  (Private EP) (Private)  Insights|
                                        +----------------------------------+
```

### Orchestrator (`Test-E2E-ACI.ps1`)

Parameters:
- `-Environment` (required): name of the target env (e.g. `dev-tonym`, `test`)
- `-Suite`: `full` (default), `per-milestone`, `cross-milestone`, `data-verification`, `observability`, `cleanup`
- `-SkipCleanup`: Retain container for log inspection
- `-WhatIf`: Dry-run

Steps:
1. Resolve Managed Identity (`id-<svc>-{env}-<region>`) via Azure AD
2. Resolve ACI subnet (`snet-aci`) in VNet for network injection
3. Delete any existing test container
4. Base64-encode `Test-Api-ACI.sh` (with `tr -d "\r"` for Windows line endings)
5. Create ACI via `az rest` ARM API with MI, VNet subnet, env vars
6. Poll container state every 15 seconds until terminal state or timeout
7. Retrieve container logs and exit code
8. Cleanup container (unless `-SkipCleanup`)

Timeouts by suite:

| Suite | Timeout |
|-------|---------|
| `full` | 40 min |
| `observability` | 20 min |
| `cross-milestone` | 15 min |
| default | 10 min |

### Test Script (`Test-Api-ACI.sh`)

Runs inside the ACI container. 1100+ lines of bash with structured test helpers.

**Authentication**: Managed Identity via IMDS endpoint (`169.254.169.254`) or ACI identity endpoint. Acquires app-only tokens for:
- Consumer-project API: `api://<api-client-id>`
- Cosmos DB: `https://cosmos-<svc>-{env}-<region>.documents.azure.com`
- App Insights: `https://api.applicationinsights.io`

Token retry: 4 attempts with linear backoff (5s, 10s, 15s -- no sleep after final attempt).

**Test Helper Functions**:

| Function | Purpose |
|----------|---------|
| `log_pass()` / `log_fail()` / `log_skip()` | Result tracking |
| `get_token()` | MI token acquisition with retry |
| `api_call()` / `api_call_no_auth()` | Authenticated/unauthenticated HTTP |
| `get_last_etag()` | Extract ETag from response headers |
| `assert_status()` | HTTP status code assertion |
| `assert_json()` | JSON field value assertion (dot-notation) |
| `assert_json_exists()` | JSON field existence check |
| `assert_json_array_len()` | Array length assertion |
| `cosmos_query()` | Partition-scoped Cosmos DB query |
| `create_test_case()` | Create unique case with `E2E-{epoch}-{suffix}` title |

**Test Suites**:

| Suite | Tests |
|-------|-------|
| **Baseline** | Health check, auth check (401), list cases, create/get/patch case, Cosmos verify, App Insights verify |
| **M018** | Notes CRUD, Communications CRUD |
| **M019** | Agencies list/get, Agents list/get |
| **M020** | NDO extension create/list, past-date rejection (400) |
| **M021** | DFT lifecycle (create, state transitions), missing If-Match (428), invalid transitions (422) |
| **M022** | Attachment upload (multipart), download, SHA256 hash verification |
| **M023** | Aggregates query, invalid type rejection |
| **M024** | Case events create/query by type/date/actor |
| **Authorizations** | Authorization create, list, 401 auth check |
| **Escalations** | Escalation CRUD lifecycle (create, get, update status, delete, verify 404), 401 auth check |

**Exit Codes**: `0` = all passed, `1` = failures, `2` = skipped-critical (skip count > 0 but no failures).

### Local Smoke Test (`Test-Api.ps1`)

Portable PowerShell version of baseline tests. Runs locally or from Kudu SSH.

```powershell
# From Kudu SSH with Managed Identity
.\Test-Api.ps1 -AuthMode ManagedIdentity

# Locally with pre-acquired token
$token = az account get-access-token --resource "api://..." --query accessToken -o tsv
.\Test-Api.ps1 -Token $token
```

Tests: health check, list cases, create case, get case, patch case (with ETag).

---

## 8. Agent Eval via ACI (`Deploy-EvalContainer.ps1`)

A separate but related ACI workflow that evaluates Claude agent scenarios (not API tests).

```
Deploy-EvalContainer.ps1
    |
    +-- Create ACI (mcr.microsoft.com/dotnet/sdk:10.0, 4 CPU, 8 GB)
    +-- Runs Eval-Entrypoint.sh inside container
    |     Install Node.js, Claude CLI, .NET SDK
    |     Checkout commit, run scenario(s)
    |     Output structured JSON results
    +-- Parse results, upload to blob storage
    +-- Store-EvalResults.ps1
          -> stlenscmseval{env}wus3 / eval-results/
             {branch}/{YYYY}/{MM}/{run_id}.json
             {branch}/latest.json
```

Scenarios: `investigate-and-implement`, `review-and-fix`, `coverage-loop`, `mutation-detection`, `workflow-fidelity`, `cross-repo-consistency`.

Result schema (v2.0) includes: timing, token usage, cost, assertion pass rate, LLM-as-Judge scores, multi-dimensional scoring, and cost regression detection.

---

## 9. Integration Points

### Deployment Pipeline Position

```
git push -> Ado-Build.ps1 -> Deploy.ps1 -> Assign-AppRoles.ps1
                                                        |
                                                        v
                                               Test-E2E-ACI.ps1  (Gate)
                                                        |
                                                        v
                                               /live-test --base-url (Optional)
```

ACI E2E tests are the CI/CD gate (Tier 4). Live-test is for deeper regression checking post-deploy.

### Progressive Validation Tiers

| Tier | Scope | Time | Trigger |
|------|-------|------|---------|
| **0** | Single test (`--filter`) | <1s | TDD red-green |
| **1** | Common.Tests + BusinessLogic.Tests | ~1s | Development |
| **2** | + DataAccess.Tests | ~82s | Pre-commit |
| **3** | + Integration | ~90s | Phase gate |
| **4** | Full suite + E2E (ACI) | 7-40 min | PR gate / nightly |
| **5a** | E2E Smoke (`@p0`) | 30s-1min | UI feature phase gate |
| **5b** | E2E Critical (`@p0`, `@p1`) | 2-5min | Pre-merge PR gate |
| **5c** | E2E Full Suite | 5-10min | Pre-release only |

Use `test-selector` agent to auto-select minimum tier based on `git diff`.

### Workflow Connections

```
Run-DotnetGates.ps1 ------> Build + Test + Coverage + Format (every commit)
                                |
test-selector agent ---------> Picks minimum test tier from git diff
                                |
/testplan  ----generates----> .claude/skills/live-test/test-plans/*.md
                                          |
/live-test ----reads plans----------------+
           ----spawns------> navigators (Playwright)
           ----spawns------> code-implementer (fix loop)
           ----writes------> .mad/scratch/live-test/FINAL-REPORT.md

/mad-validate --runs E2E---> Playwright smoke (@p0) + full suite
              --checks-----> feature-traceability coverage

Test-E2E-ACI.ps1 ---------> ACI container (bash tests, MI auth)
                  ---------> Cosmos DB verification
                  ---------> App Insights verification

Deploy-EvalContainer.ps1 --> ACI container (agent evals, .NET SDK)
                         --> Blob storage (results JSON)
```

### Quality Gates (Mandatory)

| Gate | Command | Success |
|------|---------|---------|
| Build | `Run-DotnetGates.ps1` | Exit 0 |
| Test | `Run-DotnetGates.ps1` | All pass, 0 failed |
| Coverage | `Run-DotnetGates.ps1` | Line >= 90% |
| Diff Coverage | `Run-DotnetGates.ps1` | 100% diff coverage |
| Format | `Run-DotnetGates.ps1` | Exit 0, 0 violations |
| Pre-flight | `Check-Preflight.ps1` | All checks pass |
| E2E (ACI) | `Test-E2E-ACI.ps1` | Exit 0 |

---

## 10. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| MSTest + NSubstitute + FluentAssertions | Common large-enterprise .NET test stack; consistent across ecosystem reference repos |
| 90% overall + 100% diff coverage | High bar on new code; legacy code covered incrementally |
| Test-selector agent (not manual tier selection) | Eliminates human guesswork; conservative bias prevents missed regressions |
| Dual-mode plans (Local + E2E) | Fast feedback during dev (mocks) + real verification on deploy |
| API verification required in E2E | UI assertions alone don't prove data persisted |
| ACI with Managed Identity | No credentials in scripts; VNet injection for private endpoint access |
| Separate orchestrator from test script | PowerShell manages Azure infra; bash runs tests inside container |
| LLM navigators follow plans, don't explore | Reproducible test execution; no ad-hoc wandering |
| Parallel navigators by module slice | Disjoint UI modules prevent navigator conflicts |
| Triage-Fix-Validate loop | Self-healing: find bugs, fix them, verify fixes, repeat |
| Agent Teams mode (optional) | Coordinator-less claim loop for large test suites |
| Linear backoff on MI tokens | ACI identity endpoint can be slow to become available |
| `tr -d "\r"` on base64 decode | Windows line endings break bash execution in Linux containers |

---

## 11. File Reference

### Test Projects
| File | Purpose |
|------|---------|
| `src/consumer-project/sources/test/CMS/src/Common.Tests/` | Domain model, DTO, validation tests |
| `src/consumer-project/sources/test/CMS/src/BusinessLogic.Tests/` | Handler and business logic tests |
| `src/consumer-project/sources/test/CMS/src/DataAccess.Tests/` | Cosmos DB repository tests |
| `src/consumer-project/sources/test/CMS/src/Worker.Tests/` | Background worker tests |
| `src/consumer-project/sources/test/CMS/src/API.Tests/` | API controller and integration tests |
| `src/consumer-project/sources/test/CMS/coverage.runsettings` | Coverage collection configuration |

### Skills
| File | Purpose |
|------|---------|
| `.claude/skills/testplan/SKILL.md` | Test plan generation skill definition |
| `.claude/skills/live-test/SKILL.md` | Live browser testing skill definition |
| `.claude/skills/live-test/test-plans/*.md` | Persistent test plan files |

### Scripts
| File | Purpose |
|------|---------|
| `.claude/scripts/Run-DotnetGates.ps1` | Quality gates runner (build, test, coverage, format) |
| `.claude/scripts/Measure-DiffCoverage.ps1` | Diff coverage enforcement (100% threshold) |
| `.claude/scripts/Test-E2E-ACI.ps1` | ACI E2E orchestrator (PowerShell) |
| `.claude/scripts/Test-Api-ACI.sh` | Behavioral test suite (bash, runs in ACI) |
| `.claude/scripts/Test-Api.ps1` | Local smoke test (PowerShell) |
| `.claude/scripts/Test-Api.sh` | Local smoke test (bash) |
| `.claude/scripts/Deploy-EvalContainer.ps1` | Agent eval ACI deployment |
| `.claude/scripts/Store-EvalResults.ps1` | Eval results uploader |
| `.mad/tests/Eval-Entrypoint.sh` | Agent eval bootstrap (runs in ACI) |

### Agents
| File | Purpose |
|------|---------|
| `.claude/agents/test-selector.md` | Test impact analysis and tier selection |

### Rules & Patterns
| File | Purpose |
|------|---------|
| `.claude/rules/quality-gates.md` | Universal quality gate enforcement |
| `.claude/rules/test-discipline.md` | TDD workflow and failure protocol |
| `.claude/rules/e2e-testing-patterns.md` | Playwright E2E patterns and journey priorities |
| `.claude/rules/patterns/quality-gates-dotnet.md` | .NET-specific gate commands and filter syntax |
| `.claude/rules/patterns/dotnet-testing.md` | Unit test structure, naming, builders, mocking |
| `.claude/rules/patterns/dotnet-testing-integration.md` | Integration test fixtures, API tests |
| `.claude/rules/patterns/behavioral-testing.md` | Backend + frontend behavioral test patterns |
| `.claude/rules/patterns/frontend-ux-testing.md` | Frontend-project-specific test conventions |

### Configuration
| File | Purpose |
|------|---------|
| `.claude/agent-teams-config.json` | Agent Teams enable/disable |
| `.claude/settings.local.json` | Environment flags (AGENT_TEAMS, TDD_ADVISORY, etc.) |

### Outputs
| Directory | Contents |
|-----------|----------|
| `.mad/scratch/live-test/` | Triage reports, fix summaries, screenshots, final report |
| `.mad/scratch/testplan/` | Coverage reports |
| `.mad/tests/results/` | Agent eval results (JSON + raw logs) |
| `.claude/work-items/{WI-ID}/artifacts/test-selections/` | Test selector decision logs |
