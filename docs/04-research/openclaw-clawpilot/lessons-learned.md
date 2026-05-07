---
title: Cross-cutting lessons learned (Lane C synthesis)
wave: wave-001
lane: lane-c
topic: 6/6
source-tag: "[CP+R:synthesis]"
generated-by: lane-c-research
generated-by-version: 0.1.0
date: 2026-05-06
status: preview
---

# Cross-cutting lessons learned

> Synthesis of Lane C topics 1-5. Every lesson cites the originating finding.

## L1 — Per-agent isolation must be filesystem-real, not synthetic

**Source**: openclaw-issue-43367.md F2 (session lock timeouts on isolated agents).
**Confidence**: HIGH.

OpenClaw's failure: monolithic JSON for session state with a global lock means parallel agents contend even when "isolated." The new engine MUST use one file per session (Clawpilot already does — `~/.copilot/m-sessions/{id}.json`). MAD.Council `concurrency-safety.md` Rule 1 (append-only messages) + Rule 2 (atomic write per file) already enforce this for council artifacts; we must ensure the *agent* layer follows the same discipline.

**Engine rule**: per-agent state lives in `<state-dir>/agents/<agent-id>/{session,locks,auth-cache,memory}/` — no shared mutable file across agents.

## L2 — One auth identity (refresh token) per agent role

**Source**: openclaw-issue-43367.md F3 (OAuth refresh-token reuse race) + clawpilot-architecture.md §11 (MSAL + WAM + per-tenant policy).
**Confidence**: HIGH.

OpenClaw's failure: shared refresh token + concurrent refresh = `refresh_token_reused` from OpenAI; provider may revoke entirely. Clawpilot's design is single-user-tenant-scoped, so this hasn't surfaced — but the new engine's multi-agent (Advocate/Skeptic/Architect) shape means multiple in-flight requests to the same provider from "the same user." The fix is to scope refresh tokens to a *role*, not a user.

**Engine rule**: each agent role gets its own MSAL cache file (`<state-dir>/agents/<role>/msal-cache.enc`). Even if all roles are the same logged-in user, no two agents share a token-refresh code path.

## L3 — Parent-child supervision contract for spawned agents

**Source**: openclaw-issue-43367.md F4 (detached background processes after CLI failure).
**Confidence**: HIGH.

OpenClaw's failure: child agent processes survive parent CLI death. The fix is two-part: (a) parent registers children in a known directory (`<state-dir>/children/<child-id>/{pid,started_utc,parent_pid}.json`); (b) on parent startup, sweep the directory and reap orphans. Use OS-level `flock(2)` / `LockFileEx` (released by OS on process death) instead of pidfile-based locks.

**Engine rule**: `IChildAgentRegistry` writes to `<state-dir>/children/`; orchestrator startup reaps any orphan with no live PID. Locks are OS-level, not pidfile-based.

## L4 — Single source of truth for IPC contracts (lift Clawpilot's `ipc-contract.ts` pattern verbatim)

**Source**: clawpilot-architecture.md §5 (`common/ipc-contract.ts` 2,075 LOC) + openclaw-v4-roadmap.md "Plugin SDK v2 — typed, testable contract system."
**Confidence**: HIGH.

Clawpilot's `ipc-contract.ts` is the SINGLE FILE that defines every IPC handler signature, every event payload, every namespace API interface. The result: adding an IPC handler requires touching one source-of-truth file before any handler/preload/E2E code. OpenClaw's v4.0 plan validates this approach ("typed, testable contract system").

**Engine rule**: `common/ipc-contract.ts` (or equivalent) is the canonical IPC contract. Extending IPC requires editing this file FIRST. A pre-commit hook can fail builds when handler/preload code references an undeclared method.

## L5 — Default-deny is the right default for every new capability

**Source**: openclaw-recent-releases.md v2026.5.4-beta (file-transfer plugin: default-deny path policies, 16 MB ceiling) + clawpilot-architecture.md §12 (3-tier permission engine: auto-approve / prompt / block) + openclaw-v4-roadmap.md ClawHavoc (~12% malicious skills).
**Confidence**: HIGH.

ClawHavoc proved that opt-in plugin trust scales badly. OpenClaw's most recent default-deny work + Clawpilot's 3-tier permission engine + the existing kit's `dangerous-operations-policy.md` all converge on: default-deny at every capability boundary. Default-deny applies to filesystem ops (allowed paths whitelist), network ops (allowed hosts whitelist), shell commands (read-only allowlist + prompt for writes + block for dangerous), and skill invocation (per-skill capability declarations enforced at install time).

**Engine rule**: every new capability surface starts default-deny + per-capability allowlist. Hash-audit at skill install time (governance triad). Cap on per-roundtrip data size (16 MB inspired). Per-platform DM policy default-deny (LINE-style fix).

## L6 — Backend abstraction with lint-enforced invariants (lift Clawpilot's `IBackendProvider` discipline)

