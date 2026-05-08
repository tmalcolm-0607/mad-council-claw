# PR Pattern Mining Workflow

Extract patterns from PR review feedback to continuously improve code quality rules.

---

## Purpose

Code reviews contain valuable tribal knowledge about:
- Common mistakes and how to fix them
- Team conventions not yet documented
- Edge cases and gotchas
- Best practices learned from experience

This workflow captures that knowledge and codifies it into pattern files.

---

## Architecture: Collect -> Fan-Out -> Aggregate

```
┌─────────────────────────────────────┐
│  Phase 1: COLLECT (bounded)         │
│  - gh pr list --state merged        │
│  - gh api (reviews, comments)       │
│  - Save JSON per PR                 │
│  - Dedup via manifest.json          │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Phase 2: FAN-OUT (subagents)       │
│  - 1 pr-pattern-miner per PR       │
│  - Each gets bounded JSON input     │
│  - Each writes <PR-ID>.md report    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Phase 3: AGGREGATE (orchestrator)  │
│  - Read all individual reports      │
│  - Deduplicate cross-PR patterns    │
│  - Rank by frequency                │
│  - Present unified summary          │
└─────────────────────────────────────┘
```

### Why This Architecture?

The previous approach fetched all threads/comments for all PRs directly into the agent context window, which caused context overflow with large PR sets. The 3-phase architecture solves this by:

1. **Bounding collection** at the API level (pagination, comment truncation)
2. **Isolating analysis** per PR (each subagent gets ~50KB max)
3. **Aggregating results** from lightweight markdown reports (not raw JSON)

---

## Bounding Defaults

| Setting | Default | Rationale |
|---------|---------|-----------|
| Recent PRs per repo | 5 | ~50 candidates max with --all-repos |
| Max PRs total | 15 | Safety cap regardless of repo count |
| Max threads per PR | 100 | Keeps per-PR JSON under ~50KB |
| Max comment length | 2000 chars | Prevents single comment from dominating |
| Skip already-mined | true | Manifest-based dedup |

---

## When to Run

| Trigger | Frequency | Scope | Command |
|---------|-----------|-------|---------|
| After major PR merges | Ad-hoc | Single PR | `/pr-pattern-extract <PR-NUMBER>` |
| Weekly batch processing | Weekly | Recent PRs | `/pr-pattern-extract --recent 5` |
| Cross-repo survey | Monthly | All repos | `/pr-pattern-extract --all-repos` |
| New team member joins | One-time | Their review patterns | `/pr-pattern-extract --batch <IDs>` |
| Pattern gap identified | Ad-hoc | Targeted search | `/pr-pattern-extract <PR-NUMBER>` |

---

## Quick Start

### Single PR Analysis

```bash
/pr-pattern-extract 42
```

### Recent PRs from a Repo

```bash
/pr-pattern-extract --recent 5 --repo owner/repo
```

### All Configured Repos

```bash
/pr-pattern-extract --all-repos --recent 3
```

### Batch Analysis (Multiple PRs)

```bash
/pr-pattern-extract --batch 42 57 63
```

---

## Detailed Workflow

### Phase 1: Collect (Orchestrator)

The orchestrator uses `gh` CLI to:

1. **Authenticate** with GitHub (`gh auth status`)
2. **Discover PRs** based on mode:
   - Single/batch: explicit PR numbers
   - `--recent N`: `gh pr list --state merged --limit N --json number,title,reviews`
   - `--all-repos`: iterate configured repos, cap to `--max-prs`
3. **Check manifest**: skip already-mined PRs
4. **Fetch reviews** with pagination per PR
5. **Truncate** comment content to `--max-comment-length`
6. **Save** bounded JSON to `.mad/scratch/pr-patterns/<PR-ID>.json`
7. **Update** `manifest.json` with processed PR entries

### Phase 2: Fan-Out (Subagents)

For each collected JSON file, the orchestrator spawns a `pr-pattern-miner` subagent:

