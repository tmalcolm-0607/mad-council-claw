---
artifact-class: navigable-roadmap
generated-by: wave-003 / lane-d
generated-by-version: 0.1.0
wave: wave-003
date: 2026-05-07
status: living
---

# Roadmap

> Navigable view of all milestones + features. Status auto-tracks `docs/03-feature-catalog/Mn-*/F-NNN-*.md` ledger frontmatter (`red` / `green` / `locked`). Source of truth for behavior contracts: per-feature ledger files. Source of truth for milestone scope: `docs/01-requirements/foundational-plan.md` § "True Synthesis → Feature catalog".

## Status legend

- 🔴 **RED** — ledger exists, status=red; test exists or planned, implementation absent, test fails
- 🟢 **GREEN** — ledger exists, status=green; test exists, implementation present, test passes
- 🔒 **LOCKED** — ledger exists, status=green AND post-impl council-review verdict ACCEPT
- ⏸ **DEFERRED** — explicitly out of v1 (user-acknowledged); re-open trigger noted in `docs/10-backlog/`
- ⚪ **PLANNED** — feature ID reserved in foundational-plan catalog; ledger not yet authored

## Update protocol

- When a feature transitions RED → GREEN → LOCKED, the agent updates the corresponding row in this file in the **same commit** as the ledger frontmatter change. Per `no-silent-deferrals.md` and the chain-of-thought commit message shape, the WHY field cites both transitions.
- New ledger authored (PLANNED → RED): update both the ledger and this roadmap row in one commit.
- Per `concurrency-safety.md`: this file is mutable shared state; use atomic write-temp-rename when multiple instances may edit concurrently.

## Milestone overview

| Milestone | Theme | Span | Total | RED | GREEN | LOCKED | DEFERRED | PLANNED |
|---|---|---|---:|---:|---:|---:|---:|---:|
| M0 | Project bootstrap | F-001..F-008 | 8 | 8 | 0 | 0 | 0 | 0 |
| M1 | Pluggable backend | F-009..F-013 | 5 | 5 | 0 | 0 | 0 | 0 |
| M2 | Governance triad | F-014..F-022 | 9 | 9 | 0 | 0 | 0 | 0 |
| M3 | Cron / heartbeat | F-023..F-027 | 5 | 5 | 0 | 0 | 0 | 0 |
| M4 | Headless CLI | F-028..F-031 | 4 | 4 | 0 | 0 | 0 | 0 |
| M5 | Desktop chat shell | F-032..F-043 | 12 | 5 | 0 | 0 | 0 | 7 |
| M6 | MCP & tools | F-044..F-050 | 7 | 0 | 0 | 0 | 0 | 7 |
| M7 | Skills + Permissions + Automations | F-051..F-066 | 16 | 0 | 0 | 0 | 0 | 16 |
| M8 | Settings & persistence | F-067..F-075 | 9 | 0 | 0 | 0 | 0 | 9 |
| M9 | M365 integration | F-076..F-081 | 6 | 0 | 0 | 0 | 0 | 6 |
| M10 | Multi-model adversarial review | F-082..F-087 | 6 | 0 | 0 | 0 | 0 | 6 |
| M11 | Soul / introspect / replay | F-088..F-092 | 5 | 0 | 0 | 0 | 0 | 5 |
| M12 | Visualization (NEW) | F-093..F-095 | 3 | 0 | 0 | 0 | 0 | 3 |
| M13 | Multimodal input (NEW) | F-096..F-100 | 5 | 0 | 0 | 0 | 0 | 5 |
| M14 | Productivity (NEW) | F-101..F-103 | 3 | 0 | 0 | 0 | 0 | 3 |
| M15 | Build / packaging | F-104..F-109 | 6 | 0 | 0 | 0 | 0 | 6 |
| M16 | Telemetry | F-110..F-113 | 4 | 0 | 0 | 0 | 0 | 4 |
| M17 | Documentation | F-114..F-118 | 5 | 0 | 0 | 0 | 0 | 5 |
| M18 | Marketplace local-v1 | F-119..F-121 | 3 | 0 | 0 | 0 | 0 | 3 |
| **NEW from research** | Frontier-2026 candidates | F-122..F-126 | 5 | 0 | 0 | 0 | 0 | 5 |
| M19 | Deferred / out-of-scope | F-D-001..F-D-018 | 18 | 0 | 0 | 0 | 18 | 0 |
| **TOTAL** | (121 base + 5 new = 126 active) + 18 deferred | | **144** | **36** | **0** | **0** | **18** | **90** |

