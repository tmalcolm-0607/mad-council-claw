---
artifact-class: design-review
review-type: copilot-cli-multi-model (partial — see Context Gap)
date: 2026-05-07
wave: wave-002 / lane-c
inputs:
  - docs/04-research/frontier-2026/*.md (12 docs)
  - docs/04-research/microsoft-2026/*.md (11 docs)
  - docs/04-research/openclaw-clawpilot/*.md (6 docs)
  - docs/04-research/mad-kit-inventory.md
  - docs/04-research/canonical-e-inventory.md
  - docs/04-research/cross-source-disposition-matrix.md
  - docs/01-requirements/foundational-plan.md (True Synthesis)
models-dispatched: [gpt-5.5 — completed; claude-opus-4.7 — TIMEOUT at 600s]
brief: .mad/scratch/wave-002-design-review-brief.md
dispatcher-output: .mad/scratch/wave-002-design-review-output/
---

# Wave-001 foundation design review

## Review path taken

**`copilot-cli-multi-model` partial.** Dispatcher (`Invoke-CopilotMultiModel.ps1`) launched two parallel Copilot CLI calls (claude-opus-4.7 + gpt-5.5) at TimeoutSeconds=600. GPT-5.5 returned a complete structured review at ~T+33s (job exited 0; raw_output ~7.6KB; 36.7k input + 2.2k output tokens per Copilot meter). Opus did not return within 600s and was Stop-Job'd. No partial Opus artifact was written.

**Context Gap (per `degradation-fallback-policy.md` Rule 3):** Cross-model signal is single-model. The both-flag-CRITICAL hard-block rule from `lens-multi-model-review-pattern.md` cannot fire on this run; severity escalation requires manual human gate. **All Critical findings below should be treated as candidates for HARD BLOCK pending wave-3 re-dispatch with a longer Opus timeout (recommend 1200s) or a synchronous role-split second voice.**

This dispatch satisfies QG7's "at least one Copilot CLI design review per N waves" — first dispatch executed, with a documented timeout path that informs the wave-3 dispatch budget.

## Cross-model agreement table

| Finding | claude-opus-4.7 | gpt-5.5 | Decision |
|---|---|---|---|
| (none — Opus timed out) | — | flagged | single-model only; no HARD BLOCK eligible |

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
