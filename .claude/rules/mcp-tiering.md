# MCP Tiering

Classify MCP servers into tiers. CLI-tier acts as a call-time guard (warn or block) but does not suppress tool schema loading.

## Server Tiers

| Server | Tier | | Server | Tier |
|--------|------|-|--------|------|
| playwright | cli | | filesystem | cli |
| postgres | cli | | fetch | cli |
| github | cli | | sequential-thinking | cli |
| memory | cli | | | |

**Context-tier**: <5 tools, frequent use, loaded into context. Max 5 servers.
**CLI-tier**: >10 tools or infrequent. Invoke via Bash (`gh`, `curl`, built-in tools). (playwright is an exception -- no Bash CLI alternative exists; see playwright note below.)

Config: `.claude/mcp-tiers.json`. Feature flag: `MCP_TIER_ENFORCE` in `settings.local.json`.

**Note**: playwright remains enabled in settings.json for skills that require it (lrms-ux-audit, live-test, validate-html, ux-audit). CLI-tier is a **call-time guard only** -- it intercepts tool calls at runtime but does NOT suppress tool schema loading (schemas load at session start from settings.json). To suppress schema loading, a server must be removed from settings.json entirely. The CLI-tier classification warns on playwright tool calls (advisory) or blocks them (if `MCP_TIER_ENFORCE=true`), but playwright tool schemas are always present in context while the server is in settings.json. Activate playwright only during E2E/UI validation skills.