**Source**: clawpilot-architecture.md §10 (5 invariants enforced by oxlint `no-restricted-imports`).
**Confidence**: HIGH.

Clawpilot's CLAUDE.md documents 5 invariants and enforces them via `oxlint no-restricted-imports`. Same pattern matches our needs: pluggable backend (Copilot SDK / Anthropic / Azure OpenAI / Gateway) behind `IBackendProvider`. The 5 rules are reusable verbatim:
1. Shared code must NOT import per-backend modules
2. `backend.origin` may be referenced for validation/visibility filter only, NOT to fork behavior
3. `ISessionBackend` may only declare methods implementable by ANY backend
4. Per-backend machinery lives in `backend/<name>/` or `backend/<name>-*.ts`
5. Composition root (`main.ts`) is exempt from rule 2

**Engine rule**: adopt the 5 rules verbatim; configure oxlint `no-restricted-imports` to enforce; backend selection happens at composition root only.

## L7 — Vector-memory abstraction with portable provider

**Source**: clawpilot-architecture.md §13 (Loki Memora behind experiment + shadowing-memora-store) + openclaw-v4-roadmap.md "Built-in vector memory (ChromaDB)."
**Confidence**: HIGH.

Both ecosystems are converging on built-in vector memory. Clawpilot's `shadowing-memora-store.ts` is the live migration shim (legacy → vector). OpenClaw is going to ChromaDB. Neither is universal. The new engine should ship `IMemoryProvider` abstraction with Memora as default + ChromaDB + sqlite-vec adapters.

**Engine rule**: `IMemoryProvider` interface in `common/`; Memora is default; abstraction lives behind a "shadow" period for migration safety (matches Clawpilot's pattern); experiment-flag-gated rollout (matches commit `71d515fa`).

## L8 — Per-platform integration is per-platform code; abstract the layers underneath

**Source**: openclaw-recent-releases.md cross-release patterns (Feishu / LINE / Telegram / Slack / Matrix / Google Meet — every release touches one) + clawpilot-architecture.md §15 (Teams relay, progress narrator, multi-fix saga).
**Confidence**: HIGH.

Both ecosystems pay a per-platform tax — Clawpilot's Teams relay had 10+ fixes in the recent 100 commits (lifecycle, narrator, suppression, WS routing). OpenClaw fixes Feishu / LINE / Telegram / Slack / Matrix in nearly every release. The lesson is NOT "avoid per-platform code" (impossible) but: abstract the layers underneath (threading / progress / approval / DM-policy / rendering) so that per-platform code is small and testable.

**Engine rule**: `IPlatformAdapter` interface with: `routeIncoming`, `renderProgress`, `deliverApproval`, `validateDmPolicy`, `getThreadId`. Per-platform code is one file per platform that implements the interface; shared code never branches on platform name.

## L9 — Bounded retry + circuit breaker at every IPC/HTTP/auth boundary

**Source**: openclaw-recent-releases.md v2026.5.5 (Matrix approval delivery retry 3x with backoff) + v2026.5.6 (bounded guarded-dispatcher cleanup) + the kit's existing `degradation-fallback-policy.md` Rule 4 + `circuit-breakers.md`.
**Confidence**: HIGH.

Pattern across both: retries are bounded (3 attempts, exponential backoff), timeouts are explicit, cleanup is bounded. The kit already has this in policy form. The new engine's job is to enforce it at every boundary — including auth-broker (lesson L2 prerequisite), MCP server spawning, IPC handlers (Clawpilot has `with-timeout.ts` + `ipc-limits.ts`), and per-platform message delivery.

**Engine rule**: every IPC handler has `withTimeout` wrapping; every HTTP outbound has bounded-retry-with-backoff; every dispatcher has explicit teardown + watchdog; every auth flow has bounded failover (no infinite vendor-fallback).

## L10 — Operator-visible state for everything that's running

**Source**: openclaw-issue-43367.md F4 (detached processes are invisible) + clawpilot-architecture.md §17 (heartbeat per session, busy-tracker, audit-log).
**Confidence**: HIGH.

OpenClaw's phantom-agent class proved that "running but invisible" is a bug class. Clawpilot already handles this (heartbeat per session, busy-tracker, append-only audit log, mini-mode visibility). The new engine should commit to: every spawned process / channel / agent has a visible-to-operator state file. Operator can `list`, `status`, `kill` from a single CLI.

**Engine rule**: `<state-dir>/agents/`, `<state-dir>/channels/`, `<state-dir>/automations/run-history/` all have human-readable state files. CLI surface (`mad-council list`, `mad-council status`, `mad-council kill`) reads from these. Append-only audit log per channel.

## L11 — Multi-agent orchestration must be production-grade from day 1, not bolted on

**Source**: openclaw-v4-roadmap.md ("multi-agent orchestration" is a v4.0 differentiator) + openclaw-issue-43367.md (current OpenClaw multi-agent is unstable) + the user's loop directive (the new engine's `mad-council` is the differentiator).
**Confidence**: HIGH.

