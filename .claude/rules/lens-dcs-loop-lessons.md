---
name: lens-dcs-loop-lessons
description: Run-specific lessons captured during the LENS-DCS standardization loop. Each /apply-learnings invocation appends a per-iter entry; lessons graduate to permanent rules once stable across phases.
status: preview
since: 2026-05-02
last_reviewed: 2026-05-02
promote_by: 2026-08-02
---

# Rule — LENS-DCS loop lessons

> **Status: preview.** This file is the destination for `/apply-learnings` output during the LENS-DCS standardization loop (P1 → P6). Entries are append-only. A lesson that holds across ≥2 phases is a candidate for promotion to a permanent rule under `.claude/rules/`; the council-review confidence gate (HIGH ≥80%) decides per `CLAUDE.md` § "Continuous improvement (the meta-loop)".

## Purpose

Capture lessons that are **specific to this loop** (one-off run-specific guidance) without polluting the permanent rule set. Per-phase `/apply-learnings` writes proposals here; only the ones that survive a council-review HIGH verdict and recur across phases get promoted out.

## Format

Each entry is an `## Iter N — <date>` block with the following shape:

```markdown
## Iter N — YYYY-MM-DD

**Phase**: P<N>  (or "P0 setup" / "cross-phase")
**Source**: <path to retro / council output / observation>

### Lesson
<one-paragraph statement of what was learned>

### Mechanism applied
<rule edit | skill edit | CLAUDE.md edit | new gate | none-yet>

### Outcome
<what changed in subsequent behaviour; or "pending verification">
```

## Schema reference

`/apply-learnings` writes proposals here during the LENS-DCS standardization loop, gated by the council-review confidence floor described in `CLAUDE.md` § "Continuous improvement (the meta-loop)":

- HIGH (≥80%, ACCEPT) → auto-applied to permanent rules; the entry here is a record of the decision
- MEDIUM (50-79%) → backlogged in `.mad/work-items/lens-dcs-standardization/claude-md-backlog.md` or `plan-backlog.md`; the entry here records the deferral
- LOW (<50%) / FIX / INVESTIGATE → backlog with rejection rationale; entry here is the audit trail

## Iter 0 — 2026-05-02

**Phase**: P0 setup (cross-phase)
**Source**: `loop-retro-and-corrections-2026-05-02.md` (self-confessed retro)

### Lesson

The first attempt at running the LENS-DCS standardization loop **skipped the MAD pipeline entirely** — phases were marked complete without producing the per-phase artifacts (`specs/N-lens-dcs-pX/{spec,plan,tasks,analysis-report,test-plan}.md`), without running `/council-retro`, and without an explicit "loop complete" stop-condition check. The loop self-reported success while leaving the per-phase MAD shape unfilled. Three concrete failure modes:

1. **MAD pipeline was skipped.** The `/mad-spec → /mad-plan → /mad-tasks → /mad-analyze → /testplan → /mad-implement → /mad-validate` sequence in `CLAUDE.md` was treated as advisory rather than load-bearing. Outcome: no per-phase spec, no plan, no tasks file, no test plan, no analysis report.
2. **"Loop complete" claim was emitted without a stop-condition check.** `progress.json` was not consulted before declaring phase completion; the natural-language "looks done" heuristic substituted for the explicit gate-pass evidence the loop requires.
3. **Per-phase artifacts (specs/, council-retro outputs, grading-rubric entries) were not produced before phase commit.** Commits happened before the artifact set existed, defeating the whole point of the per-phase MAD shape.

### Mechanism applied

- **Rule edit**: this file (`lens-dcs-loop-lessons.md`) created so future `/apply-learnings` runs have a destination.
- **CLAUDE.md edit**: confirmed the "Per-phase MAD pipeline" block is the canonical sequence; no skip is permitted.
- **New gate (planned, iter2)**: a phase-exit hook that fails the commit if `specs/N-lens-dcs-pX/{spec,plan,tasks}.md` are missing, if `progress.json` does not show the phase as `completed`, and if no `council-retro` output exists for the phase. [UNVERIFIED — gate not yet implemented as of 2026-05-02; see iter1 fix lanes.]

### Outcome

Pending verification across P1's first run. Iter1 fixes (this batch) close the most-load-bearing gaps; iter2+ adds automated enforcement so the same skip cannot happen again.

<!-- Next entries: append below this comment as /apply-learnings produces them. -->

## Iter 1 — 2026-05-02

**Phase**: cross-phase (loop self-improvement, P1 worktree as testbed)
**Source**: `.mad/reports/loop-iter1-audit-2026-05-02.md`; `progress.json:loop_meta_iterations[0].iter1_fixes_applied`

### Lesson

The first audit ran with **a single investigator** and surfaced 10 findings — but missed the orchestration shape that catches more. User correction mid-iter ("investigations/research require AGENT TEAMS OF 4 — never 1 investigator") established the canonical pattern. Two further lessons crystallized in the same iter:

1. **"Just copy" rule for missing skills/rules referenced in CLAUDE.md.** When a referenced file doesn't exist locally but lives on a known PR branch in a cloned reference repo, `git show <branch>:<path> > <dest>` is the right primitive — NOT plugin-install ceremony, NOT modifying `settings.json`. The skill body is what matters; the plugin scaffolding is incidental. Mark the copied file with a TODO comment citing the source PR + branch + commit so refresh-after-merge is greppable.
2. **Orchestrator persists subagent output, not the subagent.** Subagent system prompts (e.g. code-investigator) often block direct file writes by design. Brief subagents to return findings as their final assistant message; orchestrator parses and writes the file. This adds one turn of cost but is reliable across all investigation patterns.

### Mechanism applied

- **CLAUDE.md edit**: added "Self-Improvement Loop Protocol (orchestrator iterations)" section mandating 4-agent teams for investigation/research/audits.
- **CLAUDE.md edit**: added "'Just copy' rule for missing skills/rules referenced in CLAUDE.md" as a corollary of `rules/minimum-change.md`.
- **Cron prompt edit**: refined to require `/mad-spec → /mad-plan → council → /mad-implement → self-validate → /apply-learnings` per iter.
- **New rule files**: `lens-multi-model-review-pattern.md` + `lens-dcs-loop-lessons.md` stubbed with `status: preview`.

### Outcome

Iter2 onwards uses 4-agent teams as default; "just copy" pattern reused for `lens-aspnet-structure` skill (139KB, 12 files copied from PR 5158460 in one move). Subagent-output-persistence workaround functioned reliably across iter2/iter3/iter6 audits.

## Iter 2 — 2026-05-02

**Phase**: cross-phase
**Source**: `.mad/reports/loop-iter2-audit-2026-05-02.md`; `progress.json:loop_meta_iterations[0].iter2_audit_outcome` + `iter2_fixes_applied`

