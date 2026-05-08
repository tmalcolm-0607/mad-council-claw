# Implementation Plan: /council-list

Target: MAD.Council Phase 1 MVP per `mad.council.a2a.md` §12. Simplest skill — pure read.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/channel-helpers.ps1` (read helpers) | iter 11 | ⏸ |
| `scripts/context-gaps-reporter.ps1` (shared with /council-check) | iter 11 | ⏸ |

No new helpers required beyond what other skills already need.

## Implementation steps

### 1. Parse arguments

- Optional `--verbose` flag.

### 2. Read .sessions.json

- `~/claude-data/channels/.sessions.json`.
- On read fail → `rc=2`/`rc=4`.
- Parse; extract this session's `.channels`.
- Empty → `rc=2` ("no memberships").

### 3. Build per-channel read tasks

For each membership, schedule parallel reads:

- `<channel>/digest.json`
- `<channel>/channel.json`
- `<channel>/read-markers/<alias>.json`

### 4. Execute reads + build rows

For each channel:

- Collect the 3 file contents (or gaps).
- Compute row: threads, unread, MAD phase, activity time-ago, members.
- Record any Context Gaps per channel.

### 5. Render default table

- Fixed-width columns; right-align numbers.
- Time-ago formatted: `<1m` / `<N>m` / `<N>h` / `<N>d` / `<Nw>`.

### 6. If --verbose, render expanded sections per channel

- Purpose, creation metadata, MAD gate details, A2A status, full member list with last-seen, recent archives within 60-min window.

### 7. Append summary line

- Total channel count, total unread, polling-active count.

### 8. Append Context Gaps section (if any)

- Table with source + status + impact.

## Error messages

| Condition | Message |
|---|---|
| `~/claude-data/channels/` missing | `"No Claude Code channels directory found. Run /council-open or /council-join first."` |
| `.sessions.json` corrupt | `"Session registry is corrupt. Run /council-list --help or inspect ~/claude-data/channels/.sessions.json"` |
| No memberships | `"No channel memberships for this session. Run /council-open <name> or /council-join <name> first."` |

## Test coverage

- 0, 1, N channels.
- Per-channel read failure (Context Gap).
- `--verbose` expansion.
- MAD-enabled + MAD-disabled channels.
- A2A-enabled + A2A-disabled channels.
- Stale thread rendering.
- Idle/disconnected member rendering.

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing | 0.5 |
| Session read | 0.5 |
| Parallel channel reads | 2 |
| Row computation (time-ago formatting, stale detection) | 2 |
| Default table render | 2 |
| Verbose rendering | 2 |
| Context Gaps aggregation | 1 |
| Tests | 3 |
| **Total** | **~13 hours (~1.5 working days)** |

Simplest skill. Reuses read-helpers from other skills.

## Risks

| Risk | Mitigation |
|---|---|
| Slow on many channels | Parallel reads; 5s cap per dep; truncate table at 20 channels with "…and N more" |
| Stale digest causes wrong unread count | Use channel_seq comparison; user can run /council-check to refresh |
| `--verbose` outputs too much | Cap per-channel expanded section; truncate member lists >10 with "and N more" |

## Forward-links

- `evals/fixtures/council-list-no-memberships/`
- `evals/fixtures/council-list-single-channel/`
- `evals/fixtures/council-list-many-channels/`
- `evals/fixtures/council-list-verbose-mad-enabled/`
- `evals/fixtures/council-list-with-gaps/`
- `evals/layer-2-integration/council-list.test.md`
