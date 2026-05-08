---
description: List channels the current session is a member of. Pure read — no side effects.
allowed-tools: Bash
---

# /council-list

Arguments:
```
[--session-id <sess-id>] [--expand]
```

## Steps

1. Parse `$ARGUMENTS`.
2. Default `session-id` to today's `sess-<latest>-<yyyyMMdd>` — or prompt the user if ambiguous.
3. Invoke:

```bash
pwsh -NoProfile -Command "
  \$args = & '\${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1' -ArgumentsString '\$ARGUMENTS'
  \$params = @{ SessionId = \$args.named['session-id'] }
  if (\$args.flags -contains 'expand') { \$params['Expand'] = \$true }
  \$r = & '\${CLAUDE_PLUGIN_ROOT}/skills/council-list/council-list.ps1' @params
  \$r.report
"
```

4. Render the formatted `report` string verbatim — it's already human-readable.
