---
title: OpenClaw recent releases (2026.5.x)
wave: wave-001
lane: lane-c
topic: 5/6
source-tag: "[R:openclaw-external]"
generated-by: lane-c-research
generated-by-version: 0.1.0
date: 2026-05-06
status: preview
---

# OpenClaw recent releases (2026.5.x)

> Source: https://github.com/openclaw/openclaw/releases (fetched 2026-05-06 via WebFetch). Coverage: most recent ~10 releases.

## v2026.5.6 (2026-05-06)

| Change | Class | Lesson for new engine |
|---|---|---|
| Reverted OAuth routing changes that could break GPT-5.5 setups | Bug regression | Treat model-vendor compatibility as a release-gate criterion (have a per-vendor smoke-test in the eval suite) |
| Fixed plugin fetch requests by dropping third-party symbol metadata | Security/privacy | Don't leak third-party metadata in outbound HTTP; sanitize at the wire boundary |
| Normalized debug-proxy header dictionaries for request replay | Operability | Debug-replay infra is real; ours should match (record + replay HTTP for repro) |
| Bounded guarded-dispatcher cleanup after fetch timeouts | Stability | Match: every IPC/HTTP path has a timeout + bounded cleanup |

## v2026.5.5 (2026-05-06)

| Change | Class | Lesson |
|---|---|---|
| Feishu: hydrate missing native topic-starter thread IDs before session routing | Multi-platform UX | Threading metadata is per-platform; abstract before routing |
| LINE webhook validation rejects open DM policies without wildcard `allowFrom` | Security default | Default-deny on platform DM policies; require explicit allowlist |
| Telegram/Codex progress drafts render native tool progress correctly | UX | Per-platform progress-rendering matters; abstract `progress` event from per-platform render |
| xAI Grok models no longer receive unsupported reasoning-effort controls | Model adapter | Per-model capability negotiation (don't send fields the model doesn't accept) |
| Matrix approval delivery retries up to 3 times with backoff | Reliability | Match: every approval-delivery path has bounded retry with backoff |

## v2026.5.4 (2026-05-05)

| Change | Class | Lesson |
|---|---|---|
| Google Meet Twilio joins use realtime Gemini voice bridge with paced audio + backpressure | Voice / multimodal | Backpressure matters for streaming voice; the new engine's voice path needs explicit backpressure semantics (not "drop") |
| Windows gateway listener bound to `127.0.0.1` only (no IPv6 dual-stack) | Security | Match: bind to `127.0.0.1` explicitly; IPv6 dual-stack widens attack surface (`::1` accepts more sources) |
| Plugin migration emits install hints for missing official external plugins | Operability | When a skill/MCP referenced in config isn't installed, surface "install hint" rather than silent failure |
| Control UI shows active agent name in breadcrumbs | UX | Agent identity must be visible in the UI at all times when multi-agent is active |
| Cron sidebar collapsible | UX | Long lists need progressive-disclosure |
| Slack streaming adds rich Block-Kit progress drafts with structured data | UX / platform integration | Per-platform rich content; not just plain text |

## v2026.5.4-beta cycle (2026-05-04 to 2026-05-05)

| Change | Class | Lesson |
|---|---|---|
| File-transfer plugin: `file_fetch`, `dir_list`, `file_write` | Capability | Match: filesystem operations are first-class plugin operations |
| Default-deny path policies | Security default | **Default-deny is the right default** — file-transfer plugin requires explicit allow rules |
| 16 MB per-round-trip ceiling | Operability | Hard size cap on file-transfer round-trips; the new engine's file ops must have a similar ceiling |
| `/steer` command for queue-independent session steering | UX | Out-of-band steering interrupts the queued stream; new engine's chat surface should support similar |

## Cross-release patterns

| Pattern | Frequency | Lesson |
|---|---|---|
| Per-platform integrations need per-platform fixes | High (Feishu / LINE / Telegram / Slack / Matrix / Google Meet — every release touches one) | Build a per-platform abstraction layer that minimizes per-platform code paths; centralize threading / progress / approval / DM policies |
| OAuth routing is fragile | Multiple regressions across releases | OAuth must have versioned tests per provider, run on every release |
| Guarded dispatcher cleanup keeps surfacing | Multiple cleanup fixes | Lifecycle ownership matters; every dispatcher/handler that has setup must have explicit teardown + a watchdog |
| Plugin install hints | New surface | When config references missing plugins, the install hint is the recovery surface |
| Default-deny is the new default | New surface (file-transfer) | Apply default-deny everywhere new capabilities appear |

## Unreleased / signaled (per release-note prose)

- v2026.6.x is implied to land within ~2-3 weeks per the documented rolling cadence.
- v4.0 milestone target: mid-2026 (roadmap doc).

## Comparison: OpenClaw release velocity vs Clawpilot

| Repo | Cadence | Recent versions in last ~30 days |
|---|---|---|
| OpenClaw | Rolling, every 2-3 weeks; many beta intermediates | 6+ in May 2026 alone (5.4-beta cycle + 5.4 + 5.5 + 5.6) |
| Clawpilot (m-main) | Weekly chore-bumps from v0.22.43 to v0.22.66 over recent commits | ~24 chore-bumps; semantic = ~24 release cuts |

**Confidence: HIGH** — both ship aggressively. The new engine should plan for the same cadence + the same beta-channel discipline (Clawpilot already has `release:cut-beta` + `release:promote` scripts).

## Findings explicitly marked "no findings"

- **No release notes for v3.x** in the fetched window — the recent stream is all v2026.5.x date-versioned. v4.0 is the next named milestone.
- **No release notes published for the issue #43367 fix series** — the linked issues #42160 / #32799 / #26322 may have fix landings but were not enumerated.
- **No published Microsoft Teams release** in the v2026.5.x window — Teams is on the v4.0 roadmap (mid-2026), still unshipped.

---

**Lane C topic 5/6 complete.** Next: cross-cutting lessons.
