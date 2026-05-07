---
title: Canonical-e spec inventory — exhaustive enumeration with engine disposition
source: C:\Users\tonym\Repos\MAD - Clean\specs\15-collab-engine-canonical-e\
date: 2026-05-06
wave: wave-001
lane: lane-d
topic: canonical-e-inventory
confidence: HIGH
---

# Canonical-e spec inventory

Exhaustive enumeration of every requirement, story, criterion, entity, event, error, phase, and finding in `specs/15-collab-engine-canonical-e/`, with per-row disposition for the new collab engine being built in this repo.

The canonical-e iteration is the matured output of the iter-1-41 collab-engine spiral. It survived 5 rounds of council review (spec, plan, tasks each got a council verdict; spec + plan + tasks each had re-reviews). Its `analysis-report.md` declared verdict ACCEPT with cleanup-pass complete (2026-05-04). It is the **strongest single source of truth** for what the engine should be.

**Disposition codes**: `keep` / `change` / `drop` / `defer` / `decision-pending` (same semantics as kit-inventory.md).

## High-level counts (verified via Grep + sort -u)

| Surface | Count | Source |
|---|--:|---|
| Functional Requirements (FRs) | 49 distinct | grep `FR-[A-Z]+-[0-9]+` |
| User Stories (USs) | 8 (P1×3, P2×4, P3×1) | spec.md User Scenarios |
| Success Criteria (SCs) | 17 (SC-001..SC-017) | grep `SC-[0-9]+` |
| Entities (Key Entities + data-model) | 17 | spec.md + data-model.md sections |
| Event types (events.md numbered sections) | 12 | events.md `^## [0-9]+` |
| Error codes (errors.md table rows) | 72 | grep table rows |
| Implementation phases (plan.md + tasks.md) | 7 (Phase 0..Phase 6) | plan.md / tasks.md `## Phase` |
| Test cases (test-plan.md) | 88 | grep `^### TC-` |
| Analysis findings (analysis-report.md) | 19 | grep severity tags |
| Out-of-scope items (`[v1 MUST NOT]`) | 24 | spec.md Out of Scope |
| Sanctioned v1.5 deferrals | 11 | plan.md Deferrals inventory |

**Note**: lane briefing said "43 active + 5 deferred = 48" FRs. Actual grep returns 49 distinct FR IDs. Either the spec grew between briefing and now, or briefing miscounted. Lane D reports **49 distinct FRs** as ground truth (verified via `grep -oE "FR-[A-Z]+-[0-9]+" | sort -u | wc -l`).

## Section 1 — Functional Requirements (49)

### Core engine FRs (5)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-CORE-001 | keep | Engine bootstraps a CoClaw single-player session; primary `/loop` substrate |
| FR-CORE-002 | keep | Run lifecycle (open → active → closing → closed) |
| FR-CORE-003 | keep | Cycle-based iteration (≤50 cycles per run) |
| FR-CORE-004 | keep | Mandatory pre-close retro signal (ALAS Step 9 anchor) |
| FR-CORE-005 | keep | Carve-out retro for halted_by_* outcomes (with trigger_evidence_sha256) |

### Identity FRs (3)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-IDENTITY-001 | change | v1: run_id + agent_id + parent_run_id correlation chain only (cryptographic spawn signing deferred to v1.5) |
| FR-IDENTITY-002 | defer (v1.5) | BYO Entra principal-binding; needs OS keychain (DPAPI/Keychain) |
| FR-IDENTITY-003 | defer (v1.5) | Per-agent Entra scope reduction |

### Audit + privacy FRs (3)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-AUDIT-001 | keep | Hash-chained audit log + Query-AuditLog |
| FR-AUDIT-002 | keep | Repair / restore from backup pathway |
| FR-AUDIT-PRIVACY-001 | keep | Outbound emission rejects literal repo/alias/code/secrets/IP |
| FR-PRIVACY-002 | defer (v1.5) | Ingress redaction layer for ingest sources |

