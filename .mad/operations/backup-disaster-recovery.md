# Backup & Disaster Recovery

MAD.Council stores all channel state in user-local files under `~/claude-data/channels/`. This file describes what state exists, what's worth backing up, how to back it up, and how to recover when the machine is lost.

## What state exists

| Path | Durability class | Typical size | Lossiness on loss |
|---|---|---|---|
| `~/claude-data/channels/<channel>/channel.json` | **Durable** | ~1–10 KB | High — reconstructing member registry + Agent Cards requires coordination. |
| `~/claude-data/channels/<channel>/digest.json` | **Derived** | <2 KB | Low — rebuildable from messages/ via `scripts/digest-rebuild.ps1`. |
| `~/claude-data/channels/<channel>/seq.json` | **Durable** | <100 bytes | Medium — losing seq.json without message history causes seq-reuse collisions on recovery. |
| `~/claude-data/channels/<channel>/threads/<id>/*.json` | **Durable** | ~5–500 KB/thread | **Very high** — messages are the primary artifact; irreplaceable without backup. |
| `~/claude-data/channels/<channel>/threads/<id>/verdict.json` | **Durable** | ~1–5 KB | High — verdicts are legal-grade audit trail. |
| `~/claude-data/channels/<channel>/read-markers/<alias>.json` | **Recoverable** | <500 bytes | Low — member can re-read from start; only loses cursor. |
| `~/claude-data/channels/<channel>/archive/` | **Durable (cold)** | varies | Very high — archived channels are the audit history. |
| `~/claude-data/.sessions.json` | **Session-bound** | <5 KB | None — regenerated on next session start. |
| MAD artifacts in `spec.md` / `plan.md` / `tasks.md` (channel-level) | **Durable** | ~5–50 KB | High — replacement requires re-running the MAD workflow. |

Tl;dr: **messages, verdicts, archives, channel.json, seq.json, and MAD artifacts are worth backing up. Everything else is rebuildable or ephemeral.**

## Backup strategy

### Recommended cadence

- **Daily incremental** of the `threads/` subtree and all `*.json` channel-level files.
- **Weekly full** of the entire `~/claude-data/channels/` tree.
- **On-archive**: when a channel archives, the archive is copied verbatim to the backup location as part of `/council-leave`'s side-effects.

### Backup destinations (pick one)

| Destination | When to use | Notes |
|---|---|---|
| Secondary local disk | Single-user laptop | Cheapest; survives primary disk failure but not machine loss. |
| OneDrive / iCloud / Dropbox (`~/claude-data/` mounted into cloud-sync folder) | Team of 1–5 already using a consumer cloud-sync product | Easy to set up. **Check cloud provider encryption at rest**; verify no mid-file sync during atomic write (see concurrency caveat below). |
| Internal object store (Azure Blob + lifecycle policy, S3 + versioning) | Teams with compliance obligations | Robust, versioned, auditable. Backup script below targets this path. |
| Home NAS (Synology, Unraid) with ZFS snapshots | Privacy-sensitive users | Strong durability, no third party, snapshots trivially recover deleted files. |

### Cloud-sync caveat

**Atomic-write + filesystem-sync tools do not always cooperate.** The `.tmp+rename` pattern (see `rules/concurrency-safety.md`) is atomic on NTFS/APFS/ext4 — but a cloud-sync client may see the `.tmp` file, sync it, and still be syncing when the rename happens. Results: backup contains `file.tmp` alongside `file.json`. Mitigations:

- Sync client should be configured to ignore `*.tmp` glob patterns.
- Or use a backup tool that snapshots first (ZFS, rsync `--delete-excluded`, restic, etc.) rather than live-sync.
- Or back up after channel activity stops (e.g. nightly at 3am) — reduces the chance of catching an in-flight atomic write.

### Reference backup script (sketch)

Ship as `scripts/backup-channels.ps1` in Phase-1:

```powershell
# Pseudocode — real impl in Phase 1
$src = Join-Path $env:USERPROFILE 'claude-data'
$dest = $env:MAD_BACKUP_PATH  # user sets this env var
if (-not $dest) { throw "Set MAD_BACKUP_PATH to a backup root." }

# Skip .tmp files to avoid half-written content
$tsDir = (Get-Date -Format 'yyyy-MM-dd-HHmm')
$target = Join-Path $dest $tsDir
robocopy $src $target /E /XF '*.tmp' /XF '.sessions.json' /R:3 /W:5 /NP /NFL
# Retain 30 days; lifecycle policy on the object-store side handles pruning.
```

