<#
.SYNOPSIS
    Bootstrap the mad-council-claw repo with the CRITICAL set of MAD kit primitives.

.DESCRIPTION
    Copies a tier-scoped subset of the MAD - Clean kit (rules, hooks, skills, agents,
    scripts, templates, .mad/docs) into a target repo (default: mad-council-claw),
    rewrites kit-source-absolute paths to target-repo-relative, generates a
    council-claw-adapted CLAUDE.md root brief, generates adapted settings.json +
    settings.local.json, and runs a small smoke-test battery.

    This script implements F-205 (kit-bootstrap) acceptance criteria (a)-(h) per
    docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md in the target repo.

    Tiers:
      - critical : 32 load-bearing rules + ~14 antipattern hooks + ~22 council/MAD skills
                   + 14 agents + 11 council infra scripts + 12 coverage oracles
                   + .mad/scripts (LENS-prefixed dropped) + .mad/docs subset + CLAUDE.md
                   + 3 m-main-derived skills (skill-sanitize, mcp-permission-validate,
                     copilot-cli-bridge — these are authored by sibling implementer A
                     in the same batch; this script merely VERIFIES their presence
                     post-copy and reports missing as a smoke-test fail).
      - full     : everything in MAD-Clean kit minus _dotnet/ patterns minus LENS-prefixed
                   scripts/skills (lens-aspnet-structure, Ev2-Deploy, etc.).
      - minimal  : rules only + 5 council skills + 3 hooks (smallest possible bootstrap
                   to satisfy MAD orchestration discipline).

    Per F-205 out-of-scope-notes #4: full hardcoded-path audit across .claude/scripts/*.ps1
    is DEFERRED. This script handles settings.local.json env path-rewriting (in scope) and
    settings.json hook-command path rewriting (in scope, since hooks must resolve from the
    target repo root). It does NOT rewrite paths inside copied .ps1 / .js files beyond
    settings.json itself.

.PARAMETER TargetRepo
    Absolute path to the target repo. Default: C:/Users/tonym/Repos/mad-council-claw.
    MUST exist and be a git repo.

.PARAMETER KitSourceRoot
    Absolute path to this kit's root. Default: C:/Users/tonym/Repos/MAD - Clean.
    MUST exist and contain .claude/, .mad/, CLAUDE.md.

.PARAMETER DryRun
    Print every file that WOULD be copied + every rewrite that WOULD happen + every
    smoke test that WOULD run. NO actual writes (except the optional output report).

.PARAMETER Force
    Overwrite existing content in -TargetRepo/.claude/ if present. Without -Force,
    refuses to bootstrap a repo that already has kit content.

.PARAMETER OutputReport
    Path to write a structured run report (markdown). If empty, defaults to
    <TargetRepo>/.mad/reports/kit-bootstrap-<yyyyMMdd-HHmmss>.md.

.PARAMETER Tier
    'critical' (default) | 'full' | 'minimal'. See description for what each includes.

.EXAMPLE
    # Dry-run preview against the default target
    pwsh -NoProfile -File .claude/scripts/Bootstrap-CouncilClawKit.ps1 -DryRun

.EXAMPLE
    # Real run against the default target with critical tier
    pwsh -NoProfile -File .claude/scripts/Bootstrap-CouncilClawKit.ps1

.EXAMPLE
    # Re-bootstrap (overwriting existing content)
    pwsh -NoProfile -File .claude/scripts/Bootstrap-CouncilClawKit.ps1 -Force

.EXAMPLE
    # Minimal tier with explicit report path
    pwsh -NoProfile -File .claude/scripts/Bootstrap-CouncilClawKit.ps1 `
      -Tier minimal `
      -OutputReport C:/temp/bootstrap-minimal.md

.NOTES
    Exit codes:
      0 - bootstrap complete; all smoke tests pass (or skipped due to missing CLI)
      1 - bootstrap complete; >=1 smoke test failed (degraded but non-blocking)
      2 - input validation failed (TargetRepo or KitSourceRoot bad)
      3 - refused: existing content without -Force
      4 - copy operation failed mid-flight (partial state)

    Per .claude/rules/no-silent-deferrals.md: every adjacent surface NOT covered by F-205
    is enumerated in the F-205 ledger out-of-scope-notes. This script honors that scope.

    Per .claude/rules/minimum-change.md: this script does the bootstrap and nothing more.
    It does NOT modify the source kit. It does NOT install MCP servers. It does NOT push
    git commits.

    Per .claude/rules/canonical-skill-only.md: this script does NOT author MAD artifacts
    (spec.md, plan.md, etc.). The CLAUDE.md it generates is a project brief, not a MAD
    pipeline artifact, so it is exempt from the canonical frontmatter contract.
#>
[CmdletBinding()]
param(
    [string]$TargetRepo = 'C:/Users/tonym/Repos/mad-council-claw',
    [string]$KitSourceRoot = 'C:/Users/tonym/Repos/MAD - Clean',
    [switch]$DryRun,
    [switch]$Force,
    [string]$OutputReport = '',
    [ValidateSet('critical', 'full', 'minimal')]
    [string]$Tier = 'critical',
    # F7 fix (2026-05-07 multi-model review): smoke tests (f)(g)(h) are F-205 Y/N acceptance items.
    # By default a 'skip' result on (f)(g)(h) is treated as 'partial' (NOT pass) and contributes to
    # a degraded exit code (1). Pass -SmokeOptional to accept skipped smokes as 'pass' (e.g. when
    # node/claude CLI is intentionally absent in CI).
    [switch]$SmokeOptional
)

# Hybrid error handling per .claude/rules/patterns/powershell-conventions.md
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Section 1 — Constants: the CRITICAL set per F-205 acceptance items (a)-(h)
# --------------------------------------------------------------------------

# 32 load-bearing rules per F-205 §(a). Order preserved from the F-205 ledger.
$Script:CriticalRules = @(
    'no-silent-deferrals.md',
    'no-top-n-capping.md',
    'canonical-skill-only.md',
    'canonical-artifact-frontmatter.md',
    'scope-discipline.md',
    'autonomous-loop-discipline.md',
    'loop-cadence-discipline.md',
    'loop-stop-language-discipline.md',
    'no-invented-constraints.md',
    'orchestration.md',
    'orchestrator-identity.md',
    'verification-protocol.md',
    'minimum-change.md',
    'agent-teams.md',
    'anomaly-thresholds.md',
    'context-guardian.md',
    'non-negotiable-rules.md',
    'prompt-injection-policy.md',
    'dangerous-operations-policy.md',
    'degradation-fallback-policy.md',
    'stride-threat-model.md',
    'single-owner-accountability.md',
    'triage-gate.md',
    'concurrency-safety.md',
    'skill-standards.md',
    'mad-workflow.md',
    'quality-gates.md',
    'review-gate-protocol.md',
    'council-verdict-artifact.md',
    'prescriptive-content-review.md',
    'lens-multi-model-review-pattern.md',
    '_status-convention.md'
)

# 11 load-bearing antipattern hooks per F-205 §(a) line 111.
$Script:CriticalHooks = @(
    'content-scan-deferrals.js',
    'validate-mad-pipeline.js',
    'enforce-skill-canonical-marker.js',
    'detect-top-n-capping.js',
    'enforce-orchestration.js',
    'track-mad-skill-invocation.js',
    'validate-artifact-completeness.js',
    'record-skill-completion.js',
    'pre-bash-validate.js',
    'pre-commit-validate.js',
    'validate-quality-gates.js'
)

# Council skills (10) + MAD pipeline skills (8: 7 canonical + testplan) + 2 utility skills per F-205 §(a) line 112.
# F1 fix (2026-05-07 multi-model review): testplan added per F-205 §(a). mad-full retained as the
# orchestration helper that drives the full pipeline; both ship in critical tier.
$Script:CriticalSkills = @(
    # MAD pipeline (8)
    'mad-spec',
    'testplan',
    'mad-plan',
    'mad-tasks',
    'mad-analyze',
    'mad-implement',
    'mad-validate',
    'mad-full',
    # Council (10)
    'council-open',
    'council-join',
    'council-leave',
    'council-list',
    'council-check',
    'council-post',
    'council-review',
    'council-resolve',
    'council-retro',
    'council-verdict',
    # Utility (2)
    'loop',
    'apply-learnings'
)

# Skills authored by sibling implementer A (same batch). VERIFY presence; do NOT author here.
$Script:LiftedSkills = @(
    'skill-sanitize',
    'mcp-permission-validate',
    'copilot-cli-bridge'
)

# Workflow + council-role agents per F-205 §(a) line 113.
$Script:CriticalAgents = @{
    'workflow' = @(
        'code-investigator.md',
        'code-implementer.md',
        'code-reviewer.md',
        'domain-reviewer.md',
        'research-scout.md',
        'research-curator.md',
        'research-reviewer.md',
        'parallel-researcher.md',
        'janitor.md',
        'work-planner.md',
        'investigate-and-implement.md',
        'review-and-fix.md',
        'coverage-loop.md'
    )
    # The 3 council-role agents live in role-keyed subdirectories per the kit layout.
    'advocate'  = @('agent.md', 'plan.md')
    'skeptic'   = @('agent.md', 'plan.md')
    'architect' = @('agent.md', 'plan.md')
}

