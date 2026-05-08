# Model Selection

| Model | Best For |
|-------|----------|
| **Opus** | Complex reasoning, architecture, security, code review |
| **Sonnet** | Implementation, testing, documentation, refactoring |
| **Haiku** | Cleanup, formatting, batch operations |

## Core Agent Mappings

| Agent | Model | | Agent | Model |
|-------|-------|-|-------|-------|
| code-investigator | Opus | | research-scout | Sonnet |
| code-implementer | Opus | | test-selector | Sonnet |
| code-reviewer | Opus | | janitor | Haiku |
| feature-verifier | Opus | | All other direct agents | Sonnet |
| work-planner | Opus | | | |
| domain-reviewer | Opus | | | |

**Composite agents** (`investigate-and-implement`, `review-and-fix`, `coverage-loop`): Opus, `subagent_type="general-purpose"`. Use for multi-step or 3+ file tasks. Save ~90% main context.

**Heuristic**: 1-2 files changed -> direct agent. 3+ files or multi-step -> composite agent (each subagent gets fresh context with rules auto-loaded, preventing context saturation).

## Agent Teams

Use **Sonnet for teammates**, **Opus for lead** (40% cost savings). Use Opus teammates only for security-critical review or first-time pattern establishment.

## Aliases & Effort Levels

| Alias | Behavior |
|-------|---------|
| `opusplan` | Opus for planning phase -> auto-switches to Sonnet for execution |

## Opus 4.6 Effort Levels

| Level | Use Case |
|-------|----------|
| `low` | Quick tasks, formatting, batch ops |
| `medium` | Standard implementation (default) |
| `high` | Complex reasoning, security review, architecture |

Set via `CLAUDE_CODE_EFFORT_LEVEL` in `.claude/settings.local.json` under `env`.
