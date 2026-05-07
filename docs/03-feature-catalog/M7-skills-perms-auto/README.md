---
artifact-class: milestone-overview
generated-by: hand-authored (wave-004 / lane-b)
status: red
milestone: M7
short-slug: skills-perms-auto
features: F-051..F-066, F-125
authored: 2026-05-06
---

# M7 — Skills + Permissions + Automations

The extensibility plane (`foundational-plan.md` § Architecture, V:8 + § Tool plane). M7 turns the engine from a fixed-feature chat shell into an extensible runtime: third-party (and first-party) capability is added via Skills (loaded SKILL.md bodies), governed by 3-tier Permissions (ALLOW / ASK / DENY with rules + audit), and triggered automatically via Automations (cron + condition + multistep chains). M7 is the layer where canonical-e US-6 ("allowlist + pinning") meets clawpilot's lived patterns (`electron/skills.ts` 766 LOC, `electron/permission-policy.ts` 1,331 LOC, `electron/automations/` directory). The three groups are adjacent but logically distinct; this README documents the shared dependency DAG.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-051 | skills-skill-md | SKILL.md format + YAML frontmatter; Zod-validated; ≤500-line body warning |
| F-052 | skills-bundled-installation | Bundled-skills initializer with idempotent skip + first-party-override precedence |
| F-053 | skills-toggle-per-session | Per-session enable/disable; atomic per-session toggle file; mid-run semantics |
| F-054 | skills-custom-loading | Workspace + user-global + bundled priority; path-traversal rejection; sanitization uniform |
| F-055 | skills-allowlist | Org > user policy tiers; deny-default fail-closed; canonical-e US-6 substrate |
| F-056 | skills-version-pinning | Deterministic sha256 over canonicalized SKILL.md + references; cross-platform |
| F-057 | skills-pin-expiry | ISO-8601 expiry; 7-day warning; fail-closed past expiry |
| F-058 | permissions-3tier | ALLOW / ASK / DENY classifier; default-to-ASK; org > user precedence |
| F-059 | permissions-rules | Exact > prefix > regex precedence; ReDoS-rejected patterns; shell-aware splitting |
| F-060 | permissions-audit | Hash-chained per-decision entries; PII-redacted args; ASK-latency captured |
| F-061 | automations-base | Manager + Zod schemas + run-now + atomic store + history.jsonl |
| F-062 | automations-cron-type | Cron-expression-triggered; F-023 heartbeat-driven; duplicate + overlap rejected |
| F-063 | automations-condition-type | file-watch + event-bus + idle conditions; 5s debounce; coalesced events |
| F-064 | automations-multistep | Sequential steps; output-interpolation; halt-vs-continue; per-step checkpoint |
| F-065 | automations-persistence | Validate-on-load; quarantine invalid; resume-from-checkpoint; 100-run history rotation |
| F-066 | automations-results-in-shell | RUN_COMPLETED IPC; inline render; per-automation perm decisions auditable |
| F-125 | mcp-tool-cap-per-workspace | Per-workspace cap on MCP-surfaced tools (default 10 per foundational-plan; D-3 OPEN); user picks subset when over cap; no silent truncation (NEW from frontier research) |

## Dependency DAG

```
External M0/M1/M2 dependencies:
F-001 (engine kernel) ──→ F-051, F-053, F-054, F-058, F-061, F-063
F-007 (IPC contract)  ──→ F-051, F-058, F-061, F-066
F-008 (storage layout) ──→ F-052, F-053, F-061, F-065
F-015 (hash-audit)    ──→ F-060
F-018 (halt event)    ──→ F-063 (event-bus condition)
F-023 (cron heartbeat) ──→ F-062
F-024 (skip-on-overlap) ──→ F-062
F-032 (window) + F-042 (notifications) ──→ F-066
F-104 (electron-builder) ──→ F-052 (packaging bundled-skills/)

Skills group internal:
F-051 (SKILL.md) ──→ F-052 (bundled), F-053 (toggle), F-054 (custom-load), F-055 (allowlist), F-056 (pin)
F-052 (bundled)  ──→ F-053, F-055, F-056
F-054 (custom-load) ──→ F-055
F-055 (allowlist) ──→ F-056 (pin field), F-057 (expiry field)
F-056 (pin)       ──→ F-057

Permissions group internal:
F-058 (3-tier) ──→ F-059 (rules), F-060 (audit)
F-059 (rules)  ──→ F-060

Automations group internal:
F-061 (base)        ──→ F-062, F-063, F-064, F-065, F-066
F-064 (multistep)   ──→ F-065 (checkpoint shape)
F-061 + F-064 + F-032 + F-042 + F-065 ──→ F-066

Cross-group:
F-058 (3-tier)  ──→ each step in F-061..F-066 classifies through here
F-066 (results) ──→ F-058 + F-059 (per-automation perm scope) + F-060 (audit cross-ref)
F-051 (skills)  ──→ F-061 step type "skill-invoke"
```

## Milestone exit criteria

