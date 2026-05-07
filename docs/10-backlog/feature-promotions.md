# Feature promotions (rules-without-hooks)

Per `rules-without-hooks-audit.md` discipline (from `[A:rules-without-hooks-audit.md]` in the prior session): when a documented rule recurs as a correction ≥3 times, it's a promotion candidate — it should become a PreToolUse hook (or otherwise mechanically enforced) so future instances don't re-break it.

Per memory entry `feedback_documented_rules_need_hooks.md`: "Documented rules without hooks recur."

## Schema

```
| Rule path | Promotion target | # times observed | Source observations (wave/lane) | Confidence | Blocking factors |
```

## Entries

| Rule path | Promotion target | # times observed | Source observations | Confidence | Blocking |
|---|---|---|---|---|---|
| `.claude/rules/no-top-n-capping.md` | already a PreToolUse:Task hook (`detect-top-n-capping.js`) — but the audit found multiple subagent prompts still missing the sentinel | hook exists; recurrence is in human-authored prompts that bypass the hook by being authored in a session-tool that doesn't run hooks | wave-001 across all lanes — every lane subagent prompt had to include the sentinel verbatim per CLAUDE.md | HIGH | extend hook to detect prompts authored in `.mad/scratch/`, not just Task spawns |
| `.claude/rules/no-silent-deferrals.md` | PostToolUse hook (`content-scan-deferrals.js`) exists; but kept being violated in iter-41 collab-engine session | hook exists but the override `--force-raw` and self-trigger exemptions can mask hits | wave-001 lane-d (canonical-e v-next-release deferral list enumerated; some were sanctioned, others were silent) | HIGH | hook needs stricter exemption-list and clearer exempt-paths doc |
| `.claude/rules/canonical-skill-only.md` | PreToolUse:Write\|Edit hook (`validate-mad-pipeline.js`) exists | hook exists; iter-41 closed the Edit loophole | wave-001 lane-d (kit inventory confirmed hook coverage) | HIGH (hook live) | none; this one is closed |
| `.claude/rules/canonical-artifact-frontmatter.md` | PostToolUse hook (`enforce-skill-canonical-marker.js`) exists | hook exists | wave-001 lane-d kit inventory | HIGH (hook live) | none; this one is closed |
| `.claude/rules/scope-discipline.md` | NO hook today — recurring violation pattern: items marked scope-excluded without backlog entry | the iter-41 spiral was driven by silent scope-drift; user-mandated fix was to add backlog rows + commit-time enforcement | wave-001 lane-d + memory `feedback_create_skill_when_pitfalls_repeat.md` | HIGH | hook needed: PreToolUse:Bash on `git commit` — block if any new file under specs/ lacks a backlog row OR a `scope-discipline` rationale in the commit message |
| `.claude/rules/loop-cadence-discipline.md` | NO hook today — would catch `delaySeconds` in forbidden zone (280-1199s) | recurring drift: "let's check every 10 minutes" pattern lands in forbidden zone | wave-001 lane-zero implicit (cron cadence) + memory `feedback_skill_speed_expectations.md` | MEDIUM | hook needed: PreToolUse:ScheduleWakeup that rejects forbidden-zone delays; SDK extension required (no hook surface today) — backlog as feature, not rule |
| `.claude/rules/autonomous-loop-discipline.md` | NO hook today — orchestrator-discipline rule (no mechanical surface) | drift: orchestrator pauses for permission between iters | session 6ac2f083 (in CLAUDE.md) | MEDIUM | not hook-able; rule-only enforcement; codify in cron prompt template |
| `.claude/rules/loop-stop-language-discipline.md` | NO hook today — output-content rule | drift: "Final state" / "loop complete" language used mid-loop | session 6ac2f083 | MEDIUM | hook needed: PostToolUse on assistant-final-message that scans for forbidden phrasings; SDK has no such hook today |
| `.claude/rules/no-invented-constraints.md` | NO hook today | drift: invented "5M-token soft cap" that user never set | session 249a59a7 | MEDIUM | hook needed: scan summaries for budget/cap framing; not currently hook-able |
| `.claude/rules/orchestration.md` | PreToolUse hook (`enforce-orchestration.js`) exists | hook exists; blocks main-thread Read on code files | wave-001 lane-d kit inventory | HIGH (hook live) | none; this one is closed |
| `.claude/rules/verification-protocol.md` | NO hook today — "FETCH BEFORE CITE" + "ACTUAL BEFORE PRESENT" rules | drift: claimed test results without running them; cited files without reading | memory `feedback_no_speculation.md` | MEDIUM | hook concept: scan assistant message for "tests pass" / "build succeeds" / "as noted in `<file>`" without preceding Bash dotnet test / Read of `<file>` in prior turns; not currently hook-able |
| `.claude/rules/dangerous-operations-policy.md` | partial PreToolUse hooks (`pre-bash-validate.js` blocks some destructive git ops) | recurring drift: `az` / `gh` destructive ops not always gated | session 6ac2f083 + multiple LENS deploy sessions | HIGH | extend `pre-bash-validate.js` to also block `az group delete`, `az resource delete`, `gh repo delete` without explicit consent |

