# MAD Harness

Reference configuration for installing the MAD kit into a host project's `.claude/` directory.

## What this is

`settings.json` wires hooks, MCP servers, and permissions into Claude Code. Without this file, the hooks under `MAD/hooks/` are inert — they exist as scripts but nothing dispatches them.

`agent-teams-config.json` configures multi-teammate parallel dispatch (experimental agent-teams feature).

`mcp-tiers.json` sets MCP server context-tiers to avoid the 30K-tool-schema context bloat when many servers are attached.

## How to install

Copy into your project's `.claude/` directory:

```bash
cp MAD/harness/settings.json          <project>/.claude/settings.json
cp MAD/harness/agent-teams-config.json <project>/.claude/agent-teams-config.json
cp MAD/harness/mcp-tiers.json         <project>/.claude/mcp-tiers.json
```

Then copy the hooks, agents, skills, and rules the harness references:

```bash
cp -r MAD/hooks    <project>/.claude/hooks/
cp -r MAD/agents/workflow <project>/.claude/agents/
cp -r MAD/skills/workflow <project>/.claude/skills/
cp -r MAD/rules    <project>/.claude/rules/
cp -r MAD/templates <project>/.mad/templates/
cp -r MAD/scripts  <project>/.claude/scripts/
```

## Validating

Run `scripts/ported/validate-config.js` after install to verify:

```bash
node MAD/scripts/ported/validate-config.js <project>/.claude/settings.json
```

## Layered-config override

Per-user preferences live in `<project>/.claude/settings.local.json` and are auto-gitignored by Claude Code. The harness settings.json provides defaults; settings.local.json overrides them.

Similarly, `<project>/CLAUDE.local.md` holds per-project personal preferences that never get committed.

## Minimal install (just rules + templates)

If you don't want the full harness, copy only:

```bash
cp -r MAD/rules    <project>/.claude/rules/
cp -r MAD/templates <project>/.mad/templates/
```

The rules are advisory (no hook enforcement) but still usable as guidance.