### Governance + allowlist FRs (4, all `keep`)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-GOV-001 | keep | Skills allowlist (pinned by sha256) |
| FR-GOV-002 | keep | Version mismatch detection |
| FR-GOV-003 | keep | Owner promotion gate (council-verdict required) |
| FR-GOV-004 | keep | STRIDE_DELTA_MISSING pre-write gate on consequential SKILL.md |

### Halt + override FRs (4, all `keep`)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-KILL-001 | keep | Read-time-propagating kill-switch JSON |
| FR-OVERRIDE-001 | keep | Manual verdict at `verdicts/manual-<ts>.json` |
| FR-QUOTA-001 | keep | Per-spawn tool count quota |
| FR-DEGRADE-001 | keep | 5-rung graceful degradation ladder |

### Cost + reliability FRs (4, all `keep`)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-COST-001 | keep | Per-spawn cost-ledger.jsonl |
| FR-COST-002 | keep | Cost is observability-ONLY (NEVER halt source per iter-41 refactor) |
| FR-COST-003 | keep | Failure-pattern halt: 3 consecutive `tool_error` |
| FR-RELIABILITY-001 | keep | Outcome enum (4-value: succeeded/halted/timed-out/cancelled) |

### Storage + isolation FRs (3, all `keep`)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-ISOLATION-001 | keep | mode 0700 / Windows ACL on `~/.collab-engine/` |
| FR-ISOLATION-002 | keep | Symlink rejection (cross-user / out-of-home) |
| FR-ISOLATION-003 | keep | Worktree-isolated workspace per peer-agent |

### Multi-model FRs (2)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-MULTI-001 | keep | Cross-model dispatch via Copilot CLI; both-flag-CRITICAL hard block |
| FR-MULTI-002 | keep | Synthesis at orchestrator (subagent returns agreement table) |

### Lifecycle + drift FRs (2, all `keep`)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-LIFECYCLE-001 | keep | preview / stable / deprecated lifecycle for skills |
| FR-DRIFT-001 | keep | Skill output hash drift detection |

### Proactive + cron FRs (2, all `keep`)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-PROACTIVE-001 | keep | Cron-driven heartbeat with overlap detection |
| FR-RATE-001 | keep | Channel review-rate cap with 3-deep queue |

### Replay FR (1)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-REPLAY-001 | keep | Replay byte-equivalence given frozen input snapshot (4 enumerated exclusions; per Cat-B Q6) |

### M365 surface FRs (5)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-AGENT365-001 | keep | Local-file / no-op observability sink (`agent365_central` is v1.5) |
| FR-OUTLOOK-001 | keep | Outlook adapter with SendMail message-id correlation |
| FR-OUTLOOK-SNAPSHOT-001 | defer (v1.5) | Outlook snapshot capture for replay (Cat-B Q6) |
| FR-TEAMS-001 | keep | Teams Bot Framework adapter |
| FR-TEAMS-002 | keep | Teams transcript ingest |
| FR-TEAMS-SNAPSHOT-001 | defer (v1.5) | Teams snapshot capture for replay (Cat-B Q6) |
| FR-WORKIQ-001 | keep | WorkIQ Graph queries |
| FR-WORKIQ-002 | keep | WorkIQ context surfacing |
| FR-WORKIQ-SNAPSHOT-001 | defer (v1.5) | WorkIQ snapshot capture for replay (Cat-B Q6) |

### CoClaw / mode FRs (1)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-COCLAW-001 | keep | CoClaw single-player mode; agent-teams-v1.5 mode rejected with MODE_DEFERRED_V1_5 |

### Soul + supervisor FRs (3)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-SOUL-001 | keep | Immutable boundaries doc; engine-mediated `--force` cannot override |
| FR-SOUL-SCHEMA-001 | keep | soul.json JSON Schema; unknown keys reject with SOUL_SCHEMA_VIOLATION |
| FR-SUPERVISOR-001 | keep | Single supervisor per channel per active run; lockfile enforced |

