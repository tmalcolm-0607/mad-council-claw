---
description: Join an existing MAD.Council channel. Reclaims disconnected aliases silently; --force-reclaim for active-alias conflicts.
allowed-tools: Bash
---

# /council-join

Arguments:
```
<channel-name> --alias <alias> [--session-id <sess-id>] [--poll <seconds>] [--force-reclaim] [--project <project>]
```

## Steps

1. Parse `$ARGUMENTS` via `${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1`.
2. Default `session-id` to `sess-<alias>-<yyyyMMdd>` if omitted.
3. Invoke:

```bash
pwsh -NoProfile -Command "
  \$args = & '\${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1' -ArgumentsString '\$ARGUMENTS'
  \$params = @{
    Name      = \$args.positional[0]
    Alias     = \$args.named['alias']
    SessionId = if (\$args.named['session-id']) { \$args.named['session-id'] } else { \"sess-\$(\$args.named['alias'])-\$(Get-Date -Format 'yyyyMMdd')\" }
  }
  if (\$args.named['poll']) { \$params['PollSeconds'] = [int]\$args.named['poll'] }
  if (\$args.named['project']) { \$params['Project'] = \$args.named['project'] }
  if (\$args.flags -contains 'force-reclaim') { \$params['ForceReclaim'] = \$true }
  & '\${CLAUDE_PLUGIN_ROOT}/skills/council-join/council-join.ps1' @params | ConvertTo-Json -Depth 4
"
```

4. Show the user: status, reclaim_case (A/B/C-force/D), channel, alias, message.

## Error handling

- `CHANNEL_NOT_FOUND` — the channel doesn't exist; run `/council-open` first.
- `ALIAS_ACTIVE_CONFLICT` — someone (or a prior session) holds this alias. Pass `--force-reclaim` to take it.
- `INVALID_ALIAS` — alias must be 1–64 chars, no leading/trailing whitespace.
