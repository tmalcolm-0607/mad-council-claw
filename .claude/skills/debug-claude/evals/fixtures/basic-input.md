# Fixture: basic input for /debug-claude (synthetic)

Synthetic input for the debug-claude skill. The skill diagnoses Claude Code session issues: hooks failing, MCP servers down, agent spawn failures, context corruption, slash-commands not registering.

## Synthetic input artifact

User report:
> "My PreToolUse hook is firing but seems to fail-open silently. Edits go through even when the hook should block. Also `/mad-spec` is failing with 'skill not found' but the file exists at `.claude/skills/mad-spec/SKILL.md`."

Environment:
- Claude Code CLI version: 1.x
- Platform: Windows + Git Bash
- Hooks: 14 registered

## Skill invocation

```
/debug-claude
```

## Notes

This fixture exercises the smart-default flow (collect signals → categorize → root-cause → propose fix). For mode-specific fixtures (--hooks, --mcp, --skills, --deep), add additional fixtures.