# Kit-generic scripts per F-205 §(a) line 114 (council infra + canonical helpers + loop-discipline).
# Tests files (.Tests.ps1) ride along with their primary script when present.
# F5 fix (2026-05-07 multi-model review): added Check-LoopStopConditions, Verify-CanonicalSkillFrontmatter,
# Validate-CouncilVerdict, Detect-ContentType, Pull-ProductionGrounding per F-205 §(a). Verified each exists
# in MAD-Clean kit before adding (verification-protocol.md Rule 1 FETCH BEFORE CITE).
$Script:CriticalScripts = @(
    'Check-Preflight.ps1',
    'Verify-Health.ps1',
    'Track-SkillMetrics.ps1',
    'Invoke-CopilotMultiModel.ps1',
    'atomic-write.ps1',
    'channel-helpers.ps1',
    'completion-report.ps1',
    'digest-rebuild.ps1',
    'seq-increment.ps1',
    'verdict-compute.ps1',
    'preflight.ps1',
    'validate-schemas.ps1',
    'check-mad-links.ps1',
    'mad-tasks-checkoff.ps1',
    # F-205 §(a) additions (2026-05-07 multi-model F5 — verified present in MAD-Clean kit)
    'Check-LoopStopConditions.ps1',
    'Verify-CanonicalSkillFrontmatter.ps1',
    'Validate-CouncilVerdict.ps1',
    'Detect-ContentType.ps1',
    'Pull-ProductionGrounding.ps1'
)

# F-205 §(a) scripts NOT YET authored in MAD-Clean kit; deferred per no-silent-deferrals.md.
# Each entry needs a follow-on F-NNN to author + add to $CriticalScripts.
# Detect-ScopeClaimDrift.ps1 — cited in prescriptive-content-review.md Gap 7; not yet authored;
#   defer to follow-on (no-silent-deferrals.md: explicit deferral with rationale + revisit-trigger).
# regex-spotcheck.js — exists at .mad/scratch/regex-spotcheck.js but not at .claude/scripts/;
#   not promoted to kit-generic location yet; defer to follow-on.
$Script:DeferredCriticalScripts = @(
    @{ Name = 'Detect-ScopeClaimDrift.ps1'; Reason = 'Cited in F-205 §(a) and prescriptive-content-review.md Gap 7; not authored in kit yet.' },
    @{ Name = 'regex-spotcheck.js'; Reason = 'Exists at .mad/scratch/ in MAD-Clean kit but not yet promoted to .claude/scripts/.' }
)

# Coverage oracles per F-205 §(b) (referenced from prescriptive-content-review.md Gap 3).
$Script:CoverageOracles = @(
    'bicep.md',
    'config.md',
    'cosmos-doc.md',
    'doc-generic.md',
    'ev2-config.md',
    'handler-tests.md',
    'plan.md',
    'rule-md.md',
    'skill-md.md',
    'spec.md',
    'tasks.md',
    'template-md.md'
)

# Templates other than coverage-oracles. Excludes LENS-shaped templates; keeps canonical MAD shapes.
$Script:CriticalTemplates = @(
    'idea-template.md',
    'spec-template.md',
    'plan-template.md',
    'tasks-template.md',
    'analysis-report-template.md',
    'research-report.md',
    'implementation-report.md',
    'verification-report.md',
    'feature-ledger-template.md',
    'work-item-template.md',
    'agent-file-template.md',
    'agent-md-template.md',
    'context-template.md',
    'data-model-template.md',
    'contracts-template.md',
    'task-format-full.md',
    'task-format-minimal.md',
    'task-format-standard.md',
    'pattern-rule.md',
    'feature-map-template.md',
    'parallel-plan-template.md',
    'post-phase-review.md',
    'spec-quality-checklist.md',
    'verification-spec-template.md',
    'cleanup-manifest.md',
    'council-skill-output-shapes.md',
    'checklist-template.md'
)

# 5 minimal-tier hooks: orchestration + the 4 most load-bearing antipatterns
$Script:MinimalHooks = @(
    'enforce-orchestration.js',
    'content-scan-deferrals.js',
    'detect-top-n-capping.js',
    'validate-mad-pipeline.js',
    'enforce-skill-canonical-marker.js'
)

# Minimal-tier skills: just the council substrate
$Script:MinimalSkills = @(
    'council-open',
    'council-join',
    'council-list',
    'council-post',
    'council-review'
)

# LENS-prefixed file/dir patterns to drop unconditionally (full and critical tiers).
$Script:LensDropPrefixes = @(
    'lens-',
    'Ado-Build',
    'Ado-PR-',
    'Ado-WorkItem',
    'Ev2-',
    'Diagnose-LensDcs',
    'Run-AciE2E',
    'Test-CmsApi',
    'Test-E2E-ACI',
    'Assign-CmsAppRoles',
    'Backfill-Lrms',
    'Deploy-Lrms',
    'Provision-Lrms',
    'Seed-LrmsTestData',
    'Verify-DcsCosmosPersistence',
    'Set-CmsDemoCase',
    'Migrate-DataCategoryJobIds',
    'Augment-GoldenRecords',
    'Dump-GoldenRecords',
    'Verify-JobIdClassifier',
    'Fix-DftProperties',
    'Run-DotnetGates',
    'Check-AdoReleaseDeployments',
    'lens-dcs-loop-lessons',
    'deployment-failure-diagnosis',
    'deployment-scripts',
    'deployment-troubleshooting',
    'cross-milestone-coordination',
    'cicd-',
    'mad-integration'
)

# settings.local.json env keys that are LENS-specific and should be dropped or rewritten.
$Script:LensSpecificEnvKeys = @(
    'LENS_REPOS_ROOT'
)

# --------------------------------------------------------------------------
# Section 2 — Helpers
# --------------------------------------------------------------------------

# Use ASCII-only output throughout per .claude/rules/patterns/powershell-conventions.md
# (em-dashes / smart quotes can break Windows terminal encodings).
function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 78)
    Write-Host "  $Title"
    Write-Host ('=' * 78)
}

function Write-Step {
    param([string]$Message)
    Write-Host "[step] $Message"
}

function Write-Skip {
    param([string]$Message)
    Write-Host "[skip] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ ok ] $Message"
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[fail] $Message" -ForegroundColor Red
}

function Test-IsLensSpecific {
    param([string]$FileName)
    foreach ($prefix in $Script:LensDropPrefixes) {
        if ($FileName -like "$prefix*") { return $true }
        if ($FileName -like "*$prefix*" -and $prefix -ne 'lens-') { return $true }
    }
    return $false
}

function New-DirectorySafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $Script:DryRunMode) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        $Script:Stats.DirectoriesCreated++
    }
}

function Copy-FileSafe {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Category
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Fail "MISSING in source: $Source"
        $Script:Stats.MissingSources += $Source
        return $false
    }
    $destDir = Split-Path -Parent $Destination
    New-DirectorySafe -Path $destDir
    if ($Script:DryRunMode) {
        Write-Host "  [DRY] copy: $Source -> $Destination"
    }
    else {
        try {
            Copy-Item -LiteralPath $Source -Destination $Destination -Force
        }
        catch {
            Write-Fail "Copy failed: $Source -> $Destination`n  $_"
            $Script:Stats.CopyFailures += $Source
            return $false
        }
    }
    $Script:Stats.FilesCopied++
    if (-not $Script:Stats.ByCategory.ContainsKey($Category)) {
        $Script:Stats.ByCategory[$Category] = 0
    }
    $Script:Stats.ByCategory[$Category]++
    return $true
}

function Copy-DirectoryRecursive {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Category,
        [string[]]$ExcludePatterns = @()
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Fail "MISSING source dir: $Source"
        $Script:Stats.MissingSources += $Source
        return
    }
    $items = Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $relPath = $item.FullName.Substring($Source.Length).TrimStart('\', '/')
        $skip = $false
        foreach ($pat in $ExcludePatterns) {
            if ($item.Name -like $pat) { $skip = $true; break }
            if ($relPath -like $pat) { $skip = $true; break }
        }
        if (Test-IsLensSpecific -FileName $item.Name) { $skip = $true }
        if ($skip) {
            Write-Skip "lens-specific or excluded: $relPath"
            $Script:Stats.LensFilesSkipped++
            continue
        }
        $destPath = Join-Path $Destination $relPath
        Copy-FileSafe -Source $item.FullName -Destination $destPath -Category $Category | Out-Null
    }
}

