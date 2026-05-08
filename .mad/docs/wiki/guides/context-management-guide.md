# Context Management Guide

Strategies for managing context window capacity during long workflows.

## MCP Server Limits

| MCPs | Status |
|------|--------|
| 1-10 | Good |
| 11-15 | Acceptable |
| 16+ | Poor |

Use `disabledMcpServers` to filter per-project. Spawn agents for context-heavy work.

## Skill Context Isolation

Some skills use `context: fork` to prevent polluting the main conversation:

| Skill | Reason for Isolation |
|-------|----------------------|
| **mad-tasks** | Isolates 150KB+ template content from main conversation |
| **mad-validate** | Isolates 4 parallel lens outputs (prevents context pollution) |
| **pr-pattern-extract** | Isolates 150KB+ PR comment data from main conversation |

**When to use `context: fork`**:
- Large data processing (>100KB of input/output)
- Parallel operations with verbose output (multiple agent teams)
- Template expansion with extensive content
- Data aggregation from many sources

**How it works**:
- `context: fork` - Skill executes in isolated context (doesn't see/pollute main conversation)
- `context: inherit` (default) - Skill inherits full conversation history

## References

- `.claude/rules/context-guardian.md` - Threshold behaviors and handoff protocol
- `.claude/lib/context-metrics.js` - Sliding window token estimation
- `.claude/lib/handoff-generator.js` - Structured handoff document creation