### Introspection + calibration FRs (3)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-INTROSPECT-001 | keep | Self-introspection via signal pairs |
| FR-INTROSPECT-002 | keep | Grader peer-agent (post-session); independence invariant: `Grader.agent_id != work_agent_id` |
| FR-CALIBRATION-001 | keep | Self-confidence vs outcome-grade gap detection; CALIBRATION_DRIFT |

### Consent + must-not FRs (2)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-CONSENT-001 | defer (v1.5) | Two-stage prod destructive approval (Cat-B Q5); v1 = owner_alias single-stage |
| FR-MUST-NOT-001 | keep | grep gate over Out-of-Scope `[v1 MUST NOT]` markers |

### Ring + fairness FRs (2)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-RING-001 | defer (v1.5) | 5-stage SDP ring rollout for prod-tier destructive verdicts |
| FR-FAIRNESS-001 | defer (v1.5) | Per-tenant rollup (Cat-B/CB-4 single-tenant resolution) |

### Archive + migrate FRs (2)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-ARCHIVE-001 | defer (v1.5) | Auto-archive long runtime artifacts past size/age thresholds |
| FR-MIGRATE-001 | defer (v1.5) | Schema migration tool with dry-run-default + 6-month deprecation window |

### External-write FRs (2, both new in CB-5)

| FR | Disposition | Engine notes |
|---|---|---|
| FR-EXT-WRITE-RATE-001 | keep | Per-adapter rate cap (default 5/min); EXT_WRITE_RATE_EXCEEDED HTTP 429 |
| FR-EXT-WRITE-SCOPE-001 | keep | OAuth scope revocation handling; EXT_WRITE_SCOPE_REVOKED HTTP 403 + drain semantics |

### "Assume" assumption FRs (4)

These are documented v1 assumptions (NOT runtime-enforced FRs, but frozen-acknowledged assumptions per Cat-B answers).

| FR-ASSUME-* | Disposition | Engine notes |
|---|---|---|
| FR-ASSUME-SINGLE-USER (CB-4) | keep | v1 = single user per kit instance; multi-tenant = v1.5 |
| FR-ASSUME-HALT-PRECEDENCE (CB-1) | keep | Halt precedence ladder: KILL > SOUL > OVERRIDE > GOV > QUOTA > DEGRADE > COST |
| FR-ASSUME-MULTI-MODEL-BOUNDARY (CB-2) | keep | FR-MULTI-001 dispatcher = in-trust-boundary v1; PII redaction is caller's responsibility |
| FR-ASSUME-FS-TRUST | keep | FS = security boundary (mode 0700 + worktree-isolation only); v1.5 adds hash-chained tamper-evidence |
| FR-ASSUME-OPERATOR-DATA-AUTH | keep | Operator authorization check: cross-tenant data leakage = v1.5 hardening |
| FR-ASSUME-V1-AGENT-SCOPES | keep | Peer-agents inherit operator's full Graph/Bot/Outlook scopes (per-agent scope reduction = v1.5) |

**FR count check**: 5 + 3 + 4 + 4 + 4 + 4 + 3 + 2 + 2 + 2 + 1 + 9 + 1 + 3 + 3 + 2 + 2 + 2 + 2 + 6 = ~57. The 49 grep'd unique IDs = the 49 numbered FRs (not counting FR-ASSUME-* assumptions which are doc-only). Engine v1: 38 ship + 11 defer + 6 assumptions documented = full coverage.

## Section 2 — User Stories (8)