## Top-5 from prior session (per `[A:rules-without-hooks-audit.md]`)

> _Per session 6ac2f083 + 249a59a7 + collab-engine iter-1-41 retro_

1. **`scope-discipline.md`** — 12+ recurrence; HIGH promotion priority; commit-time hook needed
2. **`no-silent-deferrals.md`** — 8+ recurrence; HIGH promotion priority; existing hook needs exemption-list tightening
3. **`loop-stop-language-discipline.md`** — 6+ recurrence (mostly mid-loop); MEDIUM; SDK gap (no assistant-message hook surface)
4. **`no-invented-constraints.md`** — 4+ recurrence; MEDIUM; SDK gap
5. **`verification-protocol.md` ACTUAL BEFORE PRESENT** — recurring across LENS deploy sessions; HIGH-MEDIUM; tooling gap (would need cross-message-history scan)

## Wave-2 / Lane D update

Per Lane D wave-1 finding "5 anti-pattern hooks are LOAD-BEARING" — these promotion candidates extend that list. The five top candidates above represent the rules most likely to recur if the engine is rebuilt without re-applying. **F-22..F-X engine telemetry tests should explicitly exercise each rule's triggering condition** to catch regression.

## Wave-2 / Lane C update — Copilot CLI design review (gpt-5.5 single-model, Opus timed out)

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md`. 8 NEW F-NNN candidates promoted to feature catalog (HIGH confidence, single-model only — Opus timeout means cross-model agreement table is empty; promote with manual gate per `lens-multi-model-review-pattern.md` fallback section).

| F-NNN | Title | Target milestone | Rationale (wave-1 source) | Confidence |
|---|---|---|---|---|
| F-127 | foundation-governance-kernel | M0 (was M2) | Critical: M0/M1 ship executable surfaces before M2 governance reachable; ungovernable-by-construction. | HIGH (single-model) |
| F-128 | per-agent-identity-bootstrap | M0 (was implicit M2) | Critical: identity chain needed from first turn; audit/cost/OAuth/permissions/replay all depend. CE FR-IDENTITY-001 + Agent365 + CP. | HIGH (single-model) |
| F-129 | oauth-refresh-singleflight-lock | M2 | Critical: matches OpenClaw F3 (refresh-token reuse can revoke entire provider account). | HIGH (single-model) |
| F-130 | tool-invocation-proof-gate | M2 | Critical: matches Devin lessons (#1 failure mode = hallucinated tool invocation); existing F-047/F-058..061 lack pre-execution proof. | HIGH (single-model) |
| F-131 | fanout-budget-governor | M2 | Critical: matches Anthropic multi-agent ~10x token cost; M10 ships council too late if K-origin agent-team patterns appear in foundation loops. | HIGH (single-model) |
| F-132 | parent-child-supervision-locks | M2/M3 | Major: matches OpenClaw F4 (detached background processes); needs OS-level flock/LockFileEx + heartbeat lease + orphan reaper. | HIGH (single-model) |
| F-133 | real-agent-filesystem-isolation | M2 | Major: matches Lane C L1 (per-agent isolation must be filesystem-real, not synthetic). | HIGH (single-model) |
| F-134 | skill-supply-chain-attestation | M7 with M0 gate | Major: 70 inherited skills have no manifest lockfile / content hash / signature gate today. | HIGH (single-model) |

## Wave-3 / Lane B update — Copilot CLI design review retry (Opus succeeded, cross-model populated)

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md` § Wave-3 retry resolution + § Cross-model agreement table.

Cross-model verdict on each wave-2 F-NNN promotion + 3 NEW F-NNN candidates surfaced by Opus only:

