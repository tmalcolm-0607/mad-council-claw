# Hook Fail-Open Policy

Reference for hook authors on correct exit codes. The central rule: **exit(1) is always wrong**.

---

## Exit Code Reference

| Hook Role | Event Type(s) | On Success | On Warning | On Error | Block Action |
|-----------|--------------|------------|------------|----------|--------------|
| Advisory | UserPromptSubmit | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | PostToolUse | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | SubagentStop | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | SessionStart | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | SessionEnd | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | Stop | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | TeammateIdle | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | TaskCompleted | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | Notification | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Advisory | PreCompact | exit 0 | exit 0 | exit 0 | N/A — cannot block |
| Security/Blocking | PreToolUse (allow) | exit 0 | exit 0 | exit 2 | exit 2 to block |
| Security/Blocking | PreToolUse (deny) | — | — | exit 2 | exit 2 to block |
| Security/Blocking | PermissionRequest | exit 0 (allow) | — | exit 2 | exit 2 to deny |

**Key rule**: exit 2 blocks execution. exit 0 allows it. exit 1 is undefined behavior in Claude Code.

---

## The exit(1) Antipattern

`exit(1)` is always wrong in Claude Code hooks. Here is why:

Claude Code only recognizes two semantically meaningful exit codes:

- **exit 0** — Success / allow / continue. Claude Code proceeds normally.
- **exit 2** — Block. Claude Code stops the action and shows the hook's stderr output to the user.

**exit 1 is not defined.** It is not "block with error" — that is exit 2. It is not "warn" — that is exit 0 with output to stderr. When a hook exits with code 1, Claude Code treats it as an unexpected hook failure, not as a meaningful signal. The behavior is undefined and may change across versions.

**Advisory hooks must exit 0 even on error.** An advisory hook (UserPromptSubmit, PostToolUse, etc.) exists to observe and warn, never to block. If the hook crashes or encounters an unexpected error, exiting with 0 is correct because the hook should fail-open — Claude Code must continue running regardless of whether the advisory succeeded. A hook that exits 1 on an internal error can silently break all prompts.

**Blocking hooks must exit 2 to actually block.** A PreToolUse security hook that wants to deny an action must use exit 2, not exit 1. If the hook exits 1 on an unexpected error, the action may or may not be blocked depending on Claude Code internals — that ambiguity is the danger.

---

## Catch Handler Templates

Copy-paste these templates into new hooks.

### Advisory hook catch handler

Use for: UserPromptSubmit, PostToolUse, SubagentStop, SessionStart, SessionEnd, Stop, TeammateIdle, TaskCompleted, Notification, PreCompact

```javascript
// Advisory hook: always exit 0 (fail-open)
// Errors must not block Claude Code from continuing.
main().catch(() => process.exit(0));
```

### Security/Blocking hook catch handler

Use for: PreToolUse hooks that intentionally block dangerous commands, PermissionRequest hooks

```javascript
// Security hook: exit 2 on unexpected error (fail-closed)
// An unknown error means we cannot verify safety — deny by default.
main().catch(() => process.exit(2));
```

### Within-function error handling for advisory hooks

```javascript
async function main() {
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    process.exit(0);  // No input: exit 0, not exit 1
  }

  let data;
  try {
    data = JSON.parse(input);
  } catch (e) {
    process.exit(0);  // Parse error: exit 0, not exit 1
  }

  // ... advisory logic ...

  process.exit(0);  // Always exit 0
}

main().catch(() => process.exit(0));  // Catch handler: exit 0
```

### Within-function error handling for security hooks

```javascript
async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);
    const command = data.tool_input?.command || '';

    if (!command) {
      process.exit(0);  // No command to check: allow
    }

    // ... blocking logic ...

    process.exit(0);  // Default: allow
  } catch (err) {
    // Unknown error: fail-closed (cannot verify safety)
    console.error('[hook-name] FATAL ERROR:', err.message);
    process.exit(2);
  }
}

main();  // No .catch() needed — try/catch inside main handles it
```

---

## Classification of Registered Hooks

Every hook currently registered in `.claude/settings.json`, classified by role.

### Advisory Hooks (exit 0 on all paths)