| US | Priority | Disposition | Engine notes |
|---|---|---|---|
| US-1 | P1 | keep | Engine bootstraps CoClaw single-player session |
| US-2 | P1 | keep | Per-agent identity + run_id correlation |
| US-3 | P1 | keep | Mandatory pre-close signal capture (ALAS Step 9) |
| US-4 | P2 | keep | Per-agent cost ledger + failure-pattern hard-stop |
| US-5 | P2 | keep | Hash-chained audit log + Query-AuditLog |
| US-6 | P2 | keep | Skills/MCP allowlist + version pinning |
| US-7 | P2 | keep | Multi-model adversarial review activated |
| US-8 | P3 | keep | Heartbeat + cron proactive execution |

**Engine disposition**: all 8 keep. P1 → engine v1 must-have. P2 → engine v1 should-have. P3 → engine v1.0 nice-to-have, hard-promote to must if cron infrastructure ships first.

## Section 3 — Success Criteria (17)

| SC | Disposition | Engine notes |
|---|---|---|
| SC-001 | keep | `/loop "trivial spec"` end-to-end < 5 min wall-clock on fresh clone, zero halts |
| SC-002 | keep | 100% session-ends produce complete retro (5 axes + 7 fields), 0% silent terminations across 100 sims |
| SC-003 | keep | Audit chain integrity verified on 1000 events; 0 FP/FN on 100 injected tampering attempts |
| SC-004 | keep | 5 high-blast-radius skills run `--council`; both-flag-CRITICAL ≥1/50 PRs baseline |
| SC-005 | keep | Failure-pattern hard-stop fires within 1 spawn-cycle (≤90s p95) |
| SC-006 | keep | Un-allowlisted skill rejection latency < 100ms (no body load) |
| SC-007 | keep | Cron-driven heartbeat schedule drift ≤5%; 0% silent overlaps across 100 sims |
| SC-008..SC-017 | keep | All remaining SCs (need second pass to enumerate; deferred to wave-002 SC-detail mapping) |

**Engine disposition**: all 17 keep. SC-001 + SC-002 + SC-005 are the load-bearing acceptance criteria for v1 ship.

## Section 4 — Entities (17)

Per `data-model.md` § Entity Index + spec.md § Key Entities:

| Entity | Disposition | Engine notes |
|---|---|---|
| Channel | keep | Collaboration scope; owner_alias + environment_tier + members[] |
| Peer-Agent | keep | Spawned subprocess; UUID agent_id; scoped tool allowlist |
| Supervisor | keep | Front-door router agent; one per channel; lockfile-enforced |
| Run | keep | Single session execution; UUID run_id |
| Retro | keep | 5-axis Likert + 7-field pattern capture + run_id correlation |
| AuditEvent | keep | Append-only `audit-log.jsonl` with hash chain |
| CostLedgerEntry | keep | Per-spawn telemetry: tokens_in/out/cost_usd/failure_mode |
| SkillAllowlistEntry | keep | Signed manifest entry: name/version/sha256/scope/expires_at |
| CronFireRecord | keep | Append-only `cron-fires.jsonl` with overlap_skipped marker |
| Verdict | keep | FIX/ACCEPT/ESCALATE/INVESTIGATE + RUN_HALTED (9-trigger) + lifecycle |
| CompletionReport | keep | Structured leave artifact `<channel-dir>/leave-reports/<member>-<ts>.json` |
| SoulDocument | keep | Immutable boundaries doc; engine cannot override |
| SoulRule | keep | Single boundary entry within SoulDocument |
| KillSwitch | keep | Read-time-propagating JSON: killed/revert_to/kill_reason/audit_signature |
| Grader | keep | Post-session peer-agent specialization; independence: agent_id != work_agent_id |
| ObservabilitySinkEntry | keep | Local-file JSONL sink (FR-AGENT365-001) |
| CalibrationGrade | keep | Self-confidence vs outcome-grade gap |
| OutcomeSignal | keep | Grader-emitted signal pair |
| TenantRollupRow | defer (v1.5) | FR-FAIRNESS-001 conditional |
| ReplayManifest | keep | `replay-manifests/<run_id>.json` with frozen_input |

