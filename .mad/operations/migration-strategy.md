# Migration Strategy — v1 → v2 and beyond

How existing MAD.Council channel state migrates when the spec evolves. The kit will eventually ship a `mad.council.a2a.md` v2; this document says how we stay safe for users with live channels on v1 when that happens.

## Versioning scheme

Three version identifiers coexist and serve different purposes:

| Identifier | Format | Source of truth | Changes on |
|---|---|---|---|
| **Spec version** | `v1`, `v2`, `v1.1`, `v2-RC1` | `mad.council.a2a.md` frontmatter | Breaking changes → major bump; additive backwards-compatible → minor bump. |
| **Schema version** | `v1`, `v1.1`, `v2` | Embedded in `channel.json.settings.schema_version` (added v1.1) | Matches spec version at time of channel creation. |
| **Kit version** | SemVer | `MAD/VERSION` file (Phase-1 deliverable) | Ships with every release of the kit. |

**Rule of thumb:** spec version drives migration decisions; kit version is informational; schema version on each channel is the load-bearing identifier at runtime.

The current state (2026-04-17) is **spec v1** / **no schema_version field** (implicit v1) / kit v0.9-pre.

## When migration is required

| Change type | Migration required? | Example |
|---|---|---|
| New optional field added to a schema | **No** | `ensemble_mode` on channel.json settings — default fills in. |
| New required field on a new artifact | No (new artifacts are v2-only) | `retros/*.json` added for learning signals. |
| New required field on existing artifact | **Yes** — field must be backfilled | Adding `body_size_bytes` retroactively to existing messages. |
| Field rename | **Yes** — rewrite every affected file | `from` renamed to `author`. |
| Removed field | **Yes** if other code reads it | Dropping `mentions` array. |
| Schema validation tightened (e.g. new regex) | **Yes** if existing data could fail validation | `alias` pattern tightened — existing aliases with spaces fail. |
| Folder layout change | **Yes** — directory move | `threads/` → `t/`. |
| Enum expansion | No | Adding `ESCALATE` to verdict types — old channels never had it, no problem. |
| Enum reduction | **Yes** | Removing `INVESTIGATE` — need to rewrite or reject existing INVESTIGATE verdicts. |

## Migration tool contract

Every migration ships as one PowerShell script under `scripts/migrations/` named by target version:

```
scripts/migrations/
  to-v1.1.ps1     # v1 → v1.1
  to-v2.ps1       # v1.1 → v2 (assumes v1.1 prerequisite)
```

Each migration script MUST:

1. **Dry-run by default.** `--dry-run` is the default; `--apply` must be explicit. Dry-run reports what would change without touching files.
2. **Backup before apply.** Copy `~/claude-data/channels/` to `~/claude-data/migrations/<from-version>-to-<to-version>-backup-<timestamp>/` before any write.
3. **Idempotent.** Running the migration twice on a v2 channel must be a no-op, not a corruption.
4. **Atomic per channel.** A channel is either fully migrated or fully not — never half. Use the `.tmp+rename` pattern on the whole channel directory (move to `<channel>.migrating`, do work, rename back) or a manifest file that lists completed channels.
5. **Report per channel.** Output format: JSON array, one object per channel, with fields `name`, `status` (`migrated`/`skipped`/`failed`), `files_touched`, `errors`.
6. **Rollback-able.** The backup from step 2 enables rollback via `scripts/migrations/rollback.ps1 <backup-dir>`.
7. **Versioned test fixtures.** Under `evals/fixtures/migrations/<from>-to-<to>/` a pre-migration fixture + expected post-migration fixture; Layer-1 test diff-checks against the expected output.

## Example — adding `body_size_bytes` retroactively (hypothetical v1 → v1.1)

```powershell
# scripts/migrations/to-v1.1.ps1 (sketch)
param([switch]$Apply)

Import-Module (Join-Path $PSScriptRoot '..' 'channel-helpers.psm1')

$channelRoots = Get-ChildItem "~/claude-data/channels/" -Directory -Filter '[a-z]*'
$report = @()

foreach ($channel in $channelRoots) {
    $current = Get-ChannelSchemaVersion $channel.FullName
    if ($current -ge '1.1') { continue }

    if ($Apply) {
        Backup-Channel -Path $channel.FullName -Dest "$HOME/claude-data/migrations/v1-to-v1.1-backup-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    }

    $messageFiles = Get-ChildItem -Path $channel.FullName -Filter '*.json' -Recurse | Where-Object { $_.DirectoryName -match 'messages' }
    foreach ($msg in $messageFiles) {
        $content = Get-Content $msg.FullName -Raw | ConvertFrom-Json
        if ($null -eq $content.body_size_bytes) {
            $content | Add-Member -Force NoteProperty body_size_bytes ([Text.Encoding]::UTF8.GetByteCount($content.body))
            if ($Apply) {
                Write-AtomicJson -Path $msg.FullName -Content $content
            }
        }
    }

    if ($Apply) {
        Set-ChannelSchemaVersion $channel.FullName '1.1'
    }

    $report += [pscustomobject]@{
        name = $channel.Name
        status = if ($Apply) {'migrated'} else {'would-migrate'}
        files_touched = $messageFiles.Count
        errors = @()
    }
}

$report | ConvertTo-Json | Write-Output
```

