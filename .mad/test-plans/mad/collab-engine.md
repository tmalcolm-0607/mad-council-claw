# Test Plan: collab-engine

## Metadata
- **Scenario ID**: collab-engine
- **Project**: mad
- **Feature**: Collab Engine v1 (Lobster-grounded multi-agent collaboration platform)
- **Spec**: `specs/15-collab-engine/spec.md`
- **Plan**: `specs/15-collab-engine/plan.md`
- **Tasks**: `specs/15-collab-engine/tasks.md` (42 tasks)
- **Generated**: 2026-05-02
- **Verify Script**: `.mad/scratch/verify-collab-engine.sh`
- **Verification Spec**: `plan.md` §3 — `new_feature` change type; <500ms latency overhead per spawn; +10% token cost ceiling
- **Critical-path tasks**: T010 (R1 spike, priority 0), T015 (Supervisor, priority 0), T024 (audit writer, priority 0), T039 (SC battery)

---

## Test Group: US-001 — Engine bootstraps a CoClaw single-player session (P1)

**Traces to**: FR-CORE-001, FR-CORE-002, FR-CORE-003, FR-CORE-004 (joint MVP gate per T020)

### TC-001a — Fresh-clone /loop "trivial spec" produces all 3 substrate artifacts

**Before (engine not yet implemented OR engine.disabled = true)**:
```bash
test ! -f "${CHANNEL_DIR:-/tmp/test-channel}/messages/"*"-supervisor.json"
echo "EXPECTED: pre-impl state"
# Expected output: EXPECTED: pre-impl state
```

**Action**:
Invoke `/loop "trivial spec"` on a fresh kit clone with `policy.json:engine.disabled = false`.

**After (passing state)**:
```bash
ls "${CHANNEL_DIR}/messages/"*"-supervisor.json" 2>&1
ls "${CHANNEL_DIR}/messages/"*"-peer-1.json" 2>&1
ls "${CHANNEL_DIR}/retros/"*".json" 2>&1
# Expected: 3 files exist (supervisor message, ≥1 peer-agent message, retro)
```

**Assertions**:
- [ ] Supervisor message file exists at `<channel-dir>/messages/<seq>-<ts>-supervisor.json`
- [ ] At least one peer-agent message file exists at `<channel-dir>/messages/<seq>-<ts>-peer-1.json`
- [ ] Retro file exists at `<channel-dir>/retros/<run_id>.json`
- [ ] Exit code 0

### TC-001b — 25-min self-paced wakeup advances the loop

**Action**: Open active channel; wait ~25 min (or simulate via scheduled-wake fixture).

**After**:
```bash
jq -r '.last_seen_utc' "${CHANNEL_DIR}/channel.json" 2>&1
# Expected: timestamp updated within last 30 min from start
```

**Assertions**:
- [ ] `channel.json:last_seen_utc` advances after wakeup
- [ ] Status update line emitted to stdout

### TC-001c — Ctrl-C produces interrupt-retro

**Action**: Start session, send SIGINT mid-spawn.

**After**:
```bash
jq -r '.outcome' "${CHANNEL_DIR}/retros/"*".json" 2>&1 | head -1
# Expected output contains: interrupted
```

**Assertions**:
- [ ] Retro file exists with `outcome: interrupted`
- [ ] No orphan `.tmp` files remain in `<channel-dir>/`
- [ ] Exit code 0 (clean exit, not hang)

---

## Test Group: US-002 — Per-agent identity + run_id correlation (P1)

**Traces to**: FR-CORE-002 (run_id), FR-CORE-003 (agent_id)

### TC-002a — run_id generated at session start

**Action**: Start a session.

**After**:
```bash
jq -r '.run_id' "${CHANNEL_DIR}/channel.json" 2>&1
# Expected: a UUID v4 (8-4-4-4-12 hex format)
```

**Assertions**:
- [ ] `channel.json:run_id` matches UUID v4 pattern: `[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}`
- [ ] `.mad/scratch/active-run.json` contains the same run_id

### TC-002b — Every artifact stamps the same run_id

**Action**: After running TC-002a's session.