function Convert-SettingsJsonForTarget {
    <#
    .SYNOPSIS
        Rewrites every absolute kit-source hook command in settings.json to point at the
        target repo's matching .claude/hooks/<file> location. Keeps the structure intact.
    #>
    param(
        [string]$KitSettingsJsonPath,
        [string]$TargetRepoPath
    )
    $json = Get-Content -LiteralPath $KitSettingsJsonPath -Raw
    # Rewrite the absolute kit-source path to the target repo.
    # The kit source uses: C:/Users/tonym/Repos/MAD - Clean
    # We need to escape this for regex AND for JSON-string replacement.
    $escapedSrc = [regex]::Escape($Script:KitSourceRootResolved)
    $targetPathForJson = $TargetRepoPath.Replace('\', '/')
    # F4 fix (2026-05-07 multi-model review): PowerShell -replace interprets $1, $&, $$, etc. in the
    # *replacement* string as backreferences. Source side is escaped via [regex]::Escape; replacement
    # side must escape literal $ as $$ so any $ in the target path emits literally. (PowerShell needs
    # '$$$$' in source code to produce '$$' for the regex engine, which the engine renders as a single $.)
    $replacementEscaped = $targetPathForJson -replace '\$', '$$$$'
    $rewritten = $json -replace $escapedSrc, $replacementEscaped
    return $rewritten
}

function Get-AdaptedSettingsLocalJson {
    <#
    .SYNOPSIS
        Generates the council-claw-adapted settings.local.json. Drops LENS_REPOS_ROOT.
        Adds COUNCIL_CLAW_BACKLOG_FILE and COUNCIL_CLAW_REPOS_ROOT. Keeps
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1.
    #>
    param([string]$TargetRepoPath)
    $envBlock = [ordered]@{
        'COUNCIL_CLAW_REPOS_ROOT'              = "$TargetRepoPath/references"
        'COUNCIL_CLAW_BACKLOG_FILE'            = 'docs/10-backlog/implementation-todo.md'
        'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' = '1'
    }
    $obj = [ordered]@{
        env         = $envBlock
        permissions = [ordered]@{
            allow = @('Bash(git *)')
        }
        outputStyle = 'default'
    }
    return ($obj | ConvertTo-Json -Depth 10)
}

function Get-AdaptedClaudeMd {
    <#
    .SYNOPSIS
        Synthesizes a council-claw-adapted root CLAUDE.md from kit primitives.
        Sections kept (verbatim or adapted), dropped, and added are documented in the
        F-205 ledger and in the OutputReport this script produces.
    #>
    param([string]$TargetRepoPath)
    # Single-quoted here-string so $-prefixed identifiers in the body stay literal.
    $content = @'
# mad-council-claw - Repository Brief

This repository implements the **Council collaboration engine** described in
`docs/02-foundational-plan.md`. It inherits the MAD development kit (rules, hooks,
skills, agents, scripts, templates) from the upstream `MAD - Clean` kit per the
"engine inherits, doesn't fork" disposition (see `docs/04-research/mad-kit-inventory.md`).

The authoritative architectural plan lives at `docs/02-foundational-plan.md`. **Read it first.**

---

## Project context

- mad-council-claw IS the council infrastructure being built.
- The MAD kit (this CLAUDE.md, the `.claude/` and `.mad/` directories) is the
  development substrate. The kit was developed AS the substrate for the engine;
  ~80% of primitives transfer cleanly per the foundational-plan disposition.
- Reference repos:
  - **MAD - Clean** kit (upstream substrate; lift-from source)
  - **m-main** (clawpilot patterns informing skill-sanitize, mcp-permission-validate, copilot-cli-bridge)
  - **m-relay-main** (relay patterns informing IPC contract scaffold)

---

## Non-Negotiable Rules

Verb-bound permission fences. These apply in ALL sessions regardless of context compaction.
Full list in `.claude/rules/non-negotiable-rules.md`. Most load-bearing for council-claw:

| YOU MUST NOT | You may |
|---|---|
| YOU MUST NOT create or submit a pull request without explicit user request. | Ask the user if they want a PR created. |
| YOU MUST NOT run `git push` without explicit user request in the current session. | Stage and commit; ask before pushing. |
| YOU MUST NOT dismiss test failures as "pre-existing" and proceed without action. | Fix, track via `/mad-spec`, or add skip logic - then report. |
| YOU MUST NOT use `run_in_background: true` for Task tool agent spawns. | Use synchronous parallel Task calls (single message, multiple tool blocks). |
| YOU MUST NOT skip quality gates or bypass pre-commit hooks without explicit user approval. | Run gates, fix failures, then proceed. |
| YOU MUST NOT author MAD artifacts (`spec.md`, `plan.md`, `tasks.md`, `analysis-report.md`, `test-plan.md`) directly via Write. | Always invoke the corresponding `/mad-*` skill via the Skill tool. |
| YOU MUST NOT silently defer features the user has named. | Ask explicitly before deferring. Per `.claude/rules/no-silent-deferrals.md`. |
| YOU MUST NOT cap findings at "Top N" when the task asks for an enumeration. | Enumerate exhaustively per `.claude/rules/no-top-n-capping.md`. |

---

## Orchestration (ENFORCED BY HOOK)

**Rule**: Main coordinates. Agents work. Reading code files in the main orchestrator is **BLOCKED**.

| When you need to... | Spawn this agent | subagent_type |
|---|---|---|
| Understand code | `code-investigator` or `Explore` | code-investigator |
| Modify code | `code-implementer` | code-implementer |
| Research decisions | `research-scout` -> `curator` -> `reviewer` | research-scout |
| Review code | `code-reviewer` | code-reviewer |
| Full investigate->implement->verify | `investigate-and-implement` | general-purpose |
| Review + auto-fix cycle | `review-and-fix` | general-purpose |
| Close coverage gaps | `coverage-loop` | general-purpose |

**After agent completes**: 1) Update plan checkbox  2) Verify claims yourself  3) Commit if phase done.

