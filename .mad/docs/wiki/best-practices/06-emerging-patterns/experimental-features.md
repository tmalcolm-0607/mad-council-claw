---
category: emerging-patterns
subcategory: experimental-features
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Experimental Features (2026)

## Overview

Beta features, feature flags, and opt-in functionality in Claude Code. Use with caution - experimental features may change or be removed.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Opt-In** | Experimental features require explicit enabling |
| **Feature Flags** | Configure via `.claude/settings.local.json` |
| **Stability Warning** | Expect breaking changes, bugs |
| **Feedback Loop** | Report issues to improve features |
| **Rollback Plan** | Know how to disable if problematic |

## Experimental Features

### Current Experiments

| Feature | Flag | Status | Stability |
|---------|------|--------|-----------|
| **Agent Teams** | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Research preview | **Beta** |

### Agent Teams (Research Preview)

**Status**: Beta - feature-complete but expect bugs and limitations

**Enable**: Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` under `env`

**Capability**: Multi-agent collaboration with autonomous coordination. Spin up multiple agents working in parallel as a team.

**Use cases**:
- Parallel implementation (≥3 independent tasks with disjoint file ownership)
- Multi-domain code review (security, quality, tests reviewers)
- Parallel validation (lint, coverage, security checks)
- Research swarm (parallel research topics)

**Cost**: Token-intensive
- 2 teammates ≈ 3x baseline cost
- 5 teammates ≈ 6x baseline cost
- Per-teammate model selection supported via `model` parameter (`"sonnet"`, `"opus"`, `"haiku"`); use Sonnet for teammates to reduce cost ~40%

**Justification threshold**: Use only when wall-clock savings ≥ 1.5x and cost multiplier ≤ 5x

See: `.claude/rules/agent-teams.md` for decision rules, `.claude/docs/agent-teams-guide.md` for comprehensive guide

## Feature Flags

### Configuration

All feature flags are set in `.claude/settings.local.json` under the `env` key:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "0"
  }
}
```

**Note**: These are read directly by Claude Code - do NOT set as shell environment variables.

### Flag Reference

| Flag | Values | Default | Purpose |
|------|--------|---------|---------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `0`, `1` | `0` | Enable agent teams (research preview) |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | `0`, `1` | `0` | Disable all experimental betas (gateway users workaround) |
| `DAG_EXECUTION_MODE` | `classic`, `dag-parse-only`, `dag-validate`, `dag-execute` | `classic` | DAG-based task orchestration mode |
| `DAG_VISUALIZATION_ENABLED` | `false`, `true` | `false` | Enable `/dag-visualize` skill |
| `DAG_CONTEXT_THRESHOLD` | `0.0` - `1.0` | `0.85` | Context budget threshold for DAG halting |
| `CONTEXT_GUARDIAN_ADVISORY_THRESHOLD` | `0.50` - `1.00` | `0.50` | When ADVISORY warnings begin |
| `CONTEXT_GUARDIAN_PREPARE_THRESHOLD` | `0.50` - `1.00` | `0.70` | When PREPARE warnings begin |
| `CONTEXT_GUARDIAN_HALT_THRESHOLD` | `0.50` - `1.00` | `0.85` | When hard block fires |
| `CONTEXT_GUARDIAN_HIDDEN_BUFFER` | `0.00` - `0.50` | `0.165` | Hidden buffer ratio for context rescaling (16.5% of capacity reserved for overhead). Set to `0` to disable rescaling and use raw 200K capacity |
| `STOP_GUARD_ENABLED` | `true`, `false` | `true` | Session-exit advisor that warns when work items have unchecked plan items at session end. Set to `"false"` to disable |
| `PUSH_GUARD_MODE` | `"warn"`, `"block"` | `"warn"` | Git push guard mode: `"warn"` emits warning but allows push; `"block"` prevents push entirely |
| `MCP_TIER_ENFORCE` | unset, `"true"` | unset | MCP tier enforcement: unset = advisory mode (warning only); `"true"` = blocking mode (prevents CLI-tier MCP tool use) |
| `TDD_ADVISORY_ENABLED` | `true`, `false` | `true` | TDD advisory hook that reminds developers to write tests before source code. Set to `"false"` to disable |
| `KNOWLEDGE_EXTRACTION_MIN_DURATION_MS` | `60000` - `3600000` | `600000` | Minimum agent session duration (ms) to trigger knowledge extraction prompts. Range: 1 min to 60 min |
| `E2E_STALENESS_HOURS` | Integer | `4` | Hours before E2E test results are considered stale and must be re-run before commits |
| `E2E_ENFORCEMENT_MODE` | `"block"`, `"warn"` | `"block"` | E2E enforcement: `"block"` prevents commits without recent E2E; `"warn"` logs violation but allows commit |

