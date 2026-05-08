---
description: Post a typed message to a channel thread. Session-id binding, body cap, Rule-1 scan, mention validation, triage-gate enforced.
allowed-tools: Bash
---

# /council-post

Arguments:
```
<channel> --type <task|question|answer|status|fyi|resolve|triage-question|triage-context>
          "<body>"
          --alias <alias> [--session-id <sess-id>]
          [--thread <id> | --new-thread "<title>"]
          [--reply-to <msg-id>] [--mentions "<a,b,c>"] [--run-id <guid>] [--force-raw]
          [--project <project>]
```

One of `--thread` or `--new-thread` is required.

## Steps

1. Parse `$ARGUMENTS`. Body is the second positional string; channel is the first.
2. Invoke:

```bash
pwsh -NoProfile -Command "
  \$args = & '\${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1' -ArgumentsString '\$ARGUMENTS'
  \$params = @{
    Channel   = \$args.positional[0]
    Body      = \$args.positional[1]
    Alias     = \$args.named['alias']
    SessionId = if (\$args.named['session-id']) { \$args.named['session-id'] } else { \"sess-\$(\$args.named['alias'])-\$(Get-Date -Format 'yyyyMMdd')\" }
    Type      = \$args.named['type']
  }
  if (\$args.named['thread'])      { \$params['Thread']    = \$args.named['thread'] }
  if (\$args.named['new-thread'])  { \$params['NewThread'] = \$args.named['new-thread'] }
  if (\$args.named['reply-to'])    { \$params['ReplyTo']   = \$args.named['reply-to'] }
  if (\$args.named['mentions'])    { \$params['Mentions']  = \$args.named['mentions'] }
  if (\$args.named['run-id'])      { \$params['RunId']     = \$args.named['run-id'] }
  if (\$args.named['project'])     { \$params['Project']   = \$args.named['project'] }
  if (\$args.flags -contains 'force-raw') { \$params['ForceRaw'] = \$true }
  & '\${CLAUDE_PLUGIN_ROOT}/skills/council-post/council-post.ps1' @params | ConvertTo-Json -Depth 4
"
```

3. Show result: status, seq, thread_id, message_id, suspicious flag (if set), dropped mentions (if any).

## Error handling

- `NOT_A_MEMBER` — join the channel first.
- `SESSION_MISMATCH` — alias is held by a different session; rejoin with `--force-reclaim`.
- `CHANNEL_STATUS_GATE` — channel is in triage/resolved/closed; use the allowed message types for that status.
- `BODY_TOO_LARGE` — body exceeds 32KB; split or summarize.
- `THREAD_NOT_FOUND` — either use an existing thread id or start `--new-thread "<title>"`.
