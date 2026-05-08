# Cleanup Protocol

Remove skills, agents, and rules that don't apply to the target project type.

## Cleanup Flags

| Flag | Description |
|------|-------------|
| `--cleanup` | Initialize + cleanup non-applicable components |
| `--cleanup-only` | Just cleanup (no initialization) |
| `--dry-run` | Preview what would be removed (no actual deletion) |
| `--force` | Skip confirmation prompt |

## Cleanup Workflow

```
1. Detect project type (reuse existing detection)
2. Spawn `component-scanner` subagent → JSON inventory
3. Calculate removal list based on keep/remove matrix
4. If --dry-run: generate preview and stop
5. If not --force: confirm with user
6. Spawn `component-cleaner` subagent → execute removal
7. Update index files (README.md files)
8. Generate completion report
```

## Step 1: Detect Project Type

Use the same detection logic from initialization:

| Files | Project Type |
|-------|--------------|
| `package.json`, `tsconfig.json` | nodejs |
| `*.csproj`, `*.sln` | dotnet |
| `requirements.txt`, `pyproject.toml` | python |
| `go.mod` | go |
| `Cargo.toml` | rust |

## Step 2: Scan Components

Spawn the `component-scanner` subagent:

```
Task tool with subagent_type="component-scanner"
prompt: "Scan all Claude Code components and categorize by technology.
         Return JSON inventory with files categorized as:
         universal, dotnet, python, go, rust, nodejs, cicd"
```

## Step 3: Calculate Removal List

Apply the keep/remove matrix based on detected project type:

| Project Type | KEEP | REMOVE |
|--------------|------|--------|
| nodejs | universal, nodejs, cicd | dotnet, python, go, rust, lens |
| dotnet | universal, dotnet, cicd, lens | python, go, rust |
| python | universal, python, cicd | dotnet, go, rust |
| go | universal, go, cicd | dotnet, python, rust |
| rust | universal, rust, cicd | dotnet, python, go |

**IMPORTANT**: Always exclude protected components from removal list.

## Step 4: Preview (--dry-run)

If `--dry-run` flag is set:

```markdown
# Cleanup Preview

**Project Type**: nodejs
**Action**: Preview only (no files will be removed)

## Would Remove

### Rules (23)
- .claude/rules/patterns/dotnet-*.md

## Would Keep

### Protected (never removed)
- All MAD workflow skills
- Core agents (investigator, implementer, reviewer, verifier)
- Universal rules (quality-gates, git-workflow, etc.)

### Technology-matched
- All nodejs-specific components
- All cicd components
- All universal components

To execute cleanup, run: /init --cleanup
```

## Step 5: Confirm with User

Unless `--force` flag is set, display confirmation:

```
About to remove 29 components:
- 1 skill
- 4 agents
- 24 rules

All files are git-tracked and can be recovered.

Proceed? [y/N]
```

## Step 6: Execute Cleanup

Spawn the `component-cleaner` subagent:

```
Task tool with subagent_type="component-cleaner"
prompt: "Execute cleanup with the following removal list:
         [JSON removal list]

         Create backup manifest before removal.
         Update index files after removal."
```

## Step 7: Completion Report

```
Cleanup Complete

Project Type: nodejs
Components Removed: 29
  - Skills: 1
  - Agents: 4
  - Rules: 24

Manifest: .mad/scratch/cleanup-manifest-20260205-1430.md

To restore removed components:
  git checkout HEAD -- [files]

Index files updated:
  - .claude/agents/README.md
  - .claude/rules/patterns/README.md
```

---

## Component Technology Mapping

### Current Inventory

| Category | Total | Technology-Specific | Universal |
|----------|-------|---------------------|-----------|
| Skills | 35 | 0 | 35 |
| Agents | 23 | 0 | 23 |
| Rules (patterns/) | 33 | 20 .NET, 7 TS/React, 3 CI/CD, 3 FP | 0 |
| Hooks | 24 | 0 | 24 |

### Technology Categories

| Technology | Pattern Prefix | Description |
|------------|----------------|-------------|
| `universal` | (none) | Cross-technology, always kept |
| `dotnet` | `dotnet-*` | C#/.NET specific |
| `python` | `python-*` | Python specific |
| `go` | `go-*` | Go/Golang specific |
| `rust` | `rust-*` | Rust specific |
| `nodejs` | `nodejs-*`, `typescript-*` | Node.js/TypeScript specific |
| `cicd` | `cicd-*` | CI/CD pipelines (kept for all types) |

---

## Cleanup Safety

### Prerequisites

1. **Git-tracked files only** — Cleanup refuses to delete untracked files
2. **Backup manifest** — Always created before any deletion
3. **User confirmation** — Required unless `--force` flag
4. **Protected list** — Hardcoded, cannot be overridden

### Recovery

All removed files can be recovered via git:

```bash
# Restore individual file
git checkout HEAD -- .claude/rules/patterns/dotnet-architecture.md

# Restore from manifest
cat .mad/scratch/cleanup-manifest-*.md | grep "Recovery Command"

# Full rollback (if committed)
git revert <cleanup-commit-hash>
```

### Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Cleanup untracked files | No recovery possible | Must be git-tracked |
| Skip backup manifest | No recovery record | Always create manifest |
| Remove protected components | Breaks core functionality | Check protected list |
| Cleanup without detection | Wrong components removed | Detect project type first |
| Force without review | Accidental removal | Use --dry-run first |
