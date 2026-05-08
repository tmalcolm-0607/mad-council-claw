# Implementation Plan: /council-leave

Target: MAD.Council Phase 1 MVP per `mad.council.a2a.md` §12.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 11 (scripts/) | ⏸ |
| `scripts/channel-helpers.ps1` | iter 11 | ⏸ |
| `scripts/completion-report.ps1` (new) — scans threads + builds report | iter 11 | ⏸ |
| `scripts/archive-channel.ps1` (new) — atomic-move channel → archive dir | iter 11 | ⏸ |
| CronDelete runtime (or equivalent teardown) | Claude Code host | available |

## Implementation steps

### 1. Parse arguments

- Single positional: `<channel-name>`.
- No flags.

### 2. Preflight + membership check

- Verify channel exists. Missing → `rc=2`.
- Read channel.json. Find member where `session_id == $thisSessionId`.
- No match → `rc=2` ("already not a member").
- Record my alias for report generation.

### 2a. Owner-leave gate (ADOPT-001 / -013)

Per `rules/single-owner-accountability.md` § "council-leave" and `rules/triage-gate.md` § "Owner departures":

- Read `channel.json:owner_alias`.
- If `my.alias != owner_alias` → skip this gate.
- If `my.alias == owner_alias`:
  - Read `channel.json:status`.
  - If `status ∈ {resolved, closed}` → owner may leave freely; skip to §Step 3.
  - Otherwise, scan `threads/*/verdict.json` for a verdict with:
    - `verdict == "OWNERSHIP_TRANSFER"`
    - `ownership_transfer.from_alias == my.alias`
    - `issued_utc` newer than `my.joined_utc`
    - `ownership_transfer.to_alias` is an active `members[]` entry (not disconnected)
    - verdict has been resolved (a matching `council-resolve` entry set `channel.json:owner_alias = to_alias` OR the resolution will occur in §Step 6 below).
  - If no qualifying verdict → reject with `rc=OWNER_LEAVING_WITHOUT_TRANSFER` and a clear error message describing exactly how to transfer ownership. Do NOT modify any state.
  - If a qualifying unresolved verdict exists → apply the transfer as part of §Step 6 atomically (both `status: disconnected` AND `owner_alias = to_alias` in one atomic write).

### 3. Compute Completion Report

- Spawn `scripts/completion-report.ps1 -ChannelDir <path> -Alias <a> -SessionId <s>`.
- Script scans:
  - `threads/*/thread.json` for created_by / resolved_by / participants stats.
  - `threads/*/messages/*.json` for type-filtered counts by this alias.
  - `threads/*/verdict.json` for verdicts issued by this alias.
  - Collects unique `run_id` values across my messages.
- Script returns structured JSON (matches schema in SKILL.md §Step 2).
- On thread-scan failures, fill `context_gaps[]` in the report.

### 4. Determine last-member status

- Count other members with `status == active`.
- If 0: trigger consent gate (§Step 4 spec). Otherwise skip to §Step 5.

### 5. Archival consent gate (if last member)

- Render preview (counts threads, MAD artifacts, reports, verdicts).
- Prompt `yes/no` with 60s timeout.
- Record decision in `<channel>/consent-log.jsonl`.
- User "no" / timeout → `rc=5`, archive=false, proceed to §Step 7 with dormant-channel note.
- User "yes" → set `archive=true`, continue to §Step 6.

### 6. Update channel.json

- Set my member's `status: disconnected`, `last_seen_utc = now`.
- Atomic-rename write.

### 7. Write Completion Report

- Path: if NOT archiving, `<channel-dir>/leave-reports/<alias>-<timestamp>.json`.
- If archiving, write to `<channel-dir>/leave-reports/` first — it'll move into the archive in §Step 8.
- Atomic-rename write.

### 8. Archive (if last + consented)

- Call `scripts/archive-channel.ps1 -ChannelName <n> -Timestamp <ts>`.
- Target: `~/claude-data/channels/archive/<name>-<ts>/`.
- Atomic filesystem rename — whole directory moves in one op.
- On failure: state is now half-moved (bad). Emit explicit error + path-list for manual recovery.

### 9. Tear down CronCreate

- Find `cron_task_id` in my member entry (captured before write).
- Call CronDelete.
- On failure: warn only. Polling dies when Claude Code session closes.

### 10. Update .sessions.json

- Remove channel from `sessions.<my-session>.channels`.
- If my session has no channels left, remove the session entry entirely.
- Atomic-rename write.

### 11. Emit summary

- Render human-readable output per SKILL.md §Step 10.
- Highlight `verdict_pending` list with retention note.

## Rollback