**After**:
```bash
find "${CHANNEL_DIR}/messages" -name "*.json" -exec jq -r '.run_id' {} \; 2>&1 | sort -u | wc -l
# Expected: 1 (single distinct run_id across all messages)
```

**Assertions**:
- [ ] All artifacts in `<channel-dir>/messages/`, `verdicts/`, `retros/` carry the same `run_id`
- [ ] PR-comment HTML stamps (if any) contain `<!-- mad-run-id: <uuid> -->`

### TC-002c — Three parallel peer-agents have unique agent_ids

**Action**: Spawn 3 parallel peer-agents in one session.

**After**:
```bash
find "${CHANNEL_DIR}/messages" -name "*-peer-*.json" -exec jq -r '.agent_id' {} \; 2>&1 | sort -u | wc -l
# Expected: 3
```

**Assertions**:
- [ ] 3 unique agent_ids across 3 parallel peer-agents
- [ ] Supervisor's agent_id is distinct from any peer's
- [ ] All agent_ids match UUID v4 format

---

## Test Group: US-003 — Mandatory pre-close signal capture (P1)

**Traces to**: FR-CORE-004 (Step 9 retro 5+7 fields), FR-CORE-005 (delete-and-retry gate)

### TC-003a — Retro file complete with 5 scores + 7 pattern fields

**Action**: Run a session to completion.

**After**:
```bash
RETRO=$(ls "${CHANNEL_DIR}/retros/"*.json | head -1)
jq '.scores | length' "$RETRO" 2>&1
jq '.patterns | keys | length' "$RETRO" 2>&1
# Expected: 5 then 7 (one per line)
```

**Assertions**:
- [ ] `jq '.scores | length'` returns 5
- [ ] `jq '.patterns | keys | length'` returns 7
- [ ] Pattern keys include: `what_worked, what_was_hard, improvisation, recurring_pattern, skill_gap, tsg_gap, environment_blockers`
- [ ] Score keys include: `accuracy, completeness, tsg_alignment, dx, confidence`

### TC-003b — Engine refuses to terminate without retro (delete-and-retry)

**Action**: Inject a test fixture that skips the retro write at session end.

**After**:
```bash
# (engine should have exited non-zero with BLOCK message)
echo "Last exit code was: $LAST_EXIT_CODE"
# Expected: non-zero
grep -F "[BLOCK] Step 9 incomplete" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: line containing "[BLOCK] Step 9 incomplete"
```

**Assertions**:
- [ ] Session-end exit code is non-zero (1 or higher)
- [ ] Stdout contains literal "[BLOCK] Step 9 incomplete"
- [ ] No truncated `<channel-dir>/retros/<run_id>.json` left behind

### TC-003c — Retro with missing pattern fields prompts for fill

**Action**: Inject fixture with retro file present but missing 3 of 7 pattern fields.

**After**:
```bash
grep -F "missing pattern fields" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: prompt line about missing fields
```

**Assertions**:
- [ ] Engine prompts for missing fields before exit (not silent)
- [ ] After fill, normal exit 0

---

## Test Group: US-004 — Per-agent token + $ cost ledger with hard-stop (P2)

**Traces to**: FR-COST-001, FR-COST-002 (with retro_reserve_usd carve-out per iter 6 P0), FR-COST-003

### TC-004a — Cost ledger appends per-spawn deltas

**Action**: Run 3 peer-agent spawns.

**After**:
```bash
wc -l < "${CHANNEL_DIR}/cost-ledger.jsonl" 2>&1
# Expected: 3
jq -r '.cost_usd' "${CHANNEL_DIR}/cost-ledger.jsonl" 2>&1 | head -1
# Expected: a number > 0
```

**Assertions**:
- [ ] 3 lines in `cost-ledger.jsonl` after 3 spawns
- [ ] Each line has `{ts, agent_id, run_id, tokens_in, tokens_out, cost_usd, spawn_outcome}` keys

### TC-004b — Soft-cap WARN at 80%

**Action**: Configure `soft_warn_usd: 1.00, hard_halt_usd: 1.25, retro_reserve_usd: 0.05`. Run session whose cumulative spend reaches $0.80 (80% of soft cap).

