---
artifact-class: design-review
review-type: copilot-cli-multi-model (complete — wave-3 retry succeeded)
date: 2026-05-07
wave: wave-002 / lane-c (initial dispatch) + wave-003 / lane-b (Opus retry)
inputs:
  - docs/04-research/frontier-2026/*.md (12 docs)
  - docs/04-research/microsoft-2026/*.md (11 docs)
  - docs/04-research/openclaw-clawpilot/*.md (6 docs)
  - docs/04-research/mad-kit-inventory.md
  - docs/04-research/canonical-e-inventory.md
  - docs/04-research/cross-source-disposition-matrix.md
  - docs/01-requirements/foundational-plan.md (True Synthesis)
models-dispatched:
  - gpt-5.5 — completed wave-2 ~33s
  - claude-opus-4.7 — TIMEOUT at 600s in wave-2; SUCCEEDED ~94s in wave-3 retry with TimeoutSeconds=1200
brief: .mad/scratch/wave-002-design-review-brief.md
dispatcher-output: .mad/scratch/wave-002-design-review-output/
opus-result: .mad/scratch/wave-002-design-review-output/opus-result.json
gpt-result:  .mad/scratch/wave-002-design-review-output/gpt-result.json
---

# Wave-001 foundation design review

## Review path taken

**Initial dispatch (wave-2 Lane C):** Dispatcher (`Invoke-CopilotMultiModel.ps1`) launched two parallel Copilot CLI calls (claude-opus-4.7 + gpt-5.5) at TimeoutSeconds=600. GPT-5.5 returned a complete structured review at ~T+33s (job exited 0; raw_output ~7.6KB; 36.7k input + 2.2k output tokens per Copilot meter). Opus did not return within 600s and was Stop-Job'd. No partial Opus artifact was written.

**Wave-3 retry (Lane B, this update):** Per Lane C's loop-improvement proposal, re-dispatched Opus only with TimeoutSeconds=1200 via Start-Job + `copilot --model claude-opus-4.7 --yolo -p`. Opus returned in **~94 seconds** (vs 600s timeout the first time) — well under the 600s default; the wave-2 timeout was likely a Copilot CLI / model warm-up transient, not a fundamental capacity issue. Output ~11KB; 63.7k input + 4.6k output (27.7k cached) tokens. Cross-model agreement table now populated.

**Both-flag-CRITICAL hard-block rule from `lens-multi-model-review-pattern.md` is now eligible.** Findings flagged Critical by BOTH models are HARD BLOCKs on M0/M1 freeze. Findings flagged Critical by only one model are SHOULD-FIX (single-model signal weaker per pattern doc).

This dispatch satisfies QG7's "at least one Copilot CLI design review per N waves" with the cross-model signal that QG7 expects.

## Cross-model agreement table

| Finding (canonical phrasing) | claude-opus-4.7 | gpt-5.5 | Decision |
|---|---|---|---|
| **F1 — M0/M1 ship executable surfaces before M2 governance reachable** (catalog: F-014..F-022 sit in M2 but F-009..F-013 in M1 calls SDKs first; Soul boundary in M11 also late) | Opus C1 (Critical) | gpt-5.5 C1 (Critical) | **HARD BLOCK** — both flag Critical. Move F-014/F-015/F-019/F-022/F-088 forward into M0; promote F-127 foundation-governance-kernel as M0 entry. |
| **F2 — `IBackendProvider` (F-009) over-normalizes Anthropic vs Copilot SDK event semantics** | Opus C2 (Critical) | gpt-5.5 M-A (Major) | **HARD BLOCK** (severity escalates to Critical via Opus) — split F-009 into IChat / IToolDispatch / IIdentity. Anthropic content_block_delta vs Copilot turn-based shapes diverge enough that one provider abstraction leaks. |
| **F3 — Hallucinated tool invocation has no pre-execution proof gate** (Devin #1 failure; F-022/F-058/F-125 are rate/cardinality, not schema-validation) | Opus C3 (Critical) | gpt-5.5 C4 (Critical) | **HARD BLOCK** — both flag Critical. Add F-130 tool-invocation-proof-gate (M2). Promote with HIGH cross-model confidence. |
| **F4 — Supply-chain risk on 70 inherited skills + 96 rules has no integrity check** (skill body content-hash gap) | Opus C4 (Critical) | gpt-5.5 M-G (Major) | **HARD BLOCK** (severity escalates to Critical via Opus) — promote F-134 skill-supply-chain-attestation as M0 gate (NOT M7-only). |
| **F5 — Per-agent identity chain is not foundation-order blocking** (CE FR-IDENTITY-001 must precede first backend call) | Opus M4 (Major) | gpt-5.5 C2 (Critical) | **HARD BLOCK** (severity escalates to Critical via gpt-5.5) — promote F-128 per-agent-identity-bootstrap to M0. Both flag, both tied to OpenClaw F1 cost-attribution drift. |
| **F6 — OAuth refresh-token race not mitigated in foundation** (OpenClaw F3) | Opus M3 (Major) | gpt-5.5 C3 (Critical) | **HARD BLOCK** (severity escalates to Critical via gpt-5.5) — promote F-129 oauth-refresh-singleflight-lock as a precondition for any OAuth-backed provider. |
| **F7 — Multi-agent fan-out cost not budget-gated before M10** (Anthropic ~10x token cost) | Opus M2 (Major; "F-126 misplaced in M8") | gpt-5.5 C5 (Critical) | **HARD BLOCK** (severity escalates to Critical via gpt-5.5) — promote F-131 fanout-budget-governor; tie F-126 context-budget-allocation to F-018 cost ledger; relocate F-126 to M2. |
| **F8 — Parent-child supervision via OS file-locks (OpenClaw F4 lesson) lacks F-NNN** | Opus M5 (Major) | gpt-5.5 M-E (Major) | **MUST-FIX** — both flag Major. Promote F-132 parent-child-supervision-locks (M2/M3). |
| **F9 — Per-agent filesystem isolation not explicit** (Lane C L1) | (Opus implicit via supervision lock; not a separate finding) | gpt-5.5 M-F (Major) | **SHOULD-FIX** — single-model signal; promote F-133 real-agent-filesystem-isolation but at lower confidence than F-NNN flagged by both. |
| **F10 — Hash-audit (F-015/F-016) under-specified on key/clock/process boundary** | (Opus does not flag specifically; only treats audit as triad with cost ledger) | gpt-5.5 M-D (Major) | **SHOULD-FIX** — single-model signal. Extend F-015 spec with monotonic seq, prev hash, wall+monotonic time, PID, agent ID, schema version, tamper-check CLI. |
| **F11 — A2A endpoint exposure F-122 in M4 premature without auth/TLS surface** | Opus m1 (Minor) | gpt-5.5 M-H (Major) | **MUST-FIX** — both flag (severity diverges; take the higher = Major). Split F-122: internal loopback-only in M4; external HTTPS only after F-127/F-130/F-134 + OAuth 2.1/TLS pinning decision. |
| **F12 — Soul boundary as runtime check is too weak; needs compile-time enforcement** | (Opus C1 implicit: "Soul boundary becomes a runtime assertion, not a type-system guarantee" + recommends eslint-plugin-boundaries) | gpt-5.5 M-J (Major) | **MUST-FIX** — both flag. Implement compile-time + package-boundary lint (eslint-plugin-boundaries / TS path restrictions); runtime check as defense-in-depth only. |
| **F13 — F-125 mcp-tool-cap-per-workspace duplicates / overlaps F-022 tool-quota** | Opus M1 (Major) | gpt-5.5 M-B (Major) | **MUST-FIX** — both flag. Opus says "rate vs cardinality, both needed, rename F-125 → mcp-tool-cardinality-cap"; gpt-5.5 says "merge into F-022 as hard default". Resolution: keep both as distinct features (rate-limit vs cardinality), rename F-125, add F-022 spec note `F-022 ≠ F-125`. |
| **F14 — F-126 context-budget-allocation misplaced in M8 settings; belongs M2** | Opus M2 (Major) | gpt-5.5 M-C (Major) | **MUST-FIX** — both flag, both place at M2. Relocate; bind to F-131 + F-018. |
| **F15 — All-7-phases-v1 is unsound for foundation wave** | Opus M6 (Major) | gpt-5.5 M-I (Major) | **MUST-FIX** — both flag. Freeze v1 around M0..M11 + packaging minimum; M12..M14 + M18 marketplace gated as post-foundation. |
| **F16 — Telemetry correlation late and incomplete without Agent365/OTel IDs from foundation events** | (Opus does not flag this independently — combines with C1) | gpt-5.5 M-K (Major) | **SHOULD-FIX** — single-model signal but tightly coupled with F5 (identity bootstrap). F-123 depends on F-128. |
| **F17 — Permissions model lacks expiry/override receipt coupling to audit hash chain** | (Opus does not flag this independently) | gpt-5.5 M-L (Major) | **SHOULD-FIX** — single-model signal. F-056..F-061 should require permission grant hash + expiry + approver + tool IDs + receipt link into F-015 chain. |
| **F18 — F-082..F-087 multi-model review wired to "5 high-blast-radius" call sites is undefined** | Opus M7 (Major) | (gpt-5.5 does not flag this independently) | **SHOULD-FIX** — single-model signal (Opus). Enumerate the 5 call sites in spec or kill F-087. |
| **F19 — Replay (F-092) deterministic claim conflates snapshot vs rerun modes** | Opus M8 (Major) | (gpt-5.5 does not flag) | **SHOULD-FIX** — single-model signal (Opus). Spec must distinguish snapshot (transcript-replay) vs rerun (re-execute) modes. |
| **F20 — `--council` flag (F-082) collides with `council-*` skill family naming** | Opus m4 (Minor) | (gpt-5.5 does not flag) | **CONSIDER** — single-model signal (Opus). Rename to `--multi-model` or `--adversarial`. |
| **F21 — F-D-018 activity-protocol overlaps F-D-007 + F-D-008 Teams/Outlook adapters** | Opus m3 (Minor) | (gpt-5.5 does not flag) | **CONSIDER** — single-model signal. Collapse to one deferred entry. |
| **F22 — F-110..F-113 OTel + F-123 genai-spans should be one milestone block** | Opus m5 (Minor) | (gpt-5.5 does not flag) | **CONSIDER** — single-model signal. Merge F-123 into M16 spec instead of as NEW addendum. |
| **F23 — F-124 multi-tier-routing overlaps M1 provider selection + M10 council dispatch** | Opus m2 (Minor; "belongs in M1") | gpt-5.5 m1 (Minor) | **CONSIDER** — both flag at minor severity. Rename to `adaptive-model-routing-policy`; constrain under F-131 budget governor; coexist with C2 IBackendProvider split. |
| **F24 — F-073 encrypted import-export is unrelated to F-126 context-budget-allocation** | (Opus does not flag) | gpt-5.5 m2 (Minor) | **CONSIDER** — single-model signal; keep quota/budget out of settings persistence. |
| **F25 — M2 label "governance triad" undersells scope** | (Opus does not flag; uses "governance" verbatim) | gpt-5.5 m4 (Minor) | **CONSIDER** — single-model signal; rename M2 to "Governance kernel". |
| **F26 — M18 local marketplace conflicts with M7 skill allowlist/version-pin without named source-of-truth** | (Opus does not flag) | gpt-5.5 m3 (Minor) | **CONSIDER** — single-model signal; define marketplace as UI over the F-134 signed skill registry/lockfile. |
| **F27 — MCP OAuth 2.1 server-to-server + TLS pinning (MCP roadmap 2026)** has no F-NNN | Opus G5 (gap) | gpt-5.5 G8 (gap, mapped to F-122 hardening) | **MUST-FIX** — both flag as gap. Promote **F-135 mcp-oauth-2.1-tls-pin** (M6) per Opus, OR fold into F-122 external-endpoint hardening per gpt-5.5. Cross-model agreement: external-endpoint security gate is needed; exact F-NNN shape is open. |
| **F28 — OTel GenAI semantic-convention attribute enumeration absent in F-123 spec** | Opus G6 (gap) | (not flagged independently by gpt-5.5; M-K is correlation timing) | **SHOULD-FIX** — single-model signal (Opus). Expand F-123 to require `gen_ai.agent.id` / `request.model` / `usage.input_tokens` / `usage.output_tokens`. |
| **F29 — Foundry hosted-agent deployment lifecycle has no v1 export/manifest hook** | Opus G7 (gap) | (not flagged) | **SHOULD-FIX** — single-model. Promote **F-136 agent-manifest export** (M17 docs/schema) so deferred F-D-017 has something to read later. |
| **F30 — Tool-explosion telemetry (>10 tools degrades context routing per WorkIQ Lobster)** | Opus G8 (gap) | (not flagged) | **SHOULD-FIX** — single-model. Add `tool_routing_ambiguity_score` counter to F-110. |
| **F31 — Status events during silent recovery (clawpilot lesson)** | Opus G9 (gap) | (not flagged) | **SHOULD-FIX** — single-model. F-024 heartbeat doesn't surface degraded states to UX; promote **F-137 supervisor status stream**. |
| **F32 — Activity Protocol wire compat for future Teams/Outlook adapters** | Opus G10 (gap) | (not flagged) | **CONSIDER** — single-model. Ensure `Turn` event envelope is Activity-Protocol-compatible to avoid v1.5 rewrite. |
| **F33 — F-079 token-refresh single-flight semantics not specified** | Opus M3 (Major; tied to OpenClaw F3) | gpt-5.5 C3 (Critical; tied to OpenClaw F3 + F-129) | duplicate of **F6** above; same root finding, same HARD BLOCK. |
| **P1 — HITL (propose → approve → execute → receipt) loop is correct UX invariant** | Opus implicit (M4 + P5) | gpt-5.5 P1 | **PRAISE** — both confirm. |
| **P2 — Hash-chained audit is right forensic backbone** | Opus P1 | gpt-5.5 P2 | **PRAISE** — both confirm. |
| **P3 — Tool cap of 10 default aligns with WorkIQ tool-explosion evidence** | (Opus does not echo P3 explicitly) | gpt-5.5 P3 | single-model praise. |
| **P4 — Kill-switch / override / degrade triad is correct safety shape** | Opus P1 | gpt-5.5 P4 | **PRAISE** — both confirm. |
| **P5 — Multi-model adversarial review for high-blast-radius (with budget gate)** | Opus implicit (P5 — pluggability prevents lock-in) | gpt-5.5 P5 | **PRAISE** — both confirm pattern; both also flag must-be-budget-gated. |
| **P6 — 3-tier permissions (auto/prompt/block) matches Cursor/Windsurf 2026** | Opus P2 | (gpt-5.5 does not echo) | single-model praise. |
| **P7 — Headless CLI (M4) + desktop shell (M5) duality is correct** | Opus P3 | (gpt-5.5 does not echo) | single-model praise. |
| **P8 — 11 sanctioned v1.5 deferrals from canonical-e are explicit (no-silent-deferrals discipline)** | Opus P4 | (gpt-5.5 does not echo) | single-model praise. |

### Cross-model summary

| Severity bucket | Count | Notes |
|---|---:|---|
| HARD BLOCK (both flag Critical OR one flag Critical, other Major same root) | **7** (F1, F2, F3, F4, F5, F6, F7) | Block M0/M1 freeze until remediated |
| MUST-FIX (both flag Major) | **5** (F8, F11, F12, F13, F14, F15) | Should-fix before milestone freeze |
| SHOULD-FIX (single-model Major) | **8** (F9, F10, F16, F17, F18, F19, F28, F29, F30, F31) | Single-model signal; promote with lower confidence |
| CONSIDER (Minor / single-model) | **6** (F20, F21, F22, F23, F24, F25, F26, F32) | Style/redundancy; not blocking |
| PRAISE — both flag | **4** (P1, P2, P4, P5) | Preserve. |
| PRAISE — single-model | **4** (P3, P6, P7, P8) | Preserve. |

## Findings by severity (gpt-5.5 only)

### Critical

- **C1 — M0/M1 ship executable surfaces before M2 governance is reachable.** F-001..F-013 bootstrap backend/tool execution before F-014..F-022 (halt, audit, cost, kill-switch, degradation, tool-quota). Early "working" paths are ungovernable by construction. **Action:** add **F-127 foundation-governance-kernel** to M0 (immutable audit append, halt token, policy gate, cost meter stub, identity subject required before any provider/tool call). [source: K/CE/CP]
- **C2 — Per-agent identity chain is not foundation-order blocking.** canonical-e has FR-IDENTITY-001 but catalog places governance triad in M2 while M0/M1 establish sessions/providers. Audit, cost, OAuth, permissions, replay all need stable agent identity from first turn. **Action:** add **F-128 per-agent-identity-bootstrap** to M0; F-009..F-013 depend on it; every backend/tool event carries `{sessionId, agentId, roleId, parentId, identityProvider}`. [source: CE/Agent365/CP]
- **C3 — OAuth refresh-token race (OpenClaw F3) has no explicit mitigation in foundation.** M9 owns MSAL/WAM later, but backend/tool providers in M1/M6 may need OAuth earlier. OpenClaw showed refresh-token reuse can revoke the entire provider account. **Action:** add **F-129 oauth-refresh-singleflight-lock** before any OAuth-backed provider — per-identity refresh mutex, token generation check, failed-refresh quarantine, audit event. [source: CP]
- **C4 — Hallucinated tool invocation is not its own safety primitive.** Devin lessons rank this #1 failure mode; current catalog audits tool calls (F-047) and permissions (F-058..F-061) but lacks pre-execution tool-name/schema proof. **Action:** add **F-130 tool-invocation-proof-gate** in M2 — tool call must resolve to registered tool ID, schema hash, permission grant, workspace allowlist, model-visible tool manifest version. [source: V/Devin/K]
- **C5 — Multi-agent fan-out cost explosion is acknowledged but not gated before M10.** Anthropic multi-agent research reports ~10x token cost; M10 ships council dispatch later, but K-origin agent-team behavior may appear in foundation loops earlier. **Action:** add **F-131 fanout-budget-governor** in M2 — max agents, max tokens, max wall-clock, dynamic degrade to single-reviewer, per-agent ledger enforcement. [source: V/Anthropic/K]

### Major

- **M-A — `IBackendProvider` risks over-normalizing Anthropic vs Copilot SDK event semantics.** **Action:** split F-009..F-013 into transport-neutral command API + provider-native event adapters; require canonical event envelope with raw provider payload preserved for audit/replay.
- **M-B — F-125 `mcp-tool-cap-per-workspace` partially duplicates F-022 tool-quota.** **Action:** merge F-125 into F-022 as hard default `maxVisibleTools=10` + override workflow + routing-quality telemetry + audit receipt.
- **M-C — F-126 context-budget-allocation belongs near M1/M2, not M8.** **Action:** move F-126 to M2; bind to F-131; per-plane context budgets for system/rules/tools/history/retrieval with truncation receipts.
- **M-D — Hash-audit (F-015/F-016) under-specified on key/clock/process boundary.** **Action:** extend with monotonic sequence, previous hash, wall-clock + monotonic time, process ID, agent ID, schema version, tamper-check CLI.
- **M-E — Parent-child supervision via OS/file locks is missing despite OpenClaw F4.** **Action:** add **F-132 parent-child-supervision-locks** in M2/M3 — OS-level lock per child agent/session, heartbeat lease, orphan reaper, no synthetic isolation claims.
- **M-F — Per-agent filesystem isolation is not explicit.** **Action:** add **F-133 real-agent-filesystem-isolation** before concurrent agents — separate cwd/scratch/temp/audit namespaces; shared writes only through mediated artifacts.
- **M-G — Supply-chain risk on inherited 70 skills is not represented.** **Action:** add **F-134 skill-supply-chain-attestation** in M7 but gate bundled skills in M0 — manifest lockfile, content hash, source repo/ref, signature status, allowed capability list.
- **M-H — A2A endpoint exposure F-122 in M4 is premature without auth/TLS/policy surface.** **Action:** split F-122: internal loopback-only in M4; external HTTPS A2A only after F-127/F-130/F-134 + OAuth 2.1/TLS pinning decision.
- **M-I — "All 7 phases in v1" is unsound for a foundation wave.** **Action:** freeze v1 around M0..M11 + packaging minimum; M12..M14 + M18 marketplace behind explicit "post-foundation" gates unless they validate core safety.
- **M-J — Soul boundary as runtime check is too weak if privileged APIs remain importable.** **Action:** compile-time / package-boundary enforcement (separate modules, lint rule import ban, test fixture attempting forbidden imports), runtime check as defense-in-depth only.
- **M-K — Telemetry correlation late and incomplete without Agent365/OTel IDs in foundation events.** **Action:** F-123 depends on F-128; every audit/tool/backend/span event carries trace/span/session/agent IDs from M0 onward.
- **M-L — Permissions model lacks expiry/override receipt coupling to audit hash chain.** **Action:** F-056..F-061 require permission grant hash, expiry timestamp, approver identity, affected tool IDs, receipt link into F-015 hash chain.

### Minor

- **m1 — F-124 multi-tier-routing overlaps M1 provider selection + M10 council dispatch.** Rename to **adaptive-model-routing-policy**; constrain to provider/model choice under F-131 budget governor.
- **m2 — F-073 encrypted import-export is unrelated to context-budget quota.** F-126 not covered by F-073; keep quota/budget out of settings persistence.
- **m3 — M18 local marketplace conflicts with M7 skill allowlist/version-pin unless source-of-truth is named.** Define marketplace as UI over the same signed skill registry/lockfile from F-134.
- **m4 — "Governance triad" label undersells actual scope.** Rename M2 to **Governance kernel** — includes audit, halt, cost, kill, degradation, quota, redaction, policy.

### Praise (preserve what worked)

- **P1 — Propose → approve → execute → receipt HITL loop is the right UX invariant.** [source: CP/K]
- **P2 — Hash-chained audit + query-audit from canonical-e is the right forensic backbone.** [source: CE]
- **P3 — Default tool cap of 10 aligns with WorkIQ tool-explosion evidence.** [source: Microsoft]
- **P4 — Kill-switch / override / degrade triad is the correct safety shape.** [source: CE]
- **P5 — Multi-model adversarial review for high-blast-radius changes is worth preserving, but must be budget-gated.** [source: K/V]

## Wave-1 findings without F-NNN coverage (gap)

- **G1** — Devin hallucinated-tool-invocation failure → no F-NNN; add **F-130**.
- **G2** — Anthropic multi-agent ~10x token cost → no enforcement F-NNN; add **F-131**.
- **G3** — OpenClaw parent-child supervision via OS-level file locks → no F-NNN; add **F-132**.
- **G4** — OpenClaw real per-agent filesystem isolation, not synthetic → no F-NNN; add **F-133**.
- **G5** — Supply-chain attestation for 70 inherited skills → no F-NNN; add **F-134**.
- **G6** — OAuth refresh-token singleflight/race quarantine → no F-NNN; add **F-129**.
- **G7** — Agent365 telemetry correlation from first event → only late F-123; needs M0/M2 dep via **F-128**.
- **G8** — MCP OAuth 2.1/TLS pinning direction → not covered by F-044..F-050/F-122; add external-endpoint security gate to **F-122**.

## NEW backlog items (append to docs/10-backlog/)

To `docs/10-backlog/feature-promotions.md` — promote 8 NEW F-NNN candidates:
- F-127 foundation-governance-kernel (M0) — HIGH conf, single-model
- F-128 per-agent-identity-bootstrap (M0) — HIGH conf, single-model
- F-129 oauth-refresh-singleflight-lock (M2) — HIGH conf, single-model (matches OpenClaw F3 evidence)
- F-130 tool-invocation-proof-gate (M2) — HIGH conf, single-model (matches Devin lessons)
- F-131 fanout-budget-governor (M2) — HIGH conf, single-model (matches Anthropic 10x token cost)
- F-132 parent-child-supervision-locks (M2/M3) — HIGH conf, single-model (matches OpenClaw F4)
- F-133 real-agent-filesystem-isolation (M2) — HIGH conf, single-model (matches Lane C L1)
- F-134 skill-supply-chain-attestation (M7 with M0 gate) — HIGH conf, single-model

To `docs/10-backlog/design-decisions-pending.md` — surface 3 architectural decisions:
- Drop "all 7 phases in v1" target; freeze foundation around M0..M11 + packaging
- M2 rename to "Governance kernel" (label-only)
- Soul boundary: compile-time package-boundary enforcement + runtime check as defense-in-depth (not runtime-only)

To `docs/10-backlog/research-gaps.md` — log Context Gap:
- Wave-002 Lane C Copilot CLI dispatch had Opus timeout; cross-model signal is single-model. Wave-3 should re-dispatch with longer timeout (1200s) or use synchronous role-split second voice for Opus path.

## Loop-improvement proposal for wave-3

Wave-3 should stop adding frontier features and produce a dependency-checked **foundation cut**: reorder M0..M2 into an executable governance kernel; assign every provider/tool/agent feature a blocking dependency on identity + audit + halt + policy + budget; run an adversarial matrix over the new F-127..F-134 gaps. Output a milestone graph (not prose): each F-NNN has `requires`, `blocks`, `security invariant`, `first milestone where executable code may call tools/providers`. **Plus: re-dispatch the Copilot CLI design review with TimeoutSeconds=1200 to get the second-voice cross-model signal that wave-002 Lane C did not produce.**

## Wave-3 retry resolution

**Retry executed: 2026-05-06.** Per Lane C wave-2 loop-improvement #1, wave-3 Lane B re-dispatched the Copilot CLI design review with TimeoutSeconds=1200 (Start-Job + `copilot --model claude-opus-4.7 --yolo -p`).

### What changed

- **Cross-model signal acquired.** Opus returned in ~94 seconds (1m 28s wall-clock per Copilot meter; 63.7k input + 4.6k output + 27.7k cached tokens). The wave-2 600s timeout was likely a transient — possibly cold-cache + Copilot CLI warm-up, or model availability fluctuation — NOT a fundamental capacity issue. Wave-3 retry succeeded comfortably under the 600s default. **Recommendation: keep dispatcher default at 600s; treat 1200s as the next escalation tier per `feedback_pr_review_calibration_20260503.md`. Add retry-once-on-timeout to dispatcher logic** (see backlog item below).
- **Cross-model agreement table now populated** (see above section). **7 HARD BLOCKs identified** vs. wave-2's "5 single-model Critical pending manual gate."
- **Severity escalations from cross-model agreement.** Three wave-2 single-model Critical findings get corroboration from Opus at Major severity — they remain HARD BLOCK because the *root cause* is concurred even if severity tag differs (F2, F4, F12). Three wave-2 single-model Major findings get escalated to HARD BLOCK because Opus flags them Critical (F2, F4 in Opus's view).
- **Severity escalations from gpt-5.5 corroboration.** Three wave-2 Opus-only Critical findings stay Critical because gpt-5.5 also flags them Critical (F1, F3) or as a related Critical finding (F7).
- **8 single-model SHOULD-FIX surfaced** that the original gpt-5.5-only run did not produce (Opus contributions: F18, F19, F28, F29, F30, F31, F32; F-NNN shape variations on F27).
- **F-NNN promotion roster expanded.** Wave-2 promoted F-127..F-134 (8 entries). Wave-3 retry adds candidate F-135 (mcp-oauth-2.1-tls-pin), F-136 (agent-manifest-export), F-137 (supervisor-status-stream) — all SHOULD-FIX single-model from Opus only; promote at MEDIUM confidence pending wave-4 corroboration.

### F-NNN candidates by cross-model confidence

| F-NNN | Wave-2 confidence | Wave-3 retry confidence | Cross-model decision |
|---|---|---|---|
| F-127 foundation-governance-kernel | HIGH (gpt-5.5 only) | HIGH (Opus C1 + gpt-5.5 C1 = HARD BLOCK) | **PROMOTE — both flag Critical** |
| F-128 per-agent-identity-bootstrap | HIGH (gpt-5.5 only) | HIGH (Opus M4 + gpt-5.5 C2 = HARD BLOCK) | **PROMOTE — both flag, sev escalates to Critical** |
| F-129 oauth-refresh-singleflight-lock | HIGH (gpt-5.5 only) | HIGH (Opus M3 + gpt-5.5 C3 = HARD BLOCK) | **PROMOTE — both flag, sev escalates to Critical** |
| F-130 tool-invocation-proof-gate | HIGH (gpt-5.5 only) | HIGH (Opus C3 + gpt-5.5 C4 = HARD BLOCK) | **PROMOTE — both flag Critical** |
| F-131 fanout-budget-governor | HIGH (gpt-5.5 only) | HIGH (Opus M2 + gpt-5.5 C5 = HARD BLOCK) | **PROMOTE — both flag, sev escalates to Critical** |
| F-132 parent-child-supervision-locks | HIGH (gpt-5.5 only) | HIGH (Opus M5 + gpt-5.5 M-E = MUST-FIX) | **PROMOTE — both flag Major** |
| F-133 real-agent-filesystem-isolation | HIGH (gpt-5.5 only) | MEDIUM (gpt-5.5 only — Opus folded into supervision lock; not separate finding) | **PROMOTE at MEDIUM** — single-model; demote-or-keep decision deferred to wave-4 |
| F-134 skill-supply-chain-attestation | HIGH (gpt-5.5 only) | HIGH (Opus C4 + gpt-5.5 M-G = HARD BLOCK) | **PROMOTE — both flag, sev escalates to Critical** |
| **NEW F-135 mcp-oauth-2.1-tls-pin** | not in wave-2 | MEDIUM (Opus G5 + gpt-5.5 G8 — both flag as gap; F-NNN shape divergent) | **PROMOTE at MEDIUM** — both flag; folding into F-122 hardening or new F-NNN is open |
| **NEW F-136 agent-manifest-export** | not in wave-2 | LOW (Opus G7 only) | **PROMOTE at LOW** — single-model |
| **NEW F-137 supervisor-status-stream** | not in wave-2 | LOW (Opus G9 only) | **PROMOTE at LOW** — single-model |

### Anomalies

- **GPT-5.5 raw_output mojibake** (`ΓÇö`, `ΓåÆ`, `ΓÇÿ`) carried over from wave-2 PowerShell stdout encoding; wave-3 Opus output has the **same UTF-8 BOM issue** (PowerShell default Out-File without `-Encoding utf8` flag — but this run does set `-Encoding utf8`, so the issue is upstream in the Copilot CLI's stdout pipeline). The findings extracted preserve intent; cosmetic-only. Wave-4 should normalize via `[System.Text.UTF8Encoding]::new($false)` per `powershell-conventions.md`.
- **Opus dispatched standalone, not via dispatcher.** Lane B did NOT re-run `Invoke-CopilotMultiModel.ps1` (which would have re-run gpt-5.5 unnecessarily). Instead spawned `copilot --model claude-opus-4.7` directly via Start-Job and merged the result manually. Dispatcher remains the canonical multi-model primitive; standalone path is justified for retry-of-one-leg.
- **Wave-2 timeout cause unclear.** Without an Opus-side telemetry trail, we cannot verify whether the wave-2 timeout was: (a) Copilot CLI cold-start, (b) model availability, (c) network blip, (d) brief-size complexity (12KB ~= 36k input tokens — within Opus's stated max but at the upper end). Wave-4 dispatcher should add retry-once-on-timeout (60s sleep, then retry with same TimeoutSeconds) before declaring failure; this would have caught the wave-2 case for free.
