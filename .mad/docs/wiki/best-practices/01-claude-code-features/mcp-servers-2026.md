---
category: claude-code-features
subcategory: mcp-servers
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# MCP Servers (2026)

## Overview

Model Context Protocol (MCP) server integration patterns for extending Claude Code with external tools, data sources, and services. Connect to Notion, Figma, databases, APIs, and custom business systems via `claude mcp add`.

**Key capability**: MCP servers expose tools as native Claude Code capabilities. Once connected, Claude can query databases, update tickets, analyze designs, and interact with external systems without API client boilerplate.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Minimal Server Count** | Target 1-10 servers (good), 11-15 (acceptable), 16+ (poor) |
| **Context Budget** | Each server adds to context consumption (metadata, schemas, examples) |
| **Tool Consolidation** | Group related tools in single server (avoid 1-tool-per-server) |
| **Error Handling** | Graceful degradation if server unavailable |
| **Version Pinning** | Lock server versions for stability |
| **Fully Qualified Names** | Always use `ServerName:tool_name` format to avoid "tool not found" errors |

## Patterns (Current)

### Server Configuration

**Installation** (via Claude Code CLI):
```bash
claude mcp add <server-name>
```

**Configuration file**: `.claude/mcp.json`
```json
{
  "mcpServers": {
    "BigQuery": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-bigquery"],
      "env": {
        "GCP_PROJECT_ID": "${GCP_PROJECT_ID}"
      }
    },
    "Notion": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-notion"],
      "env": {
        "NOTION_API_KEY": "${NOTION_API_KEY}"
      }
    }
  }
}
```

**Best practices**:
- Use environment variable substitution for secrets (never hardcode API keys)
- Pin server versions explicitly (e.g., `@modelcontextprotocol/server-notion@1.2.3`)
- Group servers by domain (data, design, project-management)

### Tool Discovery

**Fully qualified tool names** (REQUIRED):
```
ServerName:tool_name
```

**Example** (BigQuery server):
```
BigQuery:bigquery_schema
BigQuery:bigquery_query
BigQuery:bigquery_export
```

**Why fully qualified names**:
- Avoids conflicts (multiple servers with `query` tool)
- Explicit about which server handles request
- Prevents "tool not found" errors

**Tool listing**:
Claude automatically discovers tools from connected servers. Use `/mcp list` to see available tools.

### Context Management

**Context impact per server**:
- Server metadata: ~50-200 tokens (name, description, version)
- Tool schemas: ~100-300 tokens per tool (parameters, descriptions)
- Examples/documentation: ~500-1000 tokens per server (if included)

**Total context budget**:
| Server Count | Estimated Context Usage | Assessment |
|--------------|------------------------|------------|
| 1-5 servers | ~2-5k tokens | Minimal impact |
| 6-10 servers | ~5-10k tokens | Acceptable |
| 11-15 servers | ~10-15k tokens | Acceptable but monitor |
| 16+ servers | 15k+ tokens | Poor - spawn agents for context-heavy work |

**Mitigation strategies**:
- Disable servers not needed for current work (`claude mcp disable <server>`)
- Use subagents for MCP-heavy operations (isolates context)
- Consolidate tools into fewer, domain-specific servers

## Two-Tier MCP Configuration

MCP servers expose tool schemas that are loaded into the context window. Each server adds its full tool schema regardless of whether those tools are used. For heavyweight servers, this wastes significant context capacity.

The **two-tier model** classifies servers to minimize context consumption:

| Tier | Description | Load Strategy |
|------|-------------|---------------|
| **Context-tier** | Lightweight schemas, used frequently | Loaded into context -- tools callable directly |
| **CLI-tier** | Heavyweight schemas, specialized use | NOT loaded -- invoke via Bash/CLI instead |

**Configuration file**: `.claude/mcp-tiers.json`

### Current Tier Assignments

| Server | Tier | Rationale |
|--------|------|-----------|
| `playwright` | Context | Lightweight schema, used in E2E testing sessions |
| `postgres` | CLI | Database queries are heavyweight, better via CLI |
| `github` | CLI | Heavy API surface; prefer `gh` CLI |
| `memory` | CLI | File operations; prefer built-in Read/Write/Edit |
| `filesystem` | CLI | File operations; prefer built-in Read/Write/Edit |
| `fetch` | CLI | HTTP requests; use `curl` via Bash |
| `sequential-thinking` | CLI | Specialized use case, not frequently needed |

**Rule of thumb**: If you'd use it in every session -> context-tier. Otherwise -> cli-tier. Keep context-tier servers <= 5.

### Feature Flag: `MCP_TIER_ENFORCE`

| Value | Behavior |
|-------|----------|
| Unset (default) | Advisory mode -- warning on stderr, tool still executes |
| `"true"` | Blocking mode -- warning on stderr, CLI-tier tool blocked (exit 2) |