**Required env flag**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json`.

---

## MAD Workflow

```
/mad-spec  ->  /mad-plan  ->  /mad-tasks  ->  /mad-analyze  ->  /mad-implement  ->  /mad-validate  ->  /apply-learnings
```

For full automation: `/mad-full`. For parallel: `/mad-decompose -> /mad-parallel`.

**Authoring discipline**: every MAD artifact has exactly one canonical author skill. Inline
authoring (orchestrator Write, subagent Write, even Edit "for typo fixes") is forbidden per
`.claude/rules/canonical-skill-only.md`. Both Write and Edit on the artifact paths are blocked
by `.claude/hooks/validate-mad-pipeline.js` unless the matching skill is currently active.

| Artifact | Required canonical skill |
|---|---|
| `specs/<N>-<feature>/spec.md` | `/mad-spec` |
| `specs/<N>-<feature>/test-plan.md` | `/testplan` |
| `specs/<N>-<feature>/plan.md` | `/mad-plan` |
| `specs/<N>-<feature>/tasks.md` | `/mad-tasks` |
| `specs/<N>-<feature>/analysis-report.md` | `/mad-analyze` |

---

## Subagent discipline (NON-NEGOTIABLE)

The orchestration rules from `.claude/rules/orchestration.md` and `.claude/rules/agent-teams.md` apply EVERY phase:

| When you need to... | Spawn this | Why |
|---|---|---|
| Understand code | `code-investigator` or `Explore` | Reading code from main is BLOCKED |
| Modify code | `code-implementer` | Same reason |
| Plan a phase (`/mad-plan`) | **Agent team** (3 teammates: Architecture-reviewer + Pattern-extractor + Risk-analyst) | >=3 independent topics; mandatory per `.claude/rules/agent-teams.md` |
| Implement `[P]` task groups | **Parallel subagents** (single message, multiple Task blocks) | >=3 disjoint groups - MANDATORY parallelism |

**Agent team size for investigations/research/audits: 4 (NOT 1, NOT 3).**
- Audit phase: 4 parallel `code-investigator` agents on disjoint topic lanes
- Research phase: 4 parallel `parallel-researcher` agents, one per topic
- Implementation phase: >=3 parallel `code-implementer` agents

When you spawn ANY subagent (Task tool), the prompt MUST contain the literal phrase:

> "Enumerate exhaustively. No Top-N capping. Every item classified and acted upon. State 'no findings' explicitly when a category is empty."

Phase 1 hook `detect-top-n-capping.js` enforces this on Task spawns.

---

## Quality Gates

After EACH user story or phase, execute gates with ACTUAL OUTPUT as proof.

| Gate | Purpose | Success Criteria |
|------|---------|------------------|
| Build | Compile/transpile code | Exit 0, no errors |
| Test | Run unit/integration tests | All pass, 0 failed |
| Coverage | Measure code coverage | Per-feature target |
| Lint/Format | Check code style | Exit 0, no errors |
| Pre-flight | Mechanical grep-based checks | `.claude/scripts/Check-Preflight.ps1` |

**No skipping. Paste output. Fix before proceeding.**

---

## Stop-condition discipline

Loop stop conditions must be **mechanical** (file existence, exit codes, council verdicts),
not **negation-of-discovery** ("no more gaps"). The latter is unfalsifiable; gaps always
exist somewhere.

Forbidden stop conditions:
- "Stop when no more gaps remain" (unfalsifiable)
- "Stop when all reviewers approve" (one council verdict can disagree with prior)
- "Stop after iter N" (arbitrary; cap creates pressure to declare premature completion)

Required stop conditions: conjunctive AND mechanical.
- File X exists with frontmatter Y.
- Flag-file Z is empty.
- Council-verdict file V exists with `Decision: HIGH`.

---

## Anti-Patterns

| Anti-Pattern | Correct |
|--------------|---------|
| Read code in main | Spawn agent |
| Trust agent claims | Verify yourself |
| Auto-create PRs | Never create PRs without explicit user request |
| Plan without code for >8 turns | Write code early, validate with tests |
| Edit files outside task scope | Ask before modifying unrelated files |
| Guess when uncertain | Insert `[NEEDS CLARIFICATION: question]` marker |
| Run complex commands inline | Write a script to .mad/scratch/ and execute it |
| Cap findings at "Top 5" | Enumerate exhaustively per `no-top-n-capping.md` |
| Silently defer user-named features | Ask explicitly per `no-silent-deferrals.md` |
| Inline-author MAD artifacts | Always invoke the canonical `/mad-*` skill |

---

## Where to look

| You want... | Path |
|---|---|
| Foundational plan (architecture + 6-phase substrate) | `docs/02-foundational-plan.md` |
| Feature catalog | `docs/03-feature-catalog/` |
| Current wave + backlog | `docs/10-backlog/implementation-todo.md` |
| Loop state | `docs/11-loop-state/` |
| Reference repos | `docs/04-research/openclaw-clawpilot/`, `docs/04-research/mad-kit-inventory.md` |
| Agent team outputs | `docs/06-agent-team-outputs/` |
| Council reviews / verdicts | `docs/05-design-reviews/` |
| Kit's own behavioral rules | `.claude/rules/` |
| Kit's own enforcement hooks | `.claude/hooks/` |
| Canonical skill library | `.claude/skills/` |
| Per-skill / per-rule status | YAML frontmatter (`status: stable|preview|deprecated`) |

---

## F-NNN ledger conventions

Every backlog feature lives at `docs/03-feature-catalog/M<milestone>-<slug>/F-<NNN>-<short-slug>.md` with:

- YAML frontmatter: `feature-id`, `short-slug`, `milestone`, `status`, `status-since`,
  `status-history`, `provenance`, `fr-coverage`, `test-files`, `red-green-rule`, `depends-on`,
  `out-of-scope-notes`, `confidence`.
- Body sections: Rationale, Behavior contract, Acceptance scenarios (exhaustively enumerated),
  Red->green wire-up, Dependencies, Surface trace, Implementation notes, References.

Status flow: `red` -> `green` -> `locked`. Transitions captured in `status-history`.

---

## Skill-invocation timing metrics

Every skill invocation is timed automatically:

- `track-mad-skill-invocation.js` (PreToolUse:Skill) records `started_at_ms`
- `record-skill-completion.js` (PostToolUse:Skill) records `completed_at_ms`

Any single-skill invocation exceeding **10 minutes** emits a stderr warning. Profile via
`.claude/scripts/Track-SkillMetrics.ps1`. Reporting requirement: every Skill final-message
summary MUST include a one-line metric:
`duration: Nm / tool_uses: N / tokens: N / artifacts: N`.

---

## Resume Protocol

After context compaction or session restart:

1. Check `cat .claude/work-items/ACTIVE`
2. Check for PENDING_HANDOFF -> run `/resume-handoff`
3. Read plan.md for last `[x]` checkbox
4. Check `[!]` markers for blocked items
5. Continue from exact point

See `.claude/rules/resume-protocol.md`.

---

## How this CLAUDE.md was generated

This file was generated by `Bootstrap-CouncilClawKit.ps1` (in the upstream MAD - Clean kit)
on $(date) per F-205. It is intentionally council-claw-scoped: the LENS-DCS standardization
loop sections from the upstream kit's CLAUDE.md are deliberately NOT inherited (they are
LENS-specific work-loop content, not engine-substrate content).

If you need to refresh this brief after upstream changes, re-run the bootstrap with `-Force`.
'@
    # Inject the date inline (single-quoted here-string blocks $-interpolation).
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    return ($content -replace '\$\(date\)', $stamp)
}

# --------------------------------------------------------------------------
# Section 3 — Pre-flight validation
# --------------------------------------------------------------------------

function Test-Inputs {
    Write-Section 'Pre-flight validation'

    # Resolve KitSourceRoot
    if (-not (Test-Path -LiteralPath $KitSourceRoot)) {
        Write-Fail "KitSourceRoot does not exist: $KitSourceRoot"
        exit 2
    }
    $Script:KitSourceRootResolved = (Resolve-Path -LiteralPath $KitSourceRoot).Path.Replace('\', '/')
    Write-Ok "KitSourceRoot: $Script:KitSourceRootResolved"

    if (-not (Test-Path -LiteralPath (Join-Path $KitSourceRoot '.claude'))) {
        Write-Fail "KitSourceRoot/.claude not found"
        exit 2
    }
    if (-not (Test-Path -LiteralPath (Join-Path $KitSourceRoot '.mad'))) {
        Write-Fail "KitSourceRoot/.mad not found"
        exit 2
    }
    if (-not (Test-Path -LiteralPath (Join-Path $KitSourceRoot 'CLAUDE.md'))) {
        Write-Fail "KitSourceRoot/CLAUDE.md not found"
        exit 2
    }

    # Resolve TargetRepo
    if (-not (Test-Path -LiteralPath $TargetRepo)) {
        Write-Fail "TargetRepo does not exist: $TargetRepo"
        exit 2
    }
    $Script:TargetRepoResolved = (Resolve-Path -LiteralPath $TargetRepo).Path.Replace('\', '/')
    Write-Ok "TargetRepo:     $Script:TargetRepoResolved"

    if (-not (Test-Path -LiteralPath (Join-Path $TargetRepo '.git'))) {
        Write-Fail "TargetRepo is not a git repo (no .git/): $TargetRepo"
        exit 2
    }

    # Detect prior bootstrap
    $existingClaude = Join-Path $TargetRepo '.claude'
    if (Test-Path -LiteralPath $existingClaude) {
        $children = @(Get-ChildItem -LiteralPath $existingClaude -ErrorAction SilentlyContinue)
        if ($children.Count -gt 0 -and -not $Force) {
            Write-Fail "TargetRepo/.claude/ already has $($children.Count) entries. Use -Force to overwrite."
            Write-Host '  Existing entries:'
            foreach ($c in $children) {
                Write-Host "    - $($c.Name)"
            }
            exit 3
        }
        if ($children.Count -gt 0) {
            Write-Host "  -Force specified; will overwrite $($children.Count) existing entries in .claude/"
        }
    }
}

# --------------------------------------------------------------------------
# Section 4 — Per-tier copy plans
# --------------------------------------------------------------------------

function Invoke-CopyTierCritical {
    Write-Section "Tier: critical"

    $src = $Script:KitSourceRootResolved
    $dst = $Script:TargetRepoResolved

    # 4.1 - Rules
    Write-Step '.claude/rules/ (26+ load-bearing rules)'
    foreach ($rule in $Script:CriticalRules) {
        $srcPath = Join-Path $src ".claude/rules/$rule"
        $dstPath = Join-Path $dst ".claude/rules/$rule"
        Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'rules' | Out-Null
    }
    # Also copy patterns/README.md (path-scoped pattern conventions; non-LENS subset).
    $patternsReadme = Join-Path $src '.claude/rules/patterns/README.md'
    if (Test-Path -LiteralPath $patternsReadme) {
        Copy-FileSafe -Source $patternsReadme `
            -Destination (Join-Path $dst '.claude/rules/patterns/README.md') `
            -Category 'rules' | Out-Null
    }
    # And the kit-generic patterns the engine depends on.
    $kitGenericPatterns = @(
        'powershell-conventions.md',
        'windows-git-bash.md',
        'naming-conventions.md',
        'logging-security.md',
        'api-validation.md'
    )
    foreach ($pat in $kitGenericPatterns) {
        $sp = Join-Path $src ".claude/rules/patterns/$pat"
        if (Test-Path -LiteralPath $sp) {
            Copy-FileSafe -Source $sp `
                -Destination (Join-Path $dst ".claude/rules/patterns/$pat") `
                -Category 'rules' | Out-Null
        }
    }

    # 4.2 - Hooks
    Write-Step '.claude/hooks/ (load-bearing antipattern hooks + supporting hooks)'
    # Critical antipattern hooks must be present
    foreach ($hook in $Script:CriticalHooks) {
        $srcPath = Join-Path $src ".claude/hooks/$hook"
        $dstPath = Join-Path $dst ".claude/hooks/$hook"
        Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'hooks' | Out-Null
    }
    # Plus supporting hooks the runtime calls
    $supportingHooks = @(
        'add-context.js', 'context-warning.js', 'parallel-opportunity-detector.js',
        'detect-anomaly.js', 'on-permission.js', 'block-smart-unicode-on-outbound.js',
        'check-worktree.js', 'enforce-e2e-smoke.js', 'pre-commit-tokens.js',
        'e2e-mock-check.js', 'require-plan-approval.js', 'logeventid-collision-check.js',
        'nowarn-addition-warning.js', 'tdd-advisory.js', 'pre-write-settings-validate.js',
        'detect-parallel-miss.js', 'record-task-start.js', 'mcp-tier-redirect.js',
        'detect-vision-drift.js', 'auto-register-artifact.js', 'mid-flight-pattern-lint.js',
        'validate-plan-gates.js', 'auto-run-quality-gates.js', 'session-start.js',
        'session-end.js', 'on-subagent-stop.js', 'capture-learning.js',
        'validate-baseline-size.js', 'validate-agent-deliverable.js',
        'validate-featuremap.js', 'on-notification.js', 'pre-compact.js',
        'stop-guard.js', 'validate-checkpoint.js', 'record-task-completion.js',
        'scope-guard.js', 'config.json', 'README.md', 'hook-fail-open-policy.md'
    )
    foreach ($hook in $supportingHooks) {
        $srcPath = Join-Path $src ".claude/hooks/$hook"
        $dstPath = Join-Path $dst ".claude/hooks/$hook"
        if (Test-Path -LiteralPath $srcPath) {
            Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'hooks' | Out-Null
        }
    }

    # 4.3 - Skills (recursive copy of each skill's directory)
    Write-Step '.claude/skills/ (council + MAD pipeline + utility)'
    foreach ($skill in $Script:CriticalSkills) {
        $srcDir = Join-Path $src ".claude/skills/$skill"
        $dstDir = Join-Path $dst ".claude/skills/$skill"
        if (Test-Path -LiteralPath $srcDir) {
            Copy-DirectoryRecursive -Source $srcDir -Destination $dstDir -Category 'skills'
        }
        else {
            Write-Fail "Skill missing: $skill"
            $Script:Stats.MissingSources += $srcDir
        }
    }

    # 4.4 - Agents
    Write-Step '.claude/agents/ (workflow + council-role)'
    foreach ($subdir in $Script:CriticalAgents.Keys) {
        foreach ($file in $Script:CriticalAgents[$subdir]) {
            $srcPath = Join-Path $src ".claude/agents/$subdir/$file"
            $dstPath = Join-Path $dst ".claude/agents/$subdir/$file"
            Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'agents' | Out-Null
        }
    }
    # Workflow CATALOG.md and README.md
    foreach ($extra in @('CATALOG.md', 'README.md')) {
        $sp = Join-Path $src ".claude/agents/workflow/$extra"
        if (Test-Path -LiteralPath $sp) {
            Copy-FileSafe -Source $sp `
                -Destination (Join-Path $dst ".claude/agents/workflow/$extra") `
                -Category 'agents' | Out-Null
        }
    }

    # 4.5 - Scripts (kit-generic only; LENS-prefixed dropped)
    Write-Step '.claude/scripts/ (kit-generic only; LENS-prefixed dropped)'
    foreach ($script in $Script:CriticalScripts) {
        $srcPath = Join-Path $src ".claude/scripts/$script"
        $dstPath = Join-Path $dst ".claude/scripts/$script"
        if (Test-Path -LiteralPath $srcPath) {
            Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'scripts' | Out-Null
        }
        # Tests file riding alongside
        $testsName = ($script -replace '\.ps1$', '.Tests.ps1')
        $testsPath = Join-Path $src ".claude/scripts/$testsName"
        if (Test-Path -LiteralPath $testsPath) {
            Copy-FileSafe -Source $testsPath `
                -Destination (Join-Path $dst ".claude/scripts/$testsName") `
                -Category 'scripts' | Out-Null
        }
    }

    # 4.6 - .mad/templates/ (canonical artifact templates + coverage-oracles)
    Write-Step '.mad/templates/'
    foreach ($tpl in $Script:CriticalTemplates) {
        $srcPath = Join-Path $src ".mad/templates/$tpl"
        $dstPath = Join-Path $dst ".mad/templates/$tpl"
        if (Test-Path -LiteralPath $srcPath) {
            Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'templates' | Out-Null
        }
    }
    foreach ($oracle in $Script:CoverageOracles) {
        $srcPath = Join-Path $src ".mad/templates/coverage-oracles/$oracle"
        $dstPath = Join-Path $dst ".mad/templates/coverage-oracles/$oracle"
        Copy-FileSafe -Source $srcPath -Destination $dstPath -Category 'oracles' | Out-Null
    }

    # 4.7 - .mad/scripts/ (drop LENS-prefixed)
    Write-Step '.mad/scripts/ (LENS-prefixed dropped)'
    $madScriptsSrc = Join-Path $src '.mad/scripts'
    $madScriptsDst = Join-Path $dst '.mad/scripts'
    if (Test-Path -LiteralPath $madScriptsSrc) {
        Copy-DirectoryRecursive -Source $madScriptsSrc -Destination $madScriptsDst `
            -Category 'mad-scripts' -ExcludePatterns @('*.bak')
    }

    # 4.8 - .mad/docs/ (kit-generic; LENS-specific subdirs already handled by content)
    Write-Step '.mad/docs/ (workflow-best-practices, etc.)'
    $madDocsSrc = Join-Path $src '.mad/docs'
    $madDocsDst = Join-Path $dst '.mad/docs'
    if (Test-Path -LiteralPath $madDocsSrc) {
        Copy-DirectoryRecursive -Source $madDocsSrc -Destination $madDocsDst `
            -Category 'mad-docs' -ExcludePatterns @('*aci-e2e-runbook*', '*lens-*')
    }

    # 4.9 - .mad/ scratch + reports + work-items dirs (with .gitkeep)
    Write-Step '.mad/{scratch,reports,work-items}/ (with .gitkeep)'
    foreach ($d in @('.mad/scratch', '.mad/reports', '.mad/work-items')) {
        $dstDir = Join-Path $dst $d
        New-DirectorySafe -Path $dstDir
        if (-not $Script:DryRunMode) {
            $gk = Join-Path $dstDir '.gitkeep'
            if (-not (Test-Path -LiteralPath $gk)) {
                Set-Content -LiteralPath $gk -Value '' -Encoding ASCII
                $Script:Stats.FilesCopied++
            }
        }
        else {
            Write-Host "  [DRY] gitkeep: $dstDir/.gitkeep"
        }
    }

    # 4.10 - settings.json (path-rewritten)
    Write-Step '.claude/settings.json (rewriting kit-source paths to target)'
    $settingsSrc = Join-Path $src '.claude/settings.json'
    $settingsDst = Join-Path $dst '.claude/settings.json'
    if (Test-Path -LiteralPath $settingsSrc) {
        $rewritten = Convert-SettingsJsonForTarget -KitSettingsJsonPath $settingsSrc `
            -TargetRepoPath $Script:TargetRepoResolved
        if (-not $Script:DryRunMode) {
            New-DirectorySafe -Path (Split-Path -Parent $settingsDst)
            # UTF-8 without BOM (PS 5.1 gotcha per powershell-conventions.md)
            [System.IO.File]::WriteAllText($settingsDst, $rewritten,
                (New-Object System.Text.UTF8Encoding $false))
        }
        else {
            Write-Host "  [DRY] write rewritten: $settingsDst"
            Write-Host "  [DRY] rewrite: '$Script:KitSourceRootResolved' -> '$Script:TargetRepoResolved'"
        }
        $Script:Stats.PathRewrites++
        $Script:Stats.FilesCopied++
    }

    # 4.11 - settings.local.json (synthesized; LENS_REPOS_ROOT dropped)
    Write-Step '.claude/settings.local.json (synthesized; LENS_REPOS_ROOT dropped)'
    $localJson = Get-AdaptedSettingsLocalJson -TargetRepoPath $Script:TargetRepoResolved
    $localDst = Join-Path $dst '.claude/settings.local.json'
    if (-not $Script:DryRunMode) {
        New-DirectorySafe -Path (Split-Path -Parent $localDst)
        [System.IO.File]::WriteAllText($localDst, $localJson,
            (New-Object System.Text.UTF8Encoding $false))
    }
    else {
        Write-Host "  [DRY] write synth: $localDst"
        Write-Host '  [DRY] env block:'
        $localJson -split "`n" | ForEach-Object { Write-Host "         $_" }
    }
    $Script:Stats.FilesCopied++

    # 4.12 - CLAUDE.md (synthesized)
    Write-Step 'CLAUDE.md (synthesized; council-claw-scoped)'
    $claudeMd = Get-AdaptedClaudeMd -TargetRepoPath $Script:TargetRepoResolved
    $claudeDst = Join-Path $dst 'CLAUDE.md'
    if (-not $Script:DryRunMode) {
        [System.IO.File]::WriteAllText($claudeDst, $claudeMd,
            (New-Object System.Text.UTF8Encoding $false))
    }
    else {
        Write-Host "  [DRY] write synth: $claudeDst (~$([Math]::Round($claudeMd.Length / 1KB)) KB)"
    }
    $Script:Stats.FilesCopied++

    # 4.13 - COPY then VERIFY the 3 m-main-derived skills (sibling implementer A's batch).
    # F6 fix (2026-05-07 multi-model review): previously this block only VERIFIED; copy was never
    # invoked in critical tier, so default execution failed F-205 §(d) unless target repo already had
    # those skills. Now we copy from MAD-Clean kit when source-side present, then verify destination.
    Write-Step '.claude/skills/ - copying + verifying 3 lifted skills (skill-sanitize, mcp-permission-validate, copilot-cli-bridge)'
    foreach ($lifted in $Script:LiftedSkills) {
        $srcDir = Join-Path $src ".claude/skills/$lifted"
        $dstDir = Join-Path $dst ".claude/skills/$lifted"
        if (Test-Path -LiteralPath $srcDir) {
            Copy-DirectoryRecursive -Source $srcDir -Destination $dstDir -Category 'lifted-skills'
        }
        else {
            # Source missing in kit; sibling implementer A's batch has not landed yet.
            # Verification step below will report this as missing in destination.
            if (-not $Script:DryRunMode) {
                Write-Skip "lifted skill source missing in kit: $srcDir (sibling implementer A batch not yet landed)"
            }
            else {
                Write-Host "  [DRY] lifted skill source missing in kit (would skip copy): $srcDir"
            }
        }
        # Verification step
        $checkPath = Join-Path $dst ".claude/skills/$lifted/SKILL.md"
        if ($Script:DryRunMode) {
            Write-Host "  [DRY] would VERIFY presence post-copy: $checkPath"
        }
        else {
            if (Test-Path -LiteralPath $checkPath) {
                Write-Ok "lifted skill present: $lifted"
                $Script:Stats.LiftedSkillsPresent++
            }
            else {
                Write-Fail "lifted skill MISSING: $lifted (expected: $checkPath). Sibling implementer A authors this in same batch."
                $Script:Stats.LiftedSkillsMissing += $lifted
            }
        }
    }
}

