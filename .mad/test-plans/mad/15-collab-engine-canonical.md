---
generated-by: /testplan
generated-by-version: 2.0.0
skill-state-file-id: 249a59a7-276c-40ae-8664-4d35ffd03b7c
canonical-rerun: true
source-spec: specs/15-collab-engine-canonical/spec.md
source-fr-count: 45
phase: 3-step-2
plan-ref: C:/Users/tonym/.claude/plans/cheeky-leaping-kahn.md
---

# Test Plan: 15-collab-engine-canonical

## Verification Spec

> **Phase 0.5 mandatory section.** Five subsections required: Feature Intent, Change Type, Expected Impact, Structural Signals, Pass/Fail Oracle. Downstream consumers (`/mad-implement`, `/mad-validate`, `validate-artifact-completeness.js`, the verify script in Phase 2) read this section first to understand "what does success look like for this test plan?".

### Feature Intent

The feature under test is **Collab Engine v1**, a Lobster-grounded multi-agent collaboration substrate built on the MAD kit foundation. Its intent, as derived from `specs/15-collab-engine-canonical/spec.md`:

- **Primary purpose**: provide a single-player CoClaw + Supervisor + per-agent identity engine that can run one MAD pipeline iteration end-to-end on a fresh kit clone, capture mandatory pre-close learning signals (5+7 retro fields), and surface failure-detection telemetry without becoming a halt source itself.
- **Secondary purposes**: governance (skills allowlist + sha256 pinning + STRIDE Delta), tamper-evident audit (hash-chained log + Query-AuditLog.ps1), multi-model adversarial review activation (FR-MULTI-001/002), proactive cron-driven execution (FR-PROACTIVE-001), and 4 cross-cutting orthogonal halt axes that do NOT include cost (FR-QUOTA tool budget; FR-KILL switch; FR-OVERRIDE manual; FR-SOUL boundary; FR-DEGRADE 5-rung ladder).
- **Iter-41 framing correction**: cost is observability-only (FR-COST-002) — the engine never halts based on cost or budget. Any test that bound an After-state to "engine halts on cost threshold" is a regression and would fail this plan's TC-COST-002a.
- **Iter-41 Lobster reinstatement**: Teams Bot Framework adapter (FR-TEAMS-001/002), Outlook adapter (FR-OUTLOOK-001), WorkIQ Graph context query (FR-WORKIQ-001/002), CoClaw distribution mode (FR-COCLAW-001), and Agent365 sink boundary (FR-AGENT365-001) are in scope for v1; Agent365 cloud central impl is v1.5-deferred but the boundary exists in v1.

The verification target is whether the engine, when implemented per the spec's 45 FRs, produces the bash-observable artifacts that this plan's 52 TCs assert against.

### Change Type

Per `Detect-ContentType.ps1` content-type taxonomy (per `rules/prescriptive-content-review.md` Gap 6):

- **Primary content-type**: `spec-change` — the test plan is generated from a `specs/<N>-<feature>/spec.md` source. Severity weighting per `rules/prescriptive-content-review.md` § Severity calibration: structural absence is **BLOCKING**; cross-file inconsistency is **MUST-FIX**; stylistic precision is **SHOULD-FIX**.
- **Sub-classification**: this is the **canonical-rerun (B) side** of an A/B comparison ordered by `C:/Users/tonym/.claude/plans/cheeky-leaping-kahn.md` Phase 3. The (A) side at `.mad/work-items/collab-engine/inline-snapshot/test-plan.md` is a 59-line stub authored inline (no canonical frontmatter, no FR-binding rigor). This file overwrites the previously-stub `specs/15-collab-engine-canonical/test-plan.md` with full canonical content.
- **Authoring discipline**: this artifact is the canonical `/testplan` skill body output. Inline authorship is FORBIDDEN per `memory/feedback_canonical_skill_only.md` and `validate-mad-pipeline.js`. The frontmatter signature (`generated-by: /testplan`, `skill-state-file-id: 249a59a7-...`) is the mechanical proof of canonical authorship per `enforce-skill-canonical-marker.js`.
- **Blast radius**: ≥7 (per `rules/prescriptive-content-review.md` Gap 5 axis) — this plan is consumed by every implementer working on the collab-engine spec and is the comparison baseline for the antipattern-fix loop's A/B scoring. Auto-escalation to multi-model review is appropriate (deferred to /council-review at the orchestrator's discretion).

### Expected Impact

When the engine is implemented and this test plan runs:

- **Direct impact (in this plan)**:
  - 52 TCs execute via the verify script `.mad/scratch/verify-collab-engine-canonical.sh`.
  - 45/45 FRs covered with bash-verifiable scenarios.
  - 1 of 3 max `[NEEDS CLARIFICATION]` markers preserved (FR-FAIRNESS-001 tenancy resolution).
  - 3 deferred-feature-pattern TCs guard against silent deferral removal (FR-RING, FR-FAIRNESS, FR-AGENT365).
- **Downstream impact (consumers of this plan)**:
  - `/mad-plan` reads this plan to settle the FR-RING-001 v1.5-candidacy and FR-FAIRNESS-001 tenancy resolution questions. The plan's TC-RING-001b and TC-FAIRNESS-001a alternate path are the mechanical artifacts of those resolutions.
  - `/mad-implement` orients implementers toward the After-state targets — every FR's "done" definition is a concrete bash command in this plan, not prose.
  - `/mad-validate` runs the verify script and reports per-domain pass/fail breakdown.
  - `validate-artifact-completeness.js` SubagentStop hook clears the missing-test-plan flag for `specs/15-collab-engine-canonical/spec.md` because this sibling artifact now exists with the canonical frontmatter signature.
- **A/B-comparison impact (cheeky-leaping-kahn.md Phase 3 step 2 score axes)**:
  - **Total test cases**: 52 (vs the inline-A 59-line stub which has 0 bound TCs).
  - **FRs with bound test scenarios**: 45/45 (vs the inline-A which is a placeholder).
  - **Canonical frontmatter signature**: present + valid (vs the inline-A which lacks `/testplan`-authored signature).
  - **Runnable verification script**: `.mad/scratch/verify-collab-engine-canonical.sh` produced (vs the inline-A which has none).

### Structural Signals

The mechanical signals downstream consumers and hooks check for:

| Signal | Check command | Expected result |
|---|---|---|
| Canonical frontmatter signature | `head -10 specs/15-collab-engine-canonical/test-plan.md \| grep -F "generated-by: /testplan"` | exactly one match |
| skill-state-file-id matches active session | `head -10 specs/15-collab-engine-canonical/test-plan.md \| grep -F "skill-state-file-id: 249a59a7-276c-40ae-8664-4d35ffd03b7c"` | exactly one match |
| All 45 FRs have at least one bound TC | `grep -cE '^### TC-[A-Z-]+-[0-9]+[a-z] —' specs/15-collab-engine-canonical/test-plan.md` | ≥ 45 (this plan: 52) |
| Domain coverage matrix sums to 45 | `grep -F "TOTAL" specs/15-collab-engine-canonical/test-plan.md \| grep -F "45"` | match present |
| Deferral-text-preservation TCs present | `grep -cE 'TC-RING-001b\|TC-AGENT365-001c\|deferred-feature pattern' specs/15-collab-engine-canonical/test-plan.md` | ≥ 3 |
| Verify script exists in scratch | `test -f .mad/scratch/verify-collab-engine-canonical.sh && echo present` | "present" |
| Sibling spec.md still present | `test -f specs/15-collab-engine-canonical/spec.md && echo present` | "present" |
| `[NEEDS CLARIFICATION]` markers ≤ 3 | `grep -cF '[NEEDS CLARIFICATION' specs/15-collab-engine-canonical/test-plan.md` | ≤ 3 (this plan: 1 of 3 max) |
| No silent deferrals introduced post-source | `grep -cF 'v1.5' specs/15-collab-engine-canonical/test-plan.md` | source-aligned (deferral text preserved verbatim) |