> Wave-1 research lanes consolidated ~78 additional F-NNN candidates as F-127..F-204 (see `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md`). These are tracked in the consolidation matrix and will be allocated against existing milestones (or roll a M20+) as design decisions close. They are NOT counted in the milestone-overview table above; that table uses the foundational-plan F-NNN allocation only.

## Per-milestone detail

### M0 — Project bootstrap

📂 [`docs/03-feature-catalog/M0-bootstrap/README.md`](docs/03-feature-catalog/M0-bootstrap/README.md) — engine kernel, identity, scaffolding, vitest+playwright, deps, logging, IPC contract, storage layout.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-001 | engine-bootstrap-loop | 🔴 RED | `tests/unit/F-001-engine-bootstrap-loop.test.ts` |
| F-002 | per-agent-identity-runid | 🔴 RED | TBD |
| F-003 | repo-scaffolding | 🔴 RED | TBD |
| F-004 | vitest-playwright-config | 🔴 RED | TBD |
| F-005 | deps-pinning | 🔴 RED | TBD |
| F-006 | logging-pipeline | 🔴 RED | TBD |
| F-007 | ipc-contract-scaffold | 🔴 RED | TBD |
| F-008 | local-storage-layout | 🔴 RED | TBD |

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
| F-014 | pre-close-retro-signal | 🔴 RED | TBD |
| F-015 | hash-chained-audit-log | 🔴 RED | TBD |
| F-016 | query-audit-log | 🔴 RED | TBD |
| F-017 | pii-redaction-egress | 🔴 RED | TBD |
| F-018 | failure-pattern-halt | 🔴 RED | TBD |
| F-019 | cost-ledger | 🔴 RED | TBD |
| F-020 | kill-switch | 🔴 RED | TBD |
| F-021 | degradation-fallback | 🔴 RED | TBD |
| F-022 | tool-quota | 🔴 RED | TBD |

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

📂 [`docs/03-feature-catalog/M5-desktop-shell/`](docs/03-feature-catalog/M5-desktop-shell/) (in-flight wave-3 Lane B; 5/12 ledgers landed) — window, history, info-panel, model picker, personality, system message, primitives, theming, shortcuts, menu, notifications, multi-window.

| F-ID | Slug | Status |
|---|---|---|
| F-032 | window | 🔴 RED |
| F-033 | history | 🔴 RED |
| F-034 | info-panel | 🔴 RED |
| F-035 | model-picker | 🔴 RED |
| F-036 | personality | 🔴 RED |
| F-037 | system-message-editor | ⚪ PLANNED |
| F-038 | ui-primitives | ⚪ PLANNED |
| F-039 | theming | ⚪ PLANNED |
| F-040 | keyboard-shortcuts | ⚪ PLANNED |
| F-041 | menu-bar | ⚪ PLANNED |
| F-042 | notifications | ⚪ PLANNED |
| F-043 | multi-window | ⚪ PLANNED |

### M6 — MCP & tools

⚪ PLANNED — bridge, lifecycle, reconnect+health, tool-call audit, streaming, BYO-MCP, registry persist.

| F-ID | Slug | Status |
|---|---|---|
| F-044 | mcp-bridge | ⚪ PLANNED |
| F-045 | mcp-lifecycle | ⚪ PLANNED |
| F-046 | mcp-reconnect-health | ⚪ PLANNED |
| F-047 | tool-call-audit | ⚪ PLANNED |
| F-048 | mcp-streaming | ⚪ PLANNED |
| F-049 | byo-mcp | ⚪ PLANNED |
| F-050 | mcp-registry-persist | ⚪ PLANNED |

### M7 — Skills + Permissions + Automations

⚪ PLANNED — SKILL.md, bundled, toggle, custom-load, allowlist, version-pin, expiry, 3-tier perms, rules, audit, automations base + cron + condition + multistep + persist + shell-visible.

