---
title: OpenClaw issue #43367 — multi-agent orchestration unstable
wave: wave-001
lane: lane-c
topic: 3/6
source-tag: "[R:openclaw-external]"
generated-by: lane-c-research
generated-by-version: 0.1.0
date: 2026-05-06
status: preview
---

# OpenClaw issue #43367 — multi-agent orchestration unstable

> Source: https://github.com/openclaw/openclaw/issues/43367 (fetched 2026-05-06 via WebFetch).

## Summary

The reporter ran multiple OpenClaw agents in parallel and observed cascading failure modes. The issue links three previously-tracked tickets that cover individual aspects of the failure (session locking #42160, lock cleanup on process death #32799, OAuth refresh races #26322) — issue #43367 is the integrative report showing they compound under multi-agent load.

## Documented failure modes

### F1 — Concurrent config file corruption during agent creation

- **Symptom**: simultaneous `openclaw agents add` invocations corrupt the global config file.
- **Root cause**: race condition; no serialization or file-level lock around the global config write path.
- **Workaround documented**: create agents sequentially.
- **Severity**: HIGH (data loss — config corruption requires manual reconstruction).
- **Confidence**: HIGH (cited verbatim in issue body).

### F2 — Session lock timeouts on isolated agents

- **Symptom**: agents with separate workspaces and separate sessions still see lock-timeout errors when running in parallel.
- **Root cause**: per-agent session files use a monolithic JSON with a global locking mechanism. Even isolated agents contend on the global lock.
- **Workaround documented**: none. Sequential execution may reduce contention but doesn't address the underlying global-lock design.
- **Severity**: HIGH (fails the "agents are independent" promise).
- **Confidence**: HIGH (cited verbatim).

### F3 — OAuth token refresh race in failover chain

- **Symptom**: when session locks fail (F2), the model failover path tries alternative providers, triggering `refresh_token_reused` errors from OpenAI when multiple concurrent requests refresh the same token.
- **Root cause**: cascading from F2; the failover path does not deduplicate the refresh-token operation across agents that share an auth identity.
- **Workaround documented**: none.
- **Severity**: HIGH (provider may revoke the refresh token entirely on reuse, requiring full re-auth).
- **Confidence**: HIGH (cited verbatim).

### F4 — Detached background processes after CLI failure

- **Symptom**: when the CLI command fails or hangs, child agent processes continue running unsupervised. They hold session locks and execute child work (builds, installs) without operator visibility.
- **Root cause**: no parent-child supervision contract; child processes are not signaled on parent exit.
- **Workaround documented**: manual cleanup — kill processes, release locks, delete agents.
- **Severity**: HIGH (silent resource consumption + impossible-to-debug "phantom" agent state).
- **Confidence**: HIGH (cited verbatim).

## Linked issues (root-cause underlying #43367)

| Issue | Topic | Confidence |
|---|---|---|
| #42160 | Session store locking design | HIGH (linked from #43367 body) |
| #32799 | Lock file cleanup on process death | HIGH (linked) |
| #26322 | OAuth refresh races | HIGH (linked) |

## Implications for the new engine

| Implication | Specific design rule | Confidence |
|---|---|---|
| **Per-agent isolation must be filesystem-real, not synthetic** | Each agent has its own session store directory, its own lock scope, its own auth identity binding (no shared refresh token) | HIGH |
| **No global locks** | All concurrency primitives must be path-scoped (per-channel, per-thread, per-session). Validate the MAD.Council `concurrency-safety.md` Rule 1 (append-only) + Rule 2 (atomic write per file) handle this case. | HIGH |
| **Refresh-token per agent** | Bind OAuth refresh tokens to an agent identity; do not share refresh tokens across agents even when the same user is logged in. Use separate `msalCache` files per agent identity. | HIGH |
| **Parent-child supervision contract** | When the orchestrator spawns a child agent process, the parent must hold a supervision channel. On parent exit, children are signaled (SIGTERM with grace period, then SIGKILL). | HIGH |
| **Lock cleanup on process death** | Use OS-level file locks (advisory `flock(2)` on POSIX, `LockFileEx` on Windows) instead of pidfile-based locks. OS-level locks are released by the OS on process death. | HIGH |
| **Concurrent-add gate** | The `/council-open` skill (and any "add agent" / "add channel" equivalent) must serialize through a small-scope lock (e.g., `~/.copilot/m-channels/.add-lock`) — preventing F1's class. | HIGH |
| **Failover-loop bounds** | When the primary backend fails auth, do NOT retry against alternative backends with the same refresh token. Bound the failover loop and surface the auth error back to the user instead of silently retrying. | HIGH |
| **Operator-visible child state** | Spawned child agents must register in a known parent-readable directory (e.g., `~/.copilot/m-agents/<agent-id>/pid + status`). Operator can see what's running and kill it. | HIGH |

## STRIDE delta on these failure modes

| STRIDE | F1 | F2 | F3 | F4 |
|---|---|---|---|---|
| Spoofing | — | — | shared refresh token = identity confusion across agents | — |
| Tampering | corrupted config | — | — | — |
| Repudiation | — | — | refresh-token revoke leaves no audit | phantom processes leave no audit of their actions |
| Info Disclosure | — | — | — | child process may leak data via uncontrolled stdout |
| DoS | — | global-lock contention = whole-system slowdown | provider throttling / refresh-token revoke | resource exhaustion |
| Elevation | — | — | — | unsupervised child has parent's permissions but no checks |

## What the new engine should do differently (concrete diffs from OpenClaw)

1. **No monolithic JSON for session state.** Use one file per session (Clawpilot already does this — `~/.copilot/m-sessions/{id}.json`). Avoids F2's class entirely.
2. **One auth identity per agent role (Advocate/Skeptic/Architect or per-channel persona).** Refresh tokens scoped to the role. F3 cannot occur because no two agents share a refresh token.
3. **`registered-children` directory** at `<state-dir>/children/<child-id>/{pid,started_utc,parent_pid,status}.json`. Orchestrator inspects this on startup; orphans are reaped. F4's class becomes "stale child file" instead of "phantom process."
4. **Atomic-write contract on the global config + small-scope lock for adds.** F1's class is blocked by the `concurrency-safety.md` Rule 2 + Rule 3 already in the kit.
5. **Bounded failover.** `degradation-fallback-policy.md` Rule 4 (respect retry limits) already in the kit; need to ensure it's wired at the auth-broker layer specifically (separate from the request-retry layer).

## Findings explicitly marked "no findings"

- **No quantitative repro counts** in the issue (e.g., "X failures per 100 parallel runs"). The issue is qualitative.
- **No fix PR linked** as of fetch date (2026-05-06). The linked issues #42160 / #32799 / #26322 may have separate fix PRs but were not enumerated in the WebFetch summary.

---

**Lane C topic 3/6 complete.** Next: OpenClaw v4.0 roadmap.