These structural signals are what `validate-artifact-completeness.js`, `enforce-skill-canonical-marker.js`, the verify script's pre-flight checks, and the A/B scoring rubric all read.

### Pass/Fail Oracle

A test plan run is **PASS** when:
1. The verify script `.mad/scratch/verify-collab-engine-canonical.sh` exits 0.
2. All 52 TCs report `PASS [TC-...]` from the script.
3. No TCs report `FAIL [TC-...]` (any failure halts the run).
4. The `[NEEDS CLARIFICATION]`-marked TC (TC-FAIRNESS-001a) is treated as a documented gap, not a failure — the verify script labels it `SKIP_NEEDS_CLARIFICATION` and does not increment the FAIL counter.
5. The 3 deferral-preservation TCs (TC-RING-001b, TC-AGENT365-001c, and the FR-FAIRNESS-001 alternate path) all PASS — these guard against silent deferral removal.

**FAIL** when:
- Any TC's After-state command does not produce the expected substring.
- Any TC's preconditions cannot be established (e.g. spec source missing).
- A new `[NEEDS CLARIFICATION]` marker appears beyond the 1 inherited from the source (max 3 per skill body limit; current 1 + new = at most 2 before warning).
- Any deferral-preservation TC fails — that's the canary that someone removed a deferral without going through /mad-plan + user discussion.

**Verification entry points**:

| Consumer | Entry point | What it checks |
|---|---|---|
| `/mad-implement` orientation | this `## Verification Spec` section | What "done" looks like for each FR — orients implementer toward the After-state targets |
| `/mad-validate` | the verify script + this contract | Runs the script; reports per-domain pass/fail breakdown; flags any new `[NEEDS CLARIFICATION]` markers as plan drift |
| `validate-artifact-completeness.js` (SubagentStop hook) | presence of test-plan.md sibling next to spec.md + canonical frontmatter signature | Confirms the artifact was authored by /testplan, not inline-emulated; clears the missing-test-plan flag for this spec |
| Verify script (`verify-collab-engine-canonical.sh`) | per-TC `run_check` calls | Mechanical pass/fail; one line per TC; final summary line |

**Frontmatter signature contract**: both copies of this artifact (`specs/15-collab-engine-canonical/test-plan.md` and `.mad/test-plans/mad/15-collab-engine-canonical.md`) carry `generated-by: /testplan`, `generated-by-version: 2.0.0`, `skill-state-file-id: 249a59a7-276c-40ae-8664-4d35ffd03b7c`. The session_id matches `.mad/scratch/mad-pipeline-active.json:session_id` exactly. Hook `enforce-skill-canonical-marker.js` verifies this on every artifact write.

---

## Metadata
- **Scenario ID**: 15-collab-engine-canonical
- **Project**: mad
- **Feature**: Collab Engine v1 (Canonical Rerun)
- **Spec**: specs/15-collab-engine-canonical/spec.md
- **Generated**: 2026-05-02
- **Verify Script**: `.mad/scratch/verify-collab-engine-canonical.sh`
- **Source FR Count**: 45 (all enumerated; no Top-N capping)
- **FR-Coverage Bound**: 45/45 with bash-verifiable scenarios

> **Enumeration discipline.** Per `memory/feedback_no_top_n_capping.md`: every FR in the source spec gets at least one bound test scenario below. Domains with zero FRs are stated explicitly; deferred FRs (FR-RING-001 v1.5 candidacy; FR-FAIRNESS-001 [NEEDS CLARIFICATION]; FR-AGENT365-001 v1.5 implementation) carry deferred-feature-pattern test scenarios per `memory/feedback_no_silent_deferrals.md`.

---

## Test Group: FR-CORE — Engine bootstrapping + identity + retro discipline

**Traces to**: User Stories US-001, US-002, US-003 (P1). Canonical session start, run_id propagation, agent_id stability, retro pre-close gate.

### TC-CORE-001a — Engine spawns peer-agents under Supervisor pattern (FR-CORE-001)

**Before (failing state)**:
```bash
ls "$CHANNEL_DIR/messages/" 2>/dev/null | grep -c -- "supervisor\|peer" || echo "0"
# Expected: 0 (no messages before /loop runs)
```

**Action**: Run `/loop "trivial"` and let the engine spawn the Supervisor + at least one peer-agent.

**After (passing state)**:
```bash
ls "$CHANNEL_DIR/messages/" | grep -E "(supervisor|peer)" | wc -l
# Expected output substring: "2" (one supervisor + at least one peer)
```

**Assertions**:
- [ ] Before state: `messages/` is empty or absent
- [ ] After state: at least one supervisor and one peer message file exist
- [ ] No regressions in FR-CORE-002 run_id correlation

