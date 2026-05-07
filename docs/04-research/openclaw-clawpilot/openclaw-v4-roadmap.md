---
title: OpenClaw v4.0 roadmap (2026)
wave: wave-001
lane: lane-c
topic: 4/6
source-tag: "[R:openclaw-external]"
generated-by: lane-c-research
generated-by-version: 0.1.0
date: 2026-05-06
status: preview
---

# OpenClaw v4.0 roadmap (2026)

> Sources:
> - https://remoteopenclaw.com/blog/openclaw-development-roadmap-2026 (mid-2026 v4.0 target)
> - https://skywork.ai/skypage/en/openclaw-status-analysis-trends/2049105001462431745 (status + Q-by-Q breakdown)
> - https://github.com/openclaw/openclaw/releases (release history)
>
> Fetched 2026-05-06 via WebFetch.

## Project status (Q1 2026)

| Dimension | Value | Source confidence |
|---|---|---|
| GitHub stars | 346,000 (April 2026) | HIGH (Skywork) |
| Maintainership | Founder Peter Steinberger; moved to OpenAI February 2026 | HIGH (Skywork) |
| Architecture | Vision-based autonomous agent (screenshot analysis + LLM for GUI control) | HIGH (Skywork) |
| Core capability | Executes tasks via messaging platforms (WhatsApp, Telegram, Discord, Slack, Teams, LINE, Matrix, Feishu, Slack/Block-Kit) | HIGH (Skywork + release notes) |
| ClawHub marketplace | 164+ curated skills | HIGH (Skywork) |
| Plugin risk record | "ClawHavoc": ~12% of skills contained malicious payloads | HIGH (Skywork) — major informant for governance triad lessons |
| Enterprise readiness | Awareness 85% / Experimentation 60% / Production-ready 15% | HIGH (Skywork) |
| Release cadence | Rolling, minor versions every 2-3 weeks | HIGH (Remote OpenClaw blog) |

## Disclosed CVEs (Q1 2026)

| CVE | Severity | Class | Date |
|---|---|---|---|
| CVE-2026-25253 | 9.90 | Privilege escalation | Q1 2026 |
| CVE-2026-32922 | 8.80 | Cross-site WebSocket hijacking | Q1 2026 |
| CVE-2026-22179 | (unstated) | macOS command-substitution bypass | Q1 2026 |

> Exposure footprint: "over 135,000 instances globally." (Skywork)
>
> **Implication for new engine**: cross-site WebSocket hijacking is an Electron-relevant attack class. The new engine's WebSocket / IPC bridge needs explicit origin allowlisting + cert pinning (Clawpilot does both via `cert-pins.ts` — port that).

## v4.0 roadmap (mid-2026 target)

### Five confirmed tracks (Remote OpenClaw blog)

1. **Multi-agent orchestration** — running multiple agents that coordinate with each other.
2. **Plugin SDK v2** — typed, testable contract system for skills + integrations.
3. **Built-in vector memory** — native ChromaDB support for long-term recall (no external RAG plumbing required).
4. **Web dashboard** — browser-based interface for managing agents without touching config files.
5. **Enterprise integrations** — first-class Microsoft Teams, Salesforce, SSO/SAML for the dashboard, structured audit logging.

> Quote: "The major milestone release is expected in mid-2026 and will include the new plugin SDK, multi-agent orchestration, and the redesigned dashboard."

### Quarterly breakdown (Skywork)

| Quarter | Initiative | Status |
|---|---|---|
| Q1 2026 | Stability improvements | Complete |
| Q2 2026 | Enterprise SSO integration | In progress |
| Q3 2026 | Native mobile companion app | Planned |
| Q4 2026 | Mass-market expansion | Future |

### H2 2026 specific (Skywork)

- Enterprise SSO integration (production-ready)
- Vetted, formal marketplace for plugins (post-ClawHavoc reform)
- Mobile app to replace third-party chat dependencies (no-more-Telegram-as-UI)
- Foundation governance model transition (project moves from solo-maintainer to foundation)

### Multi-agent orchestration shape (Skywork)

> "Configure an `openclaw.json` file to route coding tasks to a GPT-4o agent and research tasks to a Gemini Flash agent."

