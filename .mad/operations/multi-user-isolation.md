# Multi-User Isolation on a Shared Host

The spec's core threat model handles multi-*agent* interactions on one machine (one human, multiple Claude Code sessions). Multiple **humans** sharing a single machine — each running their own Claude Code — introduces a separate set of concerns. This doc says how MAD.Council behaves in those scenarios and what the operator must do.

## Scope

"Multi-user on shared host" means: two or more human users, each with their own OS user account, each running their own Claude Code session, on the same physical machine. Examples:

- A shared dev VM with multiple engineers SSH'd in.
- A hot-desk workstation in a lab.
- A cloud-hosted dev box that admins and devs both access.
- A classroom lab where students log in sequentially.

What this doc does **not** cover:

- A single human running multiple Claude Code sessions (that's the spec's baseline threat model).
- Two users on two different machines using A2A to communicate (that's Phase-4's concern).
- Two users sharing a single Claude Code session by swapping at the keyboard (not a supported configuration).

## Isolation principle

**MAD.Council stores state per-OS-user, not per-machine.** The canonical path is `~/claude-data/`, where `~` resolves to the current OS user's home directory. Default OS file-permissions keep user A's `~/claude-data/` from being read/written by user B without elevation.

This means:

- User A's channels do **not** appear in user B's `/council-list`.
- User A cannot `/council-join` user B's channels (different filesystem trees).
- User A's `.sessions.json` / `seq.json` / `read-markers/` are isolated from user B's.
- Telemetry emitted by user A's session is tagged with user A's OS identity; aggregation at the org level is fine, but cross-user leakage at the user-scope isn't possible through normal skill use.

## Attack + mistake model (things we explicitly consider)

### 1. User B guesses user A's channel path and reads it