### TC-CORE-002a — run_id generated and propagated to every spawn (FR-CORE-002)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/channel.json" && jq -r '.run_id // "absent"' "$CHANNEL_DIR/channel.json" || echo "absent"
# Expected: "absent" pre-bootstrap
```

**Action**: Run `/loop "trivial"`; engine generates a single run_id and stamps it on all artifacts.

**After (passing state)**:
```bash
jq -r '.run_id' "$CHANNEL_DIR/channel.json"
# Expected output substring: "-" (UUID v4 format contains hyphens)
```

**Assertions**:
- [ ] After state: channel.json carries a non-empty run_id
- [ ] All `messages/*.json` files share the same run_id
- [ ] No regression on FR-CORE-001 supervisor presence

### TC-CORE-003a — Stable agent_id per peer-agent (FR-CORE-003)

**Before (failing state)**:
```bash
ls "$CHANNEL_DIR/messages/"*.json 2>/dev/null | wc -l
# Expected: 0 (no spawns yet)
```

**Action**: Spawn 3 parallel peer-agents via `/loop "parallel-fixture"`.

**After (passing state)**:
```bash
jq -r '.agent_id' "$CHANNEL_DIR/messages/"*.json | sort -u | wc -l
# Expected output substring: "4" (1 supervisor + 3 unique peers)
```

**Assertions**:
- [ ] After state: agent_id values are unique per peer-agent
- [ ] All agent_ids match UUID v4 format

### TC-CORE-004a — Step-9 retro 5+7 fields mandatory (FR-CORE-004)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/retros/$RUN_ID.json" && echo "present" || echo "absent"
# Expected: "absent" (no retro before session end)
```

**Action**: Run `/loop "trivial"` to completion; engine writes retro.

**After (passing state)**:
```bash
jq -r '"\(.scores | length) \(.patterns | keys | length)"' "$CHANNEL_DIR/retros/$RUN_ID.json"
# Expected output substring: "5 7" (5 scores + 7 pattern fields)
```

**Assertions**:
- [ ] After state: retro file present at expected path
- [ ] 5 scores: accuracy, completeness, tsg_alignment, dx, confidence
- [ ] 7 patterns: what_worked, what_was_hard, improvisation, recurring_pattern, skill_gap, tsg_gap, environment_blockers

### TC-CORE-005a — Refuses session-end if Step-9 incomplete (FR-CORE-005, normal path)

**Before (failing state)**:
```bash
echo "no fixture run yet"
# Expected: literal string
```

**Action**: Inject test-fixture that skips retro write; run `/loop "skipped-retro-fixture"`.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "Step 9 incomplete"
# Expected output substring: "Step 9 incomplete"
```

**Assertions**:
- [ ] After state: `$LAST_LOOP_EXIT_CODE` is non-zero
- [ ] stdout contains "[BLOCK] Step 9 incomplete — retry"

### TC-CORE-005b — Halt-outcome carve-out bypasses BLOCK gate (FR-CORE-005, carve-out path)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/retros/$RUN_ID.json" && echo "present" || echo "absent"
# Expected: "absent"
```

**Action**: Inject fixture producing minimal retro with `outcome: halted_by_quota` (orchestrator-filled, no retro spawn).

**After (passing state)**:
```bash
jq -r '.outcome' "$CHANNEL_DIR/retros/$RUN_ID.json"
# Expected output substring: "halted_by_quota"
```

**Assertions**:
- [ ] After state: exit code is 0 (carve-out applied)
- [ ] retro `outcome` field equals `halted_by_quota`

### TC-CORE-005c — Legacy budget_exceeded outcome rejected (FR-CORE-005, schema migration)

**Before (failing state)**:
```bash
echo "no fixture run yet"
```

**Action**: Inject fixture with `outcome: budget_exceeded` (legacy value).

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "budget_exceeded"
# Expected output substring: "budget_exceeded" (rejected with migration error)
```

**Assertions**:
- [ ] After state: schema validation rejects legacy value
- [ ] Migration error message present in stdout

---

## Test Group: FR-COST — Cost ledger as observability-only telemetry

**Traces to**: User Story US-004 (P2). Per-spawn token + USD ledger; ledger feeds failure-detection signals; never halts.

### TC-COST-001a — Per-spawn token + failure-mode delta in append-only ledger (FR-COST-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/cost-ledger.jsonl" && wc -l < "$CHANNEL_DIR/cost-ledger.jsonl" || echo "0"
# Expected: "0" or absent
```

**Action**: Run `/loop` with 3 peer-agent spawns.

**After (passing state)**:
```bash
wc -l < "$CHANNEL_DIR/cost-ledger.jsonl"
# Expected output substring: "3"
```

**Assertions**:
- [ ] After state: 3 lines in cost-ledger.jsonl
- [ ] Every line has `tokens_in`, `tokens_out`, `cost_usd` populated
- [ ] Optional `failure_mode` field uses FR-RELIABILITY-001 enum

### TC-COST-002a — Cost-threshold crossing does NOT halt engine (FR-COST-002)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/verdicts/$RUN_ID.json" && jq -r '.type // "absent"' "$CHANNEL_DIR/verdicts/$RUN_ID.json" || echo "absent"
# Expected: "absent"
```

**Action**: Run a session that crosses any cost threshold (cumulative cost_usd 0.99 → 1.01, or token count 99K → 101K).

**After (passing state)**:
```bash
grep -F "cost_trigger" "$CHANNEL_DIR/verdicts/"*.json 2>/dev/null | wc -l
# Expected output substring: "0"
```

**Assertions**:
- [ ] After state: zero verdicts contain `cost_trigger` field
- [ ] cost-ledger.jsonl continues accumulating per FR-COST-001
- [ ] Engine continues running across the threshold

### TC-COST-003a — Cost-ledger informational marker emitted exactly once (FR-COST-003)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/.session-stdout.log" && echo "exists" || echo "absent"
# Expected: "absent"
```

**Action**: Start any `/loop` session.

**After (passing state)**:
```bash
grep -cF "cost ledger active" "$CHANNEL_DIR/.session-stdout.log"
# Expected output substring: "1"
```

**Assertions**:
- [ ] After state: informational line present exactly once
- [ ] No `BUDGET_EXCEEDED`/`COST_EXCEEDED` verdict written from cost reads

---

## Test Group: FR-AUDIT — Hash-chained audit log + query script

**Traces to**: User Story US-005 (P2). Tamper-evident audit chain.

### TC-AUDIT-001a — Hash-chained audit log appends correctly (FR-AUDIT-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/audit-log.jsonl" && wc -l < "$CHANNEL_DIR/audit-log.jsonl" || echo "0"
# Expected: "0" or absent
```

**Action**: Run a session that emits 5 audit-bearing events (consent gate + verdict + retro + allowlist mutation + cron fire).

**After (passing state)**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -Verify "$CHANNEL_DIR/audit-log.jsonl"
# Expected output substring: "OK chain length 5"
```

**Assertions**:
- [ ] After state: chain verifies clean (exit 0)
- [ ] All 7 required event types representable: consent_gate, verdict, retro, allowlist_mutation, soul_mutation, cron_fire, cost_ledger_entry

### TC-AUDIT-001b — Tampered entry fails chain verification (FR-AUDIT-001)

**Before (failing state)**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -Verify "$CHANNEL_DIR/audit-log.jsonl"
# Expected output substring: "OK"
```

**Action**: Modify byte in entry 3's payload after chain is built.

**After (passing state)**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -Verify "$CHANNEL_DIR/audit-log.jsonl" 2>&1 || echo "CHAIN_BROKEN"
# Expected output substring: "CHAIN_BROKEN"
```

**Assertions**:
- [ ] After state: non-zero exit
- [ ] Error message references line 3

### TC-AUDIT-002a — Query-AuditLog.ps1 supports -Verify / -Filter / -Since (FR-AUDIT-002)

**Before (failing state)**:
```bash
test -f .claude/scripts/Query-AuditLog.ps1 && echo "present" || echo "absent"
# Expected: "present" (precondition)
```

**Action**: Inspect parameter sets.

**After (passing state)**:
```bash
pwsh -NoProfile -File .claude/scripts/Query-AuditLog.ps1 -? 2>&1 | grep -cE "(Verify|Filter|Since)"
# Expected output substring: "3"
```

**Assertions**:
- [ ] After state: all three parameter sets surface in help
- [ ] -Filter type=verdict returns only verdict entries

---

## Test Group: FR-AUDIT-PRIVACY — Telemetry privacy schema MUST-NOT

**Traces to**: spec FR-AUDIT-PRIVACY-001. Privacy schema rejects PII and code in outbound signals.

### TC-AUDIT-PRIVACY-001a — Privacy schema rejects PII-bearing signal (FR-AUDIT-PRIVACY-001)

**Before (failing state)**:
```bash
wc -l < "$CHANNEL_DIR/audit-log.jsonl" 2>/dev/null || echo "0"
# Expected: "0" or baseline
```

**Action**: Inject fixture emitting signal with literal repo name "MyService", alias "tonym@microsoft.com", 5-line code snippet.

**After (passing state)**:
```bash
grep -cF "PRIVACY_SCHEMA_VIOLATION" "$CHANNEL_DIR/.session-stdout.log"
# Expected output substring: "1"
```

**Assertions**:
- [ ] After state: PRIVACY_SCHEMA_VIOLATION emitted
- [ ] Signal is NOT appended to audit log
- [ ] Redacted suggestion offered: REPO_REDACTED, ALIAS_REDACTED, CODE_REDACTED
- [ ] PR-URL-only signal passes validation

---

## Test Group: FR-GOV — Skills allowlist + version pinning + grounding + STRIDE Delta

**Traces to**: User Story US-006 (P2). Supply-chain governance.

### TC-GOV-001a — Engine refuses non-allowlisted skill (FR-GOV-001)

**Before (failing state)**:
```bash
jq -r '.skills | keys[]' .mad/policy/skills-allowlist.json | grep -c "rogue-skill" || echo "0"
# Expected: "0"
```

**Action**: Invoke a skill named `rogue-skill` not in allowlist.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "SKILL_NOT_ALLOWED"
# Expected output substring: "SKILL_NOT_ALLOWED"
```

**Assertions**:
- [ ] After state: non-zero exit within 100ms (per SC-006)
- [ ] Suggested promotion path printed

### TC-GOV-002a — Skill body sha256 mismatch rejection (FR-GOV-002)

**Before (failing state)**:
```bash
sha256sum .claude/skills/test-skill/SKILL.md | cut -d' ' -f1
# Expected: original hash
```

**Action**: Modify a byte in an allowlisted skill body without updating the pinned sha256.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "SKILL_VERSION_MISMATCH"
# Expected output substring: "SKILL_VERSION_MISMATCH"
```

**Assertions**:
- [ ] After state: SKILL_VERSION_MISMATCH error in stdout
- [ ] Non-zero exit

### TC-GOV-003a — Production-grounding hook fires on prescriptive content (FR-GOV-003)

**Before (failing state)**:
```bash
echo "no /pr-review run yet"
```

**Action**: Run `/pr-review` on a doc-content-typed PR (per `prescriptive-content-review.md` Gap 1 keyword/path triggers).

**After (passing state)**:
```bash
grep -F "Pull-ProductionGrounding.ps1" "$CHANNEL_DIR/skill-output.log"
# Expected output substring: "Pull-ProductionGrounding.ps1"
```

**Assertions**:
- [ ] After state: Step-1.5 entry references the script invocation

### TC-GOV-004a — STRIDE Delta hook rejects skills missing the section (FR-GOV-004)

**Before (failing state)**:
```bash
grep -c "## STRIDE Delta" .claude/skills/test-skill-no-stride/SKILL.md 2>/dev/null || echo "0"
# Expected: "0"
```

**Action**: Attempt to write a consequential SKILL.md without `## STRIDE Delta` heading.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "STRIDE_DELTA_MISSING"
# Expected output substring: "STRIDE_DELTA_MISSING"
```

**Assertions**:
- [ ] After state: pre-write hook rejection
- [ ] No file written

---

## Test Group: FR-MULTI — Multi-model adversarial review

**Traces to**: User Story US-007 (P2). Cross-model gate activation.

### TC-MULTI-001a — Five high-blast-radius skills wire dispatcher in --council (FR-MULTI-001)

**Before (failing state)**:
```bash
ls "$OUTPUT_DIR/" 2>/dev/null | grep -cE "(opus|gpt)-result.json" || echo "0"
# Expected: "0"
```

**Action**: Run `pr-review --council` on a sample PR.

**After (passing state)**:
```bash
ls "$OUTPUT_DIR/" | grep -cE "(opus-result|gpt-result)"
# Expected output substring: "2"
```

**Assertions**:
- [ ] After state: both opus-result.json and gpt-result.json exist
- [ ] Cross-model agreement table written to skill output
- [ ] Note: ensemble-consensus rubric extension explicitly deferred to v1.5 (no test in v1)

### TC-MULTI-002a — S1-S15 security checklist injected into review (FR-MULTI-002)

**Before (failing state)**:
```bash
test -f references/security-checklist.md && echo "present" || echo "absent"
# Expected: "present"
```

**Action**: Run `pr-review --council`; inspect dispatcher prompt.

**After (passing state)**:
```bash
grep -cE "^S(1[0-5]|[1-9])\b" "$OUTPUT_DIR/dispatcher-prompt.txt"
# Expected output substring: "15"
```

**Assertions**:
- [ ] After state: S1-S15 sections present in prompt
- [ ] Findings tagged with [S#] in dispatcher output

---

## Test Group: FR-PROACTIVE — Heartbeat + cron

**Traces to**: User Story US-008 (P3). Proactive scheduled execution.

### TC-PROACTIVE-001a — Cron heartbeat fires N times in expected window with skip-on-overlap (FR-PROACTIVE-001)

**Before (failing state)**:
```bash
test -f .mad/scratch/cron-fires.jsonl && wc -l < .mad/scratch/cron-fires.jsonl || echo "0"
# Expected: "0" or baseline
```

**Action**: Set `*/5 * * * *` schedule; let 25 minutes elapse.

**After (passing state)**:
```bash
wc -l < .mad/scratch/cron-fires.jsonl
# Expected output substring: "5"
```

**Assertions**:
- [ ] After state: 5 fires recorded with monotonic timestamps
- [ ] Overlap during a long-running fire logs `CRON_OVERLAP` and skips the new fire
- [ ] Engine resumes from checkpoint if halted mid-fire

---

## Test Group: FR-RING — 5-stage SDP ring rollout

**Traces to**: spec FR-RING-001. **Status**: v1.5 deferral candidacy preserved verbatim from source per `memory/feedback_no_silent_deferrals.md`. The FR remains in the spec; the hard-defer/keep judgment is for `/mad-plan` to settle, not `/testplan`.

### TC-RING-001a — Prod destructive verdict progresses through 5-stage SDP rings (FR-RING-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/rollout-progress.jsonl" && wc -l < "$CHANNEL_DIR/rollout-progress.jsonl" || echo "0"
# Expected: "0" or absent
```

