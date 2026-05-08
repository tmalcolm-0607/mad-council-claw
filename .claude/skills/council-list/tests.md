# Tests: /council-list

Simplest skill — read-only. Test plan maps to 6-layer harness.

## Layer 1 — Unit

| Test ID | Scenario | Expected |
|---|---|---|
| T1-01 | Parse `/council-list` (no args) | verbose=false |
| T1-02 | Parse `/council-list --verbose` | verbose=true |
| T1-03 | Parse extra args | rejected |
| T1-04 | Time-ago formatter: 45s | `<1m` |
| T1-05 | Time-ago formatter: 180s | `3m` |
| T1-06 | Time-ago formatter: 7200s | `2h` |
| T1-07 | Time-ago formatter: 90000s | `1d` |
| T1-08 | Unread count: digest.channel_seq=10, marker.last_read_seq=7 | 3 |
| T1-09 | Unread count: digest=10, marker=10 | 0 |
| T1-10 | Unread count: digest=110, marker=10 | `99+` (clamped display) |
| T1-11 | Members render: 3 active, 1 idle, 1 disconnected | `"5 (1 idle, 1 disconnected)"` |
| T1-12 | MAD phase: disabled | `—` |
| T1-13 | MAD phase: enabled, implementation | `implementation` |
| T1-14 | Stale thread render: 2 active (1 stale) | `"2 active (1 stale)"` |

## Layer 2 — Integration

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | No memberships | `rc=2` helpful message |
| T2-02 | 1 channel membership | 1-row table |
| T2-03 | 3 channel memberships | 3-row table |
| T2-04 | Channel with 0 unread | unread=0 |
| T2-05 | Channel with 5 unread | unread=5 |
| T2-06 | Channel with 150 unread | unread=99+ |
| T2-07 | MAD-enabled channel | phase column filled |
| T2-08 | A2A-enabled channel | bridge status shown in verbose |
| T2-09 | Channel with idle members | member column shows "(N idle)" |
| T2-10 | Channel with stale thread | thread count shows "(N stale)" |
| T2-11 | Per-channel digest.json unreadable | row shows "?" for thread/unread counts; Context Gap appended |
| T2-12 | Per-channel channel.json unreadable | row shows "?" for member count; Context Gap appended |
| T2-13 | Per-channel read-marker unreadable | row shows "?" for unread; Context Gap appended |
| T2-14 | `.sessions.json` corrupt | `rc=2` with diagnosis |
| T2-15 | `--verbose` renders expanded per-channel section | all fields present |
| T2-16 | `--verbose` truncates member list at 10 | "and N more" note |
| T2-17 | Mixed: 2 channels healthy, 1 with digest gap | `rc=1`; 2 full rows + 1 partial row; Context Gap listed |
| T2-18 | Many channels (20) | render completes; no truncation (at threshold) |
| T2-19 | More than 20 channels | truncate with "…and N more" note |

## Layer 3 — E2E + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | Concurrent /council-list + /council-post (another agent posting) | read is best-effort; may show stale digest; no crash |
| T3-02 | `~/claude-data/channels/` permission revoked mid-invocation | `rc=4` with FS error |
| T3-03 | All channels' digests unreadable | `rc=1` with many Context Gaps; table shows all "?" values |

## Layer 4 — Adversarial / red-team

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | `.sessions.json` injection (e.g., channel name "../../../etc/passwd") | sessions.json is our own artifact; if malformed, rejected at parse; no file traversal |
| T4-02 | Channel name in .sessions.json references nonexistent channel | render "?" values; Context Gap "channel dir missing" |
| T4-03 | Channel name contains Rule-1 phrase in `channel.json.purpose` | rendered as plain text in `--verbose`; not executed |
| T4-04 | Craft digest.json with suspicious values (channel_seq=9999999, message_count=-1) | render safely; consider validation but don't crash |
| T4-05 | Symlink in channel dir pointing outside ~/claude-data/channels/ | read follows or rejects per atomic-write.ps1 policy (shared helper responsibility) |

## Layer 5 — CI

| T5-01 | L1-L4 pass | gate open |
| T5-02 | Branch coverage ≥95% | gate open |
| T5-03 | Perf: 20-channel list renders in <3s | gate open |

## Fixture requirements

Under `evals/fixtures/council-list/`:

| Fixture | Purpose |
|---|---|
| `no-memberships/` | empty `.sessions.json` for this session |
| `one-channel/` | single membership |
| `three-channels/` | multi-channel |
| `20-channels/` | stress-test rendering |
| `21-channels/` | truncation test |
| `channel-with-150-unread/` | 99+ clamping |
| `channel-mad-enabled/` | phase rendering |
| `channel-a2a-enabled/` | bridge info in verbose |
| `channel-with-idle-members/` | `(N idle)` rendering |
| `channel-with-stale-threads/` | `(N stale)` rendering |
| `corrupt-digest-one-channel/` | Context Gap for that row |
| `corrupt-sessions-json/` | rc=2 |
| `healthy-plus-one-gap/` | mixed — rc=1 |

## Coverage targets

- **Branch coverage ≥ 95%**.
- **All 4 rc codes** reachable.
- **Time-ago formatter** exercises all 4 brackets (<1m, Nm, Nh, Nd).
- **Unread clamping** at 99+ covered.
- **Context Gap** at each source (digest/channel/marker) covered.
- **Verbose mode** renders all fields.
- **Truncation** at 20+ channels covered.

## Metrics to emit

- `invoke_skill council-list` span with rc, channel_count, context_gap_count.
- `council_list.invocations_total` counter (labels: rc, verbose=true|false).
- `council_list.channels_rendered` histogram.
- `council_list.render_duration_ms` histogram.

## Related

- `SKILL.md` — contract.
- `plan.md` — implementation plan.
- `skills/council-check/SKILL.md` — updates what /council-list shows (last_seen_utc).
- `wiki/patterns/state-file-coordination.md` — concurrency model for reads.
