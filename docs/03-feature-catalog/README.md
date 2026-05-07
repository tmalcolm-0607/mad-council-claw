# 03 — Feature catalog

Complete enumeration of every feature across milestones M0..M19 — ~125 F-NNN identifiers plus the F-D-NNN deferred set, plus 5 new F-NNN candidates from frontier research and 3 new F-D-NNN deferreds.

## Catalog index (populated incrementally — wave-by-wave)

| Milestone | Span | File | Focus |
|---|---|---|---|
| M0 | F-001..F-008 | `M0-bootstrap.md` | engine kernel, identity, scaffolding, vitest+playwright, deps, logging, IPC contract, storage layout |
| M1 | F-009..F-013 | `M1-backend.md` | IBackendProvider, Anthropic SDK, Copilot SDK, factory, event normalization |
| M2 | F-014..F-022 | `M2-governance-triad.md` | pre-close signal, hash-audit, query-audit, PII redaction, halt, cost ledger, kill-switch, degradation, tool-quota |
| M3 | F-023..F-027 | `M3-cron-heartbeat.md` | heartbeat, skip-on-overlap, idle archive, resume-checkpoint, manual halt |
| M4 | F-028..F-031 | `M4-headless-cli.md` | cli entry, subcommands, JSON output, daemon mode |
| M5 | F-032..F-043 | `M5-desktop-shell.md` | window, history, info-panel, model picker, personality, system message, primitives, theming, shortcuts, menu, notifications, multi-window |
| M6 | F-044..F-050 | `M6-mcp-tools.md` | bridge, lifecycle, reconnect+health, tool-call audit, streaming, BYO-MCP, registry persist |
| M7 | F-051..F-066 | `M7-skills-perms-auto.md` | SKILL.md, bundled, toggle, custom-load, allowlist, version-pin, expiry, 3-tier perms, rules, audit, automations base + cron + condition + multistep + persist + shell-visible |
| M8 | F-067..F-075 | `M8-settings-persistence.md` | shape, UI, per-automation rules, encrypted storage, key-mgmt, encrypted import/export, project workspace, switcher UI, persistence |
| M9 | F-076..F-081 | `M9-m365.md` | MSAL, WAM, auth screen, token refresh, WorkIQ adapter, rate-limit+CB |
| M10 | F-082..F-087 | `M10-multi-model.md` | --council dispatch, agreement table, both-flag-CRITICAL block, fallback, consent gate, 5 high-blast-radius wired |
| M11 | F-088..F-092 | `M11-soul-introspect-replay.md` | soul boundary, schema, snapshot, signal pairs, deterministic replay |
| M12 | F-093..F-095 | `M12-visualization.md` | timeline UI, replay scrubber, filtering |
| M13 | F-096..F-100 | `M13-multimodal.md` | voice STT, engine selection, activation modes, screenshot-to-prompt, image preprocessing |
| M14 | F-101..F-103 | `M14-productivity.md` | daily briefing, schedule, destination |
| M15 | F-104..F-109 | `M15-build-packaging.md` | electron-builder, auto-update, branding, code signing, CI, CLI binary |
| M16 | F-110..F-113 | `M16-telemetry.md` | local OTel, crash reporting, perf metrics, opt-in/out |
| M17 | F-114..F-118 | `M17-docs.md` | README+quickstart, architecture docs, skill guide, MCP guide, automation cookbook |
| M18 | F-119..F-121 | `M18-marketplace.md` | local marketplace, metadata, search/browse UI |
| M19 | F-D-001..F-D-018 | `deferred.md` | 18 deferred items |
| - | F-122..F-126 | `new-from-research.md` | a2a-endpoint-exposure, otel-genai-spans, multi-tier-routing, mcp-tool-cap, context-budget |

## Per-feature ledger contract (every F-NNN MUST have)

Per Goals G1, G6, G27, G28:

- Behavior contract (one paragraph)
- Acceptance scenarios (Given/When/Then)
- RED test on day 0 (failing test exists)
- Status: RED | GREEN | LOCKED
- Source citations: `[V:N]` / `[R:topic]` / `[K:path]` / `[CP:path]` / `[CE:path]` / `[A:filename]` / `[NEW]`

Schema and lifecycle: `docs/03-feature-catalog/_schema.md` (to be written in M0 wave).
