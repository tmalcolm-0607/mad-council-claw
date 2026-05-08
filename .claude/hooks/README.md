# Claude Code Hooks

Event-driven automations for Claude Code sessions.

## Available Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `add-context.js` | UserPromptSubmit | Inject git branch and time into prompts |
| `context-warning.js` | UserPromptSubmit | **WARN** at 70% token usage with count displayed |
| `parallel-opportunity-detector.js` | UserPromptSubmit | **WARN** when 3+ independent tasks could be parallelized |
| `detect-anomaly.js` | UserPromptSubmit, SubagentStop, PostToolUse | **WARN** unusual session patterns (spawns, failures, duration) |
| `on-permission.js` | PermissionRequest | Auto-approve safe operations to reduce permission prompts |
| `pre-bash-validate.js` | PreToolUse (Bash) | Block dangerous commands |
| `pre-commit-validate.js` | PreToolUse (Bash) | **ENFORCE** test verification before commits |
| `check-worktree.js` | PreToolUse (Bash) | **WARN** when feature work runs outside worktree |
| `enforce-e2e-smoke.js` | PreToolUse (Bash) | **ENFORCE** block commits with frontend changes unless E2E smoke tests ran recently |
| `pre-commit-tokens.js` | PreToolUse (Bash) | **ENFORCE** validate token limits for Claude configuration files before commit |
| `e2e-mock-check.js` | PreToolUse (Write\|Edit) | **BLOCK** writing E2E tests that mock APIs |
| `require-plan-approval.js` | PreToolUse (Write\|Edit) | **WARN** when implementing source code without an approved plan |
| `tdd-advisory.js` | PreToolUse (Write\|Edit) | Advisory reminder for TDD workflow when modifying source without recent test changes (always exit 0) |
| `enforce-orchestration.js` | PreToolUse (Read) | **ENFORCE** block main conversation from reading code files directly |
| `mcp-tier-redirect.js` | PreToolUse (mcp__*) | Redirect CLI-tier MCP tools to CLI invocation |
| `auto-register-artifact.js` | PostToolUse (Write\|Edit) | Auto-register artifacts written to work-items directories in manifest |
| `mid-flight-pattern-lint.js` | PostToolUse (Write\|Edit) | Regex-based C# pattern checking at zero LLM cost |
| `validate-plan-gates.js` | PostToolUse (Write\|Edit) | **ENFORCE** plan.md pattern compliance and verification spec completeness |
| `auto-run-quality-gates.js` | PostToolUse (Write\|Edit) | Auto-execute quality gates when a phase completes in plan.md |
| `validate-checkpoint.js` | PostToolUse (Bash) | **WARN** when phase transitions happen without plan updates |
| `capture-learning.js` | PostToolUse (Bash), SubagentStop | Capture success/failure patterns for the learning system |
| `session-start.js` | SessionStart | Initialize environment variables |
| `on-subagent-stop.js` | SubagentStop | Collect subagent results and metrics |
| `validate-baseline-size.js` | SubagentStop | **ENFORCE** 200-line cap on baseline extraction files |
| `validate-agent-deliverable.js` | SubagentStop | **WARN** validate that agents produced their expected deliverable files |
| `validate-quality-gates.js` | SubagentStop | **ENFORCE** detect when quality gate failures are dismissed without action |
| `validate-featuremap.js` | SubagentStop | **WARN** non-blocking staleness warnings for featuremap |
| `stop-guard.js` | Stop | Warn about unchecked plan items when session ends, suggest handoff generation (advisory, always exit 0) |
| `on-notification.js` | Notification | Log notifications, send alerts |
| `pre-compact.js` | PreCompact | Backup context before compaction |
| `session-end.js` | SessionEnd | Cleanup and save session metrics |
| `TeammateIdle.ps1` | TeammateIdle | Cleanup and coordination when Agent Teams teammates idle |
| `TaskCompleted.ps1` | TaskCompleted | Validate mad-validate output and block progression on failure |

### Helper Modules

| Module | Purpose |
|--------|---------|
| `update-context-failure.js` | Add/update failure entries in context.md Failure Log |

