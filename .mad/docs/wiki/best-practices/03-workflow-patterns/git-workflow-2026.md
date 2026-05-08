---
category: workflow-patterns
subcategory: git-workflow
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Git Workflow (2026)

## Overview

Git branching, commit conventions, worktree usage, and PR creation patterns for AI-assisted development workflows.

**2026 Update**: GitHub Actions integration with `@claude` mentions, hooks for CI/CD enforcement, worktrees for parallel sessions, and descriptive commit automation.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Conventional Commits** | Use `type(scope): description` format |
| **Atomic Commits** | One logical change per commit |
| **Branch Naming** | `feature/`, `bugfix/`, `refactor/` prefixes |
| **Worktrees for Isolation** | Use worktrees for parallel feature work |
| **Never Auto-PR** | Always ask before creating PRs |
| **Descriptive Messages** | Let Claude generate descriptive commit messages |
| **Git History Analysis** | Use history to understand API evolution |

## Patterns (Current)

### Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<desc>` | `feature/user-auth` |
| Bug fix | `bugfix/<desc>` | `bugfix/login-timeout` |
| Refactor | `refactor/<desc>` | `refactor/auth-module` |
| Docs | `docs/<desc>` | `docs/api-reference` |

**Purpose**: Clear categorization for PR filtering and automated workflows.

### Commit Format

**Conventional Commits standard**:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Common types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring (no behavior change)
- `docs`: Documentation only
- `test`: Test additions or corrections
- `chore`: Maintenance (dependencies, tooling)

**2026 best practice**: "Ask Claude to commit with descriptive message" - Claude analyzes changes and generates high-quality commit messages following repository conventions.

### Worktree Usage

**For parallel feature work** (2026 pattern):

```bash
# Create worktree for new feature
git worktree add ../project-feature -b feature/name

# Each worktree has independent:
# - Working directory
# - .claude/ state (independent context)
# - Branch checkout

# Work in worktree
cd ../project-feature
# ... make changes, commit ...

# Merge when ready
cd ../project-main
git merge feature/name

# Cleanup after merge
git worktree remove ../project-feature
```

**Benefits**:
- **Isolation**: Separate Claude sessions don't pollute each other's context
- **Parallel work**: Multiple features in progress simultaneously
- **Clean state**: Switch between features without stashing
- **Easy cleanup**: Remove worktree when done

**2026 pattern**: "Run parallel instances and share learnings" - multiple Claude sessions in separate worktrees compound productivity over time.

### Git History Analysis

**Use history to understand code evolution**:

```bash
# Ask Claude to analyze API evolution
"Look through [Class]'s git history and summarize how its API came to be"

# Claude uses git log, git blame, git show to:
# - Trace API changes over time
# - Identify design decisions and rationale
# - Document breaking changes
# - Understand migration paths
```

**Purpose**: Understand why code is structured a certain way before proposing changes.

### GitHub CLI Integration

**Three integration methods** (2026):

1. **`gh` CLI** (command-line interface):
   ```bash
   gh pr create --title "feat(auth): add OAuth2 support" --body "..."
   gh pr view 123
   gh pr review 123 --approve
   gh pr merge 123 --squash --delete-branch
   gh issue create --title "Bug: ..." --body "..."
   ```

2. **GitHub MCP server** (via Claude Code):
   - Connects Claude to GitHub API
   - Manages PRs, issues, checks from within Claude

3. **GitHub Action** (CI/CD automation):
   - `@claude` mention in PR/Issue triggers Claude Code
   - Automates: PR reviews, fixing issues, updating docs
   - Runs in CI/CD pipeline

**Released early 2026**: Official GitHub Action for `@claude` mentions.

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| **GitHub Actions** | Manual gh CLI | Official GitHub Action + `@claude` mentions | Enable GitHub MCP server or Action |
| **Parallel sessions** | Manual coordination | Desktop app + worktrees | Use worktrees for isolated sessions |
| **Commit messages** | Manual writing | Claude-generated (analyzes git log for style) | Ask Claude to commit with descriptive message |
| **CI integration** | Manual | Hooks for automatic quality gates | Configure hooks in CI pipeline |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Committing without descriptive message | Hard to understand history | Ask Claude to generate message from git log style |
| Force push to shared branches | Overwrites team's work | Only force push to personal branches |
| Giant commits | Hard to review, hard to revert | Atomic commits (one logical change each) |
| Committing secrets | Security vulnerability | Use .gitignore, never commit .env |
| Skipping worktrees for parallel work | Context pollution between features | Use worktrees for isolation |
| Auto-creating PRs | Lacks user consent | Always ask before creating PRs |

## Examples

### Example 1: Conventional Commit

```bash
# Ask Claude to commit
"Commit these changes with a descriptive message"

# Claude analyzes:
# - git status (staged files)
# - git diff (actual changes)
# - git log (recent commit style)

# Generated commit:
git commit -m "$(cat <<'EOF'
feat(auth): add OAuth2 authentication support

- Add OAuth2Provider with Google/GitHub integrations
- Implement token refresh logic
- Add user profile mapping from OAuth claims

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

### Example 2: Worktree Setup for Parallel Work

```bash
# Main session: Working on feature A
cd ~/project
git branch
# * feature/user-auth

# Start parallel session for feature B
git worktree add ~/project-feature-b -b feature/social-auth

# Second Claude session in new worktree
cd ~/project-feature-b
# Independent .claude/ state
# Independent context window
# Independent branch

# Work proceeds in parallel:
# - Session 1: ~/project (feature/user-auth)
# - Session 2: ~/project-feature-b (feature/social-auth)

# When feature B complete:
cd ~/project
git merge feature/social-auth
git worktree remove ~/project-feature-b
```

### Example 3: GitHub Action with @claude

```yaml
# .github/workflows/claude-pr-review.yml
name: Claude PR Review
on:
  issue_comment:
    types: [created]

jobs:
  claude-review:
    if: contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

**Triggered by**: `@claude review this PR for security issues`

### Example 4: Git History Analysis

```bash
# Ask Claude to analyze API evolution
"Look through UserService's git history and summarize how its API came to be"

# Claude executes:
git log --oneline --follow src/Services/UserService.cs
git blame src/Services/UserService.cs
git show <commit-hash> -- src/Services/UserService.cs

# Returns summary:
# - v1 (2025-06): Basic CRUD operations
# - v2 (2025-08): Added async methods (breaking change)
# - v3 (2025-11): Added OAuth2 support (additive)
# - v4 (2026-01): Refactored to use IUserRepository pattern
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Context pollution between features | Use separate worktrees for parallel work |
| Commit message inconsistent with repo style | Let Claude analyze git log and generate matching style |
| GitHub Action not triggering | Check `@claude` mention syntax, verify permissions in workflow |
| Worktree conflicts | Ensure branches are truly independent, no shared uncommitted files |
| Force push rejected | Only force push to personal branches, never shared/main |

## See Also

- `git-github-2026.md` - GitHub CLI integration
- `.claude/rules/git-workflow.md` - Git workflow rules
- `quality-gates-2026.md` - Hooks for CI/CD enforcement

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (official)
- https://www.tiecaio.ai/blog/claude-code-github-workflow
- https://skywork.ai/blog/how-to-integrate-claude-code-ci-cd-guide-2025/
- InfoQ (Claude Code creator workflow - parallel sessions)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 85%+ (patterns appear in official docs + 2+ community sources)