| Hook File | Event | Purpose |
|-----------|-------|---------|
| `add-context.js` | UserPromptSubmit | Injects work item context into prompts |
| `context-warning.js` | UserPromptSubmit | Warns when context window is near capacity |
| `parallel-opportunity-detector.js` | UserPromptSubmit | Detects parallelizable task groups |
| `detect-anomaly.js` | UserPromptSubmit, SubagentStop, PostToolUse | Detects unusual session patterns |
| `on-subagent-stop.js` | SubagentStop | Tracks subagent completion |
| `capture-learning.js` | SubagentStop, PostToolUse (Bash) | Captures session learnings |
| `validate-baseline-size.js` | SubagentStop | Warns when agent deliverable is too large |
| `validate-agent-deliverable.js` | SubagentStop | Validates agent output completeness |
| `validate-quality-gates.js` | SubagentStop | Warns when gates have not been run |
| `validate-featuremap.js` | SubagentStop | Validates feature map coverage |
| `auto-register-artifact.js` | PostToolUse (Write\|Edit) | Registers written files as artifacts |
| `mid-flight-pattern-lint.js` | PostToolUse (Write\|Edit) | Lints code patterns mid-session |
| `validate-plan-gates.js` | PostToolUse (Write\|Edit) | Validates plan gate checkboxes |
| `auto-run-quality-gates.js` | PostToolUse (Write\|Edit) | Auto-runs quality gates after writes |
| `validate-checkpoint.js` | PostToolUse (Bash) | Validates checkpoint state after Bash |
| `session-start.js` | SessionStart | Initializes session state |
| `session-end.js` | SessionEnd | Persists session summary |
| `stop-guard.js` | Stop | Warns on unchecked plan items at session stop |
| `TeammateIdle.ps1` | TeammateIdle | Handles idle teammate notification |
| `TaskCompleted.ps1` | TaskCompleted | Handles task completion notification |
| `on-notification.js` | Notification | Handles notification events |
| `pre-compact.js` | PreCompact | Prepares handoff before context compaction |

### Security/Blocking Hooks (exit 2 to block, exit 0 to allow)

| Hook File | Event | Matcher | Blocks When |
|-----------|-------|---------|-------------|
| `pre-bash-validate.js` | PreToolUse | Bash | Dangerous shell commands (rm -rf /, fork bombs, etc.) |
| `pre-commit-validate.js` | PreToolUse | Bash | Git commits that fail quality criteria |
| `check-worktree.js` | PreToolUse | Bash | Worktree conflicts detected |
| `enforce-e2e-smoke.js` | PreToolUse | Bash | Commits missing E2E smoke test evidence |
| `pre-commit-tokens.js` | PreToolUse | Bash | Commits containing secret token patterns |
| `e2e-mock-check.js` | PreToolUse | Write\|Edit | Writing E2E tests with disallowed mocking patterns |
| `require-plan-approval.js` | PreToolUse | Write\|Edit | Writing files before plan is approved |
| `tdd-advisory.js` | PreToolUse | Write\|Edit | Advisory only — warns on source edits without test changes (exits 0) |
| `enforce-orchestration.js` | PreToolUse | Read | Main agent reading code files directly (orchestration violation) |
| `mcp-tier-redirect.js` | PreToolUse | mcp__* | MCP tool use on CLI-tier servers |
| `on-permission.js` | PermissionRequest | * | Permission requests that violate policy |

Note: `tdd-advisory.js` is listed under PreToolUse but is advisory by design — it exits 0 on all paths and only emits stderr warnings.

---

## JSON Output Note

`console.log(JSON.stringify({ hookSpecificOutput: { permissionDecision: 'deny', ... } }))` written to **stdout** is only meaningful for **PreToolUse** and **PermissionRequest** hooks. Claude Code reads this structured output to determine allow/deny/ask decisions for those specific event types.

For all other event types (UserPromptSubmit, PostToolUse, SubagentStop, SessionStart, SessionEnd, Stop, TeammateIdle, TaskCompleted, Notification, PreCompact), Claude Code **ignores stdout JSON entirely**. Advisory hooks should:

- Write user-facing warnings to **stderr** using `console.error()`
- Not write any JSON to stdout (it is ignored and wastes output)
- Exit 0 on all paths

Example — correct advisory output:

```javascript
// Correct: advisory hook warns via stderr
console.error('[detect-anomaly] WARNING: 12 agent spawns in the last hour');
process.exit(0);

// Wrong: advisory hook emits JSON to stdout (ignored by Claude Code)
console.log(JSON.stringify({ exit: 0, message: 'warning' }));  // never do this for advisory hooks
```

Example — correct blocking output for PreToolUse:

```javascript
// Correct: PreToolUse blocking hook uses stdout JSON + exit 0
console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'PreToolUse',
    permissionDecision: 'deny',
    permissionDecisionReason: 'Dangerous command blocked'
  }
}));
process.exit(0);  // exit 0 even when denying — the JSON payload carries the deny decision

// Also correct for hard-block (no JSON needed):
process.exit(2);  // Claude Code blocks the action on exit 2 without needing JSON
```

Both forms work for PreToolUse blocking — JSON payload with `permissionDecision: 'deny'` and exit 0, or bare exit 2. The JSON form gives a richer user message. The exit 2 form is simpler for catch handlers.