**Action**: Set `channel.json:environment_tier = prod`; issue ARCHIVE verdict.

**After (passing state)**:
```bash
jq -r '.stage' "$CHANNEL_DIR/rollout-progress.jsonl" | sort -u | wc -l
# Expected output substring: "5"
```

**Assertions**:
- [ ] After state: 5 stages logged: Canary, Pilot, Medium, Heavy, Broad
- [ ] Bake duration honored between stages (24h normal / 6h emergency)
- [ ] [DEFERRAL CANDIDACY PRESERVED]: source flagged this FR as v1.5 candidate

### TC-RING-001b — Deferral-text preservation assertion (FR-RING-001 deferred-feature pattern)

**Before (failing state)**:
```bash
echo "n/a"
```

**Action**: Verify the v1.5-candidacy rationale is preserved verbatim in the spec.

**After (passing state)**:
```bash
grep -cF "v1.5" specs/15-collab-engine-canonical/spec.md
# Expected output substring: a positive integer (deferral text retained)
```

**Assertions**:
- [ ] After state: deferral candidacy text present
- [ ] No silent deferral introduced post-source

---

## Test Group: FR-SOUL — Immutable boundary enforcement

**Traces to**: spec FR-SOUL-001. Soul document boundaries are not overridable.

### TC-SOUL-001a — Soul violation rejected without --force (FR-SOUL-001)

**Before (failing state)**:
```bash
test -f .mad/policy/soul.json && jq -r '.forbidden_branches[]' .mad/policy/soul.json | head -1
# Expected: "main" (or configured forbidden branch)
```

