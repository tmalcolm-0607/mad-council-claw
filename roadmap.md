---
artifact-class: navigable-roadmap
generated-by: wave-011 / lane-d
generated-by-version: 0.2.0
wave: wave-011
date: 2026-05-07
status: living
---

# Roadmap

> Navigable view of all milestones + features. Status auto-tracks `docs/03-feature-catalog/Mn-*/F-NNN-*.md` ledger frontmatter (`red` / `green` / `locked`). Source of truth for behavior contracts: per-feature ledger files. Source of truth for milestone scope: `docs/01-requirements/foundational-plan.md` § "True Synthesis → Feature catalog".

## Status legend

- 🔴 **RED** — ledger exists, status=red; test exists or planned, implementation absent, test fails
- 🟢 **GREEN** — ledger exists, status=green; test exists, implementation present, test passes
- 🔒 **LOCKED** — ledger exists, status=green AND post-impl council-review verdict ACCEPT (post-impl review verdict file must exist alongside the ledger)
- ⏸ **DEFERRED** — explicitly out of v1 (user-acknowledged); re-open trigger noted in `docs/10-backlog/`
- ⚪ **PLANNED** — feature ID reserved in foundational-plan catalog; ledger not yet authored

## Update protocol

- When a feature transitions RED → GREEN → LOCKED, the agent updates the corresponding row in this file in the **same commit** as the ledger frontmatter change. Per `no-silent-deferrals.md` and the chain-of-thought commit message shape, the WHY field cites both transitions.
- New ledger authored (PLANNED → RED): update both the ledger and this roadmap row in one commit.
- Per `concurrency-safety.md`: this file is mutable shared state; use atomic write-temp-rename when multiple instances may edit concurrently.

## Milestone overview

| Milestone | Theme | Span | Total | RED | GREEN | LOCKED | DEFERRED | PLANNED |
|---|---|---|---:|---:|---:|---:|---:|---:|
| M0 | Project bootstrap | F-001..F-008 | 8 | 2 | 1 | 5 | 0 | 0 |
| M1 | Pluggable backend | F-009..F-013 | 5 | 5 | 0 | 0 | 0 | 0 |
| M2 | Governance triad | F-014..F-022 | 9 | 0 | 9 | 0 | 0 | 0 |
| M3 | Cron / heartbeat | F-023..F-027 | 5 | 5 | 0 | 0 | 0 | 0 |
| M4 | Headless CLI | F-028..F-031 | 4 | 4 | 0 | 0 | 0 | 0 |
| M5 | Desktop chat shell | F-032..F-043 | 12 | 12 | 0 | 0 | 0 | 0 |
| M6 | MCP & tools | F-044..F-050 | 7 | 7 | 0 | 0 | 0 | 0 |
| M7 | Skills + Permissions + Automations | F-051..F-066 | 16 | 16 | 0 | 0 | 0 | 0 |
| M8 | Settings & persistence | F-067..F-075 | 9 | 9 | 0 | 0 | 0 | 0 |
| M9 | M365 integration | F-076..F-081 | 6 | 6 | 0 | 0 | 0 | 0 |
| M10 | Multi-model adversarial review | F-082..F-087 | 6 | 6 | 0 | 0 | 0 | 0 |
| M11 | Soul / introspect / replay | F-088..F-092 | 5 | 5 | 0 | 0 | 0 | 0 |
| M12 | Visualization (NEW) | F-093..F-095 | 3 | 3 | 0 | 0 | 0 | 0 |
| M13 | Multimodal input (NEW) | F-096..F-100 | 5 | 5 | 0 | 0 | 0 | 0 |
| M14 | Productivity (NEW) | F-101..F-103 | 3 | 3 | 0 | 0 | 0 | 0 |
| M15 | Build / packaging | F-104..F-109 | 6 | 6 | 0 | 0 | 0 | 0 |
| M16 | Telemetry | F-110..F-113 | 4 | 4 | 0 | 0 | 0 | 0 |
| M17 | Documentation | F-114..F-118 | 5 | 5 | 0 | 0 | 0 | 0 |
| M18 | Marketplace local-v1 | F-119..F-121 | 3 | 3 | 0 | 0 | 0 | 0 |
| **NEW from research** | Frontier-2026 candidates | F-122..F-126 | 5 | 5 | 0 | 0 | 0 | 0 |
| M19 | Deferred (user-acknowledged tracking row) | F-D-001..F-D-018 | 18 | 0 | 0 | 0 | 18 | 0 |
| **TOTAL** | (121 base + 5 new = 126 active) + 18 deferred | | **144** | **111** | **10** | **5** | **18** | **0** |