## Configuration

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [{
          "type": "command",
          "command": ".claude/hooks/add-context.js"
        }]
      }
    ]
  }
}
```

## Hook Events

| Event | When | Use Case |
|-------|------|----------|
| `UserPromptSubmit` | User submits prompt | Add context, validate input |
| `PreToolUse` | Before tool executes | Block/modify dangerous operations |
| `PostToolUse` | After tool completes | Lint, validate, provide feedback |
| `SessionStart` | Session begins | Set environment, check prerequisites |
| `SessionEnd` | Session ends | Cleanup temporary files, save metrics |
| `Stop` | Claude finishes | Log reason, capture metrics |
| `SubagentStop` | Subagent completes | Collect results, log completion |
| `PermissionRequest` | Permission needed | Auto-approve safe ops, log requests |
| `Notification` | Notification fired | Log, alert external systems |
| `PreCompact` | Before compaction | Backup important context |

## Execution Order

Hooks execute sequentially in registration order for each event type. Understanding execution flow is critical for debugging and designing hook interactions.

### Sequential Execution

Hooks for the same event run in the order they appear in `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "hooks": [{ "command": "hook-a.js" }] },  // Runs first
      { "hooks": [{ "command": "hook-b.js" }] },  // Runs second
      { "hooks": [{ "command": "hook-c.js" }] }   // Runs third
    ]
  }
}
```

### Exit Code Semantics

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| **0** | Success | Hook completed normally. For `UserPromptSubmit`, stdout becomes `<user-prompt-submit-hook>` message injected into context. |
| **2** | Blocking error | **Stops execution**. Tool use is blocked (PreToolUse) or action is cancelled. stderr is shown to user. |
| **Other non-zero** | Warning | Non-blocking warning. stderr is shown in verbose mode (`--debug`). Execution continues. |

### Exit Code Examples

```javascript
// Exit 0: Success - stdout becomes context message
console.log("Branch: feature/auth, Time: 14:30");
process.exit(0);

// Exit 2: Block the operation
console.error("BLOCKED: Cannot delete protected files");
process.exit(2);

// Exit 1: Warning only (non-blocking)
console.error("WARNING: Large file detected, consider chunking");
process.exit(1);
```

### Blocking Behavior (PreToolUse)

For `PreToolUse` hooks, execution stops at the first hook that returns exit code 2:

```
Hook A (exit 0) → Hook B (exit 2) → Hook C (never runs)
                         ↓
                  Tool execution blocked
                  stderr shown to user
```

### Non-Blocking Warnings

Hooks with exit codes other than 0 or 2 produce warnings but don't stop execution:

```
Hook A (exit 0) → Hook B (exit 1, warning) → Hook C (exit 0) → Tool executes
                         ↓
                  Warning logged (visible with --debug)
```

### Best Practices

1. **Use exit 2 sparingly** - Only for genuine safety/security blocks
2. **Prefer exit 0 with warnings** - Log to stderr but don't block
3. **Order matters** - Put validation hooks before informational hooks
4. **Keep hooks fast** - Slow hooks impact user experience

## Hook Details

### Session Lifecycle

```
SessionStart    → ... session activity ...    → SessionEnd
     │                                              │
     └─ session-start.js                           └─ session-end.js
        (env vars, checks)                            (cleanup, metrics)
```

### Tool Lifecycle

```
Permission? → PreToolUse → [Tool Executes] → PostToolUse
     │              │                              │
     └─ on-permission.js         ├─ pre-bash-validate.js (block dangerous)
        (auto-approve reads)     └─ pre-commit-validate.js (enforce tests)
```

### Pre-Commit Validation (ENFORCEMENT)

The `pre-commit-validate.js` hook enforces quality gates by blocking commits without test verification.

**What it checks:**
1. Does the commit message contain gate results (e.g., "Tests: X passed, 0 failed")?
2. Were tests run recently (within last 5 minutes)?

**Blocked if:**
- No gate verification in commit message AND
- No recent test execution detected

**Example valid commit:**
```bash
git commit -m "feat: add user login