| F-ID | Slug | Status |
|---|---|---|
| F-051 | skill-md-format | ⚪ PLANNED |
| F-052 | skills-bundled | ⚪ PLANNED |
| F-053 | skills-toggle | ⚪ PLANNED |
| F-054 | skills-custom-load | ⚪ PLANNED |
| F-055 | skills-allowlist | ⚪ PLANNED |
| F-056 | skills-version-pin | ⚪ PLANNED |
| F-057 | skills-expiry | ⚪ PLANNED |
| F-058 | perms-3-tier | ⚪ PLANNED |
| F-059 | perms-rules | ⚪ PLANNED |
| F-060 | perms-audit | ⚪ PLANNED |
| F-061 | automations-base | ⚪ PLANNED |
| F-062 | automations-cron | ⚪ PLANNED |
| F-063 | automations-condition | ⚪ PLANNED |
| F-064 | automations-multistep | ⚪ PLANNED |
| F-065 | automations-persist | ⚪ PLANNED |
| F-066 | automations-shell-visible | ⚪ PLANNED |

### M8 — Settings & persistence

⚪ PLANNED — shape, UI, per-automation rules, encrypted storage, key-mgmt, encrypted import/export, project workspace, switcher UI, persistence.

| F-ID | Slug | Status |
|---|---|---|
| F-067 | settings-shape | ⚪ PLANNED |
| F-068 | settings-ui | ⚪ PLANNED |
| F-069 | per-automation-rules | ⚪ PLANNED |
| F-070 | encrypted-storage | ⚪ PLANNED |
| F-071 | key-management | ⚪ PLANNED |
| F-072 | encrypted-import-export | ⚪ PLANNED |
| F-073 | project-workspace | ⚪ PLANNED |
| F-074 | workspace-switcher-ui | ⚪ PLANNED |
| F-075 | settings-persistence | ⚪ PLANNED |

### M9 — M365 integration

⚪ PLANNED — MSAL, WAM, auth screen, token refresh, WorkIQ adapter, rate-limit+CB.

| F-ID | Slug | Status |
|---|---|---|
| F-076 | msal-auth | ⚪ PLANNED |
| F-077 | wam-broker | ⚪ PLANNED |
| F-078 | auth-screen | ⚪ PLANNED |
| F-079 | token-refresh | ⚪ PLANNED |
| F-080 | workiq-adapter | ⚪ PLANNED |
| F-081 | rate-limit-circuit-breaker | ⚪ PLANNED |

### M10 — Multi-model adversarial review

⚪ PLANNED — --council dispatch, agreement table, both-flag-CRITICAL block, fallback, consent gate, 5 high-blast-radius wired.

| F-ID | Slug | Status |
|---|---|---|
| F-082 | council-dispatch | ⚪ PLANNED |
| F-083 | agreement-table | ⚪ PLANNED |
| F-084 | both-flag-critical-block | ⚪ PLANNED |
| F-085 | council-fallback | ⚪ PLANNED |
| F-086 | council-consent-gate | ⚪ PLANNED |
| F-087 | high-blast-radius-wiring | ⚪ PLANNED |

### M11 — Soul / introspect / replay

⚪ PLANNED — soul boundary, schema, snapshot, signal pairs, deterministic replay.

| F-ID | Slug | Status |
|---|---|---|
| F-088 | soul-boundary | ⚪ PLANNED |
| F-089 | soul-schema | ⚪ PLANNED |
| F-090 | soul-snapshot | ⚪ PLANNED |
| F-091 | signal-pairs | ⚪ PLANNED |
| F-092 | deterministic-replay | ⚪ PLANNED |

### M12 — Visualization (NEW)

⚪ PLANNED — timeline UI, replay scrubber, filtering. New surface beyond clawpilot + canonical-e per `[V:11]`.

| F-ID | Slug | Status |
|---|---|---|
| F-093 | timeline-ui | ⚪ PLANNED |
| F-094 | replay-scrubber | ⚪ PLANNED |
| F-095 | timeline-filtering | ⚪ PLANNED |

### M13 — Multimodal input (NEW)

⚪ PLANNED — voice STT, engine selection, activation modes, screenshot-to-prompt, image preprocessing.