| F-NNN | Title | Wave-2 conf | Wave-3 cross-model verdict | Notes |
|---|---|---|---|---|
| F-127 | foundation-governance-kernel | HIGH (gpt-5.5) | HARD BLOCK (Opus C1 + gpt-5.5 C1 both Critical) | Both models flag governance retrofit as a foundation-order blocker. M0/M1 must not ship without F-014/F-015/F-019/F-022/F-088 forward-moved. |
| F-128 | per-agent-identity-bootstrap | HIGH (gpt-5.5) | HARD BLOCK (Opus M4 + gpt-5.5 C2; severity escalates to Critical) | Both flag; gpt-5.5 escalates to Critical. CE FR-IDENTITY-001 + OpenClaw F1 cost-attribution drift = root convergence. |
| F-129 | oauth-refresh-singleflight-lock | HIGH (gpt-5.5) | HARD BLOCK (Opus M3 + gpt-5.5 C3; severity escalates to Critical) | Both flag OpenClaw F3 root cause. Spec F-079 token refresh must require single-flight per identity. |
| F-130 | tool-invocation-proof-gate | HIGH (gpt-5.5) | HARD BLOCK (Opus C3 + gpt-5.5 C4 both Critical) | Both models flag Devin #1 failure mode. F-022/F-058/F-125 are rate/cardinality, not schema-validation. New error code `ERR_TOOL_HALLUCINATED`. |
| F-131 | fanout-budget-governor | HIGH (gpt-5.5) | HARD BLOCK (Opus M2 + gpt-5.5 C5; severity escalates to Critical) | Both flag Anthropic 10x token cost; both place at M2. Tie F-126 context-budget to F-018 cost ledger. |
| F-132 | parent-child-supervision-locks | HIGH (gpt-5.5) | MUST-FIX (Opus M5 + gpt-5.5 M-E both Major) | Both flag OpenClaw F4. OS-level flock/LockFileEx + heartbeat lease. |
| F-133 | real-agent-filesystem-isolation | HIGH (gpt-5.5) | **MEDIUM** (gpt-5.5 only — Opus folds into supervision-lock C2/M5) | Demoted to MEDIUM cross-model. Wave-4 third-model corroboration recommended. |
| F-134 | skill-supply-chain-attestation | HIGH (gpt-5.5) | HARD BLOCK (Opus C4 + gpt-5.5 M-G; severity escalates to Critical) | Both flag; Opus escalates to Critical. M0 gate (NOT M7-only). MSEC bootcamp parallel + 70 inherited skills. |
| **F-135** | mcp-oauth-2.1-tls-pin | n/a (new) | MEDIUM (Opus G5 + gpt-5.5 G8 — both flag gap; F-NNN shape divergent) | New cross-model gap. Either fold into F-122 hardening or new F-NNN. |
| **F-136** | agent-manifest-export | n/a (new) | LOW (Opus G7 only) | Opus-only; promote at LOW pending wave-4 corroboration. |
| **F-137** | supervisor-status-stream | n/a (new) | LOW (Opus G9 only) | Opus-only; F-024 heartbeat doesn't surface degraded states to UX. |

## Wave-9 / Lane D update — Microsoft 2026 frontier deep-dive (25 NEW F-D-127..F-D-151 candidates)

**Source-file substitution note (anomaly):** the wave-9 lane-d brief named source files `agent-365-typescript-impl.md`, `workiq-a2a-versioning.md`, `foundry-deployment-patterns.md`, `m365-declarative-vs-custom-engine.md`, `workiq-typescript-engine-patterns.md` and a `wave-008/lane-d-summary.md`. None of those filenames exist in the repo at intake time. Wave-008 has no Lane D (only Lane A: F-014 GREEN; Lane B: F-015 GREEN). The substantive research surface that matches the brief's topic list is the wave-4 Lane C output under `docs/04-research/microsoft-2026/` — `agent-365-sdk-typescript.md`, `workiq-a2a-impl-patterns.md`, `foundry-agent-service.md`, `m365-copilot-extensibility.md`, `agent-framework-typescript-bridge.md`. Lane D wave-9 processed THOSE files into the backlog and surfaces the brief-vs-repo divergence below for adjudication. **Loop-improvement candidate:** brief-generation should validate referenced source-file paths against `git ls-files` before issuing.

**Schema for entries below:** `F-D-NNN | slug | one-sentence description | source wave-finding | confidence | proposed milestone | re-open trigger`