Gate Results:
- Build: ✅
- Tests: 217 passed, 0 failed
- Coverage: 85%"
```

**To bypass (not recommended):**
Run `npm test` within 5 minutes of committing, or include gate results in message.

### Worktree Check (WARNING)

The `check-worktree.js` hook warns when feature development commands are run from the main repository instead of a worktree.

**What it detects:**
| Commands | Action |
|----------|--------|
| `git commit`, `git push` | Warn if not in worktree |
| `gh pr create`, `gh pr review` | Warn if not in worktree |
| Build/test before commit chains | Warn if not in worktree |

**Why worktrees matter:**
- Isolates feature work from main repo state
- Prevents accidental commits to wrong branch
- Ensures PR reviews see correct file state
- Enables parallel work on multiple features

**What happens:**
- Hook runs before Bash commands
- Detects if working directory is a worktree
- If feature work detected in main repo → shows warning
- Command still runs (warning only, not blocking)

**Example warning:**
```
WARNING: Running feature development command in main repository (not a worktree).
Current branch: feature/context-handoff
For isolated development, use a worktree:
  git worktree add ../ccghcp-feature/context-handoff feature/context-handoff
  cd ../ccghcp-feature/context-handoff
```

### Validate Checkpoint (WARNING)

The `validate-checkpoint.js` hook warns when phase transitions are detected but the plan file hasn't been updated.

**What it detects:**
- "phase complete" or "phase N complete" in output
- "moving to phase" or "proceeding to phase"
- "checkpoint complete", "implementation complete", etc.

**What it checks:**
- Was any plan.md file modified in the last 5 minutes?
- Checks work item plan and specs directory plans

**Why this matters:**
- Per plan-management rules, plan files must be updated in real-time
- The plan file is the SOURCE OF TRUTH for progress tracking
- Batching updates at the end loses progress if interrupted

**Example warning:**
```
WARNING: Phase transition detected but plan.md may not be updated.

Detected: "phase 3 complete"

Plan files checked:
  - specs/001-feature/plan.md
  - .claude/work-items/WI-001/plan.md

REMINDER: Per plan-management rules, you MUST update the plan file:
  - Mark checkboxes as [x] when tasks complete
  - Fill Results sections with findings
  - Update phase status to "Complete"
```

### Context Warning (INFORMATIONAL)

The `context-warning.js` hook warns about context usage based on token estimation.

**When it triggers:**
1. When estimated token usage exceeds 70% of capacity (~140k tokens)
2. When detecting context-heavy operation keywords like:
   - "read all", "analyze entire", "full codebase"
   - "review all files", "search entire", "whole project"

**Token estimation:**
- Prefers actual token counts from session metadata if available
- Falls back to estimation based on prompt length and response averages
- Tracks cumulative usage across the session

**What it shows:**
- Current token count and percentage: "Context usage: X tokens (~Y%)"
- Reminder about `/cost`, `/clear`, `/compact` commands
- Tips for managing context with agents
- Link to context-management.md for full guidelines

**Example warning:**
```
CONTEXT MANAGEMENT WARNING
==========================

Context usage: 145.2k tokens (~73%)

Token usage has exceeded 70% threshold.
Consider using /clear or /compact to free up context.

Useful commands:
  /cost     - Check actual token usage and costs
  /clear    - Clear conversation history to free context
  /compact  - Summarize and compact the conversation

Tips:
  - Spawn agents for context-heavy tasks (investigation, research)
  - Agent outputs should be summaries, not raw dumps
  - Keep orchestrator context clean for coordination
  - Consider starting fresh if context feels sluggish

