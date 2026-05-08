# Coverage Oracle — config

What a *complete* config-change (settings.json, mcp.json, hook configs, package.json) must cover. Loaded for `config-change`.

## Required checks

| # | Check | What it verifies |
|---|-------|------------------|
| 1 | **Schema validity** | JSON parses; matches schema if one is registered |
| 2 | **No deprecated fields** | E.g. PreToolUse old `decision`/`reason` → use `hookSpecificOutput.permissionDecision` |
| 3 | **No secrets** | `ANTHROPIC_API_KEY` in env block, plaintext PATs, connection strings → BLOCKING |
| 4 | **Hook path resolution** | Every registered hook script path resolves on disk |
| 5 | **Permission scope** | New `allow:` entries narrowest necessary; flag `*` wildcards |
| 6 | **MCP server schema** | If `mcp.json` modified, server entries have valid `command`/`url`/`type` |
| 7 | **Backward compatibility** | Removed fields don't break existing skills/hooks that reference them |

## Severity per missing element

| Element | Missing severity |
|---------|------------------|
| 1 Schema validity | **BLOCKING** |
| 2 No deprecated fields | MUST-FIX |
| 3 **No secrets** | **BLOCKING** + treat as security incident |
| 4 Hook path resolution | **BLOCKING** (broken hooks fail-open silently) |
| 5 Permission scope | MUST-FIX (wildcards), SHOULD-FIX (overly-narrow) |
| 6 MCP server schema | **BLOCKING** if `mcp.json` modified |
| 7 Backward compatibility | MUST-FIX |

## Specific patterns to scan

| Pattern | Severity | Reason |
|---------|----------|--------|
| `ANTHROPIC_API_KEY` in env block | BLOCKING | Overrides Max/Pro auth (see CLAUDE.md note) |
| Deprecated PreToolUse `decision`/`reason` | MUST-FIX | Use `hookSpecificOutput.permissionDecision` |
| `disable-model-invocation` inside `allowed-tools` list | BLOCKING | Frontmatter parser breaks |
| `allowed-tools: *` without auditable exception | BLOCKING | Per `rules/dangerous-operations-policy.md` Least-privilege |
| Hard-coded credential literal | BLOCKING | Use Key Vault / managed identity |
| `--no-verify` / `--no-gpg-sign` in hooks | MUST-FIX | Bypasses safety gates |

## Cross-config consistency (when ≥2 config files in PR)

- settings.json + settings.local.json: env var precedence; flag if same key in both with different values
- mcp.json + settings.json: server enabled in mcp.json must have permission entry in settings.json
- Hook scripts referenced in settings.json must exist on disk

## Anti-hallucination

- Hook path resolution checked by `Test-Path`, not assumed
- Schema validity claim cites parser output, not just "looks fine"
- Secret patterns cited verbatim with file:line

## Cross-references

- `config-lint/SKILL.md` — uses this oracle
- `rules/non-negotiable-rules.md` — `.env` auto-loading + ANTHROPIC_API_KEY warning