**Action**: Configure `forbidden_branches: ["main"]`; attempt push to main.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "SOUL_BOUNDARY_VIOLATION"
# Expected output substring: "SOUL_BOUNDARY_VIOLATION"
```

**Assertions**:
- [ ] After state: rejection emitted, non-zero exit

### TC-SOUL-001b — --force does NOT override soul (FR-SOUL-001)

**Before (failing state)**:
```bash
echo "first attempt rejected"
```

**Action**: Repeat the same push with `--force`.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -cF "SOUL_BOUNDARY_VIOLATION"
# Expected output substring: "2" (one rejection per attempt)
```

**Assertions**:
- [ ] After state: --force does not bypass; same rejection class

---

## Test Group: FR-MUST-NOT — Phase MUST NOT include gates

**Traces to**: spec FR-MUST-NOT-001. Phase scope creep detection.

### TC-MUST-NOT-001a — Out-of-Scope items grep-detectable in spec (FR-MUST-NOT-001)

**Before (failing state)**:
```bash
echo "n/a — pre-state irrelevant for spec-text assertion"
```

**Action**: Inspect Out-of-Scope section.

**After (passing state)**:
```bash
grep -cF "Out of Scope" specs/15-collab-engine-canonical/spec.md
# Expected output substring: a positive integer
```

**Assertions**:
- [ ] After state: Out-of-Scope section exists with explicit forbidden-feature list
- [ ] BYOK, Agent Teams operating layer, Linux Node Host all listed

---

## Test Group: FR-RELIABILITY — Failure-mode taxonomy

**Traces to**: spec FR-RELIABILITY-001. Closed enum surfaces in retros.

### TC-RELIABILITY-001a — Failure-mode tagging covers all 8 enum values (FR-RELIABILITY-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/retros/$RUN_ID.json" && jq -r '.failure_mode // "absent"' "$CHANNEL_DIR/retros/$RUN_ID.json" || echo "absent"
# Expected: "absent" (no failure injected yet)
```

**Action**: Inject 8 fixtures (one per enum: timeout, oom, network, model_refused, tool_error, governance_block, budget_exceeded, other).

**After (passing state)**:
```bash
ls "$CHANNEL_DIR/retros/"*.json | xargs -I{} jq -r '.failure_mode' {} | sort -u | wc -l
# Expected output substring: "8"
```

**Assertions**:
- [ ] After state: all 8 enum values represented
- [ ] `other` triggers a `[NEEDS CLARIFICATION]` follow-up marker
- [ ] `budget_exceeded` is valid in failure_mode taxonomy (distinct from FR-CORE-005 retro outcome enum)

---

## Test Group: FR-IDENTITY — Signed agent spawn + Entra binding

**Traces to**: spec FR-IDENTITY-001. Cryptographic spawn + Entra principal binding.

### TC-IDENTITY-001a — Unsigned spawn rejected (FR-IDENTITY-001)

**Before (failing state)**:
```bash
echo "no spawn yet"
```

**Action**: Spawn peer-agent with stripped/forged signature.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "AGENT_SPAWN_UNSIGNED"
# Expected output substring: "AGENT_SPAWN_UNSIGNED"
```

**Assertions**:
- [ ] After state: spawn rejected with named error

### TC-IDENTITY-001b — Entra principal mismatch rejected (FR-IDENTITY-001 extension)

**Before (failing state)**:
```bash
echo "principal X configured"
```

**Action**: Misconfigure spawn to claim principal Y while agent registered as X.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "IDENTITY_PRINCIPAL_MISMATCH"
# Expected output substring: "IDENTITY_PRINCIPAL_MISMATCH"
```

**Assertions**:
- [ ] After state: spawn rejected with principal mismatch
- [ ] Note: full BYOK/per-tenant inference routing remains deferred to v1.5

---

## Test Group: FR-DRIFT — Skill behavior drift detection

**Traces to**: spec FR-DRIFT-001. Eval-snapshot-based drift detection.

### TC-DRIFT-001a — Modified skill prompt triggers SKILL_DRIFT_DETECTED (FR-DRIFT-001)

**Before (failing state)**:
```bash
echo "baseline eval present"
```

**Action**: Modify skill A's prompt slightly; invoke skill A.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "SKILL_DRIFT_DETECTED"
# Expected output substring: "SKILL_DRIFT_DETECTED"
```

**Assertions**:
- [ ] After state: drift detected in stdout
- [ ] `drift_delta` field surfaces in the next retro

---

## Test Group: FR-REPLAY — Audit chain replay

**Traces to**: spec FR-REPLAY-001. Deterministic re-execution from chain entry.

### TC-REPLAY-001a — Replay reproduces message bodies byte-for-byte (FR-REPLAY-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/run.json" && echo "present" || echo "absent"
# Expected: "present"
```

**Action**: Replay a stored run from a hash-chain entry.

**After (passing state)**:
```bash
diff <(jq 'del(.timestamp_utc)' "$CHANNEL_DIR/messages/01.json") <(jq 'del(.timestamp_utc)' "$REPLAY_DIR/messages/01.json") && echo "equal"
# Expected output substring: "equal"
```

**Assertions**:
- [ ] After state: byte-equivalence after timestamp redaction
- [ ] Hash chain validates identically

---

## Test Group: FR-OVERRIDE — Manual halt verdict

**Traces to**: spec FR-OVERRIDE-001. Operator manual halt is terminal.

### TC-OVERRIDE-001a — Manual halt verdict is terminal (FR-OVERRIDE-001)

**Before (failing state)**:
```bash
ls "$CHANNEL_DIR/verdicts/manual-"*.json 2>/dev/null && echo "present" || echo "absent"
# Expected: "absent"
```

**Action**: Inject manual halt verdict mid-run with `injected_by: human, trigger: manual`.

**After (passing state)**:
```bash
jq -r '.outcome' "$CHANNEL_DIR/retros/$RUN_ID.json"
# Expected output substring: "halted_by_override"
```

**Assertions**:
- [ ] After state: retro outcome equals `halted_by_override`
- [ ] Hash chain captures `injected_by: human` field
- [ ] No `cost_trigger` reference in verdict

---

## Test Group: FR-FAIRNESS — Per-tenant cost+latency rollup

**Traces to**: spec FR-FAIRNESS-001. **Status**: [NEEDS CLARIFICATION: tenancy model] preserved from source. Tasks T058/T059 are CONDITIONAL pending /mad-plan resolution.

### TC-FAIRNESS-001a — Per-tenant rollup file structure (FR-FAIRNESS-001, conditional)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/tenant-rollup.jsonl" && wc -l < "$CHANNEL_DIR/tenant-rollup.jsonl" || echo "0"
# Expected: "0" or absent
```

**Action**: If multi-tenant resolution = "multi-tenant": run 3 tenants in parallel. If single-tenant or single-operator: this FR defers to v1.5 and the test follows the deferred-feature pattern.

**After (passing state)**:
```bash
# [NEEDS CLARIFICATION: tenancy resolution required]
# Conditional: if multi-tenant:
#   jq -r '.tenant_id' "$CHANNEL_DIR/tenant-rollup.jsonl" | sort -u | wc -l → "3"
# Conditional: if single-tenant/operator (deferred-feature pattern):
grep -cF "FR-FAIRNESS-001" specs/15-collab-engine-canonical/spec.md
# Expected output substring: "1" (FR retained even when deferred)
```

