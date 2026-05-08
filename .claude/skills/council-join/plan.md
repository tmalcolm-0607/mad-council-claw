# Implementation Plan: /council-join

Target: MAD.Council Phase 1 MVP per `mad.council.a2a.md` §12.

## Dependencies

Same shared infrastructure as `/council-open`:

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 10 | ⏸ |
| `scripts/preflight.ps1` | iter 10 | ⏸ |
| `scripts/channel-helpers.ps1` (alias resolution, member update) | iter 10 | ⏸ |
| A2A Agent Card validator | iter 10 | ⏸ |

Adds one new helper:

| New helper | Purpose |
|---|---|
| `scripts/alias-conflict-resolver.ps1` | Determine Case A/B/C/D + render consent preview |

## Implementation steps

### 1. Parse arguments

- Extract `<channel-name>`, `<alias>`, optional `--poll`, `--agent-card`, `--force-reclaim`.
- Validate name regex + alias length + poll range.
- On failure → `rc=2` with specific message.

### 2. Verify channel exists

- `Test-Path ~/claude-data/channels/<name>/channel.json`. Missing → `rc=3`.

### 3. Preflight

Same table as `/council-open` but channel-dir-exists check (not "must not exist").

### 4. Read channel.json

- Atomic read (via `scripts/atomic-write.ps1` read helper).
- Parse JSON. Corrupt → `rc=4` with diagnosis hint.

### 5. Resolve alias conflict

- `scripts/alias-conflict-resolver.ps1 -ChannelJson $json -Alias "<alias>" -ThisSessionId <id> -ForceReclaim <bool>`.
- Returns `Case` (A/B/C/D) + `ConsentRequired` (bool).
- Case C + no force-reclaim → `rc=2` with "use --force-reclaim if..." message.
- Case C + force-reclaim → show preview + prompt. User "no" → `rc=5`.
- Case D → idempotent success; `rc=0` with "already joined" note (skip steps 6-9, skip to 10).

### 6. Load Agent Card (if --agent-card)

Same as `/council-open` step 5. Malformed → `rc=2`.

### 7. Generate run_id + update channel.json

- `$run_id = [guid]::NewGuid().ToString()`.
- Build new/updated member entry.
- Atomic-rename write (`scripts/atomic-write.ps1`).

### 8. Create or preserve read-marker

- If file exists at `read-markers/<alias>.json` (Case B reclaim), preserve.
- Else create fresh (`{last_read_seq: 0, ...}`).
- Atomic write.

### 9. CronCreate polling

- Same as `/council-open` step 9.
- Store `cron_task_id` in member entry via second atomic channel.json write.

### 10. Update .sessions.json

- Add channel membership to `sessions.<this-session-id>.channels`.
- Atomic-rename write.

### 11. Read digest + present state

- Read `digest.json` (retry 1x per retry table).
- Render channel state with member list, active threads, unread counts, MAD phase (if applicable), pending reviews.
- Prioritize threads mentioning `<alias>`.
- On digest read failure: render limited state ("channel joined; digest unavailable") with Context Gap.

## Rollback

Partial-failure cases (less cleanup needed than `/council-open` because channel already exists):

- Step 7 fails: no member added; no state change. `rc=4`.
- Step 8 fails: member added; warn that read-marker wasn't created (will be on next check-in).
- Step 9 fails: member added; channel operates in manual-check mode. `rc=1`.
- Step 10 fails: member added + polling set up; session-registry not updated. Warn. `/council-list` won't show this channel until a subsequent operation updates it. `rc=1`.

## Error messages

| Condition | Message |
|---|---|
| Channel not found | `"Channel '<n>' not found. Use /council-list to see your channels, or /council-open <n> \"<purpose>\" to create one."` |
| channel.json corrupt | `"channel.json malformed. Run /council-list to diagnose. Do NOT use /council-open on the same name — it may recover."` |
| Alias conflict (active) | `"Alias '<a>' is active (session <id>, last seen <ts>). Use --force-reclaim if you're sure that session is gone."` |
| Force reclaim consent declined | `"Cancelled. No changes made."` |
| Agent card issues | Same as `/council-open` |

## Test coverage targets

Per `tests.md` (sibling):

- All 4 conflict cases (A/B/C/D) covered.
- Reclaim preserves read-marker (Case B).
- Force-reclaim with user "yes" and user "no" both covered.
- All return codes reachable.

Coverage target: 95%+ branch.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing + validation | 1 |
| Preflight integration (reuse from /council-open) | 0.5 |
| Alias-conflict-resolver helper | 4 |
| Force-reclaim consent gate + preview | 2 |
| State file updates | 3 |
| CronCreate integration (reuse) | 1 |
| Digest read + state presentation | 3 |
| Rollback handling | 2 |
| Tests | 6 |
| **Total** | **~22 hours** |

## Forward-links

- `evals/fixtures/council-join-case-a/` — fresh join.
- `evals/fixtures/council-join-case-b/` — reclaim disconnected alias.
- `evals/fixtures/council-join-case-c/` — active-alias conflict (reject without force).
- `evals/fixtures/council-join-case-c-force/` — force-reclaim happy path.
- `evals/layer-2-integration/council-join.test.md` — integration tests.
- `evals/layer-4-adversarial/alias-hijack.test.md` — spoofing scenarios.

## Risks

| Risk | Mitigation |
|---|---|
| Two agents race to reclaim same disconnected alias | Atomic rename on channel.json write; last-write-wins; second gets updated state on next read |
| Force-reclaim used casually, disconnecting real members | Consent gate with specific session_id + last-seen time; user confirms |
| Agent Card injection via `--agent-card` path (symlink to sensitive file) | Read size-cap + schema validation reject non-Agent-Card content |
| Digest read fails during state presentation | Skill still succeeds; Context Gap surfaced; user can retry `/council-check` |
