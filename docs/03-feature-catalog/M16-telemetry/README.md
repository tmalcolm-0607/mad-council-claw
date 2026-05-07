---
artifact-class: milestone-overview
generated-by: hand-authored (wave-007 / lane-a)
status: red
milestone: M16
short-slug: telemetry
features: F-110..F-113
authored: 2026-05-06
---

# M16 — Telemetry

The engine's observability plane. Local-first by default per foundational-plan D-1: an OpenTelemetry-compatible JSONL sink under `<userData>/telemetry/`, crash capture via Electron's native crash reporter, a fixed set of performance metrics covering LLM calls / MCP tool latency / engine-cycle / process resources, and a single tri-state opt-in (`off` / `local-only` / `remote`) that gates ALL emission and export. Remote export is opt-in only, gated by Dangerous Operation consent, and audited per F-015.

This milestone consumes M0 (kernel, storage, identity) and M2 (audit-log, PII redaction) and produces the on-disk forensic record that every other milestone relies on for debuggability. It is the load-bearing surface for "engine ships observable by default but private by default" — the inverse of the SaaS-telemetry default.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-110 | local-telemetry | Default OpenTelemetry-compatible local-file sink at `<userData>/telemetry/otel-{date}.jsonl`; zero network egress in default mode |
| F-111 | crash-reporting | Electron `crashReporter` wired to local dump dir; crash records to F-110's sink; previous-run-crashed event on next boot |
| F-112 | performance-metrics | LLM latency histograms + token counters + MCP tool latency + engine-cycle phases + RSS/CPU resource samples; OTel GenAI semantic conventions |
| F-113 | telemetry-opt-in | Tri-state `off` / `local-only` (default) / `remote`; remote-mode = Dangerous Operation; transitions audited per F-015 |

## Dependency DAG

```
M0 (F-001 kernel, F-002 identity, F-006 logger, F-008 storage) ──→ all M16 features

F-113 (opt-in mode)  ──→ F-110 (sink listens to mode)
                     ├──→ F-111 (off mode disables crash disk writes; in-memory only)
                     └──→ F-112 (off mode disables metric emission)

F-110 (sink)         ──→ F-111 (shared JSONL sink for crash records)
                     └──→ F-112 (shared sink for metric records)

F-018 PII redaction  ──→ F-110 (redacts logs before write)
                     └──→ F-111 (redacts crash payloads before write)

F-015 audit-log      ──→ F-113 (mode transitions audited with session_id)
F-067 M8 settings    ──→ F-113 (UI surface for mode tri-state)
```

## Milestone exit criteria

- All 4 ledgers GREEN
- A 60-second engine run in `local-only` mode produces a parseable OTel JSONL file with logs + metrics + traces and ZERO outbound network connections from the telemetry subsystem
- An induced renderer crash on macOS / Windows / Linux produces a local crash dump and a crash-event JSONL record on next boot
- Performance metrics include LLM latency histogram, token-usage counter, MCP tool histogram, engine-cycle histogram, and resource gauges sampled at 30s cadence
- Mode transition `local-only → remote` triggers a consent prompt with signal preview, awaits explicit "yes", and writes an audit-log entry with the actor's session_id
- `off` mode produces no telemetry disk writes; in-memory ring buffer is dropped on graceful shutdown
- PII redaction (per F-018) runs before every telemetry write; no redacted token reaches disk
- The engine MUST NOT invent sampling caps / bucket boundaries / quotas absent explicit user config (per `rules/no-invented-constraints.md`)

## Out of scope (tracked elsewhere)

- Live in-app telemetry dashboard / charts — M12 visualization owns telemetry-aware UI
- Aggregation across sessions — downstream concern at the OTel collector if user opts in
- Cost forecasting / anomaly detection on metrics — F-019 halt + F-020 cost ledger handle engine-level budgets
- Per-signal opt-in granularity (metrics on, traces off) — v1.5
- Per-tenant / per-channel telemetry opt-in — M2 governance owns channel-level concerns
- Remote crash upload (Sentry / Bugsnag / AppCenter / Crashpad-server) — v1.5; v1 ships local-dump-only
- Native frame symbolication — v1.5
- Auto-restart-on-crash — M5 desktop-shell concern
- User-facing "send report?" per-crash dialog — v1 has single global opt-in via F-113
- Custom user-defined metrics SDK — v1.5
- BYOK / customer-managed keys for local telemetry encryption — v1.5

## Provenance

`cp:src/main/logger`, `cp:src/services/telemetry`, `cp:src/main/crash-reporter`, `cp:src/services/llm/factory` (LLM-call timing surface), `cp:src/main/settings` + `cp:src/features/settings/SettingsScreen.tsx` (settings UI shape for opt-in tri-state), `cp:electron crashReporter API` (native crash capture), `kit:rules/lens-telemetry-pattern` (LENS QOS metrics + structured-log shape; informs OTel record naming for cross-LENS observability), `kit:rules/no-invented-constraints.md` (no sampling caps / quotas without explicit user config — F-110 / F-112), `kit:rules/anomaly-thresholds.md` (F-112 thresholds drive opt-in operator warnings only), `kit:rules/single-owner-accountability.md` (F-110 / F-113 session_id binding), `kit:rules/dangerous-operations-policy.md` (F-111 / F-113 remote upload + mode transition consent), `kit:rules/degradation-fallback-policy.md` (F-111 pre-identity-phase markers — degraded state named not silent), `kit:rules/no-silent-deferrals.md` (F-111 / F-113 absences explicit), `foundational-plan.md` D-1 (default OpenTelemetry-compatible local-file; remote opt-in only), `foundational-plan.md` M16 telemetry section. Per-ledger `provenance.surfaces`.
