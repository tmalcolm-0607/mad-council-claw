---
category: claude-code-features
subcategory: context-management
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Context Management (2026)

## Overview

Most Claude Code best practices derive from one constraint: Claude's context window fills up fast, and performance degrades as it fills. 2026 introduced automatic compaction with manual override options, reducing need for aggressive manual management.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Auto compaction** | Claude automatically summarizes when approaching limits |
| **Manual control available** | Use `/compact <instructions>` for custom summarization |
| **Subagents for isolation** | Research in separate context, report summaries only |
| **Clear between tasks** | Use `/clear` to reset context for unrelated work |
| **Track usage** | Monitor context consumption with `/cost` command |

## Patterns (Current)

### Automatic Context Management

**Auto compaction** (2026 feature):
- Triggers when approaching context limits
- Summarizes important code and decisions
- Preserves workflow state
- No manual intervention required

**Manual controls**:
- `/clear` - Reset context entirely between unrelated tasks
- `/compact <instructions>` - Custom summarization with specific instructions
- `/cost` - View token usage breakdown in real-time

### Checkpointing and Rewind

**Automatic checkpoints**: Created before each Claude action

**Recovery options** (Double-tap Escape or `/rewind`):
- Restore conversation only
- Restore code only
- Restore both
- Summarize from selected message

**Persistent across sessions**: Close terminal, still can rewind later

**Warning**: Checkpoints track changes by Claude only, not external processes. Not replacement for git.

### Context Optimization Strategies

| Strategy | Purpose | When to Use |
|---------|---------|-------------|
| `/clear` | Reset context entirely | Between unrelated tasks |
| Subagents for investigation | Research in separate context | Complex analysis that may not be relevant |
| Track usage with `/cost` | Continuous monitoring | Long sessions |
| Aggressive management | Remove irrelevant context | Performance degradation observed |

### Subagents for Context Isolation

**Pattern**: Spawn subagent for context-heavy investigation
- Subagent reads files, analyzes patterns
- Reports concise summary back to main session
- Main session context stays clean

**Example**:
```markdown
User: "How does the auth system work?"

Main session spawns: code-investigator subagent
Subagent loads: 50+ auth-related files
Subagent returns: 200-line summary
Main session receives: Summary only (not 50 files)
```

### Context Rescaling and the Hidden Buffer

Claude Code reserves approximately **16.5% of the context window** for internal system overhead (compaction buffer). This means the effective usable capacity is ~167K tokens, not the full 200K.

**Why this matters**: All threshold calculations (ADVISORY at ~50%, PREPARE at ~70%, HALT at ~85%) are applied against **effective capacity**, not raw capacity. Thresholds fire earlier than a raw percentage would suggest.

Example -- if estimated usage is 142,000 tokens:
- Raw percentage: 142,000 / 200,000 = **71%** (appears as PREPARE)
- Effective percentage: 142,000 / 167,000 = **85%** (correctly fires HALT)

**Configuration**: The hidden buffer ratio is controlled by `CONTEXT_GUARDIAN_HIDDEN_BUFFER` (default: `0.165`):

```json
{
  "env": {
    "CONTEXT_GUARDIAN_HIDDEN_BUFFER": "0"
  }
}
```

Set to `0` to disable rescaling and revert to raw capacity calculations. Warning messages display both values: `~71% raw (~85% effective)` for transparency.

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Context management | Manual `/clear` only | Auto compaction + manual control | Rely on auto compaction, use `/compact <instructions>` for custom |
| Cost tracking | External tools | Built-in `/cost` command | Use `/cost` for real-time tracking |
| Checkpointing | Manual save points | Automatic before each action | Use Double-tap Escape or `/rewind` |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Ignoring context usage | Performance degradation | Track with `/cost`, use `/clear` between tasks |
| Long sessions without compaction | Irrelevant context reduces performance | Auto compaction handles this, or manual `/compact` |
| Over-explaining to Claude | Wastes tokens | Assume Claude knows standard concepts |
| Reading all files in main session | Context bloat | Use subagents for investigation |
| Skipping `/clear` between tasks | Context contamination | Always `/clear` for unrelated work |

## Examples

### Example 1: Context-Heavy Investigation

```markdown
# WRONG: Load all files in main session
User: "Analyze the entire auth system"
Claude reads: auth/*.ts (50 files, 10k lines)
Main context: Now full of auth details

# CORRECT: Use subagent for isolation
User: "Analyze the entire auth system"
Claude spawns: code-investigator subagent
Subagent reads: auth/*.ts (in separate context)
Subagent returns: Summary to main session
Main context: Clean, only has summary
```

### Example 2: Custom Compaction

```markdown
# When auto compaction isn't enough
User: "/compact Keep authentication decisions and DB schema, discard UI discussions"

Claude:
- Preserves auth decisions
- Preserves schema details
- Removes UI context
- Returns compacted summary
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Performance degrading | Check `/cost`, run `/compact` or `/clear` |
| Context full unexpectedly | Verify subagents used for heavy investigation |
| Auto compaction too aggressive | Use `/compact <instructions>` for custom control |
| Lost important decisions | Check `/rewind` for restoration |

## See Also

- `agents-orchestration-2026.md` - Subagents for context isolation
- `skills-2026.md` - Progressive disclosure patterns
- `token-optimization-2026.md` - Token usage optimization
- `prompting-2026.md` - Concise prompting patterns

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices
- https://code.claude.com/docs/en/checkpointing
- https://stevekinney.com/courses/ai-development/cost-management

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs)
**Frequency validation**: 100% (all patterns from official sources)
