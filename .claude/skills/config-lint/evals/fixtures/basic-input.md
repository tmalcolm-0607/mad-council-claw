# Fixture: basic input for /config-lint (synthetic)

Synthetic input for the config-lint skill. The skill audits config files (`.claude/settings.json`, `.claude/settings.local.json`, `mcp.json`, hook configs) for schema, deprecated fields, and known-bad patterns.

## Synthetic input artifact

`.claude/settings.json` excerpt:
```json
{
  "hooks": {
    "PreToolUse": [
      { "decision": "deny", "reason": "..." }
    ]
  },
  "env": {
    "ANTHROPIC_API_KEY": "<secret>"
  }
}
```

Known-bad patterns to detect:
- Deprecated `decision`/`reason` (replaced by `hookSpecificOutput.permissionDecision`)
- `ANTHROPIC_API_KEY` in `env` block (overrides Max auth)

## Skill invocation

```
/config-lint
```

## Notes

This fixture exercises the smart-default flow (parse → match patterns → propose fixes). For mode-specific fixtures (--strict, --copilot), add additional fixtures.
