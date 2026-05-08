# Technology-Specific Patterns

Path-scoped rule files providing technology-specific guidance. Patterns are loaded automatically when working on files matching their `paths` frontmatter.

---

## Quick Reference

### Pattern Rules (`.claude/rules/patterns/`)

Auto-loaded when working on files matching their `paths` frontmatter.

| File | Technology | Description |
|------|------------|-------------|
| `accessibility-wcag-patterns.md` | frontend | WCAG accessibility standards for React components |
| `async-patterns.md` | dotnet | CancellationToken propagation, async best practices |
| `csharp-coding-patterns.md` | dotnet | C# coding standards: using placement, naming, null handling |
| `dotnet-api-versioning.md` | dotnet | Route versioning (`/api/v1/`) conventions |
| `dotnet-architecture.md` | dotnet | .NET 5-layer architecture (API, DI, BusinessLogic, DataAccess, Common) |
| `dotnet-configuration.md` | dotnet | IConfigOptions pattern, options binding |
| `dotnet-di-patterns.md` | dotnet | Dependency injection patterns, async initialization |
| `dotnet-domain-models.md` | dotnet | Domain entity, DTO, and model design standards |
| `dotnet-error-handling.md` | dotnet | Result-based error handling pattern |
| `dotnet-logging.md` | dotnet | LoggerMessage source generators, structured logging |
| `dotnet-marten-patterns.md` | dotnet | Marten/PostgreSQL document store patterns |
| `dotnet-mvc-controllers.md` | dotnet | MVC Controller patterns, [ApiController] attribute |
| `dotnet-opentelemetry.md` | dotnet | OpenTelemetry distributed tracing |
| `dotnet-quick-reference.md` | dotnet | Checklists for Endpoints, Services, Logging |
| `dotnet-resilience.md` | dotnet | Polly resilience: retry, circuit breaker, timeout, bulkhead, hedging |
| `dotnet-result-pattern.md` | dotnet | Result<T> pattern for domain operations |
| `dotnet-security.md` | dotnet | Input validation, CORS, security patterns |
| `dotnet-testing.md` | dotnet | Consolidated testing patterns |
| `dotnet-testing-integration.md` | dotnet | Database fixtures, API testing, WireMock |
| `dotnet-testing-patterns.md` | dotnet | Builder pattern, assertions, mock verification |
| `dotnet-testing-setup.md` | dotnet | Test framework, project structure, naming conventions |
| `fp-advanced.md` | dotnet | Advanced functional programming patterns |
| `fp-foundations.md` | dotnet | Functional programming foundations |
| `fp-patterns.md` | dotnet | Functional programming patterns |
| `logging-security.md` | dotnet | What to log vs what NOT to log (PII, secrets) |
| `naming-conventions.md` | universal | Consistent naming standards |
| `playwright-e2e-patterns.md` | frontend | Playwright E2E testing patterns |
| `quality-gates-dotnet.md` | dotnet | .NET-specific quality gate commands |
| `react-patterns.md` | frontend | React 19 component and hook patterns |
| `signalr-client-patterns.md` | frontend | SignalR client-side patterns |
| `tailwind-shadcn-patterns.md` | frontend | Tailwind CSS + shadcn/ui patterns |
| `typescript-patterns.md` | frontend | TypeScript coding standards and patterns |
| `zustand-tanstack-patterns.md` | frontend | Zustand state + TanStack Query patterns |

### Reference Docs (`.claude/docs/`)

Not auto-loaded. Available for manual reference during planning and implementation.

| File | Category | Description |
|------|----------|-------------|
| `model-selection-guide.md` | universal | Detailed model selection rationale, cost analysis, criteria matrix |
| `patterns-index.md` | universal | This file - pattern system index and reference |
| `phased-review-schema.md` | universal | JSON schema for phased review findings |
| `agent-teams-guide.md` | universal | Agent Teams integration guide |
| `pattern-discovery-workflow.md` | universal | Workflow for discovering patterns from codebases |
| `pr-pattern-mining-workflow.md` | universal | Workflow for extracting patterns from PR reviews |
| `skill-packaging.md` | universal | How to package and distribute skills |
| `workflow-best-practices.md` | universal | MAD workflow best practices and examples |
| `best-practices/README.md` | universal | Research-backed best practices index (refreshed quarterly) |

### Technology Categories

Used by `/init --cleanup` to determine which patterns to keep or remove:

| Technology | Description | Kept For |
|------------|-------------|----------|
| `universal` | Cross-technology patterns | All project types |
| `dotnet` | C#/.NET specific | .NET projects |
| `frontend` | React/TypeScript/CSS | Frontend projects |

---

## How It Works

### Path-Scoped Loading

Rules with YAML frontmatter `paths` array only load when working on matching files:

```yaml
---
paths:
  - "**/*.cs"
  - "**/spec.md"
  - "**/plan.md"
---
```

### Planning Phase Support

High-value patterns include `**/spec.md`, `**/plan.md`, `**/tasks.md` in their paths to ensure patterns are available during specification and planning phases, not just code implementation.

---

## Adding New Patterns

1. Use YAML frontmatter with `paths` array
2. Follow naming: `{technology}-{pattern}.md`
3. Include sections: Overview, Code Examples (Correct/Incorrect), Enforcement Table, Anti-Patterns
4. Place in `.claude/rules/patterns/` (not `.claude/rules/`)

---

## Origin

Patterns adapted from:
- **CCGHCP** - Claude Code & GitHub Copilot Development Kit (master template)
- **Target projects** - Project-specific patterns for React 19, Marten, Playwright, shadcn/ui