**After**:
```bash
grep -F "WARN: 80% budget consumed" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: WARN line
```

**Assertions**:
- [ ] Stdout contains "WARN" + "80%" tokens
- [ ] Session continues running (no halt)

### TC-004c — Hard-cap halt with retro reserve respected

**Action**: Configure `hard_halt_usd: 0.10, retro_reserve_usd: 0.05`. Run session that would exceed $0.10.

**After**:
```bash
jq -r '.type' "${CHANNEL_DIR}/verdicts/"*.json 2>&1 | grep -F BUDGET_EXCEEDED
# Expected: BUDGET_EXCEEDED
jq -r '.outcome' "${CHANNEL_DIR}/retros/"*.json 2>&1 | grep -F budget_exceeded
# Expected: budget_exceeded
```

**Assertions**:
- [ ] Non-retro spawns halt at `effective_hard_halt = $0.05`
- [ ] Retro write succeeds within `retro_reserve_usd = $0.05`
- [ ] Verdict `type: BUDGET_EXCEEDED` written
- [ ] Retro `outcome: budget_exceeded` accepted as terminal (no [BLOCK] from FR-CORE-005)
- [ ] Overshoot ≤ 1 spawn-cycle beyond `hard_halt_usd` (SC-005)

### TC-004d — Cost-cap-disabled informational marker

**Action**: Set `policy.json:cost_caps.disabled = true`. Run session.

**After**:
```bash
grep -F "cost caps disabled" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: line containing "cost caps disabled"
```

**Assertions**:
- [ ] Stdout contains "cost caps disabled — ledger only"
- [ ] `cost-ledger.jsonl` still receives writes
- [ ] No halt regardless of spend

---

## Test Group: US-005 — Hash-chained audit log + Query-AuditLog (P2)

**Traces to**: FR-AUDIT-001 (with explicit JCS RFC 8785 formula per iter 6 P0), FR-AUDIT-002

### TC-005a — Audit chain valid on 5 events

**Action**: Generate a session producing 5 audit events (consent_gate / verdict / retro / allowlist_mutation / soul_mutation).

**After**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -Verify "${CHANNEL_DIR}/audit-log.jsonl" 2>&1
# Expected: "OK chain length 5"
echo "exit: $?"
# Expected: exit: 0
```

**Assertions**:
- [ ] `Query-AuditLog.ps1 -Verify` returns "OK chain length 5"
- [ ] Exit code 0
- [ ] Each line has all required fields: `{ts, sha256, prev_sha256, type, run_id, agent_id, payload}`
- [ ] Each line's `prev_sha256` matches previous line's `sha256` (or 64 zero-bytes for line 1)

### TC-005b — Tampered chain detected

**Action**: Modify any single byte in `audit-log.jsonl` line 3's `payload` field.

**After**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -Verify "${CHANNEL_DIR}/audit-log.jsonl" 2>&1
# Expected: error pointing at line 3
echo "exit: $?"
# Expected: exit: non-zero
```

**Assertions**:
- [ ] Exit code non-zero
- [ ] Error message references line 3 specifically
- [ ] No false-negatives on 100 injected tampers (SC-003)

### TC-005c — Query-AuditLog -Filter returns matching entries

**Action**: Generate audit log with mixed `type` values; run filter.

