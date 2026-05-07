# Artifact Placement

## Rule

`.claude/` is for **configuration only**. `.mad/` is for **all runtime artifacts**.

## Directory Semantics

### `.claude/` — Configuration (committed)

| Directory | Purpose |
|-----------|---------|
| `.claude/rules/` | Behavioral rules, pattern files |
| `.claude/hooks/` | Hook scripts (JS, PS1) |
| `.claude/agents/` | Agent persona definitions |
| `.claude/skills/` | Skill definitions (SKILL.md) |
| `.claude/settings.json` | Hook registration, permissions |
| `.claude/settings.local.json` | Local overrides (gitignored) |
| `.claude/work-items/` | Work item state (ACTIVE pointer, PENDING_HANDOFF) |

### `.mad/` — Runtime Artifacts

| Directory | Purpose |
|-----------|---------|
| `.mad/scratch/` | Temporary scripts, intermediate analysis, state files |
| `.mad/work-items/` | Agent artifacts per work item |
| `.mad/learning/` | Extracted patterns from PRs and validation |
| `.claude/scripts/` | Reusable PowerShell/Bash wrapper scripts |
| `.mad/docs/` | Domain knowledge, workflow guidance |
| `.mad/logs/` | Runtime logs (anomaly, session) |
| `.mad/metrics/` | Agent effectiveness metrics |
| `.mad/reports/` | Generated reports and review output |

## Anti-Patterns

| Wrong | Correct |
|-------|---------|
| `.claude/scratch/` | `.mad/scratch/` |
| `.claude/lib/` | `.mad/lib/` |
| `.claude/logs/` | `.mad/logs/` |
| `.claude/metrics/` | `.mad/metrics/` |
| `.claude/learning/` | `.mad/learning/` |
| Reports only in conversation | Write to `.mad/reports/` or `.mad/work-items/` |

## Enforcement

No hook currently enforces this rule. Rely on CLAUDE.md instruction and agent prompts.
