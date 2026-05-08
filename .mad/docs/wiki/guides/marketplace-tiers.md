# Marketplace Tiers — Internal Reference

Component inventory for the .NET Dev Kit Claude Code plugin. This document is the authoritative reference for what's included in each tier.

**Current Release**: 101 Foundation (v1.0.0)
**Target Repo**: a shared library (`plugins/dotnet-dev-kit/`)

---

## 101 Foundation (33 components)

### Patterns (20)

#### Architecture (6)

1. **dotnet-architecture.md** - 5-layer architecture (API, DI, BusinessLogic, DataAccess, Common)
   - Activates: `**/Controllers/**/*.cs`, `**/BusinessLogic/**/*.cs`, `**/DataAccess/**/*.cs`, `**/Common/**/*.cs`

2. **dotnet-configuration.md** - IConfigOptions pattern, options binding, validation
   - Activates: `**/Configuration/**/*.cs`, `**/*Options.cs`, `**/appsettings*.json`

3. **dotnet-domain-models.md** - Domain entities, DTOs, model design principles
   - Activates: `**/Models/**/*.cs`, `**/Entities/**/*.cs`, `**/DTOs/**/*.cs`

4. **dotnet-mvc-controllers.md** - MVC controller patterns, [ApiController] attributes
   - Activates: `**/Controllers/**/*.cs`

5. **dotnet-api-versioning.md** - Route-based API versioning (/api/v1/)
   - Activates: `**/Controllers/**/*.cs`, `**/Api/**/*.cs`

6. **dotnet-di-patterns.md** - Dependency injection patterns, service lifetimes, registration
   - Activates: `**/Program.cs`, `**/Startup.cs`, `**/ServiceCollectionExtensions.cs`

#### Error Handling & Resilience (3)

7. **dotnet-result-pattern.md** - Result<T> for business errors vs exceptions
   - Activates: `**/BusinessLogic/**/*.cs`, `**/Services/**/*.cs`

8. **dotnet-error-handling.md** - LENS-canonical `HandlerException` hierarchy + controller catch-ladder + library-provided `GlobalErrorHandlingMiddleware` + QOS error-code wiring
   - Activates: `**/*.cs`, `**/Middleware/**/*.cs`, `**/Exceptions/**/*.cs`

9. **dotnet-resilience.md** - Polly patterns: retry, circuit breaker, timeout, bulkhead
   - Activates: `**/Services/**/*.cs`, `**/HttpClients/**/*.cs`

#### Security (2)

10. **dotnet-security.md** - Managed Identity, input validation, CORS configuration
    - Activates: `**/Security/**/*.cs`, `**/Authentication/**/*.cs`, `**/Authorization/**/*.cs`

11. **logging-security.md** - Secure logging practices, PII redaction
    - Activates: `**/Logging/**/*.cs`, `**/*.cs` (when logging statements present)

#### Observability (2)

12. **dotnet-logging.md** - LoggerMessage source generators, structured logging
    - Activates: `**/Logging/**/*.cs`, `**/*.cs` (when logging statements present)

13. **dotnet-opentelemetry.md** - OpenTelemetry distributed tracing, Activity API
    - Activates: `**/Observability/**/*.cs`, `**/Telemetry/**/*.cs`

#### Testing (3)

14. **dotnet-testing.md** - Unit testing structure, naming conventions, builders, mocking
    - Activates: `**/Tests/**/*.cs`, `**/*.Tests/**/*.cs`, `**/*Tests.cs`

15. **dotnet-testing-integration.md** - Integration testing fixtures, API tests, test containers
    - Activates: `**/Tests.Integration/**/*.cs`, `**/*.IntegrationTests/**/*.cs`

16. **quality-gates-dotnet.md** - .NET-specific quality gate commands and thresholds
    - Activates: Always loaded during implementation phases

#### Coding Standards (3)

17. **async-patterns.md** - Async/await best practices, Task management, cancellation
    - Activates: `**/*.cs` (when async/await keywords present)

18. **csharp-coding-patterns.md** - C# standards: usings, naming, null handling, LINQ
    - Activates: `**/*.cs`

19. **naming-conventions.md** - Consistent naming across controllers, services, models
    - Activates: `**/*.cs`

#### Reference (1)

20. **dotnet-quick-reference.md** - Checklists for Cosmos DB, endpoints, services, logging
    - Activates: Always available as reference

### Skills (4)

1. **git-commit** - Create conventional commits with quality gates, Co-Authored-By attribution
   - Usage: `/git-commit`
   - Runs quality gates before committing, formats commit message with conventional commit style

2. **documentation-engineer** - Generate/update documentation (README, API docs, inline comments)
   - Usage: `/documentation-engineer`
   - Analyzes code and generates/updates documentation