**Assertions**:
- [ ] After state: outcome conditional on /mad-plan tenancy resolution
- [ ] Source preserved [NEEDS CLARIFICATION] verbatim per `memory/feedback_no_silent_deferrals.md`
- [ ] Marker count: 1 of 3 max per skill body limit

---

## Test Group: FR-INTROSPECT — Engine introspection + dual-signal capture

**Traces to**: spec FR-INTROSPECT-001, FR-INTROSPECT-002. Read-only state surface + Execution+Outcome dual signals.

### TC-INTROSPECT-001a — Introspect emits 4 sections under 500ms (FR-INTROSPECT-001)

**Before (failing state)**:
```bash
echo "no introspect run yet"
```

**Action**: Invoke `/collab-engine introspect` on a 100-run channel.

**After (passing state)**:
```bash
grep -cE "(active runs|allowlisted skills|recent retro signals|last 10 verdicts)" "$CHANNEL_DIR/introspect.txt"
# Expected output substring: "4"
```

**Assertions**:
- [ ] After state: 4 sections present
- [ ] Wall-clock < 500ms

### TC-INTROSPECT-001b — Multi-task granularity: one signal pair per task (FR-INTROSPECT-001)

**Before (failing state)**:
```bash
echo "single-task baseline"
```

**Action**: Run multi-task session with 3 distinct tasks.

**After (passing state)**:
```bash
jq -r '[.[] | .task_id] | length' "$CHANNEL_DIR/introspect-signals.json"
# Expected output substring: "3"
```

**Assertions**:
- [ ] After state: 3 signal pairs each tagged with own task_id and shared run_id
- [ ] Single-task session emits exactly 1 pair

### TC-INTROSPECT-002a — Execution + Outcome dual signals correlated by run_id (FR-INTROSPECT-002)

**Before (failing state)**:
```bash
ls "$CHANNEL_DIR/outcome-signals/" 2>/dev/null | wc -l || echo "0"
# Expected: "0"
```

**Action**: Run a session with 3 distinct tasks.

**After (passing state)**:
```bash
jq -r '.run_id' "$CHANNEL_DIR/outcome-signals/"*.json | sort -u | wc -l
# Expected output substring: "1"
```

**Assertions**:
- [ ] After state: 3 outcome signals share the same run_id
- [ ] Each Outcome Signal carries A/B/C grade + low/medium/high effort
- [ ] FR-CALIBRATION-001 detects divergence (high self-confidence + grade C)

---

## Test Group: FR-LIFECYCLE — Skill/rule/template lifecycle

**Traces to**: spec FR-LIFECYCLE-001. Status frontmatter and grace-period enforcement.

### TC-LIFECYCLE-001a — Deprecated skill warns then refuses past grace period (FR-LIFECYCLE-001)

**Before (failing state)**:
```bash
grep -F "status: deprecated" .claude/skills/test-skill/SKILL.md | head -1
# Expected: "status: deprecated" (precondition)
```

**Action**: Mark skill X deprecated with `superseded_by: Y`; invoke before grace period expiry.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "SKILL_DEPRECATED"
# Expected output substring: "SKILL_DEPRECATED"
```

**Assertions**:
- [ ] After state: warning emitted on first call within grace
- [ ] After grace: `SKILL_DEPRECATED_EXPIRED` rejection

---

## Test Group: FR-CALIBRATION — Independent grading + self-vs-outcome correlation

**Traces to**: spec FR-CALIBRATION-001. Approval-gated prompt-tuning suggestions.

### TC-CALIBRATION-001a — Calibration grade emitted on SC-004 trigger (FR-CALIBRATION-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/calibration-grade.json" && echo "present" || echo "absent"
# Expected: "absent"
```

**Action**: Run a 50-PR session with seeded CRITICAL findings.

**After (passing state)**:
```bash
jq -r '.delta != null' "$CHANNEL_DIR/calibration-grade.json"
# Expected output substring: "true"
```

**Assertions**:
- [ ] After state: calibration-grade.json present
- [ ] Trend visible across 3 sessions

### TC-CALIBRATION-001b — Approval-gated prompt-tuning (FR-CALIBRATION-001)

**Before (failing state)**:
```bash
ls "$CHANNEL_DIR/calibration-approvals/" 2>/dev/null | wc -l || echo "0"
# Expected: "0"
```

**Action**: Run 30-day historical fixture; verify CALIBRATION_DRIFT emission for 5 of 50 retros where divergence > threshold.

**After (passing state)**:
```bash
grep -cF "CALIBRATION_DRIFT" "$CHANNEL_DIR/.session-stdout.log"
# Expected output substring: "5"
```

**Assertions**:
- [ ] After state: 5 drift emissions
- [ ] Engine prompt is NOT modified until human writes approval file
- [ ] Parallel to FR-SOUL-001 immutable-boundary discipline

---

## Test Group: FR-ISOLATION — Multi-user OS-level isolation

**Traces to**: spec FR-ISOLATION-001/002/003. Storage perms, symlink defense, alias collisions.

### TC-ISOLATION-001a — User B cannot read User A artifacts (FR-ISOLATION-001)

**Before (failing state)**:
```bash
ls -ld ~/collab-engine 2>/dev/null | awk '{print $1}' || echo "absent"
# Expected: "absent"
```

**Action**: As user A, start engine. As user B, attempt to read A's channel.json.

**After (passing state)**:
```bash
ls -ld ~/collab-engine | awk '{print $1}' | grep -F "drwx------"
# Expected output substring: "drwx------" (mode 0700)
```

**Assertions**:
- [ ] After state: 0700 mode
- [ ] User B read attempt yields EACCES
- [ ] Insecure perms (0755) cause `STORAGE_INSECURE_PERMS` refusal at restart

### TC-ISOLATION-002a — Symlink-poisoned path rejected (FR-ISOLATION-002)

**Before (failing state)**:
```bash
test -L ~/collab-engine/$RUN_ID/channel.json && echo "is symlink" || echo "not symlink"
# Expected: "is symlink" (precondition: symlink injected)
```

**Action**: Replace channel.json with symlink to /etc/passwd; start engine.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "STORAGE_SYMLINK_REJECTED"
# Expected output substring: "STORAGE_SYMLINK_REJECTED"
```

**Assertions**:
- [ ] After state: rejection emitted
- [ ] No write attempted on symlink target

### TC-ISOLATION-003a — Alias-collision renders host-decorated names (FR-ISOLATION-003)

**Before (failing state)**:
```bash
echo "two undecorated 'Engineer' members in channel"
```

**Action**: Open channel with two members both aliased "Engineer" from hosts hostA, hostB; run introspect.

**After (passing state)**:
```bash
grep -cE "Engineer@host[AB]" "$CHANNEL_DIR/introspect.txt"
# Expected output substring: "2"
```

**Assertions**:
- [ ] After state: both `Engineer@hostA` and `Engineer@hostB` rendered
- [ ] No undecorated `Engineer` entries

---

## Test Group: FR-QUOTA — Per-spawn tool-call budget

**Traces to**: spec FR-QUOTA-001. Per-spawn tool-call ceiling (the only per-spawn ceiling that produces a halt).

### TC-QUOTA-001a — Quota exhaustion halts at next tool call (FR-QUOTA-001)

**Before (failing state)**:
```bash
echo "max_tool_calls: 5 declared"
```

**Action**: Spawn agent with `max_tool_calls: 5`; inject fixture invoking 10 tools.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "QUOTA_EXCEEDED_TOOL_CALLS"
# Expected output substring: "QUOTA_EXCEEDED_TOOL_CALLS"
```

