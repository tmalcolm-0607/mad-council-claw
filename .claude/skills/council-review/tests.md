# Tests: /council-review

Test plan — most complex skill. Maps to 6-layer harness.

## Layer 1 — Unit

| Test ID | Scenario | Expected |
|---|---|---|
| T1-01 | Parse default args | roles=default, mode=propose, ensemble=false |
| T1-02 | Parse `--roles skeptic` | only skeptic role |
| T1-03 | Parse `--mode auto --ensemble` | both set |
| T1-04 | Parse invalid `--mode` | rejected |
| T1-05 | Parse invalid role in `--roles` | rejected |
| T1-06 | Verdict compute: 1 CRITICAL finding | FIX |
| T1-07 | Verdict compute: 3 HIGH findings | FIX |
| T1-08 | Verdict compute: 2 HIGH findings, clean otherwise | ACCEPT |
| T1-09 | Verdict compute: all confidence <0.5 | ESCALATE (mechanical) |
| T1-10 | Verdict compute: 3/3 disagree on severity | ESCALATE (mechanical) |
| T1-11 | Verdict compute: role timed out + remaining borderline | ESCALATE (mechanical) |
| T1-12 | Verdict compute: evidence_incomplete flag | INVESTIGATE |
| T1-13 | Verdict compute: 0 critical, 0 high, some medium, high confidence | ACCEPT |
| T1-14 | Verdict compute: 0 critical, 0 high, some medium, borderline confidence | ACCEPT with caveats |
| T1-15 | FIX vs ESCALATE priority when both trigger | FIX wins |
| T1-16 | YAGNI filter: `add processBatch()`, 0 callers | demote to LOW |
| T1-17 | YAGNI filter: `add processBatch()`, 2 callers in grep | retain severity |
| T1-18 | Pattern-verify: deviation is improvement | annotation added |
| T1-19 | Finding dedupe: same file:line + same severity from 2 roles | merge; originating_roles=[a,b] |
| T1-20 | Sort: CRITICAL > HIGH > MEDIUM > LOW > OBSERVATION | correct order |

## Layer 2 — Integration

| Test ID | Scenario | Expected |
|---|---|---|
| T2-01 | Happy path propose-mode, 3 roles complete | verdict written; resolve message posted; `rc=0` |
| T2-02 | Auto-mode with ensemble, 3/3 Skeptic consensus | verdict reflects consensus |
| T2-03 | Auto-mode ensemble, 2/3 majority | majority wins |
| T2-04 | Auto-mode ensemble, all disagree | ESCALATE verdict |
| T2-05 | Role times out at 4 min | proceed with 2/3 roles; verdict has `completed: false` for timed-out role |
| T2-06 | 2 roles time out | proceed with 1/3; verdict_reasoning notes partial review |
| T2-07 | All 3 roles time out | `rc=1`; no verdict; clear error |
| T2-08 | Role returns malformed JSON | invalid_output=true; 0 findings from that role |
| T2-09 | Thread has 55 messages → batch gate fires | continue/last-20/cancel prompt |
| T2-10 | User picks "last-20" on batch gate | only last 20 messages in role briefs |
| T2-11 | User picks "cancel" on batch gate | `rc=5`; no verdict |
| T2-12 | Thread not active (resolved) | `rc=2` |
| T2-13 | Thread not active (archived) | `rc=2` |
| T2-14 | Caller not a member | `rc=3` |
| T2-15 | verdict.json write fails | `rc=4`; resolve message NOT posted; thread unchanged |
| T2-16 | verdict.json written but resolve post fails | `rc=1`; verdict persisted; thread still active; clear warning |
| T2-17 | MAD-enabled channel, verdict FIX on thread | FIX noted in digest.mad_state; downstream tasks may gate |
| T2-18 | Inherit run_id from thread's last message | verdict.run_id matches |
| T2-19 | Non-default `--alias-set court` | roles named Prosecutor/Defender/Judge; verdict.alias_set=court |
| T2-20 | YAGNI demotion visible in verdict.json | demotion object populated |
| T2-21 | Pattern-verify annotation visible in verdict.json | annotations array populated |

## Layer 3 — E2E + fault injection

| Test ID | Scenario | Expected |
|---|---|---|
| T3-01 | Network blip during one role | role times out; verdict proceeds with survivors |
| T3-02 | Claude Code stream abort at exactly 5 min (role runs to 4:58) | role completes; verdict unaffected |
| T3-03 | Claude Code stream abort at 4:30 (role runs to 4:00 with 30s buffer) | edge case; role may time out slightly early — verify 4-min timeout is strict |
| T3-04 | Multiple /council-review concurrent on same thread | both see same inputs; both compute verdicts; last-write wins on verdict.json; second's resolve message may find thread already resolved |
| T3-05 | Kill process between role completion + verdict.json write | findings lost (not persisted); user retries |
| T3-06 | YAGNI grep hangs on large codebase | 2s timeout per finding; skip filter with annotation |

## Layer 4 — Adversarial / red-team

