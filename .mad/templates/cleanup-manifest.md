# Cleanup Manifest Template

Use this template for component-cleaner agent output.

```markdown
# Cleanup Manifest

**Date**: [YYYY-MM-DD HH:MM]
**Project Type**: [nodejs | dotnet | python | go | rust]
**Action**: [preview | executed]
**Initiated By**: [/init --cleanup | /init --cleanup-only]

---

## Summary

| Category | Total | Removed | Kept | Protected |
|----------|-------|---------|------|-----------|
| Skills | X | Y | Z | P |
| Agents | X | Y | Z | P |
| Rules | X | Y | Z | P |
| **Total** | X | Y | Z | P |

---

## Removed Components

### Skills

| Name | Path | Technology | Recovery Command |
|------|------|------------|------------------|
| [skill-name] | .claude/skills/[name]/ | [tech] | `git checkout HEAD -- .claude/skills/[name]/` |

### Agents

| Name | Path | Technology | Recovery Command |
|------|------|------------|------------------|
| [agent-name] | .claude/agents/[name].md | [tech] | `git checkout HEAD -- .claude/agents/[name].md` |

### Rules

| Name | Path | Technology | Recovery Command |
|------|------|------------|------------------|
| [rule-name] | .claude/rules/patterns/[name].md | [tech] | `git checkout HEAD -- .claude/rules/patterns/[name].md` |

---

## Protected Components (Not Removed)

These components are protected and were NOT removed even if they matched the technology filter.

### Protected Directories
| Directory | Reason |
|-----------|--------|
| work-items/ | Active work tracking |
| specs/ | Feature specifications |
| hooks/ | Universal infrastructure |
| schemas/ | Validation schemas |
| templates/ | Report templates |
| docs/ | Documentation |

### Protected Agents
| Agent | Reason |
|-------|--------|
| janitor | Core utility agent |
| code-investigator | Core workflow agent |
| code-implementer | Core workflow agent |
| code-reviewer | Core workflow agent |
| feature-verifier | Core workflow agent |
| work-planner | Core workflow agent |
| research-scout | Research pipeline agent |
| research-curator | Research pipeline agent |
| research-reviewer | Research pipeline agent |
| parallel-researcher | Teams infrastructure |
| domain-reviewer | Teams infrastructure |

### Protected Skills
| Skill | Reason |
|-------|--------|
| mad-spec | MAD workflow |
| mad-plan | MAD workflow |
| mad-tasks | MAD workflow |
| mad-implement | MAD workflow |
| mad-validate | MAD workflow |
| mad-full | MAD workflow |
| git-commit | Core utility |
| pr-review | Core utility |
| project-init | Core utility |
| memory | Core utility |
| metrics | Core utility |
| workflow-checklist | Core utility |

### Protected Rules
| Rule | Reason |
|------|--------|
| quality-gates.md | Universal rule |
| git-workflow.md | Universal rule |
| model-selection.md | Universal rule |
| code-review.md | Universal rule |
| orchestration.md | Universal rule |
| agents-and-skills.md | Universal rule |
| agent-teams.md | Universal rule |

---

## Index Updates

| File | Status |
|------|--------|
| .claude/agents/README.md | [Updated | Skipped | Failed] |
| .mad/docs/patterns-index.md | [Updated | Skipped | Failed] |
| .claude/skills/README.md | [Updated | Skipped | N/A] |

---

## Recovery Commands

### Restore Individual Components

```bash
# Restore a specific skill
git checkout HEAD -- .claude/skills/[skill-name]/

# Restore a specific agent
git checkout HEAD -- .claude/agents/[agent-name].md

# Restore a specific rule
git checkout HEAD -- .claude/rules/patterns/[rule-name].md
```

### Restore All Removed Components

```bash
git checkout HEAD -- \
  [list all removed paths separated by space]
```

### Full Rollback (if committed)

```bash
# Find the cleanup commit
git log --oneline -5

# Revert the cleanup commit
git revert <commit-hash>
```

---

## Verification

After cleanup, verify the project still works:

```bash
# Check git status
git status

# Verify no broken references
grep -r "removed-component-name" .claude/

# Run any existing tests
[project-specific test command]
```
```

---

## Action Definitions

| Action | Meaning |
|--------|---------|
| `preview` | Dry run -- no files were removed |
| `executed` | Files were removed |

## Technology Categories

| Technology | Typical Components |
|------------|-------------------|
| `dotnet` | C#/.NET patterns, NuGet |
| `python` | Python patterns, pip, pytest |
| `go` | Go/Golang patterns, modules |
| `rust` | Rust patterns, Cargo |
| `nodejs` | Node.js/TypeScript patterns, npm |
| `cicd` | Pipeline, deployment patterns |
| `universal` | Cross-technology patterns (never removed) |

## Keep/Remove Matrix

| Project Type | KEEP | REMOVE |
|--------------|------|--------|
| Node.js/TS | universal, nodejs, cicd | dotnet, python, go, rust |
| .NET | universal, dotnet, cicd | python, go, rust |
| Python | universal, python, cicd | dotnet, go, rust |
| Go | universal, go, cicd | dotnet, python, rust |
| Rust | universal, rust, cicd | dotnet, python, go |