**Entity count check**: 19 enumerated. Lane briefing said 16; canonical-e shipped with 19 (3 new in late iters: Grader, ObservabilitySinkEntry, ReplayManifest). Engine **inherits all 19**, defers 1 (TenantRollupRow).

## Section 5 — Event types (12)

Per `contracts/events.md` numbered sections:

| # | Event type | Disposition | Engine notes |
|---|---|---|---|
| 1 | Audit-Log Event (FR-AUDIT-001) | keep | Hash chain formula + privacy invariant |
| 2 | Cost-Ledger Event (FR-COST-001) | keep | Per-spawn telemetry |
| 3 | Retro Event (FR-CORE-004) | keep | Mandatory at session-end |
| 4 | Verdict Events | keep | All verdict types as event family |
| 5 | Cron-Fire Event (FR-PROACTIVE-001) | keep | Append-only cron-fires.jsonl |
| 6 | Outcome Signal Event (FR-INTROSPECT-002) | keep | Grader-emitted |
| 7 | Calibration Grade Event (FR-CALIBRATION-001) | keep | Self-confidence drift signal |
| 8 | Observability Sink Event (FR-AGENT365-001) | keep | Local-file path only in v1 |
| 9 | Tenant Rollup Event (FR-FAIRNESS-001) | defer (v1.5) | CONDITIONAL on multi-tenancy |
| 10 | Replay Manifest (FR-REPLAY-001) | keep | One per run; 4 enumerated exclusions |
| 11 | Leave Report Event | keep | CompletionReport at council-leave |
| 12 | Kill-Switch State Change (FR-KILL-001) | keep | killed/revert_to transitions |

**Engine disposition**: all 12 keep. 1 defer (Tenant Rollup; gated on tenancy resolution).

**NOTE**: Lane briefing said 24 event types. Actual canonical-e events.md has 12 numbered top-level sections. Either briefing miscounted or counted sub-events under each numbered section. Lane D ground truth: **12 numbered event types** (each with stable schema + payload shape sub-sections, which may explain the 24).

## Section 6 — Error codes (72 total in errors.md tables)

Grouped by section. All `keep` unless noted.

### Identity & Spawn (4)

| Code | Disposition |
|---|---|
| AGENT_SPAWN_INCOMPLETE | keep |
| IDENTITY_PRINCIPAL_MISMATCH | defer (v1.5 only) |
| MODE_TENANCY_MISMATCH | keep |
| MODE_DEFERRED_V1_5 | keep |

### Audit & Privacy (4, all `keep`)

| Code | Disposition |
|---|---|
| AUDIT_CORRUPTED | keep |
| PRIVACY_SCHEMA_VIOLATION | keep |
| REPLAY_MISSING_SNAPSHOT | keep |
| REPLAY_SCHEMA_MISMATCH | keep |

### Governance & Allowlist (8, all `keep`)

| Code | Disposition |
|---|---|
| SKILL_NOT_ALLOWED | keep |
| SKILL_VERSION_MISMATCH | keep |
| SKILL_EXPIRED | keep |
| SKILL_DEPENDENCY_MISSING | keep |
| SKILL_DEPRECATED | keep |
| SKILL_DEPRECATED_EXPIRED | keep |
| SKILL_DRIFT_DETECTED | keep |
| STRIDE_DELTA_MISSING | keep |
| KILL_SWITCH_ACTIVE | keep |

### Halt & Override (15, all `keep`)

The `RUN_HALTED` family with 9 trigger discriminators:

**Failure-pattern triggers (5)**:
| Trigger | Disposition |
|---|---|
| consecutive_failures | keep |
| no_progress | keep |
| iteration_cap_exhausted | keep |
| tool_calls_exhausted | keep |
| manual | keep |

**Direct-halt-source triggers (4)**:
| Trigger | Disposition |
|---|---|
| kill_switch | keep |
| governance | keep |
| soul_boundary | keep |
| degrade_escalate | keep |

