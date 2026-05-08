---
category: integration-patterns
subcategory: git-github
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Git & GitHub (2026)

## Overview

Git operations, GitHub CLI integration, PR workflow automation, and repository management patterns for AI-assisted development. Includes 2026 GitHub Actions integration and MCP server capabilities.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **GitHub CLI First** | Use `gh` command for all GitHub operations |
| **Never Auto-PR** | Always ask before creating PRs |
| **Safety Protocol** | Never force-push, skip hooks, or destructive ops without approval |
| **Atomic Commits** | One logical change per commit |
| **Co-Authorship** | Always include Claude co-author tag |

## Patterns (Current)

### GitHub CLI Usage

**Recommendation**: Install `gh` CLI for GitHub integration. Claude knows how to use it for common operations.

**Common operations**:
```bash
# Create issues
gh issue create --title "Bug: ..." --body "..."

# Open pull requests
gh pr create --draft --title "feat(scope): description" --body "..."

# Read comments
gh pr view 123 --comments

# Review CI failures
gh pr checks 123
```

**Without gh**: Can use GitHub API, but unauthenticated requests hit rate limits. Always prefer `gh` CLI with authentication.

### GitHub Actions Integration (2026)

**Released early 2026**: Official GitHub Action brings Claude into CI/CD pipeline.

**Trigger**: `@claude` mention in PR or Issue

**Automates**:
- Pull request reviews
- Fixing issues
- Updating documentation
- Running quality checks

**Example workflow**:
```yaml
name: Claude Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - name: Claude Code Review
        uses: anthropics/claude-github-action@v1
        with:
          task: review-pr
```

### GitHub MCP Server

**Alternative integration**: GitHub MCP server for repository integration.

**Setup**:
```bash
claude mcp add github
```

**Capabilities**:
- Analyze repositories
- Answer technical questions
- Code assistance through `@mentions`

**Tool reference**: Always use fully qualified names: `GitHub:create_issue`, `GitHub:search_repos`

### Security Best Practices

| Practice | Reason |
|----------|--------|
| Least-privilege permissions | Avoid `contents: write` unless must open PRs |
| Require status checks | AI-authored changes need reviews |
| No force push to main/master | Protect primary branches |
| Review AI-authored changes | Human oversight required |

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| GitHub integration | Manual gh CLI only | GitHub Action + `@claude` mentions | Enable GitHub MCP server or Action |
| PR reviews | Manual only | Automated via `@claude` trigger | Configure GitHub Action workflow |
| MCP integration | N/A | `claude mcp add github` | Use qualified tool names |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| GitHub API without auth | Rate limits | Use `gh` CLI with authentication |
| Unqualified MCP tool names | "tool not found" errors | Use `GitHub:tool_name` format |
| Not using CLI tools | Inefficient API calls | Tell Claude to use `gh` for GitHub operations |
| Manual PR reviews only | Misses patterns | Use `@claude` GitHub Action for automated review |
| Force push to main | Data loss risk | Protect branches via GitHub settings |

## Examples

### Example 1: PR Creation via gh CLI

```bash
# Create PR with HEREDOC for proper formatting
gh pr create --title "feat(auth): add OAuth2 support" --body "$(cat <<'EOF'
## Summary
- Implement OAuth2 authentication flow
- Add provider configuration
- Include integration tests

## Test plan
- [x] Unit tests pass
- [x] Integration tests with mock provider
- [ ] E2E tests with real provider (manual)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Example 2: Automated Review via GitHub Action

**Workflow file** (`.github/workflows/claude-review.yml`):
```yaml
name: Claude PR Review
on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]

jobs:
  claude-review:
    if: contains(github.event.comment.body, '@claude') || github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - uses: anthropics/claude-github-action@v1
        with:
          task: review-pr
          post_comments: true
```

**Usage**: Comment `@claude review this PR` or automatic on PR open.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `gh` rate limit errors | Authenticate: `gh auth login` |
| GitHub Action not triggering | Check `@claude` mention format and workflow permissions |
| MCP tool not found | Use fully qualified name: `GitHub:create_issue` |
| PR checks failing | Review with `gh pr checks <N>` and fix issues |

## See Also

- `.claude/rules/git-workflow.md` - Git safety rules and branch naming
- `.claude/rules/quality-gates.md` - CI quality gate requirements
- `ci-cd-2026.md` - CI/CD integration patterns

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (GitHub CLI recommendations)
- https://www.thecaio.ai/blog/claude-code-github-workflow (GitHub Actions integration)
- https://code.claude.com/docs/en/mcp (MCP server setup)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 90%+ (patterns appear in official docs + GitHub integration guides)