| F-ID | Slug | Status |
|---|---|---|
| F-096 | voice-stt | ⚪ PLANNED |
| F-097 | stt-engine-selection | ⚪ PLANNED |
| F-098 | voice-activation-modes | ⚪ PLANNED |
| F-099 | screenshot-to-prompt | ⚪ PLANNED |
| F-100 | image-preprocessing | ⚪ PLANNED |

### M14 — Productivity (NEW)

⚪ PLANNED — daily briefing, schedule, destination.

| F-ID | Slug | Status |
|---|---|---|
| F-101 | daily-briefing | ⚪ PLANNED |
| F-102 | briefing-schedule | ⚪ PLANNED |
| F-103 | briefing-destination | ⚪ PLANNED |

### M15 — Build / packaging

⚪ PLANNED — electron-builder, auto-update, branding, code signing, CI, CLI binary.

| F-ID | Slug | Status |
|---|---|---|
| F-104 | electron-builder | ⚪ PLANNED |
| F-105 | auto-update | ⚪ PLANNED |
| F-106 | branding | ⚪ PLANNED |
| F-107 | code-signing | ⚪ PLANNED |
| F-108 | ci-pipeline | ⚪ PLANNED |
| F-109 | cli-binary | ⚪ PLANNED |

### M16 — Telemetry

⚪ PLANNED — local OTel, crash reporting, perf metrics, opt-in/out.

| F-ID | Slug | Status |
|---|---|---|
| F-110 | local-otel | ⚪ PLANNED |
| F-111 | crash-reporting | ⚪ PLANNED |
| F-112 | perf-metrics | ⚪ PLANNED |
| F-113 | telemetry-opt-in-out | ⚪ PLANNED |

### M17 — Documentation

⚪ PLANNED — README+quickstart, architecture docs, skill guide, MCP guide, automation cookbook.

| F-ID | Slug | Status |
|---|---|---|
| F-114 | readme-quickstart | ⚪ PLANNED |
| F-115 | architecture-docs | ⚪ PLANNED |
| F-116 | skill-guide | ⚪ PLANNED |
| F-117 | mcp-guide | ⚪ PLANNED |
| F-118 | automation-cookbook | ⚪ PLANNED |

### M18 — Marketplace local-v1

⚪ PLANNED — local marketplace, metadata, search/browse UI.

| F-ID | Slug | Status |
|---|---|---|
| F-119 | local-marketplace | ⚪ PLANNED |
| F-120 | marketplace-metadata | ⚪ PLANNED |
| F-121 | marketplace-search-ui | ⚪ PLANNED |

### NEW from research (foundational-plan §"Plus 5 NEW F-NNN candidates")

⚪ PLANNED — added during loop iter-1..4 frontier research; allocated to existing milestones.

| F-ID | Slug | Target milestone | Status | Source |
|---|---|---|---|---|
| F-122 | a2a-endpoint-exposure | M4 | ⚪ PLANNED | `[R:WorkIQ + msft-learn finding 10]` |
| F-123 | otel-genai-spans | M16 | ⚪ PLANNED | `[R:msft-learn Foundry observability]` |
| F-124 | multi-tier-routing-haiku-opus | M1 | ⚪ PLANNED | `[R:WebSearch frontier 2026 architecture]` |
| F-125 | mcp-tool-cap-per-workspace | M7 | ⚪ PLANNED | `[R:WorkIQ internal tool-explosion lesson]` |
| F-126 | context-budget-allocation | M8 | ⚪ PLANNED | `[R:WebSearch frontier 2026]` |

### M19 — Deferred / out-of-scope (tracking only)

⏸ DEFERRED — explicitly out of v1 per user-acknowledged scope. Re-open trigger: see `docs/10-backlog/`.

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
- M18 closes v1 with local marketplace; cloud variant deferred to M19.

## Source

- Generated by **wave-3 / Lane D** (this commit).
- Authoritative source for per-feature behavior contracts: `docs/03-feature-catalog/Mn-*/F-NNN-*.md` ledgers.
- Authoritative source for milestones + scope: `docs/01-requirements/foundational-plan.md` § "True Synthesis → Feature catalog".
- Wave history: `docs/11-loop-state/wave-history/`.
- Dependency graph derived from foundational-plan dependency cues + Lane C (clawpilot/openclaw) lessons L1..L15 ordering hints.