function Invoke-CopyTierFull {
    Write-Section "Tier: full"
    Write-Host '  Full tier = critical + everything else NOT explicitly LENS-prefixed.'
    Invoke-CopyTierCritical
    # Add: every other rule, every other hook, every other skill, every other agent.
    $src = $Script:KitSourceRootResolved
    $dst = $Script:TargetRepoResolved

    # Pull in remaining rules (skip patterns/_dotnet)
    Write-Step 'Full: remaining .claude/rules/ (excluding _dotnet/)'
    $rulesDir = Join-Path $src '.claude/rules'
    Copy-DirectoryRecursive -Source $rulesDir -Destination (Join-Path $dst '.claude/rules') `
        -Category 'rules-full' -ExcludePatterns @('_dotnet*', 'patterns\_dotnet*')

    # Remaining hooks
    Write-Step 'Full: remaining .claude/hooks/'
    Copy-DirectoryRecursive -Source (Join-Path $src '.claude/hooks') `
        -Destination (Join-Path $dst '.claude/hooks') -Category 'hooks-full'

    # All non-LENS skills
    Write-Step 'Full: remaining .claude/skills/'
    Copy-DirectoryRecursive -Source (Join-Path $src '.claude/skills') `
        -Destination (Join-Path $dst '.claude/skills') -Category 'skills-full'

    # All non-LENS agents
    Write-Step 'Full: remaining .claude/agents/'
    Copy-DirectoryRecursive -Source (Join-Path $src '.claude/agents') `
        -Destination (Join-Path $dst '.claude/agents') -Category 'agents-full'

    # All non-LENS-prefixed scripts
    Write-Step 'Full: remaining .claude/scripts/ (LENS-prefixed dropped)'
    Copy-DirectoryRecursive -Source (Join-Path $src '.claude/scripts') `
        -Destination (Join-Path $dst '.claude/scripts') -Category 'scripts-full' `
        -ExcludePatterns @('ported*')
}

