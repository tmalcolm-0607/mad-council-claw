# MAD — Unified Plugin + Kit

This repo is the canonical source for MAD (Multi-Agent Discipline) going forward. It combines the **runtime plugin** and the **authoring kit** in a single artifact so the council has access to its own design documentation at runtime.

## New session? Start here.

Before any work:

```powershell
./scripts/Verify-Health.ps1
```

Expected: `[PASS] HEALTHY` in ~60s. Proves git state + 30 key files + full Pester suite (294/294) + Phase 1 E2E smoke roundtrip. Do NOT trust claims in `STATUS.md` or any doc without re-running this first.

Then read `STATUS.md` for the current next-step priority list.

## Status

- **Phase 1 MVP**: `/council-*` commands for file-based multi-agent coordination (channels, threads, typed messages, session-id binding, schema-valid state).
- **Phase 2–5**: not yet built. See `plans/phase-2-council.md` through `plans/phase-5-intelligence.md`.
- **Unvalidated**: this port is the starting point, not a proven system. Expect to iterate.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest (installable via Claude Code marketplace)
- `commands/` — slash commands (`/council-open`, `/council-post`, `/council-join`, `/council-leave`, `/council-list`, `/council-check`, `/mad-ui`)
- `skills/` — council-* skills + mad-* workflow skills (feature dev)
- `agents/` — role definitions (Advocate, Skeptic, Architect)
- `rules/` — prompt-injection, dangerous-ops, degradation, concurrency, STRIDE, etc.
- `schemas/` — channel, thread, message, digest, verdict, consent-log, retro, sessions
- `scripts/` — atomic-write, seq-increment, verdict-compute, preflight, etc.
- `hooks/` — Claude Code harness hooks
- `bootstrap/` — plugin bootstrap scripts
- `ui/` — `/mad-ui` local web UI
- `wiki/` — patterns, implementations, best practices, guides, glossary (runtime-accessible knowledge)
- `evals/` — 6-layer test harness (spec coverage, STRIDE, correctness, observability)
- `metrics/` — 4-dimension KPI framework (technical, financial, safety, reliability)
- `plans/` — Phase 1–5 roadmap
- `decisions/` — ADRs (e.g. fat-plugin path resolution)
- `templates/` — spec, plan, tasks, contracts templates
- `lib/` — JS modules (phase-gates, context-metrics, wave-dispatcher, handoff-generator)
- `operations/` — ops docs (validation, DR, cost, perf, migration)
- `prompts/` — specialist prompts
- `tests-harness/` — evals infrastructure
- `specs-reference/` — reference spec artifacts
- `harness/` — Claude Code harness config references
- `docker/` — Dockerfile for local UI
- `mad.council.a2a.md` — the spec (sections 0–14, ~1050 lines)
- `BACKLOG.md` — open / deferred items
- `PORTED.md` — historical port map (from playground-main; being superseded)

## Install

See `bootstrap/README.md` and `.claude-plugin/plugin.json`. Broad strokes:

```
# Register as a marketplace
/plugin add-marketplace <path-to-this-repo>
# Install
/plugin install mad-council
```

After install, `/council-*` commands become available in all Claude Code sessions — useful for orchestrating multi-agent work across any set of consumer projects.

## Validation is the next chapter

This repo was populated by porting `playground-main/plugins/mad-council/` + `playground-main/MAD/` in one commit on 2026-04-22. Nothing is validated end-to-end yet. Expected next steps:

- Run `evals/` layer 0–5 harness against this codebase.
- Exercise `/council-open` → `/council-post` → `/council-check` roundtrip on `~/claude-data/`.
- Build Phase 2 council review/verdict/retro flow.
- Build Phase 3 autonomous MAD workflow (council auto-runs `/mad-spec` → `/mad-validate`).
- Build Phase 4 A2A protocol.
- Build Phase 5 intelligence (failure recovery, self-improvement).

See `plans/` for scope.
