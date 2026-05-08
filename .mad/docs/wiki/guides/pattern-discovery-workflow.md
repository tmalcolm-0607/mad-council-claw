# Pattern Discovery Workflow

Discover patterns from .NET codebases to continuously improve the pattern library.

---

## Purpose

Codebases contain implicit patterns that can be extracted and documented:
- Architecture decisions not yet codified
- Team conventions learned through experience
- Best practices demonstrated in reference projects
- Technology-specific patterns worth standardizing

This workflow captures that knowledge and adds it to pattern files.

---

## When to Run

| Trigger | Frequency | Scope |
|---------|-----------|-------|
| New reference project available | Ad-hoc | Single codebase |
| After major refactoring | Ad-hoc | Changed codebase |
| Quarterly pattern refresh | Quarterly | All reference projects |
| Onboarding new team member | One-time | Share discovery process |

---

## Quick Start

### Single Project Analysis

```bash
/pattern-discover C:\source\my-project
```

### All Reference Projects

```bash
pwsh scripts/Discover-Patterns.ps1
```

### Deep Analysis

```bash
/pattern-discover <project-path> --depth thorough
```

---

## Full Workflow

### 1. Identify Codebases to Analyze

Good candidates have:
- Mature, well-reviewed code
- Consistent patterns across files
- Clear architectural boundaries
- Active maintenance

### 2. Run Pattern Discovery

```bash
/pattern-discover <path>
```

The skill will:
1. Analyze project structure
2. Scan for code patterns
3. Generate report in `.mad/scratch/pattern-discovery/`

### 3. Review Pattern Candidates

Open the generated report:
- `.mad/scratch/pattern-discovery/<project-name>.md`

Review each candidate:
- **Is it reusable?** Applies to multiple projects?
- **Is it correct?** Validated approach?
- **Is it documented?** Already in pattern files?

### 4. Apply Approved Patterns

For approved patterns, update rule files:

```bash
# Use apply-learnings skill
/apply-learnings

# Or manually edit pattern files
code .claude/rules/patterns/dotnet-architecture.md
```

### 5. Track Pattern Source

Add comment to rule file linking to source:

```markdown
<!-- Pattern source: <project> src/DataAccess/Repositories/ -->
```

---

## Discovery Heuristics

### Project Structure

| Indicator | Pattern |
|-----------|---------|
| `Directory.Packages.props` | Central package management |
| `Directory.Build.props` | Central build configuration |
| `**/Interfaces/` folders | Interface-in-consumer pattern |
| `**/Extensions/` folders | Service registration extensions |

### Code Patterns

| Pattern | Detection Strategy |
|---------|-------------------|
| IConfigOptions | Search for `ConfigSectionKey` |
| LoggerMessage | Search for `[LoggerMessage(` |
| Repository | Search for `IRepository`, `async Task` |
| Result<T> | Search for `IsSuccess`, `IsFailure` |
| Cosmos SDK | Search for `CosmosClient`, `PartitionKey` |

### Architecture Patterns

| Pattern | Detection Method |
|---------|------------------|
| Layered | Analyze *.csproj references |
| CQRS | Check for Commands/, Queries/ folders |
| Clean Architecture | Check for Domain/, Application/, Infrastructure/ |

---

## Output Locations

| Type | Location | Retention |
|------|----------|-----------|
| Discovery reports | `.mad/scratch/pattern-discovery/` | Cleaned by janitor |
| Pattern updates | `.claude/rules/patterns/` | Permanent |
| Discovery logs | `.mad/scratch/logs/` | Cleaned by janitor |

---

## Pattern Quality Criteria

Before adding a pattern, verify:

| Criterion | Check |
|-----------|-------|
| **Frequency** | Used in 3+ places? |
| **Specificity** | Clear implementation? |
| **Actionable** | Developer knows what to do? |
| **Correct** | Follows best practices? |
| **Unique** | Not already documented? |

---

## Batch Processing

For multiple codebases:

```powershell
# Analyze all reference projects
.\scripts\Discover-Patterns.ps1

# Analyze specific projects
.\scripts\Discover-Patterns.ps1 -Paths @("C:\source\proj1", "C:\source\proj2")

# Deep analysis
.\scripts\Discover-Patterns.ps1 -Depth thorough
```

---

## Combining with PR Mining

Use both workflows for comprehensive pattern discovery:

```bash
# 1. Discover patterns from code
/pattern-discover <project-path>

# 2. Extract patterns from PR feedback
/pr-pattern-extract 4860830

# 3. Apply learnings from both sources
/apply-learnings
```

---

## Troubleshooting

### No Patterns Found

- Verify path contains *.csproj files
- Try `--depth thorough` for deeper scan
- Check if codebase uses non-standard patterns

### Too Many Patterns

- Use `--depth quick` to limit results
- Focus on one category at a time
- Filter by pattern confidence

### False Positives

- Review each pattern manually
- Check if pattern is intentional
- Verify against reference documentation

---

## See Also

- `/pattern-discover` - Skill documentation
- `.claude/agents/pattern-discoverer.md` - Agent definition
- `/pr-pattern-extract` - Extract patterns from PR reviews
- `/apply-learnings` - Apply approved patterns to rules
- `.claude/rules/patterns/README.md` - Pattern file reference