```json
{
  "env": {
    "MCP_TIER_ENFORCE": "true"
  }
}
```

### CLI Alternatives for CLI-Tier Servers

| Server | CLI Alternative |
|--------|----------------|
| `postgres` | `npx -y @anthropic-ai/mcp-server-postgres "$POSTGRES_URL"` |
| `github` | `gh api repos/{owner}/{repo}/...` (prefer `gh` CLI) |
| `memory` | Use built-in Read/Write/Edit tools instead |
| `filesystem` | Use built-in Read/Write/Edit tools instead |
| `fetch` | `curl -s URL \| jq '.'` via Bash |
| `sequential-thinking` | `npx -y @anthropic-ai/mcp-server-sequential-thinking` |

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Tool references | Ambiguous names accepted | **Must use `ServerName:tool_name`** | Update all tool calls to fully qualified format |
| Server installation | Manual setup | `claude mcp add <server>` CLI | Use CLI for standardized setup |
| Context awareness | Not tracked | Explicit context budgeting (1-10 good, 16+ poor) | Monitor server count, disable unused |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Ambiguous tool names (`query` instead of `BigQuery:query`) | "Tool not found" errors | Always use fully qualified `ServerName:tool_name` |
| Too many servers (20+) | Context bloat, degraded performance | Keep to 1-10 servers, disable unused |
| Hardcoded API keys in config | Security risk | Use environment variable substitution |
| One tool per server | Server overhead multiplies | Consolidate related tools into single server |
| No version pinning | Breaking changes on updates | Pin server versions explicitly |
| Ignoring server failures | Silent failures, incomplete results | Check server health, log errors, graceful degradation |

## Examples

### Example 1: MCP Server Setup (BigQuery)

**Install**:
```bash
claude mcp add bigquery
```

**Configure** (`.claude/mcp.json`):
```json
{
  "mcpServers": {
    "BigQuery": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-bigquery@1.0.0"],
      "env": {
        "GCP_PROJECT_ID": "${GCP_PROJECT_ID}"
      }
    }
  }
}
```

**Usage** (fully qualified tool name):
```
User: "Show me schema for the analytics.revenue table"

Claude calls: BigQuery:bigquery_schema
Parameters: { dataset: "analytics", table: "revenue" }
```

### Example 2: Custom MCP Server (JIRA Integration)

**Custom server** (`.mcp-servers/jira/index.js`):
```javascript
#!/usr/bin/env node
const { Server } = require('@modelcontextprotocol/sdk/server');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio');

const server = new Server({
  name: 'JIRA',
  version: '1.0.0'
}, {
  capabilities: {
    tools: {}
  }
});

server.setRequestHandler('tools/list', async () => ({
  tools: [
    {
      name: 'jira_search',
      description: 'Search JIRA issues by JQL',
      inputSchema: {
        type: 'object',
        properties: {
          jql: { type: 'string' }
        }
      }
    }
  ]
}));

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'jira_search') {
    const response = await fetch(`${process.env.JIRA_URL}/rest/api/2/search`, {
      headers: { 'Authorization': `Bearer ${process.env.JIRA_TOKEN}` },
      body: JSON.stringify({ jql: args.jql })
    });
    return await response.json();
  }
});

const transport = new StdioServerTransport();
server.connect(transport);
```

**Configuration**:
```json
{
  "mcpServers": {
    "JIRA": {
      "command": "node",
      "args": [".mcp-servers/jira/index.js"],
      "env": {
        "JIRA_URL": "${JIRA_URL}",
        "JIRA_TOKEN": "${JIRA_TOKEN}"
      }
    }
  }
}
```

**Usage**:
```
User: "Find all open bugs assigned to me"

Claude calls: JIRA:jira_search
Parameters: { jql: "assignee = currentUser() AND status = Open AND type = Bug" }
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Tool not found" error | Use fully qualified name: `ServerName:tool_name` |
| Server not starting | Check logs (`.claude/logs/mcp/`), verify environment variables set |
| Context bloat (>15 servers) | Disable unused servers: `claude mcp disable <server>` |
| API rate limiting | Implement caching in custom server, add retry logic |
| Version conflicts | Pin server versions explicitly in `mcp.json` |

## See Also

- `context-management-2026.md` - Context budgeting with MCP
- `.claude/docs/context-management-guide.md` - MCP threshold guidance (1-10 good, 16+ poor)
- `agents-orchestration-2026.md` - Using subagents for MCP-heavy operations

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/mcp-servers (official MCP integration guide)
- `.claude/docs/context-management-guide.md` (MCP server thresholds)
- DHSTSP codebase `.claude/mcp.json` (production configuration)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + production use)
**Frequency validation**: 100% (fully qualified names pattern from official docs)
