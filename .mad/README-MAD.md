# mad-council — personal install notes

File-based multi-agent coordination primitive. Six slash commands over `~/claude-data/`. Schema-validated state, session-id spoofing defense, atomic writes. Full design lives in `../../MAD/mad.council.a2a.md`.

**This README is my own reinstall reference, not a pitch. If you're me on a new laptop, start here.**

---

## Prerequisites

- PowerShell 7.4+ (`pwsh --version`)
- Pester 5.5+ (optional, for running the test suite)
- `~/claude-data/` directory will be created on first `/council-open`

## Install

From the repo root:

```powershell
# Keep plugin content in sync with the MAD/ source of truth
pwsh plugins/mad-council/bootstrap/sync-from-mad.ps1
```

Then enable the plugin in Claude Code via the marketplace mechanism (same pattern as other `plugins/*` in this repo).

## Quickstart

```text
/council-open my-channel "testing the install" --tier local --alias me
/council-post my-channel --new-thread hello --type fyi "hello"
/council-check my-channel
/council-list
/council-leave my-channel
/mad-ui                          # read-only browser view of everything
```

## Launch the UI

```text
/mad-ui                          # port 9292, opens browser
/mad-ui --port 9393              # different port
/mad-ui --no-browser             # just start the server
```

Bound to `127.0.0.1` only. Channels, threads, messages, verdicts, metrics, and the full help catalog (skills + schemas + rules) render locally. Read-only — the UI never writes. Ctrl+C in the launcher terminal stops the server.

## What's in the box

| Slash command | Skill body | What it does |
|---|---|---|
| `/council-open` | `skills/council-open/council-open.ps1` | Create a channel, own it, optionally open at triage status. |
| `/council-join` | `skills/council-join/council-join.ps1` | Join an existing channel; silent-reclaim disconnected aliases; `-ForceReclaim` for active conflicts. |
| `/council-post` | `skills/council-post/council-post.ps1` | Post typed message; session-id binding; body size + Rule-1 scan; mention validation; seq increment; digest rebuild. |
| `/council-check` | `skills/council-check/council-check.ps1` | Read unreads; post-read spoof check; Rule-1 defense-in-depth; priority sort. |
| `/council-list` | `skills/council-list/council-list.ps1` | List this session's channels with tier badge, unread count, MAD phase. |
| `/council-leave` | `skills/council-leave/council-leave.ps1` | Emit Completion Report; owner-leave blocked without transfer; last-member `-ConfirmArchive` gate. |
| `/mad-ui` | `ui/mad-ui.ps1` | Launch the local read-only UI (server + auto-open browser). |

All seven run via `${CLAUDE_PLUGIN_ROOT}/...` — see `commands/*.md`.

## How it's assembled

This plugin is a **fat copy** of MAD kit content. `bootstrap/sync-from-mad.ps1` syncs:

- `MAD/skills/council-*` → `plugins/mad-council/skills/council-*` (real Phase-1 skills only; excludes the `workflow/` subtree)
- `MAD/scripts/*.ps1` + `*.Tests.ps1` → `plugins/mad-council/scripts/`
- `MAD/schemas/*.schema.json` → `plugins/mad-council/schemas/`
- `MAD/rules/*.md` → `plugins/mad-council/rules/` (runtime reference for agents)
- `MAD/ui/*.ps1` + `MAD/ui/web/**` → `plugins/mad-council/ui/` (server + launcher + HTML/CSS assets)

Run the sync script after any change to MAD/. The plugin directory is committed to git; diffs will show when the sync is stale.

## Troubleshooting

- **`${CLAUDE_PLUGIN_ROOT}` doesn't expand** → you're running the `.ps1` directly, not via the slash command. Use `pwsh MAD/skills/council-open/council-open.ps1 -Name … -Alias … -SessionId …`.
- **`pwsh: command not found`** → install PowerShell 7 from https://aka.ms/PSWindows or `brew install powershell` on macOS.
- **Session-id mismatch** → Claude Code started a new session; the channel has an old one. Use `/council-join <name> -ForceReclaim` to reclaim your alias.
- **`/plugin` doesn't list mad-council** → run `sync-from-mad.ps1` first; the plugin entry depends on `.claude-plugin/plugin.json` existing.

## State location (machine-local)

```
~/claude-data/
├── channels/<name>/{channel,seq,digest}.json + threads/ + read-markers/
├── archive/<yyyy-mm-dd>-<name>/        # last-member archives
└── .sessions.json                       # session-bound membership registry
```

Back up with `MAD/scripts/backup-channels.ps1 -Dest D:\backups`. Restore is a plain file copy + rebuild digest per `operations/backup-disaster-recovery.md`.

## Related

- `../../MAD/mad.council.a2a.md` — full spec.
- `../../MAD/plans/phase-1b-polish-package-dogfood.md` — the plan that produced this plugin.
- `../../MAD/operations/sandbox-testing.md` — Docker sandbox for running tests in a container.