**After**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -Filter "type=verdict" "${CHANNEL_DIR}/audit-log.jsonl" 2>&1 | jq -r '.type' | sort -u
# Expected: only "verdict"
```

**Assertions**:
- [ ] Only entries with `type: verdict` returned
- [ ] No `-Repair` mode in `Get-Help` output (corruption is terminal per iter 6)

---

## Test Group: US-006 — Skills/MCP allowlist + version pinning (P2)

**Traces to**: FR-GOV-001, FR-GOV-002, SC-006 (<100ms reject)

### TC-006a — Un-allowlisted skill rejected

**Action**: Invoke a skill not present in `.mad/policy/skills-allowlist.json`.

**After**:
```bash
echo "Last exit code: $LAST_EXIT_CODE"
# Expected: non-zero
grep -F "SKILL_NOT_ALLOWED" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: rejection message
```

**Assertions**:
- [ ] Exit code non-zero
- [ ] Stdout contains "SKILL_NOT_ALLOWED"
- [ ] Rejection latency < 100ms (SC-006) — measured by `time` wrapper
- [ ] Skill body NOT loaded before rejection (verify via debug log absence of body-parse line)

### TC-006b — Modified skill body rejected with VERSION_MISMATCH

**Action**: Allowlist a skill, then modify its SKILL.md body by 1 byte.

**After**:
```bash
echo "Last exit code: $LAST_EXIT_CODE"
# Expected: non-zero
grep -F "SKILL_VERSION_MISMATCH" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: VERSION_MISMATCH
```

**Assertions**:
- [ ] Exit code non-zero
- [ ] Stdout contains "SKILL_VERSION_MISMATCH"

### TC-006c — Expired allowlist entry rejected

**Action**: Allowlist a skill with `expires_at` in the past.

**After**:
```bash
grep -F "SKILL_EXPIRED" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: SKILL_EXPIRED
```

**Assertions**:
- [ ] Stdout contains "SKILL_EXPIRED"

---

## Test Group: US-007 — Multi-model adversarial review activated (P2)

**Traces to**: FR-MULTI-001 (5 skills wired), FR-MULTI-002 (S1-S15 inject)

### TC-007a — pr-review --council produces both result files

**Action**: Run `/pr-review --council` on a sample PR (or fixture).

**After**:
```bash
ls "${MULTIMODEL_OUT_DIR}/opus-result.json" "${MULTIMODEL_OUT_DIR}/gpt-result.json" 2>&1
# Expected: both files exist
```

**Assertions**:
- [ ] Both result files exist after invocation
- [ ] Cross-model agreement table emitted to skill output
- [ ] S1-S15 sections present in dispatcher prompt (verified via dispatcher debug log)

### TC-007b — Both-flag-CRITICAL → HARD BLOCK

**Action**: Use a fixture where both Opus + GPT independently flag the same finding as CRITICAL.

**After**:
```bash
grep -F "HARD BLOCK" "${PR_REVIEW_OUTPUT}" 2>&1
# Expected: HARD BLOCK line
```

**Assertions**:
- [ ] Output contains "HARD BLOCK"
- [ ] Vote is one of: `wait-for-author` or `reject` (never `approve`)

### TC-007c — Copilot CLI absent → same-model role-split fallback

**Action**: Run with Copilot CLI not on PATH.

**After**:
```bash
grep -F "Copilot CLI unavailable" "${PR_REVIEW_OUTPUT}" 2>&1
# Expected: Context Gap line
```

**Assertions**:
- [ ] Output contains "Copilot CLI unavailable; using same-model role-split fallback"
- [ ] Both Role A (security) + Role B (correctness) outputs produced

---

## Test Group: US-008 — Heartbeat + cron proactive execution (P3)

**Traces to**: FR-PROACTIVE-001, SC-007

### TC-008a — 5 fires over 25 min on `*/5 * * * *`

**Action**: Set `cron.json:schedule = "*/5 * * * *"`. Wait 25 min (or simulate).

**After**:
```bash
wc -l < ".mad/scratch/cron-fires.jsonl" 2>&1
# Expected: 5
```

**Assertions**:
- [ ] 5 fires recorded in `cron-fires.jsonl`
- [ ] Drift ≤ 5% (SC-007)
- [ ] Each fire emits one `cron_fire` event in audit log

### TC-008b — CRON_OVERLAP logged on fire-during-fire

**Action**: Inject fixture where fire #2 starts while fire #1 is still running.

**After**:
```bash
grep -F "CRON_OVERLAP" ".mad/scratch/cron-fires.jsonl" 2>&1
# Expected: at least one CRON_OVERLAP line
```

**Assertions**:
- [ ] At least one "CRON_OVERLAP" line in `cron-fires.jsonl`
- [ ] No parallel fires unless `cron.json:max_concurrent > 1` (defaults to 1 for v1)

### TC-008c — Mid-fire halt + resume from checkpoint

**Action**: Halt engine mid-fire; let next cron fire.

**After**:
```bash
jq -r '.checkpoint_resumed' ".mad/scratch/cron-fires.jsonl" 2>&1 | grep -c true
# Expected: ≥1
```

**Assertions**:
- [ ] At least one fire marked `checkpoint_resumed: true`

---

## Test Group: Edge Cases (cross-cutting)

**Traces to**: spec.md §Edge Cases (8 entries)

### TC-EDGE-01 — Peer-agent killed mid-execution

**Action**: SIGKILL a peer-agent process mid-spawn.

**After**:
```bash
grep -F '"outcome": "interrupted"' "${CHANNEL_DIR}/retros/"*.json 2>&1
# Expected: interrupt-retro
```

**Assertions**:
- [ ] Engine writes interrupt-retro
- [ ] Engine retries within retry budget (does not abandon)

### TC-EDGE-02 — Simultaneous council-resolve on same thread

**Action**: Fire 2 concurrent `/council-resolve` invocations on the same thread.

**After**:
```bash
# Second resolver should be idempotent no-op per concurrency-safety.md retry-rc=4
echo "Both invocations completed"
```

**Assertions**:
- [ ] First invocation: succeeds (rc=0)
- [ ] Second invocation: idempotent no-op (rc=0 OR rc=4 with skip-message)
- [ ] Thread state consistent

### TC-EDGE-03 — Audit log chain broken at startup

**Action**: Pre-corrupt `audit-log.jsonl`. Start engine.

**After**:
```bash
echo "Last exit code: $LAST_EXIT_CODE"
# Expected: non-zero
grep -F "AUDIT_CORRUPTED" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
# Expected: AUDIT_CORRUPTED
```

**Assertions**:
- [ ] Engine refuses to start
- [ ] Stdout contains "AUDIT_CORRUPTED"
- [ ] No `-Repair` option offered (corruption is terminal; new channel required)

### TC-EDGE-04 — Cost-cap hard-stop mid-spawn (carve-out)

**Action**: Trigger hard-cap mid-spawn.

**After**: Same as TC-004c but verify carve-out specifically.
**Assertions**:
- [ ] Minimal-retro written within `retro_reserve_usd`
- [ ] WI marked `BUDGET_EXCEEDED`
- [ ] Engine halts cleanly (exit 0 with terminal verdict, not crash)

### TC-EDGE-05 — Allowlisted skill missing dependency

**Action**: Allowlist a skill that references a nonexistent dependency.

**After**:
```bash
grep -F "SKILL_DEPENDENCY_MISSING" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
```

**Assertions**:
- [ ] Stdout contains "SKILL_DEPENDENCY_MISSING + <dependency-name>"
- [ ] No fallback to unallowlisted alternatives

### TC-EDGE-06 — Cron fires while previous fire still running

Covered by TC-008b.

### TC-EDGE-07 — Soul-document boundary violation with --force

**Action**: Set `soul.json:forbidden_branches = ["main"]`. Attempt push to `main` with `--force`.

**After**:
```bash
grep -F "SOUL_BOUNDARY_VIOLATION" "${CHANNEL_DIR}/.session-stdout.log" 2>&1
```

**Assertions**:
- [ ] Stdout contains "SOUL_BOUNDARY_VIOLATION"
- [ ] Push rejected even with `--force`
- [ ] No exit code 0 path possible

### TC-EDGE-08 — Multi-model review when Copilot CLI broken (not absent)

**Action**: Copilot CLI present on PATH but malfunctioning (e.g. returns garbage).

**After**:
```bash
grep -F "Copilot CLI unavailable" "${PR_REVIEW_OUTPUT}" 2>&1
# OR
grep -F "Copilot CLI broken" "${PR_REVIEW_OUTPUT}" 2>&1
```

**Assertions**:
- [ ] Context Gap line distinguishes "absent" vs "broken" (per spec edge case)
- [ ] Same-model role-split fallback engages

---

## Test Group: Success Criteria battery (SC-001..SC-008)

**Traces to**: spec.md §Success Criteria; T039 SC battery task.

### TC-SC-001 — Trivial /loop completes in < 5 min wall-clock

```bash
T0=$(date +%s)
# /loop "trivial spec" runs
T1=$(date +%s)
echo "Duration: $((T1 - T0)) seconds"
# Expected: ≤ 300 (5 min)
```

**Assertions**:
- [ ] Wall-clock ≤ 300 seconds
- [ ] Zero token-budget overruns observed in cost-ledger

### TC-SC-002 — 100/100 simulated sessions produce complete retro

```bash
for i in {1..100}; do
  RUN_ID=$(uuidgen)
  # spawn simulated session...
