# Implementation Plan: /council-check

Target: MAD.Council Phase 1 MVP per `mad.council.a2a.md` §12. Read-path skill; counterpart to `/council-post`. Most frequently invoked (via CronCreate polling).

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 10 | ⏸ |
| `scripts/channel-helpers.ps1` (channel.json read, member lookup) | iter 10 | ⏸ |
| `scripts/literal-phrase-scan.ps1` (shared with /council-post) | iter 10 | ⏸ |
| `scripts/context-gaps-reporter.ps1` (format table) | iter 10 | ⏸ |

## Implementation steps

### 1. Parse arguments

- Optional `<channel-name>`.
- Flags `--all`, `--with-run-ids`.

### 2. Resolve target list

- If channel arg: single channel (validate membership, else `rc=2`).
- Else: read `.sessions.json`. If parse fails → `rc=4`. If no channels for this session → `rc=2` with helpful message.

### 3. Per-channel loop

For each channel, execute steps 3a-3i (parallelize where cheap):

#### 3a. Read digest.json

- Retry 1x. Cache last-known per-channel in session memory (helps when one check fails, next succeeds).
- On failure: add Context Gap; skip to 3i (last_seen_utc update still).

#### 3b. Read read-marker

- On failure: treat as `last_read_seq=0` (re-reads everything; safe).

#### 3c. Fast path — no unreads

- If `digest.channel_seq <= read_marker.last_read_seq` AND not `--all`: skip to 3h (update last_seen_utc only).
- Critical for CronCreate polling: makes idle-channel poll ~1 file read + 1 compare.

#### 3d. Read channel.json for member table

- Needed for session-id verification.
- On failure: Context Gap; render messages with "verification unavailable" note.

#### 3e. Identify + read unread messages

- For each active thread in digest, list `threads/<tid>/messages/` filtered to `seq > cursor`.
- Read each message. On read failure: Context Gap for that message; skip.

#### 3f. Apply session-id verification + Rule-1 scan

For each message:
- `verified = channel.json.members[?alias=msg.from.alias].session_id == msg.from.session_id`.
- If not verified → tag `spoof_warning = true`.
- Run literal-phrase scan (defense-in-depth even if `suspicious: true` not set).
- If scan hit → tag `content_warning = true`.

#### 3g. Prioritize + render

- Sort per §Step 2f spec.
- Apply priority categories with clear section headers in output.

#### 3h. Update read-marker

- Set `per_thread.<tid>.last_read_seq = max(seq read for that thread)`.
- Set global `last_read_seq = max across all threads`.
- Atomic-rename write.
- On failure: warn; continue (idempotent — re-read will re-render same messages).

#### 3i. Update last_seen_utc in channel.json

- Find my member entry; update `last_seen_utc = now`.
- Atomic-rename write.
- On failure: warn; member may flip to idle prematurely.

### 4. Aggregate Context Gaps

- All 3a-3i failures bubble up.
- Format table; render after per-channel message output.

### 5. Emit output

- Per-channel sections.
- Final "Tip" line + Context Gaps.
- If rc=1 (partial), surface a clear "partial-success" summary.

## Rollback

`/council-check` is read-only for messages. Writes are only read-marker + last_seen_utc.

| Step | Failure mode | Rollback |
|---|---|---|
| 3h (read-marker write) | Atomic rename failed | Keep rendering what was read; next invocation re-renders (safe-idempotent); `rc=1` |
| 3i (channel.json write for last_seen_utc) | Atomic rename failed | Keep rendering; next invocation tries again; `rc=1` with warning |

No destructive rollback needed.

## Error messages

| Condition | Message |
|---|---|
| `.sessions.json` unreadable | `"Cannot read session registry. Is ~/claude-data/channels/ accessible?"` |
| No memberships | `"No channel memberships for this session. Run /council-open <name> \"<purpose>\" or /council-join <name> --as \"<alias>\"."` |
| Not a member of specified channel | `"You are not a member of '<c>'. Run /council-join <c> --as \"<alias>\" first."` |
| Digest unreadable | (renders as Context Gap, not a hard error) |
| Message file unreadable | (renders as Context Gap for that message only) |

## Test coverage targets

Per `tests.md`:

- All 4 return codes (0, 1, 2, 4) reachable.
- Fast path (no unreads) distinct from full-read path.
- Session-id verification pass + fail both tested.
- Rule-1 scan catches patterns missed at post-time (defense-in-depth).
- Priority ordering honored (mentions before questions before tasks).
- Context Gaps aggregation across multi-channel check.
- `--all` flag shows resolved/stale threads too.
- `--with-run-ids` renders GUIDs correctly.
- Circuit breaker trips on 3 consecutive CronCreate-driven failures (but not manual invocations).

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing | 1 |
| Session/channel resolution | 2 |
| Digest + read-marker reads (with caching) | 3 |
| Message iteration + read | 2 |
| Session-id verification | 2 |
| Rule-1 scan (shared helper) | 1 |
| Priority sorting + rendering | 4 |
| Context Gaps aggregation | 2 |
| Read-marker + channel.json updates | 2 |
| Circuit breaker integration | 3 |
| Tests | 8 |
| **Total** | **~30 hours (~4 working days)** |

## Risks

| Risk | Mitigation |
|---|---|
| Polling cost on many channels | Fast path (Step 3c); digest <2KB; 1 file read per channel if no unreads |
| Session-id verification lookup per message slow on long threads | Cache `channel.json.members[]` per channel at start of iteration |
| Rule-1 scan false-positives inflate ⚠️ noise | `--force-raw` at post-time already opts out; read-time scan is purely defense-in-depth |
| Read-marker write failure causes re-render loop | Safe-idempotent; user sees same messages twice but functionally OK |
| Context Gaps table too long | Truncate to first 10 gaps; show count of remaining |
| Circuit breaker wrongly trips during legitimate network blip | 3-consecutive threshold + manual-reset (run `/council-join --force-reclaim`) |

## Forward-links

- `evals/fixtures/council-check-no-unreads/` — fast path.
- `evals/fixtures/council-check-many-unreads/` — prioritization test.
- `evals/fixtures/council-check-with-spoof/` — session-id mismatch in message file.
- `evals/fixtures/council-check-with-injection/` — Rule-1 match at read time.
- `evals/fixtures/council-check-corrupt-digest/` — Context Gap scenario.
- `evals/fixtures/council-check-multi-channel/` — user is member of 3 channels.
- `evals/layer-2-integration/council-check.test.md`.
- `evals/layer-4-adversarial/read-time-spoofing.test.md`.
- `metrics/operational-metrics.md` (iter 12) — poll latency, fast-path rate, circuit-breaker trip rate.
