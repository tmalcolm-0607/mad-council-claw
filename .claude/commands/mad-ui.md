---
description: Launch the MAD.Council local UI — channels, threads, metrics, and help in the browser.
allowed-tools: Bash
---

# /mad-ui

Arguments (from `$ARGUMENTS`):
```
[--port <int>] [--no-browser] [--bind-all]
```

Defaults: port 9292, browser auto-opens, bound to 127.0.0.1 only.

## Steps

1. Parse `$ARGUMENTS` using `${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1`. Expected named: `port`. Expected flags: `no-browser`, `bind-all`.
2. Invoke the launcher:

```bash
pwsh -NoProfile -Command "
  \$args = & '\${CLAUDE_PLUGIN_ROOT}/bootstrap/Parse-SlashArgs.ps1' -ArgumentsString '\$ARGUMENTS'
  \$params = @{}
  if (\$args.named.ContainsKey('port')) { \$params['Port'] = [int]\$args.named['port'] }
  if (\$args.flags -contains 'no-browser') { \$params['NoBrowser'] = \$true }
  if (\$args.flags -contains 'bind-all')   { \$params['BindAll']   = \$true }
  & '\${CLAUDE_PLUGIN_ROOT}/ui/mad-ui.ps1' @params
"
```

3. The launcher blocks in the foreground until Ctrl+C. On Windows, `Start-Process` opens the default browser; on macOS, `open`; on Linux, `xdg-open`.

## Safety

Binding to all interfaces (`--bind-all`) is blocked by the server unless the caller sets `$env:MAD_UI_ALLOW_BIND_ALL='yes'`. This is intentional — the UI is read-only but channel content may include sensitive notes.

## Error handling

- **`Address already in use`** — pass `--port <free-port>` or kill the process on the current port.
- **Browser doesn't open** — the launcher prints the URL; open it manually.
- **`server.ps1 not found`** — the plugin tree is out of sync with the `MAD/` source. Re-run `${CLAUDE_PLUGIN_ROOT}/bootstrap/sync-from-mad.ps1`.