**DAG execution flags**: See `.claude/docs/dag-feature-flags.md` for adoption path and detailed documentation

**Context guardian flags**: See `.claude/rules/context-guardian.md` for threshold behaviors

**All flags** are set under the `"env"` key in `.claude/settings.local.json`:

```json
{
  "env": {
    "STOP_GUARD_ENABLED": "false",
    "PUSH_GUARD_MODE": "block",
    "TDD_ADVISORY_ENABLED": "false"
  }
}
```

## Stability Levels

| Level | Meaning | Recommendation |
|-------|---------|----------------|
| **Alpha** | Proof of concept, may not work | Testing only, not production |
| **Beta** | Feature-complete, may have bugs | Use with caution, have rollback plan |
| **RC** | Release candidate, near-stable | Safe for most use cases |
| **Stable** | Production-ready | Recommended for all users |

**Current stability assignments**:
- **Agent Teams**: Beta (expect bugs, have rollback plan)
- **DAG Execution**: Alpha → Beta (adoption path: `classic` → `dag-parse-only` → `dag-validate` → `dag-execute`)
- **Hooks**: Stable (production-ready as of Q1 2026)

## Known Limitations

### Agent Teams

| Limitation | Impact | Workaround |
|------------|--------|-----------|
| **No session resumption** | `/resume`, `/rewind` don't restore in-process teammates | Spawn new teammates after resume |
| **Task status lag** | Teammates fail to mark tasks complete, blocks dependencies | Lead manually marks tasks complete after verification |
| **Slow shutdown** | Teammates finish current request before shutting down | Allow time for graceful shutdown |
| **One team per session** | Lead can only manage one team at a time | Complete team work before spawning new team |
| **No nested teams** | Teammates can't spawn their own teams | Flatten team structure |
| **Fixed lead** | Can't promote teammate to lead or transfer leadership | Lead coordinates all work |
| **Permissions set at spawn** | Can't set per-teammate modes at spawn time | All teammates inherit lead's permissions |
| **Split panes require tmux/iTerm2** | Not supported in VS Code terminal, Windows Terminal, Ghostty | Use tmux (Linux/macOS) or iTerm2 (macOS) |

**Critical limitations**:
- No background agents (`run_in_background: true`) - confirmed bugs causing hangs (#20679), empty outputs (#21352), session freezes (#17540)
- File ownership conflicts cause corruption - MUST have disjoint file sets
- Cost multiplier can exceed 6x for large teams

### DAG Execution

| Limitation | Impact | Workaround |
|------------|--------|-----------|
| **Backward compatibility mode** | Existing `tasks.md` files work unchanged | Optional annotations for DAG features |
| **Context budget halting** | DAG execution stops when context threshold reached | Lower `DAG_CONTEXT_THRESHOLD` or use handoff |
| **Visualization requires flag** | `/dag-visualize` disabled by default | Set `DAG_VISUALIZATION_ENABLED=true` |

## Examples

### Example 1: Enabling Agent Teams

**Step 1**: Edit `.claude/settings.local.json`

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Step 2**: Configure team templates (`.claude/agent-teams-config.json`)

```json
{
  "enabled": true,
  "phases": {
    "implement-parallel": "teams"
  }
}
```

**Step 3**: Verify setup when skill prompts for team usage

**Expected**: Skill detects config and spawns team instead of sequential subagents

### Example 2: Rolling Back Agent Teams

**Scenario**: Agent teams causing hangs or file conflicts

**Step 1**: Disable flag in `.claude/settings.local.json`

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"
  }
}
```

**Step 2**: Skills automatically fall back to sequential subagent execution

**Result**: No code changes needed - skills detect disabled flag and use fallback behavior

### Example 3: Enabling DAG Execution (Safe Adoption Path)

**Phase 1**: Parse-only mode (validate DAG annotations without changing behavior)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-parse-only"
  }
}
```