3. **config-lint** - Validate configuration consistency (appsettings, bicep params, deployment-pipeline configs)
   - Usage: `/config-lint`
   - Checks for mismatches across configuration files

4. **project-init** - Initialize new .NET project with patterns (5-layer structure, DI, configuration)
   - Usage: `/project-init`
   - Scaffolds new project with best practices baked in

### Agents (2)

1. **code-investigator** - Read-only agent (Opus model) for understanding code, analyzing architecture
   - Tools: Read, Grep, Glob, Bash (read-only)
   - Use for: Understanding codebase patterns, analyzing architecture, researching implementation approaches
   - Spawned automatically when Claude Code needs to investigate code files

2. **code-implementer** - Full-capability agent (Opus model) for implementation
   - Tools: Read, Grep, Glob, Edit, Write, Bash
   - Use for: Modifying code, writing tests, implementing features (TDD workflow)
   - Spawned automatically when Claude Code needs to modify code files

### Hooks (3)

1. **pre-bash-validate.js** - Push guard (warns on `git push`, blocks `git push --force`)
   - Triggers: Before any `git push` command
   - Behavior: Warns on unsolicited push, blocks force push
   - Config: `PUSH_GUARD_MODE` (warn/block) in `.claude/settings.local.json` under `env`

2. **tdd-advisory.js** - Red-Green-Refactor workflow reminders
   - Triggers: When modifying .cs/.ts source files without recent test changes
   - Behavior: Non-blocking advisory suggesting test-first approach
   - Excludes: .md, .json, .yaml, .xml, .csproj, .props, .sln
   - Cooldown: 5 minutes per file
   - Config: `TDD_ADVISORY_ENABLED` (default: true) in `.claude/settings.local.json` under `env`

3. **pre-commit-validate.js** - Pre-commit validation (quality gates enforcement)
   - Triggers: Before git commit
   - Behavior: Runs quality gates, blocks commit on failure
   - Gates: Build, test, lint/format

### Rules (3)

1. **quality-gates.md** - Build, test, coverage, lint, security gates
   - Always loaded during implementation
   - Commands: `dotnet build`, `dotnet test`, `dotnet format`, `dotnet list package --vulnerable`
   - Success criteria for each gate
   - Enforcement: NO SKIPPING, PROOF REQUIRED, FIX BEFORE PROCEED

2. **test-discipline.md** - TDD workflow and test failure protocol
   - Always loaded during testing
   - Red-Green-Refactor cycle
   - Test failure categorization (regression vs pre-existing)
   - Actions: Fix immediately, track via bug template, or skip with reason

3. **git-workflow.md** - Branch naming, commit format, PR checklist
   - Always loaded during git operations
   - Branch patterns: feature/, bugfix/, refactor/
   - Commit format: <type>(<scope>): <description>
   - When to commit: Phase completed, gate passed (NOT on build/test failure)

### Templates (1)

1. **_template-pattern.md** - Template for creating new path-scoped patterns
   - Location: `.claude/rules/patterns/_template-pattern.md`
   - YAML frontmatter with paths array for auto-activation
   - Pattern structure: Context, Pattern, Examples, Anti-Patterns
   - Naming convention: {technology}-{pattern}.md

---

## Component Count Table

| Category | 101 |
|----------|-----|
| Patterns | 20 |
| Skills | 4 |
| Agents | 2 |
| Hooks | 3 |
| Rules | 3 |
| Templates | 1 |
| **TOTAL** | **33** |

---

## Junior Onboarding Guide

### What Happens on Install

1. All patterns are installed to `.claude/rules/patterns/`
2. Skills become available as slash commands (`/git-commit`, etc.)
3. Agents are registered for automatic spawning
4. Hooks are registered for lifecycle events
5. Rules are loaded into Claude Code context
6. Template is available for creating custom patterns

### How Patterns Auto-Activate

Patterns use YAML frontmatter with `paths` arrays:

```yaml
---
paths:
  - "**/Controllers/**/*.cs"
  - "**/Api/**/*.cs"
---
```

When you edit a file matching any pattern's paths, that pattern automatically loads into Claude Code's context. You don't need to manually import them.

### How to Use the 4 Slash Commands

1. **`/git-commit`** - Runs quality gates, then creates a conventional commit
   - Checks: `git status`, `git diff`
   - Runs: Build, test, lint gates
   - Creates: Formatted commit message with Co-Authored-By attribution

2. **`/documentation-engineer`** - Generates or updates documentation
   - Analyzes: Code structure, patterns, dependencies
   - Creates: README, API docs, inline comments
   - Updates: Existing docs to match current code