> Wave-1 research lanes consolidated ~78 additional F-NNN candidates as F-127..F-204 (see `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md`). These are tracked in the consolidation matrix and will be allocated against existing milestones (or roll a M20+) as design decisions close. They are NOT counted in the milestone-overview table above; that table uses the foundational-plan F-NNN allocation only.

> Wave-10 transition note (closing summary `docs/11-loop-state/wave-history/wave-010.md`): F-008 (M0), F-019 / F-020 / F-022 (M2) flipped RED → GREEN. Wave-11 in flight: Lane A (F-007 ipc-contract-scaffold), Lane B (F-001 GREEN → LOCKED candidate via post-impl council review), Lane C (M5 desktop-shell ledger refresh + RED→GREEN candidate), Lane D (this lane — roadmap freshness).

> Wave-12 / Lane C transition note: F-122..F-126 (the 5 frontier-research candidates that had been PLANNED for several waves) flipped PLANNED → RED. Ledgers now exist in their respective milestone directories: F-122 (M4), F-123 (M16), F-124 (M1), F-125 (M7), F-126 (M8). Provenance traces to wave-1 Lane A (findings 21, 23) + Lane B (findings 10, 15, 16). D-3 (F-125 default cap) and D-4 (F-124 default policy) remain OPEN; closure is prerequisite for RED → GREEN flips.

> Wave-12 / Lane D transition note: F-002 + F-006 + F-008 flipped GREEN → LOCKED via post-impl council reviews. Three new review files under `docs/05-design-reviews/council-reviews/` (F-002 median confidence 90; F-006 median 86; F-008 median 88; all verdict ACCEPT, 0 CRITICAL / 0 MAJOR each). M0 now reads 3R + 1G + 4L (F-001/F-002/F-006/F-008 LOCKED; F-007 GREEN; F-003/F-004/F-005 RED). Total project state: 114 RED / 8 GREEN / 4 LOCKED across 144 features (126 active + 18 deferred).

> Wave-12 / Lane A transition note: F-021 (degradation-fallback) flipped RED → GREEN. New `packages/engine-core/src/degradation.ts` (~208 LOC) lands the in-memory `DegradationLadder` primitive — a 5-rung escalation ladder (`normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt`) with `escalate(trigger)` advancing one rung at a time and `recover(reason)` dropping one rung; reaching 'halt' returns a `RunHaltedVerdict` (trigger=`degrade_escalate`, the 14th value in the F-018 `HaltTrigger` union). Per-resource circuit-breaker, Context-Gaps emission, required-vs-optional classification, and F-018 hand-off for required-dependency failures deferred to engine-cycle integration per `rules/no-silent-deferrals.md`. M2 row updated 2R + 7G → 1R + 8G; TOTAL 114R / 8G → 113R / 9G.

