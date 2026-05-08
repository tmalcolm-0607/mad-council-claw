#!/usr/bin/env node
/**
 * Hook: PreToolUse (mcp__*)
 * Purpose: Redirect CLI-tier MCP tools to CLI invocation
 *
 * Classifies MCP servers into "context-tier" (lightweight, frequent use)
 * vs "cli-tier" (heavyweight, infrequent). Acts as a call-time guard only --
 * does NOT suppress tool schema loading (schemas load at session start from
 * settings.json regardless of tier classification).
 *
 * Exit codes:
 *   0 - Allow (context-tier, unknown, or advisory mode for cli-tier)
 *   2 - Block (cli-tier with MCP_TIER_ENFORCE=true)
 *
 * Feature flag: MCP_TIER_ENFORCE (env variable)
 *   - unset or != "true": advisory mode (warn + exit 0)
 *   - "true": blocking mode (warn + exit 2)
 *
 * Reference: .claude/rules/mcp-tiering.md
 */

const fs = require('fs');
const path = require('path');

// Module-level cache for config (read once per session)
let cachedConfig = null;
let configLoadAttempted = false;

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString();
}

/**
 * Load and cache the MCP tiers configuration.
 * Returns null on any error (missing file, parse error, etc.)
 */
function loadConfig() {
  if (configLoadAttempted) return cachedConfig;
  configLoadAttempted = true;

  try {
    const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
    const configPath = path.join(projectDir, '.claude', 'mcp-tiers.json');
    const raw = fs.readFileSync(configPath, 'utf8');
    cachedConfig = JSON.parse(raw);
  } catch (err) {
    console.error(`[mcp-tier-redirect] Config load error: ${err.message}`);
    cachedConfig = null;
  }

  return cachedConfig;
}

/**
 * Extract server name from MCP tool name format.
 * Format: mcp__{server}__{method}
 * Returns null if format does not match.
 */
function extractServerName(toolName) {
  if (!toolName || typeof toolName !== 'string') return null;

  // Expected format: mcp__{server}__{method}
  const parts = toolName.split('__');
  if (parts.length < 3 || parts[0] !== 'mcp') return null;

  // Server name is the second segment
  return parts[1] || null;
}

/**
 * Check if a server is classified as CLI-tier.
 */
function isCliTier(config, serverName) {
  if (!config || !config.tiers || !config.tiers.cli) return false;
  const cliServers = config.tiers.cli.servers;
  if (!Array.isArray(cliServers)) return false;
  return cliServers.includes(serverName);
}

async function main() {
  try {
    const input = await readStdin();
    const data = JSON.parse(input);
    const toolName = data.tool_name || '';

    // Early exit: not an MCP tool
    if (!toolName.startsWith('mcp__')) {
      process.exit(0);
    }

    // Extract server name
    const serverName = extractServerName(toolName);
    if (!serverName) {
      // Malformed tool name - pass through silently
      process.exit(0);
    }

    // Load config (cached after first call)
    const config = loadConfig();
    if (!config) {
      // Config unavailable - pass through silently
      process.exit(0);
    }

    // Check if server is CLI-tier
    if (!isCliTier(config, serverName)) {
      // Context-tier or unknown - allow silently
      process.exit(0);
    }

    // Server is CLI-tier: build warning message from config
    const redirectMsg = (config.tiers.cli.redirect_message || '')
      .replace('{name}', serverName)
      .replace('{server}', serverName);

    const warning = `[MCP Tier] ${redirectMsg || `${serverName} is CLI-tier.`}`;

    // Check enforcement mode
    const enforce = process.env.MCP_TIER_ENFORCE === 'true';

    if (enforce) {
      // Blocking mode: exit 2
      console.error(warning);
      process.exit(2);
    } else {
      // Advisory mode: warn on stderr, exit 0
      console.error(warning);
      process.exit(0);
    }
  } catch (err) {
    // All errors exit 0 to avoid breaking workflows
    console.error(`[mcp-tier-redirect] Error: ${err.message}`);
    process.exit(0);
  }
}

main();