- All 16 ledgers GREEN
- A SKILL.md with valid frontmatter + ≤500-line body registers cleanly; one with name "claude-helper" rejects
- Bundled installer runs idempotently across two cold starts (no duplicate install events)
- Per-session toggle persists via atomic write + survives renderer crash
- Custom-load resolves workspace > user-global > bundled in that order; path-traversal rejected
- Allowlist with deny-default fails-closed when missing
- sha256 pin computed on Windows + Linux is bit-identical for the same SKILL.md
- Pin past `expires_utc` rejects with `SKILL_PIN_EXPIRED` and 7-day warning fires once per session
- 3-tier classifier returns stable result for repeat calls in same run
- Permission rule precedence (exact > prefix > regex) verified with synthetic rules; ReDoS pattern rejected
- Permission-audit chain validates clean; tampered entry breaks chain detectably
- Automation manager creates + lists + runs-now + persists + rotates history
- Cron-type fires on schedule + skip-on-overlap recorded
- Condition-type debounce coalesces 50 file-modifies into 1 run
- Multistep chain interpolates `${steps.<id>.output}` correctly; halt-on-failure stops downstream
- Run-completed event renders in shell with permission_decisions array attached + audit cross-ref intact

## Out of scope (per `rules/no-silent-deferrals.md`)

- Skill marketplace browse/search/install UI → M18 (F-119..F-121)
- Pair-programming-mode (Claude-A-helps-Claude-B-iterate per Anthropic Skills authoring) → NEW F-NNN candidate; not yet authored as a ledger
- Frontmatter-contract enforcement hook → NEW F-NNN candidate from `anthropic-skills-authoring.md`; pre-tool-use Write hook that validates SKILL.md before persistence; not authored
- Reference-depth audit (>1 level deep) → NEW F-NNN candidate; not authored
- Evals-first scaffold (`/skill-create` shape) → NEW F-NNN candidate; not authored
- Skill-conciseness audit (token-cost-vs-information-value scan) → NEW F-NNN candidate; not authored
- MCP tool-name validation (`ServerName:tool_name` format) → NEW F-NNN candidate; not authored
- F-125 mcp-tool-cap-per-workspace (M7 NEW from frontier research) — ledger authored wave-012/lane-c (RED); D-3 closure (default cap value of 10) pending before flip to GREEN
- Calendar-aware permissions (time-window-bounded grants) → v1.5
- Quad-state permission expansion (ALLOW_BOUNDED, etc.) → v1.5
- Encrypted-at-rest skill / automation storage → M8 (F-070)
- Network-fetched skills (URL/registry-loaded) → out of scope for v1
- Cryptographic signing of skill bundles (PGP / sigstore) → out of scope for v1; sha256 is the v1 substrate
- Multiple-pinned-versions-side-by-side support → v1.5
- Timezone-aware cron → v1.5; v1 is local-system-time
- Parallel-step execution within a chain → v1.5; v1 is sequential
- Loops + pipes step-kinds → v1.5
- External webhook trigger (HTTP POST from outside) → out of scope; future F-NNN
- GitHub-import of automations (`GithubImportView.tsx` reference) → deferred; bundled here as future capability flag
- Remote backup of automation persistence → out of scope for v1

## Provenance

`foundational-plan.md` § True Synthesis Feature catalog table M7 row + § Architecture (Tool plane: MCP servers + Skills, strict auth + rate limits + tool-cap per workspace), `cp:bundled-skills/`, `cp:first-party-skills/`, `cp:skills/`, `cp:electron/skills.ts` (766 LOC), `cp:common/skill-sanitization.ts`, `cp:electron/yaml-utils.ts`, `cp:electron/permission-policy.ts` (1,331 LOC), `cp:electron/permission-classifier.ts`, `cp:electron/permission-classifier-types.ts`, `cp:electron/permission-patterns.ts`, `cp:electron/permission-pattern-guardrails.ts`, `cp:electron/permission-shell-syntax.ts`, `cp:electron/permissions.ts`, `cp:electron/permissions-calendar.ts`, `cp:common/permission-servers.ts`, `cp:src/features/permissions/{PermissionsPanel,PermissionsEditor,PermissionsSummary,ShellPatternsSection,ToolGroupSection,useToolRegistry,permissions-format}.tsx`, `cp:electron/automations/{manager,schedule,condition-monitor,triggering,store,schemas,types}.ts` (all test-covered), `cp:electron/automations.ts`, `cp:electron/ipc/{automations-ipc,automations-desktop-ipc}.ts`, `cp:src/features/automations/{AutomationsPanel,AutomationListView,AutomationFormView,AutomationHistoryView,AutomationDeleteDialog,AutomationOverflowMenu,GithubImportView}.tsx`, `cp:scripts/install-skills.mjs`, `cp:scripts/initialize-bundled-skills.mjs`, `ce:US-6` (allowlist + pinning), `ce:FR-AUDIT-001/002` (hash-chain + tamper-detection), `kit:rules/{skill-standards,canonical-skill-only,dangerous-operations-policy,concurrency-safety,verification-protocol,loop-cadence-discipline,anomaly-thresholds,_status-convention,orchestration,degradation-fallback-policy,resume-protocol}.md`, `kit:docs/04-research/frontier-2026/anthropic-skills-authoring.md` (F-051..F-054 frontmatter + sanitization + custom-load discipline). Per-ledger `provenance.surfaces`.