> Wave-12 / Lane B transition note: F-017 (pii-redaction-egress) flipped RED → GREEN. New `packages/engine-core/src/redaction.ts` (~104 LOC) lands the `redact()` + `redactObject()` helper primitives — pattern-based PII redactor for engine egress paths (audit-log writes, telemetry exports, outbound LLM-call prompts) with 4 built-in categories (emails, phones, GUIDs, home paths) + `customPatterns` for project-specific tokens. Order-of-operations (emails → GUIDs → phones → home paths → custom) prevents GUID-vs-phone false-match. Reject-on-detect orchestration (ledger's stricter `PII_DETECTED: <category>` semantics), F-015 audit-log emission tie-in, M16 telemetry-export integration, M1 LLM-call integration, and adversarial-eval lane deferred per `rules/no-silent-deferrals.md`. M2 row 1R + 8G → 0R + 9G; TOTAL 113R / 9G → 112R / 10G. **M2 governance triad now fully RED-cleared.**

> Wave-13 / Lane A transition note: **F-021 finalization** (deferred from wave-12 / lane-a). No row state change — F-021 is already 🟢 GREEN at wave-12 HEAD via commits `8d79b1f` (RED test stub) + `226acaa` (GREEN impl). Lane finalizes the deferred docs + proof artifacts that the wave-12 / lane-a ledger commit (intended SHA `395b79b`) failed to land due to the pre-commit-hook subject-rerouting pathology (commit `395b79b` actually landed F-017 redaction files under the F-021 ledger subject). This lane lands: F-021 ledger frontmatter flip (status: red → green + status-history append + Implementation notes section), `docs/09-examples-proof/F-021/{red,green}-test-output.txt` proof artifacts, wave-13 confidence-ledger entries, and this transition note. M2 row 0R + 9G unchanged; TOTAL 112R / 10G / 4L unchanged. Full suite at finalization time: 94/94 PASS across 14 test files (no regressions vs wave-12 / lane-b checkpoint).

> Wave-13 / Lane B transition note: **F-005 RED → GREEN** + **F-007 GREEN → LOCKED** (paired flip in same lane). F-005 deps-pinning lands `tests/node/F-005-deps-pinning.test.ts` (4 tests; root + workspace package.json exact-pin sweep, lockfile presence, engines.node specified) — RED captured (5 `^`-prefixed devDeps), root `package.json` updated to exact pins (vitest 2.1.9, @vitest/ui 2.1.9, happy-dom 15.11.7, typescript 5.9.3, @types/node 20.19.39) + `packageManager: pnpm@9.0.0` declared, `pnpm-lock.yaml` regenerated with exact-pin specifiers, GREEN captured (4/4 PASS); package-manager choice (npm → pnpm) recorded in F-005 ledger §Implementation notes (transfers F-005 intent: committed lockfile + reproducible install + frozen-lockfile install path). F-007 ipc-contract-scaffold council review at `docs/05-design-reviews/council-reviews/F-007-ipc-contract-scaffold-review.md` verdict ACCEPT (median confidence per Advocate / Skeptic / Architect lenses; 0 CRITICAL / 0 MAJOR; scaffold-shape contract only, M5 integration scenarios deferred per F-007 ledger). M0 row 3R + 1G + 4L → 2R + 1G + 5L; TOTAL 112R + 10G + 4L → 111R + 10G + 5L. **Fifth LOCKED transition in the repo** (after F-001 wave-11, F-002 + F-006 + F-008 wave-12). Full suite at GREEN time: 98/98 across 15 test files (was 94/94 across 14 pre-F-005).

## Per-milestone detail

### M0 — Project bootstrap

📂 [`docs/03-feature-catalog/M0-bootstrap/README.md`](docs/03-feature-catalog/M0-bootstrap/README.md) — engine kernel, identity, scaffolding, vitest+playwright, deps, logging, IPC contract, storage layout.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-001 | engine-bootstrap-loop | 🔒 LOCKED | `tests/unit/F-001-engine-bootstrap-loop.test.ts` (3/3 PASS); council review verdict ACCEPT (median 88) — wave-11 / lane-b |
| F-002 | per-agent-identity-runid | 🔒 LOCKED | `tests/unit/F-002-per-agent-identity-runid.test.ts` (3/3 PASS); council review verdict ACCEPT (median 90) — wave-12 / lane-d |
| F-003 | repo-scaffolding | 🔴 RED | TBD |
| F-004 | vitest-playwright-config | 🔴 RED | TBD |
| F-005 | deps-pinning | 🟢 GREEN | `tests/node/F-005-deps-pinning.test.ts` (4/4 PASS) — wave-13/lane-b flip; root + workspace package.json exact-pin sweep + lockfile presence + engines.node check; package-manager choice (npm → pnpm) recorded in §Implementation notes (transfers F-005 intent: committed lockfile + reproducible-install discipline); cross-OS byte-identity + drift-fails-CI deferred to M16 per `no-silent-deferrals.md` |
| F-006 | logging-pipeline | 🔒 LOCKED | `tests/unit/F-006-logging-pipeline.test.ts` (4/4 PASS); council review verdict ACCEPT (median 86) — wave-12 / lane-d |
| F-007 | ipc-contract-scaffold | 🔒 LOCKED | `tests/unit/F-007-ipc-contract-scaffold.test.ts` (3/3 PASS); council review verdict ACCEPT — wave-13 / lane-b; scaffold-shape contract; M5 integration scenarios deferred |
| F-008 | local-storage-layout | 🔒 LOCKED | `tests/node/F-008-local-storage-layout.test.ts` (6/6 PASS); council review verdict ACCEPT (median 88) — wave-12 / lane-d |

### M1 — Pluggable backend

📂 [`docs/03-feature-catalog/M1-backend/README.md`](docs/03-feature-catalog/M1-backend/README.md) — IBackendProvider, Anthropic SDK, Copilot SDK, factory, event normalization.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-009 | ibackendprovider | 🔴 RED | TBD |
| F-010 | anthropic-sdk-provider | 🔴 RED | TBD |
| F-011 | copilot-sdk-provider | 🔴 RED | TBD |
| F-012 | backend-factory | 🔴 RED | TBD |
| F-013 | event-normalization | 🔴 RED | TBD |

### M2 — Governance triad

📂 [`docs/03-feature-catalog/M2-governance-triad/README.md`](docs/03-feature-catalog/M2-governance-triad/README.md) — pre-close signal, hash-audit, query-audit, PII redaction, halt, cost ledger, kill-switch, degradation, tool-quota.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-014 | pre-close-retro-signal | 🟢 GREEN | `tests/unit/F-014-pre-close-retro-signal.test.ts` (8/8 PASS) |
| F-015 | hash-chained-audit-log | 🟢 GREEN | `tests/unit/F-015-hash-chained-audit-log.test.ts` (4/4 PASS) |
| F-016 | query-audit-log | 🟢 GREEN | `tests/unit/F-016-query-audit-log.test.ts` (8/8 PASS) |
| F-017 | pii-redaction-egress | 🟢 GREEN | `tests/unit/F-017-audit-pii-redaction.test.ts` (8/8 PASS) — wave-12/lane-b flip; redact() + redactObject() helper primitives (~104 LOC, 4 built-in categories: emails / phones / GUIDs / home paths + customPatterns); reject-on-detect orchestration + audit-log emission tie-in + telemetry/LLM-call integration deferred to engine-cycle integration |
| F-018 | failure-pattern-halt | 🟢 GREEN | `tests/unit/F-018-failure-pattern-halt.test.ts` (9/9 PASS) |
| F-019 | cost-ledger | 🟢 GREEN | `tests/unit/F-019-cost-ledger.test.ts` (8/8 PASS) |
| F-020 | kill-switch | 🟢 GREEN | `tests/unit/F-020-kill-switch.test.ts` (11/11 PASS) |
| F-021 | degradation-fallback | 🟢 GREEN | `tests/unit/F-021-degradation-ladder.test.ts` (11/11 PASS) — wave-12/lane-a flip; in-memory escalation-ladder primitive (5 rungs + halt); per-resource circuit-breaker + Context-Gaps + required-vs-optional classification deferred to engine-cycle integration |
| F-022 | tool-quota | 🟢 GREEN | `tests/unit/F-022-tool-call-quota.test.ts` (8/8 PASS) |

### M3 — Cron / heartbeat

📂 [`docs/03-feature-catalog/M3-cron-heartbeat/README.md`](docs/03-feature-catalog/M3-cron-heartbeat/README.md) — heartbeat, skip-on-overlap, idle archival, resume-from-checkpoint, manual halt override.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-023 | cron-heartbeat | 🔴 RED | TBD |
| F-024 | skip-on-overlap | 🔴 RED | TBD |
| F-025 | idle-archival | 🔴 RED | TBD |
| F-026 | resume-from-checkpoint | 🔴 RED | TBD |
| F-027 | manual-halt-override | 🔴 RED | TBD |

### M4 — Headless CLI

📂 [`docs/03-feature-catalog/M4-headless-cli/README.md`](docs/03-feature-catalog/M4-headless-cli/README.md) — cli entry, subcommands, JSON output, daemon mode.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-028 | cli-entry | 🔴 RED | TBD |
| F-029 | subcommands | 🔴 RED | TBD |
| F-030 | json-output | 🔴 RED | TBD |
| F-031 | daemon-mode | 🔴 RED | TBD |

### M5 — Desktop chat shell

📂 [`docs/03-feature-catalog/M5-desktop-shell/`](docs/03-feature-catalog/M5-desktop-shell/) (full ledger set landed wave-3 lane-b) — window, history, info-panel, model picker, personality, system message, primitives, theming, shortcuts, menu, notifications, multi-window.

| F-ID | Slug | Status |
|---|---|---|
| F-032 | window | 🔴 RED |
| F-033 | history | 🔴 RED |
| F-034 | info-panel | 🔴 RED |
| F-035 | model-picker | 🔴 RED |
| F-036 | personality | 🔴 RED |
| F-037 | system-message-editor | 🔴 RED |
| F-038 | ui-primitives | 🔴 RED |
| F-039 | theming | 🔴 RED |
| F-040 | keyboard-shortcuts | 🔴 RED |
| F-041 | menu-bar | 🔴 RED |
| F-042 | notifications | 🔴 RED |
| F-043 | multi-window | 🔴 RED |

### M6 — MCP & tools

🔴 RED ledgers landed wave-4 lane-a — bridge, lifecycle, reconnect+health, tool-call audit, streaming, BYO-MCP, registry persist.

| F-ID | Slug | Status |
|---|---|---|
| F-044 | mcp-bridge | 🔴 RED |
| F-045 | mcp-lifecycle | 🔴 RED |
| F-046 | mcp-reconnect-health | 🔴 RED |
| F-047 | tool-call-audit | 🔴 RED |
| F-048 | mcp-streaming | 🔴 RED |
| F-049 | byo-mcp | 🔴 RED |
| F-050 | mcp-registry-persist | 🔴 RED |

### M7 — Skills + Permissions + Automations

🔴 RED ledgers landed wave-4 lane-b — SKILL.md, bundled, toggle, custom-load, allowlist, version-pin, expiry, 3-tier perms, rules, audit, automations base + cron + condition + multistep + persist + shell-visible.

| F-ID | Slug | Status |
|---|---|---|
| F-051 | skill-md-format | 🔴 RED |
| F-052 | skills-bundled | 🔴 RED |
| F-053 | skills-toggle | 🔴 RED |
| F-054 | skills-custom-load | 🔴 RED |
| F-055 | skills-allowlist | 🔴 RED |
| F-056 | skills-version-pin | 🔴 RED |
| F-057 | skills-expiry | 🔴 RED |
| F-058 | perms-3-tier | 🔴 RED |
| F-059 | perms-rules | 🔴 RED |
| F-060 | perms-audit | 🔴 RED |
| F-061 | automations-base | 🔴 RED |
| F-062 | automations-cron | 🔴 RED |
| F-063 | automations-condition | 🔴 RED |
| F-064 | automations-multistep | 🔴 RED |
| F-065 | automations-persist | 🔴 RED |
| F-066 | automations-shell-visible | 🔴 RED |

### M8 — Settings & persistence

🔴 RED ledgers landed wave-4 lane-d — shape, UI, per-automation rules, encrypted storage, key-mgmt, encrypted import/export, project workspace, switcher UI, persistence.

| F-ID | Slug | Status |
|---|---|---|
| F-067 | settings-shape | 🔴 RED |
| F-068 | settings-ui | 🔴 RED |
| F-069 | per-automation-rules | 🔴 RED |
| F-070 | encrypted-storage | 🔴 RED |
| F-071 | key-management | 🔴 RED |
| F-072 | encrypted-import-export | 🔴 RED |
| F-073 | project-workspace | 🔴 RED |
| F-074 | workspace-switcher-ui | 🔴 RED |
| F-075 | settings-persistence | 🔴 RED |

### M9 — M365 integration

🔴 RED ledgers landed wave-5 lane-a — MSAL, WAM, auth screen, token refresh, WorkIQ adapter, rate-limit+CB.

| F-ID | Slug | Status |
|---|---|---|
| F-076 | msal-auth | 🔴 RED |
| F-077 | wam-broker | 🔴 RED |
| F-078 | auth-screen | 🔴 RED |
| F-079 | token-refresh | 🔴 RED |
| F-080 | workiq-adapter | 🔴 RED |
| F-081 | rate-limit-circuit-breaker | 🔴 RED |

### M10 — Multi-model adversarial review

🔴 RED ledgers landed wave-5 lane-b — --council dispatch, agreement table, both-flag-CRITICAL block, fallback, consent gate, 5 high-blast-radius wired.

| F-ID | Slug | Status |
|---|---|---|
| F-082 | council-dispatch | 🔴 RED |
| F-083 | agreement-table | 🔴 RED |
| F-084 | both-flag-critical-block | 🔴 RED |
| F-085 | council-fallback | 🔴 RED |
| F-086 | council-consent-gate | 🔴 RED |
| F-087 | high-blast-radius-wiring | 🔴 RED |

### M11 — Soul / introspect / replay

🔴 RED ledgers landed wave-5 lane-c — soul boundary, schema, snapshot, signal pairs, deterministic replay.

| F-ID | Slug | Status |
|---|---|---|
| F-088 | soul-boundary | 🔴 RED |
| F-089 | soul-schema | 🔴 RED |
| F-090 | soul-snapshot | 🔴 RED |
| F-091 | signal-pairs | 🔴 RED |
| F-092 | deterministic-replay | 🔴 RED |

### M12 — Visualization (NEW)

🔴 RED ledgers landed wave-6 lane-a — timeline UI, replay scrubber, filtering. New surface beyond clawpilot + canonical-e per `[V:11]`.

| F-ID | Slug | Status |
|---|---|---|
| F-093 | timeline-ui | 🔴 RED |
| F-094 | replay-scrubber | 🔴 RED |
| F-095 | timeline-filtering | 🔴 RED |

### M13 — Multimodal input (NEW)

🔴 RED ledgers landed wave-6 lane-b — voice STT, engine selection, activation modes, screenshot-to-prompt, image preprocessing.

| F-ID | Slug | Status |
|---|---|---|
| F-096 | voice-stt | 🔴 RED |
| F-097 | stt-engine-selection | 🔴 RED |
| F-098 | voice-activation-modes | 🔴 RED |
| F-099 | screenshot-to-prompt | 🔴 RED |
| F-100 | image-preprocessing | 🔴 RED |

### M14 — Productivity (NEW)

🔴 RED ledgers landed wave-6 lane-a — daily briefing, schedule, destination.

| F-ID | Slug | Status |
|---|---|---|
| F-101 | daily-briefing | 🔴 RED |
| F-102 | briefing-schedule | 🔴 RED |
| F-103 | briefing-destination | 🔴 RED |

### M15 — Build / packaging

🔴 RED ledgers landed wave-6 lane-c — electron-builder, auto-update, branding, code signing, CI, CLI binary.

| F-ID | Slug | Status |
|---|---|---|
| F-104 | electron-builder | 🔴 RED |
| F-105 | auto-update | 🔴 RED |
| F-106 | branding | 🔴 RED |
| F-107 | code-signing | 🔴 RED |
| F-108 | ci-pipeline | 🔴 RED |
| F-109 | cli-binary | 🔴 RED |

### M16 — Telemetry

🔴 RED ledgers landed wave-7 lane-a — local OTel, crash reporting, perf metrics, opt-in/out.

| F-ID | Slug | Status |
|---|---|---|
| F-110 | local-otel | 🔴 RED |
| F-111 | crash-reporting | 🔴 RED |
| F-112 | perf-metrics | 🔴 RED |
| F-113 | telemetry-opt-in-out | 🔴 RED |

### M17 — Documentation

🔴 RED ledgers landed wave-7 lane-a — README+quickstart, architecture docs, skill guide, MCP guide, automation cookbook.

| F-ID | Slug | Status |
|---|---|---|
| F-114 | readme-quickstart | 🔴 RED |
| F-115 | architecture-docs | 🔴 RED |
| F-116 | skill-guide | 🔴 RED |
| F-117 | mcp-guide | 🔴 RED |
| F-118 | automation-cookbook | 🔴 RED |

### M18 — Marketplace local-v1

🔴 RED ledgers landed wave-7 lane-b — local marketplace, metadata, search/browse UI.

| F-ID | Slug | Status |
|---|---|---|
| F-119 | local-marketplace | 🔴 RED |
| F-120 | marketplace-metadata | 🔴 RED |
| F-121 | marketplace-search-ui | 🔴 RED |

### NEW from research (foundational-plan §"Plus 5 NEW F-NNN candidates")

🔴 RED — added during loop iter-1..4 frontier research; allocated to existing milestones. Ledgers authored wave-012/lane-c.

| F-ID | Slug | Target milestone | Status | Source |
|---|---|---|---|---|
| F-122 | a2a-endpoint-exposure | M4 | 🔴 RED | `[R:WorkIQ + msft-learn finding 10]` (wave-1 lane-b finding 10) |
| F-123 | otel-genai-spans | M16 | 🔴 RED | `[R:msft-learn Foundry observability]` (wave-1 lane-b finding 16) |
| F-124 | multi-tier-routing-haiku-opus | M1 | 🔴 RED | `[R:WebSearch frontier 2026 architecture]` (wave-1 lane-a finding 21) |
| F-125 | mcp-tool-cap-per-workspace | M7 | 🔴 RED | `[R:WorkIQ internal tool-explosion lesson]` (wave-1 lane-b finding 15) |
| F-126 | context-budget-allocation | M8 | 🔴 RED | `[R:WebSearch frontier 2026]` (wave-1 lane-a finding 23) |

### M19 — Deferred (tracking only; user-acknowledged)

⏸ DEFERRED — explicitly out of v1 per user-acknowledged scope. Re-open trigger: see `docs/10-backlog/`. F-D-016/017/018 are reserved IDs without ledger files yet (15 ledgers exist on disk, 3 reserved).

| F-ID | Slug | Status |
|---|---|---|
| F-D-001 | cloud-marketplace | ⏸ DEFERRED |
| F-D-002 | ring-deployment | ⏸ DEFERRED |
| F-D-003 | archive-tier | ⏸ DEFERRED |
| F-D-004 | schema-migration | ⏸ DEFERRED |
| F-D-005 | identity-crypto | ⏸ DEFERRED |
| F-D-006 | entra-binding | ⏸ DEFERRED |
| F-D-007 | teams-adapter | ⏸ DEFERRED |
| F-D-008 | outlook-adapter | ⏸ DEFERRED |
| F-D-009 | bot-framework | ⏸ DEFERRED |
| F-D-010 | agent365-sink | ⏸ DEFERRED |
| F-D-011 | byok | ⏸ DEFERRED |
| F-D-012 | sandboxing | ⏸ DEFERRED |
| F-D-013 | i18n | ⏸ DEFERRED |
| F-D-014 | mobile-companion | ⏸ DEFERRED |
| F-D-015 | (reserved) | ⏸ DEFERRED |
| F-D-016 | in-meeting-live-assistant | ⏸ DEFERRED |
| F-D-017 | foundry-hosted-agent-deployment | ⏸ DEFERRED |
| F-D-018 | activity-protocol-teams-outlook | ⏸ DEFERRED |

## Dependency graph (high-level)

```
M0 (bootstrap) ──► M1 (backend) ──► M2 (governance triad)
                                         │
                                         ▼
                          M3 (cron) ◄──► M4 (CLI)
                                         │
                                         ▼
                M5 (desktop shell) ◄═parallel═► M6 (MCP) ──► M7 (extensibility) ──► M8 (settings)
                                                                          │
                                                                          ▼
                                            M9 (M365) ──► M10 (multi-model) ──► M11 (soul/replay)
                                                                          │
                                                                          ▼
                              M12 (viz) ‖ M13 (multimodal) ‖ M14 (productivity)
                                                                          │
                                                                          ▼
                                  M15 (build) ‖ M16 (telemetry) ‖ M17 (docs)
                                                                          │
                                                                          ▼
                                            M18 (marketplace local-v1)
                                                                          │
                                                                          ▼
                                            M19 (deferred — tracking only)
```

Notes:
- M0..M2 are sequential (foundation triad).
- M3 + M4 are co-equal headless concerns; either may land first based on driver demand.
- M5 + M6 can run in parallel with each other once M0..M4 settle; M5 depends on M0+M1, M6 depends on M0+M1+M2.
- M7 depends on M6 (skills are discovered via the MCP-style bridge).
- M8 depends on M7 (settings UI hosts the perms model + automations registry).
- M9 (M365) is gated on M0+M1+M2; can land in parallel with M5 (UI auth-screen depends on M9 partial).
- M10 depends on M1 (multi-provider) + M2 (council-dispatch is governance-adjacent).
- M11 depends on M2 (audit-log) + M14 (replay UI in scrubber).
- M12..M14 are NEW surfaces; depend on M5 (desktop shell) for UI hosts.
- M15..M17 cross-cut all milestones; M15 lands continuously as packaging concerns surface.
- M18 closes v1 with local marketplace; cloud variant tracked under M19 (user-acknowledged).

## Source

- Refreshed by **wave-11 / Lane D** (this commit). Original draft: wave-3 / Lane D.
- Authoritative source for per-feature behavior contracts: `docs/03-feature-catalog/Mn-*/F-NNN-*.md` ledgers.
- Authoritative source for milestones + scope: `docs/01-requirements/foundational-plan.md` § "True Synthesis → Feature catalog".
- Wave history: `docs/11-loop-state/wave-history/`.
- Dependency graph derived from foundational-plan dependency cues + Lane C (clawpilot/openclaw) lessons L1..L15 ordering hints.