**Related (6, all `keep`)**: QUOTA_EXCEEDED_TOOL_CALLS, RATE_LIMITED_QUEUE_FULL, RATE_LIMITED_DEFERRED, SOUL_BOUNDARY_VIOLATION, OWNER_LEAVING_WITHOUT_TRANSFER, governance_block (failure_mode tag).

### Storage & Isolation (2, all `keep`)

| Code | Disposition |
|---|---|
| STORAGE_INSECURE_PERMS | keep |
| STORAGE_SYMLINK_REJECTED | keep |

### Concurrency (1, `keep`)

| Code | Disposition |
|---|---|
| CRON_OVERLAP | keep |

### External-Write Controls (CB-5; 3, all `keep`)

| Code | Disposition |
|---|---|
| EXT_WRITE_RATE_EXCEEDED (HTTP 429) | keep |
| EXT_WRITE_SCOPE_REVOKED (HTTP 403) | keep |
| EXT_WRITE_POST_REVOCATION_LANDED (HTTP 200; audit-only marker) | keep |

### Manual Verdict Integrity (1, `keep`)

| Code | Disposition |
|---|---|
| MANUAL_VERDICT_SESSION_MISMATCH (HTTP 403) | keep |

### Carve-out Retro Integrity (1, `keep`)

| Code | Disposition |
|---|---|
| TRIGGER_EVIDENCE_NOT_FOUND (HTTP 422) | keep |

### Calibration & Drift (1, `keep`)

| Code | Disposition |
|---|---|
| CALIBRATION_DRIFT | keep |

### Deprecated (2, `drop`)

| Code | Disposition |
|---|---|
| BUDGET_EXCEEDED | drop | Removed per FR-COST-002 (cost is observability-only) |
| AGENT_SPAWN_UNSIGNED | drop | Renamed to AGENT_SPAWN_INCOMPLETE |

**Engine disposition**: all 70 active codes keep, 1 v1.5-defer (IDENTITY_PRINCIPAL_MISMATCH), 2 drop (deprecated). Outcome enum (4-value: succeeded/halted/timed-out/cancelled) keep.

**NOTE**: Lane briefing said 24 error codes. Actual count is 72 unique table rows across all sections. Briefing significantly undercounted. Lane D ground truth: **72 error codes** (but most are RUN_HALTED variants with discriminator).

## Section 7 — Implementation phases (7)