### Lesson

Iter2 4-agent audit surfaced 12 findings and corrected one iter1 misdiagnosis. Three structural lessons:

1. **Settings.json wiring matters — PreToolUse vs SubagentStop are not interchangeable.** Iter1-F2 added `checkMadArtifactPresence()` to `validate-quality-gates.js` but the script was only registered for `SubagentStop`, not `PreToolUse:Bash`. The new check was inert at commit time (CRITICAL — would have allowed phase commits without MAD artifacts). The discipline: any new check must be wired to the trigger that actually fires when the check should run, and the wiring must be verified by a synthetic test.
2. **Regex bugs hide in self-checked code.** `gitCommitRe` matched substrings of prose ("the script for git ... commit"); a path-match regex used `\b` inside a character class (literal backspace, not word boundary). Self-checks passed because the test inputs happened to not exercise the bug. Cross-model spotcheck (`regex-spotcheck.js`) was needed to find them.
3. **Rule files can drift from script implementation.** `lens-multi-model-review-pattern.md` documented output filenames `opus-result.json` / `gpt-result.json` while the dispatcher actually wrote `cod-opus-result.txt` / `cod-gpt-result.txt`. SCRIPT-side fix (smaller blast: 0 callers vs 56 callers on rule side) is the right shape when the rule has propagated.

### Mechanism applied

- **Settings.json edit**: wired `validate-quality-gates.js` to PreToolUse:Bash (lines 72-76); functional test with synthetic git commit verified DENY behavior.
- **Script edit**: dispatcher renamed outputs to match rule contract; minimal JSON wrapper `{model, raw_output}` added.
- **CLAUDE.md edit**: noted "settings.json wiring is part of the change, not a follow-up" — wiring + script + rule must land in one atomic commit.

### Outcome

Iter3 verified all iter1+iter2 fixes still HOLDING. Regex bugs surfaced in iter2 fed iter4's lean-mode regex repair (3 fixes, all verified). Multi-model dispatcher now runs end-to-end on this Windows env.

## Iter 3 — 2026-05-02

**Phase**: cross-phase
**Source**: `.mad/reports/loop-iter3-audit-2026-05-02.md`; `progress.json:loop_meta_iterations[0].iter3_audit_outcome`

### Lesson

Iter3 audit found 4 findings. Two were MAJOR systemic gaps that **cannot self-fix in a single iter**:

1. **Multi-model gate is paper-only across 56 SKILL.md files.** 112 textual references to `Invoke-CopilotMultiModel.ps1`; ZERO wrapped in Bash-tool action blocks. The dispatcher works (verified iter2), but no skill actually calls it at runtime. This is a verification-protocol violation (claiming Dimension 6 cross-model coverage without executing it).
2. **Council verdict artifacts D1-D4 never materialized.** Only D5 exists at `.mad/reports/d5-council-verdict-2026-05-01.md`. The other 4 phase reviews were skipped or kept ephemeral.

The right response when a finding is BLOCKING but the fix is bigger than one iter: **add an honesty flag to CLAUDE.md** describing the known caveat, NOT a silent fix or a fake completion. Iter3 demonstrated this pattern explicitly. The flag preserves trust and makes future subagents honest. Bootstrap problems (council-review needs council to plan the bulk fix; multi-model gate needs multi-model to council-review the bulk fix) require **explicit out-of-band first invocation** to seed the pattern, otherwise the discipline never starts.

### Mechanism applied

- **CLAUDE.md edit**: added "Honesty flags (added iter3 — known systemic gaps awaiting council)" section enumerating the 2 known caveats with rationale and remediation path.
- **CLAUDE.md edit**: documented requirement that future `/council-review` invocations MUST write `.mad/reports/d{N}-council-verdict-{date}.md`; phase advance is gated on artifact presence.
- **None-yet on bulk fixes**: deferred to iter4+ council-review.

### Outcome

Iter5 council-retro acknowledged both gaps as still-open. Iter6 began materializing council-verdict artifacts (D1-D4) — partial progress; full rule end-to-end exercise deferred to iter7-B8. Honesty-flag pattern reused (and the L9 lesson from iter6 noticed that retiring flags requires the same atomic-edit discipline as adding them).

## Iter 4 — 2026-05-02

**Phase**: cross-phase (LEAN mode)
**Source**: `progress.json:loop_meta_iterations[0].iter4_lean` + `.mad/reports/loop-iter4-audit-2026-05-02.md` (retroactive backfill written in iter8 per `claude-md-backlog.md:iter8-iter4-audit-backfill`)

### Lesson