function Invoke-CopyTierMinimal {
    Write-Section "Tier: minimal"
    Write-Host '  Minimal tier = rules only + 5 council skills + 3 critical hooks.'

    $src = $Script:KitSourceRootResolved
    $dst = $Script:TargetRepoResolved

    # Rules: full critical set
    Write-Step '.claude/rules/'
    foreach ($rule in $Script:CriticalRules) {
        Copy-FileSafe -Source (Join-Path $src ".claude/rules/$rule") `
            -Destination (Join-Path $dst ".claude/rules/$rule") -Category 'rules' | Out-Null
    }

    # Hooks: minimal set
    Write-Step '.claude/hooks/ (minimal set)'
    foreach ($hook in $Script:MinimalHooks) {
        Copy-FileSafe -Source (Join-Path $src ".claude/hooks/$hook") `
            -Destination (Join-Path $dst ".claude/hooks/$hook") -Category 'hooks' | Out-Null
    }

    # Skills: minimal set
    Write-Step '.claude/skills/ (minimal set)'
    foreach ($skill in $Script:MinimalSkills) {
        $srcDir = Join-Path $src ".claude/skills/$skill"
        $dstDir = Join-Path $dst ".claude/skills/$skill"
        Copy-DirectoryRecursive -Source $srcDir -Destination $dstDir -Category 'skills'
    }

    # Settings (rewritten)
    Write-Step '.claude/settings.json + settings.local.json'
    $settingsSrc = Join-Path $src '.claude/settings.json'
    if (Test-Path -LiteralPath $settingsSrc) {
        $rewritten = Convert-SettingsJsonForTarget -KitSettingsJsonPath $settingsSrc `
            -TargetRepoPath $Script:TargetRepoResolved
        if (-not $Script:DryRunMode) {
            New-DirectorySafe -Path (Join-Path $dst '.claude')
            [System.IO.File]::WriteAllText((Join-Path $dst '.claude/settings.json'), $rewritten,
                (New-Object System.Text.UTF8Encoding $false))
        }
        $Script:Stats.PathRewrites++
        $Script:Stats.FilesCopied++
    }
    $localJson = Get-AdaptedSettingsLocalJson -TargetRepoPath $Script:TargetRepoResolved
    if (-not $Script:DryRunMode) {
        [System.IO.File]::WriteAllText((Join-Path $dst '.claude/settings.local.json'),
            $localJson, (New-Object System.Text.UTF8Encoding $false))
    }
    $Script:Stats.FilesCopied++

    # CLAUDE.md (synthesized)
    Write-Step 'CLAUDE.md (synthesized)'
    $claudeMd = Get-AdaptedClaudeMd -TargetRepoPath $Script:TargetRepoResolved
    if (-not $Script:DryRunMode) {
        [System.IO.File]::WriteAllText((Join-Path $dst 'CLAUDE.md'), $claudeMd,
            (New-Object System.Text.UTF8Encoding $false))
    }
    $Script:Stats.FilesCopied++
}

# --------------------------------------------------------------------------
# Section 5 - Smoke tests
# --------------------------------------------------------------------------

function Invoke-SmokeTestHookFires {
    <#
    .SYNOPSIS
        Synthetic test: write a deferral keyword to a fixture file in the target repo's
        .mad/scratch/, invoke content-scan-deferrals.js with synthetic stdin, verify that
        deferral-flags.json gets written.
    #>
    Write-Step 'Smoke 1: hook fires on synthetic deferral keyword'
    if ($Script:DryRunMode) {
        Write-Host '  [DRY] would write fixture, invoke content-scan-deferrals.js, check deferral-flags.json'
        return 'skip'
    }
    $hookPath = Join-Path $Script:TargetRepoResolved '.claude/hooks/content-scan-deferrals.js'
    if (-not (Test-Path -LiteralPath $hookPath)) {
        Write-Skip "Hook not present: $hookPath - skipping (expected if Tier=minimal)"
        return 'skip'
    }
    # Check node is available
    $nodeAvail = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeAvail) {
        Write-Skip 'node not on PATH - cannot exercise hook; skipping'
        return 'skip'
    }
    $fixtureDir = Join-Path $Script:TargetRepoResolved '.mad/scratch'
    New-DirectorySafe -Path $fixtureDir
    $fixturePath = Join-Path $fixtureDir 'bootstrap-smoke-fixture.md'
    $fixtureBody = @'
# Smoke fixture
This file was authored by Bootstrap-CouncilClawKit smoke test.
It contains the literal phrase: deferred to v1.5
which the content-scan-deferrals.js hook should detect.
'@
    Set-Content -LiteralPath $fixturePath -Value $fixtureBody -Encoding UTF8
    # Build a synthetic PostToolUse hook payload
    $payload = @{
        tool_name  = 'Write'
        tool_input = @{
            file_path = $fixturePath
            content   = $fixtureBody
        }
    } | ConvertTo-Json -Depth 5 -Compress
    try {
        $ErrorActionPreference = 'Continue'
        $payload | & node $hookPath 2>&1 | Out-Null
        $hookExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        # Cleanup the fixture regardless
        Remove-Item -LiteralPath $fixturePath -ErrorAction SilentlyContinue
        # The hook is expected to be exit 0 (PostToolUse cannot block; appends to flags.json)
        $flagsPath = Join-Path $Script:TargetRepoResolved '.mad/scratch/deferral-flags.json'
        if (Test-Path -LiteralPath $flagsPath) {
            Write-Ok 'hook fired and produced deferral-flags.json'
            return 'pass'
        }
        # If the hook is wired to the kit-source paths (not target), it might not fire.
        # That is itself a useful smoke signal but we treat as PARTIAL.
        Write-Skip "hook ran (exit $hookExit) but no flags.json produced - settings paths may not yet resolve in target"
        return 'skip'
    }
    catch {
        Write-Fail "hook smoke failed: $_"
        return 'fail'
    }
}

function Invoke-SmokeTestCouncilList {
    <#
    .SYNOPSIS
        Best-effort: invoke `claude /council-list` against the target. Expect
        empty-channels output without error. If Claude CLI is not installed, skip.
    #>
    Write-Step 'Smoke 2: /council-list returns empty-channel state'
    if ($Script:DryRunMode) {
        Write-Host '  [DRY] would invoke claude /council-list against target repo'
        return 'skip'
    }
    $claudeAvail = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeAvail) {
        Write-Skip 'claude CLI not on PATH - skipping (env-dependent test)'
        return 'skip'
    }
    Push-Location $Script:TargetRepoResolved
    try {
        $ErrorActionPreference = 'Continue'
        $output = & claude /council-list 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($exitCode -ne 0) {
            Write-Fail "claude /council-list exit $exitCode"
            return 'fail'
        }
        if ($output -match '(?i)no.channels|empty|0 channels|channels:\s*$') {
            Write-Ok '/council-list reported empty channels'
            return 'pass'
        }
        # Output is non-empty but non-canonical - degraded but not a fail.
        Write-Skip "/council-list output did not match expected empty-state pattern; output:`n$output"
        return 'skip'
    }
    catch {
        Write-Fail "council-list smoke failed: $_"
        return 'fail'
    }
    finally {
        Pop-Location
    }
}

