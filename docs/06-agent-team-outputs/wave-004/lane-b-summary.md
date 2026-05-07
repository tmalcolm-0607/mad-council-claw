---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-004 / lane-b)
wave: wave-004
lane: lane-b
topic: per-feature-ledger-authoring-M7-skills-perms-automations
date: 2026-05-06
status: complete
---

# Wave 4 / Lane B — per-feature ledgers for M7 (Skills + Permissions + Automations)

## Scope

M7 catalog drop — the extensibility plane. 16 RED-state ledgers spanning F-051..F-066 across three logically distinct groups (Skills 7, Permissions 3, Automations 6) plus an M7 milestone README. Matches the `M7 | Skills+Perms+Auto | F-051..F-066` row of `foundational-plan.md` § True Synthesis Feature catalog.

## What was created

| Group | Path | Count |
|---|---|---|
| Skills ledgers | `docs/03-feature-catalog/M7-skills-perms-auto/F-051..F-057-*.md` | 7 |
| Permissions ledgers | `docs/03-feature-catalog/M7-skills-perms-auto/F-058..F-060-*.md` | 3 |
| Automations ledgers | `docs/03-feature-catalog/M7-skills-perms-auto/F-061..F-066-*.md` | 6 |
| M7 README | `docs/03-feature-catalog/M7-skills-perms-auto/README.md` | 1 |
| This summary | `docs/06-agent-team-outputs/wave-004/lane-b-summary.md` | 1 |
| **Total** | | **18** |

## Per-ledger frontmatter contract

Matches wave-2 Lane B's contract verbatim: `artifact-class: feature-ledger`, `generated-by: hand-authored (wave-004 / lane-b)`, `status: red`, `status-since: 2026-05-06`, `status-history`, `feature-id`, `short-slug`, `milestone: M7`, `provenance.surfaces: [foundational-plan:..., ce:..., cp:..., kit:...]`, `fr-coverage: []`, `test-files: {unit, node, browser, integration, e2e}` empty, `red-green-rule:` literal, `depends-on`, `out-of-scope-notes` per `rules/no-silent-deferrals.md`, `confidence: high`.

## Per-ledger body sections

Same 6-section shape as wave-2 + wave-3:
1. Behavior contract (3-5 sentences, present-tense imperative)
2. Acceptance scenarios (3 GIVEN/WHEN/THEN scenarios with observable outcomes)
3. Red→green wire-up table (TBD test files; RED initial state)
4. Dependencies (Hard / Soft / Independent)
5. Surface trace (provenance with one-line "what it contributes")
6. Implementation notes (empty placeholder)

## Provenance distribution

