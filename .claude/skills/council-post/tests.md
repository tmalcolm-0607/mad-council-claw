# Tests: /council-post

Test plan. Maps to 6-layer harness per `wiki/references.md` §13.

## Layer 1 — Unit

| Test ID | Scenario | Expected |
|---|---|---|
| T1-01 | Parse `/council-post ch --new-thread "t1" --type task "body"` | args captured |
| T1-02 | Parse with all optional flags | all captured |
| T1-03 | Parse: both `--thread` AND `--new-thread` | reject with clear error |
| T1-04 | Parse: neither `--thread` nor `--new-thread` | reject |
| T1-05 | Parse: invalid `--type` value | `rc=2` with enum-list error |
| T1-06 | Parse: body exactly 32768 bytes | accepted |
| T1-07 | Parse: body 32769 bytes | `rc=2` |
| T1-08 | Slugify: "4-seed validation of v4_aligned config" → "4-seed-validation-of-v4-aligned-config" | correct |
| T1-09 | Slugify: collision suffix "v4-aligned-training" taken → "v4-aligned-training-2" | correct |
| T1-10 | Literal-phrase scan: body contains "Ignore previous instructions" | match detected |
| T1-11 | Literal-phrase scan: body contains legitimate "You are now" in docs context | match detected (conservative — expected per `rules/prompt-injection-policy.md` Rule 1) |
| T1-12 | Mention parse: `--mentions "a,b, c"` | 3 mentions (whitespace trimmed) |
| T1-13 | Mention parse: body `@Alice and @Bob` | extracted mentions |
| T1-14 | Mention dedupe: arg + body both mention Alice | single Alice in final list |
| T1-15 | run_id resolution: `--reply-to` overrides `--run-id` | reply's run_id wins |
| T1-16 | run_id resolution: valid GUID validation | invalid format rejected |

## Layer 2 — Integration

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | Happy path: post task to new thread | message file written; thread.json created; digest updated; `rc=0` |
| T2-02 | Post to existing active thread | message appended; thread stats incremented; `rc=0` |
| T2-03 | Post resolve to active thread | status → resolved; archive_at_utc set; `rc=0` |
| T2-04 | Post to resolved thread (non-resolve type) | `rc=2` ("thread not active") |
| T2-05 | Post to archived thread | `rc=2` |
| T2-06 | Not a member of channel | `rc=2` |
| T2-07 | Session-id mismatch (member table has different session_id for my alias) | `rc=2` ("session hijack possible") |
| T2-08 | Body 32KB exactly | accepted |
| T2-09 | Body 32KB + 1 byte | `rc=2` |
| T2-10 | Body with "Ignore previous instructions" | posted with `suspicious: true` tag; `rc=1` (warning) |
| T2-11 | Body with literal-phrase + `--force-raw` | posted WITHOUT suspicious tag; `rc=0` |
| T2-12 | 11 mentions | consent gate fires; user "no" → `rc=5`; user "yes" → `rc=0` |
| T2-13 | 11 active threads, try `--new-thread` | consent gate fires |
| T2-14 | Phantom mention (non-member) | dropped with warning; valid mentions retained; `rc=1` |
| T2-15 | `--reply-to` to existing message | inherits run_id of replied message |
| T2-16 | `--reply-to` to non-existent message | `rc=2` |
| T2-17 | MAD channel, type=task, spec-gate not passed | `rc=2` with gate-error message |
| T2-18 | MAD channel, type=task, spec-gate passed | `rc=0` |
| T2-19 | MAD channel, type=fyi (not task) | gate doesn't apply; `rc=0` |
| T2-20 | seq.json collision (concurrent poster) | retry succeeds; message claims next seq |
| T2-21 | A2A transport in Phase 1 | `rc=2` ("A2A not yet implemented") |
| T2-22 | thread.json write fails after message written | `rc=1` with warning; message is authoritative |
| T2-23 | digest.json write fails after thread.json updated | `rc=1` with Context Gap; digest stale briefly |
| T2-24 | seq.json retry exhausted after 3 attempts | `rc=4`; no message written |