done
COMPLETE=$(find "${CHANNEL_DIR}/retros" -name "*.json" -exec sh -c 'jq -e ".scores | length == 5 and (.patterns | keys | length == 7)" {} > /dev/null' \; -print | wc -l)
echo "Complete retros: $COMPLETE"
# Expected: 100
```

**Assertions**:
- [ ] 100/100 retros complete (5 scores + 7 pattern fields)
- [ ] 0% silent terminations

### TC-SC-003 — Audit chain integrity 1000 events, 100 tampers

Covered by TC-005a + TC-005b at scale (1000 events; 100 random byte-flips).

**Assertions**:
- [ ] 0 false-positives (clean log fails) on 1000 events
- [ ] 0 false-negatives (tampered log passes) on 100 attempts

### TC-SC-004 — Both-flag-CRITICAL rate ≥1/50 PRs (historical sample)

Covered by replay against historical PR sample with known CRITICAL findings.

### TC-SC-005 — Cost-cap overshoot ≤1 spawn-cycle

Covered by TC-004c with explicit overshoot measurement.

**Assertions**:
- [ ] Final spend ≤ `hard_halt_usd + (1 × largest_observed_spawn_cost_usd)`

### TC-SC-006 — Skill rejection latency < 100ms

```bash
# Inside TC-006a, wrap with `time`:
time pwsh -c "/loop --invoke-skill non-allowlisted-skill" 2>&1 | grep -F real | awk '{print $2}'
# Expected: < 0m0.100s
```

**Assertions**:
- [ ] Wall-clock < 100ms

### TC-SC-007 — Cron drift ≤5%, 0% silent overlaps

Covered by TC-008a + TC-008b at 100-overlap scale.

### TC-SC-008 — Soul violations 100% caught (50/50)

Covered by 50 simulated boundary-violation attempts (varying `--force`, env var, direct file edit).

**Assertions**:
- [ ] 50/50 caught with `SOUL_BOUNDARY_VIOLATION` or `SOUL_TAMPERED`

---

## Phase-Gate Fixtures (joint-gate verification)

| Phase | Gate | Tasks | Verification |
|---|---|---|---|
| P1 (joint MVP) | All 3 P1 stories pass together | T015-T020 | TC-001a + TC-002a/b/c + TC-003a/b + FR-MUST-NOT-001 hook fires positive fixture |
| P2a (cost+audit) | Cost ledger + audit chain | T021-T025 | TC-004a/b/c + TC-005a/b + cap-overshoot test |
| P2b (governance) | Allowlist + multi-model + soul | T026-T036 | TC-006a/b/c + TC-007a/b/c + TC-EDGE-07 |
| P3 (proactive) | Cron heartbeat | T037 | TC-008a/b/c |
| Final | All 8 SCs | T039 | TC-SC-001..008 |

---

## Pass/Fail History

| Date | Script Run | Result | Notes |
|------|-----------|--------|-------|
| — | — | UNTESTED | Engine not yet implemented (W3 starts T015 onwards) |

## Known Issues

| Issue | Workaround | Reported |
|-------|------------|---------|
| TC-007c assumes Copilot CLI on PATH check is in dispatcher | If dispatcher only checks `which copilot`, ensure consistent `Copilot CLI unavailable` Context Gap line text | iter 8 testplan |
| TC-EDGE-08 distinction "absent vs broken" requires dispatcher to differentiate exit codes from missing-binary | Spec edge case relies on dispatcher behavior | iter 8 testplan |
| TC-SC-003 1000-event chain takes ~10 min wall-clock at single-thread sha256 | Acceptable for validation; not run on every CI | iter 8 testplan |