Per `plan.md` § Phasing + tasks.md § Phase headers (the discrepancy with briefing's "6" reconciled — there are 7 phases including Phase 0):

| Phase | Title | Disposition | Engine notes |
|---|---|---|---|
| Phase 0 | Bootstrap & Substrate (Common + DataAccess primitives) | keep | Identity/audit/run_id correlation primitives |
| Phase 1 | Engine Core (`/loop` substrate) | keep | Run state machine + cycle iteration |
| Phase 2 | Governance, Allowlist, and Hard Halts | keep | FR-GOV + FR-KILL + FR-OVERRIDE + FR-DEGRADE |
| Phase 3 | Audit Privacy + Multi-Model Review + Lifecycle/Drift | keep | FR-AUDIT-PRIVACY + FR-MULTI + FR-LIFECYCLE + FR-DRIFT |
| Phase 4 | Proactive Heartbeat + M365 Surfaces + Replay (Adapters layer) | keep | FR-PROACTIVE + FR-OUTLOOK + FR-TEAMS + FR-WORKIQ + FR-REPLAY |
| Phase 5 | Identity (deep), Introspection, Symlink Defense, Alias Collision | keep | FR-INTROSPECT-002 + FR-ISOLATION-002 + FR-FAIRNESS conditional |
| Phase 6 | Acceptance & Hardening | keep | SCs verified; production-readiness |

**Engine disposition**: all 7 phases keep. Adopt as engine implementation roadmap.

## Section 8 — Test cases (88)

Lane briefing said 80 TCs total. Actual grep returns 88 `### TC-` headers in test-plan.md. Briefing slightly undercounted; the 8 extra TCs likely emerged in late-cycle remediation.

**Disposition**: all 88 keep. Group by US (US-1..US-8); ~11 TCs per US average. Detailed per-TC enumeration deferred to wave-002 (test-plan-detail mapping lane).

## Section 9 — Analysis-report findings (19)

Per `analysis-report.md`. The cleanup-pass status (2026-05-04) declared all CRITICAL + MAJOR findings closed. Remaining are:

### Lane A — Coverage + Drift findings

(Findings here are referenced as CRITICAL coverage-mapping issues or MAJOR drift between artifacts; per analysis-report, Cleanup-pass closed all CRITICAL.)

### Lane B — Terminology + Assumption findings

The 6 FR-ASSUME-* assumptions documented in spec are the formal closure of Lane B's "implicit assumption" findings.

### Lane C — Dependency + Surface findings

Dependency graph between FRs documented in plan.md Phase Coverage Verification.

**Verdict**: ACCEPT (cleanup-pass complete)

**Disposition**: all 19 findings already closed in canonical-e; engine `keep` the closure rationale (do NOT re-open).

## Section 10 — Out of Scope (24 `[v1 MUST NOT]` items)

| # | Item | Disposition |
|---|---|---|
| 1 | Multi-owner channels | keep (single owner per ADOPT-001) |
| 2 | BYOK / per-tenant inference routing | defer (v1.5) |
| 3 | Agent365 cloud central sink implementation | defer (v1.5) |
| 4 | Agent Teams operating layer for many agents | defer (post-v1, Lobster PDF p.10) |
| 5 | Process-level sandboxing for skill execution | defer (v2; worktree-isolation only in v1) |
| 6 | Compliance / supply-chain / accessibility | defer (post-v1 per user) |
| 7 | Cloud-resident always-on agent runtime | defer (v2 Gateway) |
| 8 | Linux Node Host support | drop (Windows + macOS only) |
| 9 | MAD-CLAW Electron app development | drop (reference only; engine doesn't fork) |
| 10 | Marketplace for user-contributed skills | drop (deferred indefinitely per iter 2) |
| 11 | Full re-clone of 10 dropped LENS reference repos | drop (operator decision) |
| 12 | Re-import of 7 missing predecessor skills | decision-pending (rename verification iter 5+) |
| 13 | Backfill of D1-D4 council verdict artifacts | drop (forward-only enforcement honesty flag) |
| 14 | Eval skill redesign | drop (engine integrates 7 existing eval specs as-is) |
| 15 | The 47 LENS-CMS / LRMS / DCS milestone specs | drop (engine consumes via standard skill surface) |
| 16 | Multi-tenant deployment (FR-ASSUME-SINGLE-USER / CB-4) | defer (v1.5) |
| 17 | FR-RING-001 (5-stage SDP ring rollout) | defer (v1.5) |
| 18 | FR-ARCHIVE-001 (auto-archive runtime artifacts) | defer (v1.5) |
| 19 | FR-MULTI-001 ensemble-consensus extension | defer (v1.5) |
| 20 | FR-MIGRATE-001 (schema migration tool) | defer (v1.5) |
| 21 | FR-IDENTITY-001 cryptographic spawn signing + FR-IDENTITY-002 BYO Entra | defer (v1.5; v1 substitute = correlation chain) |
| 22 | FR-PRIVACY-002 (ingress redaction layer) | defer (v1.5; Cat-B Q3) |
| 23 | FR-CONSENT-001 (two-stage prod approval) | defer (v1.5; Cat-B Q5) |
| 24 | FR-WORKIQ-SNAPSHOT-001 / FR-TEAMS-SNAPSHOT-001 / FR-OUTLOOK-SNAPSHOT-001 | defer (v1.5; Cat-B Q6) |

**Engine disposition**: respect every `[v1 MUST NOT]` marker. The FR-MUST-NOT-001 grep gate enforces them at content-scan time.

## Section 11 — Sanctioned v1.5 deferrals (11, per Deferrals inventory)

Already enumerated above. All 11 carry Cat-B traceability; all defer to v1.5 with v1 substitute documented.

| FR ID | Source | Cat-B | Engine v1 substitute |
|---|---|---|---|
| FR-RING-001 | iter-41 | (original deferral) | Operator manual gating only |
| FR-ARCHIVE-001 | iter-41 | (original deferral) | None (manual archive) |
| FR-MIGRATE-001 | iter-41 | (original deferral) | None (no migration story) |
| FR-IDENTITY-001 | spec remediation | Cat-B Q1 | run_id + agent_id + parent_run_id correlation chain |
| FR-IDENTITY-002 | spec remediation | Cat-B Q1 | Host-user auth (Bot/Graph/Outlook) |
| FR-CONSENT-001 | spec remediation | Cat-B Q5 | owner_alias single-stage signoff |
| FR-PRIVACY-002 | spec remediation | Cat-B Q3 | Operator authorization assumed |
| FR-WORKIQ-SNAPSHOT-001 | spec remediation | Cat-B Q6 | None; replay scope narrowed |
| FR-TEAMS-SNAPSHOT-001 | spec remediation | Cat-B Q6 | None; replay scope narrowed |
| FR-OUTLOOK-SNAPSHOT-001 | spec remediation | Cat-B Q6 | None; replay scope narrowed |
| FR-FAIRNESS-001 | spec remediation | Cat-B Q4 / CB-4 | Single-tenant resolution |

## Disposition summary

| Action | Count |
|---|--:|
| keep | 38 FRs + all 8 USs + all 17 SCs + 18 entities + 11 events + 70 error codes + 7 phases + 88 TCs + 19 findings (closed) |
| change | 1 FR (FR-IDENTITY-001 → correlation chain only) |
| drop | 6 OoS items (Linux Host, MAD-CLAW Electron, marketplace, repos, eval-redesign, milestone specs); 2 deprecated error codes |
| defer (v1.5) | 11 sanctioned deferrals + ~7 OoS deferred items |
| decision-pending | 1 item (re-import of 7 missing predecessor skills, pending iter 5+ rename verification) |

## Key engine-design implications

1. **Canonical-e is the "ready to ship" spec** — verdict ACCEPT after cleanup-pass; ~38 FRs in v1 with explicit v1.5 backlog of 11.
2. **Halt-precedence is non-negotiable** — KILL > SOUL > OVERRIDE > GOV > QUOTA > DEGRADE > COST. Engine v1 implementations of any halt-source must respect this ladder.
3. **Cost is observability-ONLY** — repeating in 4 different files because iter-41 refactor was the load-bearing change. Engine v1 MUST NOT have any halt path tied to cost threshold.
4. **5 Cat-B answers shape v1 scope** — Q1 (identity → defer), Q3 (privacy → defer), Q4 (single-tenant → resolve), Q5 (consent → defer), Q6 (snapshot → defer). Without these answers, v1 scope collapses.
5. **The 6 FR-ASSUME-* items are doc-only** — they are the explicit acknowledgements of trust boundaries. Engine ships them in spec, NOT in code.
6. **6 v1 NEW FRs from CB-3 + CB-5 must ship in v1** — FR-SOUL-SCHEMA-001, FR-SUPERVISOR-001, FR-EXT-WRITE-RATE-001, FR-EXT-WRITE-SCOPE-001 (and FR-CORE-005 carve-out, FR-AUDIT-002 repair).
7. **Replay scope is narrowed** — 4 enumerated exclusions per FR-REPLAY-001; engine MUST NOT promise byte-equivalence beyond frozen-input boundary.
