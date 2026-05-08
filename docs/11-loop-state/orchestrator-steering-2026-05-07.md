# Orchestrator steering — 2026-05-07

**Source:** audit-driven session 967a44fb (cwd=`C:/Users/tonym/Repos/MAD - Clean`) running parallel to the wave-execution session (`64bf21c6`) that has been picking from `current-wave.md` + `implementation-todo.md` and committing through wave-15/16/17.

**Audit synthesis:** `C:/Users/tonym/Repos/MAD - Clean/.mad/reports/mad-council-claw-audit-2026-05-07.md`

This file is the **out-of-band steering channel**: the user works in session 967a44fb and authors backlog updates here; the executing session 64bf21c6 reads this file each iter to learn priorities and unlocks that landed off-wave.

## HARD BLOCK directive — F-205 frontmatter status field

- **Severity:** HARD BLOCK (both-agree from cross-model review; Opus MUST-FIX correctness, GPT BLOCKING correctness, GPT REJECT verdict on artifact 4)
- **File:** `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md:4`
- **Issue:** top-level frontmatter `status: green` contradicts the embedded `red-green-rule: GREEN if ALL 8 acceptance items pass`. The status-history entry at line 18 (wave-019 / lane-c, by orchestrator session 64bf21c6, commit `e57351e`) explicitly acknowledges that only 1 of 8 acceptance items (item (a) — `.claude/rules/`) is even partially met by Batch 1; items (b)-(h) are explicitly enumerated as "NOT YET MET" in that same entry. The frontmatter `status: green` is therefore inconsistent with the ledger's own self-reported state.
- **Impact:** automated tooling (`Check-LoopStopConditions.ps1`, roadmap counters, `validate-mad-pipeline.js`, any future M0 rollup) WILL misread the gate state and treat F-205 as fully satisfied. F-205 is the hard `depends-on` for F-206..F-210 AND the gating prerequisite for the M19 reopen council-review verdict — a false-GREEN reading propagates downstream incorrectly.
- **Requested fix:** change `status: green` → `status: red`. Add a new frontmatter field `batch-1-status: green` to capture incremental progress without misleading the top-level field. The `status-history` array retains the existing wave-019/lane-c entry verbatim — no rewriting of history.
- **Owner:** wave-019 / lane-c session `64bf21c6` (per `single-owner-accountability.md` — the amendment owner does the revert; the orchestrator session 967a44fb does NOT directly edit the concurrent session's amendment).
- **Discovered:** 2026-05-07T22:30Z via cross-model review dispatch (Copilot CLI multi-model review; Claude Opus 4.7 + GPT-5.5 in parallel). Agreement table at `C:/Users/tonym/Repos/MAD - Clean/.mad/reports/copilot-review-2026-05-07/agreement-table.md`, finding F3 (line 29).

**Why this section is placed at the top:** HARD BLOCK is the highest-priority signal in this steering file. Readers (concurrent session 64bf21c6 picking up at iter start) should see this BEFORE backlog-update tables or pickup-order recommendations. Per `loop-stop-language-discipline.md`, the loop continues — but the F-205 frontmatter must be corrected on the next batch transition (Batch 2 landing) so the loop doesn't propagate a false-GREEN reading to F-206..F-210 or M19 reopen evaluation.

## Runtime-validation gap (2026-05-07T23:50Z; honest accounting)

Session 967a44fb authored 4 batches + ran a multi-model cross-model review (real Copilot CLI dispatch — Opus 4.7 + GPT-5.5; 8m10s; 35 findings; agreement table at `MAD - Clean/.mad/reports/copilot-review-2026-05-07/agreement-table.md`). 14 MUST-FIX findings remediated. 1 HARD BLOCK (F3) flagged in the directive section above.

But: of the surfaces authored, only ~5 have real E2E runtime evidence. The other ~12 are structural / file-existence proofs only. Concurrent session 64bf21c6 (and any successor session picking up F-205 batches 2-N) should know which surfaces have NOT been runtime-validated:

### Validated end-to-end (real invocation, real output)

- `Invoke-CopilotMultiModel.ps1` → real Opus + GPT dispatch returned real findings (8m10s)
- `Bootstrap-CouncilClawKit.ps1 -DryRun` → parser + planner exercised (479 file plan, 32 LENS-strip, 1 path-rewrite)
- `pnpm test` in mad-council-claw → 323/323 PASS (38 vitest files)
- Pre-commit hook chain (`validate-quality-gates.js`, `content-scan-deferrals.js`, `validate-mad-pipeline.js`) → fired, blocked correctly, passed correctly
- Hook test suite (sampled) → PASS

### NOT validated (asserted-by-frontmatter or structural-only)

- **3 new MAD-Clean kit skills** (`skill-sanitize`, `mcp-permission-validate`, `copilot-cli-bridge`) — registered in skill registry per system-reminder, BUT never invoked with synthetic input + output verified. Skill bodies could have semantic bugs the cross-model review didn't catch.
- **Council skills** (`/council-open`, `/council-post`, `/council-review`, `/council-resolve`, `/council-retro`, etc.) — not invoked end-to-end by session 967a44fb. The cross-model dispatch went through `Invoke-CopilotMultiModel.ps1` directly, not via a `/council-*` skill chain.
- **MAD pipeline skills** (`/mad-spec`, `/mad-plan`, `/mad-tasks`, `/mad-implement`, `/mad-validate`) — not invoked.
- **Chained skill calls** — `/mad-spec → /testplan` auto-fire NOT verified. CLAUDE.md claims it auto-fires; kit's own iter1-41 collab-engine antipattern doc reports it failed across 41 iters. Whether the bug is fixed today is UNVERIFIED in this session.
- **Bootstrap script NON-DryRun** — never run live. 464 file copies + path rewrites + CLAUDE.md generation are dry-run-planned only. Concurrent session is doing staged batches; live full-bootstrap deferred.
- **Generated CLAUDE.md semantic quality** — multi-model review read the SCRIPT, not the OUTPUT. Whether the generated council-claw CLAUDE.md actually makes sense as a working orchestrator contract is UNVERIFIED.
- **Reopen-request package consumer** — `m19-reopen-request` artifact-class has typed schema; no skill yet PARSES it. Documentation-only until `/council-review` (or a new schema-validator) reads it.
- **F-205 acceptance test full assertion path** — concurrent session's `tests/node/F-205-kit-bootstrap.test.ts` runs the skip-when-not-landed branch (most items NOT met). The full post-bootstrap assertion path has not executed.
- **F-206..F-210 m-relay-main lift ledgers** — contractual only. No implementation, no test, no integration. Soft-blocked on F-D-008 reopen verdict; reopen verdict gates on `/council-review` skill availability post-F-205.
- **UI / UX** — does not exist. M5 desktop shell hasn't started; Electron not installed; no UI code; no Playwright wired despite F-093 planning browser tests. Cannot validate UX.
- **Automations** — none built. Horizon/"Prepare" equivalent not authored. Cannot validate.
- **Bootstrap script smoke tests** (hook fires, `/council-list`, `/mad-spec` dry-run) — documented in script body but only execute in NON-DryRun mode; not run.
- **Audit synthesis as downstream input** — read by session 967a44fb + dispatch subagent only. No skill consumes it as a typed input contract.

### Disposition (per user direction 2026-05-07T23:50Z)

User explicitly chose: **acknowledge the gap; do not try to close it in this session.** The concurrent session's staged-batches plan for F-205 will land kit components incrementally; runtime testing per-batch is the executing session's responsibility (concurrent session 64bf21c6 has been doing this — recent commits show test-first RED→GREEN cadence and commit-message gate-results).

When concurrent session lands a batch that includes a previously-untested skill (e.g. F-205 Batch 2 likely covers `/council-*` + `/mad-*` skills), the per-batch test extension SHOULD include at least one synthetic invocation of each skill (not just file existence). Recommendation, not directive.

### Cross-reference

Ownership of the 14 fixes already remediated (commits `1ca69e47` MAD-Clean main; `cd88fa9` mad-council-claw main; `eca205e0` MAD-Clean main audit trail). HARD BLOCK F3 still pending concurrent session revert.

## What's new in the backlog (2026-05-07 silent-deferral surfacing)

Authored across 4 user-scoped batches; all RED + uncommitted-or-recently-committed:

| ID | Slug | Milestone | Priority | Soft-blocks | Why it surfaced |
|---|---|---|---|---|---|
| **F-205** | kit-bootstrap | M0 | **HIGH** | F-206..F-210; M19 reopen verdict | Mechanical "copy MAD kit primitives into mad-council-claw" was assumed by foundational plan ("engine inherits, doesn't fork" — `mad-kit-inventory.md:881`) but never captured as F-NNN. Surfaced per `no-silent-deferrals.md`. |
| F-206 | ws-relay-manager | M9 | high | — (depends-on F-205, F-D-008) | m-relay-main lift (relay.ts:84-235). |
| F-207 | bot-connector-rest-jwt | M9 | high | — | m-relay-main lift (bot.ts:33-321). |
| F-208 | msi-fic-token-mint | M9 | high | — | m-relay-main lift (bot.ts:125-175). |
| F-209 | adaptive-card-permission-lifecycle | M9 | high | — | m-relay-main lift (relay.ts:73-74,95-101,339-418,554-566 + cards.ts:19-93). |
| F-210 | conversation-ref-atomic-persist | M9 | high | — | m-relay-main lift (relay.ts:262-331). |
| F-D-018 | activity-protocol-teams-outlook | M19 | (deferred — REOPEN-PENDING) | — | RESERVED ID, ledger authored from scratch this batch. |

Reopen-request package: `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`. Per `M19-deferred/README.md:51-57`, `status: deferred` stays on F-D-008/F-D-010/F-D-018 until `/council-review` verdict at HIGH ≥80%. Verdict gates on `/council-review` skill availability post-F-205 execution.

## Recommended next-iter pickup order

For the next wave's lane allocation:

1. **F-205 first.** Highest unblock: it enables `/council-review` (which gates the M19 reopen verdict) AND it's the hard `depends-on` for F-206..F-210 transition. Ledger has full implementation directive at `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` § "Implementation directive".
2. **Test authoring for F-205:** `tests/node/F-205-kit-bootstrap.test.ts` per ledger red-green-rule. Should mechanically verify the 8 acceptance items (a)-(h).
3. **/council-review on M19 reopen package** once /council-review is available. If HIGH ≥80%, transitions F-D-008/F-D-010/F-D-018 status from `deferred` → RED, target milestone selected (M9 expansion vs new M-Teams).
4. **F-206..F-210 transitions** unblock once F-205 GREEN AND F-D-008 reopen verdict is HIGH.

### Update — 2026-05-07T22:30Z (post-original-authoring)

Concurrent session 64bf21c6 picked up F-205 in **wave-019 / lane-c** and **re-scoped it as a 4-batch incremental landing**. Commit `e57351e` flipped F-205 RED → GREEN at the **Batch 1 (kit-generic LOAD-BEARING rules)** level — 26 rules landed in `.claude/rules/` plus a Batch-1 acceptance test `tests/node/F-205-kit-bootstrap.test.ts` (323/323 vitest PASS at HEAD).

The 8-item acceptance contract is preserved at FULL-LEDGER granularity per `F-205-kit-bootstrap.md:286`: *"When all 4 batches land + the test extends accordingly, the ledger's red-green-rule (ALL 8 items pass) will be satisfied at FULL-LEDGER granularity. Until then, batch-N GREEN is per-batch GREEN documented in status-history."*

**Implication for `Bootstrap-CouncilClawKit.ps1`:** the script's `-Tier critical` mode does the entire CRITICAL set in one shot (`.claude/{rules,hooks,skills,agents,scripts,settings.json}` + `.mad/{templates,scripts,docs}` + `CLAUDE.md` + 3 m-main skills). That collides with the staged-batches plan now in flight. **The script is now a FALLBACK** — invoke only if the staged approach stalls (≥3 iters with no progress on F-205 batches OR concurrent session signals it can't proceed). Default path: let concurrent session land Batches 2-N incrementally with their own test extensions per batch.