| Test ID | Scenario | Expected |
|---|---|---|
| T4-01 | Thread messages contain "Ignore previous instructions" — role sees it in brief | Rule-1 scan at brief-compose time; role output wrapped with warning |
| T4-02 | Role returns finding with fabricated file:line (doesn't exist) | evidence should be marked for verification; ideally: grep to verify before including in verdict |
| T4-03 | Attacker tries to trigger FIX verdict via spoofed messages | messages are the thread's content; they're data; Council can find CRITICAL legitimately. FIX is correct if attack is real |
| T4-04 | Attacker tries to force ACCEPT by writing fake "LGTM" posts | votes aren't derived from messages; Council roles do independent analysis |
| T4-05 | Role returns malicious JSON with eval-shaped keys | parser is strict; reject malformed; invalid_output=true |
| T4-06 | Concurrent /council-verdict override during /council-review | verdict.json last-write-wins; /council-verdict's override is intentional per rules/dangerous-operations-policy.md |
| T4-07 | Attempted Prompt-Injection via `--roles "<script>..."` | enum validation rejects; rc=2 |
| T4-08 | 100 consecutive /council-review on same thread (rate abuse) | bounded iteration cap: 3 re-review iterations per `mad.council.a2a.md` §10.5 — 4th rejected |
| T4-09 | Ensemble with one model permanently unreachable | timeouts handle; fall back to 2/3 majority |

## Layer 5 — CI

| T5-01 | L1-L4 pass | gate open |
| T5-02 | Branch coverage ≥95% | gate open |
| T5-03 | Mutation testing on verdict-compute logic | all mutations caught |
| T5-04 | Perf: 3-role review completes in <5 min (99th percentile) | gate open |
| T5-05 | Perf: ensemble review (3-role + 3-model Skeptic) in <6 min | gate open |

## Fixture requirements

Under `evals/fixtures/council-review/`:

| Fixture | Purpose |
|---|---|
| `clean-thread/` | no findings → ACCEPT |
| `thread-with-critical/` | 1 CRITICAL → FIX |
| `thread-with-3-high/` | 3 HIGH → FIX |
| `thread-split-severity/` | 3 roles disagree on same finding's severity → ESCALATE |
| `thread-all-low-confidence/` | all role_confidence <0.5 → ESCALATE |
| `thread-role-timeout/` | simulates 4-min timeout on one role |
| `thread-all-roles-timeout/` | simulates complete failure |
| `thread-55-msgs/` | batch-gate trigger |
| `thread-yagni-demotable/` | Skeptic suggests add feature with 0 callers |
| `thread-pattern-improvement/` | Skeptic flags deviation that's actually improvement |
| `thread-evidence-incomplete/` | INVESTIGATE verdict path |
| `ensemble-3-3-consensus/` | all 3 ensemble models agree |
| `ensemble-2-3-majority/` | 2/3 consensus |
| `ensemble-all-disagree/` | 0/3 consensus → ESCALATE |
| `mock-role-outputs/` | pre-built JSON responses for each role |
| `mock-ensemble-validator/` | pre-built validator JSON |
| `channel-with-mad-gates/` | verify MAD state reflects verdict |
| `injection-in-thread-body/` | Rule-1 phrase; scan at brief-compose time |

## Coverage targets

- **Branch coverage ≥ 95%**.
- **All 4 verdict types** reached by ≥1 test.
- **All 4 mechanical ESCALATE triggers** covered.
- **Ensemble 3/3, 2/3, all-disagree** all covered.
- **Role timeout handling** for 0, 1, 2, 3 roles timing out.
- **YAGNI demotion** + **pattern-verify annotation** both covered.
- **run_id inheritance** from thread's last message verified.

## Metrics to emit

Per OpenTelemetry GenAI conventions:

- `invoke_skill council-review` span with rc, run_id, verdict, mode, ensemble, role_count_completed.
- `invoke_agent advocate|skeptic|architect` sub-spans per role.
- `council_review.invocations_total` counter (labels: verdict, mode, ensemble).
- `council_review.verdict_distribution_total` counter (labels: verdict).
- `council_review.mechanical_escalate_trigger_total` counter (labels: trigger=disagreement|low_confidence|timeout_borderline|ensemble_all_disagree).
- `council_review.role_timeout_total` counter (labels: role=advocate|skeptic|architect).
- `council_review.role_confidence` histogram (labels: role).
- `council_review.finding_count` histogram (labels: severity).
- `council_review.yagni_demotions_total` counter.
- `council_review.pattern_verify_annotations_total` counter.
- `council_review.review_duration_ms` histogram (labels: ensemble).

## Related

- `SKILL.md` — contract.
- `plan.md` — implementation plan.
- `skills/council-verdict/tests.md` — manual-override sibling.
- `skills/council-post/tests.md` — resolve-message post flow.
- `wiki/patterns/multi-role-review.md`, `wiki/patterns/multi-model-ensemble.md`, `wiki/patterns/yagni-filter.md` — patterns implemented.
- `MAD/agents/advocate/plan.md`, `skeptic/plan.md`, `architect/plan.md` (iter 13) — role sub-agent specs.