See: .claude/rules/context-management.md for full guidelines.
```

### Anomaly Detection (WARNING)

The `detect-anomaly.js` hook identifies unusual patterns in Claude Code sessions.

**What it detects:**
| Anomaly | Severity | Trigger |
|---------|----------|---------|
| EXCESSIVE_SPAWNS | Medium | >10 agent spawns per hour |
| REPEATED_FAILURES | High | 3+ consecutive failures |
| UNUSUAL_TOKENS | Medium | Token usage >2x average |
| LONG_SESSION | Low | Session exceeds 2 hours |
| RAPID_PROMPTS | Low | 5 prompts <30s apart |

**When it triggers:**
- UserPromptSubmit: Checks rapid prompts and session duration
- SubagentStop: Checks spawn rate, failures, token usage
- PostToolUse (Bash): Tracks gate failures

**State tracking:**
- Session state stored in `.mad/scratch/anomaly-state.json`
- Anomalies logged to `.mad/logs/anomaly.log`
- State resets on new session ID

**Customization:**
Thresholds can be adjusted in `.claude/rules/anomaly-thresholds.md`:
```markdown
| spawns_per_hour | 20 |  // Increase for heavy orchestration
| consecutive_failures | 2 |  // Decrease for stricter mode
```

**Example warning:**
```
[HIGH] ANOMALY DETECTED: REPEATED_FAILURES
--------------------------------------------------
3 consecutive failures detected

Recommendation: Stop and investigate the root cause. Check logs, review recent changes, or consider a different approach.
--------------------------------------------------
```

### Event Hooks

```
Stop event           → stop-guard.js (plan check, handoff)
SubagentStop event   → on-subagent-stop.js (collect results)
Notification event   → on-notification.js (log, alert)
PreCompact event     → pre-compact.js (backup context)
```

## Writing Hooks

### Input

Hooks receive JSON on stdin:

```json
{
  "session_id": "abc123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test"
  }
}
```

### Output

- **Exit 0**: Success (stdout processed)
- **Exit 2**: Blocking error (stderr shown)
- **Other**: Non-blocking (stderr in verbose mode)

### Controlling Tool Execution (PreToolUse)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "Explanation"
  }
}
```

### Permission Decisions (PermissionRequest)

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "Reason text"
  }
}
```

## Log Files

Hooks write to these log files in `~/.claude/` or `.mad/logs/`:

| Log File | Written By | Content |
|----------|------------|---------|
| `session-metrics.log` | stop-guard.js, session-end.js | Session lifecycle events |
| `subagent-metrics.log` | on-subagent-stop.js | Subagent completions |
| `permission-requests.log` | on-permission.js | Permission request audit |
| `notifications.log` | on-notification.js | All notifications |
| `compaction.log` | pre-compact.js | Compaction events |
| `context-backups/` | pre-compact.js | Context backup files |
| `.mad/logs/anomaly.log` | detect-anomaly.js | Detected anomalies with timestamps |

## Testing Hooks

```bash
# Test manually
echo '{"tool_input":{"command":"rm -rf /"}}' | node .claude/hooks/pre-bash-validate.js

# Test permission hook
echo '{"tool":"Read","action":"file.txt"}' | node .claude/hooks/on-permission.js

# Test validate-checkpoint hook (phase transition detected)
echo '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_output":"Phase 3 complete, moving to review"}' | node .claude/hooks/validate-checkpoint.js

# Test context-warning hook (heavy operation)
echo '{"hook_event_name":"UserPromptSubmit","session_id":"test123","prompt":"read all files in the project"}' | node .claude/hooks/context-warning.js

# Test anomaly detection (UserPromptSubmit)
echo '{"hook_event_name":"UserPromptSubmit","session_id":"test123"}' | node .claude/hooks/detect-anomaly.js

# Test anomaly detection (SubagentStop with failure)
echo '{"hook_event_name":"SubagentStop","session_id":"test123","error":true}' | node .claude/hooks/detect-anomaly.js

# Test anomaly detection (PostToolUse with non-zero exit)
echo '{"hook_event_name":"PostToolUse","session_id":"test123","exit_code":1}' | node .claude/hooks/detect-anomaly.js

# Debug mode
claude --debug
```

## Security Notes

- Hooks execute arbitrary shell commands
- Always validate and sanitize inputs
- Use absolute paths with `$CLAUDE_PROJECT_DIR`
- Never trust input blindly
- Log files may contain sensitive information - secure appropriately