3. **`/config-lint`** - Validates configuration consistency
   - Checks: appsettings.json, appsettings.Development.json, bicep params
   - Reports: Mismatches, missing values, type errors
   - Suggests: Fixes for inconsistencies

4. **`/project-init`** - Scaffolds new .NET project
   - Creates: 5-layer architecture (API, DI, BusinessLogic, DataAccess, Common)
   - Sets up: Dependency injection, configuration, logging, testing
   - Applies: All 101 Foundation patterns from the start

### What the Hooks Do

1. **pre-bash-validate.js** - You'll see this when you try to `git push`
   - Warns: "Push guard: unsolicited git push detected"
   - Blocks: `git push --force` (exits with error)
   - Passes: `git push --dry-run` silently

2. **tdd-advisory.js** - You'll see this when you modify source code without tests
   - Warns: "TDD advisory: consider writing test first (Red-Green-Refactor)"
   - Non-blocking: Execution continues, just a reminder
   - Cooldown: Won't repeat for same file within 5 minutes

3. **pre-commit-validate.js** - You'll see this before every commit
   - Runs: Build, test, lint gates
   - Blocks: Commit if any gate fails
   - Requires: Fix failures before commit proceeds

### How to Create Custom Patterns

1. Copy `.claude/rules/patterns/_template-pattern.md` to a new file
2. Name it: `{technology}-{aspect}.md` (e.g., `react-hooks.md`)
3. Update YAML frontmatter with file paths that should trigger this pattern
4. Fill in: Context, Pattern, Examples, Anti-Patterns sections
5. Save: Pattern auto-loads when you edit matching files

Example frontmatter:

```yaml
---
paths:
  - "**/Components/**/*.tsx"
  - "**/hooks/**/*.ts"
---
```

---

## Future Tiers — Roadmap

### 201 Professional (planned)

Advanced agents and code review automation. Estimated ~35 additional components.

Key additions:
- Composite agents (investigate-and-implement, review-and-fix, coverage-loop)
- Adversarial review panel (advocate, skeptic, architect)
- Context management (context-guardian, handoff mechanism)
- Additional patterns (Cosmos DB, E2E testing, SignalR, Marten event sourcing)
- Enhanced hooks (anomaly detection, planning ratio check, parallel opportunity detector)
- Model selection enforcement

Target audience: Teams with established CI/CD wanting code review automation and context management.

### 301 Enterprise (future)

Orchestration, parallel execution, research pipelines. Estimated ~70 additional components over 201.

Key additions:
- Ralph Loops workflow automation (mad-implement, mad-full, mad-parallel)
- Gas Town evaluation framework (LLM-as-judge, metrics, session review)
- Agent teams (parallel execution with worktree isolation)
- Research pipelines (research-scout, research-curator, research-reviewer)
- Pattern discovery (pattern-discoverer, pr-pattern-miner)
- DAG-based wave dispatch

Target audience: Large teams (10+) with complex workflows needing parallel execution and evaluation-driven improvement.

---

## Exclusions from Plugin

The following are NOT included in the marketplace plugin (project-specific to CCGHCP repo):

- `.claude/scripts/` - Project-specific PowerShell wrapper scripts for Azure deployment / ADO
- `.mad/work-items/` - Runtime work item tracking (session-specific)
- `.claude/work-items/` - Runtime work item tracking (session-specific)
- `references/` - Consumer-specific reference repos for cross-repo pattern extraction
- `CLAUDE.md` - Project-specific main instructions (each project writes their own)
- `CLAUDE.local.md` - Personal preferences (gitignored by Claude Code)
- Project-specific agent customizations (e.g., test-selector with project-specific file paths)

The plugin provides the FRAMEWORK and PATTERNS. Projects adapt with project-specific scripts, paths, and conventions.

---

## Design Decisions

### Why MAD Skills Were Excluded from 101

MAD (Modular Agent-Driven) workflow is an internal framework developed for the consumer-project project. It includes:
- `/mad-spec` - Generate specification from requirements
- `/mad-plan` - Create implementation plan
- `/mad-tasks` - Generate task list
- `/mad-idea` - Quick idea capture

These were excluded from 101 Foundation because:
1. They're tightly coupled to the source project's structure (milestones.md, feature-traceability.md, workflows/)
2. They assume specific documentation conventions not universal to .NET projects
3. The 5 MAD skills are better suited for 201 Professional (workflow automation tier)
4. 101 should focus on universal .NET patterns, not project-specific workflows

MAD skills will appear in 201 Professional with generalized templates that projects can adapt.

### Why Bogus Was Made Optional

The original patterns referenced Bogus (fake data generation library) in testing patterns. This was made optional in the plugin version because:
1. Not every project uses Bogus (some use NBuilder, AutoFixture, or custom builders)
2. Fake data generation is a test implementation detail, not a core pattern
3. The pattern now shows the concept (test data builders) without mandating a specific library

