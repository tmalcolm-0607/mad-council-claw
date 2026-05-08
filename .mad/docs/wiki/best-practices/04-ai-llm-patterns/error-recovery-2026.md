---
category: ai-llm-patterns
subcategory: error-recovery
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Error Recovery (2026)

## Overview

Error handling, retry logic, graceful degradation, and failure recovery patterns for AI-assisted workflows.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **No Brute Force** | Don't retry same action repeatedly - find alternative |
| **Checkpointing** | Automatic before each action - restore if needed |
| **Course Correction** | Stop mid-action, rewind, or start fresh |
| **Alternative Approaches** | Find different path if blocked |
| **User Escalation** | Ask user if truly stuck after 2 corrections |

## Patterns (Current)

### Checkpointing and Rewind

**From official docs** (code.claude.com/docs/en/checkpointing):

**Automatic checkpoints**: Created before each Claude action

**Recovery options** (Double-tap Escape or `/rewind`):
- Restore conversation only
- Restore code only
- Restore both
- Summarize from selected message

**Persistent across sessions**: Close terminal, still can rewind later

**Warning**: Checkpoints track changes by Claude only, not external processes. Not a replacement for git.

**Use cases**:
- Claude made wrong changes → `/rewind` + restore code
- Conversation went off track → `/rewind` + restore conversation
- Want to try different approach → `/rewind` + give new instructions

### Course Correction Patterns

**From best practices docs**:

| Action | Purpose | When to Use |
|--------|---------|-------------|
| `Esc` | Stop mid-action, context preserved | Claude heading wrong direction |
| `Esc + Esc` or `/rewind` | Restore previous state | Undo recent actions |
| "Undo that" | Have Claude revert changes | Specific change to undo |
| `/clear` | Reset context after failed corrections | 2+ corrections failed on same issue |

**Key insight**: "If you've corrected Claude more than twice on same issue in one session, context is cluttered with failed approaches. Run `/clear` and start fresh with better prompt."

### Retry Strategies

**From project anti-patterns** (CLAUDE.md):

**FORBIDDEN**: "If approach is blocked, do not attempt to brute force your way to the outcome. For example, if an API call or test fails, do not wait and retry the same action repeatedly."

**Correct approach**:
1. Analyze why blocked (read error message, check logs)
2. Consider alternative approaches
3. If API/test failed: investigate root cause, fix underlying issue
4. If truly stuck: use AskUserQuestion to align on path forward

**Retry only when**:
- Transient network error (with exponential backoff)
- Race condition (with delay)
- Known flaky test (with `[Retry]` attribute)

**Do NOT retry when**:
- Logic error (fix code instead)
- Missing dependency (install it)
- Configuration issue (fix config)
- Test failure (investigate and fix)

### Graceful Degradation

**From project patterns**:

| Scenario | Degradation Path |
|----------|------------------|
| Agent team creation fails | Fall back to sequential subagents |
| Context threshold reached | Generate handoff, start new session |
| Quality gate fails | Fix immediately, do not skip |
| Background agent hangs | Proceed if artifact exists on disk |
| Web search unavailable | Use cached knowledge, note limitation |

### Failure Recovery

**From `.claude/learning/failures.json` and project patterns**:

**Failure logging**:
- All anomalies logged to `.claude/learning/failures.json`
- Hooks track patterns: consecutive failures, rapid prompts, overplanning
- Used for pattern learning and anti-pattern detection

**Recovery protocol**:
1. **Detect failure** - hook or manual observation
2. **Log to failures.json** - fingerprint, timestamp, context
3. **Determine cause** - read error, check logs, verify assumptions
4. **Choose recovery**:
   - Fix underlying issue (preferred)
   - Alternative approach
   - Graceful degradation
   - User escalation
5. **Verify fix** - run quality gates, check expected outcome
6. **Update patterns** - if novel failure, update anti-patterns

**Cooldown mechanism**: Duplicate anomaly fingerprints suppressed within 5-minute window (configurable via `anomaly_cooldown_seconds`)

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Checkpointing | Manual save points | Automatic before each action | Use `/rewind` instead of manual undo |
| Rewind UI | Manual restoration | Interactive menu (restore conversation/code/both) | Double-tap Escape or `/rewind` |
| Context reset | `/clear` only | `/clear` or `/compact <instructions>` | Use `/compact` to preserve relevant context |
| Failure tracking | Manual notes | Automated logging to `.claude/learning/failures.json` | Review failures.json for patterns |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Retry same action repeatedly | Wastes time, doesn't fix root cause | Analyze why blocked, try alternative |
| Ignoring error messages | Missing obvious solution | Read error carefully, check logs |
| 3+ corrections on same issue | Context cluttered with failed attempts | `/clear` and start fresh with better prompt |
| No checkpoints before risky action | Hard to recover if wrong | Automatic, but verify `/rewind` works |
| Skipping quality gates after fix | Regression undetected | Always run gates after fix |

## Examples

### Example 1: Rewind After Wrong Changes

**Scenario**: Claude modified wrong file

**Recovery**:
```
1. Double-tap Escape (or type `/rewind`)
2. Select "Restore code only"
3. Give corrected instruction: "Modify src/auth/TokenService.cs, not src/auth/AuthController.cs"
```

**Result**: Code restored to pre-mistake state, conversation preserved, Claude tries again

### Example 2: Course Correction After Multiple Failures

**Scenario**: Corrected Claude 3 times on test implementation, still wrong

**Ineffective**:
```
Try correcting again → context full of failed attempts → Claude confused
```

**Effective**:
```
1. `/clear` (reset context)
2. Read test examples yourself
3. Give specific prompt with pattern reference:
   "Write test for TokenService.RefreshAsync following pattern in AuthServiceTests.cs:
    - Use builder pattern for test data
    - Verify Result<T> success/failure
    - No mocking of Marten IDocumentSession
    Max 50 lines."
```

**Result**: Fresh context, specific instructions, pattern reference → success

### Example 3: Graceful Degradation (Agent Team Failure)

**Scenario**: TeamCreate fails (experimental feature unavailable)

**Recovery**:
```javascript
// Automatic fallback in skill code
try {
  TeamCreate({ ... })
} catch (error) {
  log("Team creation failed, falling back to sequential subagents")

  // Execute same tasks sequentially
  for (const task of tasks) {
    Task({ subagent_type: "...", prompt: task.prompt })
  }
}
```

**Result**: Work continues, no user intervention needed, unchanged behavior

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Claude made wrong changes | `/rewind` → Restore code → Give corrected instruction |
| Conversation cluttered after 2+ corrections | `/clear` and restart with better prompt |
| Test keeps failing | Don't retry - investigate root cause, read error, check assumptions |
| Agent hangs | If artifact exists on disk, proceed; otherwise kill and retry with timeout |
| Quality gate fails | Fix immediately, run gates again, never skip |
| Context too full to recover | Generate handoff (`.claude/work-items/{WI-ID}/`), start new session |

## See Also

- `.claude/learning/failures.json` - Failure pattern tracking
- `.claude/rules/context-guardian.md` - Context threshold recovery
- `.claude/rules/quality-gates.md` - Gate failure protocol
- `.claude/hooks/detect-anomaly.js` - Automated failure detection

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/checkpointing (Tier 1 - Official)
- https://code.claude.com/docs/en/best-practices (Tier 1 - Official)
- `.claude/learning/failures.json` (Local pattern tracking)
- `CLAUDE.md` Anti-Patterns section (Local pattern)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + local patterns)
**Frequency validation**: 90%+ (checkpointing in official docs, anti-patterns in project patterns)