OpenClaw is racing to add native multi-agent. Clawpilot's gateway/copilot dual-backend already handles two backends; the new engine's MAD.Council adversarial review (Advocate/Skeptic/Architect) is a *higher-order* multi-agent surface that needs to be right from day 1. Everything from L1-L10 is a prerequisite for this lesson.

**Engine rule**: `mad-council` orchestration is the central feature. Every other feature (sessions, automations, skills, MCP) must be designed to support 3+ concurrent agents per channel without race conditions, refresh-token contention, or supervision gaps. Build the multi-agent eval suite (concurrent-add, concurrent-post, refresh-token-race, parent-death-orphans) BEFORE shipping multi-agent UX.

## L12 — Beta + stable release channel discipline (lift Clawpilot's release scripts)

**Source**: clawpilot-architecture.md §11 (`release:cut-beta` + `release:promote` scripts; commit `71478871`) + openclaw-recent-releases.md (rolling cadence with beta intermediates).
**Confidence**: HIGH.

Both ecosystems ship aggressively (every 1-3 weeks). Both have beta channels. The new engine should adopt the same: `release:cut-beta` cuts a beta tag; `release:promote` promotes to stable AND verifies `/releases/latest` moved (Clawpilot's recent fix `5bcfef47`). `make_latest=true` on stable promotion (Clawpilot fix `11b57d62`).

**Engine rule**: ship `release:cut-beta` + `release:promote` + `verify-release` scripts in v1. Don't manually tag releases.

## L13 — Telemetry is per-feature + tested

**Source**: clawpilot-architecture.md §10 + clawpilot-features-inventory.md §10 (13 distinct `*.telemetry.test.tsx` files).
**Confidence**: HIGH.

Clawpilot's discipline: every feature with telemetry has a sibling `*.telemetry.test.tsx` that asserts the right events fire. This is a test-quality lesson — telemetry isn't checked at runtime if you don't test it. The new engine should adopt the same: any code path that emits telemetry has a test that asserts the event.

**Engine rule**: per-feature telemetry tests are part of the gate suite. Coverage rule: every emitter has a test.

## L14 — Cross-platform from day 1 (Windows-first attention)

**Source**: clawpilot-architecture.md §1 (sidecar `node-runner.exe` for Windows MCP spawning) + CLAUDE.md cross-platform requirement section + openclaw-recent-releases.md v2026.5.4 ("Windows gateway listener bound to 127.0.0.1 only").
**Confidence**: HIGH.

Both ecosystems hit Windows-specific issues that took fixes (path separators, console-window flash, IPv6 dual-stack). The user's environment is Windows. The new engine MUST be cross-platform from day 1, with Windows tested on every PR.

**Engine rule**: Windows is a tier-1 dev platform. CI runs on Windows + macOS + Linux. No path-separator hardcoding. `windowsHide: true` for any spawn. `127.0.0.1`-only binding (no IPv6 dual-stack). `path.join` everywhere.

## L15 — Append-only audit log + signed verdicts for governance triad

**Source**: clawpilot-architecture.md §13 (`audit-log.ts`) + the user's "Governance triad: hash-audit + halt + cost ledger" v1 directive + the kit's existing `single-owner-accountability.md` + `council-verdict-artifact.md` rules.
**Confidence**: HIGH.

Clawpilot has an append-only audit log. The kit has owner-accountability + council-verdict-artifact rules. The user wants a governance triad. Synthesis: every channel has `<channel>/audit-log.jsonl` (append-only); every council verdict is a separate file under `<channel>/verdicts/<id>.json`; every cost-bearing tool call is logged to `<channel>/cost-ledger.jsonl` with token / latency / dollar fields.

**Engine rule**: governance triad surface = (a) `audit-log.jsonl` append-only per channel; (b) `verdicts/<id>.json` per council verdict (canonical artifact frontmatter signature per the kit's existing rule); (c) `cost-ledger.jsonl` per channel with model / tokens / dollar / latency. CLI surface: `mad-council audit <channel>`, `mad-council costs <channel>`.

## Closing synthesis

The new engine's design is **L1-L15 applied at every layer**:
- Per-agent isolation (L1, L2, L3)
- Typed contracts (L4)
- Default-deny capabilities (L5)
- Pluggable backends (L6)
- Pluggable memory (L7)
- Pluggable platforms (L8)
- Bounded everything (L9)
- Operator-visible state (L10)
- Multi-agent first (L11)
- Release discipline (L12, L13, L14)
- Governance triad (L15)

The OpenClaw v4.0 race + the Clawpilot mature-codebase patterns together give us a strong target: take Clawpilot's IPC + backend + permission + skills + MCP + auth shapes, layer in MAD.Council's owner-accountability + canonical artifact + concurrency-safety rules, add the governance triad as a first-class surface, and design multi-agent orchestration from day 1 to avoid OpenClaw's #43367 failure modes.

---

**Lane C topic 6/6 complete.**