Projects using Bogus can add library-specific examples to their project-level patterns.

### Why E2E Section Was Guarded

The Playwright E2E testing pattern was moved to 201 Professional because:
1. Not every .NET project has a frontend (many are pure APIs)
2. E2E testing is a more advanced practice typically adopted after unit/integration testing is solid
3. 101 should focus on backend .NET patterns, 201 adds frontend/E2E

### Why Coverage Threshold Was Softened

Original enforcement: 100% diff coverage (every changed line must be tested).

Plugin version: 80% diff coverage (industry standard, configurable).

Reasoning:
1. Different organizations have different standards (60%, 80%, 90%)
2. 100% is aspirational but can slow down rapid prototyping
3. Plugin provides the mechanism (diff coverage measurement), projects set the threshold

Projects can override in their `quality-gates.md` with project-specific thresholds.

---

## File Organization in Target Repo

```
plugins/dotnet-dev-kit/
├── .claude/
│   ├── rules/
│   │   ├── patterns/
│   │   │   ├── dotnet-architecture.md
│   │   │   ├── dotnet-configuration.md
│   │   │   ├── dotnet-domain-models.md
│   │   │   ├── dotnet-mvc-controllers.md
│   │   │   ├── dotnet-api-versioning.md
│   │   │   ├── dotnet-di-patterns.md
│   │   │   ├── dotnet-result-pattern.md
│   │   │   ├── dotnet-error-handling.md
│   │   │   ├── dotnet-resilience.md
│   │   │   ├── dotnet-security.md
│   │   │   ├── logging-security.md
│   │   │   ├── dotnet-logging.md
│   │   │   ├── dotnet-opentelemetry.md
│   │   │   ├── dotnet-testing.md
│   │   │   ├── dotnet-testing-integration.md
│   │   │   ├── quality-gates-dotnet.md
│   │   │   ├── async-patterns.md
│   │   │   ├── csharp-coding-patterns.md
│   │   │   ├── naming-conventions.md
│   │   │   ├── dotnet-quick-reference.md
│   │   │   └── _template-pattern.md
│   │   ├── quality-gates.md
│   │   ├── test-discipline.md
│   │   └── git-workflow.md
│   ├── skills/
│   │   ├── git-commit.md
│   │   ├── documentation-engineer.md
│   │   ├── config-lint.md
│   │   └── project-init.md
│   ├── agents/
│   │   ├── code-investigator.md
│   │   └── code-implementer.md
│   ├── hooks/
│   │   ├── pre-bash-validate.js
│   │   ├── tdd-advisory.js
│   │   └── pre-commit-validate.js
│   └── settings.local.json.example (template, user renames to settings.local.json)
├── README.md (installation, usage, examples)
├── CHANGELOG.md (version history)
└── LICENSE (MIT expected)
```

---

## Installation

```bash
# Clone the plugin repo (once available in a shared library)
git clone https://dev.azure.com/<your-org>/<your-project>/_git/a shared library

# Copy the plugin to your project
cp -r a shared library/plugins/dotnet-dev-kit/.claude /path/to/your/project/

# Configure settings (optional)
cp /path/to/your/project/.claude/settings.local.json.example \
   /path/to/your/project/.claude/settings.local.json

# Edit settings.local.json to customize thresholds, enable/disable hooks
```

After installation, restart your Claude Code session to load the new patterns.

---

## Verification

After installation, verify the plugin is working:

1. **Patterns load**: Edit a file in `Controllers/` directory, type "@dotnet-mvc" in Claude Code chat - pattern should be available
2. **Skills work**: Type `/git-commit` - skill should appear in autocomplete
3. **Hooks fire**: Modify a .cs file without touching tests - TDD advisory should appear
4. **Agents spawn**: Ask Claude to investigate code - code-investigator should spawn automatically

---

## Customization

### Override Pattern Behavior

Create a project-level pattern in `.claude/rules/patterns/` with the same name. Project-level patterns take precedence over plugin patterns.

Example: Override `dotnet-architecture.md` with project-specific layer naming:

```bash
# Create project override
cp .claude/rules/patterns/dotnet-architecture.md \
   .claude/rules/patterns/dotnet-architecture-override.md

# Edit to match your project's architecture
# (e.g., "Services" instead of "BusinessLogic")
```

### Disable Hooks

In `.claude/settings.local.json`:

```json
{
  "env": {
    "TDD_ADVISORY_ENABLED": "false",
    "PUSH_GUARD_MODE": "off"
  }
}
```

### Add Custom Skills

Create `.claude/skills/my-custom-skill.md` following the template structure. Restart Claude Code to load.

---

END OF INTERNAL REFERENCE