This example is not pretty, but it illustrates the contract: explicit `-Apply`, backup, idempotent check (`$current -ge '1.1'`), per-channel atomicity via `Write-AtomicJson`, structured report output.

## Backward-compatibility window

The kit ships two compatibility reads at once:

- **`scripts/channel-helpers.psm1` reads both v1 and v1.1 channel.json transparently** — a skill running against an un-migrated channel sees the same object shape as one against a migrated channel. The compatibility shim stays for **2 minor versions** (so v1.1 code reads v1; v2 code reads v1.1; v2.1 drops v1 reads).
- **Writes always target the channel's declared schema version.** If a v1 channel is accessed by v1.1 code, writes stay in v1 format. Upgrade only when the migration tool is run explicitly by a user.

This buys users time to migrate. It also lets us test v1.1 code against v1 fixtures in CI.

## Deprecation policy

When a schema version is deprecated:

1. **Spec update** names the deprecation with a target removal version (e.g. "v1 read support removed in v2.1").
2. **Kit release notes** flag the deprecation on every minor release between now and removal.
3. **Preflight warning** — `scripts/preflight.ps1` detects un-migrated channels in the deprecation window and prints a warning: "Channel <name> is on v1 (deprecated). Run `scripts/migrations/to-v1.1.ps1 --apply` before v2.1 (target: 2027-01-01)."
4. **At removal**: preflight starts failing for un-migrated channels with instructions. No silent skipping.

Minimum deprecation window: **6 months from deprecation announcement to hard removal.** Exception: security-driven changes can shorten the window with explicit justification in the spec's change log.

## Forward-compatibility — what NOT to do

- **Don't put version logic inside every skill.** Put it in `channel-helpers.psm1` and `scripts/migrations/`. Skills should see a uniform shape.
- **Don't write "convert on read" shims in skills.** That path leaks v1 behavior into every code path; migrate once, keep the kit's mental model clean.
- **Don't break fixture tests when you deprecate.** Tests using the deprecated version should start as passing-with-warning and become failing-with-clear-instructions at removal time — not silently pass until the day of removal.
- **Don't store schema version only in the migration script.** Put it in `channel.json.settings.schema_version` so runtime code can assert on it.

## Archived channels

Archived channels (`archive/<date>-<channel>/`) are **frozen** — they are not migrated. An archived v1 channel stays v1 forever; the archive is a historical record, not a live artifact. A reader that needs to read an archived channel with a newer kit uses the compatibility-read shim (if within window) or the historical kit release.

If you need to migrate an archive for some reason (legal hold, format standardization), do it explicitly with a one-shot script, not automatic preflight.

## Testing migrations

Every migration ships with:

- **Pre-migration fixture** (a snapshot of "typical v1 channel") at `evals/fixtures/migrations/v1-to-v1.1/pre/`.
- **Expected post-migration fixture** at `evals/fixtures/migrations/v1-to-v1.1/post/`.
- **Layer-1 test** that runs the migration script in dry-run, asserts report matches expected shape.
- **Layer-2 test** that runs the migration with `-Apply`, diff-checks every file against the post fixture, then runs a `/council-check` skill against the migrated channel to confirm the skill doesn't care.
- **Layer-3 fault injection**: kill the migration script mid-run; verify partial channel is recoverable via backup rollback.

## When migration fails

Per `rules/degradation-fallback-policy.md`:

- Dry-run failure: surface the problematic channel + file + reason; do not silently skip.
- Apply-mode failure on channel N: roll back channel N from backup; continue with remaining channels unless the user specified `--stop-on-error`.
- Fundamental failure (backup fails, disk full): stop immediately with clear diagnostic; never leave the system half-migrated.

## Related

- `rules/concurrency-safety.md` — atomic write pattern migration scripts reuse.
- `operations/backup-disaster-recovery.md` — backup format is the same as migration backup.
- `schemas/*.schema.json` — tightening a schema during a migration requires a Layer-0 fixture update.
- `scripts/atomic-write.ps1` — migration scripts MUST use this helper, not direct file writes.
- `plans/phase-1-mvp.md §Migration tool (M5)` — the first migration tool (Channels v1 → MAD.Council) uses this same contract.