- Per-task routing via config file
- No native orchestration in-process today (per issue #43367); v4.0 adds it
- Implementation details still emerging

### Notable absences (Remote OpenClaw blog)

The blog explicitly does NOT mention:
- Formal marketplace launch date
- Native mobile companion app launch date (Skywork lists Q3, blog stays silent)
- H1/H2 specific feature breakdowns

> Confidence: MEDIUM on the H1/H2 split — the two sources slightly diverge.

## Recent release evidence (v2026.5.x — May 2026)

From `https://github.com/openclaw/openclaw/releases`:

### v2026.5.6 (2026-05-06)

- Reverted OAuth routing changes that could break GPT-5.5 setups
- Fixed plugin fetch requests by dropping third-party symbol metadata
- Normalized debug-proxy header dictionaries for request replay
- Bounded guarded-dispatcher cleanup after fetch timeouts

### v2026.5.5 (2026-05-06)

- Feishu: hydrate missing native topic-starter thread IDs before session routing
- LINE webhook validation rejects open DM policies without wildcard `allowFrom`
- Telegram/Codex progress drafts render native tool progress correctly
- xAI Grok models no longer receive unsupported reasoning-effort controls
- Matrix approval delivery retries up to 3 times with backoff

### v2026.5.4 (2026-05-05)

- Google Meet Twilio joins use realtime Gemini voice bridge with paced audio streaming + backpressure
- Windows gateway listener bound to `127.0.0.1` only (prevent IPv6 dual-stack issues)
- Plugin migration emits install hints for missing official external plugins
- Control UI shows active agent name in breadcrumbs; cron sidebar collapsible
- Slack streaming adds rich Block-Kit progress drafts with structured data

### v2026.5.4-beta releases (2026-05-04 to 05)

- File-transfer plugin with binary file ops (`file_fetch`, `dir_list`, `file_write`)
- Default-deny path policies + 16 MB per-round-trip ceiling
- `/steer` command for queue-independent session steering

## Implications for the new engine

| Lesson from v4.0 plans | Engine design rule | Confidence |
|---|---|---|
| **Native multi-agent orchestration is being added as a core differentiator** — competitors will catch up; the new engine's `mad-council` orchestration must be production-grade from day 1, not an afterthought | Validate `mad.council.a2a.md` against issue #43367's failure modes; write evals for F1-F4 classes | HIGH |
| **Plugin SDK v2 is "typed, testable contract system"** — matches Clawpilot's `ipc-contract.ts` pattern + `bundled-skills/` zip-manifest tested format | Adopt typed-contract-first for any skill / MCP / extension surface | HIGH |
| **Built-in vector memory (ChromaDB) is being added** — Clawpilot uses Loki Memora; the kit needs a portable vector-memory abstraction so the engine can swap (Loki / Chroma / sqlite-vec / etc.) | `IMemoryProvider` abstraction (mirror Clawpilot's `IBackendProvider` pattern); Memora as default; allow alternates | HIGH |
| **Web dashboard separate from desktop UI** — Clawpilot is desktop-only; the new engine's "Both: desktop AND headless" requirement matches | Ship a thin web dashboard for headless mode (read-only initially) | HIGH |
| **Enterprise SSO + SAML for the dashboard** — Clawpilot's MSAL + WAM is the desktop story; web dashboard needs a separate auth path | Use MSAL SPA flow for web dashboard with SAML federation; share token cache where possible | HIGH |
| **Formal marketplace coming with vetting** — ClawHavoc (12% malicious) is the cautionary tale | Hash-audit at install time (governance triad item) + signature verification + per-skill capability declarations | HIGH |
| **Foundation governance transition** — solo-maintainer → foundation is a sustainability lesson | The new engine's MAD.Council single-owner-accountability rule should consider transition paths from individual to org owners | MEDIUM |
| **Mobile companion is a Q3 2026 thing** — out of scope for v1 of the new engine | Defer mobile to v1.5+ explicitly — but keep IPC contract serializable enough that a thin-client mobile UI is feasible later (no special tooling) | MEDIUM |
| **`/steer` queue-independent steering command** is a UX wedge | The new engine's chat surface should support out-of-band steering (interrupt the queued message stream and inject a steer) | MEDIUM |
| **Default-deny path policies + per-roundtrip size ceiling** for file-transfer plugin | Match this default in the new engine's filesystem MCP wrapper | HIGH |

## Findings explicitly marked "no findings"

- **No specific OpenClaw API surface area for the multi-agent orchestrator** — the spec is at the conceptual level only as of fetched date.
- **No public mention of OpenClaw adopting MCP** — they appear to be on a custom plugin SDK trajectory; the new engine's MCP-first stance is differentiated.
- **No published vector-memory format** for OpenClaw's ChromaDB integration — implementation detail still TBD.

---

**Lane C topic 4/6 complete.** Next: OpenClaw recent releases (deeper).