Rollback complexity is high because this skill combines: report generation, state updates, filesystem moves, and external tool calls. Strategy: **forward-only rollback** for the move step; explicit errors for unrecoverable states.

| Failure point | Rollback |
|---|---|
| Step 3 (report computation) fails | Do NOT proceed. `rc=4`. No channel state modified yet. |
| Step 5 (consent gate timeout) | Treat as "no"; proceed to leave without archive. Dormant state. `rc=5`. |
| Step 6 (channel.json update) fails | `rc=4`; do NOT write report (state is incoherent); user must retry after diagnosing fs issue. |
| Step 7 (report write) fails | `rc=4`; restore channel.json member to `status: active` if possible (atomic read-check-swap). |
| Step 8 (archive move) fails mid-move | Unrecoverable in general. Emit explicit error + list of files at each location. User must manually complete. |
| Step 9 (CronDelete) fails | Warn only. Polling task may persist briefly but dies when session ends. |
| Step 10 (.sessions.json) fails | Warn; `/council-list` may show ghost membership. Not leaking state — self-corrects on next operation. |

## Error messages

| Condition | Message |
|---|---|
| Channel doesn't exist | `"Channel '<c>' not found. Use /council-list to see your channels."` |
| Not a member | `"You are not a member of '<c>'. No-op."` |
| Report write fails | `"Completion Report could not be written. Your membership remains active. Diagnose filesystem and retry."` |
| Archive move fails | `"Archive move failed mid-operation. Files may be in: ~/claude-data/channels/<n>/ AND ~/claude-data/channels/archive/<n>-<ts>/. Manual intervention required. Contact channel admin."` |
| Consent timeout | `"Archive consent timed out (60s). Channel remains dormant with your membership disconnected."` |
| Owner leaving without transfer | `"You are the owner_alias of '<c>' and the channel is in status <s>. Per rules/single-owner-accountability.md, owners MUST issue an OWNERSHIP_TRANSFER verdict before leaving. Run: /council-verdict <c> --verdict OWNERSHIP_TRANSFER --to-alias \"<other-member>\" --rationale \"...\", then /council-resolve, then retry /council-leave."` |

## Test coverage targets

Per `tests.md`:

- All 5 return codes reachable.
- Completion Report scan works on empty thread, single-thread, many-threads channels.
- Last-member detection correct across: 1-member channel, 2-member channel (other disconnected), N-member channel.
- Consent gate: yes / no / timeout (60s) all exercised.
- Archive move atomicity verified (half-move test).
- `verdict_pending` list populated correctly on leave.
- CronDelete failure doesn't block the leave.
- Dormant-channel state produced correctly when user declines archive.

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing + preflight | 1 |
| Completion Report scan (complex — all threads, all messages) | 6 |
| Last-member detection | 1 |
| Consent gate + preview rendering | 3 |
| channel.json update | 1 |
| Report write | 1 |
| Archive move (atomic rename + rollback complexity) | 4 |
| CronDelete teardown | 1 |
| .sessions.json update | 1 |
| Output rendering | 2 |
| Tests | 8 |
| **Total** | **~29 hours (~3.5 working days)** |

## Risks

| Risk | Mitigation |
|---|---|
| Scan takes long on large channels | Timeout per-thread; partial report with context_gaps |
| Archive move half-completes | Explicit error + manual-recovery instructions; add preflight to check FS-operation support |
| User leaves mid-consent-prompt (crashes session) | On next session start, sweep orphan `.tmp` files; channel stays dormant |
| verdict_pending list grows unboundedly | Each member's report captures own participation; pending list includes threads MY session participated in, not all open threads globally |
| Report reveals sensitive information (e.g., my question text) | Report is filesystem-readable; treat like any other channel file. No additional PII handling per `mad.council.a2a.md` §2 Non-Goals |
| Archive directory name collides (`<name>-<ts>/`) | Timestamp has second granularity; same-second archive collision extremely rare. Append `-<random-4-chars>` as fallback. |

## Forward-links

- `evals/fixtures/council-leave-not-last/` — multi-member channel, regular leave.
- `evals/fixtures/council-leave-last-consent-yes/` — last member, user consents → archive.
- `evals/fixtures/council-leave-last-consent-no/` — last member, user declines → dormant.
- `evals/fixtures/council-leave-last-timeout/` — 60s timeout on consent prompt.
- `evals/fixtures/council-leave-with-pending-reviews/` — report shows verdict_pending list.
- `evals/fixtures/council-leave-corrupt-channel-json/` — report still generates with context_gaps note.
- `evals/fixtures/council-leave-large-channel-1000-threads/` — perf test.
- `evals/layer-2-integration/council-leave.test.md`.
- `evals/layer-3-fault-injection/archive-half-move.test.md`.