**Phase 2**: Validation mode (warn on invalid DAG, continue with classic)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-validate"
  }
}
```

**Phase 3**: Execution mode (use DAG for wave-based parallelization)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "dag-execute"
  }
}
```

See: `.claude/docs/dag-migration-guide.md` for detailed adoption path

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Agent team hangs** | Check for background agents (`run_in_background: true`) - use synchronous parallel instead |
| **File conflicts in parallel work** | Verify disjoint file ownership - use `.mad/lib/file-ownership.js` to detect conflicts |
| **Teammate not found error** | Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings, check split pane support (tmux/iTerm2) |
| **Context validation errors (gateway)** | Set `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` |
| **DAG visualization missing** | Set `DAG_VISUALIZATION_ENABLED=true` in settings |
| **Task status lag** | Lead manually marks tasks complete after verifying teammate work |
| **Cost exceeds budget** | Reduce team size, switch teammates to Sonnet 4.5 via `model: "sonnet"` parameter (~40% cost reduction) |

## Rollback Plan

### Quick Disable (Agent Teams)

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"
  }
}
```

**Effect**: All skills fall back to sequential subagent execution - no code changes needed

### Quick Disable (DAG Execution)

```json
{
  "env": {
    "DAG_EXECUTION_MODE": "classic"
  }
}
```

**Effect**: Task execution reverts to classic linear mode

### Emergency Disable (All Betas)

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"
  }
}
```

**Effect**: Disables all experimental features - use for gateway validation errors

## Graduation Path

**Expected timeline** (based on release patterns):

| Feature | Current Status | Expected Stable |
|---------|---------------|-----------------|
| **Agent Teams** | Beta (Q1 2026) | Q2-Q3 2026 |
| **DAG Execution** | Alpha | Q2 2026 |
| **Hooks** | Stable (Q1 2026) | Already stable |

**Indicators of maturation**:
- Removal of experimental flag requirement
- Documentation moved from "experimental" to "features"
- Inclusion in default workflows without opt-in

## See Also

- `whats-new-q1-2026.md` - Features graduating from experimental
- `.claude/settings.local.json` - Feature flag configuration
- `.claude/rules/agent-teams.md` - Agent teams decision rules
- `.claude/docs/agent-teams-guide.md` - Comprehensive agent teams guide
- `.claude/docs/dag-feature-flags.md` - DAG execution feature flags
- `.claude/docs/dag-execution-guide.md` - DAG execution guide
- `.claude/rules/context-guardian.md` - Context guardian thresholds
- https://code.claude.com/docs/en/agent-teams - Official agent teams documentation

## Research Metadata

**Sources consulted**:
- https://support.claude.com/en/articles/12138966-release-notes
- https://code.claude.com/docs/en/agent-teams
- https://www.gradually.ai/en/changelogs/claude-code/
- https://releasebot.io/updates/anthropic
- Internal documentation (`.claude/docs/`, `.claude/rules/`)

**Research date**: 2026-02-16
**Confidence level**: HIGH (official documentation + internal codebase validation)
**Frequency validation**: 100% (all limitations documented in official agent teams docs)
**Next refresh**: 2026-05-16 (quarterly update)