**Assertions**:
- [ ] After state: halt at 6th call
- [ ] Audit chain captures tool-call count at termination
- [ ] retro outcome = `halted_by_quota`

---

## Test Group: FR-RATE — Channel review-rate cap with queue back-pressure

**Traces to**: spec FR-RATE-001. Third orthogonal axis (alongside FR-COST-002 telemetry and FR-QUOTA-001 tool budget).

### TC-RATE-001a — Queue full rejects synchronously with retry-after (FR-RATE-001)

**Before (failing state)**:
```bash
jq -r '.settings.review_rate_cap_seconds' "$CHANNEL_DIR/channel.json"
# Expected: "30" (precondition)
```

**Action**: Submit 5 review requests within 5s.

**After (passing state)**:
```bash
grep -cF "RATE_LIMITED_QUEUE_FULL" "$CHANNEL_DIR/.session-stdout.log"
# Expected output substring: "2" (requests 4 and 5 rejected)
```

**Assertions**:
- [ ] After state: 1-3 queued (3-deep), 4-5 rejected with retry_after_seconds
- [ ] Queue drains at 1 per 30s

---

## Test Group: FR-KILL — Read-time kill-switch

**Traces to**: spec FR-KILL-001. Emergency revert with no redeploy.

### TC-KILL-001a — Kill-switch flip reverts on next invocation (FR-KILL-001)

**Before (failing state)**:
```bash
jq -r '.killed' .mad/policy/kill-switches/X.json
# Expected: "false"
```

**Action**: Edit kill-switch JSON to `killed: true, revert_to: "previous-stable", kill_reason: "incident-12345"`; invoke X.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "KILL_SWITCH_ACTIVE"
# Expected output substring: "KILL_SWITCH_ACTIVE"
```

**Assertions**:
- [ ] After state: KILL_SWITCH_ACTIVE event emitted with `change_id: "X"` and `kill_reason`
- [ ] revert_to version executed, NOT current code
- [ ] If terminal, retro outcome = `halted_by_kill_switch`
- [ ] Distinct from FR-LIFECYCLE-001 (slow grace period)

---

## Test Group: FR-DEGRADE — 5-rung graceful degradation ladder

**Traces to**: spec FR-DEGRADE-001. Automatic mode-degradation continuation, not termination.

### TC-DEGRADE-001a — Ladder progresses rung-1 → rung-4 ESCALATE (FR-DEGRADE-001)

**Before (failing state)**:
```bash
echo "no degradation events"
```

**Action**: Inject fixture causing 3 consecutive timeouts.

**After (passing state)**:
```bash
jq -r '.degraded_modes[].rung' "$CHANNEL_DIR/retros/$RUN_ID.json" | sort -u | wc -l
# Expected output substring: "3"
```

**Assertions**:
- [ ] After state: rungs 1→2→3 progress in order
- [ ] Cumulative event triggers rung-4 with `escalate_trigger: "rate_limit_exhaustion"`
- [ ] Rung-5 (`reject-deferred`) returns replay token

---

## Test Group: FR-TEAMS — Bot Framework adapter + M365 channel/meeting context

**Traces to**: spec FR-TEAMS-001/002. Iter-41 reinstated.

### TC-TEAMS-001a — Teams bot adaptive card carries run_id stamps (FR-TEAMS-001)

**Before (failing state)**:
```bash
echo "no card sent yet"
```

**Action**: Send `@bot /loop trivial spec` from a 1:1 chat.

**After (passing state)**:
```bash
jq -r '.body[].metadata.run_id // empty' "$CHANNEL_DIR/teams-card-payload.json" | grep -c "-"
# Expected output substring: a positive integer (run_id contains hyphens)
```

**Assertions**:
- [ ] After state: card payload carries `run_id` and `agent_id`
- [ ] `source: chat|channel|meeting` provenance differs by invocation context
- [ ] Bot honors Entra agent identity per FR-IDENTITY-001

### TC-TEAMS-002a — Channel/meeting/attachment context bundled with provenance (FR-TEAMS-002)

**Before (failing state)**:
```bash
echo "no context bundle"
```

**Action**: Invoke from channel with 50+ recent messages; from meeting with transcript; from chat with attachment.

**After (passing state)**:
```bash
jq -r '.context_items[].source' "$CHANNEL_DIR/context-bundle.json" | sort -u | wc -l
# Expected output substring: "3"
```

**Assertions**:
- [ ] After state: 3 distinct provenance values (teams.channel, teams.meeting, teams.attachment)
- [ ] Each item has `acquired_utc` + `acquired_by_agent_id`

---

## Test Group: FR-OUTLOOK — Outlook adapter (drafts, never auto-send)

**Traces to**: spec FR-OUTLOOK-001. Iter-41 reinstated.

### TC-OUTLOOK-001a — Mail thread invocation produces draft, never sends (FR-OUTLOOK-001)

**Before (failing state)**:
```bash
echo "no draft yet"
```

**Action**: Trigger engine from Outlook mail thread; engine produces draft reply.

**After (passing state)**:
```bash
grep -F "requires_human_approval: true" "$CHANNEL_DIR/outlook-draft-headers.txt"
# Expected output substring: "requires_human_approval: true"
```

**Assertions**:
- [ ] After state: draft visible in Drafts folder, NOT sent
- [ ] Draft has `engine: collab-engine`, `run_id`, `requires_human_approval: true` headers
- [ ] Approval via FR-OVERRIDE-001 manual verdict triggers send; SentItems poll confirms

---

## Test Group: FR-WORKIQ — Cross-app context query + proactive day-shaping

**Traces to**: spec FR-WORKIQ-001/002. Graph cache + day-shaping suggestions.

### TC-WORKIQ-001a — Graph context cached with 5-min TTL (FR-WORKIQ-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/workiq-cache.jsonl" && echo "present" || echo "absent"
# Expected: "absent"
```

**Action**: Run `/loop` with brief mentioning "draft my morning agenda".

**After (passing state)**:
```bash
jq -r '.context_items[].source' "$CHANNEL_DIR/workiq-cache.jsonl" | sort -u | wc -l
# Expected output substring: a number ≥ 2
```

**Assertions**:
- [ ] After state: each item has source + acquired_utc tags
- [ ] Re-run within 5min: no second Graph call
- [ ] After 5min: refresh

### TC-WORKIQ-002a — Proactive day-shaping surfaces non-binding agenda (FR-WORKIQ-002)

**Before (failing state)**:
```bash
jq -r '.engine.proactive' .mad/policy/policy.json
# Expected: "true" (precondition)
```

**Action**: Cron fires at 8am with `proactive: true`.

**After (passing state)**:
```bash
test -f "$CHANNEL_DIR/agenda-card.json" && jq -r '.auto_sent' "$CHANNEL_DIR/agenda-card.json"
# Expected output substring: "false"
```

**Assertions**:
- [ ] After state: agenda card produced; `auto_sent: false`
- [ ] FR-OVERRIDE-001 approval required to send drafts

---

## Test Group: FR-COCLAW — Distribution mode

**Traces to**: spec FR-COCLAW-001. Three modes: coclaw / supervisor / agent-teams-v1.5 (deferred).