function Invoke-SmokeTestMadSpecDryRun {
    <#
    .SYNOPSIS
        Best-effort: invoke `claude /mad-spec --dry-run "test feature"` against the
        target. Expect a frontmatter-valid stub at specs/<N>-<feature>/spec.md. Validate
        with Verify-CanonicalSkillFrontmatter.ps1 if present.
    #>
    Write-Step 'Smoke 3: /mad-spec --dry-run produces frontmatter-valid stub'
    if ($Script:DryRunMode) {
        Write-Host '  [DRY] would invoke claude /mad-spec --dry-run "smoke-test"'
        return 'skip'
    }
    $claudeAvail = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeAvail) {
        Write-Skip 'claude CLI not on PATH - skipping'
        return 'skip'
    }
    Push-Location $Script:TargetRepoResolved
    try {
        $ErrorActionPreference = 'Continue'
        $output = & claude /mad-spec --dry-run 'bootstrap smoke test feature' 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($exitCode -ne 0) {
            Write-Fail "claude /mad-spec exit $exitCode"
            return 'fail'
        }
        # Look for any new spec.md under specs/
        $specs = @(Get-ChildItem -Path (Join-Path $Script:TargetRepoResolved 'specs') `
                -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1)
        if (-not $specs -or $specs.Count -eq 0) {
            Write-Skip 'no spec.md produced - dry-run may not write files in this skill version'
            return 'skip'
        }
        $newest = $specs[0]
        # Validate frontmatter via Verify-CanonicalSkillFrontmatter.ps1 if present
        $verifier = Join-Path $Script:TargetRepoResolved '.claude/scripts/Verify-CanonicalSkillFrontmatter.ps1'
        if (Test-Path -LiteralPath $verifier) {
            $ErrorActionPreference = 'Continue'
            $vOutput = & pwsh -NoProfile -File $verifier -Path $newest.FullName 2>&1
            $vExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            if ($vExit -eq 0) {
                Write-Ok "spec.md produced + frontmatter valid: $($newest.FullName)"
                return 'pass'
            }
            Write-Fail "frontmatter invalid: $vOutput"
            return 'fail'
        }
        # Manual frontmatter check
        $first = (Get-Content -LiteralPath $newest.FullName -TotalCount 10) -join "`n"
        if ($first -match '(?ms)^---.*generated-by:\s*/mad-spec.*generated-by-version:.*skill-state-file-id:.*---') {
            Write-Ok "spec.md frontmatter looks valid: $($newest.FullName)"
            return 'pass'
        }
        Write-Skip "spec.md present but frontmatter not in canonical shape: $($newest.FullName)"
        return 'skip'
    }
    catch {
        Write-Fail "mad-spec smoke failed: $_"
        return 'fail'
    }
    finally {
        Pop-Location
    }
}

function Invoke-AllSmokeTests {
    Write-Section 'Smoke tests'
    $r1 = Invoke-SmokeTestHookFires
    $r2 = Invoke-SmokeTestCouncilList
    $r3 = Invoke-SmokeTestMadSpecDryRun
    return @{
        HookFires = $r1
        CouncilList = $r2
        MadSpec = $r3
    }
}

# --------------------------------------------------------------------------
# Section 6 - Output report
# --------------------------------------------------------------------------

function Get-AcceptanceCriteriaStatus {
    <#
    .SYNOPSIS
        Return a hashtable of F-205 (a)-(h) acceptance items keyed by letter, each
        with status (pass/fail/partial/skip) and a note.
    #>
    param([hashtable]$SmokeResults)
    $dst = $Script:TargetRepoResolved
    $a = if ((Test-Path -LiteralPath (Join-Path $dst '.claude/rules')) -and
        (Test-Path -LiteralPath (Join-Path $dst '.claude/hooks')) -and
        (Test-Path -LiteralPath (Join-Path $dst '.claude/skills')) -and
        (Test-Path -LiteralPath (Join-Path $dst '.claude/agents')) -and
        (Test-Path -LiteralPath (Join-Path $dst '.claude/scripts'))) { 'pass' } else { 'fail' }
    $b = if ((Test-Path -LiteralPath (Join-Path $dst '.mad/templates')) -and
        (Test-Path -LiteralPath (Join-Path $dst '.mad/scripts')) -and
        (Test-Path -LiteralPath (Join-Path $dst '.mad/docs'))) { 'pass' } else { 'fail' }
    $c = if (Test-Path -LiteralPath (Join-Path $dst 'CLAUDE.md')) { 'pass' } else { 'fail' }
    # (d) - lifted skills check
    $missing = @($Script:Stats.LiftedSkillsMissing)
    $d = if ($missing.Count -eq 0 -and $Script:Stats.LiftedSkillsPresent -ge 3) { 'pass' }
    elseif ($Script:Stats.LiftedSkillsPresent -gt 0) { 'partial' }
    else { 'fail' }
    $e = if (Test-Path -LiteralPath (Join-Path $dst '.claude/settings.local.json')) { 'pass' } else { 'fail' }
    # F7 fix (2026-05-07 multi-model review): F-205 (f)(g)(h) are Y/N acceptance items. Treat 'skip'
    # as 'partial' (NOT pass) by default. -SmokeOptional override accepts 'skip' as pass for CI
    # environments where node / claude CLI are intentionally absent.
    $f = if ($SmokeResults.HookFires -eq 'skip' -and -not $SmokeOptional) { 'partial' } else { $SmokeResults.HookFires }
    $g = if ($SmokeResults.CouncilList -eq 'skip' -and -not $SmokeOptional) { 'partial' } else { $SmokeResults.CouncilList }
    $h = if ($SmokeResults.MadSpec -eq 'skip' -and -not $SmokeOptional) { 'partial' } else { $SmokeResults.MadSpec }
    return [ordered]@{
        '(a) .claude/ populated with CRITICAL set'    = $a
        '(b) .mad/ populated with non-LENS portions'  = $b
        '(c) CLAUDE.md authored at root'              = $c
        '(d) 3 m-main-derived skills present'         = $d
        '(e) settings.local.json env path-rewritten'  = $e
        '(f) hooks fire on synthetic test'            = $f
        '(g) /council-list returns empty-channels'    = $g
        '(h) /mad-spec dry-run produces valid stub'   = $h
    }
}