Use `/XF '*.tmp'` to skip temp files. Excluding `.sessions.json` is deliberate — it's session-bound and regenerates on next start.

## Restore procedure

### Single channel (accidental delete)

1. Identify the backup snapshot with the most recent usable state.
2. Copy `channels/<channel>/` from backup into `~/claude-data/channels/`.
3. Run `pwsh scripts/preflight.ps1 --channel <channel>` to verify integrity + sweep `.tmp` orphans.
4. Run `pwsh scripts/digest-rebuild.ps1 --channel <channel>` to regenerate `digest.json` from messages.
5. Restart Claude Code; `/council-list` should show the channel.
6. Run `/council-check <channel>` to confirm messages are intact.

### Full machine loss / new device

1. Install Claude Code on new machine.
2. Restore `~/claude-data/channels/` from latest backup snapshot.
3. **Do NOT restore `.sessions.json`** — it's session-bound and will confuse the new session.
4. For each channel you want to resume, `/council-join <channel> --as "<your alias>"` — this creates a new session_id bound to your alias. Existing messages authored by your old session_id will surface with a ⚠️ badge (expected: reader-side session-mismatch check, per spec §7.2).
5. Resolve the ⚠️ by running `/council-join <channel> --reclaim "<your alias>" --force` (per `skills/council-join/SKILL.md §reclaim`) after verifying you are the authentic owner. This updates the channel's member registry to the new session_id.

### Forensic restore (investigating an incident)

When you need to read channel state without "joining" (preserving evidence):

1. Restore the backup to an isolated directory (not `~/claude-data/`).
2. Use `Read`/`Grep` directly on the JSON — do not invoke `/council-*` skills, which would mutate `.sessions.json` and read markers.
3. Document findings in a `post-incident-<incident-id>.md` note; do not write back to the live channel.

## Retention policy

Recommended retention (adjust to your org's legal/compliance posture):

| Tier | Retained for | Why |
|---|---|---|
| Active channels (non-archived) | Indefinitely | Live working state. |
| Archived channels | 2 years | Audit window for verdicts + MAD artifacts. |
| Backup snapshots | 30 days (daily) + 12 months (monthly) | Enough to recover from "last month's delete." |
| Verdicts specifically | 7 years | Matches typical legal-hold defaults; verdicts are load-bearing for compliance. |

## DR in a multi-user org

This document treats DR as a single-user concern because MAD.Council is currently single-user-per-session. In a multi-user org with shared channels (future A2A + shared filesystem deployments):

- **Authoritative copy ownership** must be assigned per channel. First member to `/council-open` is the default owner; re-assignment requires explicit handoff per `plugins/retro-bar-raiser/` blameless pattern.
- **Backup is a shared responsibility** — whoever owns the channel owns its backup.
- **Cross-user restore** after a member leaves must go through `/council-join --reclaim --force` — same as single-user case, but now requires peer confirmation in the channel.

## Non-goals for DR

- **Cross-region replication.** MAD.Council channels are local-transport; A2A layer handles cross-region. If you need cross-region continuity, use A2A mode + replicate the A2A Ship Bridge layer.
- **Point-in-time recovery within a channel.** We don't support "restore this channel to 2 hours ago." If you need it, use ZFS/APFS snapshots at the filesystem level; MAD isn't a time-travel database.
- **Continuous replication / synchronous backup.** Overkill for a file-based kit. Daily incremental is enough for 99% of users.

## Verification

The backup/restore flow must be exercised at least quarterly:

- [ ] `/council-open <test-channel>` + post some messages.
- [ ] Run `backup-channels.ps1`.
- [ ] `rm -rf ~/claude-data/channels/<test-channel>` (on a test machine).
- [ ] Restore from backup per §Single channel procedure.
- [ ] Verify all messages readable, digest rebuild succeeds, member can rejoin via `--reclaim --force`.

An exercise that fails → open a HIGH checklist item, fix the backup script, retest. This is the DR equivalent of the Layer-3 fault-injection eval.

## Related

- `rules/concurrency-safety.md` — atomic-write pattern that interacts with backup tools.
- `scripts/preflight.ps1` — orphan `.tmp` sweep, run after restore.
- `scripts/digest-rebuild.ps1` — regenerates `digest.json` after restore.
- `skills/council-join/SKILL.md §reclaim` — how a restored member rejoins.
- `evals/layer-3-e2e-fault-injection.md` — where to add the quarterly DR exercise as a permanent test.