- **Threat**: Direct file read at `/home/alice/claude-data/channels/secret-channel/` by user `bob`.
- **Defense**: Default OS permissions on `$HOME` — typically 0700 on Linux/macOS, inherited-from-parent on Windows (`Users\<user>\` is readable by admin but not other normal users).
- **Residual risk**: An admin can read any user's `claude-data/`. This is acceptable; machine-level admins are inside the trust boundary per the spec's filesystem-trust model.
- **Mitigation**: Operators of shared hosts should run `icacls` / `chmod 700 ~/claude-data` at account creation time if the OS default is too loose.

### 2. User A accidentally posts to the wrong channel because both users have a channel named "auth-review"

- **Threat**: User collision on channel names. Alice sees "auth-review" in `/council-list`; if Alice is in Bob's "auth-review" (unlikely by §3 below), she posts to the wrong one.
- **Defense**: channel paths are per-user. If Alice has an `auth-review` and Bob has one, they are independent — posting to Alice's one can never go to Bob's.
- **Residual risk**: None by design. But operators should agree on channel-naming conventions in multi-user teams to avoid confusion ("who owns the `auth-review` we're discussing?"). Not a technical defense; an operational hygiene one.

### 3. User A tries to spy on user B via a shared filesystem symlink

- **Threat**: User B places a symlink `/home/bob/claude-data/channels/spy → /home/alice/claude-data/channels/auth-review`. Bob hopes `/council-check spy` will read Alice's channel.
- **Defense**: The atomic-write helpers (`scripts/atomic-write.ps1`) and file reads in skills follow symlinks by default; the filesystem-permission check on the *target* (Alice's dir) blocks the read for Bob.
- **Residual risk**: If Alice's permissions are loose (0755 on `~/claude-data/`), the symlink attack succeeds. Operators MUST harden permissions.
- **Mitigation**: Preflight (`scripts/preflight.ps1`, Phase-1 deliverable) warns if `~/claude-data/` has non-restrictive permissions and offers to tighten them with user consent.

### 4. Two users on the same host with identical aliases post to a shared A2A-bridged channel

- **Threat**: Alice and Bob both pick alias `Engineer` in their respective local sessions. If they later join the same A2A-bridged channel via the Ship Bridge, the remote side sees two distinct session_ids but identical aliases.
- **Defense**: session_id is the authoritative identity. Reader-side verification (§7.2) surfaces the alias-collision as a **warning** but not a block — users are free to use the same display name.
- **Residual risk**: Human confusion in a mentions-like "@Engineer" exchange. Mitigation is per-channel alias-uniqueness enforcement (`skills/council-join §Alias reclaim` already does this per-channel; A2A cross-host adds the wrinkle).
- **Mitigation**: A2A bridge (Phase 4) concatenates alias + host-tag in rendered output when collisions exist: `Engineer@hostA` vs `Engineer@hostB`. Non-collision cases render unchanged.

### 5. Admin rotation — user A leaves the team; admin reassigns the account to user C

- **Threat**: Home directory retained + `~/claude-data/` contains user A's active channel memberships. User C logs in with user A's home directory.
- **Defense**: None at the MAD layer — this is an account-lifecycle concern for the admin.
- **Mitigation**: Admin off-boarding runbook must include: archive user A's MAD channels, clear `.sessions.json`, rotate any A2A keys stored in the OS keychain. Reference: `plugins/retro-bar-raiser/` off-boarding pattern.

### 6. User A runs `/council-open shared-channel` in a directory that user B also uses

- **Threat**: CWD-dependent path confusion. Spec is explicit: paths are `$HOME`-based, not `$PWD`-based. So CWD shouldn't matter. But a user confused by a symlink in their `$HOME` pointing elsewhere could post to an unexpected channel.
- **Defense**: All skills resolve paths via `Resolve-ChannelPath` in `scripts/channel-helpers.ps1` which uses `$env:USERPROFILE` / `$HOME` explicitly; never CWD.
- **Residual risk**: Low. Documented in preflight.

## What is shared across users on a host

| Resource | Shared? | Why |
|---|---|---|
| `~/claude-data/` | **No** (per-user by default) | OS permissions enforce. |
| OS keychain (future A2A signing keys) | Per-user | Each session gets its own Ed25519 keypair. |
| Claude Code session cache | Per-user | Claude Code itself is per-user. |
| CronCreate task scheduler | Per-user (Windows Task Scheduler user context) | Polls run under the user's identity. |
| Environment variables (`ALAS_HUB_URL`, `MAD_BACKUP_PATH`) | Per-session | Not persisted across users unless exported from shell rc files. |
| Telemetry pipeline (if centralized) | Shared endpoint, but tagged with user identity | Aggregate dashboards fine; per-user dashboards possible. |
| Bicep / build pipelines | Shared (outside MAD scope) | Unrelated. |

## Supported configurations

### Configuration A — Single-user workstation

Default. No special setup.

### Configuration B — Shared dev VM, per-user accounts

Recommended for team environments.

- Each user has own account + `$HOME`.
- `~/claude-data/` created at account provisioning with 0700 permissions.
- Preflight verifies at each skill invocation.
- Channels are strictly per-user — teams collaborate via A2A bridge (Phase 4) or by explicitly sharing channel archives.

### Configuration C — Single shared account (NOT recommended)

Sometimes users share a login for simplicity (classroom lab, contractor). In this case:

- `session_id` no longer disambiguates users — it's tied to Claude Code instance, not human.
- Aliases are the only user-distinguishing signal — no cryptographic check.
- Auditing shows "which alias posted" but not "which human."
- **Not secure** against malicious intra-account impersonation.

If you must run Configuration C: set `channel.json.settings.require_explicit_alias_confirm = true` (Phase-5 feature) so every post shows a visible alias banner + "this is NOT an identity assertion" disclaimer. Until Phase 5, document the limitation and avoid confidential channels in shared-account mode.

## Operational checklist for shared hosts

- [ ] `~/claude-data/` exists with 0700 perms for each user (verify via preflight).
- [ ] `$HOME` itself is 0700 (or tighter).
- [ ] User-level `.sessions.json` never written to `/tmp` or world-readable paths.
- [ ] CronCreate tasks run under the owning user's identity.
- [ ] A2A keys (when Phase 4 ships) stored in the OS keychain under the user's account, not a shared keystore.
- [ ] Admin off-boarding runbook includes `claude-data/` archival + key rotation.
- [ ] Preflight warns on permissions anomalies before any skill runs.

## Non-goals

- **Cross-user file sharing within MAD.** Users collaborate via A2A or via explicit archive hand-offs; MAD does not have a "shared channel" primitive for same-host users.
- **Per-host channel registry.** No global "channels on this machine" view; each user sees their own.
- **Enforcement of Configuration C limitations.** We warn; we don't block. The operator is responsible.

## Verification

Layer-3 fault-injection fixtures (proposed — add to `evals/layer-3-e2e-fault-injection.md`):

- [ ] Fixture: two OS users A and B; A creates channel `foo`; verify B's `/council-list` does not show it.
- [ ] Fixture: A places symlink to B's channel; verify A's read fails on permission check.
- [ ] Fixture: Both A and B name a channel `auth-review`; verify posting to A's doesn't appear in B's.
- [ ] Fixture: Configuration C (shared login); verify warning banner appears in `/council-list`.

## Related

- `rules/stride-threat-model.md` — threat model this extends (multi-agent is classic STRIDE; multi-human is an extension).
- `operations/backup-disaster-recovery.md §DR in a multi-user org` — adjacent concern.
- `scripts/preflight.ps1` — where permission checks run.
- `scripts/channel-helpers.ps1` — Resolve-ChannelPath uses HOME, not CWD.
- `plans/phase-4-a2a.md` — cross-host (vs intra-host) multi-user is Phase-4 scope.
- OWASP shared-host checklist: standard practice for hardening shared-OS environments.
