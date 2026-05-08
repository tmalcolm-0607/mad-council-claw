---
description: Create a MAD.Council channel with single owner, environment tier, optional triage status.
allowed-tools: Bash
---

# /council-open

Arguments (from `$ARGUMENTS`):
```
<channel-name> "<purpose>" --tier <local|ci|prod> --alias <alias>
  [--session-id <sess-id>]
  [--triage]
  [--acceptance-criteria "<text>"]
  [--effort-estimate <hours>]
  [--project <project>]
```

## Steps

1. Parse `$ARGUMENTS` using `${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1`. Expected positional args: `name`, `purpose`. Expected named args: `tier`, `alias`, `session-id`, `acceptance-criteria`, `effort-estimate`, `project`. Expected flags: `triage`.
2. If `session-id` is not provided, auto-generate `sess-<alias>-<yyyyMMdd>` as a reasonable default (personal-use single-session pattern).
3. Invoke the skill via Bash:

```bash
pwsh -NoProfile -Command "
  \$args = & '\${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1' -ArgumentsString '\$ARGUMENTS'
  \$params = @{
    Name      = \$args.positional[0]
    Purpose   = \$args.positional[1]
    Tier      = \$args.named['tier']
    Alias     = \$args.named['alias']
    SessionId = if (\$args.named['session-id']) { \$args.named['session-id'] } else { \"sess-\$(\$args.named['alias'])-\$(Get-Date -Format 'yyyyMMdd')\" }
  }
  if (\$args.flags -contains 'triage') { \$params['Triage'] = \$true }
  foreach (\$k in 'acceptance-criteria','effort-estimate','project') {
    if (\$args.named.ContainsKey(\$k)) {
      \$pname = @{ 'acceptance-criteria'='AcceptanceCriteria'; 'effort-estimate'='EffortEstimate'; 'project'='Project' }[\$k]
      \$params[\$pname] = \$args.named[\$k]
    }
  }
  & '\${CLAUDE_PLUGIN_ROOT}/skills/council-open/council-open.ps1' @params | ConvertTo-Json -Depth 4
"
```

4. Display result to the user: status, channel, tier, owner, run_id, message.

## Error handling

The skill returns exit_code + error_code on failure. Common codes: `INVALID_CHANNEL_NAME`, `PROD_TRIAGE_REQUIRED`, `TRIAGE_MISSING_CRITERIA`, `CHANNEL_ALREADY_EXISTS`, `SUSPICIOUS_PURPOSE`, `OWNER_MUST_BE_CREATOR`, `PREFLIGHT_FAILED`. Present the error message verbatim to the user.