| Source family | Surfaces cited (across 16 M7 ledgers) |
|---|---|
| Foundational plan (`foundational-plan:`) | M7-skills-perms-auto row + § Tool plane (MCP servers + Skills + tool-cap-per-workspace) + § Architecture |
| Canonical-e (`ce:`) | US-6 (allowlist + pinning), FR-AUDIT-001 (hash-chain), FR-AUDIT-002 (tamper-detection) |
| Clawpilot (`cp:`) | bundled-skills/, first-party-skills/, skills/, electron/skills.ts (766 LOC), common/skill-sanitization.ts, electron/yaml-utils.ts, electron/permission-policy.ts (1,331 LOC), electron/permission-classifier{,-types}.ts, electron/permission-patterns.ts, electron/permission-pattern-guardrails.ts, electron/permission-shell-syntax.ts, electron/permissions.ts, electron/permissions-calendar.ts, common/permission-servers.ts, src/features/permissions/* (7 files), electron/automations/{manager,schedule,condition-monitor,triggering,store,schemas,types}.ts, electron/automations.ts, electron/ipc/{automations-ipc,automations-desktop-ipc}.ts, src/features/automations/* (7 files), scripts/install-skills.mjs, scripts/initialize-bundled-skills.mjs |
| MAD kit (`kit:`) | rules/{skill-standards, canonical-skill-only, dangerous-operations-policy, concurrency-safety, verification-protocol, loop-cadence-discipline, anomaly-thresholds, _status-convention, orchestration, degradation-fallback-policy, resume-protocol}.md, docs/04-research/frontier-2026/anthropic-skills-authoring.md |

## Anomalies / context gaps

- **Anthropic Skills authoring research surfaces 6 NEW F-NNN candidates that did NOT land as ledgers in this lane**: F-051..F-056 in that doc's "NEW F-NNN candidates" section (frontmatter-contract-hook, reference-depth-audit, evals-first-scaffold, pair-programming-mode, skill-conciseness-audit, mcp-tool-name-validation) clash with the M7 numbering (F-051..F-066 are the M7 features per foundational-plan). The doc was written BEFORE the M7 catalog row was numbered. The conflict is that 6 ledger F-NNN slots exist in two places. Resolution per `rules/no-silent-deferrals.md`: M7 wins (per foundational-plan numbering); the 6 candidates from anthropic-skills-authoring.md remain valuable but need re-numbered F-NNN slots in a future wave (likely M19 deferred catalog or as additions to M7 if foundational-plan is updated). Tracked in M7 README "Out of scope" + here.
- **F-066 bundles "results-in-shell" + per-automation perms + GitHub-import-button surface**: foundational-plan says "shell-visible" as the 16th item; clawpilot's actual surface bundles `AutomationListView.tsx` rendering + `automations-desktop-ipc.ts` events + `GithubImportView.tsx` + `AutomationCapabilities.perAutomationPermissions` flag. Ledger handles all four under the same F-066 ID with explicit out-of-scope-notes for GitHub-import (deferred) and per-automation perms (linked back to F-058+F-059 + F-066 cross-reference). HIGH confidence.
- **F-NNN -> FR-XXX exact mapping deferred** per the wave-2 brief precedent — `fr-coverage: []` filled by `/mad-spec` per-feature in implementation wave.
- **No live test files** per same brief — test-files frontmatter empty until M7 implementation wave lands actual test files.

## Out of scope (per `rules/no-silent-deferrals.md`)

- F-125 mcp-tool-cap-per-workspace (M7 NEW from frontier research) — listed in foundational-plan but NOT one of the 16 F-051..F-066 numbered features; deferred to its own ledger drop in a later wave
- 6 NEW Anthropic-Skills-authoring F-NNN candidates (frontmatter-hook, reference-depth-audit, evals-first-scaffold, pair-programming-mode, conciseness-audit, mcp-tool-name-validation) — re-numbering needed; flagged in M7 README out-of-scope + this summary
- Test plans (`/testplan` per-feature) — runs at /mad-spec time per wave-2 precedent
- Other M-Group catalog drops (M8, M9, M10, M11, M12, M13, M14, M15, M16, M17, M18, M19) — out of this lane's scope; M8 is a parallel lane in this wave per the foundational plan & `loop-meta` shape

## Confidence

HIGH (all 16 ledgers + README). Source material — `foundational-plan.md` M7 row + `cp:electron/skills.ts` + `cp:electron/permission-policy.ts` + `cp:electron/automations/` + `ce:US-6` — is consistent and well-mapped. The 16 features map 1-to-1 to the 16 verbatim items in the foundational-plan M7 row (counted: SKILL.md, bundled, toggle, custom-load, allowlist, version-pin, expiry, 3-tier perms, rules, audit, automations base, cron, condition, multistep, persist, shell-visible). Behavior contracts are present-tense imperative; acceptance scenarios are GIVEN/WHEN/THEN with observable outcomes; dependencies trace cleanly through the M0/M1/M2/M3/M5/M15 DAG.

## Quality-gate checklist (QG1-QG9 for wave-004 lane-b)

- [x] QG1 — net-new — first M7 catalog drop; 16 ledgers + 1 README + this summary are net-new artifacts
- [x] QG2 — sources cited — every ledger's `provenance.surfaces` lists kit/ce/cp surfaces; this summary cites foundational-plan + clawpilot inventory + canonical-e + Anthropic Skills authoring research
- [x] QG3 — touches Goal G1-G25 — touches G1 (red→green ledgers per V:1), G6 (catalog), G8 (extensibility plane primitives — skills + perms + automations), G18 (multi-agent fan-out applied to wave structure), G15 (governance triad cross-link via F-060 audit)
- [x] QG4 — backlog item processed/generated — generates: 6 NEW F-NNN candidates (Anthropic Skills authoring) needing renumber; generates: per-ledger `fr-coverage: []` to be filled by /mad-spec runs
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-004 has multiple lanes (lane-a, lane-b, lane-c, lane-d running in parallel — visible in `git log` showing F-073/F-074/F-075/M8 and msft-2026 research commits interleaving)
- [ ] QG7 — Copilot CLI design review — N/A this lane (deferred per QG7 cadence to designated lane in wave 4 or 5)
- [ ] QG8 — Microsoft tools used — N/A this lane (foundational-plan + clawpilot + canonical-e read-only synthesis)
- [x] QG9 — open questions captured — frontmatter + summary `Anomalies` section above

## Loop-improvement proposal (QG5)

The 16-ledger drop completed in ≤5 min wall-clock by template-mirroring wave-2 lane-b's exact frontmatter + body structure. Three lift-able patterns from this lane:

1. **Group-internal-DAG-in-README** is the strongest signal for an extensibility milestone. M7 has 3 logically distinct groups (Skills, Permissions, Automations) with significant cross-group dependencies (Permissions classifies Automation steps; Skills are Automation step targets; Audit cross-references Permission decisions per-automation). The README's DAG ASCII art makes these cross-group dependencies legible in one read. Recommend: every milestone with >1 logical sub-group carries a sub-group-aware DAG.

2. **`out-of-scope-notes` discipline + cross-reference to NEW F-NNN candidates** is the load-bearing way to honor `rules/no-silent-deferrals.md` when a research doc's candidate F-NNN slot collides with a numbered milestone slot. M7 had this exact collision with `anthropic-skills-authoring.md`. The resolution (M7 numbering wins; renumber the research candidates) is documented in BOTH the README out-of-scope AND this summary's anomalies — making the deferral explicit + greppable. Recommend: every catalog drop check for F-NNN slot collisions against research docs.

3. **Surface-trace table with one-line "what it contributes"** for every provenance entry is more useful than a flat `provenance.surfaces` list. The table makes the lineage between e.g. `cp:electron/permission-policy.ts (1,331 LOC)` and the feature's "deterministic policy engine" claim greppable. Recommend: future ledgers always include the table even when the list-form would suffice.

## Next steps

- Wave 4 / lane-a, lane-c, lane-d continue against their topics (per parallel commit log evidence: M8 + msft-2026 research lanes in flight)
- Wave 5+ may pick up M9-M19 catalog drops in the same template; suggested: M9 (M365 integration) is the natural next given dependency-chain proximity
- M7 implementation wave can begin once M0+M1+M2+M3 are GREEN (M7 hard-deps are F-001/F-007/F-008/F-015/F-018/F-023/F-024/F-032/F-042/F-104)
- 6 Anthropic-Skills-authoring NEW F-NNN candidates need renumbering and dedicated ledger drops (suggested: M19 deferred catalog or expand M7)
