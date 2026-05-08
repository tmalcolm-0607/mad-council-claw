# Tests: /council-join

Test plan. Maps to 6-layer harness per `wiki/references.md` §13.

## Layer 1 — Unit

| Test ID | Scenario | Expected |
|---|---|---|
| T1-01 | Parse `/council-join my-ch --as "Alice"` | args parsed correctly |
| T1-02 | Parse with `--poll 180 --agent-card ./x.json --force-reclaim` | all flags captured |
| T1-03 | Alias length 0 | `rc=2` |
| T1-04 | Alias length 65+ | `rc=2` |
| T1-05 | Alias with leading/trailing whitespace | trimmed and rejected |
| T1-06 | Poll out of range | `rc=2` |
| T1-07 | Channel name regex (same as /council-open) | invalid → `rc=2` |
| T1-08 | alias-conflict-resolver: Case A (alias absent) | returns Case A, ConsentRequired=false |
| T1-09 | alias-conflict-resolver: Case B (status=disconnected) | returns Case B, ConsentRequired=false |
| T1-10 | alias-conflict-resolver: Case B (status=idle) | returns Case B, ConsentRequired=false |
| T1-11 | alias-conflict-resolver: Case C (status=active, different session) | returns Case C, ConsentRequired=true (if force-reclaim) OR reject |
| T1-12 | alias-conflict-resolver: Case D (status=active, same session) | returns Case D, idempotent |

## Layer 2 — Integration

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | Fresh join (Case A) | member added; read-marker created with last_read_seq=0; `rc=0` |
| T2-02 | Reclaim disconnected alias (Case B) | member updated; read-marker preserved; `rc=0` |
| T2-03 | Reclaim idle alias (Case B) | same as T2-02 |
| T2-04 | Reject active-alias collision without --force (Case C) | `rc=2`; no state change |
| T2-05 | Force-reclaim active alias with user "yes" | preview shown; member updated; `rc=0` |
| T2-06 | Force-reclaim active alias with user "no" | `rc=5`; no state change |
| T2-07 | Same session re-joining (Case D) | idempotent; `rc=0` with "already joined" |
| T2-08 | Join with `--agent-card` | agent_card populated in member entry |
| T2-09 | Join nonexistent channel | `rc=3`; no state change |
| T2-10 | Join with corrupt channel.json | `rc=4` |
| T2-11 | CronCreate unavailable (mock) | `rc=1`; member added; manual-check note |
| T2-12 | `channel.json` write fails mid-update | `rc=4`; member not added; session unchanged |
| T2-13 | `.sessions.json` write fails after channel.json succeeded | `rc=1`; warn; member in channel but not session-registry |
| T2-14 | Digest read fails during state presentation | `rc=0` with Context Gap; limited output |

## Layer 3 — End-to-end + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | Race: two agents reclaim same disconnected alias | atomic rename → one wins; other sees updated state |
| T3-02 | Kill process between channel.json write + CronCreate setup | recovery: preflight sweeps orphans; next join reclaims cleanly |
| T3-03 | Clock drift 10 min | preflight warns; join proceeds; last_seen_utc reflects drift |

## Layer 4 — Adversarial / red-team

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | Alias injection: `"; DROP TABLE members;--"` | stored as literal string; no shell execution; channel.json parses; works |
| T4-02 | Force-reclaim when there is NO current active holder | regress gracefully; treat as Case A or B |
| T4-03 | Race: attacker calls /council-join simultaneously when legit member calls /council-post | atomic channel.json updates serialize; post may fail if session_id was swapped — `post` then fails binding check |
| T4-04 | 5 consecutive force-reclaim attempts from one session | rate limit triggers (`mad.council.a2a.md` §10.5 max-5-reclaim-attempts) |
| T4-05 | Symlink in `--agent-card` pointing to sensitive file | reject with schema validation error |
| T4-06 | Agent Card with description containing "Ignore previous instructions" | stored with suspicious tag; surfaced on /council-check |
| T4-07 | Attempt to reclaim with alias that matches an archive entry pattern | no conflict — archive is separate from active channel.json |

## Layer 5 — CI

| Test ID | Scenario | Expected |
|---|---|---|
| T5-01 | L1-L4 pass | CI gate open |
| T5-02 | Branch coverage ≥95% | CI gate open |
| T5-03 | Mutation testing on alias-conflict-resolver | all mutations caught |

## Fixture requirements

Under `evals/fixtures/council-join/`:

| Fixture | Purpose |
|---|---|
| `active-channel-with-alice/` | channel.json has alice (status=active) for collision tests |
| `disconnected-alice-channel/` | channel.json has alice (status=disconnected) for Case B |
| `idle-alice-channel/` | channel.json has alice (status=idle) for Case B |
| `preserved-marker/` | existing read-marker for alice with last_read_seq=42 |
| `corrupt-channel-json/` | channel.json is malformed JSON |
| `missing-channel/` | `~/claude-data/channels/` has no matching dir |
| `valid-agent-card.json` | for `--agent-card` happy path |
| `5-reclaim-attempts/` | simulates 5 recent reclaim attempts for rate-limit test |
| `symlink-agent-card/` | symlink pointing outside `~/claude-data/` |
| `injection-agent-card.json` | agent card with Rule-1 phrase in description |

## Coverage targets

- **Branch coverage ≥ 95%**.
- **All 4 alias-conflict cases** (A/B/C/D) covered.
- **Reclaim preserves read-marker** (explicit test).
- **Rate limit kicks in at 5 attempts** (T4-04).
- **All 5 return codes reachable**.

## Metrics to emit

- `invoke_skill council-join` span with rc, run_id, case.
- `council_join.alias_conflict_total` counter (labels: case=A|B|C|D).
- `council_join.force_reclaim_total` counter (labels: decision=yes|no).
- `council_join.preflight.duration_ms` histogram.

## Related

- `SKILL.md` — skill contract.
- `plan.md` — implementation plan.
- `skills/council-open/tests.md` — sibling with shared preflight tests.
- `evals/layer-4-adversarial/alias-hijack.test.md` (future) — spoofing scenarios.