**Namespace anomaly:** F-D-NNN today is the M19 deferred catalog (F-D-001..F-D-018). Allocating F-D-127..F-D-151 jumps past F-D-019. Per wave-9 lane-d brief, IDs are preserved literally. Lane D recommends either (a) renumber to F-D-019..F-D-043 in a follow-up consolidation wave, or (b) treat F-D-127..F-D-151 as the "frontier-deferred" sub-namespace mirroring the F-127+ frontier-promotion range. Decision tracked as D-30 (below).

| F-D-NNN | Slug | Description | Source | Confidence | Milestone | Re-open trigger |
|---|---|---|---|---|---|---|
| F-D-127 | agent365-ts-otel-package | `@microsoft/agents-a365-observability` provides drop-in OTel GenAI distro for TS engine — adopt instead of hand-rolling Geneva exporter. | `agent-365-sdk-typescript.md` (wave-4 lane-c finding 1) | HIGH | M16 (telemetry) | Geneva-compatible exporter validation passes |
| F-D-128 | agent365-ts-notification-package | `@microsoft/agents-a365-notifications` for outbound Teams/Outlook surfaces — could replace F-D-008/F-D-009 hand-rolled adapters. | `agent-365-sdk-typescript.md` (wave-4 lane-c finding 2) | HIGH | M14 (productivity) | F-D-008 design phase begins |
| F-D-129 | agent365-ts-runtime-utils | `@microsoft/agents-a365-runtime` provides agent-id binding + audit-evidence helpers for TS — informs F-002/F-007 implementation choice. | `agent-365-sdk-typescript.md` (wave-4 lane-c finding 3) | HIGH | M0 (bootstrap) | F-002 implementation phase |
| F-D-130 | agent365-claude-extension | `@microsoft/agents-a365-claude` provides Claude SDK wrapper for Agent 365 contracts — engine could inherit instead of building IBackendProvider Claude lane. | `agent-365-sdk-typescript.md` (wave-4 lane-c finding 4) | MEDIUM | M1 (backend providers) | D-1 closure favors thin-adapter shape |
| F-D-131 | a2a-js-sdk-default | `@a2a-js/sdk` is the official A2A protocol SDK for JS/TS — adopt as default A2A transport instead of hand-rolling per-RG-3. | `workiq-a2a-impl-patterns.md` (wave-4 lane-c finding 1) | HIGH | M9 (A2A) | RG-3 closure / F-122 implementation |
| F-D-132 | a2a-http-json-default-binding | A2A v1.0 default binding is HTTP+JSON not JSON-RPC — engine must declare default explicitly via `MapA2AHttpJson`/`MapA2AJsonRpc`. | `workiq-a2a-impl-patterns.md` (wave-4 lane-c finding 2) | HIGH | M9 (A2A) | F-122 design phase (D-30 sets default) |
| F-D-133 | a2a-itaskmanager-removed | `ITaskManager` was removed in A2A v1.0 migration — engine spec must NOT cite that contract. | `workiq-a2a-impl-patterns.md` (wave-4 lane-c finding 3) | HIGH | M9 (A2A) | F-122 spec authoring |
| F-D-134 | teams-a2a-plugin | `@microsoft/teams.a2a` is the Teams SDK A2A adapter (separate from `@a2a-js/sdk`) — informs F-D-008 Teams adapter design. | `workiq-a2a-impl-patterns.md` (wave-4 lane-c finding 4) | HIGH | M14 (productivity) | F-D-008 re-open or Teams adapter design |
| F-D-135 | foundry-agent-byo-cosmos-storage | Foundry Agent Service supports BYO Cosmos thread storage — informs M11 memory plane design (D-19). | `foundry-agent-service.md` (wave-1 lane-b reinforced wave-4) | HIGH | M11 (memory) | D-19 closure / F-185 design |
| F-D-136 | foundry-hybrid-ts-python-deploy | Foundry-hosted-runtime is Python-only; TS engine must deploy as hybrid (TS-control + Python-Foundry-worker IPC). | `foundry-agent-service.md` § Hybrid pattern | HIGH | M11 / M15 (packaging) | D-12 packaging closure / Foundry GA |
| F-D-137 | foundry-standard-vs-classic-agent | Foundry has two agent shapes (standard vs classic) with different lifecycles — engine adapter must declare which it targets. | `foundry-agent-service.md` § standard-agent-setup | MEDIUM | M11 | F-185 ledger expansion |
| F-D-138 | foundry-may-2025-ga-pattern | Foundry agents went GA May 2025 — production stability good for v1; PREVIEW risk in RG-6 partially closed. | `foundry-agent-service.md` § What's new | HIGH | M11 | RG-6 re-evaluation |
| F-D-139 | m365-declarative-vs-custom-engine | M365 Copilot extensibility distinguishes declarative agents (manifest-only) vs custom-engine agents (full code). Engine targets custom-engine path. | `m365-copilot-extensibility.md` § Declarative vs custom | HIGH | M9 (M365 adapter) | M9 design wave |
| F-D-140 | m365-mcp-apps-ui-widgets | M365 Copilot now supports declarative-agent UI widgets via MCP Apps + OpenAI Apps SDK — informs F-NNN UI widget surface. | `m365-copilot-extensibility.md` § UI widgets | MEDIUM | M9 / M13 | M9 design phase |
| F-D-141 | m365-agent-builder-low-code | Agent Builder is M365's low-code path; engine MUST NOT compete on low-code, must position as code-first. | `m365-copilot-extensibility.md` § Agent Builder | HIGH | M9 | M9 design wave |
| F-D-142 | m365-january-2026-extensibility-baseline | What's-new Jan 13 2026 release notes are the baseline — re-fetch quarterly per RG-11. | `m365-copilot-extensibility.md` § release notes | MEDIUM | M9 | quarterly RG-11 cron |
| F-D-143 | af-typescript-no-native-port | Microsoft Agent Framework has NO native TypeScript port as of May 2026 — engine must use bridge or hand-roll. | `agent-framework-typescript-bridge.md` (wave-4 lane-c finding 1) | HIGH | M0 / M2 | RG-2 closure / D-9 closure |
| F-D-144 | af-bridge-grpc-vs-reimpl-vs-skip | Three options for AF integration: (a) gRPC bridge to .NET/Python, (b) reimplement workflows in TS, (c) skip and hand-roll. | `agent-framework-typescript-bridge.md` § Bridge options | HIGH | M0 / M2 | D-9 council-review |
| F-D-145 | af-workflow-primitives-list | AF workflow primitives (`SequentialBuilder`, `WorkflowBuilder`, `GroupChatBuilder`, `MagenticBuilder`, `AddFanOutEdge`, `AddFanInBarrierEdge`) are the ones to potentially port. | `agent-framework-typescript-bridge.md` § primitives | HIGH | M2 (governance) | If D-9 picks reimpl path |
| F-D-146 | a2a-versioning-v1-migration-cliffs | A2A v1.0 migration introduces breaking changes (default binding, `MapA2A*` separation, `ITaskManager` removed) — engine spec must declare v1.0 target. | `workiq-a2a-impl-patterns.md` § Migration cliffs | HIGH | M9 | F-122 spec authoring |
| F-D-147 | claude-on-agent365-sanctioned-path | Anthropic-Claude-on-Agent-365 has a sanctioned path via `@microsoft/agents-a365-claude` — informs CE FR-IDENTITY adoption. | `agent-365-sdk-typescript.md` § Claude integration | HIGH | M0 / M1 | M1 backend provider design |
| F-D-148 | protocol-first-vs-sdk-first-philosophy | Microsoft's 2026 stack favors protocol-first (A2A, MCP, Activity, OTel GenAI) over SDK-first — engine should mirror that philosophy. | Cross-cutting (5 wave-4 files) | HIGH | M0 | M0 wave council-review |
| F-D-149 | foundry-deployment-pattern-hybrid-canonical | Hybrid TS-Python deployment is the canonical pattern when targeting Foundry hosted runtime — codify as F-NNN. | `foundry-agent-service.md` § Hybrid pattern | HIGH | M15 | M15 packaging wave |
| F-D-150 | workiq-ts-engine-patterns-internal-context | WorkIQ "internal context" (Teams chats / emails) is a SEPARATE concern from A2A protocol — engine must not conflate. | `workiq-internal-context.md` (related; not in lane-d brief but referenced) | HIGH | M9 / M14 | F-188 / F-189 design phase |
| F-D-151 | microsoft-stack-typescript-availability-baseline | TS availability is uneven across Microsoft 2026 stack: Agent 365 SDK = full TS parity; A2A = `@a2a-js/sdk`; AF = no TS; Foundry = Python-only runtime. Engine must adapt accordingly. | Cross-cutting synthesis (5 wave-4 files) | HIGH | M0 | M0 wave architectural review |

**Confidence summary:** 21 HIGH + 4 MEDIUM. None LOW.
