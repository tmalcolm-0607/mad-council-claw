---
artifact-class: milestone-overview
generated-by: hand-authored (wave-005 / lane-b)
status: red
milestone: M10
short-slug: multi-model
features: F-082..F-087
authored: 2026-05-06
---

# M10 — Multi-model adversarial review

The cross-model adversarial review plane (`kit:rules/lens-multi-model-review-pattern.md`). Same brief + diff is dispatched to **Claude Opus** AND **GPT-5+** in parallel; a synthesis step builds a cross-model agreement table. When BOTH models flag the same CRITICAL pattern, the finding is treated as a HARD BLOCK. The point is not "pick the better model" — it is to use the two as adversarial cross-checks. Each model carries different blind spots; their AND-of-flags raises precision wherever the biases are uncorrelated.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-082 | council-mode-dispatch | Task-tool subagent spawns `Invoke-CopilotMultiModel.ps1`; orchestrator never invokes dispatcher directly |
| F-083 | cross-model-agreement-table | 4-column table (Finding / Opus / GPT / Decision) built from `<OutputDir>/{opus,gpt}-result.json` |
| F-084 | both-flag-critical-hard-block | Both-model CRITICAL agreement → HARD BLOCK; only `wait-for-author` / `reject` are valid forward paths |
| F-085 | same-model-fallback | Copilot CLI absent → two parallel Tasks on same model with role-distinguishing prompts; emits Context Gap |
| F-086 | first-use-consent-gate | First `--council` invocation per session emits `AskUserQuestion`; subsequent calls reuse consent; fallback path skipped |
| F-087 | high-blast-radius-skills-wired | Skills with `blast_radius ≥ 7` MUST inherit the rule + declare `--council` mode body block |

## Dependency DAG

```
M0 (F-001 kernel, F-008 storage, F-013 events)  ──→  F-082 (dispatch)
                                                       │
                                            ┌──────────┴──────────┐
                                            ▼                     ▼
                                        F-083 (agreement-table)   F-086 (consent gate)
                                            │
                                            ▼
                                        F-084 (hard-block)
                                            │
                                            ▼
                                            ┌─────── F-085 (fallback uses same shape)
                                            │
                                            ▼
                                        F-087 (skills wired — depends on ALL upstream)

F-021 (degradation Context Gaps)  ──→  F-085 (fallback emits Context Gap line)
F-015 (hash-chained audit log)    ──→  F-084 (hard-block bypass attempts logged)
                                  └──→  F-086 (consent decisions logged)
F-077 (skill-audit infrastructure) ──→ F-087 (audit asserts wiring on blast_radius ≥ 7)
```

## Milestone exit criteria

- All 6 ledgers GREEN
- A `--council` invocation with Copilot CLI available produces both-model results, agreement table, and verdict synthesis end-to-end
- Both-flag-CRITICAL agreement on a synthetic SQL-injection fixture produces HARD BLOCK and cannot be bypassed without `wait-for-author` / `reject`
- Copilot CLI absent triggers same-model role-split fallback with the exact Context Gap line
- First-use consent gate fires once per session; consent-log carries the entry; subsequent calls reuse without re-prompting; fallback path does NOT fire the gate
- The 6 anchor skills (`pr-review`, `code-reviewer`, `mad-spec`, `mad-plan`, `lens-aspnet-structure`, `claude-md-refresh`) carry `inherits-rules` AND `## --copilot mode` body block per the inheritance contract

## Out of scope (per `rules/no-silent-deferrals.md`)

- HARD-BLOCK explicit override consent gate (deferred to M19 backlog; v1 only allows `wait-for-author` / `reject` past a HARD BLOCK).
- Per-invocation re-prompting of consent (v1 reuses session-scoped consent; per-invocation is M19-deferred for heightened-trust environments).
- Multi-host fallback (Copilot CLI on a remote machine — v1 covers only local-Copilot-missing).
- Auto-escalation trigger logic (`blast_radius ≥ 7` decision lives in `kit:rules/prescriptive-content-review.md` § Gap 5; this milestone covers the inheritance contract, not the trigger).
- Consent revocation mid-session (out of v1; tracked in M19-deferred).
- Per-skill rollout sequencing beyond the 6 anchor skills (handled when each skill is authored / refreshed, not as part of M10).