- Input: single PR's JSON file (max ~50KB)
- The subagent does NOT call GitHub APIs directly
- Output: `.mad/scratch/pr-patterns/<PR-ID>.md`
- Up to 5 subagents run in parallel

### Phase 3: Aggregate (Orchestrator)

After all subagents complete:

1. Read all `<PR-ID>.md` reports
2. Deduplicate pattern candidates by name/category
3. Count cross-PR frequency (2+ PRs = high priority)
4. Cross-reference against `.claude/rules/patterns/*.md`
5. Present unified summary to user
6. Ask for approval before applying changes

---

## Manifest Tracking

### Schema

Location: `.mad/scratch/pr-patterns/manifest.json`

```json
{
  "mined": {
    "42": {
      "repo": "owner/repo",
      "date": "2026-02-05 14:30:00",
      "commentCount": 45
    },
    "57": {
      "repo": "owner/repo",
      "date": "2026-02-05 14:31:00",
      "commentCount": 32
    }
  }
}
```

### Dedup Behavior

- On each run, the script reads `manifest.json` and skips PRs already present
- After processing, new entries are added with repo, date, and comment count
- To re-process a PR, use `--skip-mined false` or delete its entry from the manifest
- The manifest persists across runs but is cleaned by the janitor with the rest of `.mad/scratch/`

---

## Pattern Categories

| Category | Rule Files | Common Patterns |
|----------|------------|-----------------|
| Architecture | `dotnet-architecture.md`, `express-api-patterns.md` | Layer violations, dependency direction |
| Security | `dotnet-security.md`, `typescript-error-handling.md` | Auth issues, input validation, secrets |
| Performance | `dotnet-resilience.md`, `postgresql-patterns.md` | Query efficiency, caching, batching |
| Database | `postgresql-patterns.md` | Indexes, query optimization |
| Logging | `dotnet-logging.md` | Structured logging, correlation IDs |
| Testing | `dotnet-testing.md`, `typescript-testing.md` | Coverage gaps, test structure |
| Style | `naming-conventions.md` | Naming, formatting, documentation |

---

## Pattern Quality Criteria

Before adding a pattern, verify:

| Criterion | Check |
|-----------|-------|
| **Frequency** | Appears in 3+ reviews? |
| **Specificity** | Clear pass/fail criteria? |
| **Actionable** | Developer knows what to do? |
| **Enforceable** | Can be checked automatically? |
| **Documented** | Not already in existing rules? |

---

## Output Locations

| Type | Location | Retention |
|------|----------|-----------|
| PR JSON data | `.mad/scratch/pr-patterns/<PR-ID>.json` | Cleaned by janitor |
| Analysis reports | `.mad/scratch/pr-patterns/<PR-ID>.md` | Cleaned by janitor |
| Manifest | `.mad/scratch/pr-patterns/manifest.json` | Cleaned by janitor |
| Pattern updates | `.claude/rules/patterns/` | Permanent |

---

## Troubleshooting

### Authentication Failed

```bash
# Check GitHub CLI auth status
gh auth status

# Re-authenticate
gh auth login
```

### PR Not Found

```bash
# Verify PR exists and you have access
gh pr view <PR-NUMBER> --repo owner/repo
```

### No Comments Retrieved

- PR may have no review comments
- Comments may be bot-generated (filtered out)
- Permission issue - verify token has `repo` scope

### All PRs Skipped (Already Mined)

- Manifest contains all discovered PRs
- Use `--skip-mined false` to force re-processing
- Or delete entries from `.mad/scratch/pr-patterns/manifest.json`

### Context Overflow

- Reduce `--max-threads` (default 100)
- Reduce `--max-comment-length` (default 2000)
- Reduce `--max-prs` (default 15)

---

## See Also

- `/pr-pattern-extract` - Skill documentation
- `.claude/agents/pr-pattern-miner.md` - Agent definition
- `/apply-learnings` - Apply captured patterns to rules
- `.claude/rules/patterns/README.md` - Pattern file reference