Updated next-iter pickup order:

1. **F-205 Batch 2** (concurrent session's call to define scope — likely `.claude/skills/` core council + MAD primitives, OR `.claude/hooks/`).
2. **F-205 test extension** at each per-batch GREEN flip — concurrent session's pattern is to extend the test file with new assertions at each Batch N→GREEN transition.
3. **Once F-205 Batch covering `/council-review` lands** (probably Batch 2 or 3, since council skills are CRITICAL set): the M19 reopen-request package can run `/council-review` to ratify the F-D-008/F-D-010/F-D-018 transitions.
4. **F-206..F-210 implementations** unblock once F-205 reaches FULL-LEDGER GREEN AND F-D-008 reopen verdict is HIGH.

If concurrent session stalls on F-205 (no batch progress for ≥3 iters), the orchestrator session 967a44fb may decide to invoke `Bootstrap-CouncilClawKit.ps1 -Tier critical` as a fallback consolidation. That decision is owner's call (per `single-owner-accountability.md`); the script is staged and validated (dry-run 464 file plan, 32 LENS-prefix filter, 1 path-rewrite).

## How to execute F-205 (concrete invocation)

```powershell
# Dry-run first (read-only; produces a plan):
pwsh -NoProfile -File "C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/Bootstrap-CouncilClawKit.ps1" `
  -TargetRepo "C:/Users/tonym/Repos/mad-council-claw" `
  -Tier critical `
  -DryRun

# Review dry-run output. Then execute:
pwsh -NoProfile -File "C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/Bootstrap-CouncilClawKit.ps1" `
  -TargetRepo "C:/Users/tonym/Repos/mad-council-claw" `
  -Tier critical
```

**Pre-execution checklist** (per F-205 § Implementation directive):
- [ ] No uncommitted drift in `.claude/`, `.mad/`, root `CLAUDE.md` of mad-council-claw (the script writes to these paths)
- [ ] `pwsh` ≥7 available
- [ ] Dry-run output reviewed
- [ ] User notified

**Known dry-run findings** (orchestrator validated 2026-05-07):
- 464 file copies planned
- 32 LENS-prefix files filtered (Ev2-*, Ado-*, Diagnose-LensDcs*, lens-*)
- 1 path-rewrite (KitSourceRoot → TargetRepo in settings.json)
- 1 missing source: `.claude/skills/loop` (Claude Code builtin; script may need patching to either skip or include the bundled path — minor follow-up).

## Three new skills now in MAD-Clean kit (will be copied by F-205 execution)

- `skill-sanitize` — scan user-supplied skill content (frontmatter, descriptions, instructions) for model-specific delimiter tokens and length-cap violations before runtime ingestion. Source: `m-main/common/skill-sanitization.ts`.
- `mcp-permission-validate` — validate MCP server registrations + URLs against allowlist, scheme rules, and threat-model policy before they enter settings.json or runtime ingestion. Source: `m-main/common/permission-servers.ts` + `mcp-url-validation.ts`.
- `copilot-cli-bridge` — canonical wrapper for cross-model dispatch via Copilot CLI; the entry point inheriting skills invoke when running `--copilot` mode (multi-model security/architectural review). Source: `m-main/src/services/copilot.ts` + `lens-multi-model-review-pattern.md`.

## What this file does NOT do

- Does NOT claim a wave for F-205 / F-206..F-210 / reopen-request execution. Wave-claim is the executing session's call.
- Does NOT bypass council-review verdict gate. Reopen package is request-only; verdict gates the actual transition.
- Does NOT pre-empt other lane work. The executing session may have other priorities; this file is a steering input, not a directive.

## Out-of-band steering convention going forward

- 967a44fb session updates this file when it adds new backlog items or wants to surface priorities.
- 64bf21c6 (and successor sessions) read this file at iter start.
- Each entry is dated; readers should consider entries older than 14 days stale unless the underlying ledger is still RED.