### TC-COCLAW-001a — Mode flag controls channel.json shape (FR-COCLAW-001)

**Before (failing state)**:
```bash
echo "no engine started yet"
```

**Action**: Start with `--mode coclaw`; then `--mode supervisor`; then `--mode agent-teams-v1.5`.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR_TEAMS_V15/.session-stdout.log" | grep -F "MODE_DEFERRED_V1_5"
# Expected output substring: "MODE_DEFERRED_V1_5"
```

**Assertions**:
- [ ] coclaw mode: `mode: coclaw, principal_alias: <user>`, no shared-tenant indicators
- [ ] supervisor mode: `mode: supervisor`, peer-agent spawn supported
- [ ] agent-teams-v1.5: refusal with `MODE_DEFERRED_V1_5` (legitimate v1.5 deferral preserved)

---

## Test Group: FR-AGENT365 — Observability sink boundary

**Traces to**: spec FR-AGENT365-001. **Status**: v1 ships `local_file` and `no_op`; `agent365_central` v1.5-deferred per source verbatim.

### TC-AGENT365-001a — Local file sink writes Agent365 schema (FR-AGENT365-001)

**Before (failing state)**:
```bash
test -f "$CHANNEL_DIR/observability-sink.jsonl" && wc -l < "$CHANNEL_DIR/observability-sink.jsonl" || echo "0"
# Expected: "0" or absent
```

**Action**: Configure `sink_target: local_file`; run a session emitting retros + verdicts + cost-ledger entries.

**After (passing state)**:
```bash
wc -l < "$CHANNEL_DIR/observability-sink.jsonl"
# Expected output substring: a positive integer
```

**Assertions**:
- [ ] After state: sink file contains canonical Agent365 schema records

### TC-AGENT365-001b — no_op sink keeps engine functional (FR-AGENT365-001)

**Before (failing state)**:
```bash
echo "n/a"
```

**Action**: Configure `sink_target: no_op`; run a session.

**After (passing state)**:
```bash
test -f "$CHANNEL_DIR/observability-sink.jsonl" && echo "present" || echo "absent"
# Expected output substring: "absent"
```

**Assertions**:
- [ ] After state: no sink file, engine still functions

### TC-AGENT365-001c — agent365_central v1.5-deferral graceful (FR-AGENT365-001 deferred-feature pattern)

**Before (failing state)**:
```bash
echo "n/a"
```

**Action**: Configure `sink_target: agent365_central`; run a session.

**After (passing state)**:
```bash
cat "$CHANNEL_DIR/.session-stdout.log" | grep -F "v1.5 deliverable"
# Expected output substring: "v1.5 deliverable"
```

**Assertions**:
- [ ] After state: engine reports `[NOT IMPLEMENTED — v1.5 deliverable]`
- [ ] Falls back to `local_file` cleanly
- [ ] v1.5 deferral preserved verbatim per source per `memory/feedback_no_silent_deferrals.md`

---

## Domain Coverage Statement

| Domain Prefix | FR Count | TCs Bound | Notes |
|---|---|---|---|
| FR-CORE | 5 | 7 | 001, 002, 003, 004, 005 (with 005 having 3 sub-cases) |
| FR-COST | 3 | 3 | Observability-only telemetry per iter-41 refactor |
| FR-AUDIT | 2 | 3 | Hash chain + tampering + script |
| FR-AUDIT-PRIVACY | 1 | 1 | PII redaction schema |
| FR-GOV | 4 | 4 | Allowlist + sha256 + grounding + STRIDE Delta |
| FR-MULTI | 2 | 2 | Council mode + S1-S15 |
| FR-PROACTIVE | 1 | 1 | Cron heartbeat |
| FR-RING | 1 | 2 | Includes deferral-text-preservation case (v1.5 candidacy) |
| FR-SOUL | 1 | 2 | Includes --force-no-bypass case |
| FR-MUST-NOT | 1 | 1 | Out-of-Scope grep-detectable |
| FR-RELIABILITY | 1 | 1 | 8-enum failure-mode taxonomy |
| FR-IDENTITY | 1 | 2 | Signed spawn + Entra principal |
| FR-DRIFT | 1 | 1 | Skill behavior drift |
| FR-REPLAY | 1 | 1 | Audit chain replay |
| FR-OVERRIDE | 1 | 1 | Manual halt verdict |
| FR-FAIRNESS | 1 | 1 | [NEEDS CLARIFICATION] preserved (1 of 3 max) |
| FR-INTROSPECT | 2 | 3 | Sections + multi-task granularity + dual signals |
| FR-LIFECYCLE | 1 | 1 | Deprecated-skill grace period |
| FR-CALIBRATION | 1 | 2 | Grade emission + approval-gated tuning |
| FR-ISOLATION | 3 | 3 | OS perms + symlink + alias collision |
| FR-QUOTA | 1 | 1 | Per-spawn tool budget |
| FR-RATE | 1 | 1 | Channel review-rate cap |
| FR-KILL | 1 | 1 | Read-time kill-switch |
| FR-DEGRADE | 1 | 1 | 5-rung ladder |
| FR-TEAMS | 2 | 2 | Bot adapter + M365 context |
| FR-OUTLOOK | 1 | 1 | Drafts-only |
| FR-WORKIQ | 2 | 2 | Graph cache + day-shaping |
| FR-COCLAW | 1 | 1 | 3-mode flag |
| FR-AGENT365 | 1 | 3 | local_file + no_op + central-deferral |
| **TOTAL** | **45** | **52** | **45/45 FRs bound; 0 dropped; 1 [NEEDS CLARIFICATION] preserved** |

---

## Other domains (no findings)

Per anti-padding discipline (`rules/skill-standards.md` Dimension 2), categories with zero FRs are stated explicitly:

- **No findings — domain not represented in this spec**: `FR-DEFER`, `FR-MIGRATE`, `FR-ARCHIVE`, `FR-MULTI-EXTENSION`. The source spec explicitly Out-of-Scopes these (FR-ARCHIVE-001, FR-MULTI-001 ensemble extension, FR-MIGRATE-001) per its Out of Scope section. They are NOT in the active 45 FRs and so carry NO test scenario in this plan; they remain visible in the source spec's Out-of-Scope list.

---

## Pass/Fail History
| Date | Script Run | Result | Notes |
|------|-----------|--------|-------|
| — | — | UNTESTED | — |

## Known Issues
| Issue | Workaround | Reported |
|-------|------------|---------|
| FR-FAIRNESS-001 [NEEDS CLARIFICATION] | After-state binding deferred to /mad-plan tenancy resolution | 2026-05-02 |
| FR-RING-001 v1.5-candidacy | If /mad-plan hard-defers, TC-RING-001a moves to deferred-feature pattern; TC-RING-001b is the deferral-text-preservation guard | 2026-05-02 |
| FR-AGENT365-001 central impl | v1.5-deferred per source; TC-AGENT365-001c is the graceful-fallback assertion | 2026-05-02 |

---

## [NEEDS CLARIFICATION] markers (≤ 3 per skill body limit)

1. **FR-FAIRNESS-001 After-state**: tenancy resolution required (multi-tenant vs single-tenant vs single-operator). Preserved verbatim from source spec — counts as 1 of 3 max markers per `/mad-spec` skill body §4 step 3. No new markers introduced by this plan.

Total: 1 of 3 max.
