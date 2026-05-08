# Tests: /council-leave

Test plan. Maps to 6-layer harness.

## Layer 1 — Unit

| Test ID | Scenario | Expected |
|---|---|---|
| T1-01 | Parse `/council-leave my-ch` | channel=my-ch captured |
| T1-02 | Parse with extra positional args | rejected |
| T1-03 | last-member detection: only me, status=active | true |
| T1-04 | last-member detection: me + another active member | false |
| T1-05 | last-member detection: me + another member but they're disconnected | true (I'm the only active) |
| T1-06 | last-member detection: me + another idle | true |
| T1-07 | Completion Report scan: count threads created_by me | correct count |
| T1-08 | Completion Report scan: count tasks picked up | correct |
| T1-09 | Completion Report scan: tasks-completed logic (type:task from me, later type:resolve in same thread) | correct |
| T1-10 | Completion Report scan: task-dropped logic (active + no resolve + no other recent activity) | correct |
| T1-11 | Report includes unique run_ids | deduped list |
| T1-12 | Consent prompt timeout at 60s | treat as "no" |
| T1-13 | Preview renders counts correctly | matches actual state |
| T1-14 | Archive path format: `<channel>-<YYYYMMDD-HHMMSS>/` | correct format |

## Layer 2 — Integration

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | Not-last leave: regular case | `rc=0`; member status→disconnected; report written; CronDelete called; `.sessions.json` updated |
| T2-02 | Last-member + user "yes" | archive move succeeds; report IN the archive dir; channel gone from active; `rc=0` |
| T2-03 | Last-member + user "no" | channel dormant; my member disconnected; no archive; `rc=1` |
| T2-04 | Last-member + 60s timeout | same as T2-03 but `rc=5` |
| T2-05 | Channel doesn't exist | `rc=2` |
| T2-06 | Not a member (session_id no match) | `rc=2` |
| T2-07 | CronDelete fails | `rc=1` (warn); leave still succeeds |
| T2-08 | `.sessions.json` write fails | `rc=1` (warn); leave still succeeds |
| T2-09 | Completion Report write fails | `rc=4`; channel.json NOT updated (rollback); user retries |
| T2-10 | channel.json update fails after report written | `rc=4`; explicit error; user inspects state |
| T2-11 | Archive move fails mid-operation | `rc=4`; explicit manual-recovery instruction |
| T2-12 | Large channel (100 threads, 1000 messages) | perf: report scan completes in <30s |
| T2-13 | MAD-enabled channel: archive includes spec.md/plan.md/tasks.md | all artifacts present in archive |
| T2-14 | Channel with pending Council reviews | report's `verdict_pending[]` lists them; summary shows warning |
| T2-15 | Channel with A2A bridge members | leave doesn't affect remote members |

## Layer 3 — E2E + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | Concurrent leave: two agents in 2-member channel both run /council-leave simultaneously | one goes "yes" on archive consent (wins race), other sees channel already archived |
| T3-02 | Kill process between report write + archive move | next session startup: preflight detects orphan; offers to complete archive or restore |
| T3-03 | Disk fill mid-archive-move | half-move state; explicit error; manual recovery doc referenced |
| T3-04 | Archive target dir already exists (same-second collision) | append -random-4-chars; retry; documented in output |
| T3-05 | Report scan hits permission denied on one thread | context_gaps[] populated; report still valid |

## Layer 4 — Adversarial / red-team

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | Leave with alias="SuperAdmin" but session_id doesn't match | `rc=2` (not a member) — session_id check catches |
| T4-02 | Forge a channel.json with me as "disconnected" (pretending I was already gone) | my session_id still matches the "disconnected" entry; reclaim semantics apply (not leave) — user should use /council-join --force-reclaim if intentional |
| T4-03 | Trigger archive consent, then race: another agent joins at the exact moment I consent | archive move should fail gracefully (new member is now "active"); dormant-channel state instead of archive |
| T4-04 | Inject path-traversal in channel name (attempt to archive outside ~/claude-data/channels/archive/) | name already validated by /council-open regex; re-check on leave; reject with clear error |
| T4-05 | Attempt to generate Completion Report for 10K threads (DoS via fixture) | timeout per-thread; partial report with context_gaps; `rc=1` (warning) |
| T4-06 | Completion Report with body containing Rule-1 phrase (from someone's message quoted in "what I answered") | report is data; render without execution; downstream consumers apply Rule-3 flag |

## Layer 5 — CI

| T5-01 | L1-L4 pass | gate open |
| T5-02 | Branch coverage ≥95% | gate open |
| T5-03 | Mutation testing on last-member detection logic | all mutations caught |
| T5-04 | Archive move atomicity: inject mid-move failure; verify no partial state on success path | gate open |

## Fixture requirements

Under `evals/fixtures/council-leave/`:

| Fixture | Purpose |
|---|---|
| `not-last-member-basic/` | 3 active members, I'm leaving |
| `last-member-solo/` | only me as member |
| `last-member-with-disconnected-peer/` | me + disconnected peer; I'm last active |
| `last-member-with-idle-peer/` | me + idle peer; I'm last active |
| `large-channel-perf/` | 100 threads, 1000 messages |
| `corrupt-thread-subset/` | scan hits unreadable thread dirs |
| `pending-reviews/` | I participated in threads awaiting Council verdict |
| `mad-enabled-with-artifacts/` | ensure archive includes spec/plan/tasks |
| `mock-consent-yes.ps1` / `mock-consent-no.ps1` / `mock-consent-timeout.ps1` | consent-response mocks |
| `archive-target-collision/` | same-timestamp-second collision |
| `concurrent-leave-race/` | 2 agents attempting to archive simultaneously |

## Coverage targets

- **Branch coverage ≥ 95%**.
- **All 5 rc codes** reachable.
- **All 3 last-member scenarios** (solo / disconnected-peer / idle-peer) covered.
- **All 3 consent outcomes** (yes / no / timeout) covered.
- **Archive atomicity** explicitly tested (half-move scenario).
- **Completion Report** verified to capture: threads_{created,resolved,participated}, tasks_{picked_up,completed,dropped}, questions_{asked,answered}, verdicts_issued, run_ids_involved, verdict_pending.

## Metrics to emit

Per OpenTelemetry GenAI conventions:

- `invoke_skill council-leave` span with rc, run_id, was_last_member, archived.
- `execute_tool atomic-write` sub-spans for each state update.
- `execute_tool CronDelete` sub-span.
- `council_leave.invocations_total` counter (labels: rc, was_last_member, archived).
- `council_leave.completion_report.scan_duration_ms` histogram (labels: thread_count_bucket).
- `council_leave.archive_consent_decisions_total` counter (labels: decision=yes|no|timeout).
- `council_leave.verdict_pending_count` histogram — measure of "leaving work behind."

## Related

- `SKILL.md` — contract.
- `plan.md` — implementation plan.
- `skills/council-join/tests.md` — complements (rejoin after leave).
- `wiki/patterns/completion-report-protocol.md`.
- `evals/layer-3-fault-injection/archive-half-move.test.md` (future) — shared fixture.
