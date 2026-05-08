# MCP Tiering in the Orchestration Workflow

How MCP server classification integrates with the MAD workflow and orchestration phases.

---

## Overview

MCP (Model Context Protocol) servers are classified into two tiers to prevent unused tool schemas from consuming context tokens. This guide documents how the tiering system integrates with the orchestration workflow defined in `CLAUDE.md`.

For the full tiering rule (server assignments, CLI alternatives, hook behavior), see `.claude/rules/mcp-tiering.md`.

---

## Integration with Orchestration

### Context Budget Impact

Each context-tier MCP server adds its full tool schema to the context window. The Context Guardian system (`.claude/rules/context-guardian.md`) monitors overall context usage, but MCP schemas are loaded before any work begins. Keeping context-tier servers minimal preserves budget for actual work.

| Context-Tier Servers | Estimated Schema Overhead | Impact on Context Budget |
|----------------------|--------------------------|--------------------------|
| 1-3 servers | ~2-5% of capacity | Minimal |
| 4-5 servers | ~5-10% of capacity | Acceptable |
| 6+ servers | >10% of capacity | Excessive -- reclassify to CLI-tier |

### When to Consider Tiering

- **Session start**: Context-tier servers are loaded automatically. If you notice high baseline context usage, check MCP server count.
- **ADVISORY threshold (50%)**: Review whether all context-tier servers are actively used. Reclassify unused ones to CLI-tier.
- **PREPARE threshold (70%)**: Do NOT add new context-tier servers. Use CLI alternatives exclusively.

---

## Orchestration Phase Guidelines

| Phase | MCP Consideration |
|-------|-------------------|
| Setup | Verify context-tier server count is within limits (max 5) |
| Investigate | Use context-tier tools directly; CLI-tier via Bash |
| Implement | Prefer built-in tools (Read/Write/Edit) over MCP filesystem |
| Review | No MCP-specific considerations |
| Validate | Database queries via CLI (`gh`, `psql`) not context-tier |

---

## Configuration

### Tier Definitions

Configuration lives in `.claude/mcp-tiers.json`. See `.claude/rules/mcp-tiering.md` for the full schema.

### Feature Flag: MCP_TIER_ENFORCE

| Value | Behavior |
|-------|----------|
| unset (default) | Advisory mode: warning on stderr, tool still executes |
| `"true"` | Blocking mode: warning on stderr, tool execution blocked (exit 2) |

Set in `.claude/settings.local.json`:

```json
{
  "env": {
    "MCP_TIER_ENFORCE": "true"
  }
}
```

### Hook

The `mcp-tier-redirect.js` PreToolUse hook intercepts MCP tool calls and redirects CLI-tier tools. See `.claude/hooks/mcp-tier-redirect.js` for implementation details.

---

## Current Server Assignments

| Server | Tier | Rationale |
|--------|------|-----------|
| playwright | context | Frequently used during E2E testing, lightweight schema |
| postgres | cli | Database queries are heavyweight, better via CLI |
| github | cli | API calls are heavyweight, use `gh` CLI instead |
| memory | cli | File operations are heavyweight, better via CLI |
| filesystem | cli | Use built-in Read/Write/Edit tools instead |
| fetch | cli | Use `curl` via Bash instead |
| sequential-thinking | cli | Specialized use case, not frequently needed |

---

## Adding New MCP Servers

When adding a new MCP server to the project:

1. **Default to CLI-tier** unless it meets all context-tier criteria
2. **Update `.claude/mcp-tiers.json`** with the new server assignment
3. **Document CLI alternative** in `.claude/rules/mcp-tiering.md`
4. **Verify context-tier count** stays under `max_servers` (default: 5)

### Context-Tier Criteria (all must be met)

- Lightweight schema (<5 tools)
- Frequently used (expected in most sessions)
- Low latency operations
- Total context-tier servers remain under limit

---

## Cross-References

| Resource | Description |
|----------|-------------|
| `.claude/rules/mcp-tiering.md` | Full tiering rule with server assignments and CLI alternatives |
| `.claude/mcp-tiers.json` | Tier configuration file |
| `.claude/hooks/mcp-tier-redirect.js` | PreToolUse hook for tier enforcement |
| `.claude/rules/context-guardian.md` | Context budget management |
| `.claude/docs/context-management-guide.md` | General context management guidance |
| `CLAUDE.md` "Context Management" section | MCP server count guidance (1-10 good, 11-15 acceptable, 16+ poor) |
