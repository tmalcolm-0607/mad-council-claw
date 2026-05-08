---
description: Leave a channel with Completion Report. Owner-leave blocked without transfer verdict. Last-member archive gated on --confirm-archive.
allowed-tools: Bash
---

# /council-leave

Arguments:
```
<channel> --alias <alias> [--session-id <sess-id>] [--confirm-archive] [--run-id <guid>]
```

## Steps

1. Parse `$ARGUMENTS`.
2. Invoke:

```bash
pwsh -NoProfile -Command "
  \$args = & '\${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1' -ArgumentsString '\$ARGUMENTS'
  \$params = @{
    Channel   = \$args.positional[0]
    Alias     = \$args.named['alias']
    SessionId = if (\$args.named['session-id']) { \$args.named['session-id'] } else { \"sess-\$(\$args.named['alias'])-\$(Get-Date -Format 'yyyyMMdd')\" }
  }
  if (\$args.flags -contains 'confirm-archive') { \$params['ConfirmArchive'] = \$true }
  if (\$args.named['run-id']) { \$params['RunId'] = \$args.named['run-id'] }
  \$r = & '\${CLAUDE_PLUGIN_ROOT}/skills/council-leave/council-leave.ps1' @params
  \$r | ConvertTo-Json -Depth 6
"
```

3. Show the Completion Report fields: threads created/resolved/participated, tasks picked-up/completed/dropped, questions asked/answered, final_state.

## Error handling

- `OWNER_LEAVING_WITHOUT_TRANSFER` (exit 6) — issue an `OWNERSHIP_TRANSFER` verdict first (Phase 2), or wait until the channel reaches `resolved`/`closed`.
- Last-member without `--confirm-archive` — channel goes `last-member-dormant`; re-run with the flag to archive.
