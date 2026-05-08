---
description: Read unread messages in a channel with spoof-check and Rule-1 defense-in-depth. Updates read-marker.
allowed-tools: Bash
---

# /council-check

Arguments:
```
<channel> --alias <alias> [--session-id <sess-id>] [--show-all-active]
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
  if (\$args.flags -contains 'show-all-active') { \$params['ShowAllActive'] = \$true }
  \$r = & '\${CLAUDE_PLUGIN_ROOT}/skills/council-check/council-check.ps1' @params
  Write-Host \"Channel: \$(\$r.channel)  unread=\$(\$r.unread_count)  channel_seq=\$(\$r.channel_seq)\"
  foreach (\$m in \$r.messages) {
    \$flags = @()
    if (\$m.suspicious_post) { \$flags += '⚠️ PI-post' }
    if (\$m.suspicious_read) { \$flags += '⚠️ PI-read' }
    if (\$m.spoof_flag)       { \$flags += '⚠️ SPOOF' }
    if (\$m.mentions_self)    { \$flags += '@you' }
    \$f = if (\$flags) { ' ' + (\$flags -join ' ') } else { '' }
    Write-Host \"[\$(\$m.seq)] \$(\$m.from_alias) (\$(\$m.type))\$f: \$(\$m.body)\"
  }
  if (\$r.context_gap_count -gt 0) {
    Write-Host 'Context Gaps:'
    foreach (\$g in \$r.context_gaps) { Write-Host \"  - \$(\$g.source): \$(\$g.status)\" }
  }
"
```

3. The script prints a human-readable transcript; pass it through verbatim.