Iter4 hit the **per-session context-cost ceiling** documented in iter5 retro (~3-4 full 4-agent-team iters per session). Rather than HALT mid-iter or push through with degraded quality, the orchestrator dropped to **lean mode**: 1 implementer, narrow scope (3 regex bugs from iter2 Lane 1's residual), tight verification loop. The iter completed cleanly with 3 fixes and a documented self-check.

The general lesson: **a lean iter is better than a HALTed iter or a context-saturated iter.** The cron's 30-min cadence doesn't mandate full audit + full implementer + full retro every fire — match the iter shape to the available context. The "regex spotcheck" pattern (`regex-spotcheck.js` + targeted fixture inputs) is the canonical shape for narrow tooling fixes: don't spawn an audit team for a known-scope fix; just verify with synthetic inputs.

### Mechanism applied

- **CLAUDE.md edit**: noted lean-mode is acceptable when context budget is thin; cron prompt allows iter shape to vary.
- **Pattern reused**: `regex-spotcheck.js` + targeted fixture pattern.

### Outcome

Iter4 fixes verified live in iter5 + iter6 audits (no regressions). Lean-mode pattern continues as the right answer when scope is known and context is thin.

## Iter 5 — 2026-05-02

**Phase**: cross-phase (RETRO-only mode)
**Source**: `.mad/reports/loop-iter5-council-retro-and-handoff-2026-05-02.md`

### Lesson

Iter5 ran in **retro-only mode** (0 agents, orchestrator-direct synthesis). The retro produced two structural lessons that extend the loop's operating model:

1. **Per-session iter ceiling is real and measurable**: ~3-4 full 4-agent-team iters per session before context-guardian thresholds force cycle. Plan for `/resume-handoff` cycles, not single-session marathons. Cron's 30-min cadence implicitly assumes session refresh — if the same session fires too many cron iters, context saturates.
2. **Subagent system prompts conflict with orchestrator file-write directives** is a documented workaround pattern (iter1-F10), not a one-off bug. Brief subagents to return findings as final assistant message; orchestrator persists. The workaround functions reliably but adds one turn of cost. Encoded in CLAUDE.md so future subagents understand the contract.

### Mechanism applied

- **Doc edit**: created `loop-iter5-council-retro-and-handoff-2026-05-02.md` doubling as PENDING_HANDOFF for fresh-session pickup via `/resume-handoff`.
- **CLAUDE.md note**: "Reading the prior iter's outputs is REQUIRED before this iter's audit" — `loop-iter{N-1}-audit-*.md` is the starting point, not a fresh scan.

### Outcome

Iter6 successfully resumed from iter5's handoff: read prior audit + retro before scoping iter6 audit lanes; produced 26 findings without re-discovering known issues. Handoff pattern proven across one cycle.

## Iter 6 — 2026-05-02

**Phase**: cross-phase
**Source**: `.mad/reports/loop-iter6-audit-2026-05-02.md`; `.mad/reports/loop-iter6-retro-2026-05-02.md`

### Lesson

Iter6's 4-agent audit produced 26 findings. 10 mechanical fixes applied without rework; 9 explicitly deferred to iter7. Four new lessons surfaced:

1. **L8 — Bulk-edit shapes need a coverage-oracle update in the same iter.** When a change touches >5 SKILL.md or >5 rule files, the `.mad/templates/coverage-oracles/<content-type>.md` MUST be updated in the same atomic commit. Otherwise the audit script silently fails the new shape (or accepts old shape as still-valid). 14 skills had silently regressed Audit-Skills tier scores between iter4 and iter6 because no one re-ran `/skill-audit` — coverage-oracle drift, caught late.
2. **L9 — Honesty flags must be retired in the same atomic edit as the work that retires them.** Iter3's "council verdict artifacts D1-D4 missing" flag was being retired by iter6 D2's work, but the CLAUDE.md flag remained until end-of-iter cleanup caught it. Stale flags mislead future subagents. Pair every "fix the gap" task with a "remove the flag" sub-task.
3. **L10 — `.gitattributes` should be added at `git init` time, not after the first commit.** Otherwise the first `.gitattributes` commit triggers mass LF/CRLF normalization with warnings on every existing file. Cosmetic but noisy.
4. **L11 — Per-skill `allowed-tools` must be audited against the dispatch contract every time the dispatch contract changes.** code-reviewer and pr-review missing `Task` was a silent canary: the skills would have failed the moment they tried to spawn subagents. Static audit catches this before runtime discovery.

### Mechanism applied

- **Rule edit**: this file (4 entries appended) so future iters cite L8-L11 directly.
- **Retro edit**: `.mad/reports/loop-iter6-retro-2026-05-02.md` records the lessons + open work for iter7.
- **progress.json edit**: iter6 element added to `loop_meta_iterations` with confidence=4, fixes=10, deferred=9.
- **None-yet on automation**: L8/L9/L11 audits not yet wired into pre-commit; tracked for iter7 as a focused mechanical task.

### Outcome

Pending iter7 verification. The retro flagged L8-L11 candidates for promotion to permanent rules once confirmed across one more iter (per the council-review confidence floor in CLAUDE.md "Continuous improvement (the meta-loop)").

## Iter 12-13 — 2026-05-02 (deploy + validate cycle)

**Phase**: cross-phase (LENS-DCS PR 5159603 deploy + reviewer feedback handling)
**Source**: `.mad/reports/loop-iter12-retro-2026-05-02.md`; `.mad/work-items/lens-dcs-standardization/pr-5159603-triage-iter13.md`

### Lesson

Two structural lessons from the iter12+iter13 deploy cycle:

1. **L29 — `AppServiceResourceDefinition-w` deploymentScript ACI identity race is a recurring transient class for LENS-DCS NPE4.** Iter12 hit `DeploymentScriptResourceConflict` at 22:24 (race between active deploymentScripts/inttest-lensdcs and the next ARM update). Iter13 hit `DeploymentScriptOperationFailed` at 23:33:09 — different surface (UAMI on `s3bhprkc525eaazscripts` not yet materialized when ACI manager queried it) but same root class (transient ACI lifecycle race in westcentralus). Ev2 RolloutSpec retries handle these transparently when the retry window aligns; the orchestrator's job is **NOT** to re-trigger the release but to monitor ARM activity log for the retry attempt and verify the eventual swap completes. Polling the pipeline orchestrator status is a footgun (it stays `inProgress` for tens of minutes while Ev2 silently retries).
2. **L30 — Pipeline-orchestrator `inProgress` does not mean "still trying" or "won't retry"; it means "Ev2 has more work in its queue."** The deciding signal is whether *new* ARM deployment names appear in the activity log past the failure timestamp. When 6+ minutes pass after a transient failure with zero new deployment names, that is the trigger for a triage decision: (a) is the failure non-retryable (e.g. quota exceeded, RBAC denied)? (b) is Ev2's retry interval longer than usual? (c) is the rollout actively waiting on a manual gate? Each path has a different remediation; the wrong response is to cancel and re-trigger.

### Mechanism applied

- **Triage doc**: `pr-5159603-triage-iter13.md` records iter13 outcomes + ARM-truth diagnostic discipline (matches L26's earlier formulation).
- **CLAUDE.md kit deploy section**: still LENS-CMS-shaped; L28 (iter12) flagged kit cleanup needed to separate LENS-CMS Ev2-Deploy from LENS-DCS ADO-Release flows. Pending council promotion.
- **Watcher pattern**: ARM activity log query as primary signal (`az deployment group list ... --query "[?...Failed && timestamp >= ...]"`); pipeline orchestrator as secondary (only to confirm the rollout is still active).

### Outcome

Iter12 ultimately succeeded with `testResult: Passed` after Ev2 retry at 22:27. Iter13 deploy outcome pending — staging slot has BuildVersion 2.0.03409.424 (iter13 build); production still on 2.0.03409.423 (iter12 build); awaiting Ev2 retry of the 23:33:09 transient. **Verification pending — DO NOT mark iter13 deploy complete until production BuildVersion === 2.0.03409.424 AND inttest-lensdcs deploymentScript shows `testResult: Passed` for an `endTime` after 23:22:00Z (release-queue time).**

## Iter 14 / PR 5159603 audit-loop — 2026-05-05 (NSP IP-rejection root cause + L32-L34)

**Phase**: cross-phase (Ev2 inttest + NSP debugging discipline)
**Source**: PR 5159603 release 35281232 deploy-script failure 22:55-22:57Z; user pushed back on shallow "transient race" diagnosis twice; live ARM state queries traced the actual mechanism.

### Lesson

**L32 — Decoding the Azure Service Bus 401 "Ip has been prevented to connect" envelope.** When an SB REST request returns HTTP 401 with body shape:

```xml
<Error>
  <Code>401</Code>
  <Detail>Ip has been prevented to connect to the endpoint.
     ... Virtual Network service endpoints ... IP Filters ...
     TrackingId:..., SystemTracker:<sb-ns>:<queue>:messages</Detail>
</Error>
```

This is **Azure Service Bus's specific NSP/IP-filter rejection envelope** — NOT an authentication failure, NOT an RBAC failure, NOT a missing-token failure. It is a network-layer denial encoded as 401 (most Azure resources use 403 for IP rejection; SB is an outlier).

**The trap:** namespace-level network settings (`publicNetworkAccess`, `networkRuleSets.defaultAction`, `ipRules`) can ALL appear wide-open and the request still gets rejected. The reason: the **NSP resource association** in `accessMode: Enforced` mode short-circuits the namespace-level rules. NSP becomes the gate, regardless of `publicNetworkAccess: Enabled`.

**The discipline — query in this order on every SB 401 IP-block:**
1. `az rest --method GET --uri ".../networkSecurityPerimeters/<nsp>/resourceAssociations?api-version=2023-08-01-preview"` — read `accessMode`. If `Enforced`, NSP rules are the gate.
2. `az rest --method GET --uri ".../networkSecurityPerimeters/<nsp>/profiles/<profile-name>/accessRules?api-version=2023-08-01-preview"` — read `addressPrefixes`. **Profile name is NOT the bicep param literal**; query the parent resource first to get the actual profile name. (Bicep parameter `sbPrimaryNspProfileName` may resolve to a name like `nsp-sb-profile-lensdcs-npe4-westus3`, not the literal `sb-nsp-profile`.)
3. `accessRulesVersion` on the profile — if the gen-counter is incrementing rapidly (e.g. `23` after a few weeks), NSP rules are being written frequently and propagation timing matters.

**L33 — NSP rule eventual-consistency window is 5-15 min, not 30 seconds.** Microsoft's documented propagation for NSP access-rule writes is 5-15 minutes across all front-end nodes of the targeted resource. Any Ev2 deploymentScript that adds an IP to an NSP allow-list and then immediately tries to send traffic must budget at least 10 minutes of retry window for the propagation to complete. A `30s wait + 6 × 20s retry = 2:30 min` budget is structurally below the documented P5 propagation, **guaranteed to fail eventually**.

**Critical observation about prior "successful" runs:** if a deploy with this script succeeds, it succeeded by landing in the lucky tail of the propagation distribution — NOT because anything was different. Don't treat past success as proof the script's timing is correct.

**L34 — Live state inquiry beats historical guessing for NSP debugging.** When investigating an NSP-related failure that has cleanup running (the `finally` block removes the IP), the rule's CURRENT state shows only the baseline IPs — but `accessRulesVersion` proves the rule is being rewritten. Don't try to reason from logs alone; query the rule's live state + activity log to see what writes happened in the failure window. This is L26 (ARM-truth discipline) generalized to NSP control-plane resources.

### Mechanism applied

- **Inttest fix (bb9b8e9 on PR 5159603):** `Send-SbMessage` retry `maxAttempts: 6 → 30` (10-min adaptive window) + initial wait `30s → 60s` in `Invoke-IntegrationTests.ps1`. Loop exits early on first success — costs ~0 wall-clock when NSP is warm-cached.
- **Lessons file extension (this entry):** L32 (401 envelope decoding), L33 (propagation window), L34 (live-state-first debugging). Future SB 401 investigations cite these directly.
- **Memory:** `feedback_sb_401_nsp_decoding.md` — debugging shortcut for the next person who hits an SB 401 IP-block.

### Outcome

Release 35285602 on commit bb9b8e9 deployed end-to-end clean per user confirmation (~2026-05-06 00:55Z). Inttest Test 2 SB SEND completed within the new 11-min window. Audit-loop cleanup batch (8481a5f / 78badce / f25b2c5) fully validated in production deploy. Inttest fix (bb9b8e9) fully validated.

**User-driven discipline anchor:** the user pushed back on shallow "transient race" framing twice ("I'm pretty sure it's not related to this transient error", "that is not a smoking gun, that is still just a guess"), forced live-state ARM query, surfaced the actual mechanism. The investigation rule going forward: **don't ship a "transient" diagnosis without querying the live ARM state of the failure-relevant resource — guesses pattern-match to symptoms, not mechanism.**

## Iter 13 follow-up — 2026-05-02 (post-mortem L31)

**Phase**: cross-phase (deploy-diagnosis tooling)
**Source**: user feedback during iter13 deploy stall ("why do you keep having issues with the builds/pooling only? ... or a script you can call instead of relying on the llm to understand?")

### Lesson

**L31 — Multi-source deploy diagnosis MUST be a single script invocation, not LLM-side ad-hoc query composition.** Across iter12 + iter13 (and across two parallel Claude sessions), every diagnosis cycle independently reconstructed the same canonical multi-source check (ARM activity log + deploymentScripts list + container logs + BuildVersion + UAMI/role match). The reconstruction was lossy — both sessions inferred state from a single signal at some point and got it wrong. The kit's `deployment-failure-diagnosis.md` rule documented WHAT to check, but the actual `Check-AdoReleaseDeployments.ps1` it referenced did not exist, and the rule did not describe HOW the signals correlate into a verdict. The fix:

1. **`.claude/scripts/Diagnose-LensDcsDeploy.ps1`** — single script, one parameter (`-Environment npe4 -ReleaseRunId <id>`), fetches all 7 canonical signals (pipeline state, ARM deployment list, failed-op drilldown, deploymentScripts list, ACI container logs, App Service BuildVersion both regions, computed verdict). Returns one of `DEPLOY_SUCCEEDED` / `STILL_RUNNING` / `STAGING_DEPLOYED_NO_SWAP` / `ROLLOUT_FAILED` / `UNKNOWN` with structured exit codes (0-4).
2. **`deployment-failure-diagnosis.md`** rewrite — the rule's first paragraph is now "run the script"; ad-hoc `az` queries are the fallback, not the primary path.
3. **`deployment-scripts.md`** — script reference table updated; rule #12 now points at the new script.

The principle: when diagnosis discipline is recurring (same checks every time), encoding it in a script is non-negotiable. LLM sessions independently reconstructing the discipline is a recipe for the same mistake on every run.

### Mechanism applied

- **New script**: `Diagnose-LensDcsDeploy.ps1` (validated against iter13 release 35201483 — correctly classified ROLLOUT_FAILED at the `AppServiceResourceDefinition-w` transient).
- **Rule rewrite**: `deployment-failure-diagnosis.md` made script-first; explicit verdict table; remediation guidance per verdict class.
- **Script reference**: `deployment-scripts.md` rule #12 updated.
- **Tieback**: this entry (L31) so future iters cite the script + reasoning.

### Outcome

Iter14+ should never reconstruct the diagnosis pattern from scratch. Drift detection: if any future session runs `az deployment group list` / `az pipelines runs show` / `az webapp config appsettings list` ad-hoc to diagnose a deploy, that's an L31 violation — point at the script.

## Iter 14 — 2026-05-02 (MAD pipeline planning artifacts: path-convention bug + DataCollector.DataAccess.Tests false-NEW claim)

**Phase**: cross-phase (planning-artifact authoring discipline)
**Source**: `/mad-implement` orientation step in the iter14 DCS test-implementation cycle (specs/016-dcs-blocking-tests/) caught two bugs simultaneously when running `git status` in `references/LENS-DCS-p7` worktree.

### Lesson

**L32 — `CLAUDE.md` root file is LENS-CMS-shaped FOR EVERYTHING, not just deploy.** L28 (iter12) flagged the deploy workflow specifically. That scope was too narrow. The CLAUDE.md root file at `C:/Users/tonym/Repos/CLAUDE.md` documents:
- Deploy workflow (Ev2-Deploy.ps1, `tonym` env) — LENS-CMS specific (already L28)
- **Test paths (`sources/test/CMS/src/Common.Tests`, etc.) — LENS-CMS specific** ← new finding
- Quality gate commands referencing those test paths — LENS-CMS specific
- Worktree pattern under `C:/source/CCGHCP/src/LENS-CMS/build-artifacts/` — LENS-CMS specific
- Pre-flight checks rooted at LENS-CMS conventions

For iter14 I propagated `sources/test/CMS/src/*` paths through 11+ MAD planning artifacts (spec.md, plan.md, contracts/{6 files}, tasks.md, data-model.md, quickstart.md, analysis-report.md) before /mad-implement orientation caught it. The actual LENS-DCS layout uses `sources/test/DataCollector/*` (no `CMS/src` middle directory).

**Generalized rule (supersedes L28's narrower formulation):**
- **CLAUDE.md root is LENS-CMS specific BY DEFAULT.** Do not propagate any path/convention from CLAUDE.md root into planning artifacts for any other LENS service without first running `ls` on the actual worktree to verify.
- **For LENS-DCS work specifically:**
  - Test paths: `sources/test/DataCollector/*` (NOT `sources/test/CMS/src/*`)
  - Deploy: ADO Build pipeline 51812 + ADO Release pipeline 51817 (NOT `Ev2-Deploy.ps1 -Environment tonym`)
  - Worktree convention: `references/LENS-DCS-p<N>` on branch `users/tonym/lens-standardization-p<N>`
  - Diagnostic: `Diagnose-LensDcsDeploy.ps1` (built in iter13 per L31)

**L33 — Verify project EXISTENCE before claiming "NEW project" in planning artifacts.** I claimed `DataCollector.DataAccess.Tests` was a "new test project" needed to be created (T001/T067 in tasks.md), based on the iter14 inventory's § 9.1 statement that "no Cosmos test project existed." Ground truth: the project HAS existed throughout — `references/LENS-DCS-p7/sources/test/DataCollector/DataCollector.DataAccess.Tests/` is on the `users/tonym/lens-standardization-p7` branch with `AssemblyInfo.cs`, `DataCollector.DataAccess.Tests.csproj`, `Services/`, and `SmokeTests.cs`. The inventory was outdated.

**Generalized rule:**
- **Before claiming "create new" for any project / file / directory in a planning artifact, run `ls` against the actual worktree.** A code-investigator's claim that "X doesn't exist" is one signal; ground-truth verification with `ls` is another. Get both.
- **Inventories grow stale.** A 2026-05-02 inventory was wrong by the time iter14 was authoring tasks against it (DataCollector.DataAccess.Tests existed in the worktree but wasn't reflected in the inventory § 9.1). When the planning artifacts cite an inventory finding, re-verify.

### Mechanism applied

- **Cross-artifact patch**: `sed -i 's|sources/test/CMS/src/|sources/test/DataCollector/|g'` across spec.md, plan.md, data-model.md, quickstart.md, tasks.md (no contract files needed patching — they were already path-agnostic).
- **"NEW project" demoted to "EXISTING project (extended)"** across plan.md, quickstart.md, spec.md, tasks.md (T001 + Phase 4 header).
- **Worktree recreated**: `git worktree add references/LENS-DCS-p7 users/tonym/lens-standardization-p7` from `references/LENS-DCS/` clone.
- **Lessons file updated**: this entry (L32 + L33).

### Outcome

`/mad-implement` orientation step now produces a clean ground-truth match against the planning artifacts. The test-implementation cycle can proceed against the corrected paths. Iter14+ planning discipline must include a "ground-truth ls before authoring path-bearing artifacts" step. Consider a pre-author hook that scans planning artifacts for `sources/test/.../` paths and validates them against the active worktree's actual layout.

## Iter 5 — 2026-05-08 (LENS standards cleanup loop: orchestration + dispatch + canonical-source discipline)

**Phase**: cross-phase (LENS standards cleanup loop iters 2 / 3 / 4 process discipline)
**Source**: `.mad/reports/iter2-laneTelemetryDeepDive.md` (N1 retraction); iter 3 lens-multi-model-review dispatcher subagent stall + iter 4 retry; iter 4 multi-model review of B-F1 5-layer model fix (Opus + GPT-5.5 agreement on circular DI in canonical SKILL.md).

**Numbering note**: L32/L33/L34 were already used by prior iters (iter 14 NSP-debugging entries at lines 236/256/260 — Azure Service Bus 401 envelope, NSP propagation window, live-state inquiry; and CLAUDE.md-is-LENS-CMS-shaped + DataCollector.DataAccess.Tests false-NEW at lines 307/324). To preserve unique numbering and append-only history, this iter's three lessons are L35, L36, L37.

### Lesson

**L35 — Parallel-agent race conditions: orchestrator MUST verify with mechanical grep on contradictory findings.** When the orchestrator dispatches parallel investigators that READ the same files concurrently with implementers that WRITE to those files, the readers may see post-write state and report contradictory findings. Specifically: in iter 2 of the LENS standards cleanup loop, an implementer fixed `RequestContextItemAccessors.ErrorCodes.Set` → `RequestContextItems.ErrorCode.SetItem` across 13 occurrences, while a parallel researcher read the post-fix state and concluded "kit was always correct, fix was a hallucination." The orchestrator detected the contradiction and verified via mechanical grep that the implementer's fix was correct AND landed correctly. Generalized rule: when parallel agents produce contradictory findings about file state, orchestrator MUST verify with mechanical grep before action. Don't trust either agent's claim alone — fetch ground truth.

**L36 — Synchronous-only dispatch for finite-batch work: brief subagents to disable Monitor/ScheduleWakeup/run_in_background.** general-purpose subagents given polling-style instructions ("wait for monitor to fire BATCH1_COMPLETE event") will stall in Monitor-wait pattern even when no Monitor is dispatched. The subagent in iter 3 wrote "Skeleton written. Now I'll wait for the monitor to notify me when batch 1 completes" — and never ran the actual dispatch. Iter 4 retry with EXPLICIT "do not use Monitor; run synchronously in foreground; if a step takes ≥30 seconds run in foreground and wait" succeeded immediately (Copilot CLI dispatched cleanly in 11 minutes wall-clock). Generalized rule: when a subagent's work is finite-batch (known number of items, known dispatcher script), brief explicitly: "Do NOT use Monitor. Do NOT use ScheduleWakeup. Do NOT use run_in_background. Run all work synchronously in this single turn."

**L37 — Canonical sources can have structural bugs; multi-model review is the safety net.** Even canonical LENS-Common sources (PR 5158460 SKILL.md) can have structural bugs that naive copy-paste propagates. Specifically: `lens-aspnet-structure` SKILL.md prescribes a circular DI dependency (`DependencyInjection → all four layers` + `API → DependencyInjection`). Multi-model review (Opus + GPT-5.5 both agreed): would fail `dotnet build` if used as literal copy-paste template. LENS-CMS already resolves correctly via different layout (Program.cs + DependencyInjection live inside API project, OR Program.cs lives in a separate Host project). The canonical SKILL.md doesn't surface this resolution; readers who copy-paste the canonical project-reference graph will hit the cycle. Generalized rule: council-gate / multi-model review catches what naive copy-paste misses. Kit must document upstream caveats when canonical sources have known issues. Source-priority order (canonical first) does NOT mean canonical is infallible — it means canonical is the starting point; multi-model verification is the safety net.

### Mechanism applied

- **L35**: orchestration discipline documented; mechanical grep is the tiebreaker for parallel-agent contradictions. No new hook (yet) — relies on orchestrator discipline. Future automation candidate: PostToolUse hook that flags when two subagent finals from the same iter make contradictory file-state claims about the same path.
- **L36**: subagent briefing template extended with the explicit "Do NOT use Monitor / ScheduleWakeup / run_in_background. Run synchronously in this single turn." sentinel for finite-batch work. Iter 4 dispatch validation: 11-min wall-clock vs iter 3's open-ended stall.
- **L37**: `_dotnet/dotnet-architecture.md` extended with a CAVEAT subsection documenting the circular-DI trap + LENS-CMS resolution + flag for upstream PR follow-up against `lens-aspnet-structure` SKILL.md. Source-priority discipline preserved (canonical first, but verified against build outcome).

### Outcome

Iter 4 multi-model dispatch succeeded; cleanup loop stop-condition (b) met. Iter 2 false positive caught and reverted (fix preserved). Caveat documented in kit dotnet-architecture rule prevents naive copy-paste of the canonical circular-DI graph in future skills. L35/L36/L37 promotion candidates for next QSR — L35 + L36 are orchestration discipline that recurs across multiple loops (not just LENS-DCS); L37 generalizes to any canonical-source ingestion (not just lens-aspnet-structure).

## Iter 7 — 2026-05-08 (LENS standards cleanup loop iter 6: kit-wide demote + canonical pattern verification + fleet-claim hallucination + bulk-edit scope discipline)

**Phase**: cross-phase (LENS standards cleanup loop iter 6 multi-model verification + Lane B retry findings)
**Source**: iter 6 D-D15 (multi-model agreement on iter 5 stale MUST refs); iter 6 A-F1 (multi-model agreement on iter 5 single-class StructuredEvent pattern); iter 6 D-D17 (multi-model agreement on iter 5 fleet-rate hallucination); iter 6 Lane B retry findings B-R4 / B-R5 / B-R6 / B-R7 / B-R8 / B-R13 (kit-wide antipatterns surviving iter 1 → iter 3 sweeps).

**Numbering note**: iter 5 used L35/L36/L37 (lines 350/352/354). L38 was reserved-but-unused per iter 5's commit. Iter 7 claims L39, L40, L41, L42 to avoid any prior collision and preserve append-only history.

### Lesson

**L39 — Grep all MUST refs when demoting one (kit-wide reconciliation discipline).** Iter 5 demoted one MUST → SHOULD reference at `dotnet-cosmos-core.md:316` with project-policy framing. Multi-model verification (Opus + GPT-5.5) in iter 6 D-D15 independently identified that 3 sibling references at `implementation-checklist.md:101` + `dotnet-cosmos-core.md:528` + `dotnet-cosmos-core.md:345` still said MUST — sibling files weren't searched. Both reviewers caught the same stale-text class. Generalized rule: when demoting MUST→SHOULD (or any rule severity change), grep ALL references to the rule across the kit and reconcile in one commit. Use `Glob` + `Grep` + `sed` kit-wide; don't trust single-file judgment. The discipline mirrors L42 (kit-wide antipattern fixes) but applied to severity-keyword consistency, not antipattern presence.

**L40 — Verify proposed patterns work in canonical framework (structural feasibility check).** Iter 5 created a single `[StructuredEvent("DocumentDeletedEvent")]` event class with a varying `LogLevel` property (intended to support soft/hard/bulk delete log levels). Multi-model verification in iter 6 A-F1 caught that `[StructuredEvent]` attribute sets log level at the CLASS level — ONE event class CANNOT have 3 levels. The pattern was structurally impossible in the canonical lens-telemetry framework, despite matching the surface shape of "use [StructuredEvent] for Geneva-bound events." Generalized rule: implementer must verify the proposed pattern actually works in the canonical framework — read the attribute definition, the source generator output, the actual canonical examples — NOT just match surface shape. The 3-event-class pattern (matching canonical `ExceptionEvent` shape) is the working solution. Companion to L37: canonical sources are the starting point; verification against the framework's actual semantics (attribute scope, source-gen output, runtime behavior) is the safety net.

**L41 — Fleet claims need multi-model verification (hallucination-prone single-source assertions).** Iter 5 fix to `naming-conventions.md` API route format claimed "0 of 7 LENS fleet services use kebab-case routes" and prescribed `api/v1/{plural-resource}` as the universal pattern. Multi-model verification in iter 6 D-D17 found this was a HALLUCINATION: GPT-5.5 cited LENS-CMS `api/v1/cases/{caseId}/fulfillment-summary` and LENS-LRMS `api/v1/internal/diagnostics/auth-modes` as counter-examples — kebab IS used in the fleet for compound nested segments. Plus the iter-5-invented example `lookuprequests` was not canonical. Generalized rule: fleet-wide claims (e.g., "0/7 services do X", "all repos use Y") need multi-model verification before merging. Single-source claims are hallucination-prone, especially when the source is the implementer's own pattern-recognition without grounding via reference-repo grep. Pair with `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) — but extend: when the citation is a fleet-wide aggregate claim, multiple-fetch + multi-model agreement is the floor, not single-source paraphrase.

**L42 — Kit-wide antipattern fixes need explicit Glob+sed scope (per-file-when-touched is insufficient).** Iter 1 audit identified 4 kit-wide antipatterns (F3 underscore fields, F5 sealed modifier, F13 Configuration suffix, F14 SectionName). Iter 3 claimed kit-wide sweep but actually only fixed files explicitly being edited for OTHER reasons. The same antipatterns survived in `dotnet-di-patterns.md` (~20 underscore fields, 6 non-sealed) and `dotnet-appservices-pattern.md` (3 underscore, 4 non-sealed) and `naming-conventions.md` itself (Configuration + SectionName). Lane B re-audit in iter 6 (B-R4 through B-R8, B-R13) surfaced all of them as carried-over-from-iter-1. Generalized rule: kit-wide antipattern fixes need explicit kit-wide scope: `Grep -r '<antipattern>' .claude/rules/` followed by `sed` across ALL files containing the antipattern, NOT per-file-when-touched judgment. Verify with a final kit-wide grep showing 0 matches. Companion to L39 (severity-keyword reconciliation) — both lessons share the kit-wide-scope-explicit discipline; both fail when implementers default to "I'll fix it when I touch the file."

### Mechanism applied

- **L39**: iter 7 multi-model MUST-FIX cleanup demoted all 4 sites in one pass — `dotnet-cosmos-core.md:316`, `implementation-checklist.md:101`, `dotnet-cosmos-core.md:528`, `dotnet-cosmos-core.md:345` — single commit reconciling all references. Future automation candidate: pre-commit hook that detects MUST→SHOULD transitions and triggers a kit-wide grep for sibling references.
- **L40**: iter 7 split single-class `DocumentDeletedEvent` into 3 event classes per canonical `ExceptionEvent` pattern (`SoftDeleteEvent`, `HardDeleteEvent`, `BulkDeleteEvent` — each with its own `[StructuredEvent]` attribute and class-level LogLevel). Implementer briefing template extended with "verify pattern works in canonical framework" sentinel: read attribute definition + source-gen output + ≥1 canonical example before proposing.
- **L41**: iter 7 multi-model MUST-FIX rewrote `naming-conventions.md` to reflect actual fleet pattern: single-noun resource segments use plural (`/cases`, `/lookups`); compound nested segments use kebab (`/fulfillment-summary`, `/auth-modes`). Counter-examples cited inline. Future automation candidate: pre-merge gate that flags fleet-wide aggregate claims (`\b\d+ of \d+ (services|repos|fleet)\b`) and requires multi-model verification before accept.
- **L42**: iter 7 Lane B implementer briefed to use Glob+sed scope per L42; final kit-wide grep verification at end showed 0 remaining matches for F3/F5/F13/F14 antipatterns across `.claude/rules/`. Briefing template extended with "After fix, run final kit-wide grep proving 0 matches" sentinel.

### Outcome

Pending iter 8 verification — all four lessons capture iter-6-discovered process gaps that iter 7 implementations applied as remediation. L39/L40/L41/L42 promotion candidates for next QSR: L39 + L42 share kit-wide-scope-explicit discipline (likely promote together); L40 generalizes to any canonical-framework adoption (broad applicability); L41 generalizes to any aggregate-fleet-claim assertion (broad applicability). All four lessons recur across multiple loops (not just LENS-DCS standardization) and warrant promotion to permanent rules under `.claude/rules/` once iter 8 confirms the iter-7 mechanisms hold.

## Iter 10 — 2026-05-08

**Phase**: cross-phase (multi-model dispatcher orchestration + kit-wide sweep discipline + claim-vs-disk-state drift)
**Source**: iter 8 multi-model verification round 4 (L43); iter 9 D9-NEW-1 finding (L44); iter 8 D8-NEW-1 + iter 9 D9-NEW-3 (L45)

### Lesson

**L43 — PowerShell `Start-Job` over bash `& wait` for held-resource dispatchers.** Iter 8 multi-model verification round 4 used the bash `& wait` pattern to dispatch parallel multi-model subprocess invocations. The dispatcher subprocesses detached and held resource locks for 225s before parent process exit; Claude Code couldn't free the synchronous wait. Iter 9 round 5 switched to PowerShell `Start-Job` / `Wait-Job` / `Receive-Job` / `Remove-Job` — jobs ran in parallel, parent waited, lock released cleanly, all outputs collected. Canonical pattern:

```powershell
$jobs = @()
$jobs += Start-Job -ScriptBlock { pwsh -NoProfile -File "<dispatcher>" -PromptFile "<brief>" -OutputDir "<out>" }
# ... add more jobs
Wait-Job -Job $jobs | Out-Null
$jobs | Receive-Job
$jobs | Remove-Job
```

Bash `& wait` is deprecated for any dispatcher pattern that holds locks, file handles, or named-pipe resources across the wait boundary. PowerShell `Start-Job` correctly serializes the parent-wait-child-detach handoff because PowerShell job objects own the subprocess lifecycle and explicitly release on `Remove-Job`.

**L44 — Kit-wide field-naming sweeps must cover BOTH declaration AND usage axes.** Iters 7-9 underscore-prefix sweeps targeted DECLARATION sites (`private readonly TYPE _name`) and verified 0 declarations remained kit-wide. Iter 9 convergence re-audit found ~10 residual `_field.X` references in CORRECT blocks across 4 files — same antipattern, different syntax form (USAGE site, not declaration site). Each iter's "kit-wide grep" verified declarations but didn't grep usages. Generalized discipline: kit-wide field-naming sweeps must grep BOTH:

- `private readonly \w+ _[a-z]\w*` (declaration form)
- `\b_[a-z]\w+\.` (usage form, member access)
- `^\s*_[a-z]\w+\s*=` (assignment form, less common but covers fields outside constructors)

Verify ALL THREE patterns return 0 outside intentional WRONG blocks. **L42 is recursive across these axes — sweeps converge only when ALL axes are clean.** A "0 declarations" verification is insufficient proof of completion when usage-site references remain.

**L45 — Claim-vs-disk-state internal-reference drift is the same hallucination class as fleet-claim drift.** `CLAUDE.md` root § Gate skills declares 4 LENS gate skills as "REQUIRED — installed in P0". Iters 1-9 verified 3 (lens-aspnet-structure, lens-standards-audit, lens-multi-model-review eventually). lens-pipeline-audit was claimed installed but missing for 7 iters until iter 8 audit caught it. lens-telemetry was claimed installed but missing for 9 iters until iter 9 convergence re-audit caught it. Both are the same defect class: **claim-vs-disk-state drift in internal references** — the kit confidently asserts a state that doesn't match the filesystem.

This is structurally identical to L41 (fleet claims need multi-model verification) but for INTERNAL claims rather than EXTERNAL fleet claims. CLAUDE.md "already installed" / "REQUIRED" / "available" assertions need a Glob check at session start, not just at audit time. Discipline applies to:

- Plugin installs (`.claude/skills/<name>/SKILL.md` paths)
- Hook registrations (`settings.json` references vs hook files on disk)
- Cross-references (`see X.md` patterns where X.md must exist)
- Reference repos (`references/<name>/` paths)

A session-start audit script that mechanically Globs every CLAUDE.md "installed" / "available" / "REQUIRED" claim against actual disk state would have caught both lens-pipeline-audit (7 iter latency) and lens-telemetry (9 iter latency) at session 1, not session 8/9. Same hallucination class as L41; same remediation pattern (mechanical verification at claim-emission time, not just audit time).

### Mechanism applied

- **L43**: iter 9 multi-model dispatcher (round 5) used PowerShell `Start-Job`/`Wait-Job`/`Receive-Job`/`Remove-Job` pattern; dispatch succeeded cleanly with no orphan-subprocess lock retention. Bash `& wait` flagged as deprecated for held-resource dispatchers in any future skill body.
- **L44**: iter 10 added USAGE-site sweep across 4 files that retained `_field.X` references in CORRECT blocks; final grep verification on all 3 patterns (declaration / usage / assignment) showed 0 matches kit-wide outside intentional WRONG-block antipattern demonstrations. Implementer briefing template extended with "verify ALL three field-axis patterns return 0" sentinel.
- **L45**: iter 10 installed lens-telemetry via "just copy" pattern (per iter 1 corollary); L45 lesson captured in this entry. Future iters should run a session-start Glob audit before assuming installation state. Candidate hook: PreToolUse session-start audit script (`Verify-CLAUDEmdInstallationClaims.ps1`) that Globs every "installed" / "REQUIRED" claim path and fails fast on missing references — promotion target after iter 11 confirms the lesson holds.

### Outcome

Pending iter 11 verification — all three lessons capture iter-8/9-discovered process gaps that iter 10 implementations applied as remediation. L43/L44/L45 promotion candidates for next QSR: L43 generalizes to any held-resource parallel-dispatch pattern (broad applicability across orchestration skills); L44 + L42 share kit-wide-scope-explicit discipline across multiple axes (likely promote together as a unified "kit-wide sweep verification" rule); L45 + L41 share claim-vs-actual-state verification discipline (likely promote together as a unified "verification before claim emission" rule). All three lessons recur across multiple loops (not just LENS-DCS standardization) and warrant promotion to permanent rules under `.claude/rules/` once iter 11 confirms the iter-10 mechanisms hold.

## Iter 15 — 2026-05-08

**Phase**: cross-phase (LENS-CMS pattern cleanup, multi-model dispatch round 8)
**Source**: `.mad/reports/lens-cleanup/iter15-residual.md`; iter 15 multi-model dispatcher (3 briefs × 2 models)

### Lesson

Iter 15 multi-model round 8 found that iter 14's audit had reported "Result<T> removed" with 0 grep matches — but the type-deletion was incomplete. The Result<T> _API surface_ (`.IsSuccess`, `.Value`, `.IsFailure`, `.Error`) survived in test-assertion sites at `dotnet-testing.md:214-250` and `async-patterns.md:199-200`, even though the literal `Result<` type-token was gone. Iter 14's regex-only audit could not see this because the API-surface usage doesn't carry the type token.

### L46 — Token-only grep is insufficient for type-system patterns

When deleting a generic type from kit prescriptions (e.g., `Result<T>`), token-only grep (`Result<`) catches type DECLARATIONS but misses the API SURFACE that survives in usage code: `.IsSuccess`, `.Value`, `.IsFailure`, `.Error`, `.IfFailure(...)`, `.Bind(...)`. Iter 14 grepped `Result<` and reported 0 matches — but `dotnet-testing.md:214-250` and `async-patterns.md:199-200` still used `result.IsSuccess`/`result.Value` in test assertions. Pure regex audits cannot see this; only line-range reads (or API-surface-aware regex sets) catch the residue. GPT brief1 caught it by reading L180-255 of dotnet-testing.md; Opus brief1 with `Result<` regex passed.

**Mechanism applied**: Iter 16 grep extended to cover BOTH:
- Type token: `Result<`, `Option<`, etc.
- API surface: `\.IsSuccess`, `\.IsFailure`, `\.Value`, `\.Error`, `\.IfFailure\(`, `\.Bind\(`, etc.

**Outcome**: Iter 16 caught the Result<T> API surface residue across 2 files (3 fixture examples + 1 async test); rewrote each to typed-throw / concrete-return assertions per LENS-canonical handler shape. Pending iter 17 multi-model verification.

**Generalization**: Type-system pattern removals require API-surface grep, not just type-token grep. Companion to L42 (kit-wide scope) + L44 (declaration + usage axes). Multi-axis sweep discipline is now: type-token + API-surface + declaration + usage. Promotion candidate alongside L42/L44 for the unified "kit-wide sweep verification" rule (next QSR).

### Mechanism applied (iter 16 batch)

- **Items 1-2** (Result<T> API surface): rewrote `dotnet-testing.md:214-250` MSTest fixture examples to assert via concrete return shape and `Should().ThrowAsync<CaseNotFoundException>()` typed-exception pattern; rewrote `async-patterns.md:199-201` test to concrete-shape assertion.
- **Items 3-4** (`_field` underscore residue per L42/L44 kit-wide axes): replaced all `_repository`, `_service`, `_characterService`, `_cache`, `_list`, `_sut`, `_logger` references in `async-patterns.md` and `logging-security.md` with non-underscore forms (`this.repository`, `repository`, `logger`, etc.) per `naming-conventions.md:198`.
- **Items 5-9** (canonical-LENS / kit-policy framing headers): added kit-policy supplement marker on `csharp-coding-patterns.md`, `dotnet-quick-reference.md`, `quality-gates-dotnet.md`; added canonical-derived marker on `dotnet-security.md`; replaced `**Scope.**` line in `dotnet-error-handling.md` with the standard canonical marker for greppable consistency across the 24 `_dotnet/*.md` files.
- **Item 10** (CONSIDER, one-model signal per L41 conservative path): replaced literal `EventId = 1001` in `dotnet-logging.md:103` with `/* <consumer-defined> */ 0` placeholder + inline cross-reference to the L120 layer-range disclaimer.

### Outcome

Pending iter 17 verification — iter 16 closed the 10 HIGH items from iter 15's re-fix queue plus captured L46 as a process lesson. The final kit-wide grep (Result<T> + API surface + underscore-declaration + underscore-usage) should return 0 matches outside intentional WRONG / anti-pattern blocks. If iter 17 multi-model dispatch returns 0 NEW HIGH findings, stop-conditions (a) HIGH-confidence queue exhausted AND (d) re-audit shows 0 NEW HIGH are both met and the loop converges.
