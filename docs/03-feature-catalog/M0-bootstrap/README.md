---
artifact-class: milestone-overview
generated-by: hand-authored (wave-002 / lane-b)
status: red
milestone: M0
short-slug: bootstrap
features: F-001..F-008
authored: 2026-05-07
---

# M0 — Project bootstrap

The foundation milestone. Every feature here is a substrate other milestones plug into. M0 lands as a single bootstrap PR (per `foundational-plan.md` § Repo bootstrap M-1) plus per-feature follow-ons; subsequent F-NNN features land as micro-PRs.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-001 | engine-bootstrap-loop | Engine kernel — lifecycle (open→active→closing→closed), cycle iteration ≤50, foundation for every other feature |
| F-002 | per-agent-identity-runid | run_id + agent_id + parent_run_id correlation chain stamped on every audit entry / IPC message |
| F-003 | repo-scaffolding | 3-package monorepo: `engine-core`, `desktop-shell`, `cli`. tsconfig hierarchy + workspace globs |
| F-004 | vitest-playwright-config | 4-project Vitest layout + Playwright sharedTest/test fixture modes (clawpilot-derived) |
| F-005 | deps-pinning | Exact-version deps + committed package-lock.json + `npm ci` discipline; no range operators |
| F-006 | logging-pipeline | Single structured-event facade: NDJSON text log + hash-chained audit sink, identity-stamped, no-console lint rule |
| F-007 | ipc-contract-scaffold | Typed IPC channels via contextBridge; `nodeIntegration: false`, `contextIsolation: true`; contract is single-source-of-truth |
| F-008 | local-storage-layout | `userData/mad-council-claw/` directory tree; atomic write-temp-then-rename; runs/ skills/ verdicts/ kill-switch.json/ automations/ |
| F-138 | engine-cycle-orchestrator | NEW (wave-017 / lane-a). Composes F-001/F-002/F-009/F-014/F-015/F-018/F-019 into single MAD-pipeline iteration. Resolves wave-016 HARD-BLOCK F1. |

## Dependency DAG

```
F-003 (scaffolding) ─┬─→ F-004 (test config)
                     ├─→ F-005 (deps pin)
                     └─→ F-007 (ipc scaffold)

F-008 (storage)  ─┐
                  ├─→ F-001 (engine kernel) ─┬─→ F-002 (identity)
                  │                          └─→ F-006 (logging)
                  └────────────────────────────→ F-006

(F-001..F-008 land in any order their hard-deps allow; M0 is "complete"
when all 8 ledgers go GREEN.)
```

## Milestone exit criteria

- All 8 ledgers GREEN (every test file exists + every runner returns 0)
- `npm ci && npm run build && npm test` succeeds on clean clone (Linux + macOS + Windows)
- An empty engine run completes the lifecycle (`open → active → closing → closed`) and writes a valid retro
- `Verify-AuditChain` succeeds on any run's audit log

## Out of scope (tracked elsewhere)

Per `rules/no-silent-deferrals.md`:
- LLM backends (M1 / F-009..F-013)
- Governance triad (M2 / F-014..F-022)
- Any user-facing UI, settings, automations (M5+)
- Telemetry export, packaging (M15+)
- Encrypted storage of secrets (M8 / F-070..F-071)

## Provenance

Each ledger cites canonical-e (`ce:`), MAD kit (`kit:`), or clawpilot (`cp:`) surfaces in its `provenance.surfaces` frontmatter list. See `docs/01-requirements/foundational-plan.md` § True Synthesis for the source mapping.