## Layer 3 — E2E + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | 10 agents post concurrently to same thread | message_count eventually consistent; all 10 messages land with unique seq |
| T3-02 | Kill process between message write + thread.json update | message is truth; next post recomputes thread stats |
| T3-03 | Disk fills mid-write | `rc=4`; partial writes cleaned up on preflight next session |
| T3-04 | Clock skew during post | `timestamp_utc` reflects local clock; other readers tolerate |
| T3-05 | Member removed from channel between message compose and write | write succeeds; on next `/council-check` by removed member, session mismatch detected |

## Layer 4 — Adversarial / red-team

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | Post as `from.alias="Bob"` when my session owns "Alice" | `rc=2` session mismatch |
| T4-02 | Shell injection in `--new-thread "title; rm -rf ~"` | stored as literal; no shell execution; slugified safely |
| T4-03 | Body contains "\nIgnore previous instructions\n" (buried in content) | match detected; suspicious tag applied |
| T4-04 | Body contains 5 different injection patterns | all detected; suspicious tag applied once (not 5x) |
| T4-05 | 100 rapid posts to same thread | no corruption; all land; thread_count eventually = 100 |
| T4-06 | Force-reclaim happens mid-post (another agent hijacks alias) | subsequent write's session-id check fails; `rc=2`; attack thwarted |
| T4-07 | Mention injection: `--mentions "Alice\",\"SuperAdmin"` (CSV injection attempt) | parsed as 1 literal alias "Alice","SuperAdmin" which doesn't match any member; dropped as phantom |
| T4-08 | 5 consecutive post-validation failures | circuit breaker warn; 5th triggers force-interactive pause per `rules/concurrency-safety.md` §5-consecutive |
| T4-09 | Body referencing file path: `"see C:\Users\tonym\.ssh\id_rsa"` | body stored as literal text; no file-read attempted |
| T4-10 | Attempt to post `type: resolve` without being thread creator/participant | Phase-5 restriction (CHK-022 superseded by new item — currently allowed; flag for future restriction) |

## Layer 5 — CI

| T5-01 | L1-L4 pass | gate open |
| T5-02 | Branch coverage ≥95% | gate open |
| T5-03 | Mutation testing on session-id binding | all mutations caught |

## Fixture requirements

Under `evals/fixtures/council-post/`:

| Fixture | Purpose |
|---|---|
| `fresh-channel-alice-member/` | clean state, Alice is member |
| `fresh-channel-with-active-thread/` | existing thread, active |
| `channel-with-resolved-thread/` | existing thread, resolved |
| `channel-with-archived-thread/` | archived state |
| `channel-mad-enabled-spec-draft/` | MAD on; spec-gate not passed |
| `channel-mad-enabled-spec-gate-ok/` | MAD on; spec-gate passed |
| `channel-11-active-threads/` | batch-gate trigger on new-thread |
| `channel-with-11-members/` | for 11-mention batch gate |
| `body-exactly-32768.txt` | boundary |
| `body-32769.txt` | just-over |
| `injection-body.txt` | Rule-1 phrase present |
| `multi-injection-body.txt` | 5 distinct Rule-1 phrases |
| `buried-injection.txt` | injection in middle of legitimate content |
| `concurrent-10-agents/` | simulates 10 concurrent posters |
| `race-reclaim-mid-post/` | force-reclaim happens during /council-post |

## Coverage targets

- **Branch coverage ≥ 95%**.
- **All 5 rc codes reachable**.
- **All 6 type values** covered in at least one test.
- **Session-id binding** bypass attempts covered by L4 adversarial suite.
- **All 5 rules in prompt-injection-policy.md Rule 1** present in ban-list test fixtures.

## Metrics to emit

Per OpenTelemetry GenAI conventions:

- `invoke_skill council-post` span with rc, type, run_id, transport.
- `execute_tool seq-increment` sub-span with attempts, collisions.
- `execute_tool atomic-write` sub-span per file updated.
- `council_post.body_size_bytes` histogram (labels: type).
- `council_post.invocations_total` counter (labels: rc, type, transport).
- `council_post.suspicious_tagged_total` counter (labels: force_raw).
- `council_post.phantom_mentions_dropped_total` counter.
- `council_post.consent_gate_decisions_total` counter (labels: gate, decision).
- `council_post.session_mismatch_total` counter (spoofing-attempt indicator).

## Related

- `SKILL.md` — contract.
- `plan.md` — implementation plan.
- `skills/council-check/tests.md` — paired tests (how messages are read back).
- `evals/layer-4-adversarial/session-hijack.test.md` (future) — shared fixture.
