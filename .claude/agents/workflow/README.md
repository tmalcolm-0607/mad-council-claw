# Claude Code Agents

Custom agents for specialized tasks via the Task tool.

## Metadata Schema

Agent definition files include YAML frontmatter with marketplace metadata:

| Field | Required | Description |
|-------|----------|-------------|
| `version` | Yes | Semantic version (e.g., 1.0.0) |
| `tags` | Yes | Array of descriptive tags for discovery |
| `category` | Yes | Agent category (see below) |
| `model` | Yes | Default model: opus, sonnet, or haiku |
| `model_rationale` | Yes | Why this model was chosen |
| `estimated_tokens` | Yes | Typical token usage per invocation |

### Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| `core-workflow` | Essential MAD workflow | code-investigator, code-implementer, code-reviewer, feature-verifier, work-planner |
| `composite` | Multi-step orchestration | investigate-and-implement, review-and-fix, coverage-loop |
| `adversarial-review` | Multi-perspective review | advocate, architect, skeptic |
| `research` | Research pipeline | research-scout, research-curator, research-reviewer, pattern-discoverer, pr-pattern-miner |
| `code-quality` | Analysis and testing | test-selector, domain-reviewer |
| `utility` | Maintenance tasks | janitor |

### Example Frontmatter

```yaml
---
name: code-investigator
version: 1.0.0
tags: [read-only, analysis, investigation, patterns]
category: core-workflow
model: opus
model_rationale: Complex code analysis requires deep reasoning to understand patterns, trace flows, and document findings with precision
estimated_tokens: 20000
---
```

---

## Active Agents

### Orchestration & Verification

| Agent | Purpose | Model |
|-------|---------|-------|
| `feature-verifier` | Interpret test results, determine structural soundness | Opus |
| `work-planner` | Create structured plans for all work | Opus |
| `code-investigator` | Deep code investigation (read-only) | Opus |
| `code-implementer` | Implement with TDD and quality gates | Opus |

### Composite Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `investigate-and-implement` | Full investigation and implementation loop | Opus |
| `review-and-fix` | Code review with automated fix cycle | Opus |
| `coverage-loop` | Iterative test coverage gap closure | Opus |

### Research Pipeline

| Agent | Purpose | Model |
|-------|---------|-------|
| `research-scout` | Breadth-first source discovery (15-30 sources) | Sonnet |
| `research-curator` | Truth-gating, validate claims, assign confidence | Opus |
| `research-reviewer` | Adversarial audit, challenge findings, propose safeguards | Opus |
| `parallel-researcher` | Combined 3-tier pipeline for team research swarms | Opus |
| `pattern-discoverer` | Extract and document reusable patterns from code | Sonnet |
| `pr-pattern-miner` | Mine patterns from PR review comments | Sonnet |

### Quality & Testing

| Agent | Purpose | Model |
|-------|---------|-------|
| `test-selector` | Intelligent test tier selection for progressive validation | Sonnet |
| `code-reviewer` | Comprehensive code review | Opus |
| `domain-reviewer` | Multi-domain review (security, performance, architecture, UX) | Opus |

### Adversarial Review

| Agent | Purpose | Model |
|-------|---------|-------|
| `advocate` | Defense perspective in adversarial review panel | Opus |
| `architect` | Evaluator perspective in adversarial review panel | Opus |
| `skeptic` | Attacker perspective in adversarial review panel | Opus |

### Utility

| Agent | Purpose | Model |
|-------|---------|-------|
| `janitor` | Cleanup old artifacts and scratch files | Haiku |

## Archived Agents

The following agents are archived in `.claude/agents/archive/` and not available for direct dispatch. They can be restored if needed:

accessibility-checker, api-designer, component-cleaner, component-scanner, cosmos-expert, coverage-enforcer, debugger, error-handler, git-workflow, infra-auditor, lang-typescript-expert, nuget-manager, performance-analyzer, refactoring-specialist, security-auditor, test-runner

## Usage with Task Tool

Agents are invoked via the Task tool:

```
Task tool with subagent_type="general-purpose"
prompt: "Use the test-selector agent to pick the minimum safe test scope and run tests"
```

## Agent Structure

Each agent file defines:

1. **Purpose** - When to use this agent
2. **Capabilities** - What it can do
3. **Patterns** - Code examples and templates
4. **Output Format** - Expected report structure
5. **Tools** - Which tools the agent uses

## Integration

Agents complement skills:
- **Skills** = User-invoked slash commands
- **Agents** = Task tool patterns for automation

Some overlap exists (e.g., code-reviewer is both a skill and can be an agent pattern).
