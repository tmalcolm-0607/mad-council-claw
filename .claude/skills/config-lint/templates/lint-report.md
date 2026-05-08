# Template — config-lint report

Canonical shape for `/config-lint` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Config Lint — <ISO date>

**Files audited**:
- `.claude/settings.json`
- `.claude/settings.local.json`
- `mcp.json`

## Summary

| Severity | Count |
|----------|-------|
| BLOCKING | 1 |
| MUST-FIX | 2 |
| SHOULD-FIX | 0 |

## Findings

### [BLOCKING] settings.local.json:env.ANTHROPIC_API_KEY

Evidence:
```json
"env": {
  "ANTHROPIC_API_KEY": "<secret>"
}
```

Rule: Auth-override class — `ANTHROPIC_API_KEY` in `env` block overrides Claude Code Max/Pro auth.
Confidence: 0.92
Suggested fix: remove from env; rely on `claude` CLI's auth state. If you must keep an API key, store it in `.env` only (still risky — see CLAUDE.md note) and never commit it.

### [MUST-FIX] settings.json:hooks.PreToolUse[0]

Evidence:
```json
{ "decision": "deny", "reason": "..." }
```

Rule: Deprecated hook output format. New format is `hookSpecificOutput.permissionDecision`.
Confidence: 0.88
Suggested fix:
```json
{ "hookSpecificOutput": { "hookEventName": "PreToolUse", "permissionDecision": "deny" } }
```

## Anti-hallucination

- Every cited line was Read from the source file (FETCH BEFORE CITE)
- Categories with no findings stated explicitly

## Verdict

REJECT — BLOCKING auth issue; remediate before continuing session.
```

## Reference

- `rules/non-negotiable-rules.md` — the "no ANTHROPIC_API_KEY in env" entry