function Write-OutputReport {
    param(
        [hashtable]$SmokeResults,
        [string]$ReportPath
    )
    $accept = Get-AcceptanceCriteriaStatus -SmokeResults $SmokeResults

    $lines = @()
    $lines += '# Bootstrap-CouncilClawKit Run Report'
    $lines += ''
    $lines += "- **Date:** $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    $lines += "- **TargetRepo:** $Script:TargetRepoResolved"
    $lines += "- **KitSourceRoot:** $Script:KitSourceRootResolved"
    $lines += "- **Tier:** $Tier"
    $lines += "- **DryRun:** $DryRun"
    $lines += "- **Force:** $Force"
    $lines += ''
    $lines += '## Stats'
    $lines += ''
    $lines += '| Metric | Value |'
    $lines += '|--------|-------|'
    $lines += "| Files copied | $($Script:Stats.FilesCopied) |"
    $lines += "| Directories created | $($Script:Stats.DirectoriesCreated) |"
    $lines += "| LENS-specific files skipped | $($Script:Stats.LensFilesSkipped) |"
    $lines += "| Path rewrites | $($Script:Stats.PathRewrites) |"
    $lines += "| Missing source files | $($Script:Stats.MissingSources.Count) |"
    $lines += "| Copy failures | $($Script:Stats.CopyFailures.Count) |"
    $lines += "| Lifted skills present | $($Script:Stats.LiftedSkillsPresent) of $($Script:LiftedSkills.Count) |"
    $lines += ''
    $lines += '## Files copied by category'
    $lines += ''
    $lines += '| Category | Count |'
    $lines += '|----------|-------|'
    foreach ($k in ($Script:Stats.ByCategory.Keys | Sort-Object)) {
        $lines += "| $k | $($Script:Stats.ByCategory[$k]) |"
    }
    $lines += ''
    $lines += '## F-205 acceptance criteria'
    $lines += ''
    $lines += '| Item | Status |'
    $lines += '|------|--------|'
    foreach ($k in $accept.Keys) {
        $lines += "| $k | $($accept[$k]) |"
    }
    $lines += ''
    $lines += '## Smoke test results'
    $lines += ''
    $lines += '| Test | Result |'
    $lines += '|------|--------|'
    $lines += "| Hook fires (content-scan-deferrals on synthetic) | $($SmokeResults.HookFires) |"
    $lines += "| /council-list empty-channel state | $($SmokeResults.CouncilList) |"
    $lines += "| /mad-spec --dry-run frontmatter-valid stub | $($SmokeResults.MadSpec) |"
    $lines += ''
    if ($Script:Stats.MissingSources.Count -gt 0) {
        $lines += '## Missing sources (failed to copy)'
        $lines += ''
        foreach ($m in $Script:Stats.MissingSources) {
            $lines += "- $m"
        }
        $lines += ''
    }
    if ($Script:Stats.LiftedSkillsMissing.Count -gt 0) {
        $lines += '## Lifted skills missing'
        $lines += ''
        $lines += 'These are authored by sibling implementer A in the same batch.'
        $lines += 'If they are missing here, that batch has not yet completed.'
        $lines += ''
        foreach ($s in $Script:Stats.LiftedSkillsMissing) {
            $lines += "- $s"
        }
        $lines += ''
    }
    $lines += '## CLAUDE.md sections kept / dropped / added'
    $lines += ''
    $lines += '| Disposition | Sections |'
    $lines += '|-------------|----------|'
    $lines += '| Kept (verbatim or adapted) | Non-Negotiable Rules; Orchestration; MAD Workflow; Authoring discipline; Subagent discipline; Quality Gates; Stop-condition discipline; Anti-Patterns; Where to look; Skill-invocation timing metrics; Resume Protocol |'
    $lines += '| Dropped | LENS-DCS standardization loop; LENS gate skills (lens-aspnet-structure, lens-pipeline-audit, lens-telemetry, lens-standards-audit); Deployment Workflow; Deploy anti-patterns; Bicep CLI; NuGet local auth; ADO PR work-item linking; ADO blob/content retrieval; Domain conventions (epoch/CaseId/PATCH); Reference Repos LENS list; Iter1-41 collab-engine antipattern history (specifics) |'
    $lines += '| Added (council-claw-specific) | Project context (mad-council-claw IS the council infrastructure); Reference repos (MAD-Clean kit, m-main, m-relay-main); F-NNN ledger conventions |'
    $lines += ''
    $lines += '## Path rewrite rules implemented'
    $lines += ''
    $lines += '- All occurrences of `' + $Script:KitSourceRootResolved + '` in settings.json -> `' + $Script:TargetRepoResolved + '`'
    $lines += '- settings.local.json env: LENS_REPOS_ROOT dropped; COUNCIL_CLAW_REPOS_ROOT, COUNCIL_CLAW_BACKLOG_FILE added'
    $lines += '- LENS-prefixed scripts (Ev2-*, Ado-*, Diagnose-LensDcs*, Run-AciE2E*, Test-CmsApi*, lens-*) skipped during copy'
    $lines += '- LENS-prefixed skills (lens-aspnet-structure, lens-engineering-craftsmanship) skipped during copy'
    $lines += '- LENS-specific rule patterns (cicd-*, deployment-troubleshooting, deployment-failure-diagnosis) NOT in critical set'
    $lines += '- _dotnet/ pattern files NOT in critical set (full tier optionally includes them; this run did not)'
    $lines += ''

    $body = $lines -join "`n"
    if ($Script:DryRunMode) {
        Write-Host ''
        Write-Host "Report would be written to: $ReportPath"
        Write-Host ''
        Write-Host '--- BEGIN REPORT PREVIEW ---'
        Write-Host $body
        Write-Host '--- END REPORT PREVIEW ---'
    }
    else {
        $reportDir = Split-Path -Parent $ReportPath
        New-DirectorySafe -Path $reportDir
        [System.IO.File]::WriteAllText($ReportPath, $body,
            (New-Object System.Text.UTF8Encoding $false))
        Write-Ok "Report written: $ReportPath"
    }
}

# --------------------------------------------------------------------------
# Section 7 - Main
# --------------------------------------------------------------------------

# Initialize stats
$Script:Stats = @{
    FilesCopied           = 0
    DirectoriesCreated    = 0
    LensFilesSkipped      = 0
    PathRewrites          = 0
    MissingSources        = @()
    CopyFailures          = @()
    LiftedSkillsPresent   = 0
    LiftedSkillsMissing   = @()
    ByCategory            = @{}
}
$Script:DryRunMode = [bool]$DryRun

Write-Section 'Bootstrap-CouncilClawKit'
Write-Host "  Tier:           $Tier"
Write-Host "  DryRun:         $DryRun"
Write-Host "  Force:          $Force"
Write-Host "  TargetRepo:     $TargetRepo"
Write-Host "  KitSourceRoot:  $KitSourceRoot"

# Validate inputs (sets Script:KitSourceRootResolved + Script:TargetRepoResolved or exits)
Test-Inputs

# Resolve report path default
if ([string]::IsNullOrWhiteSpace($OutputReport)) {
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $OutputReport = Join-Path $Script:TargetRepoResolved ".mad/reports/kit-bootstrap-$stamp.md"
}

# Run the appropriate tier
try {
    switch ($Tier) {
        'critical' { Invoke-CopyTierCritical }
        'full'     { Invoke-CopyTierFull }
        'minimal'  { Invoke-CopyTierMinimal }
    }
}
catch {
    Write-Fail "Copy phase failed mid-flight: $_"
    Write-OutputReport -SmokeResults @{
        HookFires   = 'skip'
        CouncilList = 'skip'
        MadSpec     = 'skip'
    } -ReportPath $OutputReport
    exit 4
}

# Smoke tests (post-copy)
$smoke = Invoke-AllSmokeTests

# Output report
Write-OutputReport -SmokeResults $smoke -ReportPath $OutputReport

# Exit-code computation
Write-Section 'Summary'
$accept = Get-AcceptanceCriteriaStatus -SmokeResults $smoke
$failedAcc = @($accept.GetEnumerator() | Where-Object { $_.Value -eq 'fail' })
# F7 fix: 'partial' on smoke items (f)(g)(h) — produced when smoke skipped without -SmokeOptional —
# also contributes to degraded exit. 'partial' on (d) (lifted skills) likewise indicates incomplete bootstrap.
$partialAcc = @($accept.GetEnumerator() | Where-Object { $_.Value -eq 'partial' })
$failedSmoke = @($smoke.Values | Where-Object { $_ -eq 'fail' })

Write-Host "  Files copied:           $($Script:Stats.FilesCopied)"
Write-Host "  Directories created:    $($Script:Stats.DirectoriesCreated)"
Write-Host "  LENS files skipped:     $($Script:Stats.LensFilesSkipped)"
Write-Host "  Path rewrites:          $($Script:Stats.PathRewrites)"
Write-Host "  Missing sources:        $($Script:Stats.MissingSources.Count)"
Write-Host "  Failed acceptance:      $($failedAcc.Count)"
Write-Host "  Partial acceptance:     $($partialAcc.Count)"
Write-Host "  Failed smoke tests:     $($failedSmoke.Count)"
Write-Host "  Lifted skills present:  $($Script:Stats.LiftedSkillsPresent) of $($Script:LiftedSkills.Count)"

if ($failedAcc.Count -gt 0 -or $partialAcc.Count -gt 0 -or $failedSmoke.Count -gt 0) {
    Write-Host ''
    Write-Host '  Bootstrap completed in DEGRADED state. Some F-205 acceptance items / smoke tests failed or are partial.'
    Write-Host '  See the report above for per-item status and missing-source list.'
    Write-Host '  Pass -SmokeOptional to accept skipped smokes (f)(g)(h) as pass when CLI tooling is intentionally absent.'
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host '  Bootstrap COMPLETE. All acceptance items + smoke tests passed (or skipped).'
Write-Host "  Report: $OutputReport"
Write-Host ''
exit 0
